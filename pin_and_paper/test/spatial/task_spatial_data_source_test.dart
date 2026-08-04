import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/spatial/amethyst_desk_entity.dart';
import 'package:pin_and_paper/spatial/task_spatial_data_source.dart';
import 'package:pin_and_paper/spatial/task_spatial_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database_helper.dart';

const _kCanvasSize = Size(2000, 1500);

/// The task-card entities only (every data source also hosts the one
/// [AmethystDeskEntity] desk object, which most layout tests ignore).
List<TaskSpatialEntity> _cards(TaskSpatialDataSource dataSource) =>
    dataSource.getVisibleEntities(Rect.zero).whereType<TaskSpatialEntity>().toList();

AmethystDeskEntity _stone(TaskSpatialDataSource dataSource) =>
    dataSource.getVisibleEntities(Rect.zero).whereType<AmethystDeskEntity>().single;

void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late Database testDb;
  late TaskService taskService;

  setUp(() async {
    // Fresh, empty prefs per test so amethyst position/size never leaks
    // between tests.
    SharedPreferences.setMockInitialValues({});
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    taskService = TaskService();
  });

  tearDown(() async {
    if (testDb.isOpen) {
      await testDb.close();
    }
  });

  Future<TaskSpatialDataSource> buildDataSource() async {
    final tasks = await taskService.getAllTasks();
    final dataSource = TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: _kCanvasSize);
    await dataSource.initialized;
    return dataSource;
  }

  group('TaskSpatialDataSource layout — placed tasks', () {
    test('a task with stored canvas_x/canvas_y renders exactly there', () async {
      final task = await taskService.createTask('Placed card');
      await taskService.updateTaskCanvasPosition(task.id, 400.0, 250.0);

      final entities = _cards(await buildDataSource());

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

      final entities = _cards(await buildDataSource());

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
      final entities = _cards(await buildDataSource());

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

    test('a stacked tray past kTaskTrayRenderCap emits only the topmost (newest) cards', () async {
      for (var i = 0; i < kTaskTrayRenderCap + 10; i++) {
        await taskService.createTask('Card $i');
      }
      final dataSource = await buildDataSource();
      final entities = _cards(dataSource);

      // The cap trims widgets, not data: exactly the cap's worth render,
      // and they're the newest ones (highest zIndex = top of the stack) --
      // the buried oldest cards are the invisible/ungrabbable ones.
      expect(entities, hasLength(kTaskTrayRenderCap));
      final titles = entities.map((e) => e.task.title).toSet();
      expect(titles, contains('Card ${kTaskTrayRenderCap + 9}')); // newest
      expect(titles, isNot(contains('Card 0'))); // buried oldest

      // Spreading the tray surfaces every card, cap not applied.
      dataSource.setTrayArranged(true);
      expect(_cards(dataSource), hasLength(kTaskTrayRenderCap + 10));
    });
  });

  group('TaskSpatialDataSource layout — completed tasks', () {
    test('a completed unplaced task is omitted from the tray stack entirely', () async {
      final done = await taskService.createTask('Finished chore');
      await taskService.toggleTaskCompletion(done);
      final active = await taskService.createTask('Still to do');

      final entities = _cards(await buildDataSource());

      expect(entities, hasLength(1));
      expect(entities.single.id, active.id);
      // The sole remaining tray card sits at the anchor: the completed task
      // doesn't occupy a tray slot, it's simply gone.
      expect(entities.single.position, taskTrayAnchor(_kCanvasSize));
    });

    test('a completed task with a stored canvas position still renders there', () async {
      final placed = await taskService.createTask('Placed then finished');
      await taskService.updateTaskCanvasPosition(placed.id, 600.0, 450.0);
      // `placed` predates the position update — toggleTaskCompletion only
      // writes the columns it changes, so the stale object must not clobber
      // canvas_x/canvas_y (regression guard alongside task_service_canvas_test).
      await taskService.toggleTaskCompletion(placed);

      final entities = _cards(await buildDataSource());

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
      final entities = _cards(await buildDataSource());

      expect(entities, hasLength(10));
      // Untightened base step: the furthest card sits at anchor + step*9.
      final anchor = taskTrayAnchor(_kCanvasSize);
      final positions = entities.map((e) => e.position).toSet();
      expect(positions, contains(anchor + kTaskTrayBaseStep * 9.0));
    });
  });

  group('TaskSpatialDataSource — hide completed placed pref', () {
    test('defaults to shown; setHideCompletedPlaced(true) hides only placed completed cards', () async {
      final activePlaced = await taskService.createTask('Active placed');
      await taskService.updateTaskCanvasPosition(activePlaced.id, 100.0, 100.0);
      final donePlaced = await taskService.createTask('Done placed');
      await taskService.updateTaskCanvasPosition(donePlaced.id, 300.0, 300.0);
      await taskService.toggleTaskCompletion(donePlaced);
      final inbox = await taskService.createTask('Inbox card');

      final dataSource = await buildDataSource();
      expect(dataSource.hideCompletedPlaced, isFalse);
      expect(_cards(dataSource).map((e) => e.id), containsAll([activePlaced.id, donePlaced.id, inbox.id]));

      var notified = 0;
      dataSource.addListener(() => notified++);
      dataSource.setHideCompletedPlaced(true);

      expect(notified, 1);
      final visibleIds = _cards(dataSource).map((e) => e.id).toList();
      expect(visibleIds, isNot(contains(donePlaced.id)));
      // Active placed card and tray card are untouched; the stone stays too.
      expect(visibleIds, containsAll([activePlaced.id, inbox.id]));
      expect(_stone(dataSource), isNotNull);

      // Toggling back reveals the card exactly where it was — view-state
      // only, no position writes.
      dataSource.setHideCompletedPlaced(false);
      final revealed = _cards(dataSource).singleWhere((e) => e.id == donePlaced.id);
      expect(revealed.position, const Offset(300.0, 300.0));
    });

    test('persists: a fresh data source restores the hidden state from prefs', () async {
      final done = await taskService.createTask('Done placed');
      await taskService.updateTaskCanvasPosition(done.id, 300.0, 300.0);
      await taskService.toggleTaskCompletion(done);

      final first = await buildDataSource();
      first.setHideCompletedPlaced(true);
      // The persist is fire-and-forget; drain the event queue so it lands
      // before rebuilding (in-memory mock prefs — no real I/O to race).
      await pumpEventQueue();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TaskSpatialDataSource.kHideCompletedPlacedKey), isTrue);

      final second = await buildDataSource();
      expect(second.hideCompletedPlaced, isTrue);
      expect(_cards(second).map((e) => e.id), isNot(contains(done.id)));
    });

    test('setting the same value twice does not re-notify or re-persist', () async {
      final dataSource = await buildDataSource();
      var notified = 0;
      dataSource.addListener(() => notified++);

      dataSource.setHideCompletedPlaced(false); // already the default
      expect(notified, 0);
      dataSource.setHideCompletedPlaced(true);
      dataSource.setHideCompletedPlaced(true);
      expect(notified, 1);
    });
  });

  group('TaskSpatialDataSource — arrange toggle', () {
    test('setTrayArranged(true) spreads the tray into a newest-first grid; false restacks', () async {
      final oldest = await taskService.createTask('Oldest');
      final newest = await taskService.createTask('Newest');
      final dataSource = await buildDataSource();

      expect(dataSource.trayArranged, isFalse);
      dataSource.setTrayArranged(true);
      expect(dataSource.trayArranged, isTrue);

      final byId = {for (final e in _cards(dataSource)) e.id: e};
      // Newest takes the top-left slot; oldest sits one cell to its right.
      const margin = kTrayArrangeMargin;
      expect(byId[newest.id]!.position, const Offset(margin, margin));
      expect(byId[oldest.id]!.position.dy, margin);
      expect(byId[oldest.id]!.position.dx, greaterThan(margin));

      dataSource.setTrayArranged(false);
      final restacked = {for (final e in _cards(dataSource)) e.id: e};
      final anchor = taskTrayAnchor(_kCanvasSize);
      expect(restacked[oldest.id]!.position, anchor);
      expect(restacked[newest.id]!.position, anchor + kTaskTrayBaseStep);
    });

    test('arranged positions are in-memory only; dragging a grid card is what places it', () async {
      final task = await taskService.createTask('Inbox card');
      final dataSource = await buildDataSource();
      dataSource.setTrayArranged(true);

      // Arranging persisted nothing.
      var reloaded = (await taskService.getAllTasks()).firstWhere((t) => t.id == task.id);
      expect(reloaded.canvasX, isNull);

      // Dragging the arranged card places it for real.
      dataSource.onEntityMoved(task.id, const Offset(500.0, 500.0), 0);
      await _waitForCanvasPosition(taskService, task.id, const Offset(500.0, 500.0));
      reloaded = (await taskService.getAllTasks()).firstWhere((t) => t.id == task.id);
      expect(reloaded.canvasX, 500.0);

      // And restacking no longer touches it -- it left the tray.
      dataSource.setTrayArranged(false);
      final entity = _cards(dataSource).singleWhere((e) => e.id == task.id);
      expect(entity.position, const Offset(500.0, 500.0));
    });
  });

  group('TaskSpatialDataSource — amethyst desk object', () {
    test('every desk hosts the amethyst, centered by default, above all cards', () async {
      await taskService.createTask('A card');
      final dataSource = await buildDataSource();
      final stone = _stone(dataSource);

      expect(stone.position, const Offset((2000 - 150) / 2, (1500 - 120) / 2));
      expect(stone.size, kAmethystDefaultSize);
      for (final card in _cards(dataSource)) {
        expect(stone.zIndex, greaterThan(card.zIndex),
            reason: 'the stone is a paperweight: never buried under cards');
      }
    });

    test('moving the amethyst persists via prefs, not the tasks table, and survives reopen', () async {
      final dataSource = await buildDataSource();
      dataSource.onEntityMoved(kAmethystDeskId, const Offset(111.0, 222.0), 0);
      await pumpEventQueue();

      final reopened = await buildDataSource();
      expect(_stone(reopened).position, const Offset(111.0, 222.0));
    });

    test('resizeAmethyst scales from center, clamps width to [90, 280], and survives reopen', () async {
      final dataSource = await buildDataSource();
      final stone = _stone(dataSource);
      final centerBefore = stone.position + Offset(stone.size.width / 2, stone.size.height / 2);

      dataSource.resizeAmethyst(1.15);
      expect(stone.size.width, closeTo(150 * 1.15, 0.001));
      expect(stone.size.height / stone.size.width, closeTo(120 / 150, 0.001));
      final centerAfter = stone.position + Offset(stone.size.width / 2, stone.size.height / 2);
      expect(centerAfter.dx, closeTo(centerBefore.dx, 0.001));
      expect(centerAfter.dy, closeTo(centerBefore.dy, 0.001));

      for (var i = 0; i < 20; i++) {
        dataSource.resizeAmethyst(1.15);
      }
      expect(stone.size.width, 280.0, reason: 'growth clamps at 280');
      for (var i = 0; i < 20; i++) {
        dataSource.resizeAmethyst(1 / 1.15);
      }
      expect(stone.size.width, 90.0, reason: 'shrink clamps at 90');
      await pumpEventQueue();

      final reopened = await buildDataSource();
      expect(_stone(reopened).size.width, 90.0);
    });

    test('double-tapping the amethyst never flips it', () async {
      final dataSource = await buildDataSource();
      dataSource.onEntityDoubleTapped(kAmethystDeskId);
      expect(dataSource.isFlipped(kAmethystDeskId), isFalse);
    });
  });

  group('TaskSpatialDataSource.onEntityMoved', () {
    test('persists the dragged position via TaskService (headless proxy for "survives restart")', () async {
      final task = await taskService.createTask('Draggable card');
      final dataSource = await buildDataSource();

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
      final dataSource = await buildDataSource();

      dataSource.onEntityMoved(task.id, const Offset(1.0, 2.0), 0);
      final entity = _cards(dataSource).single;
      expect(entity.position, const Offset(1.0, 2.0));

      await pumpEventQueue();
    });

    test('dragging the top tray card out: reopening (fresh data source) promotes the next card to the top', () async {
      final oldest = await taskService.createTask('Oldest');
      final newest = await taskService.createTask('Newest');

      final firstOpen = await buildDataSource();
      final entitiesBefore = _cards(firstOpen);
      final topBefore = entitiesBefore.reduce((a, b) => a.zIndex >= b.zIndex ? a : b);
      expect(topBefore.id, newest.id); // newest is the top of the tray

      // Drag the top card out of the tray onto the open desk.
      firstOpen.onEntityMoved(newest.id, const Offset(900.0, 900.0), 0);

      // onEntityMoved's persist is fire-and-forget (unawaited) -- poll for
      // the persisted position instead of racing a fixed-size drain (see
      // _waitForCanvasPosition doc).
      await _waitForCanvasPosition(taskService, newest.id, const Offset(900.0, 900.0));

      // Reopening (fresh snapshot + fresh data source) is this milestone's
      // headless proxy for "close and reopen the Spatial View".
      final secondOpen = await buildDataSource();
      final entitiesAfter = _cards(secondOpen);

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
      final dataSource = await buildDataSource();

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
      final dataSource = await buildDataSource();

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
