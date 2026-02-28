# Pin and Paper — Supabase Sync Layer Specification

**Version:** 2.0
**Date:** 2026-02-27
**Target:** `pin_and_paper/lib/services/sync_service.dart` (main app)
**Depends on:** `database_service.dart`, Supabase Flutter SDK
**Reviewed by:** Claude, Codex, Gemini (see review changelog at end)

---

## Architecture Overview

```
Pin and Paper (phone)          Supabase (cloud)           Claude MCP Server
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  SQLite (local)  │◄────►│  PostgreSQL      │◄────►│  Edge Function   │
│  + sync_log      │      │  + RLS policies  │      │  (MCP tools)     │
│  + sync_meta     │      │  + realtime      │      │                  │
└──────────────────┘      └──────────────────┘      └──────────────────┘
        ▲                         ▲                         ▲
        │                         │                         │
   SyncService              Supabase Auth              Claude Connector
   (this spec)              (OAuth token)              (separate spec)
```

**Principle: Local-first, sync-second.** SQLite is always the source of truth for the app. Supabase is the bridge to Claude and future multi-device. The app must work perfectly offline — sync is additive.

---

## 1. New Dependencies

Add to `pubspec.yaml`:

```yaml
# Sync layer
supabase_flutter: ^2.8.0    # Supabase client + auth + realtime
```

That's it. `supabase_flutter` bundles the REST client, auth, realtime subscriptions, and offline queue.

---

## 2. New Local Tables

Add to `database_service.dart` as migration v12:

### sync_log

Tracks every local mutation that hasn't been pushed to Supabase yet.

```sql
CREATE TABLE sync_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,          -- 'tasks', 'tags', 'task_tags'
  record_id TEXT NOT NULL,           -- UUID of the affected record
  operation TEXT NOT NULL,           -- 'INSERT', 'UPDATE', 'DELETE'
  payload TEXT,                      -- JSON of the changed fields (for UPDATE, only changed cols)
  created_at INTEGER NOT NULL,       -- epoch ms
  synced INTEGER NOT NULL DEFAULT 0  -- 0 = pending, 1 = synced
);

CREATE INDEX idx_sync_log_pending ON sync_log(synced, created_at);
```

### sync_meta

Single-row table for sync state.

```sql
CREATE TABLE sync_meta (
  id INTEGER PRIMARY KEY DEFAULT 1,
  user_id TEXT,                      -- Supabase auth user ID
  last_push_at INTEGER,              -- epoch ms of last successful push
  last_pull_at INTEGER,              -- epoch ms of last successful pull
  sync_enabled INTEGER DEFAULT 0,    -- user has opted in to sync
  CHECK (id = 1)
);

INSERT INTO sync_meta (id) VALUES (1);
```

### Column additions

Add `updated_at INTEGER` to `tasks` and `tags` tables (migration v12). Backfill from `created_at`.

```sql
ALTER TABLE tasks ADD COLUMN updated_at INTEGER;
UPDATE tasks SET updated_at = created_at WHERE updated_at IS NULL;

ALTER TABLE tags ADD COLUMN updated_at INTEGER;
UPDATE tags SET updated_at = created_at WHERE updated_at IS NULL;
```

### Service write requirement [FIX: Gemini #1, Codex #3]

**CRITICAL:** Every `db.insert()` and `db.update()` in `TaskService` and `TagService` MUST include `updated_at` in the field map:

```dart
'updated_at': DateTime.now().millisecondsSinceEpoch,
```

This is required for LWW merge to work correctly. Without it, local timestamps remain stale and remote will always win. See Section 5 for the complete list of write sites.

---

## 3. Supabase Schema (PostgreSQL)

Mirror of local SQLite, with auth integration.

**NOTE on `depth`** [FIX: Codex #1]: The local SQLite schema does NOT persist `depth` — it is computed dynamically via recursive CTEs in queries. `Task.toMap()` explicitly excludes it. Therefore `depth` is excluded from the sync surface entirely. Remote `depth` is computed server-side or by MCP when needed.

```sql
-- Tasks [FIX: Codex #1 — depth removed from sync surface]
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  parent_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
  position INTEGER NOT NULL DEFAULT 0,
  is_template BOOLEAN NOT NULL DEFAULT FALSE,
  due_date TIMESTAMPTZ,
  is_all_day BOOLEAN DEFAULT TRUE,
  start_date TIMESTAMPTZ,
  notification_type TEXT DEFAULT 'use_global',
  notification_time TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  notes TEXT,
  position_before_completion INTEGER
);

-- Tags
CREATE TABLE tags (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  UNIQUE(user_id, name)
);

-- Task-Tag junction [FIX: Gemini #2, Codex #2 — added created_at to match local schema]
CREATE TABLE task_tags (
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (task_id, tag_id)
);

-- Enable RLS on all tables
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tags ENABLE ROW LEVEL SECURITY;

-- RLS Policies [FIX: Codex #8 — added WITH CHECK on updates, added UPDATE policy for task_tags]
CREATE POLICY tasks_select ON tasks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY tasks_insert ON tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY tasks_update ON tasks FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY tasks_delete ON tasks FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY tags_select ON tags FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY tags_insert ON tags FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY tags_update ON tags FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY tags_delete ON tags FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY task_tags_select ON task_tags FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY task_tags_insert ON task_tags FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY task_tags_update ON task_tags FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY task_tags_delete ON task_tags FOR DELETE USING (auth.uid() = user_id);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tags_updated_at BEFORE UPDATE ON tags
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Performance indexes
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_user_active ON tasks(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_user_due ON tasks(user_id, due_date) WHERE due_date IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_tags_user_id ON tags(user_id);
CREATE INDEX idx_task_tags_user ON task_tags(user_id);
```

---

## 4. Sync Service API

```dart
// lib/services/sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/constants.dart';
import 'database_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final _dbService = DatabaseService.instance;
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isSyncing = false;
  Timer? _debounceTimer;
  SyncMeta? _cachedMeta;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _authSub;

  // ═══════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════

  /// Call once at app startup (after Supabase.initialize)
  Future<void> initialize() async {
    // [FIX: Codex #12] Listen for auth state changes to handle user switching
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _onUserSignedOut();
      }
    });

    final meta = await _getSyncMeta();
    if (!meta.syncEnabled) return;

    // Verify the stored user matches current auth user
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || currentUser.id != meta.userId) {
      await disableSync();
      return;
    }

    _subscribeToRemoteChanges(currentUser.id);
    _listenForConnectivity();
    await pull();
  }

  /// Enable sync for the first time. Triggers initial full push.
  Future<void> enableSync() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Must be authenticated to enable sync');

    await _updateSyncMeta(syncEnabled: true, userId: user.id);
    await fullPush();
    // [FIX: Codex #7] Pass userId directly instead of reading from invalidated cache
    _subscribeToRemoteChanges(user.id);
    _listenForConnectivity();
  }

  /// Disable sync. Local data remains. Remote data remains.
  Future<void> disableSync() async {
    _supabase.removeAllChannels();
    _connectivitySub?.cancel();
    await _updateSyncMeta(syncEnabled: false);
  }

  /// [FIX: Codex #12] Handle user sign-out
  Future<void> _onUserSignedOut() async {
    _supabase.removeAllChannels();
    _connectivitySub?.cancel();
    await _updateSyncMeta(syncEnabled: false, userId: null);
  }

  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    _authSub?.cancel();
  }

  // ═══════════════════════════════════════
  // CHANGE TRACKING (called by services)
  // ═══════════════════════════════════════

  /// Log a local mutation. Call from TaskService/TagService after every
  /// INSERT, UPDATE, DELETE.
  ///
  /// For UPDATE: [payload] = only the changed fields as JSON.
  /// For INSERT: [payload] = full record as JSON.
  /// For DELETE: [payload] can be null.
  Future<void> logChange({
    required String tableName,
    required String recordId,
    required String operation,
    Map<String, dynamic>? payload,
  }) async {
    final meta = _cachedMeta ?? await _getSyncMeta();
    if (!meta.syncEnabled) return; // No-op if sync disabled

    final db = await _dbService.database;
    await db.insert('sync_log', {
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
  // PUSH (local → Supabase)
  // ═══════════════════════════════════════

  // [FIX: Gemini #4] Process sync_log in strict chronological order
  // instead of grouping by table, to preserve FK dependency ordering
  // (e.g., tags must exist before task_tags that reference them).
  Future<SyncResult> push() async {
    if (_isSyncing) return SyncResult.skipped;
    _isSyncing = true;

    try {
      final meta = await _getSyncMeta();
      if (!meta.syncEnabled) return SyncResult.disabled;

      final db = await _dbService.database;
      final pending = await db.query(
        'sync_log',
        where: 'synced = 0',
        orderBy: 'created_at ASC',
      );

      if (pending.isEmpty) return SyncResult.nothingToPush;

      // Process each entry in chronological order (NOT grouped by table)
      for (final entry in pending) {
        await _pushEntry(entry, meta.userId!);
      }

      // Mark all as synced
      final ids = pending.map((r) => r['id']).toList();
      await db.rawUpdate(
        'UPDATE sync_log SET synced = 1 WHERE id IN (${ids.join(",")})',
      );

      await _updateSyncMeta(lastPushAt: DateTime.now());
      return SyncResult.success;
    } catch (e) {
      debugPrint('[Sync] Push failed: $e');
      return SyncResult.error;
    } finally {
      _isSyncing = false;
    }
  }

  /// Full push — initial sync. Pushes ALL local data via bulk upsert.
  // [FIX: Gemini #5] Use bulk upsert instead of individual network requests.
  Future<void> fullPush() async {
    final db = await _dbService.database;
    final meta = await _getSyncMeta();

    // Bulk upsert all tasks
    final tasks = await db.query(AppConstants.tasksTable);
    if (tasks.isNotEmpty) {
      final remoteTasks = tasks.map((t) => _localTaskToRemote(t, meta.userId!)).toList();
      await _supabase.from('tasks').upsert(remoteTasks);
    }

    // Bulk upsert all tags
    final tags = await db.query(AppConstants.tagsTable);
    if (tags.isNotEmpty) {
      final remoteTags = tags.map((t) => _localTagToRemote(t, meta.userId!)).toList();
      await _supabase.from('tags').upsert(remoteTags);
    }

    // Bulk upsert all task_tags
    // [FIX: Gemini #2, Codex #2] Strip local-only fields, add user_id
    final taskTags = await db.query(AppConstants.taskTagsTable);
    if (taskTags.isNotEmpty) {
      final remoteTT = taskTags.map((tt) => _localTaskTagToRemote(tt, meta.userId!)).toList();
      await _supabase.from('task_tags').upsert(remoteTT);
    }

    await _updateSyncMeta(lastPushAt: DateTime.now());
  }

  // ═══════════════════════════════════════
  // PULL (Supabase → local)
  // ═══════════════════════════════════════

  Future<SyncResult> pull() async {
    if (_isSyncing) return SyncResult.skipped;
    _isSyncing = true;

    try {
      final meta = await _getSyncMeta();
      if (!meta.syncEnabled) return SyncResult.disabled;

      final since = meta.lastPullAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = await _dbService.database;

      // Pull tasks updated since last pull
      final remoteTasks = await _supabase
          .from('tasks')
          .select()
          .gt('updated_at', since.toIso8601String())
          .order('updated_at');

      for (final remote in remoteTasks) {
        await _mergeTask(db, remote);
      }

      // Pull tags updated since last pull
      final remoteTags = await _supabase
          .from('tags')
          .select()
          .gt('updated_at', since.toIso8601String())
          .order('updated_at');

      for (final remote in remoteTags) {
        await _mergeTag(db, remote);
      }

      // [FIX: Codex #6, Gemini #7] Pull ALL task_tags since last pull,
      // not just those for changed tasks. Remote tag association changes
      // don't update the parent task's updated_at.
      await _pullTaskTags(db, since);

      await _updateSyncMeta(lastPullAt: DateTime.now());
      return SyncResult.success;
    } catch (e) {
      debugPrint('[Sync] Pull failed: $e');
      return SyncResult.error;
    } finally {
      _isSyncing = false;
    }
  }

  /// [FIX: Gemini #3, Codex #5, Gemini #5] Union-merge for task_tags.
  /// Instead of delete-all-reinsert, we:
  /// 1. Check for pending local ops — if any, skip merge (push-first)
  /// 2. Otherwise, add remote-only rows (never delete local-only rows)
  Future<void> _pullTaskTags(Database db, DateTime since) async {
    // Fetch full remote task_tags set for this user
    final remoteAll = await _supabase
        .from('task_tags')
        .select('task_id, tag_id');

    // Check for pending local task_tag ops
    final pendingOps = await db.query(
      'sync_log',
      where: "synced = 0 AND table_name = 'task_tags'",
    );

    if (pendingOps.isNotEmpty) {
      // Local has unpushed tag changes — skip merge, let push go first
      debugPrint('[Sync] Skipping task_tags merge: ${pendingOps.length} pending local ops');
      return;
    }

    // Get current local task_tags
    final localAll = await db.query(AppConstants.taskTagsTable);
    final localSet = localAll
        .map((r) => '${r['task_id']}_${r['tag_id']}')
        .toSet();

    // Union-merge: add remote-only rows, keep local-only rows
    for (final remote in remoteAll) {
      final key = '${remote['task_id']}_${remote['tag_id']}';
      if (!localSet.contains(key)) {
        // [FIX: Gemini #2] Include created_at to satisfy NOT NULL constraint
        await db.insert(AppConstants.taskTagsTable, {
          'task_id': remote['task_id'],
          'tag_id': remote['tag_id'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }

    // Remove local rows that were deleted remotely (not in remote set)
    final remoteSet = remoteAll
        .map((r) => '${r['task_id']}_${r['tag_id']}')
        .toSet();
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
  // REALTIME (Supabase → local, live)
  // ═══════════════════════════════════════

  // [FIX: Codex #7] Takes userId as parameter instead of reading from cache
  // [FIX: Gemini #7, Codex #6] Subscribes to task_tags changes too
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
          callback: (payload) => _onRemoteChange('tasks', payload),
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
          callback: (payload) => _onRemoteChange('tags', payload),
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
          callback: (payload) => _onRemoteChange('task_tags', payload),
        )
        .subscribe();
  }

  Future<void> _onRemoteChange(String table, PostgresChangePayload payload) async {
    // Debounce rapid changes into a single pull
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () => pull());
  }

  void _listenForConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        push().then((_) => pull());
      }
    });
  }

  // ═══════════════════════════════════════
  // MERGE LOGIC (Last-Write-Wins)
  // ═══════════════════════════════════════

  Future<void> _mergeTask(Database db, Map<String, dynamic> remote) async {
    final localResult = await db.query(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [remote['id']],
    );

    if (localResult.isEmpty) {
      await db.insert(AppConstants.tasksTable, _remoteTaskToLocal(remote));
      return;
    }

    final local = localResult.first;
    final localUpdated = local['updated_at'] as int? ?? 0;
    final remoteUpdated = DateTime.parse(remote['updated_at']).millisecondsSinceEpoch;

    // [FIX: Gemini #8, Codex #9] On equal timestamps, prefer remote
    // (remote is more likely to be from MCP/Claude, which is additive)
    if (remoteUpdated >= localUpdated) {
      await db.update(
        AppConstants.tasksTable,
        _remoteTaskToLocal(remote),
        where: 'id = ?',
        whereArgs: [remote['id']],
      );
    }
  }

  Future<void> _mergeTag(Database db, Map<String, dynamic> remote) async {
    final localResult = await db.query(
      AppConstants.tagsTable,
      where: 'id = ?',
      whereArgs: [remote['id']],
    );

    if (localResult.isEmpty) {
      await db.insert(AppConstants.tagsTable, _remoteTagToLocal(remote));
      return;
    }

    final local = localResult.first;
    final localUpdated = local['updated_at'] as int? ?? 0;
    final remoteUpdated = DateTime.parse(remote['updated_at']).millisecondsSinceEpoch;

    if (remoteUpdated >= localUpdated) {
      await db.update(
        AppConstants.tagsTable,
        _remoteTagToLocal(remote),
        where: 'id = ?',
        whereArgs: [remote['id']],
      );
    }
  }

  // ═══════════════════════════════════════
  // TYPE CONVERSIONS
  // ═══════════════════════════════════════

  String? _epochToIso(int? epochMs) {
    if (epochMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs).toUtc().toIso8601String();
  }

  int? _isoToEpoch(String? iso) {
    if (iso == null) return null;
    return DateTime.parse(iso).millisecondsSinceEpoch;
  }

  // [FIX: Codex #1] depth removed — not persisted locally
  Map<String, dynamic> _remoteTaskToLocal(Map<String, dynamic> remote) {
    return {
      'id': remote['id'],
      'title': remote['title'],
      'completed': (remote['completed'] == true) ? 1 : 0,
      'created_at': _isoToEpoch(remote['created_at']),
      'completed_at': _isoToEpoch(remote['completed_at']),
      'updated_at': _isoToEpoch(remote['updated_at']),
      'parent_id': remote['parent_id'],
      'position': remote['position'],
      'is_template': (remote['is_template'] == true) ? 1 : 0,
      'due_date': _isoToEpoch(remote['due_date']),
      'is_all_day': (remote['is_all_day'] == true) ? 1 : 0,
      'start_date': _isoToEpoch(remote['start_date']),
      'notification_type': remote['notification_type'],
      'notification_time': _isoToEpoch(remote['notification_time']),
      'deleted_at': _isoToEpoch(remote['deleted_at']),
      'notes': remote['notes'],
      'position_before_completion': remote['position_before_completion'],
    };
  }

  Map<String, dynamic> _remoteTagToLocal(Map<String, dynamic> remote) {
    return {
      'id': remote['id'],
      'name': remote['name'],
      'color': remote['color'],
      'created_at': _isoToEpoch(remote['created_at']),
      'updated_at': _isoToEpoch(remote['updated_at']),
      'deleted_at': _isoToEpoch(remote['deleted_at']),
    };
  }

  // [FIX: Codex #1] depth removed — not persisted locally
  Map<String, dynamic> _localTaskToRemote(Map<String, dynamic> local, String userId) {
    return {
      'id': local['id'],
      'user_id': userId,
      'title': local['title'],
      'completed': (local['completed'] as int) == 1,
      'created_at': _epochToIso(local['created_at'] as int),
      'completed_at': _epochToIso(local['completed_at'] as int?),
      'updated_at': _epochToIso(local['updated_at'] as int?),
      'parent_id': local['parent_id'],
      'position': local['position'],
      'is_template': (local['is_template'] as int?) == 1,
      'due_date': _epochToIso(local['due_date'] as int?),
      'is_all_day': (local['is_all_day'] as int?) == 1,
      'start_date': _epochToIso(local['start_date'] as int?),
      'notification_type': local['notification_type'],
      'notification_time': _epochToIso(local['notification_time'] as int?),
      'deleted_at': _epochToIso(local['deleted_at'] as int?),
      'notes': local['notes'],
      'position_before_completion': local['position_before_completion'],
    };
  }

  Map<String, dynamic> _localTagToRemote(Map<String, dynamic> local, String userId) {
    return {
      'id': local['id'],
      'user_id': userId,
      'name': local['name'],
      'color': local['color'],
      'created_at': _epochToIso(local['created_at'] as int),
      'updated_at': _epochToIso(local['updated_at'] as int?),
      'deleted_at': _epochToIso(local['deleted_at'] as int?),
    };
  }

  // [FIX: Gemini #2, Codex #2] Explicit task_tags conversion.
  // Strips local-only columns (created_at), adds user_id.
  Map<String, dynamic> _localTaskTagToRemote(Map<String, dynamic> local, String userId) {
    return {
      'task_id': local['task_id'],
      'tag_id': local['tag_id'],
      'user_id': userId,
      'created_at': _epochToIso(local['created_at'] as int),
    };
  }

  // ═══════════════════════════════════════
  // PUSH ENTRY PROCESSING
  // ═══════════════════════════════════════

  // [FIX: Gemini #4] Process one sync_log entry at a time in chronological order
  // [FIX: Codex #10] Convert missing local rows to DELETE instead of silently dropping
  Future<void> _pushEntry(Map<String, dynamic> entry, String userId) async {
    final table = entry['table_name'] as String;
    final operation = entry['operation'] as String;
    final recordId = entry['record_id'] as String;
    final payload = entry['payload'] != null
        ? jsonDecode(entry['payload'] as String) as Map<String, dynamic>
        : null;

    switch (operation) {
      case 'INSERT':
      case 'UPDATE':
        if (table == 'task_tags' && payload != null) {
          await _supabase.from(table).upsert({
            'task_id': payload['task_id'],
            'tag_id': payload['tag_id'],
            'user_id': userId,
            'created_at': _epochToIso(payload['created_at'] as int?) ??
                DateTime.now().toUtc().toIso8601String(),
          });
        } else if (table == 'tasks') {
          final db = await _dbService.database;
          final local = await db.query(
            AppConstants.tasksTable,
            where: 'id = ?',
            whereArgs: [recordId],
          );
          if (local.isNotEmpty) {
            await _supabase.from(table).upsert(
              _localTaskToRemote(local.first, userId),
            );
          } else {
            // [FIX: Codex #10] Row was deleted locally — propagate deletion
            await _supabase.from(table).delete().eq('id', recordId);
          }
        } else if (table == 'tags') {
          final db = await _dbService.database;
          final local = await db.query(
            AppConstants.tagsTable,
            where: 'id = ?',
            whereArgs: [recordId],
          );
          if (local.isNotEmpty) {
            await _supabase.from(table).upsert(
              _localTagToRemote(local.first, userId),
            );
          } else {
            await _supabase.from(table).delete().eq('id', recordId);
          }
        }
        break;
      case 'DELETE':
        if (table == 'task_tags') {
          final parts = recordId.split('_');
          if (parts.length == 2) {
            await _supabase.from(table)
                .delete()
                .eq('task_id', parts[0])
                .eq('tag_id', parts[1]);
          }
        } else {
          await _supabase.from(table).delete().eq('id', recordId);
        }
        break;
    }
  }

  // ═══════════════════════════════════════
  // INTERNAL HELPERS
  // ═══════════════════════════════════════

  void _schedulePush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () => push());
  }

  Future<SyncMeta> _getSyncMeta() async {
    final db = await _dbService.database;
    final result = await db.query('sync_meta', where: 'id = 1');
    if (result.isEmpty) {
      return SyncMeta();
    }
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

  Future<void> _updateSyncMeta({
    bool? syncEnabled,
    String? userId,
    DateTime? lastPushAt,
    DateTime? lastPullAt,
  }) async {
    final db = await _dbService.database;
    final updates = <String, dynamic>{};
    if (syncEnabled != null) updates['sync_enabled'] = syncEnabled ? 1 : 0;
    if (userId != null) updates['user_id'] = userId;
    if (lastPushAt != null) updates['last_push_at'] = lastPushAt.millisecondsSinceEpoch;
    if (lastPullAt != null) updates['last_pull_at'] = lastPullAt.millisecondsSinceEpoch;

    await db.update('sync_meta', updates, where: 'id = 1');
    _cachedMeta = null; // Invalidate cache
  }
}

enum SyncResult {
  success,
  nothingToPush,
  skipped,     // already syncing
  disabled,    // sync not enabled
  error,
}

class SyncMeta {
  final String? userId;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;
  final bool syncEnabled;

  SyncMeta({this.userId, this.lastPushAt, this.lastPullAt, this.syncEnabled = false});
}
```

---

## 5. Integration Points

### Where to call `SyncService.logChange()`

Add one line after each DB write in existing services. **Every write must also set `updated_at`.**

[FIX: Gemini #1, Codex #3] All examples below include `updated_at` in payloads.
[FIX: Gemini #6, Codex #4] Complete list of ALL write sites, verified against actual code.

#### TaskService (15 write sites)

```dart
// In createTask(), after db.insert():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: task.id,
  operation: 'INSERT', payload: task.toMap(),
);

// In createMultipleTasks(), after each txn.insert():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: task.id,
  operation: 'INSERT', payload: task.toMap(),
);

// In toggleTaskCompletion(), after db.update():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: task.id,
  operation: 'UPDATE',
  payload: {
    'completed': task.completed ? 0 : 1,
    'completed_at': ...,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  },
);

// In uncompleteTask(), after txn.update():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: taskId,
  operation: 'UPDATE',
  payload: {
    'completed': 0, 'completed_at': null,
    'position': restoredPosition,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  },
);

// In updateTask(), after db.update():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: taskId,
  operation: 'UPDATE', payload: changedFields,
  // changedFields must include 'updated_at'
);

// In updateTaskTitle(), after db.update():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: taskId,
  operation: 'UPDATE',
  payload: {
    'title': newTitle,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  },
);

// In updateTaskParent(), after txn.update():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: taskId,
  operation: 'UPDATE',
  payload: {
    'parent_id': newParentId, 'position': newPosition,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  },
);
// NOTE: _reindexSiblings also updates positions — log each affected task

// In softDeleteTask(), after txn.update():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: taskId,
  operation: 'UPDATE',
  payload: {
    'deleted_at': DateTime.now().millisecondsSinceEpoch,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  },
);

// In restoreTask(), after txn.update():
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: taskId,
  operation: 'UPDATE',
  payload: {
    'deleted_at': null,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  },
);

// In deleteTaskWithChildren(), after txn.delete():
// Log DELETE for parent and each descendant
await SyncService.instance.logChange(
  tableName: 'tasks', recordId: taskId,
  operation: 'DELETE',
);

// In permanentlyDeleteTask() — delegates to deleteTaskWithChildren
// (no additional logging needed)

// In emptyTrash(), after txn.delete():
// Log DELETE for each permanently removed task
for (final task in deletedTasks) {
  await SyncService.instance.logChange(
    tableName: 'tasks', recordId: task['id'] as String,
    operation: 'DELETE',
  );
}

// In cleanupExpiredDeletedTasks() and cleanupOldDeletedTasks():
// Log DELETE for each cleaned-up task
for (final task in expiredTasks) {
  await SyncService.instance.logChange(
    tableName: 'tasks', recordId: task['id'] as String,
    operation: 'DELETE',
  );
}
```

#### TagService (3 write sites)

```dart
// In createTag(), after db.insert():
await SyncService.instance.logChange(
  tableName: 'tags', recordId: tag.id,
  operation: 'INSERT',
  payload: {
    'id': tag.id, 'name': tag.name, 'color': tag.color,
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  },
);

// In addTagToTask(), after db.insert():
await SyncService.instance.logChange(
  tableName: 'task_tags', recordId: '${taskId}_${tagId}',
  operation: 'INSERT',
  payload: {
    'task_id': taskId, 'tag_id': tagId,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  },
);

// In removeTagFromTask(), after db.delete():
await SyncService.instance.logChange(
  tableName: 'task_tags', recordId: '${taskId}_${tagId}',
  operation: 'DELETE',
);
```

### App initialization (main.dart)

```dart
// Add after existing init, before runApp:
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);
await SyncService.instance.initialize();
```

### Build with env vars

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJ...
```

---

## 6. Conflict Resolution: Last-Write-Wins (LWW)

| Scenario | Resolution |
|----------|------------|
| Claude creates task remotely | Pull inserts it locally |
| User edits locally offline, Claude edits same task | Newer `updated_at` wins |
| User soft-deletes, Claude edits remotely | Newer timestamp wins |
| User creates task offline | Push inserts on reconnect |
| Equal timestamps | Remote wins (prefer MCP/Claude additive edits) |

**Why LWW is sufficient:** Single primary user. Claude edits additive. Conflicts rare. Stakes low. Future path: CRDT (sync_log already records operations).

**Timestamp precision:** Local uses epoch milliseconds. Supabase uses microsecond TIMESTAMPTZ. Comparison truncates to milliseconds. Sub-millisecond collisions are theoretically possible but practically irrelevant for a single-user app. [FIX: Gemini #8, Codex #9]

---

## 7. Offline Behavior

| State | Behavior |
|-------|----------|
| Online | Changes logged + pushed after 2s debounce |
| Offline | Changes logged only. App works normally. |
| Reconnect | push() then pull() triggered automatically |
| Supabase paused (free tier) | Same as offline. ~60s wakeup on first request. |

---

## 8. Data NOT Synced (local-only)

[FIX: Codex #11] Rationale documented for each exclusion.

| Table | Reason |
|-------|--------|
| `user_settings` | Device-specific preferences (timezone, notification defaults, quiet hours). Multi-device sync is a future consideration — would require separating device-level settings (e.g., `notificationsEnabled`) from user-level settings (e.g., `use24HourTime`). |
| `task_reminders` | Tied to local notification system. Each device schedules its own reminders. |
| `quiz_responses` | Onboarding state. Low-stakes — retaking the quiz on a new device is acceptable UX. |
| `brain_dump_drafts` | Ephemeral by design. Drafts are device-local scratch space. |
| `api_usage_log` | Per-device cost tracking. Aggregation across devices would require a different schema. |

---

## 9. Security Notes

- **RLS at database level** — user A cannot see user B's data even with server bugs
- **Supabase anon key safe in app** — only grants access through RLS policies
- **Auth token** — platform-native secure storage (Android Keystore)
- **No PII in task tables** — email lives in auth.users only
- **[FIX: Codex #12] Auth state listener** — sync is disabled and meta cleared on sign-out to prevent cross-user data leakage

---

## 10. Migration Checklist

1. [ ] Add `supabase_flutter` to pubspec.yaml
2. [ ] Create database migration v12 (sync_log, sync_meta, updated_at columns)
3. [ ] Add `updated_at` to all TaskService/TagService write methods
4. [ ] Implement SyncService (this spec)
5. [ ] Wire logChange() into TaskService (15 write sites)
6. [ ] Wire logChange() into TagService (3 write sites)
7. [ ] Add sync toggle to Settings UI
8. [ ] Add Supabase Auth flow (Google OAuth recommended)
9. [ ] Add auth state listener for sign-out handling
10. [ ] Write unit tests (mock Supabase client, in-memory SQLite)
11. [ ] Create Supabase project and run schema SQL (Section 3)
12. [ ] Test: create task locally → appears in Supabase → Claude reads it

---

## 11. Review Changelog (v1.0 → v2.0)

All changes traced to findings from Codex and Gemini code reviews.

| Fix | Finding | Section | Change |
|-----|---------|---------|--------|
| Remove `depth` from sync surface | Codex #1 (CRITICAL) | 3, 4 | Removed from Supabase schema, `_remoteTaskToLocal`, `_localTaskToRemote` |
| Add `created_at` to remote `task_tags` | Gemini #2, Codex #2 (CRITICAL) | 3, 4 | Added column to Supabase schema, added `_localTaskTagToRemote` converter, fixed `_pullTaskTags` merge inserts |
| Require `updated_at` on all local writes | Gemini #1, Codex #3 (CRITICAL) | 2, 5 | Added service write requirement, updated all integration point examples |
| Complete integration points list | Gemini #6, Codex #4 (HIGH) | 5 | Expanded from 5 to 15 TaskService sites + 3 TagService sites |
| Union-merge for `task_tags` | Gemini #3, Codex #5 (HIGH) | 4 | Replaced delete-all-reinsert with union-merge + pending-check |
| Subscribe to `task_tags` realtime | Gemini #7, Codex #6 (HIGH) | 4 | Added third subscription in `_subscribeToRemoteChanges` |
| Pull `task_tags` independently | Codex #6 (HIGH) | 4 | `_pullTaskTags` fetches full remote set, not just changed-task subset |
| Process push chronologically | Gemini #4 (HIGH) | 4 | Removed `_groupByTable`, process sync_log entries one by one |
| Bulk upsert in `fullPush` | Gemini #5 (HIGH) | 4 | Batch upsert lists instead of individual network calls |
| Add UPDATE policy for `task_tags` | Codex #8 (HIGH) | 3 | Added UPDATE policy, added `WITH CHECK` to all UPDATE policies |
| Fix `enableSync()` cache bug | Codex #7 (MEDIUM) | 4 | `_subscribeToRemoteChanges` takes `userId` as parameter |
| Convert missing rows to DELETE on push | Codex #10 (MEDIUM) | 4 | `_pushEntry` propagates deletion instead of silently skipping |
| Handle auth/user switching | Codex #12 (MEDIUM) | 4, 9 | Added auth state listener, verify user on initialize, clear meta on sign-out |
| Document local-only rationale | Codex #11 (MEDIUM) | 8 | Added reasoning for each excluded table |
| LWW tie-breaking: prefer remote | Gemini #8, Codex #9 (LOW) | 4, 6 | Changed `>` to `>=` in merge logic, documented rationale |
| Realtime filter API verified | Codex #13 (LOW) | — | Confirmed `PostgresChangeFilter` constructor matches SDK ^2.8.0 |
