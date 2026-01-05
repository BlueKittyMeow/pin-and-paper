import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import '../helpers/test_database_helper.dart';

void main() {
  // Initialize sqflite_common_ffi once for all tests
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskService taskService;
  late Database testDb;

  setUp(() async {
    // Create a fresh test database for each test
    testDb = await TestDatabaseHelper.createTestDatabase();

    // Inject the test database into DatabaseService
    DatabaseService.setTestDatabase(testDb);

    // CRITICAL FIX: Clear all data from previous tests
    // In-memory databases with different paths may share data in sqflite_ffi
    await TestDatabaseHelper.clearAllData(testDb);

    // Create TaskService (it will use the injected test database)
    taskService = TaskService();
  });

  tearDown() async {
    // Clean up after each test - close the database to destroy in-memory data
    await TestDatabaseHelper.closeDatabase();
    await DatabaseService.resetDatabase();
  }

  group('TaskService - Hierarchical Query Methods', () {
    test('getTaskHierarchy() returns tasks with correct depth', () async {
      // Create hierarchy: Root → Child → Grandchild
      final root = await taskService.createTask('Root Task');
      final child = await taskService.createTask('Child Task');
      final grandchild = await taskService.createTask('Grandchild Task');

      // Nest child under root
      final error1 = await taskService.updateTaskParent(child.id, root.id, 0);
      expect(error1, isNull, reason: 'Should successfully nest child under root');

      // Nest grandchild under child
      final error2 = await taskService.updateTaskParent(grandchild.id, child.id, 0);
      expect(error2, isNull, reason: 'Should successfully nest grandchild under child');

      // Get hierarchy
      final tasks = await taskService.getTaskHierarchy();

      // Find each task in the result
      final rootResult = tasks.firstWhere((t) => t.id == root.id);
      final childResult = tasks.firstWhere((t) => t.id == child.id);
      final grandchildResult = tasks.firstWhere((t) => t.id == grandchild.id);

      // Verify depths
      expect(rootResult.depth, 0, reason: 'Root task should have depth 0');
      expect(childResult.depth, 1, reason: 'Child task should have depth 1');
      expect(grandchildResult.depth, 2, reason: 'Grandchild task should have depth 2');
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
      expect(children.length, 2, reason: 'Parent should have 2 direct children');
      expect(children.any((t) => t.id == child1.id), true, reason: 'Child1 should be included');
      expect(children.any((t) => t.id == child2.id), true, reason: 'Child2 should be included');
      expect(children.any((t) => t.id == grandchild.id), false, reason: 'Grandchild should NOT be included');
    });

    test('getTaskWithChildren() returns empty list if no children', () async {
      final task = await taskService.createTask('Single Task');

      final result = await taskService.getTaskWithChildren(task.id);

      expect(result.isEmpty, true, reason: 'Childless task should return empty list');
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

      expect(count, 3, reason: 'Parent should have 3 descendants (2 children + 1 grandchild)');
    });

    test('countDescendants() returns 0 for childless tasks', () async {
      final task = await taskService.createTask('Childless Task');

      final count = await taskService.countDescendants(task.id);

      expect(count, 0, reason: 'Childless task should have 0 descendants');
    });
  });

  group('TaskService - Parent Update Methods', () {
    test('updateTaskParent() successfully nests task', () async {
      // Create two root tasks
      final taskA = await taskService.createTask('Task A');
      final taskB = await taskService.createTask('Task B');

      // Nest TaskB under TaskA
      final error = await taskService.updateTaskParent(taskB.id, taskA.id, 0);

      expect(error, isNull, reason: 'Nesting should succeed without error');

      // Verify the change
      final tasks = await taskService.getTaskHierarchy();
      final updatedB = tasks.firstWhere((t) => t.id == taskB.id);

      expect(updatedB.parentId, taskA.id, reason: 'TaskB should have TaskA as parent');
      expect(updatedB.position, 0, reason: 'TaskB should be at position 0');
      expect(updatedB.depth, 1, reason: 'TaskB should have depth 1');
    });

    test('updateTaskParent() successfully unnests task', () async {
      // Create hierarchy: Parent → Child
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');

      await taskService.updateTaskParent(child.id, parent.id, 0);

      // Unnest child (make it root)
      final error = await taskService.updateTaskParent(child.id, null, 0);

      expect(error, isNull, reason: 'Unnesting should succeed without error');

      // Verify the change
      final tasks = await taskService.getTaskHierarchy();
      final updatedChild = tasks.firstWhere((t) => t.id == child.id);

      expect(updatedChild.parentId, isNull, reason: 'Child should have no parent');
      expect(updatedChild.depth, 0, reason: 'Child should have depth 0');
    });

    test('updateTaskParent() prevents circular reference', () async {
      // Create hierarchy: Parent → Child
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');

      await taskService.updateTaskParent(child.id, parent.id, 0);

      // Try to make parent a child of child (circular)
      final error = await taskService.updateTaskParent(parent.id, child.id, 0);

      expect(error, isNotNull, reason: 'Circular reference should be prevented');
      expect(error!.toLowerCase().contains('circular'), true, reason: 'Error should mention circular dependency');

      // Verify nothing changed
      final tasks = await taskService.getTaskHierarchy();
      final unchangedParent = tasks.firstWhere((t) => t.id == parent.id);

      expect(unchangedParent.parentId, isNull, reason: 'Parent should still be root');
      expect(unchangedParent.depth, 0, reason: 'Parent should still have depth 0');
    });

    test('updateTaskParent() enforces max depth limit', () async {
      // Create 4-level hierarchy (max allowed: depths 0, 1, 2, 3)
      final level0 = await taskService.createTask('Level 0');
      final level1 = await taskService.createTask('Level 1');
      final level2 = await taskService.createTask('Level 2');
      final level3 = await taskService.createTask('Level 3');
      final level4 = await taskService.createTask('Level 4');

      await taskService.updateTaskParent(level1.id, level0.id, 0);
      await taskService.updateTaskParent(level2.id, level1.id, 0);
      await taskService.updateTaskParent(level3.id, level2.id, 0);

      // Try to create level 5 (depth 4) - should fail
      final error = await taskService.updateTaskParent(level4.id, level3.id, 0);

      expect(error, isNotNull, reason: 'Exceeding max depth should be prevented');
      expect(error!.toLowerCase().contains('depth'), true, reason: 'Error should mention depth limit');

      // Verify level4 remains a root task
      final tasks = await taskService.getTaskHierarchy();
      final unchangedLevel4 = tasks.firstWhere((t) => t.id == level4.id);

      expect(unchangedLevel4.parentId, isNull, reason: 'Level4 should still be root');
      expect(unchangedLevel4.depth, 0, reason: 'Level4 should still have depth 0');
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

      expect(deletedCount, 4, reason: 'Should delete parent + 2 children + 1 grandchild = 4 tasks');

      // Verify all are deleted
      final remainingTasks = await taskService.getAllTasks();
      expect(remainingTasks.isEmpty, true, reason: 'All tasks should be deleted');
    });

    test('deleteTaskWithChildren() deletes single task with no children', () async {
      final task = await taskService.createTask('Single Task');

      final deletedCount = await taskService.deleteTaskWithChildren(task.id);

      expect(deletedCount, 1, reason: 'Should delete exactly 1 task');

      final remainingTasks = await taskService.getAllTasks();
      expect(remainingTasks.isEmpty, true, reason: 'Task should be deleted');
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
      expect(remaining.length, 2, reason: 'Second hierarchy should remain (2 tasks)');
      expect(remaining.any((t) => t.id == parent2.id), true, reason: 'Parent2 should still exist');
      expect(remaining.any((t) => t.id == child2.id), true, reason: 'Child2 should still exist');
    });
  });

  group('TaskService - Edge Cases', () {
    test('getTaskHierarchy() handles multiple root tasks', () async {
      final root1 = await taskService.createTask('Root 1');
      final root2 = await taskService.createTask('Root 2');
      final root3 = await taskService.createTask('Root 3');

      final tasks = await taskService.getTaskHierarchy();

      expect(tasks.length, 3, reason: 'Should have 3 root tasks');
      expect(tasks.where((t) => t.depth == 0).length, 3, reason: 'All should have depth 0');
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

      // Verify depths updated correctly
      final tasks = await taskService.getTaskHierarchy();
      final updatedChild = tasks.firstWhere((t) => t.id == child.id);
      final updatedGrandchild = tasks.firstWhere((t) => t.id == grandchild.id);

      expect(updatedChild.depth, 1, reason: 'Child should now have depth 1 (under Root2)');
      expect(updatedGrandchild.depth, 2, reason: 'Grandchild depth should update recursively to 2');
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

      // Move Child3 to position 0 (should push others down)
      await taskService.updateTaskParent(child3.id, parent.id, 0);

      // Verify all siblings reindexed correctly
      final tasks = await taskService.getTaskHierarchy();
      final updated1 = tasks.firstWhere((t) => t.id == child1.id);
      final updated2 = tasks.firstWhere((t) => t.id == child2.id);
      final updated3 = tasks.firstWhere((t) => t.id == child3.id);

      expect(updated3.position, 0, reason: 'Child3 should be at position 0');
      expect(updated1.position, 1, reason: 'Child1 should be pushed to position 1');
      expect(updated2.position, 2, reason: 'Child2 should be pushed to position 2');
    });
  });
}
