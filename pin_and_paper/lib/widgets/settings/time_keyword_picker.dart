import 'package:flutter/material.dart';

import '../../utils/theme.dart';

/// A compact picker for time keyword preferences.
///
/// Displays the keyword label with its current hour setting.
/// Tapping opens a time picker to change the hour.
class TimeKeywordPicker extends StatelessWidget {
  final String label;
  final String description;
  final int currentHour;
  final ValueChanged<int> onHourChanged;

  const TimeKeywordPicker({
    super.key,
    required this.label,
    required this.description,
    required this.currentHour,
    required this.onHourChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pickTime(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.richBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.kraftPaper.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatHour(currentHour),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepShadow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: 0),
      helpText: 'When does "$label" start?',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.creamPaper,
              dialHandColor: AppTheme.deepShadow,
              hourMinuteColor: AppTheme.kraftPaper,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onHourChanged(picked.hour);
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }
}
