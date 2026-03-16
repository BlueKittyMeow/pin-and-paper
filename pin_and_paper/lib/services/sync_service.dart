import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Sync engine for the Supabase sync layer.
///
/// Handles change tracking (sync_log), LWW merge logic, type conversions
/// between local SQLite (epoch ms, int booleans) and remote Supabase
/// (ISO 8601, native booleans), task_tags union-merge, and network
/// operations (push/pull via Supabase REST + Realtime subscriptions).
///
/// Phase 4.0: Full network sync with per-entry push, server-timestamp
/// pull cursor, deduplication, batched fullPush, and connectivity gating.
class SyncService {
  static final SyncService instance = SyncService._production();

  final Database? _testDb;

  SyncService._production() : _testDb = null;

  /// Test constructor — uses the provided database directly, bypassing
  /// DatabaseService and avoiding any Supabase dependency.
  @visibleForTesting
  SyncService.testInstance(Database db) : _testDb = db;

  SyncMeta? _cachedMeta;
  bool _isSyncing = false;
  bool _pendingPull = false;
  Timer? _pullDebounceTimer;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _authSub;

  /// Callback invoked after pull merges remote changes into local DB.
  /// Wire this to TaskProvider.refreshTasks() in main.dart.
  VoidCallback? onDataChanged;

  /// Callback invoked after any push() or pull() completes (success or empty).
  /// Used by SettingsScreen to refresh the "Last synced" timestamp live.
  VoidCallback? onSyncComplete;

  /// Whether Supabase is available (false in test mode).
  bool get _hasSupabase => _testDb == null;

  SupabaseClient get _supabase => Supabase.instance.client;

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
    // Update cache in-place instead of clearing it. Clearing causes a
    // deadlock when logChange() is called inside a transaction — the
    // getSyncMeta() fallback tries to read the DB outside the txn, which
    // is queued behind the active transaction, creating a circular wait.
    if (_cachedMeta != null) {
      _cachedMeta = SyncMeta(
        userId: userId ?? _cachedMeta!.userId,
        lastPushAt: lastPushAt ?? _cachedMeta!.lastPushAt,
        lastPullAt: lastPullAt ?? _cachedMeta!.lastPullAt,
        syncEnabled: syncEnabled ?? _cachedMeta!.syncEnabled,
      );
    } else {
      // No cache yet — clear so next getSyncMeta() rebuilds from DB
      _cachedMeta = null;
    }
  }

  // ═══════════════════════════════════════
  // CHANGE LOGGING
  // ═══════════════════════════════════════

  /// Log a local mutation. Call from TaskService/TagService after every
  /// INSERT, UPDATE, DELETE.
  ///
  /// No-op when sync is disabled. For DELETE, [payload] can be null.
  ///
  /// When [txn] is provided, the sync_log insert happens inside the same
  /// transaction as the data write — prevents crash-window data loss.
  Future<void> logChange({
    required String tableName,
    required String recordId,
    required String operation,
    Map<String, dynamic>? payload,
    DatabaseExecutor? txn,
  }) async {
    final meta = _cachedMeta ?? await getSyncMeta();
    if (!meta.syncEnabled) return;

    final executor = txn ?? await _database;
    await executor.insert('sync_log', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });

    _schedulePush();
  }

  // ═══════════════════════════════════════
  // PUSH SCHEDULING
  // ═══════════════════════════════════════

  Timer? _pushTimer;

  /// Schedule a push after a 2-second debounce.
  /// Called from logChange() when sync is enabled.
  void _schedulePush() {
    if (!_hasSupabase) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), () {
      push();
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

  Map<String, dynamic> localTagToRemote(
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

  Map<String, dynamic> remoteTagToLocal(Map<String, dynamic> remote) {
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

    final localData = remoteTagToLocal(remote);

    if (localResult.isEmpty) {
      // Check for name collision (local tag with same name but different UUID)
      final nameResult = await db.query(
        AppConstants.tagsTable,
        where: 'name = ?',
        whereArgs: [localData['name']],
      );
      if (nameResult.isNotEmpty) {
        // A local tag with this name already exists under a different ID.
        // Unify: insert remote tag, migrate task_tags FKs, delete old tag.
        final existingLocal = nameResult.first;
        final localId = existingLocal['id'];
        final remoteId = localData['id'];

        // Non-standard LWW: preserve local color when remote color is null.
        // MCP-created tags lack color, so we keep the user's local color choice.
        if (localData['color'] == null && existingLocal['color'] != null) {
          localData['color'] = existingLocal['color'];
        }

        // Temporarily disable FK checks to allow the migration.
        await db.execute('PRAGMA foreign_keys = OFF');
        try {
          // Delete old tag first (FK checks off, so task_tags won't cascade)
          await db.delete(
            AppConstants.tagsTable,
            where: 'id = ?',
            whereArgs: [localId],
          );
          // Insert remote tag (name is now free)
          await db.insert(AppConstants.tagsTable, localData);
          // Migrate task_tags to point to the remote ID
          await db.update(
            AppConstants.taskTagsTable,
            {'tag_id': remoteId},
            where: 'tag_id = ?',
            whereArgs: [localId],
          );
        } finally {
          await db.execute('PRAGMA foreign_keys = ON');
        }
      } else {
        await db.insert(AppConstants.tagsTable, localData);
      }
      return;
    }

    final local = localResult.first;
    final localUpdated = local['updated_at'] as int? ?? 0;
    final remoteUpdated =
        DateTime.parse(remote['updated_at']).millisecondsSinceEpoch;

    if (remoteUpdated >= localUpdated) {
      // Non-standard LWW: preserve local color when remote color is null.
      // MCP-created tags lack color, so we keep the user's local color choice.
      if (localData['color'] == null && local['color'] != null) {
        localData['color'] = local['color'];
      }
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

    // Build sets of locally existing task and tag IDs for FK validation
    final localTaskIds = (await db.query(AppConstants.tasksTable, columns: ['id']))
        .map((r) => r['id'] as String)
        .toSet();
    final localTagIds = (await db.query(AppConstants.tagsTable, columns: ['id']))
        .map((r) => r['id'] as String)
        .toSet();

    // Add remote-only rows (skip if referenced task or tag doesn't exist locally)
    for (final remote in remoteTaskTags) {
      final key = '${remote['task_id']}_${remote['tag_id']}';
      if (!localSet.contains(key)) {
        final taskId = remote['task_id'] as String;
        final tagId = remote['tag_id'] as String;
        if (!localTaskIds.contains(taskId) || !localTagIds.contains(tagId)) {
          debugPrint('[Sync] Skipping task_tag $taskId/$tagId — missing local FK');
          continue;
        }
        await db.insert(AppConstants.taskTagsTable, {
          'task_id': taskId,
          'tag_id': tagId,
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
        return {'type': 'delete', 'id': recordId};
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
        return {'type': 'delete', 'id': recordId};
      }
      return {
        'type': 'upsert',
        'data': localTagToRemote(local.first, userId),
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

  // ═══════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════

  /// Call once at app startup (after Supabase.initialize).
  /// Sets up auth listener, verifies stored user, subscribes to realtime.
  Future<void> initialize() async {
    if (!_hasSupabase) return;

    // Listen for auth state changes
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _onUserSignedOut();
      }
    });

    final meta = await getSyncMeta();
    if (!meta.syncEnabled) return;

    // Verify stored user matches current auth user
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || currentUser.id != meta.userId) {
      await disableSync();
      return;
    }

    // Subscribe first, then pull (catches changes during pull)
    _subscribeToRemoteChanges(currentUser.id);
    _listenForConnectivity();
    await pull();
  }

  /// Enable sync for the first time. Triggers initial full push.
  Future<void> enableSync() async {
    if (!_hasSupabase) return;

    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Must be authenticated to enable sync');

    await updateSyncMeta(syncEnabled: true, userId: user.id);
    await fullPush();
    await pull(); // Fetch remote data (e.g. tags added via MCP)
    _subscribeToRemoteChanges(user.id);
    _listenForConnectivity();
  }

  /// Disable sync. Local data remains. Remote data remains.
  Future<void> disableSync() async {
    if (_hasSupabase) {
      _supabase.removeAllChannels();
    }
    _connectivitySub?.cancel();
    _pushTimer?.cancel();
    _pullDebounceTimer?.cancel();
    await updateSyncMeta(syncEnabled: false);
  }

  /// Handle user sign-out — disable sync and clear user.
  Future<void> _onUserSignedOut() async {
    if (_hasSupabase) {
      _supabase.removeAllChannels();
    }
    _connectivitySub?.cancel();
    _pushTimer?.cancel();
    _pullDebounceTimer?.cancel();
    // Clear userId by setting it to empty, then clearing sync state
    final db = await _database;
    await db.update('sync_meta', {
      'sync_enabled': 0,
      'user_id': null,
    }, where: 'id = 1');
    _cachedMeta = null;
  }

  void dispose() {
    _pushTimer?.cancel();
    _pullDebounceTimer?.cancel();
    _connectivitySub?.cancel();
    _authSub?.cancel();
  }

  // ═══════════════════════════════════════
  // PUSH (local → Supabase)
  // ═══════════════════════════════════════

  /// Push pending local changes to Supabase.
  ///
  /// Design review fixes applied:
  /// - Deduplicates sync_log by record_id (keeps latest per record)
  /// - Marks entries synced one at a time (not in bulk)
  /// - Stops on first failure to prevent data loss
  Future<SyncResult> push() async {
    if (_isSyncing) return SyncResult.skipped;
    if (!_hasSupabase) return SyncResult.disabled;
    _isSyncing = true;

    try {
      final meta = await getSyncMeta();
      if (!meta.syncEnabled) return SyncResult.disabled;
      if (meta.userId == null) return SyncResult.disabled;

      final db = await _database;
      final pending = await db.query(
        'sync_log',
        where: 'synced = 0',
        orderBy: 'created_at ASC',
      );

      if (pending.isEmpty) return SyncResult.nothingToPush;

      // Deduplicate: for the same record_id, only push the latest entry.
      // Earlier entries for the same record are redundant since _pushEntry
      // re-reads current local state for tasks/tags.
      final seen = <String, Map<String, dynamic>>{};
      final obsoleteIds = <int>[];
      for (final entry in pending) {
        final key = '${entry['table_name']}_${entry['record_id']}';
        if (seen.containsKey(key)) {
          // Mark the previous entry as synced (obsolete)
          obsoleteIds.add(seen[key]!['id'] as int);
        }
        seen[key] = entry;
      }

      // Mark obsolete entries as synced
      if (obsoleteIds.isNotEmpty) {
        await db.rawUpdate(
          'UPDATE sync_log SET synced = 1 WHERE id IN (${obsoleteIds.join(",")})',
        );
      }

      // Push remaining unique entries, mark each synced individually
      for (final entry in seen.values) {
        try {
          await _pushEntry(entry, meta.userId!);

          // Mark this entry synced immediately after success
          await db.update(
            'sync_log',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [entry['id']],
          );
        } catch (e) {
          // Stop on first failure — remaining entries stay unsynced
          debugPrint('[Sync] Push entry failed: $e');
          return SyncResult.error;
        }
      }

      await updateSyncMeta(lastPushAt: DateTime.now());
      return SyncResult.success;
    } catch (e) {
      debugPrint('[Sync] Push failed: $e');
      return SyncResult.error;
    } finally {
      _isSyncing = false;
      onSyncComplete?.call();
      // If a pull was requested during sync, run it now
      if (_pendingPull) {
        _pendingPull = false;
        pull();
      }
    }
  }

  /// Push a single sync_log entry to Supabase.
  Future<void> _pushEntry(Map<String, dynamic> entry, String userId) async {
    final db = await _database;
    final table = entry['table_name'] as String;
    final recordId = entry['record_id'] as String;
    final operation = entry['operation'] as String;
    final payloadJson = entry['payload'] as String?;
    final payload = payloadJson != null
        ? jsonDecode(payloadJson) as Map<String, dynamic>
        : null;

    final prepared = await preparePushEntry(
      db, table, recordId, operation, payload, userId,
    );
    if (prepared == null) return;

    final type = prepared['type'] as String;

    if (type == 'upsert') {
      await _supabase.from(table).upsert(prepared['data']);
    } else if (type == 'delete') {
      await _supabase.from(table).delete().eq('id', prepared['id']);
    } else if (type == 'delete_task_tag') {
      await _supabase
          .from('task_tags')
          .delete()
          .eq('task_id', prepared['task_id'])
          .eq('tag_id', prepared['tag_id']);
    }
  }

  /// Full push — initial sync. Pushes ALL local data via bulk upsert.
  /// Batches at 500 records to avoid payload/timeout limits.
  /// Check if a string is a valid UUID v4 format.
  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static bool _isValidUuid(String id) => _uuidRegex.hasMatch(id);

  Future<void> fullPush() async {
    if (!_hasSupabase) return;

    final db = await _database;
    final meta = await getSyncMeta();
    if (meta.userId == null) return;
    final userId = meta.userId!;

    const batchSize = 500;

    // Bulk upsert all tasks (batched)
    // Filter out rows with non-UUID IDs (e.g., test/sample data created
    // before sync was implemented). Supabase requires UUID primary keys.
    final allTasks = await db.query(AppConstants.tasksTable);
    final tasks = allTasks.where((t) => _isValidUuid(t['id'] as String)).toList();
    if (tasks.length < allTasks.length) {
      debugPrint('[Sync] Skipped ${allTasks.length - tasks.length} tasks with non-UUID IDs');
    }
    for (int i = 0; i < tasks.length; i += batchSize) {
      final end = (i + batchSize < tasks.length) ? i + batchSize : tasks.length;
      final batch = tasks.sublist(i, end);
      final remoteTasks = batch.map((t) => localTaskToRemote(t, userId)).toList();
      await _supabase.from('tasks').upsert(remoteTasks);
    }

    // Bulk upsert all tags (batched)
    // First, reconcile tag IDs with remote to avoid UNIQUE(user_id, name)
    // conflicts when the same tag was created independently on another device.
    final allTags = await db.query(AppConstants.tagsTable);
    // Make mutable copies — sqflite returns read-only maps
    final tags = allTags
        .where((t) => _isValidUuid(t['id'] as String))
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    if (tags.length < allTags.length) {
      debugPrint('[Sync] Skipped ${allTags.length - tags.length} tags with non-UUID IDs');
    }

    final existingRemoteTags = await _supabase
        .from('tags')
        .select('id, name')
        .eq('user_id', userId);
    final remoteTagByName = <String, String>{};
    for (final rt in existingRemoteTags) {
      remoteTagByName[rt['name'] as String] = rt['id'] as String;
    }

    // Remap local tag IDs to match remote where names collide
    for (final tag in tags) {
      final localId = tag['id'] as String;
      final name = tag['name'] as String;
      final remoteId = remoteTagByName[name];
      if (remoteId != null && remoteId != localId) {
        debugPrint('[Sync] Remapping tag "$name" from $localId to $remoteId');
        // Update task_tags references first (FK constraint)
        await db.rawUpdate(
          'UPDATE ${AppConstants.taskTagsTable} SET tag_id = ? WHERE tag_id = ?',
          [remoteId, localId],
        );
        // Update the tag itself
        await db.rawUpdate(
          'UPDATE ${AppConstants.tagsTable} SET id = ? WHERE id = ?',
          [remoteId, localId],
        );
        tag['id'] = remoteId;
      }
    }

    for (int i = 0; i < tags.length; i += batchSize) {
      final end = (i + batchSize < tags.length) ? i + batchSize : tags.length;
      final batch = tags.sublist(i, end);
      final remoteTags = batch.map((t) => localTagToRemote(t, userId)).toList();
      // Use onConflict on the business key (user_id, name) with ignoreDuplicates
      // so tags that already exist remotely (e.g. pushed from another device) are
      // skipped rather than causing a unique constraint violation. The subsequent
      // pull() will reconcile any skipped tags back to local.
      await _supabase.from('tags').upsert(
        remoteTags,
        onConflict: 'user_id,name',
        ignoreDuplicates: true,
      );
    }

    // Re-fetch remote tags to build a set of valid remote tag IDs.
    // This ensures task_tags only reference tags that actually exist remotely,
    // avoiding FK violations when some tags were skipped above.
    final postUpsertRemoteTags = await _supabase
        .from('tags')
        .select('id')
        .eq('user_id', userId);
    final remoteTagIds = <String>{
      for (final rt in postUpsertRemoteTags) rt['id'] as String,
    };

    // Bulk upsert all task_tags (batched)
    // Filter task_tags where both task_id and tag_id are valid UUIDs
    // and where the tag_id exists remotely (to avoid FK violations)
    final allTaskTags = await db.query(AppConstants.taskTagsTable);
    final taskTags = allTaskTags.where((tt) =>
      _isValidUuid(tt['task_id'] as String) &&
      _isValidUuid(tt['tag_id'] as String) &&
      remoteTagIds.contains(tt['tag_id'] as String)
    ).toList();
    if (taskTags.length < allTaskTags.length) {
      debugPrint('[Sync] Skipped ${allTaskTags.length - taskTags.length} task_tags with non-UUID or missing remote tag IDs');
    }
    for (int i = 0; i < taskTags.length; i += batchSize) {
      final end = (i + batchSize < taskTags.length) ? i + batchSize : taskTags.length;
      final batch = taskTags.sublist(i, end);
      final remoteTT = batch.map((tt) => localTaskTagToRemote(tt, userId)).toList();
      await _supabase.from('task_tags').upsert(remoteTT);
    }

    // Mark all existing sync_log entries as synced
    await db.rawUpdate('UPDATE sync_log SET synced = 1 WHERE synced = 0');

    await updateSyncMeta(lastPushAt: DateTime.now());
  }

  // ═══════════════════════════════════════
  // PULL HELPERS
  // ═══════════════════════════════════════

  /// Sort tasks so parents come before children (topological order).
  /// Prevents FK constraint failures when inserting hierarchical tasks.
  List<Map<String, dynamic>> _topologicalSortTasks(
      List<dynamic> tasks) {
    final byId = <String, Map<String, dynamic>>{};
    for (final t in tasks) {
      byId[t['id'] as String] = Map<String, dynamic>.from(t);
    }

    final sorted = <Map<String, dynamic>>[];
    final visited = <String>{};

    void visit(Map<String, dynamic> task) {
      final id = task['id'] as String;
      if (visited.contains(id)) return;
      visited.add(id);

      // If parent is in this batch, visit it first
      final parentId = task['parent_id'] as String?;
      if (parentId != null && byId.containsKey(parentId)) {
        visit(byId[parentId]!);
      }

      sorted.add(task);
    }

    for (final task in byId.values) {
      visit(task);
    }

    return sorted;
  }

  // ═══════════════════════════════════════
  // PULL (Supabase → local)
  // ═══════════════════════════════════════

  /// Pull remote changes since last pull and merge via LWW.
  ///
  /// Design review fix: Uses max server timestamp from pulled records
  /// as lastPullAt cursor instead of local clock (prevents clock skew).
  Future<SyncResult> pull() async {
    if (_isSyncing) {
      _pendingPull = true;
      return SyncResult.skipped;
    }
    if (!_hasSupabase) return SyncResult.disabled;
    _isSyncing = true;

    try {
      final meta = await getSyncMeta();
      if (!meta.syncEnabled) return SyncResult.disabled;

      final since = meta.lastPullAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = await _database;

      int maxUpdatedAt = since.millisecondsSinceEpoch;

      // Pull tasks updated since last pull
      final remoteTasks = await _supabase
          .from('tasks')
          .select()
          .gt('updated_at', since.toUtc().toIso8601String())
          .order('updated_at');

      // Sort parents before children to avoid FK constraint failures.
      // Tasks with null parent_id come first, then children after their parents.
      final sortedTasks = _topologicalSortTasks(remoteTasks);

      for (final remote in sortedTasks) {
        await mergeTask(db, remote);
        // Track max server timestamp
        final ts = DateTime.parse(remote['updated_at']).millisecondsSinceEpoch;
        if (ts > maxUpdatedAt) maxUpdatedAt = ts;
      }

      // Pull tags updated since last pull
      final remoteTags = await _supabase
          .from('tags')
          .select()
          .gt('updated_at', since.toUtc().toIso8601String())
          .order('updated_at');

      for (final remote in remoteTags) {
        await mergeTag(db, remote);
        final ts = DateTime.parse(remote['updated_at']).millisecondsSinceEpoch;
        if (ts > maxUpdatedAt) maxUpdatedAt = ts;
      }

      // Pull ALL task_tags for this user and union-merge
      final remoteTaskTags = await _supabase
          .from('task_tags')
          .select('task_id, tag_id');

      final hasPending = await hasPendingTaskTagOps();
      await pullTaskTags(db, remoteTaskTags, hasPendingOps: hasPending);

      // Use max server timestamp as cursor (not local clock)
      await updateSyncMeta(
        lastPullAt: DateTime.fromMillisecondsSinceEpoch(maxUpdatedAt),
      );

      // Notify UI of data changes
      onDataChanged?.call();

      return SyncResult.success;
    } catch (e) {
      debugPrint('[Sync] Pull failed: $e');
      return SyncResult.error;
    } finally {
      _isSyncing = false;
      onSyncComplete?.call();
      // If another pull was requested during sync, run it now
      if (_pendingPull) {
        _pendingPull = false;
        pull();
      }
    }
  }

  // ═══════════════════════════════════════
  // REALTIME (Supabase → local, live)
  // ═══════════════════════════════════════

  void _subscribeToRemoteChanges(String userId) {
    _supabase
        .channel('sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _onRemoteChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tags',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _onRemoteChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_tags',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _onRemoteChange(),
        )
        .subscribe();
  }

  /// Debounced handler for remote changes — triggers pull after 500ms.
  void _onRemoteChange() {
    _pullDebounceTimer?.cancel();
    _pullDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      pull();
    });
  }

  // ═══════════════════════════════════════
  // CONNECTIVITY
  // ═══════════════════════════════════════

  /// Listen for connectivity changes. On reconnect, push then pull.
  /// Design review fix: Only pull after successful push.
  void _listenForConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        // Gate pull on push success to prevent overwriting unpushed local changes
        push().then((result) {
          if (result != SyncResult.error) {
            pull();
          }
        });
      }
    });
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
