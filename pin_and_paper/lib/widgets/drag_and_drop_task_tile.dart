import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';
import '../models/tag.dart'; // Phase 3.5
import 'task_item.dart';

/// Extension to detect drop position (above/inside/below) based on pointer offset
/// Reference: flutter_fancy_tree_view2 example
extension TaskDropPosition on TreeDragAndDropDetails<Task> {
  /// Splits the target node's height in three (30/40/30) and checks the vertical offset
  /// of the dragging node, applying the appropriate callback.
  T mapDropPosition<T>({
    required T Function() whenAbove,
    required T Function() whenInside,
    required T Function() whenBelow,
  }) {
    final double oneThirdOfTotalHeight = targetBounds.height * 0.3;
    final double pointerVerticalOffset = dropPosition.dy;

    if (pointerVerticalOffset < oneThirdOfTotalHeight) {
      return whenAbove(); // Top 30%
    } else if (pointerVerticalOffset < oneThirdOfTotalHeight * 2.33) {
      return whenInside(); // Middle 40%
    } else {
      return whenBelow(); // Bottom 30%
    }
  }
}

/// Draggable task tile for reordering in tree view
/// Phase 3.2: Implements drag-and-drop with visual feedback
/// Phase 3.5: Added tags parameter
class DragAndDropTaskTile extends StatelessWidget {
  final TreeEntry<Task> entry;
  final TreeDragTargetNodeAccepted<Task> onNodeAccepted;
  final VoidCallback? onToggleCollapse;
  final Duration? longPressDelay;
  final List<Tag>? tags; // Phase 3.5

  const DragAndDropTaskTile({
    super.key,
    required this.entry,
    required this.onNodeAccepted,
    this.onToggleCollapse,
    this.longPressDelay,
    this.tags, // Phase 3.5
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderSide = BorderSide(
      color: colorScheme.primary,
      width: 2.0,
    );

    return TreeDragTarget<Task>(
      node: entry.node,
      onNodeAccepted: onNodeAccepted,
      builder: (BuildContext context, TreeDragAndDropDetails<Task>? details) {
        Decoration? decoration;

        if (details != null) {
          // Add visual feedback border to indicate drop position
          decoration = BoxDecoration(
            border: details.mapDropPosition(
              whenAbove: () => Border(top: borderSide),
              whenInside: () => Border.fromBorderSide(borderSide),
              whenBelow: () => Border(bottom: borderSide),
            ),
          );
        }

        return TreeDraggable<Task>(
          node: entry.node,
          longPressDelay: longPressDelay,

          // Show semi-transparent version when dragging
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: IgnorePointer(
              child: TaskItem(
                task: entry.node,
                depth: entry.level, // Phase 3.6A: Use visible tree depth
                hasChildren: entry.hasChildren,
                isExpanded: entry.isExpanded,
                onToggleCollapse: onToggleCollapse,
                isReorderMode: true,
                tags: tags, // Phase 3.5
              ),
            ),
          ),

          // Feedback widget shown under pointer while dragging
          feedback: IntrinsicWidth(
            child: Material(
              elevation: 6.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 200,
                  maxWidth: 400,
                ),
                child: TaskItem(
                  task: entry.node,
                  depth: 0, // No indentation in feedback
                  hasChildren: entry.hasChildren,
                  isExpanded: entry.isExpanded,
                  isReorderMode: true,
                  tags: tags, // Phase 3.5
                ),
              ),
            ),
          ),

          // Actual child widget with drop position indicator
          child: DecoratedBox(
            decoration: decoration ?? const BoxDecoration(),
            child: TaskItem(
              task: entry.node,
              depth: entry.level, // Phase 3.6A: Use visible tree depth
              hasChildren: entry.hasChildren,
              isExpanded: entry.isExpanded,
              onToggleCollapse: onToggleCollapse,
              isReorderMode: true,
              tags: tags, // Phase 3.5
            ),
          ),
        );
      },
    );
  }
}
