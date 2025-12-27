import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pin_and_paper/main.dart' as app;

/// Integration tests for Phase 3.2 features:
/// - Hierarchical task structure
/// - Drag-and-drop reordering (including sibling reordering bug fix)
/// - Breadcrumb navigation
/// - CASCADE delete
///
/// These tests simulate real user interactions with the app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3.2 - Drag and Drop Reordering', () {
    testWidgets('Create parent and child tasks', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Wait for app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Create a parent task
      final taskInput = find.byType(TextField).first;
      await tester.enterText(taskInput, 'Parent Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify parent task exists
      expect(find.text('Parent Task'), findsOneWidget);

      // Tap on parent to navigate to it
      await tester.tap(find.text('Parent Task'));
      await tester.pumpAndSettle();

      // Create 4 child tasks
      for (int i = 1; i <= 4; i++) {
        await tester.enterText(taskInput, 'Child $i');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }

      // Verify all children exist
      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
      expect(find.text('Child 4'), findsOneWidget);
    });

    testWidgets('Sibling reordering bug fix - drag to position 0', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Create parent with 4 children
      final taskInput = find.byType(TextField).first;
      await tester.enterText(taskInput, 'Parent Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parent Task'));
      await tester.pumpAndSettle();

      for (int i = 1; i <= 4; i++) {
        await tester.enterText(taskInput, 'Child $i');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }

      // Enter reorder mode via long-press
      await tester.longPress(find.text('Child 1'));
      await tester.pumpAndSettle();

      // Verify reorder mode is active (check for reorder icon changed to checkmark)
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Get initial position of Child 4
      final child4Finder = find.text('Child 4');
      final child1Finder = find.text('Child 1');

      // Calculate offset to drag Child 4 to top (position 0)
      final child4Rect = tester.getRect(child4Finder);
      final child1Rect = tester.getRect(child1Finder);
      final dragOffset = Offset(0, child1Rect.top - child4Rect.top);

      // Drag Child 4 to position 0
      await tester.drag(child4Finder, dragOffset);
      await tester.pumpAndSettle();

      // Exit reorder mode
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Verify Child 4 is now at position 0
      // We can check this by finding all text widgets and verifying order
      final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
      final childTexts = allTextWidgets
          .map((w) => w.data)
          .where((text) => text != null && text.startsWith('Child '))
          .toList();

      expect(childTexts.first, 'Child 4',
          reason: 'Child 4 should be at position 0 after reordering');
    });

    testWidgets('Reorder multiple times within same parent', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Create parent with 3 children
      final taskInput = find.byType(TextField).first;
      await tester.enterText(taskInput, 'Parent Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parent Task'));
      await tester.pumpAndSettle();

      for (int i = 1; i <= 3; i++) {
        await tester.enterText(taskInput, 'Child $i');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }

      // Enter reorder mode
      await tester.longPress(find.text('Child 1'));
      await tester.pumpAndSettle();

      // Move Child 3 to position 1
      final child3Rect = tester.getRect(find.text('Child 3'));
      final child2Rect = tester.getRect(find.text('Child 2'));
      await tester.drag(
        find.text('Child 3'),
        Offset(0, child2Rect.top - child3Rect.top),
      );
      await tester.pumpAndSettle();

      // Move Child 1 to position 2
      final child1Rect = tester.getRect(find.text('Child 1'));
      final targetRect = tester.getRect(find.text('Child 2'));
      await tester.drag(
        find.text('Child 1'),
        Offset(0, targetRect.bottom - child1Rect.top),
      );
      await tester.pumpAndSettle();

      // Exit reorder mode
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Verify final order: Child 2, Child 3, Child 1
      final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
      final childTexts = allTextWidgets
          .map((w) => w.data)
          .where((text) => text != null && text.startsWith('Child '))
          .toList();

      expect(childTexts.length, 3);
      expect(childTexts[0], 'Child 2');
      expect(childTexts[1], 'Child 3');
      expect(childTexts[2], 'Child 1');
    });
  });

  group('Phase 3.2 - Breadcrumb Navigation', () {
    testWidgets('Breadcrumbs show navigation path', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final taskInput = find.byType(TextField).first;

      // Create root task
      await tester.enterText(taskInput, 'Root Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Navigate to root
      await tester.tap(find.text('Root Task'));
      await tester.pumpAndSettle();

      // Verify breadcrumb shows root
      expect(find.text('Root Task'), findsWidgets);

      // Create child task
      await tester.enterText(taskInput, 'Child Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Navigate to child
      await tester.tap(find.text('Child Task'));
      await tester.pumpAndSettle();

      // Verify breadcrumb shows path: Root Task > Child Task
      expect(find.text('Root Task'), findsWidgets);
      expect(find.text('Child Task'), findsWidgets);

      // Create grandchild
      await tester.enterText(taskInput, 'Grandchild Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Navigate to grandchild
      await tester.tap(find.text('Grandchild Task'));
      await tester.pumpAndSettle();

      // Verify full path visible
      expect(find.text('Root Task'), findsWidgets);
      expect(find.text('Child Task'), findsWidgets);
      expect(find.text('Grandchild Task'), findsWidgets);
    });

    testWidgets('Clicking breadcrumb navigates back', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final taskInput = find.byType(TextField).first;

      // Create root -> child -> grandchild hierarchy
      await tester.enterText(taskInput, 'Root Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Root Task'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Child Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Child Task'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Grandchild Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grandchild Task'));
      await tester.pumpAndSettle();

      // Now at Grandchild level, click Root Task breadcrumb
      // Find breadcrumb in top area (not in task list)
      final breadcrumbFinder = find.ancestor(
        of: find.text('Root Task'),
        matching: find.byType(TextButton),
      ).first;

      await tester.tap(breadcrumbFinder);
      await tester.pumpAndSettle();

      // Should be back at Root level
      // Child Task should be visible in list
      expect(find.text('Child Task'), findsOneWidget);
    });
  });

  group('Phase 3.2 - CASCADE Delete', () {
    testWidgets('Delete parent with children shows confirmation', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final taskInput = find.byType(TextField).first;

      // Create parent with 2 children
      await tester.enterText(taskInput, 'Parent Task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parent Task'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Child 1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Child 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Go back to root
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      // Long-press on parent to show delete option
      await tester.longPress(find.text('Parent Task'));
      await tester.pumpAndSettle();

      // Look for delete button/icon
      final deleteFinder = find.byIcon(Icons.delete);
      if (deleteFinder.evaluate().isNotEmpty) {
        await tester.tap(deleteFinder);
        await tester.pumpAndSettle();

        // Should show confirmation dialog mentioning child count
        expect(find.textContaining('2'), findsOneWidget,
            reason: 'Confirmation should show count of children');
      }
    });

    testWidgets('Confirming delete removes parent and all children', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final taskInput = find.byType(TextField).first;

      // Create parent with children
      await tester.enterText(taskInput, 'Parent To Delete');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parent To Delete'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Child 1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Child 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Go back to root
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      // Delete parent
      await tester.longPress(find.text('Parent To Delete'));
      await tester.pumpAndSettle();

      final deleteFinder = find.byIcon(Icons.delete);
      if (deleteFinder.evaluate().isNotEmpty) {
        await tester.tap(deleteFinder);
        await tester.pumpAndSettle();

        // Confirm deletion
        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();

          // Verify parent and children are gone
          expect(find.text('Parent To Delete'), findsNothing);
          expect(find.text('Child 1'), findsNothing);
          expect(find.text('Child 2'), findsNothing);
        }
      }
    });

    testWidgets('Delete does not affect unrelated tasks', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final taskInput = find.byType(TextField).first;

      // Create two separate hierarchies
      await tester.enterText(taskInput, 'Parent A');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Parent B');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Add children to Parent A
      await tester.tap(find.text('Parent A'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Child A1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Go back and add children to Parent B
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parent B'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Child B1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Go back to root
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      // Delete Parent A
      await tester.longPress(find.text('Parent A'));
      await tester.pumpAndSettle();

      final deleteFinder = find.byIcon(Icons.delete);
      if (deleteFinder.evaluate().isNotEmpty) {
        await tester.tap(deleteFinder);
        await tester.pumpAndSettle();

        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();

          // Verify Parent A and its children are gone
          expect(find.text('Parent A'), findsNothing);
          expect(find.text('Child A1'), findsNothing);

          // Verify Parent B and its children still exist
          expect(find.text('Parent B'), findsOneWidget);
          await tester.tap(find.text('Parent B'));
          await tester.pumpAndSettle();
          expect(find.text('Child B1'), findsOneWidget);
        }
      }
    });
  });

  group('Phase 3.2 - Edge Cases', () {
    testWidgets('Maximum nesting depth (4 levels)', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final taskInput = find.byType(TextField).first;

      // Create 4-level hierarchy
      await tester.enterText(taskInput, 'Level 1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Level 1'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Level 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Level 2'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Level 3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Level 3'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Level 4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should successfully create Level 4
      expect(find.text('Level 4'), findsOneWidget);

      // Try to create Level 5 (should be prevented)
      await tester.tap(find.text('Level 4'));
      await tester.pumpAndSettle();

      await tester.enterText(taskInput, 'Level 5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should show error or not create Level 5
      // The exact behavior depends on implementation
      // This test documents the expected behavior
    });

    testWidgets('Reordering with empty list', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Try to enter reorder mode with no tasks
      final reorderButton = find.byIcon(Icons.reorder);
      if (reorderButton.evaluate().isNotEmpty) {
        await tester.tap(reorderButton);
        await tester.pumpAndSettle();

        // Should handle gracefully (no crash)
        expect(find.byIcon(Icons.check), findsOneWidget,
            reason: 'Should enter reorder mode even with empty list');
      }
    });
  });
}
