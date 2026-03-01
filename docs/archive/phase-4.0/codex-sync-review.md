# Sync Layer Spec Review — Codex

**Spec under review:** `docs/specs/sync-layer-spec.md`
**Reviewer:** Codex
**Date:** 2026-02-27

---

## Instructions

Please review the sync layer specification at `docs/specs/sync-layer-spec.md` and record ALL findings in THIS document. Do not modify any other files.

For context, the app's core API contract is documented in `CORE_API.md` at project root. The existing database service is at `pin_and_paper/lib/services/database_service.dart`. The existing task service is at `pin_and_paper/lib/services/task_service.dart`. The existing tag service is at `pin_and_paper/lib/services/tag_service.dart`.

### What to look for

1. **Logic bugs** — Are there race conditions, edge cases, or incorrect assumptions in the merge/push/pull logic?
2. **Data integrity risks** — Could any scenario lead to data loss, duplication, or corruption?
3. **LWW merge gaps** — Is `updated_at` comparison sufficient? What about sub-millisecond collisions, or cases where the sync_log payload is stale by the time push runs?
4. **The delete-all-then-reinsert pattern** in `_mergeTaskTags` — Is this safe under concurrent push/pull?
5. **Tables excluded from sync** — `user_settings`, `task_reminders`, `quiz_responses` are local-only. Should any of these sync for multi-device?
6. **`_pushTable` re-reads local DB** instead of using the sync_log payload — Is this always correct when multiple edits queue up?
7. **Missing integration points** — Are there DB write call sites in the existing services that the spec fails to mention?
8. **Schema mismatches** — Does the Supabase schema correctly mirror all local columns? Any type conversion issues?
9. **Supabase SDK usage** — Are the realtime subscription, RLS policy, and auth patterns correct for `supabase_flutter ^2.8.0`?
10. **Anything else** — Security, performance, error handling, offline edge cases, etc.

### How to report

Use the sections below. For each finding, rate severity:
- **CRITICAL** — Must fix before implementation. Data loss or corruption risk.
- **HIGH** — Should fix. Incorrect behavior in realistic scenarios.
- **MEDIUM** — Worth discussing. Design tradeoff or minor edge case.
- **LOW** — Nit or suggestion. Won't cause problems but could be better.

---

## Findings

### Finding 1: Local schema mismatch — `depth` is not persisted locally

**Severity:** CRITICAL
**Location:** Section 3 (Supabase Schema), Section 4 (type conversions `_remoteTaskToLocal` / `_localTaskToRemote`), Section 2 (migration v12)
**Description:** Local SQLite does not persist `depth` (Task.toMap omits it; DB schema has no `depth` column). The spec’s remote schema requires `depth NOT NULL`, and the merge/convert helpers read/write `depth` to local rows. That will fail inserts/updates on pull, and upserts may send null `depth` to Supabase.
**Suggested fix:** Either (a) remove `depth` from the sync surface and compute it locally only, or (b) add `depth` to local schema, keep it updated on all hierarchy operations, and ensure it’s present in all sync payloads.

---

### Finding 2: `task_tags` schema mismatch + `created_at` handling

**Severity:** HIGH
**Location:** Section 3 (Supabase Schema), Section 4 (`_mergeTaskTags`, `fullPush`)
**Description:** Local `task_tags` rows include `created_at` (TagService inserts it). The spec’s remote `task_tags` table does not define `created_at`, yet `fullPush()` upserts `...tt` (includes all local columns). That will be rejected by PostgREST. Conversely, `_mergeTaskTags()` inserts only `task_id` and `tag_id`; if local `task_tags.created_at` is NOT NULL, local insert will fail.
**Suggested fix:** Align schemas and conversions. Either add `created_at` (and optionally `updated_at`) to remote `task_tags` and include it in conversions, or strip `created_at` from push/pull and make the local column nullable with a default.

---

### Finding 3: `updated_at` is never updated locally

**Severity:** HIGH
**Location:** Section 2 (migration v12), Section 6 (LWW)
**Description:** The spec relies on `updated_at` for LWW, but TaskService/TagService never set `updated_at` on local writes. This makes local updates appear stale, and pull can overwrite unsynced local changes. It can also send `updated_at = null` to Supabase, violating NOT NULL constraints.
**Suggested fix:** Add `updated_at` to local models and update it on every write (insert/update/soft-delete/tag edits). Prefer a centralized helper or DB trigger; ensure `updated_at` is set before `logChange()`.

---

### Finding 4: Missing sync logging for several write paths

**Severity:** HIGH
**Location:** Section 5 (Integration Points)
**Description:** The spec lists only a subset of write call sites. Current code includes additional DB mutations that won’t be logged, so remote will diverge. Examples: `updateTaskTitle`, `createMultipleTasks`, `uncompleteTask`, `restoreTask`, `deleteTaskWithChildren`, `permanentlyDeleteTask`, `emptyTrash`, `cleanupExpiredDeletedTasks`, `cleanupOldDeletedTasks`, and task-tag mutations in `TaskProvider.updateTask()` via `TagProvider` (indirect writes).
**Suggested fix:** Audit all DB writes in `TaskService`, `TagService`, and cleanup flows in `DatabaseService`. Add `SyncService.logChange()` immediately after each write, including hard deletes and restores.

---

### Finding 5: `delete-all-then-reinsert` in `_mergeTaskTags` can clobber local changes

**Severity:** HIGH
**Location:** Section 4 (`_mergeTaskTags`)
**Description:** Pull deletes all local tag links for a task, then reinserts remote. If local has pending tag changes (logged but not yet pushed), pull will erase them. This violates “local-first” and can cause silent data loss under concurrent push/pull.
**Suggested fix:** Use per-row LWW for `task_tags` (add `updated_at` + `deleted_at` or soft deletes), or reconcile with sync_log by skipping merges when local has pending tag ops for the task, or merging by set-diff with conflict resolution.

---

### Finding 6: Remote tag changes won’t sync if task rows don’t change

**Severity:** HIGH
**Location:** Section 4 (pull logic), Section 4 (realtime), Section 5 (TagService)
**Description:** Pull only fetches `task_tags` for tasks updated since last pull, and realtime subscribes only to `tasks` and `tags`. Tag associations changed remotely (e.g., another device adds a tag) do not update task `updated_at`, so they will never be pulled.
**Suggested fix:** Subscribe to `task_tags` realtime changes, or add `updated_at` to `task_tags` and pull by that, or bump the parent task’s `updated_at` on tag changes (both local and remote).

---

### Finding 7: `enableSync()` never subscribes to realtime (cache invalidation bug)

**Severity:** MEDIUM
**Location:** Section 4 (`enableSync`, `_subscribeToRemoteChanges`)
**Description:** `enableSync()` calls `_updateSyncMeta(...)` which clears `_cachedMeta`, then immediately calls `_subscribeToRemoteChanges()`. That method reads `_cachedMeta?.userId`, so it will no-op and never subscribe on first enable.
**Suggested fix:** Pass `userId` directly into `_subscribeToRemoteChanges`, or re-fetch meta after `_updateSyncMeta` before subscribing.

---

### Finding 8: RLS policies and upsert mismatch for `task_tags`

**Severity:** HIGH
**Location:** Section 3 (RLS policies), Section 4 (`_pushTable`)
**Description:** `task_tags` has no UPDATE policy, but `_pushTable` uses `upsert` (INSERT … ON CONFLICT DO UPDATE). Without UPDATE permission, upsert will fail. Also `tasks_update`/`tags_update` policies lack `WITH CHECK`, allowing `user_id` mutation in updates.
**Suggested fix:** Add `UPDATE` policy for `task_tags`, and add `WITH CHECK (auth.uid() = user_id)` to update policies for all three tables.

---

### Finding 9: LWW tie/collision handling is incomplete

**Severity:** MEDIUM
**Location:** Section 6 (LWW), Section 4 (`_mergeTask`, `_mergeTag`)
**Description:** LWW uses millisecond precision and only applies remote when `remoteUpdated > localUpdated`. Equal timestamps (or sub-millisecond collisions across devices) will drop one write.
**Suggested fix:** Use `>=` plus a deterministic tiebreaker (e.g., device_id, operation id), or store a monotonic logical clock / version counter.

---

### Finding 10: `_pushTable` can silently drop updates

**Severity:** MEDIUM
**Location:** Section 4 (`_pushTable`, `push()`)
**Description:** For UPDATE on `tasks`/`tags`, `_pushTable` re-reads the local row and skips the upsert if not found, but the sync_log entry is still marked `synced = 1`. If a row was deleted or cleaned up, that update is silently lost and remote may remain stale.
**Suggested fix:** If local row is missing, convert to DELETE (if appropriate) or keep the entry unsynced and raise an error.

---

### Finding 11: Excluding `user_settings` and `quiz_responses` may break multi-device UX

**Severity:** MEDIUM
**Location:** Section 8 (Data NOT Synced)
**Description:** If multi-device is a goal, `user_settings` (time preferences, timezone, notification defaults) and `quiz_responses` (onboarding completion) are user-level state, not device-only. Keeping them local causes inconsistent behavior across devices.
**Suggested fix:** Clarify intended UX. If multi-device consistency is desired, sync these tables (or a curated subset) and handle device-specific overrides separately (e.g., reminders).

---

### Finding 12: Auth/user switching not handled

**Severity:** MEDIUM
**Location:** Section 4 (`sync_meta`, `initialize`, `enableSync`)
**Description:** `sync_meta.user_id` persists across sessions. If a user logs out and another logs in, sync may push/pull under the wrong user context unless the meta is cleared.
**Suggested fix:** On auth state change, clear `sync_meta` and disable sync, or bind sync state to the current auth user.

---

### Finding 13: Realtime filter API may not match `supabase_flutter ^2.8.0`

**Severity:** LOW
**Location:** Section 4 (Realtime subscription)
**Description:** The spec uses `PostgresChangeFilter` objects; the SDK often uses a filter string (`'user_id=eq.$userId'`). If the API surface differs in `^2.8.0`, subscriptions will fail silently.
**Suggested fix:** Verify against the official `supabase_flutter` 2.8.0 docs and adjust to the correct filter API.

---

## Summary

**Total findings:** 13
**Critical:** 1
**High:** 5
**Medium:** 5
**Low:** 1

**Overall assessment:**
High-risk as written. The core sync model (LWW on `updated_at`) is viable, but there are critical schema mismatches, missing write logging, and task-tag sync gaps that will break correctness and/or cause data loss. Fixing schema alignment, `updated_at` maintenance, and task-tag change propagation should be treated as prerequisites before implementation.
