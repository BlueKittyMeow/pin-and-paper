import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/filter_state.dart';
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

/// Phase 4.0: Tests for TaskProvider sync integration.
///
/// Tests `refreshWithCurrentFilters()` which is the public method
/// called by the onDataChanged callback to re-apply active filters
/// after sync pulls new data.
///
/// RED phase — these tests define the contract before implementation.
void main() {
  group('TaskProvider — sync integration', () {
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
      testDb = await TestDatabaseHelper.createTestDatabase();
      DatabaseService.setTestDatabase(testDb);
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
    Future<void> waitForUpdate() async {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // ═══════════════════════════════════════
    // refreshWithCurrentFilters
    // ═══════════════════════════════════════

    group('refreshWithCurrentFilters', () {
      test('exists as a public method', () {
        // This method must exist on TaskProvider so that HomeScreen's
        // onDataChanged callback can re-apply filters after sync pull.
        expect(taskProvider.refreshWithCurrentFilters, isA<Function>());
      });

      test('reloads tasks when no filters active', () async {
        // Create a task
        await taskService.createTask('Test task');

        // Load initial tasks
        await taskProvider.loadTasks();
        await waitForUpdate();
        expect(taskProvider.activeTasks.length, 1);

        // Add another task directly to DB (simulating sync pull)
        await taskService.createTask('Synced task');

        // refreshWithCurrentFilters should pick up the new task
        taskProvider.refreshWithCurrentFilters();
        await waitForUpdate();
        expect(taskProvider.activeTasks.length, 2,
            reason: 'Should reload and include the newly synced task');
      });

      test('preserves active tag filter after refresh', () async {
        // Create a tag and two tasks
        final tag = await tagService.createTag('Important');
        final taggedTask = await taskService.createTask('Tagged task');
        await tagService.addTagToTask(taggedTask.id, tag.id);

        await taskService.createTask('Untagged task');

        // Load and apply tag filter
        await taskProvider.loadTasks();
        await waitForUpdate();

        // Set filter to only show tasks with 'Important' tag
        filterProvider.setFilter(FilterState(
          selectedTagIds: [tag.id],
          logic: FilterLogic.or,
        ));
        await waitForUpdate();

        // Verify filter is active
        expect(taskProvider.hasActiveFilters, isTrue);

        // Now simulate a sync pull adding a third task (without the tag)
        await taskService.createTask('Synced untagged');

        // refreshWithCurrentFilters should reload but still respect the filter
        taskProvider.refreshWithCurrentFilters();
        await waitForUpdate();

        // The untagged synced task should NOT appear in the filtered view
        final visibleTitles = taskProvider.activeTasks.map((t) => t.title).toList();
        expect(visibleTitles, contains('Tagged task'),
            reason: 'Tagged task should still be visible');
        expect(visibleTitles, isNot(contains('Synced untagged')),
            reason: 'Untagged synced task should be filtered out');
      });
    });
  });
}
