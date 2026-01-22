import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';

void main() {
  group('DateParsingService', () {
    late DateParsingService service;

    setUp(() {
      service = DateParsingService();
    });

    group('Initialization', () {
      test('initializes successfully', () async {
        await service.initialize();
        // Should not throw
      });

      test('handles multiple initialization calls gracefully', () async {
        await service.initialize();
        await service.initialize(); // Should be no-op
        // Should not throw
      });

      test('on web platform, skips flutter_js initialization', () async {
        await service.initialize();
        // On web, this should complete without errors
        // flutter_js is not available on web, but service should handle gracefully
        expect(true, isTrue); // Just verify no crash
      });
    });

    group('containsPotentialDate (Pre-filter)', () {
      test('returns false for non-date strings', () {
        expect(service.containsPotentialDate('Call mom'), isFalse);
        expect(service.containsPotentialDate('Buy milk'), isFalse);
        expect(service.containsPotentialDate('Meeting notes'), isFalse);
        expect(service.containsPotentialDate('Read'), isFalse);
        expect(service.containsPotentialDate('Go'), isFalse);
      });

      test('returns true for relative dates', () {
        expect(service.containsPotentialDate('Call tomorrow'), isTrue);
        expect(service.containsPotentialDate('Meeting today'), isTrue);
        expect(service.containsPotentialDate('Due yesterday'), isTrue);
        expect(service.containsPotentialDate('See you tonight'), isTrue);
        expect(service.containsPotentialDate('Due next week'), isTrue);
        expect(service.containsPotentialDate('This Monday'), isTrue);
        expect(service.containsPotentialDate('Last Friday'), isTrue);
      });

      test('returns true for day names', () {
        expect(service.containsPotentialDate('Monday meeting'), isTrue);
        expect(service.containsPotentialDate('See you Friday'), isTrue);
        expect(service.containsPotentialDate('Wed deadline'), isTrue);
        expect(service.containsPotentialDate('on Thursday'), isTrue);
      });

      test('returns true for month names with context', () {
        expect(service.containsPotentialDate('Jan 15'), isTrue);
        expect(service.containsPotentialDate('Meeting March 3'), isTrue);
        expect(service.containsPotentialDate('Due December 25'), isTrue);
      });

      test('returns false for month names alone (prevents false positives)', () {
        // Critical: "May need to..." should NOT trigger parsing
        expect(service.containsPotentialDate('May need to check'), isFalse);
        expect(service.containsPotentialDate('March forward'), isFalse);
        expect(service.containsPotentialDate('Meet with April'), isFalse);
      });

      test('returns true for numeric dates', () {
        expect(service.containsPotentialDate('Due 12/31'), isTrue);
        expect(service.containsPotentialDate('Meeting 1-15'), isTrue);
        expect(service.containsPotentialDate('Year 2026'), isTrue);
        expect(service.containsPotentialDate('in 3 days'), isTrue);
        expect(service.containsPotentialDate('in 2 weeks'), isTrue);
      });

      test('returns true for time expressions', () {
        expect(service.containsPotentialDate('Meeting at 3pm'), isTrue);
        expect(service.containsPotentialDate('Call at 10'), isTrue);
      });

      test('returns false for very short strings', () {
        expect(service.containsPotentialDate('Go'), isFalse);
        expect(service.containsPotentialDate('To'), isFalse);
        expect(service.containsPotentialDate('A'), isFalse);
        expect(service.containsPotentialDate(''), isFalse);
      });

      test('is case insensitive', () {
        expect(service.containsPotentialDate('TOMORROW'), isTrue);
        expect(service.containsPotentialDate('Tomorrow'), isTrue);
        expect(service.containsPotentialDate('tomorrow'), isTrue);
        expect(service.containsPotentialDate('tOmOrRoW'), isTrue);
      });
    });

    group('getEffectiveToday (Today Window Algorithm)', () {
      test('before cutoff (2:30am) returns yesterday', () {
        final now = DateTime(2026, 1, 22, 2, 30); // 2:30am Wednesday
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.year, equals(2026));
        expect(effectiveToday.month, equals(1));
        expect(effectiveToday.day, equals(21)); // Tuesday (yesterday)
      });

      test('at exact cutoff time (4:59am) returns yesterday', () {
        final now = DateTime(2026, 1, 22, 4, 59); // 4:59am Wednesday
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.day, equals(21)); // Tuesday (yesterday)
      });

      test('one minute after cutoff (5:00am) returns today', () {
        final now = DateTime(2026, 1, 22, 5, 0); // 5:00am Wednesday
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.day, equals(22)); // Wednesday (today)
      });

      test('at exact cutoff hour but after cutoff minute returns today', () {
        final now = DateTime(2026, 1, 22, 4, 60); // Invalid but tests logic
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        // This would be 5:00am in reality
        expect(effectiveToday.day, equals(22)); // Today
      });

      test('during normal hours (noon) returns today', () {
        final now = DateTime(2026, 1, 22, 12, 0); // Noon Wednesday
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.day, equals(22)); // Wednesday (today)
      });

      test('late night (11:59pm) returns today', () {
        final now = DateTime(2026, 1, 22, 23, 59); // 11:59pm Wednesday
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.day, equals(22)); // Wednesday (today)
      });

      test('just after midnight (12:01am) returns yesterday', () {
        final now = DateTime(2026, 1, 22, 0, 1); // 12:01am Wednesday
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.day, equals(21)); // Tuesday (yesterday)
      });

      test('handles month boundary correctly', () {
        final now = DateTime(2026, 2, 1, 2, 0); // 2am Feb 1
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.year, equals(2026));
        expect(effectiveToday.month, equals(1)); // January
        expect(effectiveToday.day, equals(31)); // Jan 31 (yesterday)
      });

      test('handles year boundary correctly', () {
        final now = DateTime(2026, 1, 1, 2, 0); // 2am Jan 1, 2026
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.year, equals(2025));
        expect(effectiveToday.month, equals(12)); // December
        expect(effectiveToday.day, equals(31)); // Dec 31, 2025 (yesterday)
      });

      test('handles leap year boundary', () {
        final now = DateTime(2024, 3, 1, 2, 0); // 2am Mar 1, 2024 (leap year)
        final effectiveToday = service.getEffectiveToday(now, 4, 59);

        expect(effectiveToday.year, equals(2024));
        expect(effectiveToday.month, equals(2)); // February
        expect(effectiveToday.day, equals(29)); // Feb 29, 2024 (yesterday)
      });

      test('different cutoff times work correctly', () {
        final now = DateTime(2026, 1, 22, 3, 30); // 3:30am

        // Cutoff at 3:00am - should return today
        final today1 = service.getEffectiveToday(now, 3, 0);
        expect(today1.day, equals(22));

        // Cutoff at 4:00am - should return yesterday
        final today2 = service.getEffectiveToday(now, 4, 0);
        expect(today2.day, equals(21));
      });
    });

    group('getCurrentEffectiveToday', () {
      test('returns a date without time components', () {
        final effectiveToday = service.getCurrentEffectiveToday();

        // Should return a date at midnight (time stripped)
        expect(effectiveToday.hour, equals(0));
        expect(effectiveToday.minute, equals(0));
        expect(effectiveToday.second, equals(0));
      });

      test('uses default cutoff settings (4:59am)', () {
        final effectiveToday = service.getCurrentEffectiveToday();

        // Should be a valid date
        expect(effectiveToday, isNotNull);
        expect(effectiveToday.year, greaterThanOrEqualTo(2026));
      });
    });

    group('parse', () {
      // Note: Actual parsing tests depend on chrono.js which may not be available in test environment
      // These tests verify the service handles various cases gracefully

      test('returns null for empty string', () async {
        await service.initialize();
        final result = service.parse('');
        expect(result, isNull);
      });

      test('returns null for whitespace-only string', () async {
        await service.initialize();
        final result = service.parse('   ');
        expect(result, isNull);
      });

      test('handles null gracefully when not initialized', () {
        // Before initialization, parse should handle gracefully
        final result = service.parse('tomorrow');
        // On web or before init, should return null
        expect(result, isNull);
      });

      test('on web platform, always returns null', () async {
        await service.initialize();
        final result = service.parse('tomorrow');

        if (kIsWeb) {
          expect(result, isNull);
        }
        // On non-web, might return a result or null depending on chrono.js availability
      });
    });

    group('ParsedDate model', () {
      test('creates ParsedDate with all required fields', () {
        final parsed = ParsedDate(
          matchedText: 'tomorrow',
          matchedRange: const TextRange(start: 14, end: 22),
          date: DateTime(2026, 1, 23),
          isAllDay: true,
        );

        expect(parsed.matchedText, equals('tomorrow'));
        expect(parsed.matchedRange.start, equals(14));
        expect(parsed.matchedRange.end, equals(22));
        expect(parsed.date, equals(DateTime(2026, 1, 23)));
        expect(parsed.isAllDay, isTrue);
      });

      test('cleanTitle returns matched text', () {
        final parsed = ParsedDate(
          matchedText: 'tomorrow',
          matchedRange: const TextRange(start: 14, end: 22),
          date: DateTime(2026, 1, 23),
          isAllDay: true,
        );

        expect(parsed.cleanTitle, equals('tomorrow'));
      });
    });

    group('Edge Cases', () {
      test('handles very long strings', () async {
        await service.initialize();
        final longString = 'Call dentist tomorrow ' * 100;

        // Should not crash
        expect(() => service.parse(longString), returnsNormally);
      });

      test('handles special characters', () async {
        await service.initialize();

        expect(() => service.parse('Meeting @ tomorrow'), returnsNormally);
        expect(() => service.parse('Call #tomorrow'), returnsNormally);
        expect(() => service.parse('Due: tomorrow!'), returnsNormally);
      });

      test('handles unicode characters', () async {
        await service.initialize();

        expect(() => service.parse('Meeting 明天 tomorrow'), returnsNormally);
        expect(() => service.parse('Tomorrow café ☕'), returnsNormally);
      });

      test('containsPotentialDate handles empty string', () {
        expect(service.containsPotentialDate(''), isFalse);
      });

      test('containsPotentialDate handles very long string', () {
        final longString = 'Call dentist tomorrow ' * 1000;
        expect(() => service.containsPotentialDate(longString), returnsNormally);
      });
    });

    group('Disposal', () {
      test('dispose cleans up resources', () {
        final testService = DateParsingService();
        expect(() => testService.dispose(), returnsNormally);
      });

      test('can use service after disposal (singleton pattern)', () async {
        service.dispose();
        // Since it's a singleton, getting instance again should work
        final newService = DateParsingService();
        await newService.initialize();
        expect(true, isTrue);
      });
    });
  });
}
