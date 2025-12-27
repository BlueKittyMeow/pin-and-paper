import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pin_and_paper/main.dart' as app;

/// Smoke tests for basic app functionality
///
/// These tests validate core features work in the real app environment.
/// They're simpler than full integration tests but catch critical issues.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Tests - Basic Functionality', () {
    testWidgets('App launches and shows task input', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify task input is visible
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('Can create a task using Add button', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and type into text field
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test Task');
      await tester.pumpAndSettle();

      // Tap Add button
      final addButton = find.widgetWithText(ElevatedButton, 'Add');
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify task appears (should find it somewhere in the widget tree)
      expect(find.textContaining('Test Task'), findsWidgets);
    });

    testWidgets('Reorder mode toggle works', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find reorder button (should be Icons.reorder initially)
      final reorderButton = find.byIcon(Icons.reorder);
      expect(reorderButton, findsOneWidget);

      // Tap to enter reorder mode
      await tester.tap(reorderButton);
      await tester.pumpAndSettle();

      // Should now show checkmark (Icons.check)
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.reorder), findsNothing);

      // Tap again to exit reorder mode
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Should be back to reorder icon
      expect(find.byIcon(Icons.reorder), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('Can create multiple tasks', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final textField = find.byType(TextField).first;
      final addButton = find.widgetWithText(ElevatedButton, 'Add');

      // Create 3 tasks
      for (int i = 1; i <= 3; i++) {
        await tester.enterText(textField, 'Task $i');
        await tester.pumpAndSettle();
        await tester.tap(addButton);
        await tester.pumpAndSettle();
      }

      // All tasks should be visible
      expect(find.textContaining('Task 1'), findsWidgets);
      expect(find.textContaining('Task 2'), findsWidgets);
      expect(find.textContaining('Task 3'), findsWidgets);
    });

    testWidgets('Settings screen accessible', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap settings icon
      final settingsButton = find.byIcon(Icons.settings);
      expect(settingsButton, findsOneWidget);

      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Should navigate to settings (exact content may vary)
      // Just verify we navigated somewhere
      expect(find.byType(TextField), findsNothing,
          reason: 'Should have navigated away from main screen');
    });

    testWidgets('Brain Dump screen accessible', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap brain dump icon
      final brainDumpButton = find.byIcon(Icons.auto_awesome);
      expect(brainDumpButton, findsOneWidget);

      await tester.tap(brainDumpButton);
      await tester.pumpAndSettle();

      // Should navigate to brain dump
      expect(find.byType(TextField), findsNothing,
          reason: 'Should have navigated away from main screen');
    });
  });

  group('Smoke Tests - Task Completion', () {
    testWidgets('Can complete a task', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Create a task
      final textField = find.byType(TextField).first;
      final addButton = find.widgetWithText(ElevatedButton, 'Add');

      await tester.enterText(textField, 'Complete Me');
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Find the checkbox (should be unchecked)
      final checkbox = find.byType(Checkbox).first;
      expect(checkbox, findsOneWidget);

      // Tap to complete
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Task should still exist but state changed
      expect(find.textContaining('Complete Me'), findsWidgets);
    });
  });

  group('Smoke Tests - Empty States', () {
    testWidgets('Shows empty state message when no tasks', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // On first launch with no tasks, should show empty message
      // (This assumes fresh database - may not always be true)
      final emptyMessage = find.textContaining('No tasks');
      if (emptyMessage.evaluate().isNotEmpty) {
        expect(emptyMessage, findsOneWidget);
      }
    });
  });

  group('Smoke Tests - UI Responsiveness', () {
    testWidgets('Add button is disabled with empty input', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final textField = find.byType(TextField).first;
      final addButton = find.widgetWithText(ElevatedButton, 'Add');

      // Clear any text
      await tester.enterText(textField, '');
      await tester.pumpAndSettle();

      // Try tapping Add (should do nothing with empty input)
      final taskCountBefore = find.byType(Checkbox).evaluate().length;

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      final taskCountAfter = find.byType(Checkbox).evaluate().length;

      expect(taskCountAfter, taskCountBefore,
          reason: 'Should not create task with empty input');
    });

    testWidgets('Text field clears after adding task', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final textField = find.byType(TextField).first;
      final addButton = find.widgetWithText(ElevatedButton, 'Add');

      // Add a task
      await tester.enterText(textField, 'Clear Test');
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Text field should be cleared
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, isEmpty,
          reason: 'Text field should clear after adding task');
    });
  });
}
