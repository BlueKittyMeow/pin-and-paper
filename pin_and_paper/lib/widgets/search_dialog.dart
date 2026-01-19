import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/tag.dart';
import '../models/filter_state.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';
import '../services/tag_service.dart';
import '../services/task_service.dart';
import '../services/database_service.dart';
import '../providers/task_provider.dart';
import '../utils/tag_colors.dart';
import 'search_result_tile.dart';
import 'tag_filter_dialog.dart';

class SearchDialog extends StatefulWidget {
  @override
  _SearchDialogState createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final _searchController = TextEditingController();
  final _tagService = TagService();  // v4: Cache service instance
  SearchScope _scope = SearchScope.current;  // DEFAULT: Current (BlueKitty)
  List<SearchResult> _results = [];

  // v3 FIX (Codex): Full FilterState instead of just tag IDs
  FilterState? _tagFilters;  // Preserves AND/OR logic and presence filters

  bool _isSearching = false;

  // v3 FIX (Codex): Debounce implementation - prevent race conditions
  Timer? _debounceTimer;
  int _searchOperationId = 0;  // Monotonic ID for race condition protection

  // v4 FIX (CRITICAL #1): Pre-loaded data maps
  Map<String, Tag> _tagCache = {};
  Map<String, String> _breadcrumbs = {};  // CRITICAL: Store breadcrumbs here

  @override
  void initState() {
    super.initState();
    // v3 FIX (Gemini): Set loading state synchronously before async restore
    _restoreSearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();  // v3: Clean up timer
    _searchController.dispose();
    // Save search state for next open (cleared only on app launch)
    _saveSearchState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias, // Clip AppBar to respect rounded corners
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header with close and clear all buttons
            _buildHeader(),

            // Search field
            _buildSearchField(),

            // Scope filter chips
            _buildScopeFilters(),

            // v3 NEW: FilterState UI (AND/OR toggle + presence filters + tag chips)
            _buildTagFilters(),

            // Results list (or loading/empty state)
            Expanded(
              child: _isSearching
                  ? _buildLoadingState()
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppBar(
      title: Text('Search Tasks'),
      actions: [
        // Clear All button - BlueKitty requirement
        if (_searchController.text.isNotEmpty ||
            _tagFilters != null ||
            _scope != SearchScope.current)
          TextButton(
            onPressed: _clearAll,
            child: Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _clearAll() {
    setState(() {
      _searchController.clear();
      _scope = SearchScope.current;
      _tagFilters = null;
      _results = [];
      _breadcrumbs = {};
    });
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search titles, notes, tags...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _debounceTimer?.cancel();  // v3: Cancel pending search
                    setState(() {
                      _results = [];
                      _breadcrumbs = {};
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(),
        ),
        // v3 FIX (Codex): Debounced search on input
        onChanged: (value) => _debouncedSearch(),
        onSubmitted: (value) {
          _debounceTimer?.cancel();  // v3: Skip debounce on submit
          _performSearch();
        },
      ),
    );
  }

  // v3 NEW (Codex): Debounce search to prevent race conditions
  void _debouncedSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  void _setScope(SearchScope scope) {
    setState(() {
      _scope = scope;
    });
    _debouncedSearch();  // v3: Trigger debounced search on scope change
  }

  Widget _buildScopeFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: Text('All tasks'),
            selected: _scope == SearchScope.all,
            onSelected: (_) => _setScope(SearchScope.all),
          ),
          FilterChip(
            label: Text('Current'),
            selected: _scope == SearchScope.current,
            onSelected: (_) => _setScope(SearchScope.current),
          ),
          FilterChip(
            label: Text('Recently completed'),
            selected: _scope == SearchScope.recentlyCompleted,
            onSelected: (_) => _setScope(SearchScope.recentlyCompleted),
          ),
          FilterChip(
            label: Text('Completed'),
            selected: _scope == SearchScope.completed,
            onSelected: (_) => _setScope(SearchScope.completed),
          ),
        ],
      ),
    );
  }

  // v4 COMPLETE (HIGH FIX #1): Full FilterState UI with contradictory state prevention
  Widget _buildTagFilters() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // "Apply active tags" button
              ElevatedButton.icon(
                onPressed: _applyActiveTagFilters,
                icon: Icon(Icons.filter_list),
                label: Text('Apply active tags'),
              ),
              SizedBox(width: 8),
              // "Add tags" button
              OutlinedButton.icon(
                onPressed: _selectTags,
                icon: Icon(Icons.add),
                label: Text('Add tags'),
              ),
            ],
          ),

          // v4 COMPLETE: Show FilterState controls if tags selected
          if (_tagFilters != null && _tagFilters!.selectedTagIds.isNotEmpty) ...[
            SizedBox(height: 12),
            Row(
              children: [
                // AND/OR toggle - only show when MORE THAN ONE tag selected
                if (_tagFilters!.selectedTagIds.length > 1) ...[
                  Text('Match: ', style: TextStyle(fontSize: 14)),
                  SegmentedButton<FilterLogic>(
                    segments: [
                      ButtonSegment(
                        value: FilterLogic.or,
                        label: Text('Any'),
                        icon: Icon(Icons.filter_alt_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: FilterLogic.and,
                        label: Text('All'),
                        icon: Icon(Icons.filter_alt, size: 16),
                      ),
                    ],
                    selected: {_tagFilters!.logic},
                    onSelectionChanged: (Set<FilterLogic> selected) {
                      setState(() {
                        _tagFilters = _tagFilters!.copyWith(logic: selected.first);
                      });
                      _debouncedSearch();
                    },
                  ),
                  SizedBox(width: 16),
                ],

                // Additional presence filter dropdown (when tags are selected)
                Text('Also require: ', style: TextStyle(fontSize: 14)),
                DropdownButton<TagPresenceFilter>(
                  value: _tagFilters!.presenceFilter,
                  items: [
                    DropdownMenuItem(
                      value: TagPresenceFilter.any,
                      child: Text('No additional filter'),
                    ),
                    DropdownMenuItem(
                      value: TagPresenceFilter.onlyTagged,
                      child: Text('Has any tag'),
                    ),
                    // Don't show "has no tags" when specific tags are selected (contradiction)
                    if (_tagFilters!.selectedTagIds.isEmpty)
                      DropdownMenuItem(
                        value: TagPresenceFilter.onlyUntagged,
                        child: Text('Has no tags'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _tagFilters = _tagFilters!.copyWith(presenceFilter: value);

                        // Clear tags if "has no tags" selected (contradiction)
                        if (value == TagPresenceFilter.onlyUntagged) {
                          _tagFilters = FilterState(
                            selectedTagIds: [],
                            logic: FilterLogic.or,
                            presenceFilter: TagPresenceFilter.onlyUntagged,
                          );
                        }
                      });
                      _debouncedSearch();
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 8),

            // v4 FIX (CRITICAL #1): Pre-loaded tag chips - NO FutureBuilder!
            Wrap(
              spacing: 8,
              children: _tagFilters!.selectedTagIds.map((tagId) {
                final tag = _tagCache[tagId];
                if (tag == null) return SizedBox.shrink();
                final tagColor = tag.color != null
                    ? TagColors.hexToColor(tag.color!)
                    : TagColors.defaultColor;
                return Chip(
                  label: Text(tag.name),
                  deleteIcon: Icon(Icons.close, size: 18),
                  onDeleted: () => _removeTagFilter(tagId),
                  backgroundColor: tagColor.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
          ],

          // v4 HIGH FIX #1: Show presence filter even when no tags selected
          // Allows "only untagged" or "only tagged (any tag)" filters
          if (_tagFilters == null || _tagFilters!.selectedTagIds.isEmpty) ...[
            SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Additional filter:', style: TextStyle(fontSize: 14)),
                SegmentedButton<TagPresenceFilter>(
                  segments: [
                    ButtonSegment(
                      value: TagPresenceFilter.any,
                      label: Text('None'),
                    ),
                    ButtonSegment(
                      value: TagPresenceFilter.onlyTagged,
                      label: Text('Has any tag'),
                      tooltip: 'Show only tasks that have at least one tag',
                    ),
                    ButtonSegment(
                      value: TagPresenceFilter.onlyUntagged,
                      label: Text('Has no tags'),
                      tooltip: 'Show only tasks with no tags',
                    ),
                  ],
                  selected: {_tagFilters?.presenceFilter ?? TagPresenceFilter.any},
                  onSelectionChanged: (Set<TagPresenceFilter> selected) {
                    setState(() {
                      _tagFilters = FilterState(
                        selectedTagIds: [],
                        logic: FilterLogic.or,
                        presenceFilter: selected.first,
                      );
                    });
                    _debouncedSearch();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // v4 COMPLETE (CRITICAL #2): Apply full FilterState, not just IDs
  void _applyActiveTagFilters() {
    final taskProvider = context.read<TaskProvider>();
    final activeFilters = taskProvider.filterState;

    if (activeFilters.selectedTagIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No active tag filters to apply')),
      );
      return;
    }

    setState(() {
      // v3: Copy full FilterState to preserve AND/OR + presence semantics
      _tagFilters = FilterState(
        selectedTagIds: List.from(activeFilters.selectedTagIds),
        logic: activeFilters.logic,
        presenceFilter: activeFilters.presenceFilter,
      );
    });

    // v3 FIX (Gemini): Pre-load tags to avoid FutureBuilder
    _loadTagsForFilter();

    _debouncedSearch();
  }

  // v4 COMPLETE (CRITICAL #2): Full tag selection with correct parameters
  void _selectTags() async {
    // v4 CRITICAL FIX: Fetch all tags first (required parameter)
    List<Tag> allTags;
    try {
      allTags = await _tagService.getAllTags();
    } catch (e) {
      print('Failed to load tags: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load tags. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    // v4 CRITICAL FIX: Pass ALL 4 required parameters to TagFilterDialog
    final selected = await showDialog<FilterState>(
      context: context,
      builder: (context) => TagFilterDialog(
        initialFilter: _tagFilters ?? FilterState.empty,  // Static const, not method
        allTags: allTags,                                 // Required
        showCompletedCounts: _scope == SearchScope.completed ||
                             _scope == SearchScope.recentlyCompleted,
        tagService: _tagService,                          // Required
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _tagFilters = selected;
      });

      // v3 FIX (Gemini): Pre-load tags
      await _loadTagsForFilter();

      _debouncedSearch();
    }
  }

  // v4.1 MEDIUM FIX (Codex): TRUE batch-load tags (single query, not N queries)
  Future<void> _loadTagsForFilter() async {
    if (_tagFilters == null || _tagFilters!.selectedTagIds.isEmpty) return;

    // Find tags not already in cache
    final missingTagIds = _tagFilters!.selectedTagIds
        .where((id) => !_tagCache.containsKey(id))
        .toList();

    if (missingTagIds.isEmpty) return;

    try {
      // v4.1 MEDIUM FIX: Single batch query instead of N queries
      final tags = await _tagService.getTagsByIds(missingTagIds);

      // Add to cache
      for (final tag in tags) {
        _tagCache[tag.id] = tag;
      }
    } catch (e) {
      print('Failed to batch-load tags: $e');
      // Fallback to individual loading if batch fails
      for (final tagId in missingTagIds) {
        try {
          final tag = await _tagService.getTagById(tagId);
          if (tag != null) {
            _tagCache[tagId] = tag;
          }
        } catch (e) {
          print('Failed to load tag $tagId: $e');
        }
      }
    }

    // v3 FIX (Codex): Check mounted before setState
    if (!mounted) return;
    setState(() {});  // Refresh chips with loaded tags
  }

  void _removeTagFilter(String tagId) {
    setState(() {
      final updatedIds = List<String>.from(_tagFilters!.selectedTagIds)
        ..remove(tagId);

      if (updatedIds.isEmpty) {
        _tagFilters = null;
      } else {
        _tagFilters = _tagFilters!.copyWith(selectedTagIds: updatedIds);
      }
    });
    _debouncedSearch();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Searching...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'Type to search tasks'
                : 'No tasks found matching "${_searchController.text}"',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    // Group results by Active/Completed
    final activeResults = _results
        .where((r) => !r.task.completed)
        .toList();
    final completedResults = _results
        .where((r) => r.task.completed)
        .toList();

    return ListView(
      children: [
        if (activeResults.isNotEmpty) ...[
          _buildSectionHeader('Active Tasks', activeResults.length),
          ..._buildResultsList(activeResults),
        ],
        if (completedResults.isNotEmpty) ...[
          _buildSectionHeader('Completed Tasks', completedResults.length),
          ..._buildResultsList(completedResults),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  // v4 COMPLETE (CRITICAL #1): Pass pre-loaded breadcrumbs to tiles
  List<Widget> _buildResultsList(List<SearchResult> results) {
    return results.map((result) => SearchResultTile(
      result: result,
      query: _searchController.text,
      onTap: () => _navigateToTask(result.task),
      breadcrumb: _breadcrumbs[result.task.id],  // CRITICAL: Pass pre-loaded
    )).toList();
  }

  // v4 COMPLETE (CRITICAL #1 + HIGH #3): Search with breadcrumb loading and error handling
  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _breadcrumbs = {};
      });
      return;
    }

    // v3 FIX (Gemini): Set loading synchronously to prevent flash
    setState(() => _isSearching = true);

    // v3 FIX (Codex): Operation ID for race condition protection
    final currentOperationId = ++_searchOperationId;

    try {
      // v4.1 LOW FIX (Codex): Complete instantiation instead of placeholder
      // Use DatabaseService singleton (not from Provider)
      final db = await DatabaseService.instance.database;
      final searchService = SearchService(db);

      // Perform search
      final results = await searchService.search(
        query: query,
        scope: _scope,
        tagFilters: _tagFilters,  // Full FilterState with AND/OR + presence
      );

      // v4 CRITICAL FIX #1: Batch-load breadcrumbs BEFORE updating state
      final breadcrumbsMap = await _loadBreadcrumbsForResults(results);

      // v3 FIX (Codex): Only update if this is still the latest search
      if (currentOperationId != _searchOperationId) return;

      // v3 FIX (Codex): Check mounted before setState
      if (!mounted) return;

      setState(() {
        _results = results;
        _breadcrumbs = breadcrumbsMap;  // CRITICAL: Store breadcrumbs
        _isSearching = false;
      });
    } on SearchException catch (e) {
      // v4: Custom search error - show user-friendly message
      print('Search error: $e');

      if (currentOperationId != _searchOperationId) return;
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _results = [];
        _breadcrumbs = {};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _performSearch(),
          ),
        ),
      );
    } catch (e, stackTrace) {
      // v4: Unexpected error
      print('Unexpected search error: $e\n$stackTrace');

      if (currentOperationId != _searchOperationId) return;
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _results = [];
        _breadcrumbs = {};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed. Please try again.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _performSearch(),
          ),
        ),
      );
    }
  }

  // v4 COMPLETE (CRITICAL #1): Batch-load breadcrumbs with graceful degradation
  // v4.1 MEDIUM (Codex note): This is still N queries (one per task with parent)
  //
  // TRADE-OFF DOCUMENTED:
  // - Still N sequential database queries (not true batch)
  // - BUT: Loaded ONCE before rendering (not per scroll like FutureBuilder)
  // - For typical search results (10-50 tasks): adds ~50-200ms total
  // - Acceptable because: breadcrumbs improve UX significantly, alternative
  //   (recursive CTE or precomputed paths) adds significant complexity
  //
  // If performance becomes issue, consider:
  // - Parallel loading with Future.wait + concurrency limit
  // - Precompute parent paths in TaskProvider tree
  // - Add breadcrumb cache in TaskService
  Future<Map<String, String>> _loadBreadcrumbsForResults(
    List<SearchResult> results,
  ) async {
    final breadcrumbs = <String, String>{};
    final taskService = TaskService();

    for (final result in results) {
      if (result.task.parentId != null) {
        try {
          final parents = await taskService.getParentChain(result.task.id);
          breadcrumbs[result.task.id] = parents.map((t) => t.title).join(' > ');
        } catch (e) {
          // v4: Graceful degradation - just skip breadcrumb for this task
          print('Failed to load breadcrumb for task ${result.task.id}: $e');
          // Don't add entry - tile will check for null
        }
      }
    }

    return breadcrumbs;
  }

  void _navigateToTask(Task task) {
    // Close dialog - BlueKitty confirmed
    Navigator.pop(context);

    // Navigate to task in main list
    context.read<TaskProvider>().navigateToTask(task.id);
  }

  // Search state persistence (BlueKitty: cleared only on app launch)
  void _saveSearchState() {
    final state = {
      'query': _searchController.text,
      'scope': _scope.index,
      'filterState': _tagFilters?.toJson(),  // v3: Save full FilterState
    };
    context.read<TaskProvider>().saveSearchState(state);
  }

  // v3 FIX (Gemini): Set loading synchronously if restoring with query
  void _restoreSearchState() {
    final state = context.read<TaskProvider>().getSearchState();
    if (state != null) {
      _searchController.text = state['query'] as String? ?? '';
      _scope = SearchScope.values[state['scope'] as int? ?? SearchScope.current.index];

      // v3: Restore full FilterState
      final filterJson = state['filterState'] as Map<String, dynamic>?;
      if (filterJson != null) {
        _tagFilters = FilterState.fromJson(filterJson);
        _loadTagsForFilter();  // v3: Pre-load tags
      }

      // v3 FIX (Gemini): Set loading synchronously before async search
      if (_searchController.text.isNotEmpty) {
        _isSearching = true;
        _performSearch();
      }
    }
  }
}
