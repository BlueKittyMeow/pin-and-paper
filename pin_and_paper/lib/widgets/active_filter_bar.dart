import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../models/filter_state.dart';
import '../models/tag.dart';

/// Phase 3.6A: Compact filter bar showing active filters with tag chips.
///
/// Features:
/// - Scrollable tag chips (horizontally)
/// - Presence filter indicator ("Has tags" / "No tags")
/// - Logic indicator ("ALL" / "ANY") when multiple tags selected
/// - Pinned "Clear All" button (doesn't scroll off screen)
/// - Hides automatically when no filters active
/// - Ghost tag handling: Hides deleted tags gracefully (self-healing UI)
/// - Haptic feedback for Clear All (UX polish)
///
/// L2 (v3.1): Optimized ghost tag filtering - O(n+m) using Set lookup
class ActiveFilterBar extends StatelessWidget {
  final FilterState filterState;
  final List<Tag> allTags;
  final VoidCallback onClearAll;
  final void Function(String tagId) onRemoveTag;

  const ActiveFilterBar({
    super.key,
    required this.filterState,
    required this.allTags,
    required this.onClearAll,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    if (!filterState.isActive) {
      return const SizedBox.shrink(); // Hide when no filters
    }

    // UX POLISH: Filter out ghost tags (deleted tags that are still in filter state)
    // Instead of showing "Unknown", we hide them gracefully (self-healing UI)
    // L2: Optimization - use Set for O(n+m) instead of O(n*m)
    final allTagIds = allTags.map((t) => t.id).toSet(); // O(m)
    final validTagIds = filterState.selectedTagIds
        .where((id) => allTagIds.contains(id)) // O(n) with Set lookup
        .toList();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Scrollable tag chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Tag chips (only valid tags)
                  for (final tagId in validTagIds) ...[
                    _buildTagChip(context, tagId),
                    const SizedBox(width: 8),
                  ],

                  // Presence filter indicator
                  if (filterState.presenceFilter != TagPresenceFilter.any) ...[
                    _buildPresenceChip(context),
                    const SizedBox(width: 8),
                  ],

                  // Logic indicator (if multiple tags)
                  if (filterState.selectedTagIds.length > 1) ...[
                    _buildLogicIndicator(context),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),

          // Pinned "Clear All" button (doesn't scroll)
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              // UX POLISH: Medium haptic feedback for major action
              HapticFeedback.mediumImpact();
              onClearAll();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String tagId) {
    // Safe to use firstWhere without orElse since we filtered validTagIds above
    final tag = allTags.firstWhere((t) => t.id == tagId);

    return Chip(
      label: Text(tag.name),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: () => onRemoveTag(tagId),
      backgroundColor: Color(tag.color).withOpacity(0.2),
      side: BorderSide(color: Color(tag.color)),
    );
  }

  Widget _buildPresenceChip(BuildContext context) {
    final label = filterState.presenceFilter == TagPresenceFilter.onlyTagged
        ? 'Has tags'
        : 'No tags';

    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  Widget _buildLogicIndicator(BuildContext context) {
    final label = filterState.logic == FilterLogic.and ? 'ALL' : 'ANY';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
