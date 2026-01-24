import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/providers/task_provider.dart';
import 'package:pin_and_paper/providers/task_sort_provider.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import '../helpers/test_database_helper.dart';

/// Phase 3.5 Fix #C3: Tests for completed task hierarchy preservation
///
/// These tests verify that completed tasks display with correct hierarchy
/// (depth and hasChildren) instead of being flattened.
///
/// Critical edge case: Orphaned completed children (parent incomplete, child complete)
void main() {
  // Initialize sqflite_common_ffi once for all tests
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskProvider taskProvider;
  late TaskService taskService;
  late TagService tagService;
  late Database testDb;

  setUp(() async {
    // Create a fresh test database for each test
    testDb = await TestDatabaseHelper.createTestDatabase();

    // Inject the test database into DatabaseService
    DatabaseService.setTestDatabase(testDb);

    // CRITICAL FIX: Clear all data from previous tests
    await TestDatabaseHelper.clearAllData(testDb);

    // Create services
    taskService = TaskService();
    tagService = TagService();

    // Create TaskProvider with test services
    taskProvider = TaskProvider(
      taskService: taskService,
      tagService: tagService,
      sortProvider: TaskSortProvider(),
    );

    // Load initial (empty) tasks
    await taskProvider.loadTasks();
  });

  group('Phase 3.5 Fix #C3: Completed Task Hierarchy', () {
    test('Simple hierarchy: all completed tasks show correct order and depth', () async {
      // Create hierarchy: Parent (depth=0) → Child1 (depth=1) → Child2 (depth=1)
      final parent = await taskService.createTask('Parent Task');
      final child1 = await taskService.createTask('Child 1');
      final child2 = await taskService.createTask('Child 2');

      // Nest children under parent (position determines order)
      await taskService.updateTaskParent(child1.id, parent.id, 0);  // pos=0 → first
      await taskService.updateTaskParent(child2.id, parent.id, 1);  // pos=1 → second

      // Reload tasks to get updated depth from DB
      await taskProvider.loadTasks();

      // Now get fresh task objects with correct depth
      final tasks = await taskService.getTaskHierarchy();
      final parentFresh = tasks.firstWhere((t) => t.id == parent.id);
      final child1Fresh = tasks.firstWhere((t) => t.id == child1.id);
      final child2Fresh = tasks.firstWhere((t) => t.id == child2.id);

      // Complete all tasks (using fresh objects with correct depth)
      await taskService.toggleTaskCompletion(parentFresh);
      await taskService.toggleTaskCompletion(child1Fresh);
      await taskService.toggleTaskCompletion(child2Fresh);

      // Reload to get updated hierarchy
      await taskProvider.loadTasks();

      // Get completed hierarchy
      final hierarchy = taskProvider.completedTasksWithHierarchy;

      // Verify count
      expect(hierarchy.length, 3, reason: 'Should have parent + 2 children');

      // Verify order: Parent, Child1, Child2
      expect(hierarchy[0].title, 'Parent Task', reason: 'Parent should be first');
      expect(hierarchy[1].title, 'Child 1', reason: 'Child 1 should be second (pos=0)');
      expect(hierarchy[2].title, 'Child 2', reason: 'Child 2 should be third (pos=1)');

      // Verify depth
      expect(hierarchy[0].depth, 0, reason: 'Parent should have depth 0');
      expect(hierarchy[1].depth, 1, reason: 'Child 1 should have depth 1');
      expect(hierarchy[2].depth, 1, reason: 'Child 2 should have depth 1');

      // Verify hasCompletedChildren
      expect(
        taskProvider.hasCompletedChildren(parent.id),
        true,
        reason: 'Parent should show has children',
      );
      expect(
        taskProvider.hasCompletedChildren(child1.id),
        false,
        reason: 'Child 1 should show no children',
      );
    });

    test('Orphaned completed child: parent incomplete, child complete', () async {
      // Create hierarchy: Parent → Child
      final parent = await taskService.createTask('Incomplete Parent');
      final child = await taskService.createTask('Completed Child');

      // Nest child under parent
      await taskService.updateTaskParent(child.id, parent.id, 0);

      // Reload to get updated depth
      await taskProvider.loadTasks();

      // Get fresh task objects
      final tasks = await taskService.getTaskHierarchy();
      final childFresh = tasks.firstWhere((t) => t.id == child.id);

      // Complete ONLY the child (parent stays incomplete)
      await taskService.toggleTaskCompletion(childFresh);

      // Reload
      await taskProvider.loadTasks();

      // Get completed hierarchy
      final hierarchy = taskProvider.completedTasksWithHierarchy;

      // Verify orphaned child appears as root (Codex fix)
      expect(hierarchy.length, 1, reason: 'Only child should be in completed list');
      expect(hierarchy[0].title, 'Completed Child', reason: 'Orphaned child should appear');

      // CRITICAL: Verify depth is preserved from DB, not recalculated
      expect(
        hierarchy[0].depth,
        1,
        reason: 'Orphaned child keeps original depth (historical context)',
      );
    });

    test('Position-based sorting: children sorted by position field', () async {
      // Create parent with 3 children in specific order
      final parent = await taskService.createTask('Parent');
      final childA = await taskService.createTask('Child A');
      final childB = await taskService.createTask('Child B');
      final childC = await taskService.createTask('Child C');

      // Nest in non-alphabetical position order
      await taskService.updateTaskParent(childB.id, parent.id, 0);  // pos=0 → first
      await taskService.updateTaskParent(childA.id, parent.id, 1);  // pos=1 → second
      await taskService.updateTaskParent(childC.id, parent.id, 2);  // pos=2 → third

      // Reload to get updated depth
      await taskProvider.loadTasks();

      // Get fresh task objects
      final tasks = await taskService.getTaskHierarchy();
      final parentFresh = tasks.firstWhere((t) => t.id == parent.id);
      final childAFresh = tasks.firstWhere((t) => t.id == childA.id);
      final childBFresh = tasks.firstWhere((t) => t.id == childB.id);
      final childCFresh = tasks.firstWhere((t) => t.id == childC.id);

      // Complete all
      await taskService.toggleTaskCompletion(parentFresh);
      await taskService.toggleTaskCompletion(childAFresh);
      await taskService.toggleTaskCompletion(childBFresh);
      await taskService.toggleTaskCompletion(childCFresh);

      // Reload
      await taskProvider.loadTasks();

      // Get hierarchy
      final hierarchy = taskProvider.completedTasksWithHierarchy;

      // Verify position-based order (not alphabetical)
      expect(hierarchy[1].title, 'Child B', reason: 'pos=0 should be first child');
      expect(hierarchy[2].title, 'Child A', reason: 'pos=1 should be second child');
      expect(hierarchy[3].title, 'Child C', reason: 'pos=2 should be third child');
    });

    test('Deep nesting: grandchildren preserve depth correctly', () async {
      // Create 3-level hierarchy
      final root = await taskService.createTask('Root');
      final child = await taskService.createTask('Child');
      final grandchild = await taskService.createTask('Grandchild');

      // Nest: Root → Child → Grandchild
      await taskService.updateTaskParent(child.id, root.id, 0);
      await taskService.updateTaskParent(grandchild.id, child.id, 0);

      // Reload to get updated depth
      await taskProvider.loadTasks();

      // Get fresh task objects
      final tasks = await taskService.getTaskHierarchy();
      final rootFresh = tasks.firstWhere((t) => t.id == root.id);
      final childFresh = tasks.firstWhere((t) => t.id == child.id);
      final grandchildFresh = tasks.firstWhere((t) => t.id == grandchild.id);

      // Complete all (root → child → grandchild order)
      await taskService.toggleTaskCompletion(rootFresh);
      await taskService.toggleTaskCompletion(childFresh);
      await taskService.toggleTaskCompletion(grandchildFresh);

      // Reload
      await taskProvider.loadTasks();

      // Get hierarchy
      final hierarchy = taskProvider.completedTasksWithHierarchy;

      // Verify depth progression
      expect(hierarchy[0].depth, 0, reason: 'Root at depth 0');
      expect(hierarchy[1].depth, 1, reason: 'Child at depth 1');
      expect(hierarchy[2].depth, 2, reason: 'Grandchild at depth 2');

      // Verify order
      expect(hierarchy[0].title, 'Root', reason: 'Root first');
      expect(hierarchy[1].title, 'Child', reason: 'Child second');
      expect(hierarchy[2].title, 'Grandchild', reason: 'Grandchild third');
    });

    test('hasCompletedChildren: correctly identifies completed children', () async {
      // Create parent with completed and incomplete children
      final parent = await taskService.createTask('Parent');
      final completedChild = await taskService.createTask('Completed Child');
      final incompleteChild = await taskService.createTask('Incomplete Child');
      final childlessTask = await taskService.createTask('No Children');

      // Nest children
      await taskService.updateTaskParent(completedChild.id, parent.id, 0);
      await taskService.updateTaskParent(incompleteChild.id, parent.id, 1);

      // Reload to get updated depth
      await taskProvider.loadTasks();

      // Get fresh task objects
      final tasks = await taskService.getTaskHierarchy();
      final parentFresh = tasks.firstWhere((t) => t.id == parent.id);
      final completedChildFresh = tasks.firstWhere((t) => t.id == completedChild.id);
      final childlessTaskFresh = tasks.firstWhere((t) => t.id == childlessTask.id);

      // Complete parent and one child
      await taskService.toggleTaskCompletion(parentFresh);
      await taskService.toggleTaskCompletion(completedChildFresh);
      await taskService.toggleTaskCompletion(childlessTaskFresh);

      // Reload
      await taskProvider.loadTasks();

      // Build hierarchy (this caches the child map)
      final hierarchy = taskProvider.completedTasksWithHierarchy;

      // Parent should NOT appear in completed list (has incomplete child)
      expect(
        hierarchy.any((t) => t.id == parent.id),
        false,
        reason: 'Parent with incomplete child should not appear in completed list',
      );

      // Childless task should appear
      expect(
        hierarchy.any((t) => t.id == childlessTask.id),
        true,
        reason: 'Task with no children should appear in completed list',
      );

      // Now complete the incomplete child
      final tasksAfterFirst = await taskService.getTaskHierarchy();
      final incompleteChildFresh = tasksAfterFirst.firstWhere((t) => t.id == incompleteChild.id);
      await taskService.toggleTaskCompletion(incompleteChildFresh);
      await taskProvider.loadTasks();

      // Rebuild hierarchy
      final hierarchyAfter = taskProvider.completedTasksWithHierarchy;

      // Now parent should appear (all children complete)
      expect(
        hierarchyAfter.any((t) => t.id == parent.id),
        true,
        reason: 'Parent with all children complete should appear',
      );

      // Test hasCompletedChildren helper
      expect(
        taskProvider.hasCompletedChildren(parent.id),
        true,
        reason: 'Parent should have completed children',
      );

      expect(
        taskProvider.hasCompletedChildren(childlessTask.id),
        false,
        reason: 'Childless task should have no completed children',
      );
    });

    test('Multiple roots: independent trees sorted by position', () async {
      // Create two independent hierarchies
      final rootA = await taskService.createTask('Root A');
      final rootB = await taskService.createTask('Root B');
      final childA = await taskService.createTask('Child A');
      final childB = await taskService.createTask('Child B');

      // Nest children under respective parents
      await taskService.updateTaskParent(childA.id, rootA.id, 0);
      await taskService.updateTaskParent(childB.id, rootB.id, 0);

      // Reload to get updated depth
      await taskProvider.loadTasks();

      // Get fresh task objects
      final tasks = await taskService.getTaskHierarchy();
      final rootAFresh = tasks.firstWhere((t) => t.id == rootA.id);
      final rootBFresh = tasks.firstWhere((t) => t.id == rootB.id);
      final childAFresh = tasks.firstWhere((t) => t.id == childA.id);
      final childBFresh = tasks.firstWhere((t) => t.id == childB.id);

      // Complete all
      await taskService.toggleTaskCompletion(rootAFresh);
      await taskService.toggleTaskCompletion(rootBFresh);
      await taskService.toggleTaskCompletion(childAFresh);
      await taskService.toggleTaskCompletion(childBFresh);

      // Reload
      await taskProvider.loadTasks();

      // Get hierarchy
      final hierarchy = taskProvider.completedTasksWithHierarchy;

      // Verify structure: RootA, ChildA, RootB, ChildB
      expect(hierarchy.length, 4, reason: 'Should have 2 trees with 2 tasks each');

      // Find indices
      final rootAIndex = hierarchy.indexWhere((t) => t.id == rootA.id);
      final childAIndex = hierarchy.indexWhere((t) => t.id == childA.id);
      final rootBIndex = hierarchy.indexWhere((t) => t.id == rootB.id);
      final childBIndex = hierarchy.indexWhere((t) => t.id == childB.id);

      // Verify child immediately follows parent
      expect(childAIndex, rootAIndex + 1, reason: 'Child A should follow Root A');
      expect(childBIndex, rootBIndex + 1, reason: 'Child B should follow Root B');

      // Verify roots come before children of other trees
      expect(rootAIndex < childBIndex, true, reason: 'Roots should be processed in order');
    });
  });
}
