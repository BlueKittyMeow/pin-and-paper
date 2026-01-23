import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../models/filter_state.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';
import '../services/task_service.dart'; // UX7: For result count preview

/// Phase 3.6A: Dialog for advanced tag filtering with multi-select and logic options.
///
/// Features:
/// - Multi-select tag checkboxes
/// - Search field (preserves selection state across search changes)
/// - AND/OR logic toggle
/// - Tag presence radio buttons (mutually exclusive)
/// - Task count per tag (preloaded with single query - M3)
/// - Haptic feedback for interactions (UX polish)
/// - Empty state when no tags exist or search returns nothing (M5)
///
/// FIX #2 (Codex v2): Preloads all tag counts in one query instead of N×FutureBuilder
/// FIX #3 (Codex v2): "Tagged" option can show tasks with ANY tag (useful!)
/// M3 (v3.1): Accepts showCompletedCounts parameter for correct counts
/// M4 (v3.1): Includes "Clear All" button for easy reset
/// L5 (v3.1): TagService injected as constructor parameter (cleaner than context.read)
class TagFilterDialog extends StatefulWidget {
  final FilterState initialFilter;
  final List<Tag> allTags;
  final bool showCompletedCounts; // M3: Which counts to show
  final TagService tagService; // L5: Injected service

  const TagFilterDialog({
    super.key,
    required this.initialFilter,
    required this.allTags,
    required this.showCompletedCounts, // M3
    required this.tagService, // L5
  });

  @override
  State<TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends State<TagFilterDialog> {
  late Set<String> _selectedTagIds; // Preserved across search changes
  late FilterLogic _logic;
  late TagPresenceFilter _presenceFilter;
  late DateFilter _dateFilter; // Phase 3.7.5
  String _searchQuery = '';
  Set<String> _savedSelections = {}; // UX7: Remember selections when switching to Untagged
  final TextEditingController _searchController = TextEditingController(); // UX1: For clear button
  final FocusNode _searchFocusNode = FocusNode(); // Phase 3.6B: For Enter key detection

  // FIX #2 (Codex v2): Preload tag counts instead of N×FutureBuilder
  Map<String, int> _tagCounts = {};
  bool _countsLoading = true;

  // UX7: Result count preview
  int? _resultCount;
  bool _countLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set.from(widget.initialFilter.selectedTagIds);
    _logic = widget.initialFilter.logic;
    _presenceFilter = widget.initialFilter.presenceFilter;
    _dateFilter = widget.initialFilter.dateFilter; // Phase 3.7.5

    // FIX #2: Load all tag counts in one query
    _loadTagCounts();

    // UX7: Load initial result count if filter is active
    if (widget.initialFilter.isActive) {
      _updateResultCount();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // Phase 3.6B
    super.dispose();
  }

  Future<void> _loadTagCounts() async {
    try {
      // L5: Use injected service instead of context.read (cleaner architecture)
      // M3: Use widget parameter to show correct counts (active vs completed)
      final counts = await widget.tagService.getTaskCountsByTag(
        completed: widget.showCompletedCounts,
      );

      if (mounted) {
        setState(() {
          _tagCounts = counts;
          _countsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tag counts: $e');
      if (mounted) {
        setState(() {
          _countsLoading = false;
        });
      }
    }
  }

  /// UX7: Update result count preview based on current filter selections
  Future<void> _updateResultCount() async {
    // Only show count for specific tag selections (not for "Any" or "Untagged")
    if (_selectedTagIds.isEmpty) {
      setState(() {
        _resultCount = null;
        _countLoading = false;
      });
      return;
    }

    setState(() {
      _countLoading = true;
    });

    try {
      final filter = FilterState(
        selectedTagIds: _selectedTagIds.toList(),
        logic: _logic,
        presenceFilter: _presenceFilter,
        dateFilter: _dateFilter,
      );

      final taskService = TaskService();
      final count = await taskService.countFilteredTasks(
        filter,
        completed: widget.showCompletedCounts,
      );

      if (mounted) {
        setState(() {
          _resultCount = count;
          _countLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error counting filtered tasks: $e');
      if (mounted) {
        setState(() {
          _resultCount = null;
          _countLoading = false;
        });
      }
    }
  }

  // Filter displayed tags based on search query
  // UX6: Sort by usage count (most used first)
  List<Tag> get _displayedTags {
    List<Tag> filtered;
    if (_searchQuery.isEmpty) {
      filtered = widget.allTags;
    } else {
      final query = _searchQuery.toLowerCase();
      filtered = widget.allTags
          .where((tag) => tag.name.toLowerCase().contains(query))
          .toList();
    }

    // Sort by usage count (descending), then alphabetically
    filtered.sort((a, b) {
      final countA = _tagCounts[a.id] ?? 0;
      final countB = _tagCounts[b.id] ?? 0;
      if (countA != countB) {
        return countB.compareTo(countA); // Higher counts first
      }
      return a.name.compareTo(b.name); // Alphabetically as tiebreaker
    });

    return filtered;
  }

  // Check if specific tag selection should be disabled
  bool get _tagSelectionDisabled {
    return _presenceFilter == TagPresenceFilter.onlyUntagged;
  }

  // Phase 3.6B: Apply filter and close dialog (same as Apply button)
  void _applyFilter() {
    // Gemini suggestion: Guard clause to prevent double-triggering
    // Only apply if search field is NOT focused (TextField.onSubmitted handles it when focused)
    if (_searchFocusNode.hasFocus) {
      return;
    }

    HapticFeedback.mediumImpact();
    final filter = FilterState(
      selectedTagIds: _selectedTagIds.toList(),
      logic: _logic,
      presenceFilter: _presenceFilter,
      dateFilter: _dateFilter,
    );
    Navigator.pop(context, filter);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phase 3.7.5: Due date filter section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Due Date',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DateFilter>(
              segments: const [
                ButtonSegment(
                  value: DateFilter.any,
                  label: Text('Any'),
                ),
                ButtonSegment(
                  value: DateFilter.overdue,
                  label: Text('Overdue'),
                ),
                ButtonSegment(
                  value: DateFilter.noDueDate,
                  label: Text('No Date'),
                ),
              ],
              selected: {_dateFilter},
              onSelectionChanged: (Set<DateFilter> selected) {
                setState(() {
                  _dateFilter = selected.first;
                });
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Tag filter section header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tags',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Search field
            // UX1: Clear button for search
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode, // Phase 3.6B: For Enter key detection
              decoration: InputDecoration(
                labelText: 'Search tags',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Tag presence filter (segmented buttons)
            // UX2: Tooltips for each option
            SegmentedButton<TagPresenceFilter>(
              segments: const [
                ButtonSegment(
                  value: TagPresenceFilter.any,
                  label: Text('Any'),
                  tooltip: 'Show all tasks (no tag filter)',
                ),
                ButtonSegment(
                  value: TagPresenceFilter.onlyTagged,
                  label: Text('Tagged'),
                  tooltip: 'Show tasks that have at least one tag',
                ),
                ButtonSegment(
                  value: TagPresenceFilter.onlyUntagged,
                  label: Text('Untagged'),
                  tooltip: 'Show only tasks with no tags',
                ),
              ],
              selected: {_presenceFilter},
              onSelectionChanged: (Set<TagPresenceFilter> selected) {
                setState(() {
                  final oldFilter = _presenceFilter;
                  _presenceFilter = selected.first;

                  // UX7: Save selections when switching TO untagged
                  if (_presenceFilter == TagPresenceFilter.onlyUntagged) {
                    _savedSelections = Set.from(_selectedTagIds);
                    _selectedTagIds.clear();
                  }

                  // UX7: Restore selections when switching FROM untagged
                  if (oldFilter == TagPresenceFilter.onlyUntagged &&
                      _presenceFilter != TagPresenceFilter.onlyUntagged &&
                      _savedSelections.isNotEmpty) {
                    _selectedTagIds = Set.from(_savedSelections);
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // AND/OR logic toggle (only show when multiple tags selected)
            if (_selectedTagIds.length > 1)
              SegmentedButton<FilterLogic>(
                segments: const [
                  ButtonSegment(
                    value: FilterLogic.or,
                    label: Text('ANY'),
                    tooltip: 'Show tasks with ANY selected tag',
                  ),
                  ButtonSegment(
                    value: FilterLogic.and,
                    label: Text('ALL'),
                    tooltip: 'Show tasks with ALL selected tags',
                  ),
                ],
                selected: {_logic},
                onSelectionChanged: (Set<FilterLogic> selected) {
                  setState(() {
                    _logic = selected.first;
                  });
                  // UX7: Update result count when logic changes
                  _updateResultCount();
                },
              ),
            const SizedBox(height: 16),

            // Tag list (scrollable)
            // M5: Show empty state when no tags exist or search returns nothing
            // UX3: Scroll indicator with fade effect
            Expanded(
              child: _displayedTags.isEmpty
                  ? _buildEmptyState()
                  : ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Colors.transparent,
                            Colors.black,
                          ],
                          stops: const [0.7, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstOut,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _displayedTags.length,
                        itemBuilder: (context, index) {
                        final tag = _displayedTags[index];
                        final isChecked = _selectedTagIds.contains(tag.id);

                        // Parse hex color string to int (default to grey if null/invalid)
                        final colorInt = _parseHexColor(tag.color) ?? 0xFF9E9E9E;

                        return ListTile(
                          enabled: !_tagSelectionDisabled,
                          title: Text(tag.name),
                          // FIX #2: Direct access to preloaded counts (no FutureBuilder!)
                          subtitle: _countsLoading
                              ? const Text('...')
                              : Text('${_tagCounts[tag.id] ?? 0} tasks'),
                          leading: Opacity(
                            opacity: _tagSelectionDisabled ? 0.3 : 1.0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(colorInt),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          trailing: Opacity(
                            opacity: _tagSelectionDisabled ? 0.38 : 1.0,
                            child: Checkbox(
                              value: isChecked,
                              onChanged: _tagSelectionDisabled
                                  ? null
                                  : (bool? value) {
                                      // UX POLISH: Light haptic feedback for checkbox toggle
                                      HapticFeedback.lightImpact();

                                      setState(() {
                                        if (value == true) {
                                          _selectedTagIds.add(tag.id);
                                        } else {
                                          _selectedTagIds.remove(tag.id);
                                        }
                                      });

                                      // UX7: Update result count when selections change
                                      _updateResultCount();
                                    },
                            ),
                          ),
                          // UX5: Visual bounding box for selected tags
                          tileColor: isChecked
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3)
                              : null,
                          shape: isChecked
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                )
                              : null,
                          onTap: _tagSelectionDisabled
                              ? null
                              : () {
                                  // UX POLISH: Light haptic feedback for checkbox toggle
                                  HapticFeedback.lightImpact();

                                  setState(() {
                                    if (isChecked) {
                                      _selectedTagIds.remove(tag.id);
                                    } else {
                                      _selectedTagIds.add(tag.id);
                                    }
                                  });

                                  // UX7: Update result count when selections change
                                  _updateResultCount();
                                },
                        );
                      },
                    ),
                  ),
            ),

            // UX7: Result count preview (only show when tags are selected)
            if (_selectedTagIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _countLoading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _resultCount == null
                                  ? 'Counting...'
                                  : '$_resultCount ${_resultCount == 1 ? 'task' : 'tasks'} match',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
              ),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        // M4: Clear All button on the left side
        Row(
          children: [
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, FilterState.empty);
              },
              child: const Text('Clear All'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            // Phase 3.6B: Gemini solution - CallbackShortcuts on Apply button itself
            CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): _applyFilter,
                const SingleActivator(LogicalKeyboardKey.numpadEnter): _applyFilter,
              },
              child: Focus(
                child: FilledButton(
                  autofocus: true, // Get focus when search field unfocused
                  onPressed: _applyFilter,
                  child: const Text('Apply'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Parse hex color string (#RRGGBB) to int
  int? _parseHexColor(String? hexColor) {
    if (hexColor == null) return null;
    try {
      return int.parse(hexColor.replaceFirst('#', '0xFF'));
    } catch (e) {
      return null;
    }
  }

  // M5: Helper method for empty state
  Widget _buildEmptyState() {
    final noTagsAtAll = widget.allTags.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noTagsAtAll ? Icons.label_off : Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              noTagsAtAll
                  ? 'No tags yet'
                  : 'No tags match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (noTagsAtAll) ...[
              const SizedBox(height: 8),
              Text(
                'Create tags in Tag Management',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
