import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/tag.dart';
import 'tag_chip.dart';

/// Phase 3.6.5: Read-only metadata view for completed tasks
///
/// Displays:
/// - Title
/// - Status (completed)
/// - Hierarchy breadcrumb
/// - Created/Completed timestamps
/// - Duration calculation
/// - Tags
/// - Notes
///
/// Actions:
/// - View in Context: Navigate to task location in hierarchy
/// - Uncomplete: Restore task to active state (with position restore)
/// - Delete Permanently: Soft delete task
class CompletedTaskMetadataDialog extends StatelessWidget {
  final Task task;
  final List<Tag> tags;
  final String? breadcrumb;

  const CompletedTaskMetadataDialog({
    super.key,
    required this.task,
    required this.tags,
    this.breadcrumb,
  });

  /// Show the metadata dialog
  static Future<String?> show({
    required BuildContext context,
    required Task task,
    required List<Tag> tags,
    String? breadcrumb,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => CompletedTaskMetadataDialog(
        task: task,
        tags: tags,
        breadcrumb: breadcrumb,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      if (hours > 0) {
        return '$days day${days != 1 ? 's' : ''} $hours hour${hours != 1 ? 's' : ''}';
      }
      return '$days day${days != 1 ? 's' : ''}';
    } else if (hours > 0) {
      if (minutes > 0) {
        return '$hours hour${hours != 1 ? 's' : ''} $minutes min${minutes != 1 ? 's' : ''}';
      }
      return '$hours hour${hours != 1 ? 's' : ''}';
    } else if (minutes > 0) {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    }
    return 'Less than a minute';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Calculate duration
    final duration = task.completedAt != null
        ? task.completedAt!.difference(task.createdAt)
        : Duration.zero;

    return AlertDialog(
      title: const Text('Task Details'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== TITLE =====
              _buildSection(
                context,
                icon: Icons.task_alt,
                label: 'Title',
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Divider(height: 24),

              // ===== STATUS =====
              _buildSection(
                context,
                icon: Icons.check_circle,
                iconColor: Colors.green,
                label: 'Status',
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text(
                      'Completed',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),

              // ===== HIERARCHY =====
              if (breadcrumb != null && breadcrumb!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSection(
                  context,
                  icon: Icons.account_tree,
                  label: 'Hierarchy',
                  child: Text(
                    breadcrumb!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],

              const Divider(height: 24),

              // ===== TIMESTAMPS =====
              _buildSection(
                context,
                icon: Icons.calendar_today,
                label: 'Created',
                child: Text(
                  '${dateFormat.format(task.createdAt)} at ${timeFormat.format(task.createdAt)}',
                ),
              ),

              const SizedBox(height: 12),

              if (task.completedAt != null)
                _buildSection(
                  context,
                  icon: Icons.event_available,
                  label: 'Completed',
                  child: Text(
                    '${dateFormat.format(task.completedAt!)} at ${timeFormat.format(task.completedAt!)}',
                  ),
                ),

              const SizedBox(height: 12),

              // ===== DURATION =====
              _buildSection(
                context,
                icon: Icons.timer,
                label: 'Duration',
                child: Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

              // ===== TAGS =====
              if (tags.isNotEmpty) ...[
                const Divider(height: 24),
                _buildSection(
                  context,
                  icon: Icons.label,
                  label: 'Tags',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags
                        .map((tag) => CompactTagChip(tag: tag))
                        .toList(),
                  ),
                ),
              ],

              // ===== NOTES =====
              if (task.notes != null && task.notes!.isNotEmpty) ...[
                const Divider(height: 24),
                _buildSection(
                  context,
                  icon: Icons.notes,
                  label: 'Notes',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // ===== VIEW IN CONTEXT =====
        TextButton.icon(
          onPressed: () => Navigator.pop(context, 'view_in_context'),
          icon: const Icon(Icons.visibility),
          label: const Text('View in Context'),
        ),

        // ===== UNCOMPLETE =====
        TextButton.icon(
          onPressed: () => Navigator.pop(context, 'uncomplete'),
          icon: const Icon(Icons.undo),
          label: const Text('Uncomplete'),
        ),

        // ===== DELETE PERMANENTLY =====
        TextButton.icon(
          onPressed: () => Navigator.pop(context, 'delete'),
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          label: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceEvenly,
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String label,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor ?? Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
