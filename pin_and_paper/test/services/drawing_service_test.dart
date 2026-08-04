import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/models/task_drawing.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/drawing_service.dart';
import 'package:pin_and_paper/services/sync_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/utils/constants.dart';
import '../helpers/test_database_helper.dart';

/// Card drawings M-D4 (DB v14): unit tests for DrawingService — the
/// task_drawings persistence surface (save/get/visible/delete), the
/// one-row-per-(task_id, face) upsert rule, cascade delete via the real
/// task delete path, and sync silence (drawing ops never touch sync_log
/// or tasks.updated_at).
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskService taskService;
  late DrawingService drawingService;
  late Database testDb;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    taskService = TaskService();
    drawingService = DrawingService();
  });

  tearDown(() async {
    // SyncService.instance is a singleton that caches sync_meta in-process;
    // reset it to disabled so tests in other files aren't affected by the
    // sync-enabled tests below.
    try {
      await SyncService.instance.updateSyncMeta(syncEnabled: false);
    } catch (_) {
      // Ignore — best-effort cleanup only.
    }
  });

  group('DrawingService - save/get round-trip', () {
    test('saves and reads back a front-face drawing', () async {
      final task = await taskService.createTask('Doodled card');

      final saved = await drawingService.saveTaskDrawing(
          task.id, '{"v":1,"layers":[]}');

      expect(saved.taskId, task.id);
      expect(saved.face, TaskDrawing.faceFront);
      expect(saved.visible, isTrue);

      final loaded = await drawingService.getDrawingForTask(task.id);
      expect(loaded, isNotNull);
      expect(loaded!.id, saved.id);
      expect(loaded.drawingJson, '{"v":1,"layers":[]}');
      expect(loaded.face, TaskDrawing.faceFront);
      expect(loaded.visible, isTrue);
      expect(loaded.positionX, 0);
      expect(loaded.positionY, 0);
    });

    test('returns null for a task with no drawing', () async {
      final task = await taskService.createTask('Blank card');

      final loaded = await drawingService.getDrawingForTask(task.id);
      expect(loaded, isNull);
    });

    test('front and back faces store independent drawings', () async {
      final task = await taskService.createTask('Two-sided card');

      await drawingService.saveTaskDrawing(task.id, '{"v":1,"side":"front"}');
      await drawingService.saveTaskDrawing(task.id, '{"v":1,"side":"back"}',
          face: TaskDrawing.faceBack);

      final front = await drawingService.getDrawingForTask(task.id);
      final back = await drawingService.getDrawingForTask(task.id,
          face: TaskDrawing.faceBack);

      expect(front!.drawingJson, '{"v":1,"side":"front"}');
      expect(back!.drawingJson, '{"v":1,"side":"back"}');
      expect(front.id, isNot(equals(back.id)));

      // Deleting one face leaves the other untouched
      await drawingService.deleteTaskDrawing(task.id);
      expect(await drawingService.getDrawingForTask(task.id), isNull);
      final backStill = await drawingService.getDrawingForTask(task.id,
          face: TaskDrawing.faceBack);
      expect(backStill, isNotNull);
    });

    test('rejects a drawing for a nonexistent task (FK constraint)', () async {
      expect(
        () => drawingService.saveTaskDrawing('no-such-task', '{"v":1}'),
        throwsA(anything),
      );
    });
  });

  group('DrawingService - upsert semantics', () {
    test('re-saving replaces the drawing rather than duplicating', () async {
      final task = await taskService.createTask('Redrawn card');

      final first = await drawingService.saveTaskDrawing(task.id, '{"v":1,"n":1}');
      final second = await drawingService.saveTaskDrawing(task.id, '{"v":1,"n":2}');

      // Same row: id preserved, content replaced
      expect(second.id, first.id);

      final rows = await testDb.query(
        AppConstants.taskDrawingsTable,
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      expect(rows.length, 1);
      expect(rows.first['drawing_json'], '{"v":1,"n":2}');
    });

    test('upsert preserves visibility and created_at', () async {
      final task = await taskService.createTask('Hidden then redrawn');

      final first = await drawingService.saveTaskDrawing(task.id, '{"v":1,"n":1}');
      await drawingService.setTaskDrawingVisible(task.id, false);

      await drawingService.saveTaskDrawing(task.id, '{"v":1,"n":2}');

      final loaded = await drawingService.getDrawingForTask(task.id);
      expect(loaded!.visible, isFalse,
          reason: 'Upsert must not reset the show/hide toggle');
      // DB stores millisecondsSinceEpoch — compare at ms precision
      expect(loaded.createdAt.millisecondsSinceEpoch,
          first.createdAt.millisecondsSinceEpoch);
    });

    test('at most one row per (task_id, face) across many saves', () async {
      final task = await taskService.createTask('Compulsive doodler');

      for (var i = 0; i < 5; i++) {
        await drawingService.saveTaskDrawing(task.id, '{"v":1,"n":$i}');
        await drawingService.saveTaskDrawing(task.id, '{"v":1,"b":$i}',
            face: TaskDrawing.faceBack);
      }

      final rows = await testDb.query(
        AppConstants.taskDrawingsTable,
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      expect(rows.length, 2); // one front + one back
    });
  });

  group('DrawingService - visibility toggle', () {
    test('toggle persists and round-trips', () async {
      final task = await taskService.createTask('Peekaboo card');
      await drawingService.saveTaskDrawing(task.id, '{"v":1}');

      await drawingService.setTaskDrawingVisible(task.id, false);
      var loaded = await drawingService.getDrawingForTask(task.id);
      expect(loaded!.visible, isFalse);

      await drawingService.setTaskDrawingVisible(task.id, true);
      loaded = await drawingService.getDrawingForTask(task.id);
      expect(loaded!.visible, isTrue);
    });

    test('throws when the task face has no drawing', () async {
      final task = await taskService.createTask('Never drawn on');

      expect(
        () => drawingService.setTaskDrawingVisible(task.id, false),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DrawingService - delete', () {
    test('deleteTaskDrawing removes the row', () async {
      final task = await taskService.createTask('Erased card');
      await drawingService.saveTaskDrawing(task.id, '{"v":1}');

      await drawingService.deleteTaskDrawing(task.id);

      expect(await drawingService.getDrawingForTask(task.id), isNull);
      final rows = await testDb.query(
        AppConstants.taskDrawingsTable,
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      expect(rows, isEmpty);
    });

    test('deleteTaskDrawing is a no-op when no drawing exists', () async {
      final task = await taskService.createTask('Nothing to erase');

      // Must not throw
      await drawingService.deleteTaskDrawing(task.id);
    });

    test('deleting a task via the real delete path cascades to drawings', () async {
      final parent = await taskService.createTask('Parent with ink');
      final child = await taskService.createTask('Child with ink');
      await taskService.updateTaskParent(child.id, parent.id, 0);

      await drawingService.saveTaskDrawing(parent.id, '{"v":1,"who":"parent"}');
      await drawingService.saveTaskDrawing(parent.id, '{"v":1,"back":true}',
          face: TaskDrawing.faceBack);
      await drawingService.saveTaskDrawing(child.id, '{"v":1,"who":"child"}');

      await taskService.deleteTaskWithChildren(parent.id);

      final rows = await testDb.query(AppConstants.taskDrawingsTable);
      expect(rows, isEmpty,
          reason: 'ON DELETE CASCADE must remove all drawing rows for the '
              'deleted task and its descendants');
    });
  });

  group('DrawingService - sync silence', () {
    test('drawing operations write NO sync_log rows and never bump tasks.updated_at', () async {
      // logChange() is a no-op when sync is disabled (the test DB's default
      // sync_meta state) — enable it so an accidental logChange call WOULD
      // be observable in sync_log.
      await SyncService.instance
          .updateSyncMeta(syncEnabled: true, userId: 'test-user');

      final task = await taskService.createTask('Quiet card');

      final logCountBefore = (await testDb.query('sync_log')).length;
      final taskRowBefore = (await testDb
              .query('tasks', where: 'id = ?', whereArgs: [task.id]))
          .first;

      // The full drawing write surface
      await drawingService.saveTaskDrawing(task.id, '{"v":1,"n":1}');
      await drawingService.saveTaskDrawing(task.id, '{"v":1,"n":2}'); // upsert
      await drawingService.saveTaskDrawing(task.id, '{"v":1}',
          face: TaskDrawing.faceBack);
      await drawingService.setTaskDrawingVisible(task.id, false);
      await drawingService.deleteTaskDrawing(task.id,
          face: TaskDrawing.faceBack);

      // No sync_log rows at all — not for task_drawings, not for tasks
      final logCountAfter = (await testDb.query('sync_log')).length;
      expect(logCountAfter, logCountBefore,
          reason: 'Drawing ops must not call SyncService.logChange — the '
              'push path would mark task_drawings entries synced-and-dropped, '
              'silently losing them for a future retro-push');

      final drawingLogs = await testDb.query(
        'sync_log',
        where: 'table_name = ?',
        whereArgs: [AppConstants.taskDrawingsTable],
      );
      expect(drawingLogs, isEmpty);

      // tasks row untouched — updated_at must not move (task LWW stays
      // untouched by ink; that's why task_drawings is a separate table)
      final taskRowAfter = (await testDb
              .query('tasks', where: 'id = ?', whereArgs: [task.id]))
          .first;
      expect(taskRowAfter['updated_at'], taskRowBefore['updated_at']);
      expect(taskRowAfter, equals(taskRowBefore));
    });
  });
}
