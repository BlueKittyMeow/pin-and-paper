import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart'; // Using a model to get a realistic import.

void main() {
  // A simple, fast mock parser using regex to find common date words.
  // This is NOT a real date parser. It's for establishing a performance baseline.
  String? mockDateParser(String text) {
    final regex = RegExp(
      r'\b(today|tomorrow|next week|next month|in \d+ days)\b',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  group('Performance Testing for Date Parsing', () {
    const singleParseTarget = Duration(milliseconds: 1);
    const rapidParseTarget = Duration(milliseconds: 10);

    // One-time JIT/regex-engine warm-up, paid outside any assertion.
    // Without this, the *first* RegExp/Stopwatch use in this isolate pays a
    // one-off compilation tax (observed 1-2.4ms on a loaded dev host, vs.
    // ~20us once warm) that lands entirely on whichever test happens to run
    // first below — a false failure from JIT noise, not a real regression
    // in mockDateParser. This mirrors the "host guard" used elsewhere in
    // the date-parsing suite (see
    // test/integration/date_parsing_integration_test.dart) but for a
    // different underlying cause: this file never touches flutter_js, so
    // it isn't gated on the QuickJS native library like those tests are.
    setUpAll(() {
      mockDateParser('warm up');
    });

    test('Single parse speed should be well under 1ms', () {
      const testPhrase =
          'This is a test to see if we can find tomorrow in this string';
      final stopwatch = Stopwatch()..start();
      mockDateParser(testPhrase);
      stopwatch.stop();

      print('Single parse time: ${stopwatch.elapsedMicroseconds} microseconds');
      expect(stopwatch.elapsed, lessThan(singleParseTarget));
    });

    test('1000 sequential parses should be very fast', () {
      const testPhrase = 'Find tomorrow in this string';
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        mockDateParser(testPhrase);
      }
      stopwatch.stop();
      final averageTime = stopwatch.elapsedMicroseconds / 1000;
      print('1000 parses total time: ${stopwatch.elapsedMilliseconds} ms');
      print('Average parse time: $averageTime microseconds');
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
    });

    test('Rapid sequential parsing (typing simulation) should be fast', () {
      final phrases = [
        "t",
        "to",
        "tom",
        "tomo",
        "tomor",
        "tomorr",
        "tomorro",
        "tomorrow",
      ];
      final stopwatch = Stopwatch()..start();
      for (final phrase in phrases) {
        mockDateParser(phrase);
      }
      stopwatch.stop();
      print('Rapid parse (8 calls) total time: ${stopwatch.elapsedMicroseconds} microseconds');
      expect(stopwatch.elapsed, lessThan(rapidParseTarget));
    });

     test('False positive rejection should be extremely fast', () {
      const testPhrase =
          'This is a long string of text that contains no date-like keywords at all.';
      final stopwatch = Stopwatch()..start();
      mockDateParser(testPhrase);
      stopwatch.stop();
      print('False positive rejection time: ${stopwatch.elapsedMicroseconds} microseconds');
      expect(stopwatch.elapsed, lessThan(singleParseTarget));
    });
  });
}
