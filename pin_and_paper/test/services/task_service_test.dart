import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:pin_and_paper/models/filter_state.dart'; // Phase 3.6A
import 'package:pin_and_paper/models/task_suggestion.dart'; // Phase 2
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/tag_service.dart'; // Phase 3.6A
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/utils/constants.dart';
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

  // tearDown removed - TestDatabaseHelper.createTestDatabase() handles cleanup
  // Double-close was causing "database is locked" errors (Gemini Issue #1)

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

  group('TaskService - New-task-top-insert (MIN - 1 position assignment)', () {
    test('createTask(): second task gets a smaller position and sorts first', () async {
      final task1 = await taskService.createTask('First');
      final task2 = await taskService.createTask('Second');

      expect(
        task2.position,
        lessThan(task1.position),
        reason: 'Newer task should get a smaller position (MIN - 1)',
      );

      // Verify the tree/provider-facing order (getTaskHierarchy) shows the
      // newest task first.
      final hierarchy = await taskService.getTaskHierarchy();
      expect(hierarchy.first.id, task2.id, reason: 'Newest task should be first');
      expect(hierarchy.last.id, task1.id, reason: 'Oldest task should be last');
    });

    test('getTaskHierarchy() orders correctly with mixed negative/positive positions and nesting', () async {
      // Exercises the printf fix (getTaskHierarchy: %011d with a +1e9 offset,
      // rather than %05d which mis-sorts negatives). Craft a mix of negative
      // and positive positions across both a root and a nested child - a
      // positive root position can show up from a not-yet-upgraded device
      // still using the old MAX+1 scheme, or simply from manual reordering.
      final rootNeg = await taskService.createTask('Root Negative'); // position 0
      final rootPos = await taskService.createTask('Root Positive'); // position -1
      final child = await taskService.createTask('Child'); // position -2, will be nested

      await testDb.update(
        AppConstants.tasksTable,
        {'position': 5},
        where: 'id = ?',
        whereArgs: [rootPos.id],
      );
      await testDb.update(
        AppConstants.tasksTable,
        {'parent_id': rootNeg.id, 'position': -30},
        where: 'id = ?',
        whereArgs: [child.id],
      );

      final tasks = await taskService.getTaskHierarchy();

      // Roots ascending: rootNeg (0) before rootPos (5)
      final rootIds = tasks.where((t) => t.parentId == null).map((t) => t.id).toList();
      expect(rootIds, [rootNeg.id, rootPos.id]);

      // Child should be nested directly after its parent (only child) despite
      // its own deeply negative position.
      final rootNegIndex = tasks.indexWhere((t) => t.id == rootNeg.id);
      final childIndex = tasks.indexWhere((t) => t.id == child.id);
      expect(
        childIndex,
        rootNegIndex + 1,
        reason: 'Child should immediately follow its parent despite negative position',
      );
      expect(tasks[childIndex].depth, 1);
    });

    test('createMultipleTasks(): approved suggestions appear in order at the top', () async {
      // Seed an existing task so there's a non-trivial minimum to insert above.
      final existing = await taskService.createTask('Existing');

      final suggestions = [
        TaskSuggestion(id: const Uuid().v4(), title: 'Suggestion 1', approved: true),
        TaskSuggestion(id: const Uuid().v4(), title: 'Suggestion 2', approved: false), // not approved
        TaskSuggestion(id: const Uuid().v4(), title: 'Suggestion 3', approved: true),
      ];

      final created = await taskService.createMultipleTasks(suggestions);

      expect(created.length, 2, reason: 'Only approved suggestions should be created');
      expect(created[0].title, 'Suggestion 1');
      expect(created[1].title, 'Suggestion 3');

      // First approved suggestion gets the smallest position (appears first)...
      expect(created[0].position, lessThan(created[1].position));
      // ...and the whole batch sits above the pre-existing task.
      expect(created[1].position, lessThan(existing.position));

      final hierarchy = await taskService.getTaskHierarchy();
      expect(
        hierarchy.map((t) => t.id).toList(),
        [created[0].id, created[1].id, existing.id],
        reason: 'Batch should display top-most-first, above existing tasks',
      );
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

  group('getFilteredTasks (Phase 3.6A)', () {
    late TagService tagService;

    setUp(() {
      tagService = TagService();
    });

    test('returns all tasks when filter is inactive', () async {
      final task1 = await taskService.createTask('Task 1');
      final task2 = await taskService.createTask('Task 2');

      final filter = FilterState.empty; // No filter
      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 2);
      expect(tasks.map((t) => t.id), containsAll([task1.id, task2.id]));
    });

    test('filters by completed status', () async {
      final task1 = await taskService.createTask('Active Task');
      final task2 = await taskService.createTask('Completed Task');
      await taskService.toggleTaskCompletion(task2);

      final filter = FilterState.empty;

      // Get active tasks
      final activeTasks = await taskService.getFilteredTasks(filter, completed: false);
      expect(activeTasks.length, 1);
      expect(activeTasks.first.id, task1.id);

      // Get completed tasks
      final completedTasks = await taskService.getFilteredTasks(filter, completed: true);
      expect(completedTasks.length, 1);
      expect(completedTasks.first.id, task2.id);
    });

    test('excludes soft-deleted tasks', () async {
      final task1 = await taskService.createTask('Active Task');
      final task2 = await taskService.createTask('Deleted Task');
      await taskService.softDeleteTask(task2.id);

      final filter = FilterState.empty;
      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 1);
      expect(tasks.first.id, task1.id);
    });

    test('OR logic: returns tasks with ANY of the selected tags', () async {
      final tag1 = await tagService.createTag('work');
      final tag2 = await tagService.createTag('urgent');

      final task1 = await taskService.createTask('Task 1');
      final task2 = await taskService.createTask('Task 2');
      final task3 = await taskService.createTask('Task 3');

      await tagService.addTagToTask(task1.id, tag1.id); // Has work
      await tagService.addTagToTask(task2.id, tag2.id); // Has urgent
      // task3 has no tags

      final filter = FilterState(
        selectedTagIds: [tag1.id, tag2.id],
        logic: FilterLogic.or,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 2);
      expect(tasks.map((t) => t.id), containsAll([task1.id, task2.id]));
      expect(tasks.map((t) => t.id), isNot(contains(task3.id)));
    });

    test('AND logic: returns tasks with ALL of the selected tags', () async {
      final tag1 = await tagService.createTag('work');
      final tag2 = await tagService.createTag('urgent');

      final task1 = await taskService.createTask('Task 1');
      final task2 = await taskService.createTask('Task 2');
      final task3 = await taskService.createTask('Task 3');

      await tagService.addTagToTask(task1.id, tag1.id); // Only work
      await tagService.addTagToTask(task2.id, tag1.id); // Both work and urgent
      await tagService.addTagToTask(task2.id, tag2.id);
      await tagService.addTagToTask(task3.id, tag2.id); // Only urgent

      final filter = FilterState(
        selectedTagIds: [tag1.id, tag2.id],
        logic: FilterLogic.and,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 1);
      expect(tasks.first.id, task2.id); // Only task2 has both tags
    });

    test('onlyTagged: returns only tasks with at least one tag', () async {
      final tag = await tagService.createTag('work');

      final task1 = await taskService.createTask('Tagged Task');
      final task2 = await taskService.createTask('Untagged Task');

      await tagService.addTagToTask(task1.id, tag.id);

      final filter = FilterState(
        presenceFilter: TagPresenceFilter.onlyTagged,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 1);
      expect(tasks.first.id, task1.id);
    });

    test('onlyUntagged: returns only tasks with no tags', () async {
      final tag = await tagService.createTag('work');

      final task1 = await taskService.createTask('Tagged Task');
      final task2 = await taskService.createTask('Untagged Task');

      await tagService.addTagToTask(task1.id, tag.id);

      final filter = FilterState(
        presenceFilter: TagPresenceFilter.onlyUntagged,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 1);
      expect(tasks.first.id, task2.id);
    });

    test('single tag filter works correctly', () async {
      final tag = await tagService.createTag('work');

      final task1 = await taskService.createTask('Task 1');
      final task2 = await taskService.createTask('Task 2');

      await tagService.addTagToTask(task1.id, tag.id);

      final filter = FilterState(
        selectedTagIds: [tag.id],
        logic: FilterLogic.or,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 1);
      expect(tasks.first.id, task1.id);
    });

    test('returns empty list when no tasks match filter', () async {
      final tag = await tagService.createTag('work');

      await taskService.createTask('Untagged Task 1');
      await taskService.createTask('Untagged Task 2');

      final filter = FilterState(
        selectedTagIds: [tag.id],
        logic: FilterLogic.or,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks, isEmpty);
    });

    test('combines tag filter with completed filter correctly', () async {
      final tag = await tagService.createTag('work');

      final task1 = await taskService.createTask('Active with tag');
      final task2 = await taskService.createTask('Completed with tag');
      final task3 = await taskService.createTask('Active without tag');

      await tagService.addTagToTask(task1.id, tag.id);
      await tagService.addTagToTask(task2.id, tag.id);
      await taskService.toggleTaskCompletion(task2);

      final filter = FilterState(
        selectedTagIds: [tag.id],
        logic: FilterLogic.or,
      );

      // Active tasks with tag
      final activeTasks = await taskService.getFilteredTasks(filter, completed: false);
      expect(activeTasks.length, 1);
      expect(activeTasks.first.id, task1.id);

      // Completed tasks with tag
      final completedTasks = await taskService.getFilteredTasks(filter, completed: true);
      expect(completedTasks.length, 1);
      expect(completedTasks.first.id, task2.id);
    });

    test('AND logic with 3+ tags', () async {
      final tag1 = await tagService.createTag('work');
      final tag2 = await tagService.createTag('urgent');
      final tag3 = await tagService.createTag('personal');

      final task1 = await taskService.createTask('Task with all 3 tags');
      final task2 = await taskService.createTask('Task with 2 tags');

      await tagService.addTagToTask(task1.id, tag1.id);
      await tagService.addTagToTask(task1.id, tag2.id);
      await tagService.addTagToTask(task1.id, tag3.id);

      await tagService.addTagToTask(task2.id, tag1.id);
      await tagService.addTagToTask(task2.id, tag2.id);

      final filter = FilterState(
        selectedTagIds: [tag1.id, tag2.id, tag3.id],
        logic: FilterLogic.and,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(tasks.length, 1);
      expect(tasks.first.id, task1.id);
    });

    test('tasks are ordered by position', () async {
      final tag = await tagService.createTag('work');

      // Create tasks in specific order
      final task1 = await taskService.createTask('Task 1');
      final task2 = await taskService.createTask('Task 2');
      final task3 = await taskService.createTask('Task 3');

      // Tag all tasks
      await tagService.addTagToTask(task1.id, tag.id);
      await tagService.addTagToTask(task2.id, tag.id);
      await tagService.addTagToTask(task3.id, tag.id);

      final filter = FilterState(
        selectedTagIds: [tag.id],
        logic: FilterLogic.or,
      );

      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      // New-task-top-insert: ordered by position ASC (newest first - newest tasks get the
      // smallest/most-negative position via MIN - 1, so ASC still yields newest-first)
      expect(tasks.length, 3);
      expect(tasks[0].id, task3.id); // Newest (smallest/most-negative position)
      expect(tasks[1].id, task2.id);
      expect(tasks[2].id, task1.id); // Oldest (largest position)
    });

    test('returns smallest-position-first regardless of creation order', () async {
      // New-task-top-insert: directly craft an arbitrary, non-monotonic-with-
      // creation-order position spread (including negatives) so the ordering
      // is provably driven by `position` itself, not creation order.
      final tag = await tagService.createTag('work');

      final taskA = await taskService.createTask('Task A');
      final taskB = await taskService.createTask('Task B');
      final taskC = await taskService.createTask('Task C');

      await tagService.addTagToTask(taskA.id, tag.id);
      await tagService.addTagToTask(taskB.id, tag.id);
      await tagService.addTagToTask(taskC.id, tag.id);

      await testDb.update(AppConstants.tasksTable, {'position': 10}, where: 'id = ?', whereArgs: [taskA.id]);
      await testDb.update(AppConstants.tasksTable, {'position': -5}, where: 'id = ?', whereArgs: [taskB.id]);
      await testDb.update(AppConstants.tasksTable, {'position': 0}, where: 'id = ?', whereArgs: [taskC.id]);

      final filter = FilterState(selectedTagIds: [tag.id], logic: FilterLogic.or);
      final tasks = await taskService.getFilteredTasks(filter, completed: false);

      expect(
        tasks.map((t) => t.id).toList(),
        [taskB.id, taskC.id, taskA.id],
        reason: 'Should be ordered smallest-position-first: B(-5), C(0), A(10)',
      );
    });
  });
}
