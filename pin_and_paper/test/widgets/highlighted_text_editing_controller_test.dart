import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/widgets/highlighted_text_editing_controller.dart';

void main() {
  group('HighlightedTextEditingController', () {
    testWidgets('initializes with text', (tester) async {
      final controller = HighlightedTextEditingController(
        text: 'Test text',
      );

      expect(controller.text, equals('Test text'));
      expect(controller.highlightRange, isNull);

      controller.dispose();
    });

    testWidgets('setHighlight updates range and notifies listeners', (tester) async {
      final controller = HighlightedTextEditingController(
        text: 'Call dentist tomorrow',
      );

      var notified = false;
      controller.addListener(() => notified = true);

      // Set highlight range
      controller.setHighlight(const TextRange(start: 14, end: 21));

      expect(controller.highlightRange, equals(const TextRange(start: 14, end: 21)));
      expect(notified, isTrue);

      controller.dispose();
    });

    testWidgets('clearHighlight removes range and notifies listeners', (tester) async {
      final controller = HighlightedTextEditingController(
        text: 'Call dentist tomorrow',
      );

      controller.setHighlight(const TextRange(start: 14, end: 21));

      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearHighlight();

      expect(controller.highlightRange, isNull);
      expect(notified, isTrue);

      controller.dispose();
    });

    testWidgets('setHighlight does not notify if range unchanged', (tester) async {
      final controller = HighlightedTextEditingController(
        text: 'Call dentist tomorrow',
      );

      controller.setHighlight(const TextRange(start: 14, end: 21));

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      // Set same range again
      controller.setHighlight(const TextRange(start: 14, end: 21));

      // Should not notify because range is unchanged
      expect(notifyCount, equals(0));

      controller.dispose();
    });

    testWidgets('clearHighlight does not notify if already null', (tester) async {
      final controller = HighlightedTextEditingController(
        text: 'Test text',
      );

      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearHighlight();

      // Should not notify because range was already null
      expect(notified, isFalse);

      controller.dispose();
    });

    testWidgets('buildTextSpan returns plain text when no highlight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'Test text',
                );

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Should return simple TextSpan without children
                expect(span.children, isNull);
                expect(span.text, equals('Test text'));

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('buildTextSpan creates highlighted span', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'Call dentist tomorrow',
                );

                controller.setHighlight(const TextRange(start: 14, end: 21));

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Web platform: highlighting disabled, returns plain text
                if (kIsWeb) {
                  expect(span.children, isNull);
                  expect(span.text, equals('Call dentist tomorrow'));
                } else {
                  // Mobile/desktop: should have children for multi-part span
                  expect(span.children, isNotNull);
                  expect(span.children!.length, equals(2)); // Before + highlighted
                }

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('buildTextSpan validates range boundaries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'Short',
                );

                // Invalid range (extends beyond text)
                controller.setHighlight(const TextRange(start: 0, end: 100));

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Should return plain text when range is invalid
                expect(span.children, isNull);
                expect(span.text, equals('Short'));

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('buildTextSpan handles negative range', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'Test text',
                );

                // Invalid range (negative start)
                controller.setHighlight(const TextRange(start: -1, end: 5));

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Should return plain text when range is invalid
                expect(span.children, isNull);
                expect(span.text, equals('Test text'));

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('buildTextSpan handles inverted range', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'Test text',
                );

                // Invalid range (start >= end)
                controller.setHighlight(const TextRange(start: 5, end: 2));

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Should return plain text when range is invalid
                expect(span.children, isNull);
                expect(span.text, equals('Test text'));

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('onTapHighlight wires TapGestureRecognizer to highlighted TextSpan', (tester) async {
      // Skip on web (highlighting disabled)
      if (kIsWeb) return;

      bool callbackFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'meet tomorrow',
                  onTapHighlight: () => callbackFired = true,
                );
                controller.setHighlight(const TextRange(start: 5, end: 13));

                final textSpan = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Find the highlighted child span
                final children = textSpan.children!;
                final highlightSpan = children[1] as TextSpan;
                expect(highlightSpan.text, 'tomorrow');
                expect(highlightSpan.recognizer, isA<TapGestureRecognizer>());

                // Simulate the tap via the recognizer directly
                (highlightSpan.recognizer as TapGestureRecognizer).onTap!();
                expect(callbackFired, isTrue);

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('handles highlight at start of text', (tester) async {
      // Skip on web (highlighting disabled)
      if (kIsWeb) {
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'Tomorrow is the day',
                );

                controller.setHighlight(const TextRange(start: 0, end: 8));

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Should have children: highlighted + after
                expect(span.children, isNotNull);
                expect(span.children!.length, equals(2));

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('handles highlight at end of text', (tester) async {
      // Skip on web (highlighting disabled)
      if (kIsWeb) {
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'Meeting tomorrow',
                );

                controller.setHighlight(const TextRange(start: 8, end: 16));

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Should have children: before + highlighted
                expect(span.children, isNotNull);
                expect(span.children!.length, equals(2));

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('handles highlight covering entire text', (tester) async {
      // Skip on web (highlighting disabled)
      if (kIsWeb) {
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = HighlightedTextEditingController(
                  text: 'tomorrow',
                );

                controller.setHighlight(const TextRange(start: 0, end: 8));

                final span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(color: Colors.black),
                  withComposing: false,
                );

                // Should have only highlighted span (no before/after)
                expect(span.children, isNotNull);
                expect(span.children!.length, equals(1));

                controller.dispose();
                return Container();
              },
            ),
          ),
        ),
      );
    });
  });
}
