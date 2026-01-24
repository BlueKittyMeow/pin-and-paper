/// Phase 3.6.5: Tests for Incomplete Descendant Cache (Completed Parent Indicator)
///
/// Tests:
/// - IncompleteDescendantInfo class behavior
/// - Cache rebuild on loadTasks() and toggleTaskCompletion()
/// - Deep detection (grandchildren+)
/// - Depth indicator (> vs >>)

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/providers/task_provider.dart';
import 'package:pin_and_paper/providers/task_sort_provider.dart';
import 'package:pin_and_paper/providers/task_filter_provider.dart';
import 'package:pin_and_paper/providers/task_hierarchy_provider.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/providers/tag_provider.dart';
import 'package:pin_and_paper/services/preferences_service.dart';

import '../helpers/test_database_helper.dart';

void main() {
  group('Phase 3.6.5: Incomplete Descendant Cache', () {
    setUpAll(() {
      TestDatabaseHelper.initialize();
    });

    late TaskProvider taskProvider;
    late TaskService taskService;
    late TagService tagService;
    late TagProvider tagProvider;
    late PreferencesService preferencesService;
    late Database testDb;

    /// Helper to create a subtask (creates task then sets parent)
    Future<Task> createSubtask(String parentId, String title) async {
      final task = await taskService.createTask(title);
      await taskService.updateTaskParent(task.id, parentId, 0);
      // Reload to get updated task with parentId
      final tasks = await taskService.getTaskHierarchy();
      return tasks.firstWhere((t) => t.id == task.id);
    }

    setUp(() async {
      // Create fresh database for each test
      testDb = await TestDatabaseHelper.createTestDatabase();
      DatabaseService.setTestDatabase(testDb);

      // Clear all data from previous tests
      await TestDatabaseHelper.clearAllData(testDb);

      // Create services and providers
      taskService = TaskService();
      tagService = TagService();
      tagProvider = TagProvider(tagService: tagService);
      preferencesService = PreferencesService();

      taskProvider = TaskProvider(
        taskService: taskService,
        preferencesService: preferencesService,
        tagService: tagService,
        tagProvider: tagProvider,
        sortProvider: TaskSortProvider(),
        filterProvider: TaskFilterProvider(tagProvider: tagProvider),
        hierarchyProvider: TaskHierarchyProvider(),
      );
    });

    group('IncompleteDescendantInfo class', () {
      test('hasIncomplete returns true when totalCount > 0', () {
        const info = IncompleteDescendantInfo(
          immediateCount: 0,
          totalCount: 3,
          maxDepth: 2,
        );
        expect(info.hasIncomplete, isTrue);
      });

      test('hasIncomplete returns false when totalCount is 0', () {
        const info = IncompleteDescendantInfo(
          immediateCount: 0,
          totalCount: 0,
          maxDepth: 0,
        );
        expect(info.hasIncomplete, isFalse);
      });

      test('hasDeepIncomplete returns true when maxDepth > 1', () {
        const info = IncompleteDescendantInfo(
          immediateCount: 1,
          totalCount: 3,
          maxDepth: 2,
        );
        expect(info.hasDeepIncomplete, isTrue);
      });

      test('hasDeepIncomplete returns false when maxDepth == 1', () {
        const info = IncompleteDescendantInfo(
          immediateCount: 2,
          totalCount: 2,
          maxDepth: 1,
        );
        expect(info.hasDeepIncomplete, isFalse);
      });

      test('displayText shows ">" for immediate only', () {
        const info = IncompleteDescendantInfo(
          immediateCount: 2,
          totalCount: 2,
          maxDepth: 1,
        );
        expect(info.displayText, '> 2 incomplete');
      });

      test('displayText shows ">>" for grandchildren+', () {
        const info = IncompleteDescendantInfo(
          immediateCount: 1,
          totalCount: 3,
          maxDepth: 2,
        );
        expect(info.displayText, '>> 3 incomplete');
      });

      test('displayText shows ">>" for great-grandchildren', () {
        const info = IncompleteDescendantInfo(
          immediateCount: 0,
          totalCount: 1,
          maxDepth: 3,
        );
        expect(info.displayText, '>> 1 incomplete');
      });
    });

    group('Cache behavior', () {
      test('getIncompleteDescendantInfo returns null for incomplete task', () async {
        // Create an incomplete task
        await taskService.createTask('Incomplete Task');
        await taskProvider.loadTasks();

        final tasks = taskProvider.tasks;
        expect(tasks.length, 1);

        final info = taskProvider.getIncompleteDescendantInfo(tasks.first.id);
        expect(info, isNull);
      });

      test('getIncompleteDescendantInfo returns null for completed task with no children', () async {
        // Create and complete a task
        final task = await taskService.createTask('Completed Task');
        await taskService.toggleTaskCompletion(task);
        await taskProvider.loadTasks();

        final info = taskProvider.getIncompleteDescendantInfo(task.id);
        expect(info, isNull);
      });

      test('getIncompleteDescendantInfo returns info for completed parent with incomplete child', () async {
        // Create parent and child
        final parent = await taskService.createTask('Parent');
        await createSubtask(parent.id, 'Child');

        // Complete parent
        await taskService.toggleTaskCompletion(parent);

        await taskProvider.loadTasks();

        final info = taskProvider.getIncompleteDescendantInfo(parent.id);
        expect(info, isNotNull);
        expect(info!.immediateCount, 1);
        expect(info.totalCount, 1);
        expect(info.maxDepth, 1);
        expect(info.displayText, '> 1 incomplete');
      });

      test('isCompletedParentWithIncomplete returns correct value', () async {
        // Create parent and child
        final parent = await taskService.createTask('Parent');
        await createSubtask(parent.id, 'Child');

        // Complete parent
        await taskService.toggleTaskCompletion(parent);

        await taskProvider.loadTasks();

        expect(taskProvider.isCompletedParentWithIncomplete(parent.id), isTrue);
      });
    });

    group('Deep detection', () {
      test('detects incomplete grandchildren', () async {
        // Create: Parent → Child → Grandchild (all incomplete initially)
        final parent = await taskService.createTask('Parent');
        final child = await createSubtask(parent.id, 'Child');
        await createSubtask(child.id, 'Grandchild');

        // Complete Parent and Child, leave Grandchild incomplete
        await taskService.toggleTaskCompletion(parent);
        await taskService.toggleTaskCompletion(child);

        await taskProvider.loadTasks();

        final parentInfo = taskProvider.getIncompleteDescendantInfo(parent.id);
        expect(parentInfo, isNotNull);
        expect(parentInfo!.totalCount, 1);
        expect(parentInfo.maxDepth, 2); // Grandchild is at depth 2
        expect(parentInfo.displayText, '>> 1 incomplete');
      });

      test('detects incomplete great-grandchildren', () async {
        // Create: Parent → Child → Grandchild → GreatGrandchild
        final parent = await taskService.createTask('Parent');
        final child = await createSubtask(parent.id, 'Child');
        final grandchild = await createSubtask(child.id, 'Grandchild');
        await createSubtask(grandchild.id, 'GreatGrandchild');

        // Complete Parent, Child, and Grandchild
        await taskService.toggleTaskCompletion(parent);
        await taskService.toggleTaskCompletion(child);
        await taskService.toggleTaskCompletion(grandchild);

        await taskProvider.loadTasks();

        final parentInfo = taskProvider.getIncompleteDescendantInfo(parent.id);
        expect(parentInfo, isNotNull);
        expect(parentInfo!.totalCount, 1);
        expect(parentInfo.maxDepth, 3); // Great-grandchild is at depth 3
      });

      test('counts multiple incomplete descendants at different depths', () async {
        // Create: Parent → Child1 (incomplete), Child2 → Grandchild (incomplete)
        final parent = await taskService.createTask('Parent');
        await createSubtask(parent.id, 'Child1'); // Will stay incomplete
        final child2 = await createSubtask(parent.id, 'Child2');
        await createSubtask(child2.id, 'Grandchild'); // Will stay incomplete

        // Complete Parent and Child2
        await taskService.toggleTaskCompletion(parent);
        await taskService.toggleTaskCompletion(child2);

        await taskProvider.loadTasks();

        final parentInfo = taskProvider.getIncompleteDescendantInfo(parent.id);
        expect(parentInfo, isNotNull);
        expect(parentInfo!.immediateCount, 1); // Child1
        expect(parentInfo.totalCount, 2); // Child1 + Grandchild
        expect(parentInfo.maxDepth, 2); // Grandchild is deepest
      });
    });

    group('Cache updates on toggleTaskCompletion', () {
      test('cache updates when task is completed', () async {
        // Create parent with child
        final parent = await taskService.createTask('Parent');
        await createSubtask(parent.id, 'Child');

        await taskProvider.loadTasks();

        // Initially, parent is incomplete - no cache entry
        expect(taskProvider.isCompletedParentWithIncomplete(parent.id), isFalse);

        // Complete parent via provider
        final loadedParent = taskProvider.tasks.firstWhere((t) => t.id == parent.id);
        await taskProvider.toggleTaskCompletion(loadedParent);

        // Now parent should be in cache (completed with incomplete child)
        expect(taskProvider.isCompletedParentWithIncomplete(parent.id), isTrue);
      });

      test('cache updates when child is completed', () async {
        // Create parent with child
        final parent = await taskService.createTask('Parent');
        final child = await createSubtask(parent.id, 'Child');

        // Complete parent first
        await taskService.toggleTaskCompletion(parent);

        await taskProvider.loadTasks();

        // Parent has incomplete child
        expect(taskProvider.isCompletedParentWithIncomplete(parent.id), isTrue);

        // Complete child via provider
        final loadedChild = taskProvider.tasks.firstWhere((t) => t.id == child.id);
        await taskProvider.toggleTaskCompletion(loadedChild);

        // Now parent should NOT be in cache (all descendants complete)
        expect(taskProvider.isCompletedParentWithIncomplete(parent.id), isFalse);
      });
    });
  });
}
