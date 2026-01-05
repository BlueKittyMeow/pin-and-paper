import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import '../helpers/test_database_helper.dart';

/// Comprehensive unit tests for Phase 3.3 soft delete functionality
///
/// Test Coverage:
/// - Soft delete operations (single task, with children)
/// - Restore operations (single task, with children)
/// - Permanent delete operations (validation, cascade)
/// - Query isolation (active tasks vs deleted tasks)
/// - Cascade behavior (hierarchy integrity)
/// - Edge cases (errors, non-existent tasks, state validation)
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskService taskService;
  late Database testDb;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);

    // CRITICAL FIX: Clear all data from previous tests
    // In-memory databases with different paths may share data in sqflite_ffi
    await TestDatabaseHelper.clearAllData(testDb);

    taskService = TaskService();
  });

  tearDown() async {
    await TestDatabaseHelper.closeDatabase();
    await DatabaseService.resetDatabase();
  };

  group('TaskService - Soft Delete Operations', () {
    test('softDeleteTask() soft deletes a single task', () async {
      final task = await taskService.createTask('Task to delete');

      // Verify task exists and is active
      final activeBefore = await taskService.getAllTasks();
      expect(activeBefore.length, 1);
      expect(activeBefore.first.id, task.id);

      // Soft delete the task
      final deletedCount = await taskService.softDeleteTask(task.id);

      expect(deletedCount, 1, reason: 'Should delete exactly 1 task');

      // Verify task no longer appears in active tasks
      final activeAfter = await taskService.getAllTasks();
      expect(activeAfter.length, 0, reason: 'Deleted task should not appear in active list');

      // Verify task appears in recently deleted
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 1, reason: 'Task should appear in deleted list');
      expect(deleted.first.id, task.id);
      expect(deleted.first.deletedAt, isNotNull, reason: 'deleted_at should be set');
    });

    test('softDeleteTask() cascades to all descendants', () async {
      // Create hierarchy: Root → Child → Grandchild
      final root = await taskService.createTask('Root');
      final child = await taskService.createTask('Child');
      final grandchild = await taskService.createTask('Grandchild');

      await taskService.updateTaskParent(child.id, root.id, 0);
      await taskService.updateTaskParent(grandchild.id, child.id, 0);

      // Verify all 3 tasks exist
      final activeBefore = await taskService.getAllTasks();
      expect(activeBefore.length, 3);

      // Soft delete root (should cascade to child and grandchild)
      final deletedCount = await taskService.softDeleteTask(root.id);

      expect(deletedCount, 3, reason: 'Should delete root + 2 descendants = 3 tasks');

      // Verify all tasks removed from active list
      final activeAfter = await taskService.getAllTasks();
      expect(activeAfter.length, 0, reason: 'All tasks should be soft-deleted');

      // Verify all tasks appear in deleted list
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 3, reason: 'All 3 tasks should appear in deleted list');

      final deletedIds = deleted.map((t) => t.id).toSet();
      expect(deletedIds.contains(root.id), true);
      expect(deletedIds.contains(child.id), true);
      expect(deletedIds.contains(grandchild.id), true);

      // All should have same deleted_at timestamp
      final timestamps = deleted.map((t) => t.deletedAt).toSet();
      expect(timestamps.length, 1, reason: 'All tasks should have same deletion timestamp');
    });

    test('softDeleteTask() does not affect sibling tasks', () async {
      // Create two separate hierarchies
      final parent1 = await taskService.createTask('Parent1');
      final child1 = await taskService.createTask('Child1');

      final parent2 = await taskService.createTask('Parent2');
      final child2 = await taskService.createTask('Child2');

      await taskService.updateTaskParent(child1.id, parent1.id, 0);
      await taskService.updateTaskParent(child2.id, parent2.id, 0);

      // Soft delete first hierarchy
      final deletedCount = await taskService.softDeleteTask(parent1.id);
      expect(deletedCount, 2, reason: 'Should delete parent1 and child1');

      // Verify second hierarchy still active
      final active = await taskService.getAllTasks();
      expect(active.length, 2, reason: 'Parent2 and Child2 should still be active');

      final activeIds = active.map((t) => t.id).toSet();
      expect(activeIds.contains(parent2.id), true);
      expect(activeIds.contains(child2.id), true);

      // Verify only first hierarchy in deleted
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 2);

      final deletedIds = deleted.map((t) => t.id).toSet();
      expect(deletedIds.contains(parent1.id), true);
      expect(deletedIds.contains(child1.id), true);
    });
  });

  group('TaskService - Restore Operations', () {
    test('restoreTask() restores a single soft-deleted task', () async {
      final task = await taskService.createTask('Task to restore');

      // Soft delete the task
      await taskService.softDeleteTask(task.id);

      // Verify it's deleted
      final activeBeforeRestore = await taskService.getAllTasks();
      expect(activeBeforeRestore.length, 0);

      // Restore the task
      final restoredCount = await taskService.restoreTask(task.id);

      expect(restoredCount, 1, reason: 'Should restore exactly 1 task');

      // Verify task reappears in active list
      final activeAfterRestore = await taskService.getAllTasks();
      expect(activeAfterRestore.length, 1);
      expect(activeAfterRestore.first.id, task.id);
      expect(activeAfterRestore.first.deletedAt, isNull, reason: 'deleted_at should be NULL');

      // Verify task no longer in deleted list
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 0, reason: 'Restored task should not appear in deleted list');
    });

    test('restoreTask() cascades to all descendants', () async {
      // Create hierarchy: Root → Child → Grandchild
      final root = await taskService.createTask('Root');
      final child = await taskService.createTask('Child');
      final grandchild = await taskService.createTask('Grandchild');

      await taskService.updateTaskParent(child.id, root.id, 0);
      await taskService.updateTaskParent(grandchild.id, child.id, 0);

      // Soft delete entire hierarchy
      await taskService.softDeleteTask(root.id);

      // Verify all deleted
      final activeBeforeRestore = await taskService.getAllTasks();
      expect(activeBeforeRestore.length, 0);

      // Restore root (should cascade to children)
      final restoredCount = await taskService.restoreTask(root.id);

      expect(restoredCount, 3, reason: 'Should restore root + 2 descendants = 3 tasks');

      // Verify all tasks restored to active list
      final activeAfterRestore = await taskService.getAllTasks();
      expect(activeAfterRestore.length, 3);

      final activeIds = activeAfterRestore.map((t) => t.id).toSet();
      expect(activeIds.contains(root.id), true);
      expect(activeIds.contains(child.id), true);
      expect(activeIds.contains(grandchild.id), true);

      // All should have deleted_at = NULL
      for (final task in activeAfterRestore) {
        expect(task.deletedAt, isNull, reason: 'All restored tasks should have deleted_at = NULL');
      }

      // Verify hierarchy preserved
      final hierarchy = await taskService.getTaskHierarchy();
      final rootResult = hierarchy.firstWhere((t) => t.id == root.id);
      final childResult = hierarchy.firstWhere((t) => t.id == child.id);
      final grandchildResult = hierarchy.firstWhere((t) => t.id == grandchild.id);

      expect(rootResult.depth, 0);
      expect(childResult.depth, 1);
      expect(grandchildResult.depth, 2);
    });

    test('restoreTask() does not affect other deleted tasks', () async {
      final task1 = await taskService.createTask('Task 1');
      final task2 = await taskService.createTask('Task 2');
      final task3 = await taskService.createTask('Task 3');

      // Soft delete all 3
      await taskService.softDeleteTask(task1.id);
      await taskService.softDeleteTask(task2.id);
      await taskService.softDeleteTask(task3.id);

      // Verify all deleted
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 3);

      // Restore only task2
      await taskService.restoreTask(task2.id);

      // Verify task2 active, others still deleted
      final active = await taskService.getAllTasks();
      expect(active.length, 1);
      expect(active.first.id, task2.id);

      final stillDeleted = await taskService.getRecentlyDeletedTasks();
      expect(stillDeleted.length, 2);

      final deletedIds = stillDeleted.map((t) => t.id).toSet();
      expect(deletedIds.contains(task1.id), true);
      expect(deletedIds.contains(task3.id), true);
    });

    test('softDeleteTask() then restoreTask() round trip preserves task data', () async {
      // Create task with full data
      final original = await taskService.createTask('Task with data');

      // Store original properties
      final originalId = original.id;
      final originalTitle = original.title;
      final originalCreatedAt = original.createdAt;

      // Soft delete
      await taskService.softDeleteTask(original.id);

      // Restore
      await taskService.restoreTask(original.id);

      // Verify all data preserved
      final restored = await taskService.getAllTasks();
      expect(restored.length, 1);

      final task = restored.first;
      expect(task.id, originalId, reason: 'ID should be preserved');
      expect(task.title, originalTitle, reason: 'Title should be preserved');
      // Compare milliseconds since SQLite stores timestamps as milliseconds (microseconds are truncated)
      expect(task.createdAt.millisecondsSinceEpoch, originalCreatedAt.millisecondsSinceEpoch,
        reason: 'Created timestamp should be preserved (millisecond precision)');
      expect(task.deletedAt, isNull, reason: 'deleted_at should be NULL after restore');
      expect(task.completed, false, reason: 'Completed status should be preserved');
    });
  });

  group('TaskService - Permanent Delete Operations', () {
    test('permanentlyDeleteTask() hard deletes a soft-deleted task', () async {
      final task = await taskService.createTask('Task to permanently delete');

      // Soft delete first
      await taskService.softDeleteTask(task.id);

      // Verify in deleted list
      final deletedBefore = await taskService.getRecentlyDeletedTasks();
      expect(deletedBefore.length, 1);

      // Permanently delete
      final permanentlyDeletedCount = await taskService.permanentlyDeleteTask(task.id);

      expect(permanentlyDeletedCount, 1, reason: 'Should permanently delete 1 task');

      // Verify task no longer exists anywhere
      final active = await taskService.getAllTasks();
      expect(active.length, 0);

      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 0, reason: 'Task should be completely removed');
    });

    test('permanentlyDeleteTask() throws error for active (non-deleted) task', () async {
      final task = await taskService.createTask('Active task');

      // Attempt to permanently delete without soft-deleting first
      expect(
        () => taskService.permanentlyDeleteTask(task.id),
        throwsA(isA<StateError>()),
        reason: 'Should throw StateError when trying to permanently delete active task',
      );

      // Verify task still exists and is active
      final active = await taskService.getAllTasks();
      expect(active.length, 1);
      expect(active.first.id, task.id);
    });

    test('permanentlyDeleteTask() throws error for non-existent task', () async {
      expect(
        () => taskService.permanentlyDeleteTask('non-existent-id'),
        throwsA(isA<StateError>()),
        reason: 'Should throw StateError for non-existent task',
      );
    });

    test('permanentlyDeleteTask() cascades to soft-deleted descendants', () async {
      // Create hierarchy
      final root = await taskService.createTask('Root');
      final child = await taskService.createTask('Child');
      final grandchild = await taskService.createTask('Grandchild');

      await taskService.updateTaskParent(child.id, root.id, 0);
      await taskService.updateTaskParent(grandchild.id, child.id, 0);

      // Soft delete entire hierarchy
      await taskService.softDeleteTask(root.id);

      // Permanently delete root (should cascade to children via FK constraint)
      final deletedCount = await taskService.permanentlyDeleteTask(root.id);

      expect(deletedCount, 3, reason: 'Should permanently delete all 3 tasks via CASCADE');

      // Verify all tasks completely gone
      final active = await taskService.getAllTasks();
      expect(active.length, 0);

      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 0, reason: 'All tasks should be permanently deleted');
    });
  });

  group('TaskService - Query Isolation', () {
    test('getAllTasks() excludes soft-deleted tasks', () async {
      final task1 = await taskService.createTask('Active Task');
      final task2 = await taskService.createTask('Deleted Task');

      // Soft delete task2
      await taskService.softDeleteTask(task2.id);

      // getAllTasks should only return active task
      final active = await taskService.getAllTasks();
      expect(active.length, 1);
      expect(active.first.id, task1.id);
    });

    test('getTaskHierarchy() excludes soft-deleted tasks', () async {
      // Create hierarchy
      final root = await taskService.createTask('Root');
      final child1 = await taskService.createTask('Active Child');
      final child2 = await taskService.createTask('Deleted Child');

      await taskService.updateTaskParent(child1.id, root.id, 0);
      await taskService.updateTaskParent(child2.id, root.id, 1);

      // Soft delete child2
      await taskService.softDeleteTask(child2.id);

      // getTaskHierarchy should only return root and child1
      final hierarchy = await taskService.getTaskHierarchy();
      expect(hierarchy.length, 2);

      final ids = hierarchy.map((t) => t.id).toSet();
      expect(ids.contains(root.id), true);
      expect(ids.contains(child1.id), true);
      expect(ids.contains(child2.id), false, reason: 'Deleted child should be excluded');
    });

    test('getTaskWithChildren() excludes soft-deleted children', () async {
      final parent = await taskService.createTask('Parent');
      final child1 = await taskService.createTask('Active Child');
      final child2 = await taskService.createTask('Deleted Child');

      await taskService.updateTaskParent(child1.id, parent.id, 0);
      await taskService.updateTaskParent(child2.id, parent.id, 1);

      // Soft delete child2
      await taskService.softDeleteTask(child2.id);

      // getTaskWithChildren should only return child1
      final children = await taskService.getTaskWithChildren(parent.id);
      expect(children.length, 1);
      expect(children.first.id, child1.id);
    });

    test('createTask() position calculation ignores soft-deleted tasks', () async {
      // Create 3 root tasks
      final task1 = await taskService.createTask('Task 1');
      final task2 = await taskService.createTask('Task 2');
      final task3 = await taskService.createTask('Task 3');

      // Positions should be 0, 1, 2
      expect(task1.position, 0);
      expect(task2.position, 1);
      expect(task3.position, 2);

      // Soft delete task2 (position 1)
      await taskService.softDeleteTask(task2.id);

      // Create new task - should get position 2 (ignoring deleted task's position)
      final task4 = await taskService.createTask('Task 4');

      // Position should be 3 (max of active tasks is 2, so 2 + 1 = 3)
      expect(task4.position, 3, reason: 'Should calculate position from active tasks only');

      // Verify active tasks have positions 0, 2, 3 (gap at 1 from deleted task)
      final active = await taskService.getAllTasks();
      expect(active.length, 3);
    });
  });

  group('TaskService - Recently Deleted Query', () {
    test('getRecentlyDeletedTasks() returns only soft-deleted tasks', () async {
      final active = await taskService.createTask('Active Task');
      final deleted = await taskService.createTask('Deleted Task');

      await taskService.softDeleteTask(deleted.id);

      final recentlyDeleted = await taskService.getRecentlyDeletedTasks();
      expect(recentlyDeleted.length, 1);
      expect(recentlyDeleted.first.id, deleted.id);
      expect(recentlyDeleted.first.deletedAt, isNotNull);
    });

    test('getRecentlyDeletedTasks() includes hierarchy information', () async {
      // Create hierarchy
      final root = await taskService.createTask('Root');
      final child = await taskService.createTask('Child');

      await taskService.updateTaskParent(child.id, root.id, 0);

      // Soft delete entire hierarchy
      await taskService.softDeleteTask(root.id);

      // Query deleted tasks
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 2);

      // Find tasks by ID and verify depth
      final rootResult = deleted.firstWhere((t) => t.id == root.id);
      final childResult = deleted.firstWhere((t) => t.id == child.id);

      expect(rootResult.depth, 0, reason: 'Root should have depth 0');
      expect(childResult.depth, 1, reason: 'Child should have depth 1');
    });

    test('getRecentlyDeletedTasks() orders by deletion time (most recent first)', () async {
      // Create and delete tasks one by one with small delays
      final task1 = await taskService.createTask('Deleted First');
      await taskService.softDeleteTask(task1.id);

      await Future.delayed(Duration(milliseconds: 10));

      final task2 = await taskService.createTask('Deleted Second');
      await taskService.softDeleteTask(task2.id);

      await Future.delayed(Duration(milliseconds: 10));

      final task3 = await taskService.createTask('Deleted Third');
      await taskService.softDeleteTask(task3.id);

      // Query should return most recent first
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 3);

      // Most recent deletion should be first
      expect(deleted[0].id, task3.id, reason: 'Most recently deleted should be first');
      expect(deleted[1].id, task2.id);
      expect(deleted[2].id, task1.id, reason: 'Oldest deletion should be last');

      // Verify timestamps are ordered (most recent first)
      expect(deleted[0].deletedAt!.millisecondsSinceEpoch >= deleted[1].deletedAt!.millisecondsSinceEpoch, true);
      expect(deleted[1].deletedAt!.millisecondsSinceEpoch >= deleted[2].deletedAt!.millisecondsSinceEpoch, true);
    });

    test('getRecentlyDeletedTasks() returns empty list when no deleted tasks', () async {
      await taskService.createTask('Active Task 1');
      await taskService.createTask('Active Task 2');

      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 0);
    });
  });

  group('TaskService - Edge Cases', () {
    test('softDeleteTask() on already deleted task updates timestamp', () async {
      final task = await taskService.createTask('Task');

      // First soft delete
      await taskService.softDeleteTask(task.id);
      final deleted1 = await taskService.getRecentlyDeletedTasks();
      final timestamp1 = deleted1.first.deletedAt!;

      await Future.delayed(Duration(milliseconds: 10));

      // Second soft delete (should update timestamp)
      await taskService.softDeleteTask(task.id);
      final deleted2 = await taskService.getRecentlyDeletedTasks();
      final timestamp2 = deleted2.first.deletedAt!;

      expect(timestamp2.millisecondsSinceEpoch > timestamp1.millisecondsSinceEpoch, true, reason: 'Timestamp should be updated');
    });

    test('restoreTask() on already active task is idempotent', () async {
      final task = await taskService.createTask('Task');

      // Restore without deleting first (task is already active)
      final restoredCount = await taskService.restoreTask(task.id);

      // Should return 1 (task found and processed)
      expect(restoredCount, 1);

      // Task should still be active
      final active = await taskService.getAllTasks();
      expect(active.length, 1);
      expect(active.first.id, task.id);
      expect(active.first.deletedAt, isNull);
    });

    test('Soft deleting child, then parent, maintains deletion timestamps', () async {
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');

      await taskService.updateTaskParent(child.id, parent.id, 0);

      // Delete child first
      await taskService.softDeleteTask(child.id);
      final deleted1 = await taskService.getRecentlyDeletedTasks();
      final childTimestamp1 = deleted1.first.deletedAt!;

      await Future.delayed(Duration(milliseconds: 10));

      // Delete parent (child already deleted, should update its timestamp)
      await taskService.softDeleteTask(parent.id);

      final deleted2 = await taskService.getRecentlyDeletedTasks();
      expect(deleted2.length, 2);

      final parentResult = deleted2.firstWhere((t) => t.id == parent.id);
      final childResult = deleted2.firstWhere((t) => t.id == child.id);

      // Both should have same timestamp from parent deletion
      expect(parentResult.deletedAt, childResult.deletedAt);
      expect(childResult.deletedAt!.millisecondsSinceEpoch > childTimestamp1.millisecondsSinceEpoch, true,
        reason: 'Child timestamp should be updated to match parent deletion');
    });

    test('countDescendants() counts only active (non-deleted) descendants', () async {
      final parent = await taskService.createTask('Parent');
      final child1 = await taskService.createTask('Active Child');
      final child2 = await taskService.createTask('Deleted Child');

      await taskService.updateTaskParent(child1.id, parent.id, 0);
      await taskService.updateTaskParent(child2.id, parent.id, 1);

      // Count before deletion
      final countBefore = await taskService.countDescendants(parent.id);
      expect(countBefore, 2);

      // Soft delete one child
      await taskService.softDeleteTask(child2.id);

      // Count after deletion (should only count active descendants)
      final countAfter = await taskService.countDescendants(parent.id);
      expect(countAfter, 1, reason: 'Should only count active descendants');
    });
  });

  group('TaskService - Ancestor Restore (Regression Tests)', () {
    test('restoreTask() on deep child restores entire ancestor chain', () async {
      // Regression test for Bug #3: Restoring child without parent shows nothing
      // Create 3-level hierarchy: Root → Parent → Child
      final root = await taskService.createTask('Root');
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');

      await taskService.updateTaskParent(parent.id, root.id, 0);
      await taskService.updateTaskParent(child.id, parent.id, 0);

      // Soft delete entire chain
      await taskService.softDeleteTask(root.id);

      // Verify all are deleted
      final activeBefore = await taskService.getAllTasks();
      expect(activeBefore.length, 0, reason: 'All tasks should be deleted');

      final deletedBefore = await taskService.getRecentlyDeletedTasks();
      expect(deletedBefore.length, 3, reason: 'All 3 tasks in trash');

      // CRITICAL: Restore only the grandchild
      final restoredCount = await taskService.restoreTask(child.id);

      // Verify ALL ancestors were also restored
      final activeAfter = await taskService.getAllTasks();
      expect(activeAfter.length, 3, reason: 'All 3 tasks should be restored');

      final activeIds = activeAfter.map((t) => t.id).toSet();
      expect(activeIds.contains(root.id), true, reason: 'Root should be restored');
      expect(activeIds.contains(parent.id), true, reason: 'Parent should be restored');
      expect(activeIds.contains(child.id), true, reason: 'Child should be restored');

      // Verify none remain in trash
      final deletedAfter = await taskService.getRecentlyDeletedTasks();
      expect(deletedAfter.length, 0, reason: 'Trash should be empty');

      expect(restoredCount, greaterThanOrEqualTo(3),
          reason: 'Should restore at least child + parent + root');
    });

    test('restoreTask() on middle task restores ancestors AND descendants', () async {
      // Create 3-level hierarchy: Root → Middle → Leaf
      final root = await taskService.createTask('Root');
      final middle = await taskService.createTask('Middle');
      final leaf = await taskService.createTask('Leaf');

      await taskService.updateTaskParent(middle.id, root.id, 0);
      await taskService.updateTaskParent(leaf.id, middle.id, 0);

      // Delete entire chain
      await taskService.softDeleteTask(root.id);

      // Restore middle task
      await taskService.restoreTask(middle.id);

      // Verify all 3 are restored (ancestors UP + descendants DOWN)
      final activeAfter = await taskService.getAllTasks();
      expect(activeAfter.length, 3, reason: 'Root + Middle + Leaf should all be restored');

      final activeIds = activeAfter.map((t) => t.id).toSet();
      expect(activeIds.contains(root.id), true);
      expect(activeIds.contains(middle.id), true);
      expect(activeIds.contains(leaf.id), true);
    });
  });

  group('TaskService - Auto-Cleanup', () {
    test('cleanupExpiredDeletedTasks() removes tasks older than 30 days', () async {
      // Create test tasks
      final oldTask = await taskService.createTask('Old Task');
      final recentTask = await taskService.createTask('Recent Task');

      // Soft delete both
      await taskService.softDeleteTask(oldTask.id);
      await taskService.softDeleteTask(recentTask.id);

      // Manually age the old task's deleted_at timestamp to 31 days ago
      final thirtyOneDaysAgo =
          DateTime.now().subtract(const Duration(days: 31)).millisecondsSinceEpoch;

      await testDb.rawUpdate(
        'UPDATE tasks SET deleted_at = ? WHERE id = ?',
        [thirtyOneDaysAgo, oldTask.id],
      );

      // Verify both tasks are in trash
      final deletedBefore = await taskService.getRecentlyDeletedTasks();
      expect(deletedBefore.length, 2, reason: 'Both tasks should be in trash');

      // Run cleanup (should remove task > 30 days old)
      final cleanedCount = await taskService.cleanupExpiredDeletedTasks();

      expect(cleanedCount, 1, reason: 'Should remove exactly 1 expired task');

      // Verify only recent task remains
      final deletedAfter = await taskService.getRecentlyDeletedTasks();
      expect(deletedAfter.length, 1, reason: 'Only recent task should remain');
      expect(deletedAfter.first.id, recentTask.id,
          reason: 'Recent task should be the one remaining');

      // Verify old task is permanently gone (not in active OR deleted)
      final allTasks = await testDb.query('tasks');
      final taskIds = allTasks.map((t) => t['id'] as String).toSet();
      expect(taskIds.contains(oldTask.id), false,
          reason: 'Old task should be permanently deleted');
      expect(taskIds.contains(recentTask.id), true,
          reason: 'Recent task should still exist');
    });

    test('cleanupExpiredDeletedTasks() returns 0 when no expired tasks', () async {
      final task = await taskService.createTask('Recent Task');
      await taskService.softDeleteTask(task.id);

      // Run cleanup (no tasks are old enough)
      final cleanedCount = await taskService.cleanupExpiredDeletedTasks();

      expect(cleanedCount, 0, reason: 'No tasks should be cleaned');

      // Verify task still exists
      final deleted = await taskService.getRecentlyDeletedTasks();
      expect(deleted.length, 1, reason: 'Recent task should remain');
    });

    test('cleanupExpiredDeletedTasks() cascades to expired descendants', () async {
      // Create hierarchy
      final root = await taskService.createTask('Old Root');
      final child = await taskService.createTask('Old Child');
      await taskService.updateTaskParent(child.id, root.id, 0);

      // Delete hierarchy
      await taskService.softDeleteTask(root.id);

      // Age both to > 30 days
      final thirtyOneDaysAgo =
          DateTime.now().subtract(const Duration(days: 31)).millisecondsSinceEpoch;

      await testDb.rawUpdate(
        'UPDATE tasks SET deleted_at = ? WHERE deleted_at IS NOT NULL',
        [thirtyOneDaysAgo],
      );

      // Run cleanup
      final cleanedCount = await taskService.cleanupExpiredDeletedTasks();

      expect(cleanedCount, 2, reason: 'Should remove both root and child');

      // Verify both are permanently gone
      final allTasks = await testDb.query('tasks');
      expect(allTasks.length, 0, reason: 'All tasks should be permanently deleted');
    });
  });
}
