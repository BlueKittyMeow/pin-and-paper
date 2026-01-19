import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/tag.dart';
import '../providers/task_provider.dart';
import '../providers/tag_provider.dart';
import 'task_context_menu.dart';
import 'tag_picker_dialog.dart';
import 'tag_chip.dart';

class TaskItem extends StatelessWidget {
  final Task task;

  // Phase 3.2: Hierarchy parameters (optional for backward compatibility)
  final int? depth;
  final bool? hasChildren;
  final bool? isExpanded;
  final VoidCallback? onToggleCollapse;
  final bool isReorderMode;
  final String? breadcrumb; // Phase 3.2: Optional breadcrumb for completed tasks
  final List<Tag>? tags; // Phase 3.5: Task tags

  const TaskItem({
    super.key,
    required this.task,
    this.depth,
    this.hasChildren,
    this.isExpanded,
    this.onToggleCollapse,
    this.isReorderMode = false,
    this.breadcrumb,
    this.tags, // Phase 3.5
  });

  // Phase 3.2: Handle task deletion with confirmation
  Future<void> _handleDelete(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();

    // Show confirmation dialog (callback expects childCount parameter)
    final deleted = await taskProvider.deleteTaskWithConfirmation(
      task.id,
      (childCount) => DeleteTaskDialog.show(
        context: context,
        task: task,
        childCount: childCount,
      ),
    );

    // Show feedback if deleted
    if (deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${task.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Phase 3.4: Handle task edit
  Future<void> _handleEdit(BuildContext context) async {
    final controller = TextEditingController(text: task.title);

    // Select all text for easy replacement
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Task title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Service layer handles validation and trimming (Gemini feedback)
    if (result != null && context.mounted) {
      try {
        await context.read<TaskProvider>().updateTaskTitle(task.id, result);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task updated'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update task: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }

    // Delayed disposal is required due to complex timing:
    // 1. Dialog closes (animation starts)
    // 2. updateTaskTitle() calls _categorizeTasks() + _refreshTreeController() + notifyListeners()
    // 3. These trigger rebuilds while dialog is still animating
    // 4. TextField tries to access controller during rebuild → crash
    // Both try/finally and addPostFrameCallback dispose too early (tested & confirmed)
    // The 300ms delay ensures dialog animation + all rebuilds complete before disposal
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });
  }

  // Phase 3.5: Handle tag management
  Future<void> _handleManageTags(BuildContext context) async {
    final tagProvider = context.read<TagProvider>();

    // Show tag picker dialog
    final selectedTagIds = await TagPickerDialog.show(
      context: context,
      taskId: task.id,
      currentTags: tags ?? [],
    );

    // User cancelled
    if (selectedTagIds == null || !context.mounted) return;

    // Codex review: Check return values to detect silent failures
    bool allSucceeded = true;
    String? failureReason;

    try {
      // Get current tag IDs
      final currentTagIds = (tags ?? []).map((t) => t.id).toSet();
      final newTagIds = selectedTagIds.toSet();

      // Add new tags
      for (final tagId in newTagIds.difference(currentTagIds)) {
        final success = await tagProvider.addTagToTask(task.id, tagId);
        if (!success) {
          allSucceeded = false;
          failureReason = tagProvider.errorMessage ?? 'Failed to add tag';
          break;
        }
      }

      // Remove removed tags (only if adds succeeded)
      if (allSucceeded) {
        for (final tagId in currentTagIds.difference(newTagIds)) {
          final success = await tagProvider.removeTagFromTask(task.id, tagId);
          if (!success) {
            allSucceeded = false;
            failureReason = tagProvider.errorMessage ?? 'Failed to remove tag';
            break;
          }
        }
      }

      // Only reload and show success if all operations succeeded
      if (allSucceeded && context.mounted) {
        // Codex review: Use refreshTags() to avoid tree collapse
        await context.read<TaskProvider>().refreshTags();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tags updated'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else if (!allSucceeded && context.mounted) {
        // Show specific failure message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureReason ?? 'Failed to update tags'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update tags: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 3.2: Calculate indentation based on depth
    final effectiveDepth = depth ?? task.depth;
    final leftMargin = 16.0 + (effectiveDepth * 24.0); // 24px per level

    // Phase 3.6B: Check if task is highlighted (for search navigation)
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final isHighlighted = taskProvider.isTaskHighlighted(task.id);

        final taskContainer = Container(
          margin: EdgeInsets.only(
            left: leftMargin,
            right: 16,
            top: 4,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: isHighlighted
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase 3.2: Show breadcrumb if provided
          if (breadcrumb != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      breadcrumb!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: breadcrumb != null ? 0 : 4,
              bottom: 4,
            ),
            // Phase 3.2: Expand/collapse button for tasks with children
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasChildren == true)
                  IconButton(
                    icon: Icon(
                      isExpanded == true
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                    ),
                    onPressed: onToggleCollapse,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  )
                else
                  const SizedBox(width: 24), // Spacer for alignment
                Checkbox(
                  value: task.completed,
                  onChanged: (_) {
                    context.read<TaskProvider>().toggleTaskCompletion(task);
                  },
                ),
              ],
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.completed
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: task.completed
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            // Phase 3.2: Drag handle in reorder mode
            trailing: isReorderMode
                ? const Icon(Icons.drag_handle, color: Colors.grey)
                : null,
          ),

          // Phase 3.5: Display tags (only when tags exist)
          // Fix #C2: Show tags in reorder mode
          // UX Decision: No "+ Add Tag" chip - use context menu only
          if (tags != null && tags!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: 60, // Align with title (24px collapse + 24px checkbox + 12px padding)
                right: 12,
                bottom: 8,
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Show first 3 tags
                  ...tags!.take(3).map((tag) {
                    return CompactTagChip(tag: tag);
                  }),
                  // Show "+N more" chip if there are more than 3 tags
                  if (tags!.length > 3)
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '+${tags!.length - 3} more',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

        // Only enable context menu (long-press/right-click) when NOT in reorder mode
        // In reorder mode, TreeDraggable handles the long-press for dragging
        if (isReorderMode) {
          return taskContainer;
        }

        return GestureDetector(
          // Phase 3.2: Long-press (mobile) and right-click (desktop) to show context menu
          onLongPressStart: (details) {
            TaskContextMenu.show(
              context: context,
              task: task,
              position: details.globalPosition,
              onDelete: () => _handleDelete(context),
              onEdit: () => _handleEdit(context), // Phase 3.4
              onManageTags: () => _handleManageTags(context), // Phase 3.5
            );
          },
          // Add right-click support for desktop (Linux, Windows, macOS)
          onSecondaryTapDown: (details) {
            TaskContextMenu.show(
              context: context,
              task: task,
              position: details.globalPosition,
              onDelete: () => _handleDelete(context),
              onEdit: () => _handleEdit(context),
              onManageTags: () => _handleManageTags(context),
            );
          },
          child: taskContainer,
        );
      },
    );
  }
}
