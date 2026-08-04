import 'dart:convert' show jsonEncode;

import 'package:flutter/widgets.dart' show Color, Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task_drawing.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/drawing_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/spatial/amethyst_desk_entity.dart';
import 'package:pin_and_paper/spatial/task_spatial_data_source.dart';
import 'package:pin_and_paper/spatial/task_spatial_entity.dart';
import 'package:pin_and_paper_sketchpad/sketchpad.dart';
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

  group('TaskSpatialDataSource layout — completed tasks & the done pile', () {
    test('a completed unplaced task moves to the done pile, not the tray', () async {
      final done = await taskService.createTask('Finished chore');
      await taskService.toggleTaskCompletion(done);
      final active = await taskService.createTask('Still to do');

      final entities = _cards(await buildDataSource());
      final byId = {for (final e in entities) e.id: e};

      expect(entities, hasLength(2));
      // The active card has the tray to itself: the completed task doesn't
      // occupy a tray slot.
      expect(byId[active.id]!.position, taskTrayAnchor(_kCanvasSize));
      expect(byId[done.id]!.position, completedStackAnchor(_kCanvasSize));
    });

    test('a placed completed card sits in the done pile, not at its desk spot', () async {
      // Doubles as the stale-object canvas-clobber regression guard:
      // toggleTaskCompletion gets the pre-position Task object and must not
      // wipe canvas_x/canvas_y (it only writes the columns it owns).
      final placed = await taskService.createTask('Placed then finished');
      await taskService.updateTaskCanvasPosition(placed.id, 600.0, 450.0);
      await taskService.toggleTaskCompletion(placed); // deliberately stale object

      final entities = _cards(await buildDataSource());
      expect(entities, hasLength(1));
      expect(entities.single.position, completedStackAnchor(_kCanvasSize));

      final reloaded = (await taskService.getAllTasks()).firstWhere((t) => t.id == placed.id);
      expect(reloaded.canvasX, 600.0);
      expect(reloaded.canvasY, 450.0);

      // Uncompleting returns the card to its exact desk spot.
      await taskService.uncompleteTask(placed.id);
      final restored = _cards(await buildDataSource());
      expect(restored, hasLength(1));
      expect(restored.single.position, const Offset(600.0, 450.0));
    });

    test('the pile holds only the most recent $kRecentCompletedCount, newest on top', () async {
      // 12 completions with deterministic completed_at: 'Done 0' oldest.
      for (var i = 0; i < 12; i++) {
        final t = await taskService.createTask('Done $i');
        await taskService.toggleTaskCompletion(t);
        await testDb.update('tasks', {'completed_at': 1000 + i}, where: 'id = ?', whereArgs: [t.id]);
      }
      final entities = _cards(await buildDataSource());

      expect(entities, hasLength(kRecentCompletedCount));
      final titles = entities.map((e) => e.task.title).toSet();
      expect(titles, isNot(contains('Done 0'))); // the two oldest dropped off
      expect(titles, isNot(contains('Done 1')));
      expect(titles, contains('Done 11'));

      // Newest completion: deepest fan offset AND highest zIndex.
      final newest = entities.singleWhere((e) => e.task.title == 'Done 11');
      expect(
        newest.position,
        completedStackAnchor(_kCanvasSize) + kTaskTrayBaseStep * (kRecentCompletedCount - 1).toDouble(),
      );
      final topZ = entities.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b);
      expect(newest.zIndex, topZ);
    });

    test('pile cards snap back when dragged and never persist a position', () async {
      final done = await taskService.createTask('Done card');
      await taskService.toggleTaskCompletion(done);
      final dataSource = await buildDataSource();
      final before = _cards(dataSource).single.position;

      dataSource.onEntityMoved(done.id, const Offset(500.0, 500.0), 0);
      await pumpEventQueue();

      expect(_cards(dataSource).single.position, before);
      final reloaded = (await taskService.getAllTasks()).firstWhere((t) => t.id == done.id);
      expect(reloaded.canvasX, isNull);
    });

    test('completed tasks do not count toward the tray tighten threshold', () async {
      // 10 active + 10 completed = 20 cards total (tray + pile), but only
      // the 10 active occupy the tray — under the threshold, no tightening.
      for (var i = 0; i < 10; i++) {
        await taskService.createTask('Active $i');
      }
      for (var i = 0; i < 10; i++) {
        final t = await taskService.createTask('Done $i');
        await taskService.toggleTaskCompletion(t);
      }
      final entities = _cards(await buildDataSource());

      expect(entities, hasLength(20)); // 10 tray + 10 pile
      // Untightened base step: the furthest tray card sits at anchor+step*9.
      final anchor = taskTrayAnchor(_kCanvasSize);
      final positions = entities.map((e) => e.position).toSet();
      expect(positions, contains(anchor + kTaskTrayBaseStep * 9.0));
    });
  });

  group('TaskSpatialDataSource — flip view modes', () {
    test('allBacks/allFronts override per-card flips without destroying them', () async {
      final a = await taskService.createTask('A');
      final b = await taskService.createTask('B');
      final dataSource = await buildDataSource();
      dataSource.onEntityDoubleTapped(a.id); // A manually flipped

      dataSource.setFlipViewMode(FlipViewMode.allBacks);
      expect(dataSource.isFlipped(a.id), isTrue);
      expect(dataSource.isFlipped(b.id), isTrue);

      dataSource.setFlipViewMode(FlipViewMode.allFronts);
      expect(dataSource.isFlipped(a.id), isFalse);
      expect(dataSource.isFlipped(b.id), isFalse);

      dataSource.setFlipViewMode(FlipViewMode.manual);
      expect(dataSource.isFlipped(a.id), isTrue); // manual state survived
      expect(dataSource.isFlipped(b.id), isFalse);
    });

    test('commitFlipView adopts the override as the new manual state', () async {
      final a = await taskService.createTask('A');
      final b = await taskService.createTask('B');
      final dataSource = await buildDataSource();
      dataSource.onEntityDoubleTapped(a.id);

      dataSource.setFlipViewMode(FlipViewMode.allBacks);
      dataSource.commitFlipView();

      expect(dataSource.flipViewMode, FlipViewMode.manual);
      expect(dataSource.isFlipped(a.id), isTrue);
      expect(dataSource.isFlipped(b.id), isTrue);
    });

    test('double-tap during an override keeps the view and toggles just that card', () async {
      final a = await taskService.createTask('A');
      final b = await taskService.createTask('B');
      final dataSource = await buildDataSource();
      dataSource.onEntityDoubleTapped(b.id); // pre-override manual flip

      dataSource.setFlipViewMode(FlipViewMode.allFronts);
      dataSource.onEntityDoubleTapped(a.id); // flip A to its back

      expect(dataSource.flipViewMode, FlipViewMode.manual);
      expect(dataSource.isFlipped(a.id), isTrue);
      // B stays as the override showed it (front), not its old manual flip:
      // the on-screen view must not jump when a double-tap exits override.
      expect(dataSource.isFlipped(b.id), isFalse);
    });

    test('mode changes notify once; same-mode sets and manual commits are no-ops', () async {
      await taskService.createTask('A');
      final dataSource = await buildDataSource();
      var notified = 0;
      dataSource.addListener(() => notified++);

      dataSource.setFlipViewMode(FlipViewMode.manual); // already manual
      expect(notified, 0);
      dataSource.setFlipViewMode(FlipViewMode.allBacks);
      dataSource.setFlipViewMode(FlipViewMode.allBacks);
      expect(notified, 1);
      dataSource.commitFlipView();
      expect(notified, 2);
      dataSource.commitFlipView(); // already manual: no-op
      expect(notified, 2);
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

  group('TaskSpatialDataSource — card drawings (M-D5)', () {
    late DrawingService drawingService;

    setUp(() {
      drawingService = DrawingService();
    });

    test('drawings for every task and both faces load at construction (await initialized)', () async {
      final drawn = await taskService.createTask('Drawn card');
      final plain = await taskService.createTask('Plain card');
      final frontJson = _drawingJson(label: 10);
      final backJson = _drawingJson(label: 20);
      await drawingService.saveTaskDrawing(drawn.id, frontJson);
      await drawingService.saveTaskDrawing(drawn.id, backJson, face: TaskDrawing.faceBack);

      final dataSource = await buildDataSource();

      expect(dataSource.drawingJsonFor(drawn.id), frontJson);
      expect(dataSource.drawingJsonFor(drawn.id, face: TaskDrawing.faceBack), backJson);
      expect(dataSource.isDrawingVisible(drawn.id), isTrue);
      expect(dataSource.isDrawingVisible(drawn.id, face: TaskDrawing.faceBack), isTrue);

      // No drawing: null JSON, and "visible" is false (there is nothing to
      // show), not an error.
      expect(dataSource.drawingJsonFor(plain.id), isNull);
      expect(dataSource.isDrawingVisible(plain.id), isFalse);
      expect(dataSource.hasHiddenDrawing(plain.id), isFalse);
    });

    test('drawingStackFor parses format v1 and returns the SAME cached instance across calls', () async {
      final task = await taskService.createTask('Cached card');
      await drawingService.saveTaskDrawing(task.id, _drawingJson(label: 30));
      final dataSource = await buildDataSource();

      final first = dataSource.drawingStackFor(task.id);
      final second = dataSource.drawingStackFor(task.id);

      expect(first, isNotNull);
      expect(first!.layers.any((l) => l.strokes.isNotEmpty), isTrue);
      // Identity, not just equality: DrawingPreview's picture cache keys on
      // the stack instance, so a fresh parse per canvas rebuild would
      // re-record every frame.
      expect(identical(first, second), isTrue);

      // Corrupt JSON parses to null (logged once, no crash).
      final corrupt = await taskService.createTask('Corrupt card');
      await drawingService.saveTaskDrawing(corrupt.id, '{"v":99}');
      final ds2 = await buildDataSource();
      expect(ds2.drawingStackFor(corrupt.id), isNull);
    });

    test('toggleDrawingVisible flips in memory, notifies, and persists across a restart', () async {
      final task = await taskService.createTask('Peekaboo card');
      await drawingService.saveTaskDrawing(task.id, _drawingJson(label: 40));
      final dataSource = await buildDataSource();

      var notifyCount = 0;
      dataSource.addListener(() => notifyCount++);

      dataSource.toggleDrawingVisible(task.id);

      // In-memory state flips synchronously (immediate repaint)...
      expect(dataSource.isDrawingVisible(task.id), isFalse);
      expect(dataSource.hasHiddenDrawing(task.id), isTrue);
      expect(notifyCount, 1);

      // ...and the DB write lands (fire-and-forget — poll, don't race).
      await _waitForDrawingVisible(drawingService, task.id, TaskDrawing.faceFront, false);

      // Restart proxy: a fresh data source sees the persisted hide.
      final secondOpen = await buildDataSource();
      expect(secondOpen.isDrawingVisible(task.id), isFalse);
      expect(secondOpen.hasHiddenDrawing(task.id), isTrue);

      // Toggle back on.
      secondOpen.toggleDrawingVisible(task.id);
      expect(secondOpen.isDrawingVisible(task.id), isTrue);
      expect(secondOpen.hasHiddenDrawing(task.id), isFalse);
      await _waitForDrawingVisible(drawingService, task.id, TaskDrawing.faceFront, true);
    });

    test('toggleDrawingVisible on a face with no drawing is a no-op', () async {
      final task = await taskService.createTask('Blank card');
      final dataSource = await buildDataSource();

      var notifyCount = 0;
      dataSource.addListener(() => notifyCount++);

      dataSource.toggleDrawingVisible(task.id);
      await pumpEventQueue();

      expect(notifyCount, 0);
      expect(dataSource.isDrawingVisible(task.id), isFalse);
    });

    test('hasHiddenDrawing is true when ANY face is hidden', () async {
      final task = await taskService.createTask('Two-faced card');
      await drawingService.saveTaskDrawing(task.id, _drawingJson(label: 50));
      await drawingService.saveTaskDrawing(task.id, _drawingJson(label: 60), face: TaskDrawing.faceBack);
      final dataSource = await buildDataSource();

      expect(dataSource.hasHiddenDrawing(task.id), isFalse);

      // Hide only the back: front still visible, but the tell shows.
      dataSource.toggleDrawingVisible(task.id, face: TaskDrawing.faceBack);
      expect(dataSource.isDrawingVisible(task.id), isTrue);
      expect(dataSource.isDrawingVisible(task.id, face: TaskDrawing.faceBack), isFalse);
      expect(dataSource.hasHiddenDrawing(task.id), isTrue);

      dataSource.toggleDrawingVisible(task.id, face: TaskDrawing.faceBack);
      expect(dataSource.hasHiddenDrawing(task.id), isFalse);
      // Wait for the fire-and-forget writes to land before teardown closes
      // the DB (pumpEventQueue alone races real ffi I/O).
      await _waitForDrawingVisible(drawingService, task.id, TaskDrawing.faceBack, true);
    });

    test('refreshDrawingFor picks up a drawing saved after construction', () async {
      final task = await taskService.createTask('Late bloomer');
      final dataSource = await buildDataSource();
      expect(dataSource.drawingJsonFor(task.id), isNull);

      // The editor saves behind the data source's back...
      final json = _drawingJson(label: 70);
      await drawingService.saveTaskDrawing(task.id, json);

      var notifyCount = 0;
      dataSource.addListener(() => notifyCount++);

      // ...and refreshDrawingFor re-reads just that task's rows.
      await dataSource.refreshDrawingFor(task.id);

      expect(dataSource.drawingJsonFor(task.id), json);
      expect(dataSource.isDrawingVisible(task.id), isTrue);
      expect(notifyCount, 1);

      // A re-save (new ink) also refreshes the parsed-stack cache.
      final before = dataSource.drawingStackFor(task.id);
      final updated = _drawingJson(label: 80);
      await drawingService.saveTaskDrawing(task.id, updated);
      await dataSource.refreshDrawingFor(task.id);
      expect(dataSource.drawingJsonFor(task.id), updated);
      expect(identical(dataSource.drawingStackFor(task.id), before), isFalse);
    });
  });
}

/// A minimal valid format-v1 drawing (one ink stroke), varied by [label] so
/// distinct drawings serialize to distinct JSON.
String _drawingJson({required int label}) {
  final stack = LayerStack(size: const Size(880, 560));
  stack.addStrokeToActiveLayer(
    Stroke(
      points: [StrokePoint(label.toDouble(), 10, 0.5), StrokePoint(label + 40.0, 60, 0.5)],
      color: const Color(0xFF2D2D2D),
      options: StrokeOptions.ink,
    ),
  );
  return jsonEncode(stack.toJson());
}

/// Polls the DB for a drawing's visible flag — same rationale as
/// [_waitForCanvasPosition]: toggleDrawingVisible persists fire-and-forget
/// against real sqflite_common_ffi I/O.
Future<void> _waitForDrawingVisible(
  DrawingService drawingService,
  String taskId,
  String face,
  bool expected,
) async {
  const timeout = Duration(seconds: 5);
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final drawing = await drawingService.getDrawingForTask(taskId, face: face);
    if (drawing != null && drawing.visible == expected) return;
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $taskId/$face drawing visible == $expected '
          '(last seen: ${drawing?.visible})');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
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
