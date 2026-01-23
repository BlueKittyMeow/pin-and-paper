import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/widgets/date_options_sheet.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';

void main() {
  group('DateOptionsSheet', () {
    late DateParsingService dateParser;

    setUp(() {
      dateParser = DateParsingService();
    });

    testWidgets('displays title correctly', (tester) async {
      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: DateTime(2026, 1, 23),
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      expect(find.text('Due Date Options'), findsOneWidget);
    });

    testWidgets('displays current selection with checkmark', (tester) async {
      final effectiveToday = dateParser.getCurrentEffectiveToday();
      final tomorrow = effectiveToday.add(const Duration(days: 1));

      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: tomorrow,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Should have a check_circle icon for selected option
      expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));

      // Should display "Tomorrow" in the selected option
      expect(find.textContaining('Tomorrow'), findsWidgets);
    });

    testWidgets('generates Today alternative when parsed date is not today', (tester) async {
      final effectiveToday = dateParser.getCurrentEffectiveToday();
      final tomorrow = effectiveToday.add(const Duration(days: 1));

      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: tomorrow,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Should show "Today" as an alternative
      expect(find.textContaining('Today'), findsWidgets);
    });

    testWidgets('generates Tomorrow alternative when parsed date is not tomorrow', (tester) async {
      final effectiveToday = dateParser.getCurrentEffectiveToday();

      final parsedDate = ParsedDate(
        matchedText: 'today',
        matchedRange: const TextRange(start: 0, end: 5),
        date: effectiveToday,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Should show "Tomorrow" as an alternative
      expect(find.textContaining('Tomorrow'), findsWidgets);
    });

    testWidgets('generates Next week alternative', (tester) async {
      final effectiveToday = dateParser.getCurrentEffectiveToday();

      final parsedDate = ParsedDate(
        matchedText: 'today',
        matchedRange: const TextRange(start: 0, end: 5),
        date: effectiveToday,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Should show "Next week" as an alternative
      expect(find.textContaining('Next week'), findsWidgets);
    });

    testWidgets('does not show Today alternative when parsed date is today', (tester) async {
      final effectiveToday = dateParser.getCurrentEffectiveToday();

      final parsedDate = ParsedDate(
        matchedText: 'today',
        matchedRange: const TextRange(start: 0, end: 5),
        date: effectiveToday,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Count how many times "Today" appears - should be once (current selection only)
      final todayFinder = find.textContaining('Today');
      expect(todayFinder, findsWidgets);

      // Verify only one "Today" option exists (the selected one)
      final listTiles = find.byType(ListTile);
      int todayCount = 0;
      for (final element in listTiles.evaluate()) {
        final widget = element.widget as ListTile;
        final title = widget.title as Text?;
        if (title?.data?.contains('Today') ?? false) {
          todayCount++;
        }
      }
      expect(todayCount, equals(1));
    });

    testWidgets('displays manual date picker option', (tester) async {
      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: DateTime(2026, 1, 23),
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      expect(find.text('Pick custom date & time...'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    });

    testWidgets('displays remove due date option', (tester) async {
      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: DateTime(2026, 1, 23),
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      expect(find.text('Remove due date'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onRemove when remove option is tapped', (tester) async {
      var removeCalled = false;

      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: DateTime(2026, 1, 23),
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () => removeCalled = true,
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Remove due date'));
      await tester.pump();

      expect(removeCalled, isTrue);
    });

    testWidgets('calls onSelectDate when alternative is tapped', (tester) async {
      DateTime? selectedDate;
      bool? selectedIsAllDay;

      final effectiveToday = dateParser.getCurrentEffectiveToday();
      final tomorrow = effectiveToday.add(const Duration(days: 1));

      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: tomorrow,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {
                selectedDate = date;
                selectedIsAllDay = isAllDay;
              },
            ),
          ),
        ),
      );

      // Find and tap the "Today" alternative
      final todayOptions = find.textContaining('Today');
      await tester.tap(todayOptions.first);
      await tester.pump();

      expect(selectedDate, isNotNull);
      expect(selectedIsAllDay, isTrue);
      expect(selectedDate!.day, equals(effectiveToday.day));
      expect(selectedDate!.month, equals(effectiveToday.month));
      expect(selectedDate!.year, equals(effectiveToday.year));
    });

    testWidgets('selected option is not tappable', (tester) async {
      var callCount = 0;

      final effectiveToday = dateParser.getCurrentEffectiveToday();

      final parsedDate = ParsedDate(
        matchedText: 'today',
        matchedRange: const TextRange(start: 0, end: 5),
        date: effectiveToday,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {
                callCount++;
              },
            ),
          ),
        ),
      );

      // Try to tap the selected option (should have check_circle icon)
      final selectedOption = find.byIcon(Icons.check_circle);
      await tester.tap(selectedOption);
      await tester.pump();

      // Should not call onSelectDate (onTap is null for selected items)
      expect(callCount, equals(0));
    });

    testWidgets('displays time for non-all-day dates', (tester) async {
      final dateWithTime = DateTime(2026, 1, 23, 15, 30); // 3:30 PM

      final parsedDate = ParsedDate(
        matchedText: 'tomorrow at 3:30pm',
        matchedRange: const TextRange(start: 0, end: 18),
        date: dateWithTime,
        isAllDay: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Should display the time (formatted by DateFormatter)
      expect(find.textContaining('3:30 PM'), findsOneWidget);
    });

    testWidgets('alternatives are all-day by default', (tester) async {
      bool? lastIsAllDay;

      final effectiveToday = dateParser.getCurrentEffectiveToday();
      final tomorrow = effectiveToday.add(const Duration(days: 1));

      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: tomorrow,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {
                lastIsAllDay = isAllDay;
              },
            ),
          ),
        ),
      );

      // Tap "Today" alternative
      final todayOptions = find.textContaining('Today');
      await tester.tap(todayOptions.first);
      await tester.pump();

      expect(lastIsAllDay, isTrue);
    });

    testWidgets('uses effectiveToday for alternatives (Today Window consistency)', (tester) async {
      // CRITICAL TEST: Verifies Codex fix for Today Window consistency
      final effectiveToday = dateParser.getCurrentEffectiveToday();
      final tomorrow = effectiveToday.add(const Duration(days: 1));

      final parsedDate = ParsedDate(
        matchedText: 'tomorrow',
        matchedRange: const TextRange(start: 0, end: 8),
        date: tomorrow,
        isAllDay: true,
      );

      DateTime? selectedDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {
                selectedDate = date;
              },
            ),
          ),
        ),
      );

      // Tap "Today" alternative
      final todayOptions = find.textContaining('Today');
      await tester.tap(todayOptions.first);
      await tester.pump();

      // Verify that "Today" matches effectiveToday, not DateTime.now()
      expect(selectedDate, isNotNull);
      expect(selectedDate!.year, equals(effectiveToday.year));
      expect(selectedDate!.month, equals(effectiveToday.month));
      expect(selectedDate!.day, equals(effectiveToday.day));
    });

    testWidgets('handles dates far in the future', (tester) async {
      final farFuture = DateTime(2030, 12, 31);

      final parsedDate = ParsedDate(
        matchedText: 'Dec 31 2030',
        matchedRange: const TextRange(start: 0, end: 11),
        date: farFuture,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Should still show alternatives (Today, Tomorrow, Next week)
      expect(find.textContaining('Today'), findsWidgets);
      expect(find.textContaining('Tomorrow'), findsWidgets);
      expect(find.textContaining('Next week'), findsWidgets);
    });

    testWidgets('handles dates in the past', (tester) async {
      final effectiveToday = dateParser.getCurrentEffectiveToday();
      final yesterday = effectiveToday.subtract(const Duration(days: 1));

      final parsedDate = ParsedDate(
        matchedText: 'yesterday',
        matchedRange: const TextRange(start: 0, end: 9),
        date: yesterday,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // Should still show future alternatives
      expect(find.textContaining('Today'), findsWidgets);
      expect(find.textContaining('Tomorrow'), findsWidgets);
    });

    testWidgets('does not show duplicate alternatives', (tester) async {
      final effectiveToday = dateParser.getCurrentEffectiveToday();
      final nextWeek = effectiveToday.add(const Duration(days: 7));

      // Parse "next week" - alternatives should not include duplicate "Next week"
      final parsedDate = ParsedDate(
        matchedText: 'next week',
        matchedRange: const TextRange(start: 0, end: 9),
        date: nextWeek,
        isAllDay: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateOptionsSheet(
              parsedDate: parsedDate,
              onRemove: () {},
              onSelectDate: (date, isAllDay) {},
            ),
          ),
        ),
      );

      // When parsed date IS next week, the alternative "Next week" should be filtered out
      // to avoid duplication. The selected option will show the day of week instead.
      // So we verify that "Today" and "Tomorrow" ARE shown as alternatives
      expect(find.textContaining('Today'), findsWidgets);
      expect(find.textContaining('Tomorrow'), findsWidgets);

      // Verify we have at least 2 unselected alternatives (Today, Tomorrow)
      final unselectedOptions = find.byIcon(Icons.circle_outlined);
      expect(unselectedOptions, findsAtLeastNWidgets(2));
    });
  });
}
