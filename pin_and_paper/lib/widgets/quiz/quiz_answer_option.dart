import 'package:flutter/material.dart';

import '../../models/quiz_question.dart';
import '../../utils/theme.dart';

/// A single answer option for a quiz question.
///
/// Displays as a tappable card with radio-style selection indicator.
/// Supports optional time picker trigger via [QuizAnswer.showTimePicker].
class QuizAnswerOption extends StatelessWidget {
  final QuizAnswer answer;
  final bool isSelected;
  final TimeOfDay? selectedTime;
  final String? selectedDayName;
  final VoidCallback onTap;

  const QuizAnswerOption({
    super.key,
    required this.answer,
    required this.isSelected,
    this.selectedTime,
    this.selectedDayName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.deepShadow.withValues(alpha: 0.08)
              : AppTheme.creamPaper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.deepShadow : AppTheme.kraftPaper,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.deepShadow : AppTheme.creamPaper,
                    border: Border.all(
                      color: isSelected ? AppTheme.deepShadow : AppTheme.muted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: AppTheme.creamPaper)
                      : null,
                ),
                const SizedBox(width: 14),

                // Answer text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answer.text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: AppTheme.richBlack,
                        ),
                      ),
                      if (answer.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          answer.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Time picker icon hint
                if (answer.showTimePicker)
                  Icon(
                    Icons.access_time_rounded,
                    size: 20,
                    color: isSelected ? AppTheme.deepShadow : AppTheme.muted,
                  ),

                // Day picker icon hint
                if (answer.showDayPicker)
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: isSelected ? AppTheme.deepShadow : AppTheme.muted,
                  ),
              ],
            ),

            // Show selected custom day
            if (answer.showDayPicker && isSelected && selectedDayName != null) ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(left: 36),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Selected: $selectedDayName',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],

            // Show selected custom time
            if (answer.showTimePicker && isSelected && selectedTime != null) ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(left: 36),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Selected: ${selectedTime!.format(context)}',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
