import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('executes action after delay', () async {
      final debouncer = Debouncer(milliseconds: 100);
      var counter = 0;

      debouncer.run(() => counter++);

      // Should not execute immediately
      expect(counter, equals(0));

      // Wait for debounce delay
      await Future.delayed(const Duration(milliseconds: 150));

      // Should execute after delay
      expect(counter, equals(1));

      debouncer.dispose();
    });

    test('cancels previous action when called multiple times', () async {
      final debouncer = Debouncer(milliseconds: 100);
      var counter = 0;

      // Call multiple times in quick succession
      debouncer.run(() => counter = 1);
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.run(() => counter = 2);
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.run(() => counter = 3);

      // Wait for final debounce to complete
      await Future.delayed(const Duration(milliseconds: 150));

      // Only the last call should execute
      expect(counter, equals(3));

      debouncer.dispose();
    });

    test('cancel() prevents execution', () async {
      final debouncer = Debouncer(milliseconds: 100);
      var executed = false;

      debouncer.run(() => executed = true);

      // Cancel before delay expires
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.cancel();

      // Wait past the original delay
      await Future.delayed(const Duration(milliseconds: 100));

      // Should not have executed
      expect(executed, isFalse);

      debouncer.dispose();
    });

    test('dispose() cancels pending actions', () async {
      final debouncer = Debouncer(milliseconds: 100);
      var executed = false;

      debouncer.run(() => executed = true);

      // Dispose immediately
      debouncer.dispose();

      // Wait past the delay
      await Future.delayed(const Duration(milliseconds: 150));

      // Should not have executed
      expect(executed, isFalse);
    });

    test('can be reused after cancel', () async {
      final debouncer = Debouncer(milliseconds: 100);
      var counter = 0;

      debouncer.run(() => counter = 1);
      debouncer.cancel();

      // Use again after cancel
      debouncer.run(() => counter = 2);
      await Future.delayed(const Duration(milliseconds: 150));

      expect(counter, equals(2));

      debouncer.dispose();
    });

    test('handles rapid successive calls correctly', () async {
      final debouncer = Debouncer(milliseconds: 100);
      var lastValue = 0;

      // Simulate rapid typing (10 calls in 200ms)
      for (var i = 1; i <= 10; i++) {
        debouncer.run(() => lastValue = i);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // Wait for final debounce
      await Future.delayed(const Duration(milliseconds: 150));

      // Only last value should be set
      expect(lastValue, equals(10));

      debouncer.dispose();
    });
  });
}
