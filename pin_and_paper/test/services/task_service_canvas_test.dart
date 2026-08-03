import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/sync_service.dart';
import '../helpers/test_database_helper.dart';

/// Phase 4.4-MVP: Unit tests for spatial canvas position persistence
/// Tests updateTaskCanvasPosition() — DB v13's canvas_x/canvas_y write path
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskService taskService;
  late Database testDb;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    taskService = TaskService();
  });

  tearDown(() async {
    // SyncService.instance is a singleton that caches sync_meta in-process;
    // reset it to disabled so tests in other files (or added later in this
    // file) aren't affected by the sync-enabled test below.
    try {
      await SyncService.instance.updateSyncMeta(syncEnabled: false);
    } catch (_) {
      // Ignore — best-effort cleanup only.
    }
  });

  group('TaskService - updateTaskCanvasPosition()', () {
    test('persists canvas_x/canvas_y for the task', () async {
      // Arrange
      final task = await taskService.createTask('Card on the desk');

      // Act
      await taskService.updateTaskCanvasPosition(task.id, 123.5, -45.25);

      // Assert - verify persistence via raw query (canvasX/Y not returned by this method)
      final rows = await testDb.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [task.id],
      );
      expect(rows.length, 1);
      expect(rows.first['canvas_x'], 123.5);
      expect(rows.first['canvas_y'], -45.25);
    });

    test('round-trips through Task.fromMap after persisting', () async {
      final task = await taskService.createTask('Round trip card');

      await taskService.updateTaskCanvasPosition(task.id, 200.0, 300.0);

      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);

      expect(found.canvasX, 200.0);
      expect(found.canvasY, 300.0);
    });

    test('overwrites a previously-stored position', () async {
      final task = await taskService.createTask('Repositioned card');

      await taskService.updateTaskCanvasPosition(task.id, 10.0, 10.0);
      await taskService.updateTaskCanvasPosition(task.id, 999.0, -999.0);

      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);

      expect(found.canvasX, 999.0);
      expect(found.canvasY, -999.0);
    });

    test('bumps updated_at (pre-existing LWW contention, accepted)', () async {
      final task = await taskService.createTask('LWW card');
      final before = task.updatedAt;

      // Ensure a measurable time delta
      await Future.delayed(const Duration(milliseconds: 5));
      await taskService.updateTaskCanvasPosition(task.id, 1.0, 2.0);

      final rows = await testDb.query('tasks', where: 'id = ?', whereArgs: [task.id]);
      final updatedAtMs = rows.first['updated_at'] as int;

      expect(updatedAtMs, greaterThan(before!.millisecondsSinceEpoch));
    });

    test('throws on non-existent task', () async {
      expect(
        () => taskService.updateTaskCanvasPosition('non-existent-uuid', 1.0, 2.0),
        throwsA(isA<Exception>()),
      );
    });

    test('does not affect other task fields', () async {
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');
      await taskService.updateTaskParent(child.id, parent.id, 0);

      await taskService.updateTaskCanvasPosition(child.id, 42.0, 84.0);

      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == child.id);

      expect(found.title, 'Child');
      expect(found.parentId, parent.id);
      expect(found.canvasX, 42.0);
      expect(found.canvasY, 84.0);
    });

    test('writes a sync_log row with the canvas payload', () async {
      // logChange() is a no-op when sync is disabled (the test DB's default
      // sync_meta state) — enable it so this test can observe the write.
      await SyncService.instance.updateSyncMeta(syncEnabled: true, userId: 'test-user');

      final task = await taskService.createTask('Synced card');

      await taskService.updateTaskCanvasPosition(task.id, 55.5, -22.5);

      final logs = await testDb.query(
        'sync_log',
        where: 'table_name = ? AND record_id = ? AND operation = ?',
        whereArgs: ['tasks', task.id, 'UPDATE'],
      );

      // There may be an earlier sync_log row from createTask's INSERT; find
      // the UPDATE entry carrying the canvas payload.
      final canvasLog = logs.firstWhere(
        (log) => (log['payload'] as String).contains('canvas_x'),
      );

      final payload = jsonDecode(canvasLog['payload'] as String) as Map<String, dynamic>;
      expect(payload['canvas_x'], 55.5);
      expect(payload['canvas_y'], -22.5);
      expect(payload.containsKey('updated_at'), true);
    });
  });
}
