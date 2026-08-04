import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/spatial/task_spatial_data_source.dart';
import 'package:pin_and_paper/spatial/task_spatial_entity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database_helper.dart';

const _kCanvasSize = Size(2000, 1500);

void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late Database testDb;
  late TaskService taskService;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    taskService = TaskService();
  });

  tearDown(() async {
    if (testDb.isOpen) {
      await testDb.close();
    }
  });

  group('TaskSpatialDataSource layout — placed tasks', () {
    test('a task with stored canvas_x/canvas_y renders exactly there', () async {
      final task = await taskService.createTask('Placed card');
      await taskService.updateTaskCanvasPosition(task.id, 400.0, 250.0);
      final tasks = await taskService.getAllTasks();

      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);
      final entities = dataSource.getVisibleEntities(Rect.zero);

      expect(entities, hasLength(1));
      expect(entities.single.position, const Offset(400.0, 250.0));
    });
  });

  group('TaskSpatialDataSource layout — landing tray (M3/M4 addendum item 11)', () {
    test('unplaced tasks stack at the tray anchor with Offset(7,5)*i steps, newest on top', () async {
      // Sequential createTask() calls assign strictly decreasing positions
      // (new-task-top-insert), so `newest` (created last) ends up with the
      // most negative position.
      final oldest = await taskService.createTask('Oldest');
      final middle = await taskService.createTask('Middle');
      final newest = await taskService.createTask('Newest');
      final tasks = await taskService.getAllTasks();

      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);
      final entities = dataSource
          .getVisibleEntities(Rect.zero)
          .cast<TaskSpatialEntity>()
          .toList();

      expect(entities, hasLength(3));

      final byId = {for (final e in entities) e.id: e};
      final anchor = taskTrayAnchor(_kCanvasSize);
      const step = kTaskTrayBaseStep; // count (3) is well under the tighten threshold

      // Oldest gets i=0 (no offset, sits at the anchor); each newer task
      // steps further into the fan; newest gets the largest offset.
      expect(byId[oldest.id]!.position, anchor);
      expect(byId[middle.id]!.position, anchor + step * 1.0);
      expect(byId[newest.id]!.position, anchor + step * 2.0);

      // Newest-on-top: zIndex = -position, and newest has the most negative
      // position, so it also has the strictly highest zIndex -- "on top" in
      // both the offset fan and the paint order agree.
      expect(byId[newest.id]!.zIndex, greaterThan(byId[middle.id]!.zIndex));
      expect(byId[middle.id]!.zIndex, greaterThan(byId[oldest.id]!.zIndex));
    });

    test('tightens the per-card step once the tray holds more than ~15 unplaced cards', () async {
      for (var i = 0; i < 20; i++) {
        await taskService.createTask('Card $i');
      }
      final tasks = await taskService.getAllTasks();
      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);
      final entities = dataSource
          .getVisibleEntities(Rect.zero)
          .cast<TaskSpatialEntity>()
          .toList();

      expect(entities, hasLength(20));
      final tightStep = taskTrayStackStep(20);
      expect(tightStep.dx, lessThan(kTaskTrayBaseStep.dx));
      expect(tightStep.dy, lessThan(kTaskTrayBaseStep.dy));

      // The furthest-offset card (index 19, the newest) still lands inside
      // the tray zone rather than escaping it.
      final anchor = taskTrayAnchor(_kCanvasSize);
      final maxOffset = tightStep * 19.0;
      expect(anchor.dx + maxOffset.dx, lessThan(anchor.dx + kTaskTrayZoneSize.width));
      expect(anchor.dy + maxOffset.dy, lessThan(anchor.dy + kTaskTrayZoneSize.height));
    });

    test('does not tighten at or below the ~15 threshold', () {
      expect(taskTrayStackStep(15), kTaskTrayBaseStep);
      expect(taskTrayStackStep(1), kTaskTrayBaseStep);
    });
  });

  group('TaskSpatialDataSource layout — completed tasks', () {
    test('a completed unplaced task is omitted from the tray stack entirely', () async {
      final done = await taskService.createTask('Finished chore');
      await taskService.toggleTaskCompletion(done);
      final active = await taskService.createTask('Still to do');
      final tasks = await taskService.getAllTasks();

      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);
      final entities = dataSource.getVisibleEntities(Rect.zero).cast<TaskSpatialEntity>().toList();

      expect(entities, hasLength(1));
      expect(entities.single.id, active.id);
      // The sole remaining tray card sits at the anchor: the completed task
      // doesn't occupy a tray slot, it's simply gone.
      expect(entities.single.position, taskTrayAnchor(_kCanvasSize));
    });

    test('a completed task with a stored canvas position still renders there', () async {
      final placed = await taskService.createTask('Placed then finished');
      await taskService.updateTaskCanvasPosition(placed.id, 600.0, 450.0);
      // Reload before toggling: toggleTaskCompletion writes the passed
      // task's full map, so a stale object (like `placed`, from before the
      // position update) would clobber canvas_x/canvas_y back to null.
      final withPosition = (await taskService.getAllTasks()).firstWhere((t) => t.id == placed.id);
      await taskService.toggleTaskCompletion(withPosition);
      final tasks = await taskService.getAllTasks();

      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);
      final entities = dataSource.getVisibleEntities(Rect.zero).cast<TaskSpatialEntity>().toList();

      expect(entities, hasLength(1));
      expect(entities.single.id, placed.id);
      expect(entities.single.position, const Offset(600.0, 450.0));
    });

    test('completed unplaced tasks do not count toward the tray tighten threshold', () async {
      // 10 active + 10 completed unplaced = 20 total, but only the 10 active
      // stack in the tray — well under the threshold, so no tightening.
      for (var i = 0; i < 10; i++) {
        await taskService.createTask('Active $i');
      }
      for (var i = 0; i < 10; i++) {
        final t = await taskService.createTask('Done $i');
        await taskService.toggleTaskCompletion(t);
      }
      final tasks = await taskService.getAllTasks();

      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);
      final entities = dataSource.getVisibleEntities(Rect.zero).cast<TaskSpatialEntity>().toList();

      expect(entities, hasLength(10));
      // Untightened base step: the furthest card sits at anchor + step*9.
      final anchor = taskTrayAnchor(_kCanvasSize);
      final positions = entities.map((e) => e.position).toSet();
      expect(positions, contains(anchor + kTaskTrayBaseStep * 9.0));
    });
  });

  group('TaskSpatialDataSource.onEntityMoved', () {
    test('persists the dragged position via TaskService (headless proxy for "survives restart")', () async {
      final task = await taskService.createTask('Draggable card');
      final tasks = await taskService.getAllTasks();
      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);

      dataSource.onEntityMoved(task.id, const Offset(777.0, 333.0), 0);

      // The persist is fire-and-forget; poll for it instead of racing a
      // single pumpEventQueue() drain against real sqflite_common_ffi I/O
      // (observed flaky under load -- see _waitForCanvasPosition doc).
      await _waitForCanvasPosition(taskService, task.id, const Offset(777.0, 333.0));

      final reloaded = await taskService.getAllTasks();
      final found = reloaded.firstWhere((t) => t.id == task.id);
      expect(found.canvasX, 777.0);
      expect(found.canvasY, 333.0);
    });

    test('updates the entity in place immediately (before the persist settles)', () async {
      final task = await taskService.createTask('Card');
      final tasks = await taskService.getAllTasks();
      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);

      dataSource.onEntityMoved(task.id, const Offset(1.0, 2.0), 0);
      final entity = dataSource.getVisibleEntities(Rect.zero).cast<TaskSpatialEntity>().single;
      expect(entity.position, const Offset(1.0, 2.0));

      await pumpEventQueue();
    });

    test('dragging the top tray card out: reopening (fresh data source) promotes the next card to the top', () async {
      final oldest = await taskService.createTask('Oldest');
      final newest = await taskService.createTask('Newest');
      final tasksBefore = await taskService.getAllTasks();

      final firstOpen = TaskSpatialDataSource(tasks: tasksBefore, taskService: taskService, canvasSize: _kCanvasSize);
      final entitiesBefore = firstOpen.getVisibleEntities(Rect.zero).cast<TaskSpatialEntity>().toList();
      final topBefore = entitiesBefore.reduce((a, b) => a.zIndex >= b.zIndex ? a : b);
      expect(topBefore.id, newest.id); // newest is the top of the tray

      // Drag the top card out of the tray onto the open desk.
      firstOpen.onEntityMoved(newest.id, const Offset(900.0, 900.0), 0);

      // onEntityMoved's persist is fire-and-forget (unawaited) -- a single
      // pumpEventQueue() drains a fixed number of event-loop turns, which
      // is not a guarantee that the real sqflite_common_ffi write has
      // actually landed under load (observed flaky: the write occasionally
      // hadn't landed yet, so the reopened data source below still saw the
      // task as unplaced). Poll for the persisted position instead of
      // racing a single fixed-size drain.
      await _waitForCanvasPosition(taskService, newest.id, const Offset(900.0, 900.0));

      // Reopening (fresh snapshot + fresh data source) is this milestone's
      // headless proxy for "close and reopen the Spatial View".
      final tasksAfter = await taskService.getAllTasks();
      final secondOpen = TaskSpatialDataSource(tasks: tasksAfter, taskService: taskService, canvasSize: _kCanvasSize);
      final entitiesAfter = secondOpen.getVisibleEntities(Rect.zero).cast<TaskSpatialEntity>().toList();

      final placedNewest = entitiesAfter.firstWhere((e) => e.id == newest.id);
      expect(placedNewest.position, const Offset(900.0, 900.0));

      final stillInTray = entitiesAfter.where((e) => e.id != newest.id).toList();
      expect(stillInTray, hasLength(1));
      expect(stillInTray.single.id, oldest.id);
      expect(stillInTray.single.position, taskTrayAnchor(_kCanvasSize)); // now the sole (and top) tray card
    });
  });

  group('TaskSpatialDataSource flip state (M3/M4 addendum item 1)', () {
    test('onEntityDoubleTapped toggles the flipped set and notifies listeners', () async {
      final task = await taskService.createTask('Flippable card');
      final tasks = await taskService.getAllTasks();
      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);

      var notifyCount = 0;
      dataSource.addListener(() => notifyCount++);

      expect(dataSource.isFlipped(task.id), isFalse);

      dataSource.onEntityDoubleTapped(task.id);
      expect(dataSource.isFlipped(task.id), isTrue);
      expect(notifyCount, 1);

      dataSource.onEntityDoubleTapped(task.id);
      expect(dataSource.isFlipped(task.id), isFalse);
      expect(notifyCount, 2);
    });

    test('flip state is per-id -- flipping one card does not affect another', () async {
      final a = await taskService.createTask('Card A');
      final b = await taskService.createTask('Card B');
      final tasks = await taskService.getAllTasks();
      final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);

      dataSource.onEntityDoubleTapped(a.id);
      expect(dataSource.isFlipped(a.id), isTrue);
      expect(dataSource.isFlipped(b.id), isFalse);
    });
  });
}

/// Polls [taskService] for [taskId]'s stored canvas position to reach
/// [expected], instead of racing a single fixed-size pumpEventQueue() drain
/// against onEntityMoved's fire-and-forget persist. sqflite_common_ffi
/// writes are real async I/O, not fake-clock timers, so a bounded number of
/// event-loop turns isn't a reliable "wait until settled" under load.
Future<void> _waitForCanvasPosition(TaskService taskService, String taskId, Offset expected) async {
  const timeout = Duration(seconds: 5);
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final tasks = await taskService.getAllTasks();
    final task = tasks.firstWhere((t) => t.id == taskId);
    if (task.canvasX == expected.dx && task.canvasY == expected.dy) return;
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'Timed out waiting for task $taskId to persist canvas position $expected '
        '(last seen: (${task.canvasX}, ${task.canvasY}))',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
