import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../models/filter_state.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';

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
  String _searchQuery = '';

  // FIX #2 (Codex v2): Preload tag counts instead of N×FutureBuilder
  Map<String, int> _tagCounts = {};
  bool _countsLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set.from(widget.initialFilter.selectedTagIds);
    _logic = widget.initialFilter.logic;
    _presenceFilter = widget.initialFilter.presenceFilter;

    // FIX #2: Load all tag counts in one query
    _loadTagCounts();
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

  // Filter displayed tags based on search query
  List<Tag> get _displayedTags {
    if (_searchQuery.isEmpty) return widget.allTags;

    final query = _searchQuery.toLowerCase();
    return widget.allTags
        .where((tag) => tag.name.toLowerCase().contains(query))
        .toList();
  }

  // Check if specific tag selection should be disabled
  bool get _tagSelectionDisabled {
    return _presenceFilter == TagPresenceFilter.onlyUntagged;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search tags',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Tag presence filter (segmented buttons)
            SegmentedButton<TagPresenceFilter>(
              segments: const [
                ButtonSegment(
                  value: TagPresenceFilter.any,
                  label: Text('Any'),
                ),
                ButtonSegment(
                  value: TagPresenceFilter.onlyTagged,
                  label: Text('Tagged'),
                ),
                ButtonSegment(
                  value: TagPresenceFilter.onlyUntagged,
                  label: Text('Untagged'),
                ),
              ],
              selected: {_presenceFilter},
              onSelectionChanged: (Set<TagPresenceFilter> selected) {
                setState(() {
                  _presenceFilter = selected.first;
                  // If "untagged" selected, clear specific tag selections
                  if (_presenceFilter == TagPresenceFilter.onlyUntagged) {
                    _selectedTagIds.clear();
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
                },
              ),
            const SizedBox(height: 16),

            // Tag list (scrollable)
            // M5: Show empty state when no tags exist or search returns nothing
            Expanded(
              child: _displayedTags.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _displayedTags.length,
                      itemBuilder: (context, index) {
                        final tag = _displayedTags[index];
                        final isChecked = _selectedTagIds.contains(tag.id);

                        // Parse hex color string to int (default to grey if null/invalid)
                        final colorInt = _parseHexColor(tag.color) ?? 0xFF9E9E9E;

                        return CheckboxListTile(
                          enabled: !_tagSelectionDisabled,
                          value: isChecked,
                          title: Text(tag.name),
                          // FIX #2: Direct access to preloaded counts (no FutureBuilder!)
                          subtitle: _countsLoading
                              ? const Text('...')
                              : Text('${_tagCounts[tag.id] ?? 0} tasks'),
                          secondary: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(colorInt),
                              shape: BoxShape.circle,
                            ),
                          ),
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
                                },
                        );
                      },
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
            FilledButton(
              onPressed: () {
                // UX POLISH: Medium haptic feedback for major action
                HapticFeedback.mediumImpact();

                final filter = FilterState(
                  selectedTagIds: _selectedTagIds.toList(),
                  logic: _logic,
                  presenceFilter: _presenceFilter,
                );
                Navigator.pop(context, filter);
              },
              child: const Text('Apply'),
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
