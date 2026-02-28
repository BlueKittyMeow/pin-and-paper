import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Local sync engine for the Supabase sync layer.
///
/// Handles change tracking (sync_log), LWW merge logic, type conversions
/// between local SQLite (epoch ms, int booleans) and remote Supabase
/// (ISO 8601, native booleans), and task_tags union-merge.
///
/// Network operations (push/pull via Supabase REST + Realtime) will be
/// added in a later phase. This file contains only the local logic that
/// can be tested with in-memory SQLite.
class SyncService {
  static final SyncService instance = SyncService._production();

  final Database? _testDb;

  SyncService._production() : _testDb = null;

  /// Test constructor — uses the provided database directly, bypassing
  /// DatabaseService and avoiding any Supabase dependency.
  @visibleForTesting
  SyncService.testInstance(Database db) : _testDb = db;

  SyncMeta? _cachedMeta;

  Future<Database> get _database async {
    if (_testDb != null) return _testDb!;
    return await DatabaseService.instance.database;
  }

  // ═══════════════════════════════════════
  // SYNC META
  // ═══════════════════════════════════════

  Future<SyncMeta> getSyncMeta() async {
    final db = await _database;
    final result = await db.query('sync_meta', where: 'id = 1');
    if (result.isEmpty) return SyncMeta();

    final row = result.first;
    final meta = SyncMeta(
      userId: row['user_id'] as String?,
      lastPushAt: row['last_push_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_push_at'] as int)
          : null,
      lastPullAt: row['last_pull_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_pull_at'] as int)
          : null,
      syncEnabled: (row['sync_enabled'] as int?) == 1,
    );
    _cachedMeta = meta;
    return meta;
  }

  Future<void> updateSyncMeta({
    bool? syncEnabled,
    String? userId,
    DateTime? lastPushAt,
    DateTime? lastPullAt,
  }) async {
    final db = await _database;
    final updates = <String, dynamic>{};
    if (syncEnabled != null) updates['sync_enabled'] = syncEnabled ? 1 : 0;
    if (userId != null) updates['user_id'] = userId;
    if (lastPushAt != null) {
      updates['last_push_at'] = lastPushAt.millisecondsSinceEpoch;
    }
    if (lastPullAt != null) {
      updates['last_pull_at'] = lastPullAt.millisecondsSinceEpoch;
    }

    if (updates.isNotEmpty) {
      await db.update('sync_meta', updates, where: 'id = 1');
    }
    _cachedMeta = null;
  }

  // ═══════════════════════════════════════
  // CHANGE LOGGING
  // ═══════════════════════════════════════

  /// Log a local mutation. Call from TaskService/TagService after every
  /// INSERT, UPDATE, DELETE.
  ///
  /// No-op when sync is disabled. For DELETE, [payload] can be null.
  Future<void> logChange({
    required String tableName,
    required String recordId,
    required String operation,
    Map<String, dynamic>? payload,
  }) async {
    final meta = _cachedMeta ?? await getSyncMeta();
    if (!meta.syncEnabled) return;

    final db = await _database;
    await db.insert('sync_log', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });
  }

  // ═══════════════════════════════════════
  // PENDING CHANGES
  // ═══════════════════════════════════════

  /// Returns all unsynced sync_log entries in chronological order.
  Future<List<Map<String, dynamic>>> getPendingChanges() async {
    final db = await _database;
    return await db.query(
      'sync_log',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
  }

  // ═══════════════════════════════════════
  // MARK SYNCED
  // ═══════════════════════════════════════

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _database;
    await db.rawUpdate(
      'UPDATE sync_log SET synced = 1 WHERE id IN (${ids.join(",")})',
    );
  }

  // ═══════════════════════════════════════
  // TYPE CONVERSIONS
  // ═══════════════════════════════════════

  /// Convert epoch milliseconds to ISO 8601 UTC string (for Supabase).
  String? epochToIso(int? epochMs) {
    if (epochMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs)
        .toUtc()
        .toIso8601String();
  }

  /// Convert ISO 8601 string to epoch milliseconds (for local SQLite).
  int? isoToEpoch(String? iso) {
    if (iso == null) return null;
    return DateTime.parse(iso).millisecondsSinceEpoch;
  }

  /// Convert a local task row (SQLite ints) to remote format (Supabase booleans/ISO).
  /// Excludes `depth` — it is not persisted locally, computed via recursive CTEs.
  Map<String, dynamic> localTaskToRemote(
      Map<String, dynamic> local, String userId) {
    return {
      'id': local['id'],
      'user_id': userId,
      'title': local['title'],
      'completed': (local['completed'] as int) == 1,
      'created_at': epochToIso(local['created_at'] as int),
      'completed_at': epochToIso(local['completed_at'] as int?),
      'updated_at': epochToIso(local['updated_at'] as int?),
      'parent_id': local['parent_id'],
      'position': local['position'],
      'is_template': (local['is_template'] as int?) == 1,
      'due_date': epochToIso(local['due_date'] as int?),
      'is_all_day': (local['is_all_day'] as int?) == 1,
      'start_date': epochToIso(local['start_date'] as int?),
      'notification_type': local['notification_type'],
      'notification_time': epochToIso(local['notification_time'] as int?),
      'deleted_at': epochToIso(local['deleted_at'] as int?),
      'notes': local['notes'],
      'position_before_completion': local['position_before_completion'],
    };
  }

  /// Convert a remote task row (Supabase booleans/ISO) to local format (SQLite ints).
  /// Excludes `depth` — must not be written to local DB.
  Map<String, dynamic> remoteTaskToLocal(Map<String, dynamic> remote) {
    return {
      'id': remote['id'],
      'title': remote['title'],
      'completed': (remote['completed'] == true) ? 1 : 0,
      'created_at': isoToEpoch(remote['created_at']),
      'completed_at': isoToEpoch(remote['completed_at']),
      'updated_at': isoToEpoch(remote['updated_at']),
      'parent_id': remote['parent_id'],
      'position': remote['position'],
      'is_template': (remote['is_template'] == true) ? 1 : 0,
      'due_date': isoToEpoch(remote['due_date']),
      'is_all_day': (remote['is_all_day'] == true) ? 1 : 0,
      'start_date': isoToEpoch(remote['start_date']),
      'notification_type': remote['notification_type'],
      'notification_time': isoToEpoch(remote['notification_time']),
      'deleted_at': isoToEpoch(remote['deleted_at']),
      'notes': remote['notes'],
      'position_before_completion': remote['position_before_completion'],
    };
  }

  /// Convert a local task_tag row to remote format.
  /// Converts created_at from epoch to ISO, adds user_id.
  Map<String, dynamic> localTaskTagToRemote(
      Map<String, dynamic> local, String userId) {
    return {
      'task_id': local['task_id'],
      'tag_id': local['tag_id'],
      'user_id': userId,
      'created_at': epochToIso(local['created_at'] as int),
    };
  }

  Map<String, dynamic> _localTagToRemote(
      Map<String, dynamic> local, String userId) {
    return {
      'id': local['id'],
      'user_id': userId,
      'name': local['name'],
      'color': local['color'],
      'created_at': epochToIso(local['created_at'] as int),
      'updated_at': epochToIso(local['updated_at'] as int?),
      'deleted_at': epochToIso(local['deleted_at'] as int?),
    };
  }

  Map<String, dynamic> _remoteTagToLocal(Map<String, dynamic> remote) {
    return {
      'id': remote['id'],
      'name': remote['name'],
      'color': remote['color'],
      'created_at': isoToEpoch(remote['created_at']),
      'updated_at': isoToEpoch(remote['updated_at']),
      'deleted_at': isoToEpoch(remote['deleted_at']),
    };
  }

  // ═══════════════════════════════════════
  // MERGE LOGIC (Last-Write-Wins)
  // ═══════════════════════════════════════

  /// Merge a remote task into the local DB using LWW on updated_at.
  /// Inserts if the task doesn't exist locally.
  /// Remote wins on equal timestamps (>= — prefers MCP/additive edits).
  Future<void> mergeTask(Database db, Map<String, dynamic> remote) async {
    final localResult = await db.query(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [remote['id']],
    );

    final localData = remoteTaskToLocal(remote);

    if (localResult.isEmpty) {
      await db.insert(AppConstants.tasksTable, localData);
      return;
    }

    final local = localResult.first;
    final localUpdated = local['updated_at'] as int? ?? 0;
    final remoteUpdated =
        DateTime.parse(remote['updated_at']).millisecondsSinceEpoch;

    if (remoteUpdated >= localUpdated) {
      await db.update(
        AppConstants.tasksTable,
        localData,
        where: 'id = ?',
        whereArgs: [remote['id']],
      );
    }
  }

  /// Merge a remote tag into the local DB using LWW on updated_at.
  Future<void> mergeTag(Database db, Map<String, dynamic> remote) async {
    final localResult = await db.query(
      AppConstants.tagsTable,
      where: 'id = ?',
      whereArgs: [remote['id']],
    );

    final localData = _remoteTagToLocal(remote);

    if (localResult.isEmpty) {
      await db.insert(AppConstants.tagsTable, localData);
      return;
    }

    final local = localResult.first;
    final localUpdated = local['updated_at'] as int? ?? 0;
    final remoteUpdated =
        DateTime.parse(remote['updated_at']).millisecondsSinceEpoch;

    if (remoteUpdated >= localUpdated) {
      await db.update(
        AppConstants.tagsTable,
        localData,
        where: 'id = ?',
        whereArgs: [remote['id']],
      );
    }
  }

  // ═══════════════════════════════════════
  // TASK_TAGS UNION MERGE
  // ═══════════════════════════════════════

  /// Union-merge remote task_tags with local.
  ///
  /// When [hasPendingOps] is true, skips the merge entirely — local changes
  /// must be pushed first to avoid clobbering unpushed tag associations.
  ///
  /// When [hasPendingOps] is false, reconciles local with remote:
  /// - Adds rows that exist remotely but not locally
  /// - Removes rows that exist locally but not remotely (deleted remotely)
  /// - Inserted rows include created_at to satisfy NOT NULL constraint
  Future<void> pullTaskTags(
    Database db,
    List<Map<String, dynamic>> remoteTaskTags, {
    required bool hasPendingOps,
  }) async {
    if (hasPendingOps) return;

    // Get all local task_tags
    final localAll = await db.query(AppConstants.taskTagsTable);
    final localSet =
        localAll.map((r) => '${r['task_id']}_${r['tag_id']}').toSet();

    // Build remote set
    final remoteSet =
        remoteTaskTags.map((r) => '${r['task_id']}_${r['tag_id']}').toSet();

    // Add remote-only rows
    for (final remote in remoteTaskTags) {
      final key = '${remote['task_id']}_${remote['tag_id']}';
      if (!localSet.contains(key)) {
        await db.insert(AppConstants.taskTagsTable, {
          'task_id': remote['task_id'],
          'tag_id': remote['tag_id'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }

    // Remove local rows that were deleted remotely
    for (final local in localAll) {
      final key = '${local['task_id']}_${local['tag_id']}';
      if (!remoteSet.contains(key)) {
        await db.delete(
          AppConstants.taskTagsTable,
          where: 'task_id = ? AND tag_id = ?',
          whereArgs: [local['task_id'], local['tag_id']],
        );
      }
    }
  }

  // ═══════════════════════════════════════
  // PUSH ENTRY PREPARATION
  // ═══════════════════════════════════════

  /// Prepare a sync_log entry for pushing to Supabase.
  ///
  /// For tasks/tags UPDATE: re-reads current local state (not stale payload).
  /// For task_tags: uses the payload directly (junction rows are simple).
  /// If a local row is missing on UPDATE, converts to DELETE instead of
  /// silently dropping the change.
  ///
  /// Returns a map with 'type' ('upsert', 'delete', 'delete_task_tag')
  /// and the relevant data.
  Future<Map<String, dynamic>?> preparePushEntry(
    Database db,
    String table,
    String recordId,
    String operation,
    Map<String, dynamic>? payload,
    String userId,
  ) async {
    // DELETE operations
    if (operation == 'DELETE') {
      if (table == 'task_tags') {
        final parts = recordId.split('_');
        return {
          'type': 'delete_task_tag',
          'task_id': parts[0],
          'tag_id': parts[1],
        };
      }
      return {'type': 'delete', 'id': recordId};
    }

    // INSERT or UPDATE
    if (table == 'task_tags' && payload != null) {
      return {
        'type': 'upsert',
        'data': localTaskTagToRemote(payload, userId),
      };
    }

    if (table == 'tasks') {
      final local = await db.query(
        AppConstants.tasksTable,
        where: 'id = ?',
        whereArgs: [recordId],
      );
      if (local.isEmpty) {
        return {'type': 'delete'};
      }
      return {
        'type': 'upsert',
        'data': localTaskToRemote(local.first, userId),
      };
    }

    if (table == 'tags') {
      final local = await db.query(
        AppConstants.tagsTable,
        where: 'id = ?',
        whereArgs: [recordId],
      );
      if (local.isEmpty) {
        return {'type': 'delete'};
      }
      return {
        'type': 'upsert',
        'data': _localTagToRemote(local.first, userId),
      };
    }

    return null;
  }

  // ═══════════════════════════════════════
  // PENDING TASK TAG OPS
  // ═══════════════════════════════════════

  /// Check whether there are any unsynced task_tags operations in sync_log.
  /// Used to decide whether to skip the union-merge during pull.
  Future<bool> hasPendingTaskTagOps() async {
    final db = await _database;
    final result = await db.query(
      'sync_log',
      where: "synced = 0 AND table_name = 'task_tags'",
    );
    return result.isNotEmpty;
  }
}

// ═══════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════

class SyncMeta {
  final String? userId;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;
  final bool syncEnabled;

  SyncMeta({
    this.userId,
    this.lastPushAt,
    this.lastPullAt,
    this.syncEnabled = false,
  });
}

enum SyncResult {
  success,
  nothingToPush,
  skipped,
  disabled,
  error,
}
