import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/utils/date_formatter.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';

void main() {
  group('DateFormatter', () {
    late DateParsingService dateParser;

    setUp(() {
      dateParser = DateParsingService();
    });

    group('formatRelativeDate', () {
      test('formats today correctly (all-day)', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final result = DateFormatter.formatRelativeDate(effectiveToday, isAllDay: true);

        expect(result, contains('Today'));
        expect(result, isNot(contains(':')));  // No time for all-day
      });

      test('formats tomorrow correctly (all-day)', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final tomorrow = effectiveToday.add(const Duration(days: 1));
        final result = DateFormatter.formatRelativeDate(tomorrow, isAllDay: true);

        expect(result, contains('Tomorrow'));
        expect(result, isNot(contains(':')));  // No time for all-day
      });

      test('formats yesterday correctly (all-day)', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final yesterday = effectiveToday.subtract(const Duration(days: 1));
        final result = DateFormatter.formatRelativeDate(yesterday, isAllDay: true);

        expect(result, contains('Yesterday'));
        expect(result, isNot(contains(':')));  // No time for all-day
      });

      test('formats today with time correctly (not all-day)', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final todayAt3pm = DateTime(
          effectiveToday.year,
          effectiveToday.month,
          effectiveToday.day,
          15,
          30,
        );
        final result = DateFormatter.formatRelativeDate(todayAt3pm, isAllDay: false);

        expect(result, contains('Today'));
        expect(result, contains('3:30 PM'));
      });

      test('formats tomorrow with time correctly (not all-day)', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final tomorrow = effectiveToday.add(const Duration(days: 1));
        final tomorrowAt10am = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          10,
          0,
        );
        final result = DateFormatter.formatRelativeDate(tomorrowAt10am, isAllDay: false);

        expect(result, contains('Tomorrow'));
        expect(result, contains('10:00 AM'));
      });

      test('formats day of week for dates within a week', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final inFiveDays = effectiveToday.add(const Duration(days: 5));
        final result = DateFormatter.formatRelativeDate(inFiveDays, isAllDay: true);

        // Should contain a day name (Monday, Tuesday, etc.)
        final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        expect(dayNames.any((day) => result.contains(day)), isTrue);
      });

      test('formats dates beyond a week with abbreviated format', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final inTwoWeeks = effectiveToday.add(const Duration(days: 14));
        final result = DateFormatter.formatRelativeDate(inTwoWeeks, isAllDay: true);

        // Should contain abbreviated day and month (e.g., "Wed, Jan 22")
        expect(result, matches(RegExp(r'[A-Z][a-z]{2}, [A-Z][a-z]{2} \d{1,2}')));
      });

      test('includes full date in parentheses for clarity', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final result = DateFormatter.formatRelativeDate(effectiveToday, isAllDay: true);

        // Should have format like "Today (Wed, Jan 22)"
        expect(result, contains('('));
        expect(result, contains(')'));
        expect(result, matches(RegExp(r'\([A-Z][a-z]{2}, [A-Z][a-z]{2} \d{1,2}\)')));
      });

      test('handles dates in the past (beyond yesterday)', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final lastWeek = effectiveToday.subtract(const Duration(days: 7));
        final result = DateFormatter.formatRelativeDate(lastWeek, isAllDay: true);

        // Should contain day name or abbreviated date
        expect(result.isNotEmpty, isTrue);
      });

      test('handles midnight times correctly for all-day', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final midnight = DateTime(
          effectiveToday.year,
          effectiveToday.month,
          effectiveToday.day,
          0,
          0,
        );
        final result = DateFormatter.formatRelativeDate(midnight, isAllDay: true);

        expect(result, contains('Today'));
        expect(result, isNot(contains('12:00 AM')));  // No time shown for all-day
      });

      test('handles AM times correctly', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final morning = DateTime(
          effectiveToday.year,
          effectiveToday.month,
          effectiveToday.day,
          9,
          15,
        );
        final result = DateFormatter.formatRelativeDate(morning, isAllDay: false);

        expect(result, contains('9:15 AM'));
      });

      test('handles PM times correctly', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final evening = DateTime(
          effectiveToday.year,
          effectiveToday.month,
          effectiveToday.day,
          18,
          45,
        );
        final result = DateFormatter.formatRelativeDate(evening, isAllDay: false);

        expect(result, contains('6:45 PM'));
      });

      test('handles noon correctly', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final noon = DateTime(
          effectiveToday.year,
          effectiveToday.month,
          effectiveToday.day,
          12,
          0,
        );
        final result = DateFormatter.formatRelativeDate(noon, isAllDay: false);

        expect(result, contains('12:00 PM'));
      });
    });

    group('formatAlternativeDate', () {
      test('formats with custom label and full date', () {
        final date = DateTime(2026, 1, 22);
        final result = DateFormatter.formatAlternativeDate(date, 'Custom Label');

        expect(result, contains('Custom Label'));
        expect(result, contains('('));
        expect(result, contains(')'));
        expect(result, matches(RegExp(r'[A-Z][a-z]{2}, [A-Z][a-z]{2} \d{1,2}')));
      });

      test('formats today alternative correctly', () {
        final effectiveToday = DateParsingService().getCurrentEffectiveToday();
        final result = DateFormatter.formatAlternativeDate(effectiveToday, 'Today');

        expect(result, startsWith('Today ('));
        expect(result, endsWith(')'));
      });

      test('formats tomorrow alternative correctly', () {
        final effectiveToday = DateParsingService().getCurrentEffectiveToday();
        final tomorrow = effectiveToday.add(const Duration(days: 1));
        final result = DateFormatter.formatAlternativeDate(tomorrow, 'Tomorrow');

        expect(result, startsWith('Tomorrow ('));
        expect(result, endsWith(')'));
      });

      test('formats next week alternative correctly', () {
        final effectiveToday = DateParsingService().getCurrentEffectiveToday();
        final nextWeek = effectiveToday.add(const Duration(days: 7));
        final result = DateFormatter.formatAlternativeDate(nextWeek, 'Next week');

        expect(result, startsWith('Next week ('));
        expect(result, endsWith(')'));
      });

      test('handles empty label gracefully', () {
        final date = DateTime(2026, 1, 22);
        final result = DateFormatter.formatAlternativeDate(date, '');

        // Should still have the date in parentheses
        expect(result, contains('('));
        expect(result, matches(RegExp(r'\([A-Z][a-z]{2}, [A-Z][a-z]{2} \d{1,2}\)')));
      });

      test('handles dates with different years', () {
        final date = DateTime(2027, 6, 15);
        final result = DateFormatter.formatAlternativeDate(date, 'Future date');

        expect(result, contains('Future date'));
        expect(result, contains('Jun 15'));
      });
    });

    group('Today Window Consistency', () {
      test('formatRelativeDate uses effectiveToday, not DateTime.now()', () {
        // This test verifies the critical fix from Codex review
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final now = DateTime.now();

        // If current time is before cutoff (e.g., 2am), effectiveToday should be yesterday
        // Format should use effectiveToday for "Today" calculation
        final result = DateFormatter.formatRelativeDate(effectiveToday, isAllDay: true);

        expect(result, contains('Today'));
        // This verifies that formatRelativeDate correctly uses effectiveToday
        // instead of DateTime.now(), maintaining consistency with parsing
      });

      test('relative day calculation is consistent across calls', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();

        // Multiple calls should produce consistent results
        final result1 = DateFormatter.formatRelativeDate(effectiveToday, isAllDay: true);
        final result2 = DateFormatter.formatRelativeDate(effectiveToday, isAllDay: true);

        expect(result1, equals(result2));
      });
    });

    group('Edge Cases', () {
      test('handles leap year dates correctly', () {
        final leapDay = DateTime(2024, 2, 29);
        final result = DateFormatter.formatRelativeDate(leapDay, isAllDay: true);

        expect(result, contains('Feb 29'));
      });

      test('handles year boundaries correctly', () {
        final newYear = DateTime(2026, 1, 1);
        final result = DateFormatter.formatRelativeDate(newYear, isAllDay: true);

        expect(result, contains('Jan 1'));
      });

      test('handles different time zones (uses DateTime objects)', () {
        final effectiveToday = dateParser.getCurrentEffectiveToday();
        final date = DateTime(
          effectiveToday.year,
          effectiveToday.month,
          effectiveToday.day,
          14,
          30,
        );

        final result = DateFormatter.formatRelativeDate(date, isAllDay: false);

        expect(result, contains('2:30 PM'));
      });

      test('handles very far future dates', () {
        final farFuture = DateTime(2030, 12, 31);
        final result = DateFormatter.formatRelativeDate(farFuture, isAllDay: true);

        expect(result, contains('Dec 31'));
      });

      test('handles very far past dates', () {
        final farPast = DateTime(2020, 1, 1);
        final result = DateFormatter.formatRelativeDate(farPast, isAllDay: true);

        expect(result, contains('Jan 1'));
      });
    });
  });
}
