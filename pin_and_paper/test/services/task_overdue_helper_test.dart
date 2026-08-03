import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';
import 'package:pin_and_paper/utils/date_suffix_parser.dart';

/// Phase 4.4-MVP (M3/M4 addendum item 2): tests for the extracted
/// `isTaskOverdue()` helper and for agreement between its two repointed
/// call sites (`DateSuffixParser` and, indirectly, the Spatial View's
/// `task_card_adapter.dart` — covered separately in
/// test/spatial/task_card_adapter_test.dart since it needs a `Task`).
///
/// Deliberately does not call `DateParsingService.initialize()` (that boots
/// the flutter_js/QuickJS chrono.js runtime, which is flaky on Linux test
/// hosts per this repo's known limitation) — `isTaskOverdue` and
/// `DateSuffixParser.parse` are both plain-Dart and don't need it.
///
/// All-day boundary cases are built from `getCurrentEffectiveToday()`, not
/// raw `DateTime.now()` — the same idiom the rest of this test suite uses
/// (see test/utils/date_formatter_test.dart) — so these tests can't flake
/// depending on what wall-clock time they happen to run at relative to the
/// default 4:59am Today Window cutoff.
void main() {
  final effectiveToday = DateParsingService().getCurrentEffectiveToday();

  group('isTaskOverdue', () {
    test('all-day task due yesterday (effective) is overdue', () {
      final yesterday = effectiveToday.subtract(const Duration(days: 1));
      expect(isTaskOverdue(yesterday, isAllDay: true), isTrue);
    });

    test('all-day task due today (effective) is NOT overdue', () {
      expect(isTaskOverdue(effectiveToday, isAllDay: true), isFalse);
    });

    test('all-day task due tomorrow (effective) is not overdue', () {
      final tomorrow = effectiveToday.add(const Duration(days: 1));
      expect(isTaskOverdue(tomorrow, isAllDay: true), isFalse);
    });

    test('all-day comparison ignores time-of-day on the due date', () {
      // Today at 23:59 is still "today", not overdue, for an all-day task —
      // the all-day branch compares date-only, not the wall clock.
      final todayLate = DateTime(effectiveToday.year, effectiveToday.month, effectiveToday.day, 23, 59);
      expect(isTaskOverdue(todayLate, isAllDay: true), isFalse);
    });

    test('timed task in the past is overdue', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(isTaskOverdue(past, isAllDay: false), isTrue);
    });

    test('timed task in the future is not overdue', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      expect(isTaskOverdue(future, isAllDay: false), isFalse);
    });

    test('timed task just barely in the future is not overdue', () {
      // A margin generous enough to stay stable under slow CI (avoids
      // flaking on the literal instant of "now"), while still exercising
      // the near-boundary case the M3/M4 addendum's test list calls for.
      final justAhead = DateTime.now().add(const Duration(seconds: 30));
      expect(isTaskOverdue(justAhead, isAllDay: false), isFalse);
    });
  });

  group('DateSuffixParser repointed at isTaskOverdue (agreement check)', () {
    test('all-day suffix in the past parses as overdue, matching isTaskOverdue directly', () {
      final past = effectiveToday.subtract(const Duration(days: 5));
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final weekday = weekdays[past.weekday % 7];
      final suffix = '($weekday, ${months[past.month]} ${past.day})';

      final result = DateSuffixParser.parse('Do the thing $suffix');
      expect(result, isNotNull);
      expect(result!.isOverdue, isTaskOverdue(past, isAllDay: true));
      expect(result.isOverdue, isTrue);
    });

    test('all-day suffix for today (effective) parses as NOT overdue, matching isTaskOverdue directly', () {
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final weekday = weekdays[effectiveToday.weekday % 7];
      final suffix = '($weekday, ${months[effectiveToday.month]} ${effectiveToday.day})';

      final result = DateSuffixParser.parse('Do the thing $suffix');
      expect(result, isNotNull);
      expect(result!.isOverdue, isTaskOverdue(effectiveToday, isAllDay: true));
      expect(result.isOverdue, isFalse);
    });
  });
}
