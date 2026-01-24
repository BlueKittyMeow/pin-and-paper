import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/filter_state.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/models/tag.dart';
import 'package:pin_and_paper/providers/task_provider.dart';
import 'package:pin_and_paper/providers/task_sort_provider.dart';
import 'package:pin_and_paper/providers/task_filter_provider.dart';
import 'package:pin_and_paper/providers/task_hierarchy_provider.dart';
import 'package:pin_and_paper/providers/tag_provider.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/preferences_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../helpers/test_database_helper.dart';

/// Phase 3.6A: TaskProvider filter tests
///
/// Tests the filter state management and operation ID pattern
/// for race condition prevention.
void main() {
  group('TaskProvider - Phase 3.6A Filters', () {
    setUpAll(() {
      TestDatabaseHelper.initialize();
    });

    late TaskProvider taskProvider;
    late TagProvider tagProvider;
    late TaskFilterProvider filterProvider;
    late TaskService taskService;
    late TagService tagService;
    late PreferencesService preferencesService;
    late Database testDb;

    setUp(() async {
      // Create fresh database for each test
      testDb = await TestDatabaseHelper.createTestDatabase();
      DatabaseService.setTestDatabase(testDb);

      // Clear all data from previous tests
      await TestDatabaseHelper.clearAllData(testDb);

      taskService = TaskService();
      tagService = TagService();
      preferencesService = PreferencesService();
      tagProvider = TagProvider(tagService: tagService);
      filterProvider = TaskFilterProvider(tagProvider: tagProvider);
      taskProvider = TaskProvider(
        taskService: taskService,
        tagService: tagService,
        preferencesService: preferencesService,
        tagProvider: tagProvider,
        sortProvider: TaskSortProvider(),
        filterProvider: filterProvider,
        hierarchyProvider: TaskHierarchyProvider(),
      );
    });

    /// Helper: Wait for async listener callbacks to complete
    Future<void> waitForFilterUpdate() async {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    group('Filter State Management', () {
      test('starts with empty filter', () {
        expect(taskProvider.filterState, equals(FilterState.empty));
        expect(taskProvider.hasActiveFilters, isFalse);
      });

      test('setFilter updates filter state', () async {
        final filter = FilterState(
          selectedTagIds: ['tag1'],
          logic: FilterLogic.or,
        );

        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        expect(taskProvider.filterState, equals(filter));
        expect(taskProvider.hasActiveFilters, isTrue);
      });

      test('setFilter early returns if filter unchanged', () async {
        final filter = FilterState(selectedTagIds: ['tag1']);

        filterProvider.setFilter(filter);
        await waitForFilterUpdate();
        final firstState = taskProvider.filterState;

        // Set same filter again
        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        // Should be exactly the same instance (early return optimization)
        expect(identical(taskProvider.filterState, firstState), isTrue);
      });

      test('clearFilters resets to empty', () async {
        final filter = FilterState(selectedTagIds: ['tag1']);
        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        expect(taskProvider.hasActiveFilters, isTrue);

        filterProvider.clearFilters();
        await waitForFilterUpdate();

        expect(taskProvider.filterState, equals(FilterState.empty));
        expect(taskProvider.hasActiveFilters, isFalse);
      });
    });

    group('Filter with Tasks', () {
      late Tag tag1;
      late Tag tag2;
      late Task task1;
      late Task task2;
      late Task task3;

      setUp(() async {
        // Create test data
        tag1 = await tagService.createTag('work');
        tag2 = await tagService.createTag('urgent');

        task1 = await taskService.createTask('Task 1');
        task2 = await taskService.createTask('Task 2');
        task3 = await taskService.createTask('Task 3');

        await tagService.addTagToTask(task1.id, tag1.id); // Task 1: work
        await tagService.addTagToTask(task2.id, tag2.id); // Task 2: urgent
        // Task 3: no tags

        // Load tags into TagProvider
        await tagProvider.loadTags();

        // Load tasks into TaskProvider
        await taskProvider.loadTasks();
      });

      test('setFilter with OR logic filters tasks', () async {
        expect(taskProvider.tasks.length, 3); // All tasks initially

        final filter = FilterState(
          selectedTagIds: [tag1.id],
          logic: FilterLogic.or,
        );

        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        expect(taskProvider.tasks.length, 1);
        expect(taskProvider.tasks.first.id, task1.id);
      });

      test('setFilter with AND logic filters tasks', () async {
        // Add both tags to task1
        await tagService.addTagToTask(task1.id, tag2.id);
        await taskProvider.loadTasks();

        final filter = FilterState(
          selectedTagIds: [tag1.id, tag2.id],
          logic: FilterLogic.and,
        );

        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        expect(taskProvider.tasks.length, 1);
        expect(taskProvider.tasks.first.id, task1.id); // Only task with both tags
      });

      test('setFilter with onlyTagged shows only tagged tasks', () async {
        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        expect(taskProvider.tasks.length, 2); // task1 and task2 have tags
        expect(taskProvider.tasks.map((t) => t.id), containsAll([task1.id, task2.id]));
      });

      test('setFilter with onlyUntagged shows only untagged tasks', () async {
        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyUntagged,
        );

        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        expect(taskProvider.tasks.length, 1);
        expect(taskProvider.tasks.first.id, task3.id); // Only task without tags
      });

      test('clearFilters reloads all tasks', () async {
        // Apply filter
        final filter = FilterState(selectedTagIds: [tag1.id]);
        filterProvider.setFilter(filter);
        await waitForFilterUpdate();
        expect(taskProvider.tasks.length, 1);

        // Clear filter
        filterProvider.clearFilters();
        await waitForFilterUpdate();

        expect(taskProvider.tasks.length, 3); // All tasks restored
      });
    });

    group('addTagFilter', () {
      late Tag tag1;
      late Tag tag2;

      setUp(() async {
        tag1 = await tagService.createTag('work');
        tag2 = await tagService.createTag('urgent');

        await tagProvider.loadTags();
      });

      test('adds tag to empty filter', () async {
        expect(taskProvider.filterState.selectedTagIds, isEmpty);

        filterProvider.addTagFilter(tag1.id);

        expect(taskProvider.filterState.selectedTagIds, contains(tag1.id));
        expect(taskProvider.hasActiveFilters, isTrue);
      });

      test('adds second tag to existing filter', () async {
        filterProvider.addTagFilter(tag1.id);

        filterProvider.addTagFilter(tag2.id);

        expect(taskProvider.filterState.selectedTagIds.length, 2);
        expect(taskProvider.filterState.selectedTagIds, containsAll([tag1.id, tag2.id]));
      });

      test('ignores duplicate tag IDs', () async {
        filterProvider.addTagFilter(tag1.id);

        filterProvider.addTagFilter(tag1.id); // Duplicate

        expect(taskProvider.filterState.selectedTagIds.length, 1);
        expect(taskProvider.filterState.selectedTagIds, [tag1.id]);
      });

      test('rejects empty tag ID', () async {
        filterProvider.addTagFilter('');

        expect(taskProvider.filterState.selectedTagIds, isEmpty);
      });

      test('rejects non-existent tag ID (M2: validation)', () async {
        filterProvider.addTagFilter('invalid-tag-id');

        expect(taskProvider.filterState.selectedTagIds, isEmpty);
      });
    });

    group('removeTagFilter', () {
      late Tag tag1;
      late Tag tag2;

      setUp(() async {
        tag1 = await tagService.createTag('work');
        tag2 = await tagService.createTag('urgent');

        await tagProvider.loadTags();

        // Start with both tags in filter
        final filter = FilterState(
          selectedTagIds: [tag1.id, tag2.id],
        );
        filterProvider.setFilter(filter);
        await waitForFilterUpdate();
      });

      test('removes tag from filter', () async {
        expect(taskProvider.filterState.selectedTagIds.length, 2);

        filterProvider.removeTagFilter(tag1.id);

        expect(taskProvider.filterState.selectedTagIds.length, 1);
        expect(taskProvider.filterState.selectedTagIds, [tag2.id]);
      });

      test('clears filter when removing last tag', () async {
        filterProvider.removeTagFilter(tag1.id);
        filterProvider.removeTagFilter(tag2.id);

        expect(taskProvider.filterState, equals(FilterState.empty));
        expect(taskProvider.hasActiveFilters, isFalse);
      });

      test('preserves presence filter when removing tags', () async {
        final filter = FilterState(
          selectedTagIds: [tag1.id],
          presenceFilter: TagPresenceFilter.onlyTagged,
        );
        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        filterProvider.removeTagFilter(tag1.id);

        // Should still have presence filter active
        expect(taskProvider.filterState.presenceFilter, TagPresenceFilter.onlyTagged);
        expect(taskProvider.hasActiveFilters, isTrue);
      });
    });

    group('Race Condition Prevention (Operation ID)', () {
      test('discards stale filter results', () async {
        final tag1 = await tagService.createTag('work');
        final tag2 = await tagService.createTag('urgent');
        await tagProvider.loadTags();

        // Create tasks
        final task1 = await taskService.createTask('Task 1');
        await tagService.addTagToTask(task1.id, tag1.id);

        final task2 = await taskService.createTask('Task 2');
        await tagService.addTagToTask(task2.id, tag2.id);

        await taskProvider.loadTasks();

        // Start two filter operations rapidly
        final filter1 = FilterState(selectedTagIds: [tag1.id]);
        final filter2 = FilterState(selectedTagIds: [tag2.id]);

        filterProvider.setFilter(filter1);
        filterProvider.setFilter(filter2); // Immediately set second

        // Wait for async listener to complete
        await waitForFilterUpdate();

        // Should have filter2 results (latest operation wins)
        expect(taskProvider.filterState, equals(filter2));
        expect(taskProvider.tasks.length, 1);
        expect(taskProvider.tasks.first.id, task2.id);
      });

      test('rollback works when operation is still latest (H2)', () async {
        // This test is hard to trigger reliably, but we can test the logic by
        // checking that error doesn't leave provider in inconsistent state

        final tag = await tagService.createTag('work');
        await tagProvider.loadTags();

        final previousFilter = taskProvider.filterState;

        // Try to set filter that will cause DB error (closed database)
        await testDb.close();

        final filter = FilterState(selectedTagIds: [tag.id]);
        filterProvider.setFilter(filter);
        await waitForFilterUpdate();

        // Should have rolled back to previous filter (empty)
        expect(taskProvider.filterState, equals(previousFilter));
      });
    });

    group('Integration with Task Operations', () {
      late Tag tag;
      late Task task1;

      setUp(() async {
        tag = await tagService.createTag('work');
        await tagProvider.loadTags();

        task1 = await taskService.createTask('Task 1');
        await tagService.addTagToTask(task1.id, tag.id);

        await taskProvider.loadTasks();

        // Apply filter
        final filter = FilterState(selectedTagIds: [tag.id]);
        filterProvider.setFilter(filter);
        await waitForFilterUpdate();
      });

      test('filtered view updates when task completed', () async {
        expect(taskProvider.tasks.length, 1);
        expect(taskProvider.tasks.first.completed, false);

        await taskProvider.toggleTaskCompletion(task1);

        // Filtered view should update (though task moved to completed list)
        // The active tasks list should now be empty
        expect(taskProvider.activeTasks, isEmpty);
      });
    });
  });
}
