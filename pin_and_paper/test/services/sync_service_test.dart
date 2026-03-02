import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/sync_service.dart';
import 'package:pin_and_paper/utils/constants.dart';
import '../helpers/test_database_helper.dart';

/// Tests for the sync layer's local logic: sync_log recording, push ordering,
/// merge behavior, and task_tags union-merge. These tests use real SQLite
/// (in-memory) but do NOT hit Supabase — network calls are tested separately.
void main() {
  group('SyncService', () {
    setUpAll(() {
      TestDatabaseHelper.initialize();
    });

    late Database testDb;
    late SyncService syncService;

    setUp(() async {
      testDb = await TestDatabaseHelper.createTestDatabase();
      DatabaseService.setTestDatabase(testDb);
      await TestDatabaseHelper.clearAllData(testDb);

      syncService = SyncService.testInstance(testDb);
    });

    // ═══════════════════════════════════════
    // SYNC META
    // ═══════════════════════════════════════

    group('SyncMeta', () {
      test('starts with sync disabled', () async {
        final meta = await syncService.getSyncMeta();
        expect(meta.syncEnabled, false, reason: 'Sync should be disabled by default');
        expect(meta.userId, isNull);
        expect(meta.lastPushAt, isNull);
        expect(meta.lastPullAt, isNull);
      });

      test('updateSyncMeta persists changes', () async {
        await syncService.updateSyncMeta(
          syncEnabled: true,
          userId: 'user-123',
        );

        final meta = await syncService.getSyncMeta();
        expect(meta.syncEnabled, true);
        expect(meta.userId, 'user-123');
      });

      test('updateSyncMeta clears userId when set to empty string', () async {
        await syncService.updateSyncMeta(userId: 'user-123', syncEnabled: true);
        await syncService.updateSyncMeta(syncEnabled: false);

        final meta = await syncService.getSyncMeta();
        expect(meta.syncEnabled, false);
        // userId should still be 'user-123' since we only changed syncEnabled
        expect(meta.userId, 'user-123');
      });
    });

    // ═══════════════════════════════════════
    // CHANGE LOGGING
    // ═══════════════════════════════════════

    group('logChange', () {
      test('does nothing when sync is disabled', () async {
        await syncService.logChange(
          tableName: 'tasks',
          recordId: 'task-1',
          operation: 'INSERT',
          payload: {'title': 'Test'},
        );

        final logs = await testDb.query('sync_log');
        expect(logs.isEmpty, true, reason: 'Should not log when sync disabled');
      });

      test('logs change when sync is enabled', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');

        await syncService.logChange(
          tableName: 'tasks',
          recordId: 'task-1',
          operation: 'INSERT',
          payload: {'title': 'Test'},
        );

        final logs = await testDb.query('sync_log');
        expect(logs.length, 1);
        expect(logs.first['table_name'], 'tasks');
        expect(logs.first['record_id'], 'task-1');
        expect(logs.first['operation'], 'INSERT');
        expect(logs.first['synced'], 0);
      });

      test('stores payload as JSON', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');

        final payload = {'title': 'My Task', 'completed': 0};
        await syncService.logChange(
          tableName: 'tasks',
          recordId: 'task-1',
          operation: 'INSERT',
          payload: payload,
        );

        final logs = await testDb.query('sync_log');
        final storedPayload = jsonDecode(logs.first['payload'] as String);
        expect(storedPayload['title'], 'My Task');
        expect(storedPayload['completed'], 0);
      });

      test('DELETE operations can have null payload', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');

        await syncService.logChange(
          tableName: 'tasks',
          recordId: 'task-1',
          operation: 'DELETE',
        );

        final logs = await testDb.query('sync_log');
        expect(logs.first['payload'], isNull);
      });
    });

    // ═══════════════════════════════════════
    // PENDING CHANGES
    // ═══════════════════════════════════════

    group('getPendingChanges', () {
      test('returns pending entries in chronological order', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');

        await syncService.logChange(
          tableName: 'tags', recordId: 'tag-1',
          operation: 'INSERT', payload: {'name': 'Work'},
        );
        // Small delay so created_at differs
        await Future.delayed(const Duration(milliseconds: 5));
        await syncService.logChange(
          tableName: 'task_tags', recordId: 'task-1_tag-1',
          operation: 'INSERT', payload: {'task_id': 'task-1', 'tag_id': 'tag-1'},
        );

        final pending = await syncService.getPendingChanges();
        expect(pending.length, 2);
        expect(pending[0]['table_name'], 'tags',
            reason: 'Tag INSERT must come before task_tags INSERT (FK order)');
        expect(pending[1]['table_name'], 'task_tags');
      });

      test('does not return already-synced entries', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');

        await syncService.logChange(
          tableName: 'tasks', recordId: 'task-1',
          operation: 'INSERT', payload: {'title': 'Test'},
        );

        // Mark as synced
        await testDb.rawUpdate('UPDATE sync_log SET synced = 1');

        final pending = await syncService.getPendingChanges();
        expect(pending.isEmpty, true);
      });
    });

    // ═══════════════════════════════════════
    // MARK SYNCED
    // ═══════════════════════════════════════

    group('markSynced', () {
      test('marks specific entries as synced', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');

        await syncService.logChange(
          tableName: 'tasks', recordId: 'task-1',
          operation: 'INSERT', payload: {'title': 'Task 1'},
        );
        await syncService.logChange(
          tableName: 'tasks', recordId: 'task-2',
          operation: 'INSERT', payload: {'title': 'Task 2'},
        );

        final pending = await syncService.getPendingChanges();
        await syncService.markSynced([pending.first['id'] as int]);

        final remaining = await syncService.getPendingChanges();
        expect(remaining.length, 1);
        expect(remaining.first['record_id'], 'task-2');
      });
    });

    // ═══════════════════════════════════════
    // TYPE CONVERSIONS
    // ═══════════════════════════════════════

    group('type conversions', () {
      test('localTaskToRemote excludes depth', () {
        final localTask = {
          'id': 'task-1',
          'title': 'Test',
          'completed': 0,
          'created_at': 1700000000000,
          'completed_at': null,
          'updated_at': 1700000000000,
          'parent_id': null,
          'position': 0,
          'is_template': 0,
          'due_date': null,
          'is_all_day': 1,
          'start_date': null,
          'notification_type': 'use_global',
          'notification_time': null,
          'deleted_at': null,
          'notes': null,
          'position_before_completion': null,
        };

        final remote = syncService.localTaskToRemote(localTask, 'user-1');

        expect(remote.containsKey('depth'), false,
            reason: 'depth is not persisted locally, must not appear in remote payload');
        expect(remote['user_id'], 'user-1');
        expect(remote['completed'], false);
        expect(remote['is_template'], false);
        expect(remote['is_all_day'], true);
      });

      test('remoteTaskToLocal excludes depth', () {
        final remoteTask = {
          'id': 'task-1',
          'title': 'Test',
          'completed': true,
          'created_at': '2023-11-14T22:13:20.000Z',
          'completed_at': '2023-11-14T22:13:20.000Z',
          'updated_at': '2023-11-14T22:13:20.000Z',
          'parent_id': null,
          'position': 0,
          'is_template': false,
          'due_date': null,
          'is_all_day': true,
          'start_date': null,
          'notification_type': 'use_global',
          'notification_time': null,
          'deleted_at': null,
          'notes': null,
          'position_before_completion': null,
        };

        final local = syncService.remoteTaskToLocal(remoteTask);

        expect(local.containsKey('depth'), false,
            reason: 'depth must not be written to local DB');
        expect(local['completed'], 1);
        expect(local['is_template'], 0);
        expect(local['is_all_day'], 1);
      });

      test('localTaskTagToRemote strips created_at as epoch, adds user_id', () {
        final localTT = {
          'task_id': 'task-1',
          'tag_id': 'tag-1',
          'created_at': 1700000000000,
        };

        final remote = syncService.localTaskTagToRemote(localTT, 'user-1');

        expect(remote['user_id'], 'user-1');
        expect(remote['task_id'], 'task-1');
        expect(remote['tag_id'], 'tag-1');
        expect(remote['created_at'], isA<String>(),
            reason: 'created_at must be ISO string for Supabase');
      });

      test('epoch/ISO round-trip preserves timestamps', () {
        final epoch = 1700000000000;
        final iso = syncService.epochToIso(epoch);
        final backToEpoch = syncService.isoToEpoch(iso!);

        expect(backToEpoch, epoch);
      });

      test('null epoch returns null ISO', () {
        expect(syncService.epochToIso(null), isNull);
      });

      test('null ISO returns null epoch', () {
        expect(syncService.isoToEpoch(null), isNull);
      });
    });

    // ═══════════════════════════════════════
    // MERGE LOGIC (LWW)
    // ═══════════════════════════════════════

    group('mergeTask', () {
      test('inserts new remote task that does not exist locally', () async {
        final remoteTask = _makeRemoteTask('task-1', 'Remote Task',
            updatedAt: DateTime(2024, 1, 1, 12, 0));

        await syncService.mergeTask(testDb, remoteTask);

        final local = await testDb.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: ['task-1']);
        expect(local.length, 1);
        expect(local.first['title'], 'Remote Task');
      });

      test('remote wins when remote updated_at > local updated_at', () async {
        // Insert local task at T1
        final t1 = DateTime(2024, 1, 1, 10, 0).millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tasksTable, {
          'id': 'task-1', 'title': 'Local Title', 'completed': 0,
          'created_at': t1, 'updated_at': t1, 'position': 0,
          'is_template': 0, 'is_all_day': 1,
        });

        // Merge remote at T2 (later)
        final remoteTask = _makeRemoteTask('task-1', 'Remote Title',
            updatedAt: DateTime(2024, 1, 1, 12, 0));
        await syncService.mergeTask(testDb, remoteTask);

        final local = await testDb.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: ['task-1']);
        expect(local.first['title'], 'Remote Title',
            reason: 'Remote should win when it has newer updated_at');
      });

      test('local wins when local updated_at > remote updated_at', () async {
        // Insert local task at T2 (later)
        final t2 = DateTime(2024, 1, 1, 14, 0).millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tasksTable, {
          'id': 'task-1', 'title': 'Local Title', 'completed': 0,
          'created_at': t2, 'updated_at': t2, 'position': 0,
          'is_template': 0, 'is_all_day': 1,
        });

        // Merge remote at T1 (earlier)
        final remoteTask = _makeRemoteTask('task-1', 'Remote Title',
            updatedAt: DateTime(2024, 1, 1, 10, 0));
        await syncService.mergeTask(testDb, remoteTask);

        final local = await testDb.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: ['task-1']);
        expect(local.first['title'], 'Local Title',
            reason: 'Local should win when it has newer updated_at');
      });

      test('remote wins on equal timestamps (tie-break)', () async {
        final t = DateTime(2024, 1, 1, 12, 0).millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tasksTable, {
          'id': 'task-1', 'title': 'Local Title', 'completed': 0,
          'created_at': t, 'updated_at': t, 'position': 0,
          'is_template': 0, 'is_all_day': 1,
        });

        final remoteTask = _makeRemoteTask('task-1', 'Remote Title',
            updatedAt: DateTime(2024, 1, 1, 12, 0));
        await syncService.mergeTask(testDb, remoteTask);

        final local = await testDb.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: ['task-1']);
        expect(local.first['title'], 'Remote Title',
            reason: 'Remote should win on equal timestamps (prefer MCP/additive edits)');
      });
    });

    group('mergeTag', () {
      test('inserts new remote tag that does not exist locally', () async {
        final remoteTag = _makeRemoteTag('tag-1', 'Work',
            updatedAt: DateTime(2024, 1, 1, 12, 0));

        await syncService.mergeTag(testDb, remoteTag);

        final local = await testDb.query(AppConstants.tagsTable, where: 'id = ?', whereArgs: ['tag-1']);
        expect(local.length, 1);
        expect(local.first['name'], 'Work');
      });

      test('LWW applies correctly to tags', () async {
        final t1 = DateTime(2024, 1, 1, 10, 0).millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'tag-1', 'name': 'Local Tag',
          'created_at': t1, 'updated_at': t1,
        });

        final remoteTag = _makeRemoteTag('tag-1', 'Remote Tag',
            updatedAt: DateTime(2024, 1, 1, 12, 0));
        await syncService.mergeTag(testDb, remoteTag);

        final local = await testDb.query(AppConstants.tagsTable, where: 'id = ?', whereArgs: ['tag-1']);
        expect(local.first['name'], 'Remote Tag');
      });

      test('preserves local color when remote color is null', () async {
        final t1 = DateTime(2024, 1, 1, 10, 0).millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'tag-1', 'name': 'My Tag', 'color': '#FF5722',
          'created_at': t1, 'updated_at': t1,
        });

        // Remote wins LWW (newer) but has null color (MCP-created)
        final remoteTag = _makeRemoteTag('tag-1', 'My Tag',
            updatedAt: DateTime(2024, 1, 1, 12, 0));
        await syncService.mergeTag(testDb, remoteTag);

        final local = await testDb.query(AppConstants.tagsTable,
            where: 'id = ?', whereArgs: ['tag-1']);
        expect(local.first['color'], '#FF5722',
            reason: 'Local color should be preserved when remote color is null');
      });

      test('overwrites local color when remote has explicit color', () async {
        final t1 = DateTime(2024, 1, 1, 10, 0).millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'tag-1', 'name': 'My Tag', 'color': '#FF5722',
          'created_at': t1, 'updated_at': t1,
        });

        // Remote wins LWW (newer) AND has an explicit color
        final remoteTag = _makeRemoteTag('tag-1', 'My Tag',
            updatedAt: DateTime(2024, 1, 1, 12, 0), color: '#4CAF50');
        await syncService.mergeTag(testDb, remoteTag);

        final local = await testDb.query(AppConstants.tagsTable,
            where: 'id = ?', whereArgs: ['tag-1']);
        expect(local.first['color'], '#4CAF50',
            reason: 'Remote color should overwrite when it has an explicit value');
      });

      test('preserves local color during name-collision unification when remote color is null', () async {
        final t1 = DateTime(2024, 1, 1, 10, 0).millisecondsSinceEpoch;
        // Local tag with color
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'local-tag-id', 'name': 'Work', 'color': '#E91E63',
          'created_at': t1, 'updated_at': t1,
        });

        // Remote tag with same name but different ID and null color
        final remoteTag = _makeRemoteTag('remote-tag-id', 'Work',
            updatedAt: DateTime(2024, 1, 1, 12, 0));
        await syncService.mergeTag(testDb, remoteTag);

        // Should have unified to the remote ID
        final local = await testDb.query(AppConstants.tagsTable,
            where: 'id = ?', whereArgs: ['remote-tag-id']);
        expect(local.length, 1);
        expect(local.first['name'], 'Work');
        expect(local.first['color'], '#E91E63',
            reason: 'Local color should be preserved during name-collision unification');

        // Old local ID should be gone
        final oldLocal = await testDb.query(AppConstants.tagsTable,
            where: 'id = ?', whereArgs: ['local-tag-id']);
        expect(oldLocal, isEmpty);
      });
    });

    // ═══════════════════════════════════════
    // TASK_TAGS UNION MERGE
    // ═══════════════════════════════════════

    group('pullTaskTags (union merge)', () {
      setUp(() async {
        // Insert prerequisite tasks and tags
        final now = DateTime.now().millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tasksTable, {
          'id': 'task-1', 'title': 'Task 1', 'completed': 0,
          'created_at': now, 'updated_at': now, 'position': 0,
          'is_template': 0, 'is_all_day': 1,
        });
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'tag-a', 'name': 'Tag A', 'created_at': now, 'updated_at': now,
        });
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'tag-b', 'name': 'Tag B', 'created_at': now, 'updated_at': now,
        });
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'tag-c', 'name': 'Tag C', 'created_at': now, 'updated_at': now,
        });
      });

      test('adds remote-only rows without deleting local-only rows', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Local has tag-a
        await testDb.insert(AppConstants.taskTagsTable, {
          'task_id': 'task-1', 'tag_id': 'tag-a', 'created_at': now,
        });

        // Remote has tag-a and tag-b
        final remoteTaskTags = [
          {'task_id': 'task-1', 'tag_id': 'tag-a'},
          {'task_id': 'task-1', 'tag_id': 'tag-b'},
        ];

        await syncService.pullTaskTags(testDb, remoteTaskTags, hasPendingOps: false);

        final local = await testDb.query(AppConstants.taskTagsTable,
            where: 'task_id = ?', whereArgs: ['task-1']);
        final tagIds = local.map((r) => r['tag_id']).toSet();
        expect(tagIds, containsAll(['tag-a', 'tag-b']),
            reason: 'Should have both local and remote tags');
      });

      test('removes local rows that were deleted remotely', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Local has tag-a and tag-b
        await testDb.insert(AppConstants.taskTagsTable, {
          'task_id': 'task-1', 'tag_id': 'tag-a', 'created_at': now,
        });
        await testDb.insert(AppConstants.taskTagsTable, {
          'task_id': 'task-1', 'tag_id': 'tag-b', 'created_at': now,
        });

        // Remote only has tag-a (tag-b was removed remotely)
        final remoteTaskTags = [
          {'task_id': 'task-1', 'tag_id': 'tag-a'},
        ];

        await syncService.pullTaskTags(testDb, remoteTaskTags, hasPendingOps: false);

        final local = await testDb.query(AppConstants.taskTagsTable,
            where: 'task_id = ?', whereArgs: ['task-1']);
        expect(local.length, 1);
        expect(local.first['tag_id'], 'tag-a');
      });

      test('skips merge when there are pending local ops', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');
        final now = DateTime.now().millisecondsSinceEpoch;

        // Local has tag-a
        await testDb.insert(AppConstants.taskTagsTable, {
          'task_id': 'task-1', 'tag_id': 'tag-a', 'created_at': now,
        });

        // Log a pending task_tags op
        await syncService.logChange(
          tableName: 'task_tags', recordId: 'task-1_tag-c',
          operation: 'INSERT',
          payload: {'task_id': 'task-1', 'tag_id': 'tag-c', 'created_at': now},
        );

        // Remote has only tag-b (would normally delete tag-a)
        final remoteTaskTags = [
          {'task_id': 'task-1', 'tag_id': 'tag-b'},
        ];

        await syncService.pullTaskTags(testDb, remoteTaskTags, hasPendingOps: true);

        // Local should be unchanged — merge was skipped
        final local = await testDb.query(AppConstants.taskTagsTable,
            where: 'task_id = ?', whereArgs: ['task-1']);
        expect(local.length, 1);
        expect(local.first['tag_id'], 'tag-a',
            reason: 'Should skip merge when pending local ops exist');
      });

      test('inserted rows include created_at (NOT NULL constraint)', () async {
        // Remote has tag-b which doesn't exist locally
        final remoteTaskTags = [
          {'task_id': 'task-1', 'tag_id': 'tag-b'},
        ];

        // This should NOT throw a NotNullConstraintViolation
        await syncService.pullTaskTags(testDb, remoteTaskTags, hasPendingOps: false);

        final local = await testDb.query(AppConstants.taskTagsTable,
            where: 'task_id = ?', whereArgs: ['task-1']);
        expect(local.length, 1);
        expect(local.first['created_at'], isNotNull,
            reason: 'Inserted task_tags rows must have created_at to satisfy NOT NULL');
      });
    });

    // ═══════════════════════════════════════
    // PUSH ENTRY PROCESSING
    // ═══════════════════════════════════════

    group('preparePushEntry', () {
      test('reads current local state for task UPDATE', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tasksTable, {
          'id': 'task-1', 'title': 'Current Title', 'completed': 0,
          'created_at': now, 'updated_at': now, 'position': 0,
          'is_template': 0, 'is_all_day': 1,
        });

        final result = await syncService.preparePushEntry(
          testDb, 'tasks', 'task-1', 'UPDATE', null, 'user-1',
        );

        expect(result, isNotNull);
        expect(result!['type'], 'upsert');
        expect(result['data']['title'], 'Current Title',
            reason: 'Should re-read current local state, not use stale payload');
      });

      test('converts to DELETE when local row is missing', () async {
        final result = await syncService.preparePushEntry(
          testDb, 'tasks', 'task-gone', 'UPDATE', null, 'user-1',
        );

        expect(result, isNotNull);
        expect(result!['type'], 'delete',
            reason: 'Missing local row should become a DELETE, not be silently dropped');
      });

      test('task_tags INSERT uses payload directly', () async {
        final payload = {'task_id': 'task-1', 'tag_id': 'tag-1', 'created_at': 1700000000000};

        final result = await syncService.preparePushEntry(
          testDb, 'task_tags', 'task-1_tag-1', 'INSERT', payload, 'user-1',
        );

        expect(result, isNotNull);
        expect(result!['type'], 'upsert');
        expect(result['data']['user_id'], 'user-1');
        expect(result['data']['task_id'], 'task-1');
      });

      test('DELETE on task_tags splits composite key', () async {
        final result = await syncService.preparePushEntry(
          testDb, 'task_tags', 'task-1_tag-1', 'DELETE', null, 'user-1',
        );

        expect(result, isNotNull);
        expect(result!['type'], 'delete_task_tag');
        expect(result['task_id'], 'task-1');
        expect(result['tag_id'], 'tag-1');
      });
    });

    // ═══════════════════════════════════════
    // UPDATED_AT REQUIREMENT
    // ═══════════════════════════════════════

    group('updated_at requirement', () {
      test('tasks table has updated_at column', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tasksTable, {
          'id': 'task-1', 'title': 'Test', 'completed': 0,
          'created_at': now, 'updated_at': now, 'position': 0,
          'is_template': 0, 'is_all_day': 1,
        });

        final result = await testDb.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: ['task-1']);
        expect(result.first['updated_at'], isNotNull);
        expect(result.first['updated_at'], now);
      });

      test('tags table has updated_at column', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await testDb.insert(AppConstants.tagsTable, {
          'id': 'tag-1', 'name': 'Test Tag',
          'created_at': now, 'updated_at': now,
        });

        final result = await testDb.query(AppConstants.tagsTable, where: 'id = ?', whereArgs: ['tag-1']);
        expect(result.first['updated_at'], isNotNull);
        expect(result.first['updated_at'], now);
      });
    });

    // ═══════════════════════════════════════
    // HAS PENDING TASK TAG OPS
    // ═══════════════════════════════════════

    group('hasPendingTaskTagOps', () {
      test('returns false when no pending ops', () async {
        final result = await syncService.hasPendingTaskTagOps();
        expect(result, false);
      });

      test('returns true when pending task_tags ops exist', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');
        await syncService.logChange(
          tableName: 'task_tags',
          recordId: 'task-1_tag-1',
          operation: 'INSERT',
          payload: {'task_id': 'task-1', 'tag_id': 'tag-1'},
        );

        final result = await syncService.hasPendingTaskTagOps();
        expect(result, true);
      });

      test('returns false for pending non-task_tags ops', () async {
        await syncService.updateSyncMeta(syncEnabled: true, userId: 'user-1');
        await syncService.logChange(
          tableName: 'tasks',
          recordId: 'task-1',
          operation: 'UPDATE',
          payload: {'title': 'New Title'},
        );

        final result = await syncService.hasPendingTaskTagOps();
        expect(result, false);
      });
    });
  });
}

// ═══════════════════════════════════════
// TEST HELPERS
// ═══════════════════════════════════════

Map<String, dynamic> _makeRemoteTask(String id, String title,
    {required DateTime updatedAt}) {
  return {
    'id': id,
    'title': title,
    'completed': false,
    'created_at': updatedAt.toUtc().toIso8601String(),
    'completed_at': null,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'parent_id': null,
    'position': 0,
    'is_template': false,
    'due_date': null,
    'is_all_day': true,
    'start_date': null,
    'notification_type': 'use_global',
    'notification_time': null,
    'deleted_at': null,
    'notes': null,
    'position_before_completion': null,
  };
}

Map<String, dynamic> _makeRemoteTag(String id, String name,
    {required DateTime updatedAt, String? color}) {
  return {
    'id': id,
    'name': name,
    'color': color,
    'created_at': updatedAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted_at': null,
  };
}
