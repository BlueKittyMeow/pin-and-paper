import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/tag.dart';
import '../providers/task_provider.dart';
import '../providers/tag_provider.dart';
import '../services/date_parsing_service.dart'; // Phase 3.7
import '../utils/date_suffix_parser.dart'; // Phase 3.7
import '../utils/date_formatter.dart'; // Phase 3.7
import 'task_context_menu.dart';
import 'tag_picker_dialog.dart';
import 'tag_chip.dart';
import 'edit_task_dialog.dart'; // Phase 3.6.5
import 'completed_task_metadata_dialog.dart'; // Phase 3.6.5 Day 5
import 'date_options_sheet.dart'; // Phase 3.7

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

  // Phase 3.6.5: Handle comprehensive task edit
  Future<void> _handleEdit(BuildContext context) async {
    // Show comprehensive edit dialog
    final result = await EditTaskDialog.show(
      context: context,
      task: task,
      currentTags: tags ?? [],
    );

    // User cancelled
    if (result == null || !context.mounted) return;

    try {
      final taskProvider = context.read<TaskProvider>();

      // 1. Update task basic fields (title, dueDate, isAllDay, notes, tags)
      await taskProvider.updateTask(
        taskId: task.id,
        title: result['title'] as String,
        dueDate: result['dueDate'] as DateTime?,
        isAllDay: (result['isAllDay'] as bool?) ?? true,
        notes: result['notes'] as String?,
        tagIds: (result['tagIds'] as List<String>?) ?? [],
      );

      // 2. Handle parent changes (Day 4: Uses validated changeTaskParent)
      final newParentId = result['parentId'] as String?;
      if (newParentId != task.parentId) {
        // Parent changed - use changeTaskParent which has cycle detection
        // Position 0 = start of children list for new parent
        await taskProvider.changeTaskParent(
          taskId: task.id,
          newParentId: newParentId,
          newPosition: 0, // Insert at top of new parent's children
        );
      }

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

  // Phase 3.6.5 Day 5: Handle completed task tap to show metadata
  Future<void> _handleCompletedTaskTap(BuildContext context) async {
    if (!task.completed) return; // Only for completed tasks

    final action = await CompletedTaskMetadataDialog.show(
      context: context,
      task: task,
      tags: tags ?? [],
      breadcrumb: breadcrumb,
    );

    if (action == null || !context.mounted) return;

    final taskProvider = context.read<TaskProvider>();

    switch (action) {
      case 'view_in_context':
        // Navigate to parent task (if exists) and highlight it
        // For root tasks, just navigate to self
        final targetId = task.parentId ?? task.id;
        await taskProvider.navigateToTask(targetId);
        break;

      case 'uncomplete':
        // Toggle completion (uses new position restore)
        await taskProvider.toggleTaskCompletion(task);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task "${task.title}" restored'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;

      case 'delete':
        // Show delete confirmation
        await _handleDelete(context);
        break;
    }
  }

  // Phase 3.7: Build title with colored date suffix (clickable)
  Widget _buildTitleWithDateSuffix(
    BuildContext context, {
    required bool isTrulyComplete,
    required bool isCompletedParent,
  }) {
    // Parse date suffix from title
    final suffixResult = DateSuffixParser.parse(task.title);

    // Base text style for title
    final baseTextStyle = TextStyle(
      decoration: isTrulyComplete ? TextDecoration.lineThrough : TextDecoration.none,
      color: task.completed
          ? Theme.of(context).colorScheme.onSurface.withValues(
              alpha: isCompletedParent ? 0.35 : 0.5,
            )
          : Theme.of(context).colorScheme.onSurface,
    );

    // No date suffix - render plain text
    if (suffixResult == null) {
      return Text(task.title, style: baseTextStyle);
    }

    // Date suffix colors: blue for future, red for overdue
    final suffixColor = suffixResult.isOverdue
        ? Colors.red.shade600
        : Colors.blue.shade600;
    final suffixBgColor = suffixResult.isOverdue
        ? Colors.red.shade50
        : Colors.blue.shade50;

    // Adjust opacity for completed tasks
    final suffixOpacity = task.completed
        ? (isCompletedParent ? 0.5 : 0.7)
        : 1.0;

    // Use Row with Text + tappable suffix chip
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Title prefix
        Flexible(
          child: Text(
            suffixResult.prefix,
            style: baseTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        // Tappable date suffix chip
        GestureDetector(
          onTap: task.completed ? null : () => _showDateOptionsForSuffix(context, suffixResult),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: suffixBgColor.withValues(alpha: suffixOpacity),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              suffixResult.suffix,
              style: baseTextStyle.copyWith(
                color: suffixColor.withValues(alpha: suffixOpacity),
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none, // Never strikethrough the date
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Phase 3.7: Show DateOptionsSheet for tapped suffix in task list
  void _showDateOptionsForSuffix(BuildContext context, DateSuffixResult suffixResult) {
    // Create ParsedDate from the suffix
    final parsedDate = ParsedDate(
      matchedText: suffixResult.suffix,
      matchedRange: TextRange(start: 0, end: suffixResult.suffix.length),
      date: suffixResult.date,
      isAllDay: !suffixResult.hasTime,
    );

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => DateOptionsSheet(
        parsedDate: parsedDate,
        onRemove: () async {
          Navigator.pop(sheetContext);
          // Update task: remove due date and suffix from title
          final taskProvider = context.read<TaskProvider>();
          final currentTagIds = (tags ?? []).map((t) => t.id).toList();
          await taskProvider.updateTask(
            taskId: task.id,
            title: suffixResult.prefix.trim(), // Title without suffix
            dueDate: null,
            isAllDay: true,
            tagIds: currentTagIds, // Preserve existing tags
          );
        },
        onSelectDate: (DateTime date, bool isAllDay) async {
          Navigator.pop(sheetContext);
          // Update task with new date and new suffix
          final newSuffix = DateFormatter.formatTitleSuffix(date, isAllDay: isAllDay);
          final newTitle = '${suffixResult.prefix.trim()} $newSuffix';
          final taskProvider = context.read<TaskProvider>();
          final currentTagIds = (tags ?? []).map((t) => t.id).toList();
          await taskProvider.updateTask(
            taskId: task.id,
            title: newTitle,
            dueDate: date,
            isAllDay: isAllDay,
            tagIds: currentTagIds, // Preserve existing tags
          );
        },
      ),
    );
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

        final taskContainer = AnimatedContainer(
          duration: Duration(milliseconds: 500), // Smooth fade animation
          curve: Curves.easeInOut,
          margin: EdgeInsets.only(
            left: leftMargin,
            right: 16,
            top: 4,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.amber.shade100 // Bright, visible highlight color
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: isHighlighted
                ? Border.all(
                    color: Colors.amber.shade700, // Darker amber border
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
      child: Builder(
        builder: (context) {
          // Phase 3.6.5: Get incomplete descendant info for completed parent detection
          final incompleteInfo = taskProvider.getIncompleteDescendantInfo(task.id);
          final isCompletedParent = task.completed && incompleteInfo != null;
          final isTrulyComplete = task.completed && incompleteInfo == null;

          return Column(
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
            title: _buildTitleWithDateSuffix(
              context,
              isTrulyComplete: isTrulyComplete,
              isCompletedParent: isCompletedParent,
            ),
            // Phase 3.2: Drag handle in reorder mode
            trailing: isReorderMode
                ? const Icon(Icons.drag_handle, color: Colors.grey)
                : null,
          ),

          // Phase 3.5: Display tags (only when tags exist)
          // Fix #C2: Show tags in reorder mode
          // UX Decision: No "+ Add Tag" chip - use context menu only
          // Phase 3.6.5: Dim tags for completed tasks
          if (tags != null && tags!.isNotEmpty)
            Opacity(
              opacity: task.completed ? (isCompletedParent ? 0.4 : 0.6) : 1.0,
              child: Padding(
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
            ),

          // Phase 3.6.5: Depth indicator for completed parents with incomplete descendants
          if (isCompletedParent)
            Padding(
              padding: const EdgeInsets.only(left: 60, right: 12, bottom: 8),
              child: Text(
                incompleteInfo!.displayText,  // "> 3 incomplete" or ">> 5 incomplete"
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      );
        },
      ),
    );

        // Only enable context menu (long-press/right-click) when NOT in reorder mode
        // In reorder mode, TreeDraggable handles the long-press for dragging
        if (isReorderMode) {
          return taskContainer;
        }

        return GestureDetector(
          // Phase 3.6.5: Tap on completed tasks shows metadata dialog
          onTap: task.completed ? () => _handleCompletedTaskTap(context) : null,
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
