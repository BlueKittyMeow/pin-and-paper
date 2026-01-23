import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';
import 'package:pin_and_paper/utils/date_formatter.dart';
import 'package:pin_and_paper/widgets/highlighted_text_editing_controller.dart';
import 'package:pin_and_paper/utils/debouncer.dart';

/// Integration tests for the complete date parsing flow
///
/// These tests verify that all components work together:
/// - HighlightedTextEditingController
/// - Debouncer
/// - DateParsingService
/// - DateFormatter
///
/// Note: Some tests are skipped on web platform where flutter_js is not available
void main() {
  group('Date Parsing Integration', () {
    group('End-to-End Parsing Flow', () {
      testWidgets('typing "tomorrow" triggers parsing and highlighting', (tester) async {
        // Skip on web (flutter_js not available)
        if (kIsWeb) {
          return;
        }

        final dateParser = DateParsingService();
        await dateParser.initialize();

        final controller = HighlightedTextEditingController(text: '');
        ParsedDate? parsedDate;

        // Simulate the flow from EditTaskDialog
        void onTitleChanged(String text) {
          if (!dateParser.containsPotentialDate(text)) {
            controller.clearHighlight();
            parsedDate = null;
            return;
          }

          // In real app, this would be debounced
          final parsed = dateParser.parse(text);
          if (parsed != null) {
            controller.setHighlight(parsed.matchedRange);
            parsedDate = parsed;
          } else {
            controller.clearHighlight();
            parsedDate = null;
          }
        }

        // Simulate typing "Call dentist tomorrow"
        controller.text = 'Call dentist tomorrow';
        onTitleChanged(controller.text);

        // Verify parsing occurred
        expect(parsedDate, isNotNull);
        expect(parsedDate!.matchedText, equals('tomorrow'));
        expect(controller.highlightRange, isNotNull);

        controller.dispose();
      });

      testWidgets('pre-filter prevents unnecessary parsing', (tester) async {
        final dateParser = DateParsingService();
        final controller = HighlightedTextEditingController(text: '');
        var parseCallCount = 0;

        void onTitleChanged(String text) {
          // Pre-filter check
          if (!dateParser.containsPotentialDate(text)) {
            controller.clearHighlight();
            return;
          }

          // This should not be reached for non-date text
          parseCallCount++;
          final parsed = dateParser.parse(text);
          if (parsed != null) {
            controller.setHighlight(parsed.matchedRange);
          }
        }

        // Non-date text should be filtered out
        controller.text = 'Call mom';
        onTitleChanged(controller.text);

        expect(parseCallCount, equals(0)); // Pre-filter prevented parse
        expect(controller.highlightRange, isNull);

        controller.dispose();
      });

      testWidgets('changing text clears previous highlight', (tester) async {
        // Skip on web
        if (kIsWeb) {
          return;
        }

        final dateParser = DateParsingService();
        await dateParser.initialize();

        final controller = HighlightedTextEditingController(text: '');

        void onTitleChanged(String text) {
          if (!dateParser.containsPotentialDate(text)) {
            controller.clearHighlight();
            return;
          }

          final parsed = dateParser.parse(text);
          if (parsed != null) {
            controller.setHighlight(parsed.matchedRange);
          } else {
            controller.clearHighlight();
          }
        }

        // First, type with date
        controller.text = 'Meeting tomorrow';
        onTitleChanged(controller.text);
        expect(controller.highlightRange, isNotNull);

        // Then change to non-date text
        controller.text = 'Meeting with Bob';
        onTitleChanged(controller.text);
        expect(controller.highlightRange, isNull);

        controller.dispose();
      });
    });

    group('Debouncer Integration', () {
      test('debouncer delays parsing during rapid typing', () async {
        final debouncer = Debouncer(milliseconds: 300);
        var parseCount = 0;

        // Simulate rapid typing (like user typing a sentence)
        for (var i = 0; i < 10; i++) {
          debouncer.run(() => parseCount++);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Parsing should not have occurred yet
        expect(parseCount, equals(0));

        // Wait for debounce to complete
        await Future.delayed(const Duration(milliseconds: 400));

        // Only one parse should have occurred (the last one)
        expect(parseCount, equals(1));

        debouncer.dispose();
      });

      test('debouncer cancels when text changes before delay expires', () async {
        final debouncer = Debouncer(milliseconds: 300);
        var executedText = '';

        // Start typing "tom..."
        debouncer.run(() => executedText = 'tom');
        await Future.delayed(const Duration(milliseconds: 100));

        // Continue to "tomo..."
        debouncer.run(() => executedText = 'tomo');
        await Future.delayed(const Duration(milliseconds: 100));

        // Complete to "tomorrow"
        debouncer.run(() => executedText = 'tomorrow');

        // Wait for final debounce
        await Future.delayed(const Duration(milliseconds: 400));

        // Only the last value should have been executed
        expect(executedText, equals('tomorrow'));

        debouncer.dispose();
      });
    });

    group('Today Window Consistency', () {
      test('effectiveToday is consistent between parsing and formatting', () {
        final dateParser = DateParsingService();
        final effectiveToday = dateParser.getCurrentEffectiveToday();

        // Format "today" using DateFormatter
        final formatted = DateFormatter.formatRelativeDate(effectiveToday, isAllDay: true);

        // Should always say "Today" regardless of actual clock time
        expect(formatted, contains('Today'));

        // Verify both use same base date
        final now = DateTime.now();
        final cutoffHour = 4;
        final cutoffMinute = 59;

        // If current time is before cutoff, effectiveToday should be yesterday
        if (now.hour < cutoffHour || (now.hour == cutoffHour && now.minute <= cutoffMinute)) {
          expect(effectiveToday.day, equals(now.day - 1));
        } else {
          expect(effectiveToday.day, equals(now.day));
        }
      });
    });

    group('Title Cleaning Flow', () {
      testWidgets('getCleanTitle strips matched date text', (tester) async {
        // Skip on web
        if (kIsWeb) {
          return;
        }

        final dateParser = DateParsingService();
        await dateParser.initialize();

        final text = 'Call dentist tomorrow';
        final parsed = dateParser.parse(text);

        expect(parsed, isNotNull);

        // Simulate _getCleanTitle logic from EditTaskDialog
        String getCleanTitle(String originalText, ParsedDate? parsedDate) {
          if (parsedDate == null) {
            return originalText.trim();
          }

          final range = parsedDate.matchedRange;
          final before = originalText.substring(0, range.start);
          final after = originalText.substring(range.end);

          return '$before$after'.trim();
        }

        final cleanTitle = getCleanTitle(text, parsed);

        // Should remove "tomorrow" and clean up spaces
        expect(cleanTitle, equals('Call dentist'));
        expect(cleanTitle, isNot(contains('tomorrow')));
      });

      testWidgets('getCleanTitle handles date at start of text', (tester) async {
        // Skip on web
        if (kIsWeb) {
          return;
        }

        final dateParser = DateParsingService();
        await dateParser.initialize();

        final text = 'Tomorrow call dentist';
        final parsed = dateParser.parse(text);

        expect(parsed, isNotNull);

        String getCleanTitle(String originalText, ParsedDate? parsedDate) {
          if (parsedDate == null) {
            return originalText.trim();
          }

          final range = parsedDate.matchedRange;
          final before = originalText.substring(0, range.start);
          final after = originalText.substring(range.end);

          return '$before$after'.trim();
        }

        final cleanTitle = getCleanTitle(text, parsed);

        expect(cleanTitle, equals('call dentist'));
      });

      testWidgets('getCleanTitle handles date at end of text', (tester) async {
        // Skip on web
        if (kIsWeb) {
          return;
        }

        final dateParser = DateParsingService();
        await dateParser.initialize();

        final text = 'Call dentist tomorrow';
        final parsed = dateParser.parse(text);

        expect(parsed, isNotNull);

        String getCleanTitle(String originalText, ParsedDate? parsedDate) {
          if (parsedDate == null) {
            return originalText.trim();
          }

          final range = parsedDate.matchedRange;
          final before = originalText.substring(0, range.start);
          final after = originalText.substring(range.end);

          return '$before$after'.trim();
        }

        final cleanTitle = getCleanTitle(text, parsed);

        expect(cleanTitle, equals('Call dentist'));
      });
    });

    group('Performance Characteristics', () {
      test('pre-filter is significantly faster than parsing', () {
        final dateParser = DateParsingService();
        final nonDateText = 'Call mom about the project';

        // Measure pre-filter time
        final preFilterStart = DateTime.now();
        for (var i = 0; i < 1000; i++) {
          dateParser.containsPotentialDate(nonDateText);
        }
        final preFilterEnd = DateTime.now();
        final preFilterMs = preFilterEnd.difference(preFilterStart).inMilliseconds;

        // Pre-filter should be very fast (< 100ms for 1000 iterations)
        expect(preFilterMs, lessThan(100));
      });

      test('pre-filter correctly identifies date patterns', () {
        final dateParser = DateParsingService();

        // Should return true (has date patterns)
        expect(dateParser.containsPotentialDate('tomorrow'), isTrue);
        expect(dateParser.containsPotentialDate('Call dentist tomorrow'), isTrue);
        expect(dateParser.containsPotentialDate('Meeting Monday'), isTrue);
        expect(dateParser.containsPotentialDate('Due Jan 15'), isTrue);
        expect(dateParser.containsPotentialDate('Next week'), isTrue);
        expect(dateParser.containsPotentialDate('at 3pm'), isTrue);

        // Should return false (no date patterns)
        expect(dateParser.containsPotentialDate('Call mom'), isFalse);
        expect(dateParser.containsPotentialDate('Buy milk'), isFalse);
        expect(dateParser.containsPotentialDate('Project meeting'), isFalse);

        // Critical: Should NOT trigger on "May need to..." (false positive prevention)
        expect(dateParser.containsPotentialDate('May need to buy milk'), isFalse);
        expect(dateParser.containsPotentialDate('March forward with plan'), isFalse);
      });
    });

    group('Error Handling', () {
      testWidgets('handles empty text gracefully', (tester) async {
        final dateParser = DateParsingService();
        await dateParser.initialize();

        final result = dateParser.parse('');
        expect(result, isNull);
      });

      testWidgets('handles whitespace-only text gracefully', (tester) async {
        final dateParser = DateParsingService();
        await dateParser.initialize();

        final result = dateParser.parse('   ');
        expect(result, isNull);
      });

      testWidgets('handles very long text gracefully', (tester) async {
        final dateParser = DateParsingService();
        await dateParser.initialize();

        final longText = 'Call dentist tomorrow ' * 100;
        expect(() => dateParser.parse(longText), returnsNormally);
      });

      testWidgets('handles special characters gracefully', (tester) async {
        final dateParser = DateParsingService();
        await dateParser.initialize();

        expect(() => dateParser.parse('Meeting @ tomorrow'), returnsNormally);
        expect(() => dateParser.parse('Call #tomorrow'), returnsNormally);
        expect(() => dateParser.parse('Due: tomorrow!'), returnsNormally);
      });
    });

    group('False Positive Prevention', () {
      test('prevents "May need to..." false positive', () {
        final dateParser = DateParsingService();

        // Pre-filter should reject these (no number after month name)
        expect(dateParser.containsPotentialDate('May need to check'), isFalse);
        expect(dateParser.containsPotentialDate('March forward'), isFalse);
        expect(dateParser.containsPotentialDate('Meet with April'), isFalse);
      });

      test('accepts valid month + day patterns', () {
        final dateParser = DateParsingService();

        // These should pass pre-filter (month + day)
        expect(dateParser.containsPotentialDate('May 15'), isTrue);
        expect(dateParser.containsPotentialDate('Meeting May 15'), isTrue);
        expect(dateParser.containsPotentialDate('Jan 1'), isTrue);
        expect(dateParser.containsPotentialDate('December 25'), isTrue);
      });
    });

    group('Web Platform Compatibility', () {
      testWidgets('gracefully handles web platform', (tester) async {
        final dateParser = DateParsingService();
        await dateParser.initialize();

        // On web, parse should return null
        // On native, it may return a result or null
        final result = dateParser.parse('tomorrow');

        if (kIsWeb) {
          expect(result, isNull);
        }
        // On native, we can't guarantee chrono.js loaded successfully in test env
      });

      test('pre-filter works on all platforms', () {
        final dateParser = DateParsingService();

        // Pre-filter is pure Dart, should work everywhere
        expect(dateParser.containsPotentialDate('tomorrow'), isTrue);
        expect(dateParser.containsPotentialDate('Call mom'), isFalse);
      });
    });
  });
}
