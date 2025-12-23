import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskItem extends StatelessWidget {
  final Task task;

  // Phase 3.2: Hierarchy parameters (optional for backward compatibility)
  final int? depth;
  final bool? hasChildren;
  final bool? isExpanded;
  final VoidCallback? onToggleCollapse;
  final bool isReorderMode;

  const TaskItem({
    super.key,
    required this.task,
    this.depth,
    this.hasChildren,
    this.isExpanded,
    this.onToggleCollapse,
    this.isReorderMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Phase 3.2: Calculate indentation based on depth
    final effectiveDepth = depth ?? task.depth;
    final leftMargin = 16.0 + (effectiveDepth * 24.0); // 24px per level

    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
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
    );
  }
}
