import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/models/filter_state.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/providers/task_provider.dart';
import 'package:pin_and_paper/providers/task_sort_provider.dart';
import 'package:pin_and_paper/providers/task_filter_provider.dart';
import 'package:pin_and_paper/providers/task_hierarchy_provider.dart';
import 'package:pin_and_paper/providers/tag_provider.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import '../helpers/test_database_helper.dart';

/// New-task-top-insert #6 (REQUIRED): regression tests for the drag-reorder
/// staleness fix in TaskProvider.onNodeAccepted.
///
/// Before the fix, whenAbove/whenBelow passed the target node's raw (possibly
/// stale) position straight into updateTaskParent. For a same-parent move,
/// updateTaskParent reindexes the remaining siblings to 0..N-1 *before* using
/// that value, so a stale raw position landed the dragged task in the wrong
/// slot. This only bit non-compact positions before (soft-delete gaps); under
/// MIN - 1 top-level insertion, negative/non-compact positions are the norm.
///
/// TreeDragAndDropDetails is a plain data class (draggedNode/targetNode/
/// dropPosition/targetBounds), so it can be constructed directly without a
/// widget tree. mapDropPosition splits targetBounds.height into a 30/40/30
/// (above/inside/below) zone based on dropPosition.dy - with height 100, dy=10
/// lands in "above" and dy=90 lands in "below".
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskProvider taskProvider;
  late TaskService taskService;
  late TagService tagService;
  late TaskFilterProvider filterProvider;
  late Database testDb;

  const targetBounds = Rect.fromLTWH(0, 0, 100, 100);
  const above = Offset(0, 10); // 10 < 30% of height -> whenAbove
  const below = Offset(0, 90); // 90 >= 69.9% of height -> whenBelow

  /// Filter changes are applied asynchronously via a ChangeNotifier listener
  /// (TaskProvider._onFilterChanged) - wait for them to settle.
  Future<void> waitForFilterUpdate() async {
    await taskProvider.waitForPendingOperations();
  }

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    await TestDatabaseHelper.clearAllData(testDb);

    taskService = TaskService();
    tagService = TagService();
    final tagProvider = TagProvider(tagService: tagService);
    filterProvider = TaskFilterProvider(tagProvider: tagProvider);

    taskProvider = TaskProvider(
      taskService: taskService,
      tagService: tagService,
      tagProvider: tagProvider,
      sortProvider: TaskSortProvider(),
      filterProvider: filterProvider,
      hierarchyProvider: TaskHierarchyProvider(),
    );
  });

  tearDown(() async {
    // Drain in-flight async work (filter ops, loadTasks) before the test
    // database goes away, so stray DatabaseException(database_closed)
    // errors can't land in a later test.
    await taskProvider.waitForPendingOperations();
    taskProvider.dispose();
    if (testDb.isOpen) {
      await testDb.close();
    }
  });

  group('New-task-top-insert #6: same-parent drag reorder', () {
    test(
      'dragging the bottom root above the middle root lands it exactly there '
      '(pre-existing negative positions {-2,-1,0})',
      () async {
        // Create three root tasks: positions come out 0, -1, -2 (MIN - 1),
        // i.e. exactly the {-2, -1, 0} spread called out in the spec.
        final t1 = await taskService.createTask('T1'); // position 0 (bottom)
        final t2 = await taskService.createTask('T2'); // position -1 (middle)
        final t3 = await taskService.createTask('T3'); // position -2 (top)
        expect([t1.position, t2.position, t3.position], [0, -1, -2]);

        await taskProvider.loadTasks();
        final draggedT1 = taskProvider.tasks.firstWhere((t) => t.id == t1.id);
        final targetT2 = taskProvider.tasks.firstWhere((t) => t.id == t2.id);

        // Drag T1 (bottom) "above" T2 (middle): T1 should land directly above
        // T2, but must NOT jump above T3 (the pre-fix bug: raw position -1 for
        // T2 got compared against T3's *reindexed* value, not its stale -2).
        await taskProvider.onNodeAccepted(TreeDragAndDropDetails<Task>(
          draggedNode: draggedT1,
          targetNode: targetT2,
          dropPosition: above,
          targetBounds: targetBounds,
        ));

        await taskProvider.loadTasks();
        final roots = taskProvider.tasks.where((t) => t.parentId == null).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        expect(
          roots.map((t) => t.id).toList(),
          [t3.id, t1.id, t2.id],
          reason: 'Expected order T3, T1, T2 (T1 dropped directly above T2)',
        );
      },
    );

    test(
      'dragging the top root below the middle root lands it exactly there '
      '(pre-existing negative positions {-2,-1,0})',
      () async {
        final t1 = await taskService.createTask('T1'); // position 0 (bottom)
        final t2 = await taskService.createTask('T2'); // position -1 (middle)
        final t3 = await taskService.createTask('T3'); // position -2 (top)

        await taskProvider.loadTasks();
        final draggedT3 = taskProvider.tasks.firstWhere((t) => t.id == t3.id);
        final targetT2 = taskProvider.tasks.firstWhere((t) => t.id == t2.id);

        // Drag T3 (top) "below" T2 (middle): T3 should land directly below T2,
        // above T1.
        await taskProvider.onNodeAccepted(TreeDragAndDropDetails<Task>(
          draggedNode: draggedT3,
          targetNode: targetT2,
          dropPosition: below,
          targetBounds: targetBounds,
        ));

        await taskProvider.loadTasks();
        final roots = taskProvider.tasks.where((t) => t.parentId == null).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        expect(
          roots.map((t) => t.id).toList(),
          [t2.id, t3.id, t1.id],
          reason: 'Expected order T2, T3, T1 (T3 dropped directly below T2)',
        );
      },
    );

    test(
      'same-parent drag reorder while a tag filter is active still ranks '
      'against the TRUE sibling list, not the filtered snapshot',
      () async {
        // New-task-top-insert #6 amendment: TaskProvider._tasks holds only the
        // filtered subset whenever a tag filter is active (_onFilterChanged
        // assigns getFilteredTasks' results to _tasks). Only T2 is tagged, so
        // the filtered _tasks would contain just [T2] - if the sibling-rank
        // computation used that in-memory list instead of querying the DB, it
        // would never see T3 and would misplace the drop.
        final t1 = await taskService.createTask('T1'); // position 0 (bottom)
        final t2 = await taskService.createTask('T2'); // position -1 (middle)
        final t3 = await taskService.createTask('T3'); // position -2 (top)

        final tag = await tagService.createTag('work');
        await tagService.addTagToTask(t2.id, tag.id);

        filterProvider.setFilter(FilterState(
          selectedTagIds: [tag.id],
          logic: FilterLogic.or,
        ));
        await waitForFilterUpdate();

        // Sanity check: the filtered in-memory list really is missing T3.
        expect(filterProvider.hasActiveFilters, isTrue);
        expect(taskProvider.tasks.map((t) => t.id), [t2.id]);

        // Drag T1 (bottom) "above" T2 (middle) while the filter above is
        // active. Use the original (unfiltered) task snapshots for the drag
        // details, since the tree wouldn't offer T1/T3 as drag targets from
        // the filtered `_tasks` list, but the DB rows are unaffected by the
        // filter and that's what the fix must rank against.
        await taskProvider.onNodeAccepted(TreeDragAndDropDetails<Task>(
          draggedNode: t1,
          targetNode: t2,
          dropPosition: above,
          targetBounds: targetBounds,
        ));

        // Verify against the raw DB state (bypassing the still-filtered
        // provider view) that T1 landed directly above T2, below T3.
        final active = await taskService.getAllTasks();
        final roots = active.where((t) => t.parentId == null).toList();
        expect(
          roots.map((t) => t.id).toList(),
          [t3.id, t1.id, t2.id],
          reason: 'Expected order T3, T1, T2 even with a tag filter active',
        );
      },
    );
  });

  group('New-task-top-insert #6: cross-parent drag reorder', () {
    test(
      'cross-parent move with negative source/destination positions drops '
      'exactly above the target',
      () async {
        // RootA and RootB are both root-level, so both have MIN - 1 (negative)
        // positions. RootB's children are seeded directly via updateTaskParent
        // with deliberately non-compact negative positions {-5, -3, -1} - e.g.
        // as they'd be left by a mix of past drag operations - to exercise the
        // destination side of the fix.
        final rootA = await taskService.createTask('Root A');
        final rootB = await taskService.createTask('Root B');
        final mover = await taskService.createTask('Mover');
        final childP = await taskService.createTask('Child P');
        final childQ = await taskService.createTask('Child Q');
        final childR = await taskService.createTask('Child R');

        // Nest Mover under Root A (the source list for the cross-parent move).
        await taskService.updateTaskParent(mover.id, rootA.id, 0);

        // Seed Root B's children at non-compact negative positions.
        await taskService.updateTaskParent(childP.id, rootB.id, -5);
        await taskService.updateTaskParent(childQ.id, rootB.id, -3);
        await taskService.updateTaskParent(childR.id, rootB.id, -1);

        await taskProvider.loadTasks();
        final draggedMover = taskProvider.tasks.firstWhere((t) => t.id == mover.id);
        final targetChildQ = taskProvider.tasks.firstWhere((t) => t.id == childQ.id);

        // Drag Mover (currently a child of Root A) "above" Child Q (a child of
        // Root B): this is a cross-parent move (Root A -> Root B).
        await taskProvider.onNodeAccepted(TreeDragAndDropDetails<Task>(
          draggedNode: draggedMover,
          targetNode: targetChildQ,
          dropPosition: above,
          targetBounds: targetBounds,
        ));

        await taskProvider.loadTasks();

        // Mover should now be a child of Root B, directly above Child Q.
        final rootBChildren = taskProvider.tasks.where((t) => t.parentId == rootB.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        expect(
          rootBChildren.map((t) => t.id).toList(),
          [childP.id, mover.id, childQ.id, childR.id],
          reason: 'Mover should land directly above Child Q, below Child P',
        );

        // Root A should have no children left.
        final rootAChildren = taskProvider.tasks.where((t) => t.parentId == rootA.id);
        expect(rootAChildren, isEmpty);
      },
    );
  });
}
