import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import 'task_context_menu.dart';

class TaskItem extends StatelessWidget {
  final Task task;

  // Phase 3.2: Hierarchy parameters (optional for backward compatibility)
  final int? depth;
  final bool? hasChildren;
  final bool? isExpanded;
  final VoidCallback? onToggleCollapse;
  final bool isReorderMode;
  final String? breadcrumb; // Phase 3.2: Optional breadcrumb for completed tasks

  const TaskItem({
    super.key,
    required this.task,
    this.depth,
    this.hasChildren,
    this.isExpanded,
    this.onToggleCollapse,
    this.isReorderMode = false,
    this.breadcrumb,
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

    // Dispose controller after update completes and dialog animation finishes
    // (avoids "controller used after dispose" error during rebuild)
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phase 3.2: Calculate indentation based on depth
    final effectiveDepth = depth ?? task.depth;
    final leftMargin = 16.0 + (effectiveDepth * 24.0); // 24px per level

    final taskContainer = Container(
      margin: EdgeInsets.only(
        left: leftMargin,
        right: 16,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
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
              child: Text(
                breadcrumb!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
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
        ],
      ),
    );

    // Only enable context menu (long-press) when NOT in reorder mode
    // In reorder mode, TreeDraggable handles the long-press for dragging
    if (isReorderMode) {
      return taskContainer;
    }

    return GestureDetector(
      // Phase 3.2: Long-press to show context menu (disabled in reorder mode)
      onLongPressStart: (details) {
        TaskContextMenu.show(
          context: context,
          task: task,
          position: details.globalPosition,
          onDelete: () => _handleDelete(context),
          onEdit: () => _handleEdit(context), // Phase 3.4
        );
      },
      child: taskContainer,
    );
  }
}
