import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Dialog explaining why the app needs notification permission.
///
/// Shown before requesting OS-level permission on Android 13+ and iOS.
/// Provides context so users understand the value before seeing the system dialog.
class PermissionExplanationDialog extends StatelessWidget {
  const PermissionExplanationDialog({super.key});

  /// Show the dialog and return whether permission was granted
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PermissionExplanationDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable Notifications'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pin and Paper can remind you about upcoming due dates so you never miss a deadline.',
          ),
          SizedBox(height: 12),
          Text(
            'You can configure when and how you receive reminders in Settings.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () async {
            final granted = await NotificationService().requestPermission();
            if (context.mounted) {
              Navigator.pop(context, granted);
            }
          },
          child: const Text('Enable'),
        ),
      ],
    );
  }
}
