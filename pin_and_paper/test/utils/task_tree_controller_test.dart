import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/utils/task_tree_controller.dart';

void main() {
  group('TaskTreeController', () {
    late TaskTreeController controller;
    late Task task1;
    late Task task2;
    late Task child1;

    setUp(() {
      task1 = Task(
        id: 'task-1',
        title: 'Task 1',
        createdAt: DateTime.now(),
      );
      task2 = Task(
        id: 'task-2',
        title: 'Task 2',
        createdAt: DateTime.now(),
      );
      child1 = Task(
        id: 'child-1',
        title: 'Child 1',
        createdAt: DateTime.now(),
        parentId: 'task-1',
      );

      controller = TaskTreeController(
        roots: [task1, task2],
        childrenProvider: (task) {
          if (task.id == 'task-1') return [child1];
          return [];
        },
      );
    });

    group('getExpansionState', () {
      test('returns false by default', () {
        expect(controller.getExpansionState(task1), isFalse);
        expect(controller.getExpansionState(task2), isFalse);
      });

      test('returns true after setExpansionState(true)', () {
        controller.setExpansionState(task1, true);
        expect(controller.getExpansionState(task1), isTrue);
        expect(controller.getExpansionState(task2), isFalse);
      });
    });

    group('setExpansionState', () {
      test('sets state correctly', () {
        controller.setExpansionState(task1, true);
        expect(controller.getExpansionState(task1), isTrue);

        controller.setExpansionState(task1, false);
        expect(controller.getExpansionState(task1), isFalse);
      });
    });

    group('state persists across object replacement', () {
      test('CRITICAL: state persists when Task object is replaced with same ID',
          () {
        // Expand task1
        controller.setExpansionState(task1, true);
        expect(controller.getExpansionState(task1), isTrue);

        // Create NEW Task object with SAME ID (simulates update)
        final task1Updated = Task(
          id: 'task-1', // Same ID
          title: 'Task 1 - Updated Title',
          createdAt: DateTime.now(),
        );

        // The key test: expansion state should persist for the new object
        expect(controller.getExpansionState(task1Updated), isTrue);
      });

      test('different IDs have independent state', () {
        controller.setExpansionState(task1, true);
        controller.setExpansionState(task2, false);

        expect(controller.getExpansionState(task1), isTrue);
        expect(controller.getExpansionState(task2), isFalse);
      });
    });

    group('pruneOrphanedIds', () {
      test('removes IDs not in valid set', () {
        controller.setExpansionState(task1, true);
        controller.setExpansionState(task2, true);

        // Prune, keeping only task1
        controller.pruneOrphanedIds({'task-1'});

        expect(controller.getExpansionState(task1), isTrue);
        expect(controller.getExpansionState(task2), isFalse); // Pruned
      });

      test('keeps all IDs when all are valid', () {
        controller.setExpansionState(task1, true);
        controller.setExpansionState(task2, true);

        controller.pruneOrphanedIds({'task-1', 'task-2', 'other'});

        expect(controller.getExpansionState(task1), isTrue);
        expect(controller.getExpansionState(task2), isTrue);
      });

      test('handles empty valid set', () {
        controller.setExpansionState(task1, true);
        controller.pruneOrphanedIds({});
        expect(controller.getExpansionState(task1), isFalse);
      });
    });

    group('clearExpansionState', () {
      test('clears all expansion state', () {
        controller.setExpansionState(task1, true);
        controller.setExpansionState(task2, true);

        controller.clearExpansionState();

        expect(controller.getExpansionState(task1), isFalse);
        expect(controller.getExpansionState(task2), isFalse);
      });
    });

    group('inherited methods work through overrides', () {
      test('toggleExpansion works', () {
        expect(controller.getExpansionState(task1), isFalse);

        controller.toggleExpansion(task1);
        expect(controller.getExpansionState(task1), isTrue);

        controller.toggleExpansion(task1);
        expect(controller.getExpansionState(task1), isFalse);
      });

      test('expand and collapse work', () {
        controller.expand(task1);
        expect(controller.getExpansionState(task1), isTrue);

        controller.collapse(task1);
        expect(controller.getExpansionState(task1), isFalse);
      });

      test('expandAll expands all nodes via setExpansionState', () {
        controller.expandAll();
        expect(controller.getExpansionState(task1), isTrue);
      });

      test('collapseAll collapses all nodes via setExpansionState', () {
        controller.expandAll();
        controller.collapseAll();
        expect(controller.getExpansionState(task1), isFalse);
      });
    });

    group('edge cases', () {
      test('handles non-existent task ID gracefully', () {
        final nonExistent = Task(
          id: 'non-existent',
          title: 'Ghost',
          createdAt: DateTime.now(),
        );
        // Should return default (false), not throw
        expect(controller.getExpansionState(nonExistent), isFalse);
      });

      test('rapid expand/collapse operations', () {
        for (int i = 0; i < 100; i++) {
          controller.toggleExpansion(task1);
        }
        // After 100 toggles (even number), should be back to original
        expect(controller.getExpansionState(task1), isFalse);
      });

      test('state preserved after multiple object replacements', () {
        // Simulate multiple update cycles
        controller.setExpansionState(task1, true);

        for (int i = 0; i < 10; i++) {
          final replacement = Task(
            id: 'task-1',
            title: 'Task 1 - Version $i',
            createdAt: DateTime.now(),
          );
          // State should persist through all replacements
          expect(controller.getExpansionState(replacement), isTrue);
        }
      });
    });

    group('filter scenarios', () {
      test('hidden task IDs preserved when filter applied then cleared', () {
        // Expand both tasks
        controller.setExpansionState(task1, true);
        controller.setExpansionState(task2, true);

        // Simulate filter: only task1 is visible
        // (In real app, task2 would be filtered out of _tasks)
        // But _toggledIds still contains task2's ID

        // Create new task2 (simulating filter being cleared, task2 returns)
        final task2Restored = Task(
          id: 'task-2',
          title: 'Task 2',
          createdAt: DateTime.now(),
        );

        // State should still be preserved
        expect(controller.getExpansionState(task2Restored), isTrue);
      });

      test('orphaned IDs are harmless', () {
        // Expand a task
        controller.setExpansionState(task1, true);

        // Create task with different ID
        final differentTask = Task(
          id: 'different-id',
          title: 'Different Task',
          createdAt: DateTime.now(),
        );

        // Should return default (false), orphaned 'task-1' ID doesn't affect it
        expect(controller.getExpansionState(differentTask), isFalse);
      });
    });
  });
}
