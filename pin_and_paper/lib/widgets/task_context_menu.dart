import 'package:flutter/material.dart';
import '../models/task.dart';

/// Context menu that appears on long-press of a task
/// Phase 3.2: Initial implementation with delete action
class TaskContextMenu extends StatelessWidget {
  final Task task;
  final VoidCallback? onDelete;

  const TaskContextMenu({
    super.key,
    required this.task,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delete option
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Task',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show context menu at a specific position
  static Future<void> show({
    required BuildContext context,
    required Task task,
    required Offset position,
    VoidCallback? onDelete,
  }) async {
    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: TaskContextMenu(
            task: task,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

/// Delete confirmation dialog with CASCADE warning
class DeleteTaskDialog extends StatelessWidget {
  final Task task;
  final int childCount;

  const DeleteTaskDialog({
    super.key,
    required this.task,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasChildren = childCount > 0;

    return AlertDialog(
      title: const Text('Delete Task?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete:'),
          const SizedBox(height: 8),
          Text(
            '"${task.title}"',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (hasChildren) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will also delete $childCount subtask${childCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  /// Show delete confirmation dialog
  /// Returns true if user confirmed, false if cancelled
  static Future<bool> show({
    required BuildContext context,
    required Task task,
    required int childCount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteTaskDialog(
        task: task,
        childCount: childCount,
      ),
    );
    return result ?? false;
  }
}
