import 'dart:convert' show jsonEncode;
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Color, Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task_drawing.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/drawing_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/spatial/amethyst_desk_entity.dart';
import 'package:pin_and_paper/spatial/dachshund_desk_entity.dart';
import 'package:pin_and_paper/spatial/task_spatial_data_source.dart';
import 'package:pin_and_paper/spatial/task_spatial_entity.dart';
import 'package:pin_and_paper_canvas/spatial_canvas.dart' show DachshundStop, GemVariant;
import 'package:pin_and_paper_card_renderer/card_renderer.dart' show kCardSize;
import 'package:pin_and_paper_sketchpad/sketchpad.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database_helper.dart';

const _kCanvasSize = Size(2000, 1500);

/// The task-card entities only (every data source also hosts the one
/// [GemDeskEntity] desk objects, which most layout tests ignore).
List<TaskSpatialEntity> _cards(TaskSpatialDataSource dataSource) =>
    dataSource.getVisibleEntities(Rect.zero).whereType<TaskSpatialEntity>().toList();

GemDeskEntity _stone(TaskSpatialDataSource dataSource) =>
    dataSource.getVisibleEntities(Rect.zero).whereType<GemDeskEntity>().single;

DachshundDeskEntity _dog(TaskSpatialDataSource dataSource) =>
    dataSource.getVisibleEntities(Rect.zero).whereType<DachshundDeskEntity>().single;

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
      // The fan ENVELOPE centers on the anchor (owner 2026-08-04 night):
      // base card at anchor - extent/2, so the stack's visual middle sits
      // where a lone card would.
      final base = anchor - step * ((3 - 1) / 2);

      // Oldest gets i=0 (the base slot); each newer task steps further
      // into the fan; newest gets the largest offset.
      expect(byId[oldest.id]!.position, base);
      expect(byId[middle.id]!.position, base + step * 1.0);
      expect(byId[newest.id]!.position, base + step * 2.0);
      // Envelope midpoint = anchor.
      expect((byId[oldest.id]!.position + byId[newest.id]!.position) / 2, anchor);

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

      expect(entities, hasLength(10 + kRecentCompletedCount)); // tray + capped pile
      // Untightened base step, envelope centered on the anchor: base is
      // anchor - step*4.5, so the furthest tray card sits at anchor+step*4.5.
      final anchor = taskTrayAnchor(_kCanvasSize);
      final positions = entities.map((e) => e.position).toSet();
      expect(positions, contains(anchor + kTaskTrayBaseStep * 4.5));
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
      final base = anchor - kTaskTrayBaseStep * ((2 - 1) / 2);
      expect(restacked[oldest.id]!.position, base);
      expect(restacked[newest.id]!.position, base + kTaskTrayBaseStep);
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

      expect(
        stone.position,
        Offset((2000 - kAmethystDefaultSize.width) / 2, (1500 - kAmethystDefaultSize.height) / 2),
      );
      expect(stone.size, kAmethystDefaultSize);
      for (final card in _cards(dataSource)) {
        expect(stone.zIndex, greaterThan(card.zIndex),
            reason: 'the stone is a paperweight: never buried under cards');
      }
    });

    test('moving the amethyst persists as decor (desk_objects, not the tasks table) and survives reopen', () async {
      final dataSource = await buildDataSource();
      dataSource.onEntityMoved(kAmethystDeskId, const Offset(111.0, 222.0), 0);
      await pumpEventQueue();

      final reopened = await buildDataSource();
      expect(_stone(reopened).position, const Offset(111.0, 222.0));
    });

    test('resizeAmethyst scales from center, clamps width to [90, 490], and survives reopen', () async {
      final dataSource = await buildDataSource();
      final stone = _stone(dataSource);
      final centerBefore = stone.position + Offset(stone.size.width / 2, stone.size.height / 2);

      dataSource.resizeAmethyst(1.15);
      expect(stone.size.width, closeTo(kAmethystDefaultSize.width * 1.15, 0.001));
      expect(stone.size.height / stone.size.width, closeTo(1.0, 0.001)); // square sprite frames
      final centerAfter = stone.position + Offset(stone.size.width / 2, stone.size.height / 2);
      expect(centerAfter.dx, closeTo(centerBefore.dx, 0.001));
      expect(centerAfter.dy, closeTo(centerBefore.dy, 0.001));

      for (var i = 0; i < 20; i++) {
        dataSource.resizeAmethyst(1.15);
      }
      expect(stone.size.width, 490.0, reason: 'growth clamps at 490');
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

  group('TaskSpatialDataSource — desk-objects drawer', () {
    test('the dachshund starts in the drawer: unplaced, absent from the desk', () async {
      final dataSource = await buildDataSource();
      expect(dataSource.isDeskObjectPlaced(kDachshundDeskId), isFalse);
      expect(
        dataSource.getVisibleEntities(Rect.zero).whereType<DachshundDeskEntity>(),
        isEmpty,
      );
      // The stone predates the drawer and stays placed by default.
      expect(dataSource.isDeskObjectPlaced(kAmethystDeskId), isTrue);
    });

    test('placeDeskObject centers him on the view center and survives reopen', () async {
      final dataSource = await buildDataSource();
      dataSource.placeDeskObject(kDachshundDeskId, viewCenter: const Offset(500, 400));

      final dog = _dog(dataSource);
      final half = kDachshundDefaultSize.width / 2;
      expect(dataSource.isDeskObjectPlaced(kDachshundDeskId), isTrue);
      expect(dog.size, kDachshundDefaultSize);
      expect(dog.position, Offset(500 - half, 400 - half));
      await pumpEventQueue();

      final reopened = await buildDataSource();
      expect(reopened.isDeskObjectPlaced(kDachshundDeskId), isTrue);
      expect(_dog(reopened).position, Offset(500 - half, 400 - half));
    });

    test('placement clamps into the canvas bounds', () async {
      final dataSource = await buildDataSource();
      dataSource.placeDeskObject(kDachshundDeskId, viewCenter: Offset.zero);
      expect(_dog(dataSource).position, Offset.zero);
    });

    test('removeDeskObject puts him away but keeps his spot for re-placing', () async {
      final dataSource = await buildDataSource();
      dataSource.placeDeskObject(kDachshundDeskId, viewCenter: const Offset(600, 700));
      dataSource.removeDeskObject(kDachshundDeskId);

      expect(dataSource.isDeskObjectPlaced(kDachshundDeskId), isFalse);
      expect(
        dataSource.getVisibleEntities(Rect.zero).whereType<DachshundDeskEntity>(),
        isEmpty,
      );
      await pumpEventQueue();

      // Still in the drawer after a reopen...
      final reopened = await buildDataSource();
      expect(reopened.isDeskObjectPlaced(kDachshundDeskId), isFalse);

      // ...and re-placing WITHOUT a view center restores the exact spot.
      reopened.placeDeskObject(kDachshundDeskId);
      final half = kDachshundDefaultSize.width / 2;
      expect(_dog(reopened).position, Offset(600 - half, 700 - half));
    });

    test('the amethyst can be put away too, and stays away across reopen', () async {
      final dataSource = await buildDataSource();
      dataSource.removeDeskObject(kAmethystDeskId);
      expect(
        dataSource.getVisibleEntities(Rect.zero).whereType<GemDeskEntity>().where((e) => e.id == kAmethystDeskId),
        isEmpty,
      );
      await pumpEventQueue();

      final reopened = await buildDataSource();
      expect(reopened.isDeskObjectPlaced(kAmethystDeskId), isFalse);
    });

    test('double-tap turns the figurine to the next rotation stop and it survives reopen', () async {
      final dataSource = await buildDataSource();
      dataSource.placeDeskObject(kDachshundDeskId, viewCenter: const Offset(500, 400));
      expect(_dog(dataSource).stop, DachshundStop.threeQLeft);

      dataSource.onEntityDoubleTapped(kDachshundDeskId);
      expect(_dog(dataSource).stop, DachshundStop.threeQLeft.next);
      // Turning is a pose change, never a card flip.
      expect(dataSource.isFlipped(kDachshundDeskId), isFalse);
      await pumpEventQueue();

      final reopened = await buildDataSource();
      expect(_dog(reopened).stop, DachshundStop.threeQLeft.next);
    });

    test('resizeDeskObject keeps the dachshund square and clamps width to [112, 1176]', () async {
      final dataSource = await buildDataSource();
      dataSource.placeDeskObject(kDachshundDeskId, viewCenter: const Offset(500, 400));
      final dog = _dog(dataSource);
      final centerBefore = dog.position + Offset(dog.size.width / 2, dog.size.height / 2);

      dataSource.resizeDeskObject(kDachshundDeskId, 1.15);
      expect(dog.size.width, closeTo(kDachshundDefaultSize.width * 1.15, 0.001));
      expect(dog.size.height, closeTo(dog.size.width, 0.001));
      final centerAfter = dog.position + Offset(dog.size.width / 2, dog.size.height / 2);
      expect(centerAfter.dx, closeTo(centerBefore.dx, 0.001));
      expect(centerAfter.dy, closeTo(centerBefore.dy, 0.001));

      for (var i = 0; i < 20; i++) {
        dataSource.resizeDeskObject(kDachshundDeskId, 1.15);
      }
      expect(dog.size.width, 1176.0, reason: 'growth clamps at 1176');
      for (var i = 0; i < 30; i++) {
        dataSource.resizeDeskObject(kDachshundDeskId, 1 / 1.15);
      }
      expect(dog.size.width, 112.0, reason: 'shrink clamps at 112');
    });

    test('legacy amethyst prefs restore when no desk_objects row exists yet', () async {
      SharedPreferences.setMockInitialValues({
        'spatial_amethyst_x': 321.0,
        'spatial_amethyst_y': 123.0,
        'spatial_amethyst_width': 200.0,
      });
      final dataSource = await buildDataSource();
      final stone = _stone(dataSource);
      expect(stone.position, const Offset(321.0, 123.0));
      expect(stone.size.width, 200.0);
    });

    test('a desk_objects row wins over stale legacy prefs', () async {
      // First run writes a row...
      final first = await buildDataSource();
      first.onEntityMoved(kAmethystDeskId, const Offset(50.0, 60.0), 0);
      await pumpEventQueue();

      // ...so even if the old prefs keys linger with different values, the
      // row speaks for the stone.
      SharedPreferences.setMockInitialValues({
        'spatial_amethyst_x': 999.0,
        'spatial_amethyst_y': 999.0,
      });
      final reopened = await buildDataSource();
      expect(_stone(reopened).position, const Offset(50.0, 60.0));
    });

    test('placing without a view center uses the retained/default spot', () async {
      final dataSource = await buildDataSource();
      dataSource.placeDeskObject(kDachshundDeskId);
      // Default stagger spot right of the stone — NOT a view-center drop.
      expect(
        _dog(dataSource).position,
        Offset((2000 - kDachshundDefaultSize.width) / 2 + 260, (1500 - kDachshundDefaultSize.height) / 2),
      );
    });

    test('crystal variants start in the drawer, place independently, and survive reopen', () async {
      final dataSource = await buildDataSource();

      expect(TaskSpatialDataSource.deskObjectIds, [
        kAmethystDeskId,
        kCitrineDeskId,
        kRoseQuartzDeskId,
        kFluoriteDeskId,
        kObsidianDeskId,
        kDachshundDeskId,
      ]);
      for (final id in const [kCitrineDeskId, kRoseQuartzDeskId, kFluoriteDeskId]) {
        expect(dataSource.isDeskObjectPlaced(id), isFalse, reason: '$id starts in the drawer');
      }

      dataSource.placeDeskObject(kCitrineDeskId, viewCenter: const Offset(500, 400));
      final stones =
          dataSource.getVisibleEntities(Rect.zero).whereType<GemDeskEntity>().toList();
      expect(stones, hasLength(2));
      expect(stones.map((s) => s.id), containsAll([kAmethystDeskId, kCitrineDeskId]));

      // Each id renders its own modeled habit variant (separate meshes)...
      final citrine = stones.singleWhere((s) => s.id == kCitrineDeskId);
      expect(citrine.variant, GemVariant.citrine);
      // ...and every desk object keeps a unique paint order.
      final zIndexes = [
        for (final id in TaskSpatialDataSource.deskObjectIds)
          dataSource.getVisibleEntities(Rect.zero).where((e) => e.id == id),
      ].expand((e) => e).map((e) => e.zIndex).toList();
      expect(zIndexes.toSet().length, zIndexes.length);
      await pumpEventQueue();

      final reopened = await buildDataSource();
      expect(reopened.isDeskObjectPlaced(kCitrineDeskId), isTrue);
      expect(reopened.isDeskObjectPlaced(kRoseQuartzDeskId), isFalse);
    });

    test('the dachshund sits above the stone, both above every card', () async {
      await taskService.createTask('A card');
      final dataSource = await buildDataSource();
      dataSource.placeDeskObject(kDachshundDeskId, viewCenter: const Offset(500, 400));

      final dog = _dog(dataSource);
      final stone = _stone(dataSource);
      expect(dog.zIndex, greaterThan(stone.zIndex));
      for (final card in _cards(dataSource)) {
        expect(stone.zIndex, greaterThan(card.zIndex));
      }
    });
  });

  group('TaskSpatialDataSource — done-pile fan (owner request 2026-08-04)', () {
    Future<TaskSpatialDataSource> withCompleted(int count) async {
      for (var i = 0; i < count; i++) {
        final t = await taskService.createTask('Done $i');
        await taskService.toggleTaskCompletion(t);
      }
      return buildDataSource();
    }

    List<TaskSpatialEntity> pile(TaskSpatialDataSource ds) => ds
        .getVisibleEntities(Rect.zero)
        .whereType<TaskSpatialEntity>()
        .where((e) => e.task.completed)
        .toList();

    test('a felt tap inside the done-pile zone fans the pile down the right edge', () async {
      final dataSource = await withCompleted(4);
      expect(dataSource.donePileFanned, isFalse);

      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      expect(dataSource.donePileFanned, isTrue);

      final cards = pile(dataSource);
      // All at the same x, spread vertically, no two overlapping fully.
      final xs = cards.map((c) => c.position.dx).toSet();
      expect(xs, hasLength(1));
      final ys = cards.map((c) => c.position.dy).toList()..sort();
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i] - ys[i - 1], greaterThan(0));
      }
      // Newest completion (highest zIndex in the pile) takes the top slot.
      final newest = cards.reduce((a, b) => a.zIndex >= b.zIndex ? a : b);
      expect(newest.position.dy, ys.first);

      // Tapping the zone again restacks at the anchor fan.
      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      expect(dataSource.donePileFanned, isFalse);
      final restacked = pile(dataSource);
      for (var i = 0; i < restacked.length; i++) {
        // Order within _recentCompleted isn't exposed; just verify all are
        // back within the compact zone.
        expect(donePileZoneRect(_kCanvasSize).inflate(120).contains(restacked[i].position), isTrue);
      }
    });

    test('felt taps elsewhere never FAN, and an empty pile never toggles', () async {
      final dataSource = await withCompleted(0);
      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      expect(dataSource.donePileFanned, isFalse);

      final withCards = await withCompleted(2);
      withCards.onCanvasTapped(const Offset(10, 10));
      expect(withCards.donePileFanned, isFalse);
    });

    test('any tap OFF the fanned cards collapses; tapping a fanned card does not', () async {
      final placed = await taskService.createTask('Live card');
      await taskService.updateTaskCanvasPosition(placed.id, 400.0, 400.0);
      final dataSource = await withCompleted(3);

      // Felt tap far from the pile → collapse.
      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      expect(dataSource.donePileFanned, isTrue);
      dataSource.onCanvasTapped(const Offset(10, 10));
      expect(dataSource.donePileFanned, isFalse);

      // Tap on some OTHER entity → collapse.
      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      expect(dataSource.donePileFanned, isTrue);
      dataSource.onEntityTapped(placed.id);
      expect(dataSource.donePileFanned, isFalse);

      // Tap on a fanned card itself → stays open (inspecting, not
      // dismissing).
      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      dataSource.onEntityTapped(pile(dataSource).first.id);
      expect(dataSource.donePileFanned, isTrue);
    });

    test('the fan stays clear of the landing tray corner', () async {
      final dataSource = await withCompleted(kRecentCompletedCount);
      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);

      final lowest = pile(dataSource).map((c) => c.position.dy).reduce(math.max);
      expect(
        lowest + kCardSize.height,
        lessThan(taskTrayAnchor(_kCanvasSize).dy),
        reason: 'fanned cards must not run into the inbox stack (owner screenshot)',
      );
    });

    test(
      'a pile that would overlap on-desk falls back to the compact stack and flags overflow '
      '(owner decision 2026-08-06, phone APK)',
      () async {
        // Mirrors the app's real desk-panel canvas (CanvasScreen's
        // kCanvasScreenSize) rather than this file's generous _kCanvasSize
        // fixture above -- naive `availableHeight / (n - 1)` spacing at
        // THAT size, with a full pile, squeezes to ~123px against a 140px
        // card height (see _positionDonePile's doc comment for the exact
        // numbers), which this file's own larger fixture never exercises.
        // An earlier fix wrapped the overflow into a second on-desk fan
        // column; the owner's call (2026-08-06) was simpler: no fan on the
        // desk at all in that case -- CanvasScreen shows a scrollable tray
        // instead (see [TaskSpatialDataSource.donePileOverflowsFan]) and
        // the desk itself just keeps the pile's neat compact stack.
        const crampedCanvas = Size(1823, 1323);
        for (var i = 0; i < kRecentCompletedCount; i++) {
          final t = await taskService.createTask('Done $i');
          await taskService.toggleTaskCompletion(t);
        }
        final tasks = await taskService.getAllTasks();
        final dataSource =
            TaskSpatialDataSource(tasks: tasks, taskService: taskService, canvasSize: crampedCanvas);
        await dataSource.initialized;
        expect(dataSource.donePileOverflowsFan, isFalse, reason: 'not fanned yet');

        dataSource.onCanvasTapped(donePileZoneRect(crampedCanvas).center);
        expect(dataSource.donePileFanned, isTrue);
        expect(dataSource.donePileOverflowsFan, isTrue);

        final cards = dataSource
            .getVisibleEntities(Rect.zero)
            .whereType<TaskSpatialEntity>()
            .where((e) => e.task.completed)
            .toList();
        expect(cards, hasLength(kRecentCompletedCount));
        // The desk stays at the compact anchor stack -- the same small
        // per-card offset as the unfanned resting state -- never an
        // overlapping or multi-column on-desk fan.
        for (final c in cards) {
          expect(
            donePileZoneRect(crampedCanvas).inflate(120).contains(c.position),
            isTrue,
            reason: 'overflowing pile must stay in its compact stack, not spill an on-desk fan',
          );
        }

        // Closing (restacking) the pile drops the overflow flag too.
        dataSource.onCanvasTapped(donePileZoneRect(crampedCanvas).center);
        expect(dataSource.donePileFanned, isFalse);
        expect(dataSource.donePileOverflowsFan, isFalse);
      },
    );

    test('recentCompletedNewestFirst lists the pile newest-first, for the overflow tray', () async {
      final dataSource = await withCompleted(3);
      final stackIds = pile(dataSource).map((c) => c.id).toSet();
      final newestFirst = dataSource.recentCompletedNewestFirst;

      expect(newestFirst.map((e) => e.id).toSet(), stackIds);
      // zIndex is assigned ascending oldest -> newest at construction, so
      // the first (newest) entry must outrank the last (oldest) one.
      expect(newestFirst.first.zIndex, greaterThan(newestFirst.last.zIndex));
    });

    test('dragging a fanned pile card snaps back to its fanned slot', () async {
      final dataSource = await withCompleted(3);
      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      final before = {for (final c in pile(dataSource)) c.id: c.position};

      final victim = pile(dataSource).first;
      dataSource.onEntityMoved(victim.id, const Offset(100, 100), 0);

      final after = {for (final c in pile(dataSource)) c.id: c.position};
      expect(after, before, reason: 'read-only pile re-lays out in its CURRENT mode');
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

    test(
      'a card placed via drag-end survives reopen even from a STALE Task snapshot '
      '(owner report 2026-08-05, phone APK: cards lost position on Spatial View -> '
      'task list -> Spatial View, while desk objects survived)',
      () async {
        // CanvasScreen builds TaskSpatialDataSource from `TaskProvider.tasks`
        // -- a cache nothing patches after onEntityMoved's fire-and-forget
        // persist. Reproduce that exactly: hold on to the pre-drag (unplaced,
        // canvasX/Y == null) Task snapshot and keep reusing THAT stale
        // object across "reopens" instead of ever re-querying the service
        // for a fresh one, same as a TaskProvider that never calls
        // loadTasks() again after the drag.
        final stale = await taskService.createTask('Dragged then reopened');
        expect(stale.canvasX, isNull);
        expect(stale.canvasY, isNull);

        final firstOpen = TaskSpatialDataSource(
          tasks: [stale],
          taskService: taskService,
          canvasSize: _kCanvasSize,
        );
        await firstOpen.initialized;
        expect(_cards(firstOpen).single.position, taskTrayAnchor(_kCanvasSize)); // starts in the tray

        firstOpen.onEntityMoved(stale.id, const Offset(650.0, 500.0), 0);
        await _waitForCanvasPosition(taskService, stale.id, const Offset(650.0, 500.0));
        firstOpen.dispose();

        // "Reopen" the Spatial View using the SAME stale, still-unplaced
        // Task object -- this is the bug repro: without a self-healing
        // restore, _layout buckets it right back into the tray because the
        // snapshot it's handed still shows canvasX/canvasY == null.
        final secondOpen = TaskSpatialDataSource(
          tasks: [stale],
          taskService: taskService,
          canvasSize: _kCanvasSize,
        );
        await secondOpen.initialized;

        final entity = _cards(secondOpen).single;
        expect(entity.position, const Offset(650.0, 500.0),
            reason: 'canvas position must be re-read from SQLite, not trusted from the stale snapshot');
      },
    );
  });

  group('TaskSpatialDataSource.completeTask (owner request 2026-08-06, complete-from-card)', () {
    test('moves a placed (on-desk) card into the done pile and persists the completion', () async {
      final task = await taskService.createTask('On-desk card');
      await taskService.updateTaskCanvasPosition(task.id, 600.0, 450.0);
      final dataSource = await buildDataSource();
      expect(dataSource.recentCompletedNewestFirst, isEmpty);

      await dataSource.completeTask(task.id);

      // Left _placed for the pile, at the pile's anchor.
      expect(_cards(dataSource).where((e) => e.id == task.id).single.position, completedStackAnchor(_kCanvasSize));
      expect(dataSource.recentCompletedNewestFirst.map((e) => e.id), [task.id]);

      // Persisted: completed, but canvas_x/canvas_y stand (toggleTaskCompletion
      // only ever writes the columns it owns -- same contract the layout
      // tests above already cover for the plain toggle path).
      final reloaded = (await taskService.getAllTasks()).firstWhere((t) => t.id == task.id);
      expect(reloaded.completed, isTrue);
      expect(reloaded.canvasX, 600.0);
      expect(reloaded.canvasY, 450.0);

      // Survives a fresh data-source build (reopening the Spatial View):
      // _layout buckets it straight into the pile from the persisted row.
      final reopened = await buildDataSource();
      expect(reopened.recentCompletedNewestFirst.map((e) => e.id), [task.id]);
    });

    test('moves an unplaced (tray) card into the done pile and re-stacks the remaining tray', () async {
      final oldest = await taskService.createTask('Oldest');
      final newest = await taskService.createTask('Newest');
      final dataSource = await buildDataSource();

      // Newest starts on top of the tray -- complete it.
      await dataSource.completeTask(newest.id);

      expect(dataSource.recentCompletedNewestFirst.map((e) => e.id), [newest.id]);
      // Oldest is now the tray's sole occupant, re-stacked at the tray's
      // one-card base position (not left wherever it sat under the
      // now-departed newest card).
      final trayEntities = _cards(dataSource).where((e) => e.id == oldest.id);
      expect(trayEntities.single.position, taskTrayAnchor(_kCanvasSize));

      final reloaded = (await taskService.getAllTasks()).firstWhere((t) => t.id == newest.id);
      expect(reloaded.completed, isTrue);
    });

    test('the newly-completed card lands on top of the pile (highest zIndex)', () async {
      // Pre-fill the pile via the plain toggle path (same setup as the
      // "most recent N, newest on top" layout test), then complete one
      // more LIVE task through completeTask and confirm it takes the top
      // slot, not just gets appended anywhere.
      for (var i = 0; i < 3; i++) {
        final t = await taskService.createTask('Done $i');
        await taskService.toggleTaskCompletion(t);
      }
      final freshest = await taskService.createTask('Freshest');
      final dataSource = await buildDataSource();

      await dataSource.completeTask(freshest.id);

      final entities = _cards(dataSource).where((e) => dataSource.recentCompletedNewestFirst.any((p) => p.id == e.id));
      final topZ = entities.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b);
      final freshestEntity = entities.singleWhere((e) => e.id == freshest.id);
      expect(freshestEntity.zIndex, topZ);
      expect(dataSource.recentCompletedNewestFirst.first.id, freshest.id);
    });

    test('evicts the oldest pile card past $kRecentCompletedCount, same cap as the initial layout', () async {
      // Fill the pile to the cap with deterministic completed_at ordering.
      String? oldestId;
      for (var i = 0; i < kRecentCompletedCount; i++) {
        final t = await taskService.createTask('Done $i');
        await taskService.toggleTaskCompletion(t);
        await testDb.update('tasks', {'completed_at': 1000 + i}, where: 'id = ?', whereArgs: [t.id]);
        oldestId ??= t.id; // i == 0: smallest completed_at, the pile's oldest member
      }
      final freshest = await taskService.createTask('Freshest');
      final dataSource = await buildDataSource();
      expect(dataSource.recentCompletedNewestFirst, hasLength(kRecentCompletedCount));
      expect(dataSource.recentCompletedNewestFirst.map((e) => e.id), contains(oldestId));

      await dataSource.completeTask(freshest.id);

      expect(dataSource.recentCompletedNewestFirst, hasLength(kRecentCompletedCount));
      final ids = dataSource.recentCompletedNewestFirst.map((e) => e.id).toSet();
      expect(ids, contains(freshest.id));
      expect(ids, isNot(contains(oldestId)), reason: 'the oldest pile member should have dropped off');
    });

    test('is a no-op for an id that is not a currently placed/tray task (unknown id, or already in the pile)', () async {
      final alreadyDone = await taskService.createTask('Already done');
      await taskService.toggleTaskCompletion(alreadyDone);
      final dataSource = await buildDataSource();
      final pileBefore = dataSource.recentCompletedNewestFirst.map((e) => e.id).toList();

      await dataSource.completeTask('not-a-real-id');
      await dataSource.completeTask(alreadyDone.id); // already in the pile, not placed/tray

      expect(dataSource.recentCompletedNewestFirst.map((e) => e.id).toList(), pileBefore);
    });

    test('notifies listeners once the completion lands', () async {
      final task = await taskService.createTask('Notifying card');
      final dataSource = await buildDataSource();
      var notifications = 0;
      dataSource.addListener(() => notifications++);

      await dataSource.completeTask(task.id);

      expect(notifications, greaterThan(0));
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

  group('TaskSpatialDataSource — tag-tap spotlight (owner idea 2026-08-06, tentative)', () {
    test('spotlighting a tag sets it, notifies, and starts null (never persisted)', () async {
      final dataSource = await buildDataSource();
      expect(dataSource.spotlitTag, isNull);

      var notifyCount = 0;
      dataSource.addListener(() => notifyCount++);

      dataSource.spotlightTag('work');
      expect(dataSource.spotlitTag, 'work');
      expect(notifyCount, 1);
    });

    test('tapping the same tag again clears the spotlight', () async {
      final dataSource = await buildDataSource();

      dataSource.spotlightTag('work');
      expect(dataSource.spotlitTag, 'work');

      dataSource.spotlightTag('work');
      expect(dataSource.spotlitTag, isNull);
    });

    test('tapping a different tag switches the spotlight straight to it', () async {
      final dataSource = await buildDataSource();

      dataSource.spotlightTag('work');
      expect(dataSource.spotlitTag, 'work');

      dataSource.spotlightTag('urgent');
      expect(dataSource.spotlitTag, 'urgent');
    });

    test('a felt tap clears an active spotlight', () async {
      final dataSource = await buildDataSource();
      dataSource.spotlightTag('work');
      expect(dataSource.spotlitTag, 'work');

      dataSource.onCanvasTapped(const Offset(10, 10));
      expect(dataSource.spotlitTag, isNull);
    });

    test('clearSpotlight is a no-op (no spurious notify) when nothing is spotlit', () async {
      final dataSource = await buildDataSource();
      var notifyCount = 0;
      dataSource.addListener(() => notifyCount++);

      dataSource.clearSpotlight();
      expect(dataSource.spotlitTag, isNull);
      expect(notifyCount, 0);
    });

    test('a felt tap still collapses the done pile fan even with no active spotlight', () async {
      final done = await taskService.createTask('Finished chore');
      await taskService.toggleTaskCompletion(done);
      final dataSource = await buildDataSource();

      dataSource.onCanvasTapped(donePileZoneRect(_kCanvasSize).center);
      expect(dataSource.donePileFanned, isTrue);

      dataSource.onCanvasTapped(const Offset(10, 10));
      expect(dataSource.donePileFanned, isFalse);
      expect(dataSource.spotlitTag, isNull);
    });
  });

  group('TaskSpatialDataSource — tag-tap spotlight paint-order raise (owner addendum 2026-08-06)', () {
    // Three placed cards, created in order so `low` < `mid` < `high` in
    // BOTH creation order and zIndex (new-task-top-insert: each later
    // createTask() gets a strictly more negative task.position, hence a
    // strictly higher zIndex = -position -- same fact the tray group's
    // "newest on top" tests above rely on).
    Future<(TaskSpatialDataSource, Map<String, TaskSpatialEntity>)> buildThreePlaced() async {
      final low = await taskService.createTask('Low zIndex');
      final mid = await taskService.createTask('Mid zIndex');
      final high = await taskService.createTask('High zIndex');
      for (final (i, t) in [low, mid, high].indexed) {
        await taskService.updateTaskCanvasPosition(t.id, 100.0 * i, 100.0 * i);
      }
      final dataSource = await buildDataSource();
      final byId = {for (final e in _cards(dataSource)) e.id: e};
      // Sanity check the fixture actually has the ordering the rest of
      // this group's tests assume, before spotlighting anything.
      expect(byId[low.id]!.zIndex, lessThan(byId[mid.id]!.zIndex));
      expect(byId[mid.id]!.zIndex, lessThan(byId[high.id]!.zIndex));
      return (dataSource, {'low': byId[low.id]!, 'mid': byId[mid.id]!, 'high': byId[high.id]!});
    }

    test('spotlighting with no reported matches leaves paint order untouched', () async {
      final (dataSource, cards) = await buildThreePlaced();
      final originalZ = {for (final e in cards.values) e.id: e.zIndex};

      dataSource.spotlightTag('work'); // no setSpotlightMatches call at all

      final after = {for (final e in _cards(dataSource)) e.id: e.zIndex};
      expect(after, originalZ);
    });

    test('raises matching placed cards as one group above their non-matching sibling, '
        'preserving the matches\' own relative order', () async {
      final (dataSource, cards) = await buildThreePlaced();
      final midOriginalZ = cards['mid']!.zIndex;

      // low and high match the spotlit tag; mid does not -- and low/high
      // are NOT adjacent in the original stack, so a naive "just move the
      // matches to the front of the list" implementation would not by
      // itself prove the order survives; the zIndex assertions below do.
      dataSource.spotlightTag('work');
      dataSource.setSpotlightMatches({cards['low']!.id, cards['high']!.id});

      final byId = {for (final e in _cards(dataSource)) e.id: e};

      // The untouched sibling keeps its exact original zIndex.
      final mid = byId[cards['mid']!.id]!;
      expect(mid.zIndex, midOriginalZ);

      // Both matches cleared mid's zIndex...
      final low = byId[cards['low']!.id]!;
      final high = byId[cards['high']!.id]!;
      expect(low.zIndex, greaterThan(mid.zIndex));
      expect(high.zIndex, greaterThan(mid.zIndex));

      // ...as a contiguous block starting one above it (group raise, not
      // "every match claims zIndex max")...
      expect(low.zIndex, mid.zIndex + 1);
      expect(high.zIndex, mid.zIndex + 2);

      // ...and their MUTUAL order survived the raise: low was below high
      // before, and stays below it after -- not reversed, not collapsed to
      // a shared value that would leave their order to an id tie-break.
      expect(low.zIndex, lessThan(high.zIndex));

      // Passthrough properties (id/position/rotation/size) are untouched
      // by the wrap.
      expect(low.position, cards['low']!.position);
      expect(low.rotation, cards['low']!.rotation);
      expect(low.size, cards['low']!.size);
    });

    test('clearing the spotlight (same-tag tap) restores the normal z-order exactly', () async {
      final (dataSource, cards) = await buildThreePlaced();
      final originalZ = {for (final e in cards.values) e.id: e.zIndex};

      dataSource.spotlightTag('work');
      dataSource.setSpotlightMatches({cards['low']!.id, cards['high']!.id});
      expect(_cards(dataSource).map((e) => e.zIndex).toSet(), isNot(originalZ.values.toSet()));

      dataSource.spotlightTag('work'); // same tag again = clear (owner spec)
      expect(dataSource.spotlitTag, isNull);

      final after = {for (final e in _cards(dataSource)) e.id: e.zIndex};
      expect(after, originalZ);
    });

    test('a felt tap (clearSpotlight) restores the normal z-order too', () async {
      final (dataSource, cards) = await buildThreePlaced();
      final originalZ = {for (final e in cards.values) e.id: e.zIndex};

      dataSource.spotlightTag('work');
      dataSource.setSpotlightMatches({cards['low']!.id});

      dataSource.onCanvasTapped(const Offset(10, 10)); // felt tap -> clearSpotlight
      expect(dataSource.spotlitTag, isNull);

      final after = {for (final e in _cards(dataSource)) e.id: e.zIndex};
      expect(after, originalZ);
    });

    test('switching to a different tag drops the stale match set until re-supplied', () async {
      final (dataSource, cards) = await buildThreePlaced();
      final originalZ = {for (final e in cards.values) e.id: e.zIndex};

      dataSource.spotlightTag('work');
      dataSource.setSpotlightMatches({cards['low']!.id});
      expect(_cards(dataSource).firstWhere((e) => e.id == cards['low']!.id).zIndex,
          greaterThan(cards['mid']!.zIndex));

      // Switch straight to a different tag -- no matter what "work" used
      // to match, nothing should still be raised for "urgent" until the
      // caller reports fresh matches for it.
      dataSource.spotlightTag('urgent');
      expect(dataSource.spotlitTag, 'urgent');

      final after = {for (final e in _cards(dataSource)) e.id: e.zIndex};
      expect(after, originalZ);
    });

    test('a stray setSpotlightMatches call while nothing is spotlit is inert', () async {
      final (dataSource, cards) = await buildThreePlaced();
      final originalZ = {for (final e in cards.values) e.id: e.zIndex};

      dataSource.setSpotlightMatches({cards['low']!.id}); // no active spotlight at all

      dataSource.spotlightTag('work'); // now spotlight -- but never re-called setSpotlightMatches
      final after = {for (final e in _cards(dataSource)) e.id: e.zIndex};
      expect(after, originalZ); // the stray call from before spotlighting didn't stick
    });

    test('if every placed card matches, there is nothing to raise above (no-op)', () async {
      final (dataSource, cards) = await buildThreePlaced();
      final originalZ = {for (final e in cards.values) e.id: e.zIndex};

      dataSource.spotlightTag('work');
      dataSource.setSpotlightMatches(cards.values.map((e) => e.id).toSet());

      final after = _cards(dataSource);
      expect({for (final e in after) e.id: e.zIndex}, originalZ);
      // Not just numerically the same -- the exact same (unwrapped) entity
      // instances, since there's no non-matching sibling to raise above.
      final originalById = {for (final e in cards.values) e.id: e};
      for (final e in after) {
        expect(identical(e, originalById[e.id]), isTrue);
      }
    });

    test('the raise is placed-only: tray and done-pile cards never get raised, '
        'even if their ids are (mistakenly) reported as matches', () async {
      final trayTask = await taskService.createTask('Still in the tray');
      final doneTask = await taskService.createTask('Finished chore');
      await taskService.toggleTaskCompletion(doneTask);
      final (dataSource, cards) = await buildThreePlaced();

      final trayBefore = _zIndexOf(dataSource, trayTask.id);
      final doneBefore = _zIndexOf(dataSource, doneTask.id);

      dataSource.spotlightTag('work');
      // Defensively report tray/done ids too, alongside a real placed match.
      dataSource.setSpotlightMatches({cards['low']!.id, trayTask.id, doneTask.id});

      expect(_zIndexOf(dataSource, trayTask.id), trayBefore);
      expect(_zIndexOf(dataSource, doneTask.id), doneBefore);
    });

    test('nothing is persisted: canvas positions and task ordering survive a raise+clear cycle',
        () async {
      final (dataSource, cards) = await buildThreePlaced();
      final positionsBefore = {
        for (final t in await taskService.getAllTasks()) t.id: (t.position, t.canvasX, t.canvasY),
      };

      dataSource.spotlightTag('work');
      dataSource.setSpotlightMatches({cards['low']!.id, cards['high']!.id});
      dataSource.clearSpotlight();

      final positionsAfter = {
        for (final t in await taskService.getAllTasks()) t.id: (t.position, t.canvasX, t.canvasY),
      };
      expect(positionsAfter, positionsBefore);

      // A fresh data source (simulating a re-open of the Spatial View) has
      // no memory of the raise or even the spotlight at all.
      final reopened = await buildDataSource();
      expect(reopened.spotlitTag, isNull);
      final reopenedZ = {for (final e in _cards(reopened)) e.id: e.zIndex};
      expect(reopenedZ, {for (final e in cards.values) e.id: e.zIndex});
    });
  });
}

int _zIndexOf(TaskSpatialDataSource dataSource, String id) => _cards(dataSource).firstWhere((e) => e.id == id).zIndex;

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
