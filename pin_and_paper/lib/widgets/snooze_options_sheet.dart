import 'package:flutter/material.dart';

/// Bottom sheet for selecting snooze duration.
///
/// Returns a Duration representing the snooze choice:
/// - Positive durations: snooze for that amount of time from now
/// - Duration(hours: -1): "Tomorrow" sentinel (uses user's preferred notification time)
/// - Duration.zero: "Custom" sentinel (caller opens a time picker)
/// - null: user cancelled
class SnoozeOptionsSheet extends StatelessWidget {
  final String taskId;
  final void Function(Duration duration) onSnoozeSelected;

  const SnoozeOptionsSheet({
    super.key,
    required this.taskId,
    required this.onSnoozeSelected,
  });

  static Future<Duration?> show(BuildContext context, String taskId) {
    return showModalBottomSheet<Duration>(
      context: context,
      builder: (_) => SnoozeOptionsSheet(
        taskId: taskId,
        onSnoozeSelected: (d) => Navigator.pop(context, d),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Snooze reminder', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600,
            )),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('15 minutes'),
            onTap: () => onSnoozeSelected(const Duration(minutes: 15)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('30 minutes'),
            onTap: () => onSnoozeSelected(const Duration(minutes: 30)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('1 hour'),
            onTap: () => onSnoozeSelected(const Duration(hours: 1)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('3 hours'),
            onTap: () => onSnoozeSelected(const Duration(hours: 3)),
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Tomorrow'),
            subtitle: const Text('At your preferred notification time'),
            onTap: () => onSnoozeSelected(const Duration(hours: -1)),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Pick a time...'),
            onTap: () => onSnoozeSelected(Duration.zero),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
