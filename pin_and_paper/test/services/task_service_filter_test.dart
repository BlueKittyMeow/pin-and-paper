import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/models/filter_state.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import '../helpers/test_database_helper.dart';

/// Phase 3.6A: Comprehensive tests for tag filtering functionality
///
/// Tests both getFilteredTasks() and countFilteredTasks() methods
/// to ensure filtering logic works correctly and consistently.
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskService taskService;
  late TagService tagService;
  late Database testDb;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    await TestDatabaseHelper.clearAllData(testDb);

    taskService = TaskService();
    tagService = TagService();
  });

  /// Helper: Create test data with tags
  Future<Map<String, dynamic>> createTestData() async {
    // Create tags
    final workTag = await tagService.createTag('Work', color: '#2196F3');
    final urgentTag = await tagService.createTag('Urgent', color: '#FF5722');
    final personalTag = await tagService.createTag('Personal', color: '#4CAF50');

    // Create tasks
    final task1 = await taskService.createTask('Task with Work tag');
    final task2 = await taskService.createTask('Task with Urgent tag');
    final task3 = await taskService.createTask('Task with both Work and Urgent');
    final task4 = await taskService.createTask('Task with no tags');
    final task5 = await taskService.createTask('Task with Personal tag');

    // Add tags
    await tagService.addTagToTask(task1.id, workTag.id);
    await tagService.addTagToTask(task2.id, urgentTag.id);
    await tagService.addTagToTask(task3.id, workTag.id);
    await tagService.addTagToTask(task3.id, urgentTag.id);
    await tagService.addTagToTask(task5.id, personalTag.id);

    return {
      'tags': {'work': workTag, 'urgent': urgentTag, 'personal': personalTag},
      'tasks': {
        'task1': task1, // Work
        'task2': task2, // Urgent
        'task3': task3, // Work + Urgent
        'task4': task4, // No tags
        'task5': task5, // Personal
      },
    };
  }

  group('TaskService.getFilteredTasks()', () {
    group('OR Logic (ANY tag)', () {
      test('returns tasks with any of the selected tags', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;
        final tasks = data['tasks'] as Map<String, Task>;

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id, tags['urgent']!.id],
          logic: FilterLogic.or,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // Should return tasks 1, 2, and 3 (any task with Work OR Urgent)
        expect(results.length, 3);
        expect(results.any((t) => t.id == tasks['task1']!.id), true);
        expect(results.any((t) => t.id == tasks['task2']!.id), true);
        expect(results.any((t) => t.id == tasks['task3']!.id), true);
        expect(results.any((t) => t.id == tasks['task4']!.id), false);
        expect(results.any((t) => t.id == tasks['task5']!.id), false);
      });

      test('single tag selection works correctly', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;
        final tasks = data['tasks'] as Map<String, Task>;

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id],
          logic: FilterLogic.or,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // Should return tasks 1 and 3 (both have Work tag)
        expect(results.length, 2);
        expect(results.any((t) => t.id == tasks['task1']!.id), true);
        expect(results.any((t) => t.id == tasks['task3']!.id), true);
      });
    });

    group('AND Logic (ALL tags)', () {
      test('returns only tasks with all selected tags', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;
        final tasks = data['tasks'] as Map<String, Task>;

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id, tags['urgent']!.id],
          logic: FilterLogic.and,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // Should return only task3 (has BOTH Work AND Urgent)
        expect(results.length, 1);
        expect(results.first.id, tasks['task3']!.id);
      });

      test('returns empty when no tasks have all tags', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id, tags['personal']!.id],
          logic: FilterLogic.and,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // No task has both Work AND Personal
        expect(results.isEmpty, true);
      });
    });

    group('Tag Presence Filters', () {
      test('onlyTagged returns tasks with at least one tag', () async {
        final data = await createTestData();
        final tasks = data['tasks'] as Map<String, Task>;

        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // Should return tasks 1, 2, 3, 5 (all have tags)
        expect(results.length, 4);
        expect(results.any((t) => t.id == tasks['task1']!.id), true);
        expect(results.any((t) => t.id == tasks['task2']!.id), true);
        expect(results.any((t) => t.id == tasks['task3']!.id), true);
        expect(results.any((t) => t.id == tasks['task5']!.id), true);
        expect(results.any((t) => t.id == tasks['task4']!.id), false);
      });

      test('onlyUntagged returns tasks with no tags', () async {
        final data = await createTestData();
        final tasks = data['tasks'] as Map<String, Task>;

        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyUntagged,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // Should return only task4 (no tags)
        expect(results.length, 1);
        expect(results.first.id, tasks['task4']!.id);
      });

      test('any (default) returns all tasks', () async {
        final data = await createTestData();

        final filter = FilterState(
          presenceFilter: TagPresenceFilter.any,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // Should return all 5 tasks
        expect(results.length, 5);
      });
    });

    group('Completed Filter', () {
      test('filters by completed=false correctly', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;
        final tasks = data['tasks'] as Map<String, Task>;

        // Complete task1
        await taskService.toggleTaskCompletion(tasks['task1']!);

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id],
          logic: FilterLogic.or,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        // Should return only task3 (task1 is completed)
        expect(results.length, 1);
        expect(results.first.id, tasks['task3']!.id);
      });

      test('filters by completed=true correctly', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;
        final tasks = data['tasks'] as Map<String, Task>;

        // Complete task1
        await taskService.toggleTaskCompletion(tasks['task1']!);

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id],
          logic: FilterLogic.or,
        );

        final results = await taskService.getFilteredTasks(filter, completed: true);

        // Should return only completed task1
        expect(results.length, 1);
        expect(results.first.id, tasks['task1']!.id);
      });
    });

    group('Empty/Invalid Filters', () {
      test('empty filter returns all tasks', () async {
        await createTestData();

        final filter = FilterState.empty;
        final results = await taskService.getFilteredTasks(filter, completed: false);

        expect(results.length, 5);
      });

      test('filter with non-existent tag IDs returns empty', () async {
        await createTestData();

        final filter = FilterState(
          selectedTagIds: ['fake-tag-id-1', 'fake-tag-id-2'],
          logic: FilterLogic.or,
        );

        final results = await taskService.getFilteredTasks(filter, completed: false);

        expect(results.isEmpty, true);
      });
    });
  });

  group('TaskService.countFilteredTasks()', () {
    group('Count vs. Fetch Consistency', () {
      test('count matches actual filtered results (OR logic)', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id, tags['urgent']!.id],
          logic: FilterLogic.or,
        );

        final count = await taskService.countFilteredTasks(filter, completed: false);
        final results = await taskService.getFilteredTasks(filter, completed: false);

        expect(count, results.length);
        expect(count, 3);
      });

      test('count matches actual filtered results (AND logic)', () async {
        final data = await createTestData();
        final tags = data['tags'] as Map<String, dynamic>;

        final filter = FilterState(
          selectedTagIds: [tags['work']!.id, tags['urgent']!.id],
          logic: FilterLogic.and,
        );

        final count = await taskService.countFilteredTasks(filter, completed: false);
        final results = await taskService.getFilteredTasks(filter, completed: false);

        expect(count, results.length);
        expect(count, 1);
      });

      test('count matches actual filtered results (onlyTagged)', () async {
        await createTestData();

        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        final count = await taskService.countFilteredTasks(filter, completed: false);
        final results = await taskService.getFilteredTasks(filter, completed: false);

        expect(count, results.length);
        expect(count, 4);
      });

      test('count matches actual filtered results (onlyUntagged)', () async {
        await createTestData();

        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyUntagged,
        );

        final count = await taskService.countFilteredTasks(filter, completed: false);
        final results = await taskService.getFilteredTasks(filter, completed: false);

        expect(count, results.length);
        expect(count, 1);
      });
    });

    group('Performance (Count should be faster)', () {
      test('count query works with many tasks', () async {
        final tag = await tagService.createTag('Test');

        // Create 100 tasks with the tag
        for (int i = 0; i < 100; i++) {
          final task = await taskService.createTask('Task $i');
          await tagService.addTagToTask(task.id, tag.id);
        }

        final filter = FilterState(
          selectedTagIds: [tag.id],
          logic: FilterLogic.or,
        );

        final count = await taskService.countFilteredTasks(filter, completed: false);

        expect(count, 100);
      });
    });

    group('Edge Cases', () {
      test('count returns 0 for no matches', () async {
        await createTestData();

        final filter = FilterState(
          selectedTagIds: ['fake-tag-id'],
          logic: FilterLogic.or,
        );

        final count = await taskService.countFilteredTasks(filter, completed: false);

        expect(count, 0);
      });

      test('count handles empty filter correctly', () async {
        await createTestData();

        final filter = FilterState.empty;
        final count = await taskService.countFilteredTasks(filter, completed: false);

        expect(count, 5);
      });

      test('count handles completed=true filter', () async {
        final data = await createTestData();
        final tasks = data['tasks'] as Map<String, Task>;

        // Complete 2 tasks
        await taskService.toggleTaskCompletion(tasks['task1']!);
        await taskService.toggleTaskCompletion(tasks['task2']!);

        final filter = FilterState.empty;
        final count = await taskService.countFilteredTasks(filter, completed: true);

        expect(count, 2);
      });
    });
  });

  group('Filter Integration Tests', () {
    test('complex filter: AND logic with completed tasks', () async {
      final data = await createTestData();
      final tags = data['tags'] as Map<String, dynamic>;
      final tasks = data['tasks'] as Map<String, Task>;

      // Complete task3 (has Work + Urgent)
      await taskService.toggleTaskCompletion(tasks['task3']!);

      final filter = FilterState(
        selectedTagIds: [tags['work']!.id, tags['urgent']!.id],
        logic: FilterLogic.and,
      );

      final activeCount = await taskService.countFilteredTasks(filter, completed: false);
      final completedCount = await taskService.countFilteredTasks(filter, completed: true);

      expect(activeCount, 0); // No active tasks have both tags
      expect(completedCount, 1); // task3 is completed and has both tags
    });

    test('filter respects soft-deleted tasks', () async {
      final data = await createTestData();
      final tags = data['tags'] as Map<String, dynamic>;
      final tasks = data['tasks'] as Map<String, Task>;

      // Soft delete task1
      await taskService.softDeleteTask(tasks['task1']!.id);

      final filter = FilterState(
        selectedTagIds: [tags['work']!.id],
        logic: FilterLogic.or,
      );

      final results = await taskService.getFilteredTasks(filter, completed: false);
      final count = await taskService.countFilteredTasks(filter, completed: false);

      // Should not include deleted task1
      expect(results.length, 1);
      expect(count, 1);
      expect(results.first.id, tasks['task3']!.id);
    });

    test('switching between OR and AND logic gives different results', () async {
      final data = await createTestData();
      final tags = data['tags'] as Map<String, dynamic>;

      final orFilter = FilterState(
        selectedTagIds: [tags['work']!.id, tags['urgent']!.id],
        logic: FilterLogic.or,
      );

      final andFilter = FilterState(
        selectedTagIds: [tags['work']!.id, tags['urgent']!.id],
        logic: FilterLogic.and,
      );

      final orCount = await taskService.countFilteredTasks(orFilter, completed: false);
      final andCount = await taskService.countFilteredTasks(andFilter, completed: false);

      expect(orCount, 3); // Tasks with Work OR Urgent
      expect(andCount, 1); // Tasks with Work AND Urgent
      expect(orCount, greaterThan(andCount));
    });
  });
}
