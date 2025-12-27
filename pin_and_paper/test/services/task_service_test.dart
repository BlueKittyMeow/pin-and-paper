import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TaskService taskService;

  setUp(() async {
    // Initialize database
    await DatabaseService.instance.database;
    taskService = TaskService();

    // Clean database before each test
    final db = await DatabaseService.instance.database;
    await db.delete('tasks');
  });

  tearDown() async {
    // Clean up database after each test
    final db = await DatabaseService.instance.database;
    await db.delete('tasks');
  }

  group('TaskService - Hierarchical Query Methods', () {
    test('getTaskHierarchy() returns tasks with correct depth', () async {
      // Create hierarchy: Root → Child → Grandchild
      final root = await taskService.createTask('Root Task');
      final child = await taskService.createTask('Child Task');
      final grandchild = await taskService.createTask('Grandchild Task');

      // Nest child under root
      await taskService.updateTaskParent(child.id, root.id, 0);
      // Nest grandchild under child
      await taskService.updateTaskParent(grandchild.id, child.id, 0);

      final tasks = await taskService.getTaskHierarchy();

      // Find each task in the result
      final rootResult = tasks.firstWhere((t) => t.id == root.id);
      final childResult = tasks.firstWhere((t) => t.id == child.id);
      final grandchildResult = tasks.firstWhere((t) => t.id == grandchild.id);

      expect(rootResult.depth, 0);
      expect(childResult.depth, 1);
      expect(grandchildResult.depth, 2);
    });

    test('getTaskWithChildren() fetches direct children only', () async {
      // Create hierarchy: Parent → [Child1, Child2] → Grandchild
      final parent = await taskService.createTask('Parent');
      final child1 = await taskService.createTask('Child1');
      final child2 = await taskService.createTask('Child2');
      final grandchild = await taskService.createTask('Grandchild');

      await taskService.updateTaskParent(child1.id, parent.id, 0);
      await taskService.updateTaskParent(child2.id, parent.id, 1);
      await taskService.updateTaskParent(grandchild.id, child1.id, 0);

      final children = await taskService.getTaskWithChildren(parent.id);

      // Should return only direct children (not grandchildren)
      expect(children.length, 2);
      expect(children.any((t) => t.id == child1.id), true);
      expect(children.any((t) => t.id == child2.id), true);
      expect(children.any((t) => t.id == grandchild.id), false);
    });

    test('getTaskWithChildren() returns empty list if no children', () async {
      final task = await taskService.createTask('Single Task');

      final result = await taskService.getTaskWithChildren(task.id);

      expect(result.isEmpty, true);
    });

    test('countDescendants() returns accurate count', () async {
      // Create hierarchy: Parent → [Child1, Child2] → Grandchild
      final parent = await taskService.createTask('Parent');
      final child1 = await taskService.createTask('Child1');
      final child2 = await taskService.createTask('Child2');
      final grandchild = await taskService.createTask('Grandchild');

      await taskService.updateTaskParent(child1.id, parent.id, 0);
      await taskService.updateTaskParent(child2.id, parent.id, 1);
      await taskService.updateTaskParent(grandchild.id, child1.id, 0);

      final count = await taskService.countDescendants(parent.id);

      expect(count, 3); // 2 children + 1 grandchild
    });

    test('countDescendants() returns 0 for childless tasks', () async {
      final task = await taskService.createTask('Childless Task');

      final count = await taskService.countDescendants(task.id);

      expect(count, 0);
    });
  });

  group('TaskService - Parent Update Methods', () {
    test('updateTaskParent() successfully nests task', () async {
      // Create two root tasks
      final taskA = await taskService.createTask('Task A');
      final taskB = await taskService.createTask('Task B');

      // Nest TaskB under TaskA
      final error = await taskService.updateTaskParent(taskB.id, taskA.id, 0);

      expect(error, null);

      // Verify the change
      final tasks = await taskService.getTaskHierarchy();
      final updatedB = tasks.firstWhere((t) => t.id == taskB.id);

      expect(updatedB.parentId, taskA.id);
      expect(updatedB.position, 0);
      expect(updatedB.depth, 1);
    });

    test('updateTaskParent() successfully unnests task', () async {
      // Create hierarchy: Parent → Child
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');

      await taskService.updateTaskParent(child.id, parent.id, 0);

      // Unnest child (make it root)
      final error = await taskService.updateTaskParent(child.id, null, 0);

      expect(error, null);

      // Verify the change
      final tasks = await taskService.getTaskHierarchy();
      final updatedChild = tasks.firstWhere((t) => t.id == child.id);

      expect(updatedChild.parentId, null);
      expect(updatedChild.depth, 0);
    });

    test('updateTaskParent() prevents circular reference', () async {
      // Create hierarchy: Parent → Child
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');

      await taskService.updateTaskParent(child.id, parent.id, 0);

      // Try to make parent a child of child (circular)
      final error = await taskService.updateTaskParent(parent.id, child.id, 0);

      expect(error, isNotNull);
      expect(error!.contains('circular'), true);

      // Verify nothing changed
      final tasks = await taskService.getTaskHierarchy();
      final unchangedParent = tasks.firstWhere((t) => t.id == parent.id);

      expect(unchangedParent.parentId, null);
      expect(unchangedParent.depth, 0);
    });

    test('updateTaskParent() enforces max depth limit', () async {
      // Create 4-level hierarchy (max allowed)
      final level0 = await taskService.createTask('Level 0');
      final level1 = await taskService.createTask('Level 1');
      final level2 = await taskService.createTask('Level 2');
      final level3 = await taskService.createTask('Level 3');
      final level4 = await taskService.createTask('Level 4');

      await taskService.updateTaskParent(level1.id, level0.id, 0);
      await taskService.updateTaskParent(level2.id, level1.id, 0);
      await taskService.updateTaskParent(level3.id, level2.id, 0);

      // Try to create level 5 (should fail)
      final error = await taskService.updateTaskParent(level4.id, level3.id, 0);

      expect(error, isNotNull);
      expect(error!.contains('depth'), true);

      // Verify level4 remains a root task
      final tasks = await taskService.getTaskHierarchy();
      final unchangedLevel4 = tasks.firstWhere((t) => t.id == level4.id);

      expect(unchangedLevel4.parentId, null);
      expect(unchangedLevel4.depth, 0);
    });
  });

  group('TaskService - Delete Methods', () {
    test('deleteTaskWithChildren() CASCADE deletes entire subtree', () async {
      // Create Parent → [Child1, Child2] → Grandchild
      final parent = await taskService.createTask('Parent');
      final child1 = await taskService.createTask('Child1');
      final child2 = await taskService.createTask('Child2');
      final grandchild = await taskService.createTask('Grandchild');

      await taskService.updateTaskParent(child1.id, parent.id, 0);
      await taskService.updateTaskParent(child2.id, parent.id, 1);
      await taskService.updateTaskParent(grandchild.id, child1.id, 0);

      // Delete parent (should delete all 4 tasks)
      final deletedCount = await taskService.deleteTaskWithChildren(parent.id);

      expect(deletedCount, 4);

      // Verify all are deleted
      final remainingTasks = await taskService.getAllTasks();
      expect(remainingTasks.isEmpty, true);
    });

    test('deleteTaskWithChildren() deletes single task with no children', () async {
      final task = await taskService.createTask('Single Task');

      final deletedCount = await taskService.deleteTaskWithChildren(task.id);

      expect(deletedCount, 1);

      final remainingTasks = await taskService.getAllTasks();
      expect(remainingTasks.isEmpty, true);
    });

    test('deleteTaskWithChildren() does not affect unrelated tasks', () async {
      // Create two separate hierarchies
      final parent1 = await taskService.createTask('Parent1');
      final child1 = await taskService.createTask('Child1');

      final parent2 = await taskService.createTask('Parent2');
      final child2 = await taskService.createTask('Child2');

      await taskService.updateTaskParent(child1.id, parent1.id, 0);
      await taskService.updateTaskParent(child2.id, parent2.id, 0);

      // Delete first hierarchy
      await taskService.deleteTaskWithChildren(parent1.id);

      // Verify second hierarchy intact
      final remaining = await taskService.getAllTasks();
      expect(remaining.length, 2);
      expect(remaining.any((t) => t.id == parent2.id), true);
      expect(remaining.any((t) => t.id == child2.id), true);
    });
  });

  group('TaskService - Edge Cases', () {
    test('getTaskHierarchy() handles multiple root tasks', () async {
      final root1 = await taskService.createTask('Root 1');
      final root2 = await taskService.createTask('Root 2');
      final root3 = await taskService.createTask('Root 3');

      final tasks = await taskService.getTaskHierarchy();

      expect(tasks.length, 3);
      expect(tasks.where((t) => t.depth == 0).length, 3);
      expect(tasks.any((t) => t.id == root1.id), true);
      expect(tasks.any((t) => t.id == root2.id), true);
      expect(tasks.any((t) => t.id == root3.id), true);
    });

    test('updateTaskParent() updates descendants depth recursively', () async {
      // Create Root1 → Child → Grandchild
      final root1 = await taskService.createTask('Root1');
      final child = await taskService.createTask('Child');
      final grandchild = await taskService.createTask('Grandchild');

      await taskService.updateTaskParent(child.id, root1.id, 0);
      await taskService.updateTaskParent(grandchild.id, child.id, 0);

      // Create Root2
      final root2 = await taskService.createTask('Root2');

      // Move Child from Root1 to Root2 (grandchild should follow)
      await taskService.updateTaskParent(child.id, root2.id, 0);

      // Verify depths updated
      final tasks = await taskService.getTaskHierarchy();
      final updatedChild = tasks.firstWhere((t) => t.id == child.id);
      final updatedGrandchild = tasks.firstWhere((t) => t.id == grandchild.id);

      expect(updatedChild.depth, 1);
      expect(updatedGrandchild.depth, 2);
    });

    test('Sibling reordering with multiple tasks', () async {
      // Create Parent → [Child1, Child2, Child3]
      final parent = await taskService.createTask('Parent');
      final child1 = await taskService.createTask('Child1');
      final child2 = await taskService.createTask('Child2');
      final child3 = await taskService.createTask('Child3');

      await taskService.updateTaskParent(child1.id, parent.id, 0);
      await taskService.updateTaskParent(child2.id, parent.id, 1);
      await taskService.updateTaskParent(child3.id, parent.id, 2);

      // Move Child3 to position 0
      await taskService.updateTaskParent(child3.id, parent.id, 0);

      // Verify all siblings reindexed correctly
      final tasks = await taskService.getTaskHierarchy();
      final updated1 = tasks.firstWhere((t) => t.id == child1.id);
      final updated2 = tasks.firstWhere((t) => t.id == child2.id);
      final updated3 = tasks.firstWhere((t) => t.id == child3.id);

      expect(updated3.position, 0);
      expect(updated1.position, 1);
      expect(updated2.position, 2);
    });
  });
}
