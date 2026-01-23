import 'package:flutter/material.dart';
import '../services/date_parsing_service.dart';
import '../utils/date_formatter.dart';

/// Bottom sheet showing date options for a parsed date
///
/// Phase 3.7: Shown when user taps on highlighted date text
///
/// Features:
/// - Shows current parsed date as selected option
/// - Provides alternatives (Today, Tomorrow, Next week)
/// - Manual date picker option
/// - Remove due date option
class DateOptionsSheet extends StatelessWidget {
  final ParsedDate parsedDate;
  final VoidCallback onRemove;
  final Function(DateTime date, bool isAllDay) onSelectDate;

  const DateOptionsSheet({
    super.key,
    required this.parsedDate,
    required this.onRemove,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final alternatives = _generateAlternatives(parsedDate.date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Due Date Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(),

          // Current selection
          _buildOption(
            context,
            date: parsedDate.date,
            isAllDay: parsedDate.isAllDay,
            label: DateFormatter.formatRelativeDate(
              parsedDate.date.toLocal(),
              isAllDay: parsedDate.isAllDay,
            ),
            isSelected: true,
          ),

          // Alternatives
          ...alternatives.map((alt) => _buildOption(
            context,
            date: alt.date,
            isAllDay: alt.isAllDay,
            label: alt.label,
            isSelected: false,
          )),

          const Divider(),

          // Manual picker (date + optional time)
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Pick custom date & time...'),
            onTap: () async {
              // Show date picker BEFORE closing sheet (context still valid)
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: parsedDate.date.toLocal(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (pickedDate != null) {
                // Then show time picker
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: parsedDate.isAllDay
                      ? TimeOfDay.now()
                      : TimeOfDay.fromDateTime(parsedDate.date.toLocal()),
                );
                // Don't pop here - callbacks are responsible for closing the sheet
                if (pickedTime != null) {
                  final dateWithTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                  onSelectDate(dateWithTime, false); // Not all-day
                } else {
                  // User cancelled time picker, use date as all-day
                  onSelectDate(pickedDate, true);
                }
              }
            },
          ),

          // Remove option
          ListTile(
            leading: const Icon(Icons.close, color: Colors.red),
            title: const Text('Remove due date', style: TextStyle(color: Colors.red)),
            onTap: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required DateTime date,
    required bool isAllDay,
    required String label,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      title: Text(label),
      onTap: isSelected ? null : () => onSelectDate(date, isAllDay),
    );
  }

  List<_DateAlternative> _generateAlternatives(DateTime current) {
    // CRITICAL FIX (Codex): Use effectiveToday instead of DateTime.now()
    // Otherwise at 2am, alternatives use wrong base date (off by one day)
    final effectiveToday = DateParsingService().getCurrentEffectiveToday();
    final alternatives = <_DateAlternative>[];

    // Add "Today" if not already today
    if (current.day != effectiveToday.day ||
        current.month != effectiveToday.month ||
        current.year != effectiveToday.year) {
      alternatives.add(_DateAlternative(
        date: DateTime(effectiveToday.year, effectiveToday.month, effectiveToday.day),
        isAllDay: true,
        label: DateFormatter.formatAlternativeDate(
          effectiveToday,
          'Today',
        ),
      ));
    }

    // Add "Tomorrow" if not already tomorrow
    final tomorrow = effectiveToday.add(const Duration(days: 1));
    if (current.day != tomorrow.day ||
        current.month != tomorrow.month ||
        current.year != tomorrow.year) {
      alternatives.add(_DateAlternative(
        date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        isAllDay: true,
        label: DateFormatter.formatAlternativeDate(
          tomorrow,
          'Tomorrow',
        ),
      ));
    }

    // Add "Next week" if not already next week
    final nextWeek = effectiveToday.add(const Duration(days: 7));
    if ((current.difference(effectiveToday).inDays - 7).abs() > 1) {
      alternatives.add(_DateAlternative(
        date: DateTime(nextWeek.year, nextWeek.month, nextWeek.day),
        isAllDay: true,
        label: DateFormatter.formatAlternativeDate(
          nextWeek,
          'Next week',
        ),
      ));
    }

    return alternatives;
  }
}

class _DateAlternative {
  final DateTime date;
  final bool isAllDay;
  final String label;

  _DateAlternative({
    required this.date,
    required this.isAllDay,
    required this.label,
  });
}
