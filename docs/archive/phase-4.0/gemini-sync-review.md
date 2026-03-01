# Sync Layer Spec Review — Gemini

**Spec under review:** `docs/specs/sync-layer-spec.md`
**Reviewer:** Gemini
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

**IMPORTANT:** Only report findings you have verified against the actual codebase files listed above. Do not speculate about code you haven't read. If you're unsure whether something exists, read the file first.

---

## Findings

### Finding 1: Local `updated_at` Column Never Advanced During Mutations

**Severity:** CRITICAL
**Location:** Sections 2 and 5 of `sync-layer-spec.md`
**Description:**
The spec adds an `updated_at` column to the `tasks` and `tags` tables and backfills it during migration. However, it fails to specify that `TaskService` and `TagService` must be updated to set `updated_at = DateTime.now()` during every local `INSERT` and `UPDATE`. 

Because the Supabase schema includes a trigger to auto-advance `updated_at` on the server, remote records will always have a newer timestamp than local records after the first remote edit. The LWW merge logic in `pull()` (`remoteUpdated > localUpdated`) will then incorrectly overwrite local changes with remote state, even if the local change happened later but didn't advance its own timestamp.

**Suggested fix:**
Update the code snippets in Section 5 to show that every database write in `TaskService` and `TagService` must include `updated_at: DateTime.now().millisecondsSinceEpoch` in the map.

---

### Finding 2: `task_tags` Merge/Push Schema Mismatches (Crashes)

**Severity:** CRITICAL
**Location:** Section 4, `_mergeTaskTags` and `fullPush` methods
**Description:**
There are two schema-related crashes in the `task_tags` sync logic:
1. **Pull Crash:** The local `task_tags` table (see `database_service.dart`) defines `created_at INTEGER NOT NULL`. The `_mergeTaskTags` method in the spec inserts remote junction rows into the local DB but omits the `created_at` field. This will trigger a `NotNullConstraintViolation` and crash the sync process.
2. **Push Crash:** The `fullPush` method sends the full local `task_tags` map to Supabase. This map includes the `created_at` column, which does not exist in the Supabase schema provided in Section 3. Supabase will reject the upsert with an "undefined column" error.

**Suggested fix:**
1. In `_mergeTaskTags`, add `'created_at': DateTime.now().millisecondsSinceEpoch` to the insert map.
2. In `fullPush` and `_pushTable`, explicitly remove the `created_at` key from the `task_tags` map before sending to Supabase, or update the Supabase schema to include it.

---

### Finding 3: `task_tags` Merge Blows Away Local-Only Changes (Data Loss)

**Severity:** HIGH
**Location:** Section 4, `pull()` and `_mergeTaskTags` methods
**Description:**
The `pull()` logic for tags is destructive. For every task changed remotely, it calls `_mergeTaskTags`, which deletes ALL local tag associations for that task and replaces them with the remote set. 

If a user adds a tag locally while offline, and then a remote change happens to the task title (e.g. via Claude MCP), the next `pull()` will see the task change and proceed to delete the locally-added tag because it hasn't been pushed to the server yet. Since `task_tags` has no `updated_at` column, there is no way for the merge logic to know which side is newer at the row level.

**Suggested fix:**
Perform a non-destructive merge for `task_tags`. Instead of a blind delete-all, compare local and remote junction rows. Or, more robustly, add an `updated_at` column to the `task_tags` table locally and remotely to allow proper LWW comparison for junction rows.

---

### Finding 4: Group-by-Table Push Breaks Foreign Key Constraints

**Severity:** HIGH
**Location:** Section 4, `push()` and `_groupByTable` methods
**Description:**
The `push()` method groups pending changes by table and then iterates through the groups. This destroys the relative chronological order of operations across different tables. 

For example, if a user creates a new tag and immediately associates it with a task, the `sync_log` contains `[INSERT tag, INSERT task_tag]`. If the grouping logic processes `task_tags` before `tags`, the remote `task_tags` insert will fail because the referenced `tag_id` does not yet exist in the Supabase `tags` table.

**Suggested fix:**
Remove the `_groupByTable` logic. Iterate through the `sync_log` in strict `created_at ASC` order, processing each operation one by one to ensure that dependency order (parent tasks before children, tags before associations) is preserved.

---

### Finding 5: Performance Bottleneck in `fullPush` and `pull` (N+1 Network Requests)

**Severity:** HIGH
**Location:** Section 4, `fullPush` and `pull` methods
**Description:**
The spec uses individual network requests for bulk operations:
1. `fullPush` iterates over every local task/tag and awaits a separate `upsert` call for each. For a user with 500 tasks, this is 500+ sequential network requests, which will be extremely slow and likely time out.
2. `pull` for `task_tags` performs a separate `.select()` query for every changed task ID.

**Suggested fix:**
1. In `fullPush`, use Supabase's bulk upsert capability: `await _supabase.from('tasks').upsert(allTasksInOneList)`.
2. In `pull`, fetch all relevant `task_tags` in a single query using the `.in_()` filter: `await _supabase.from('task_tags').select().in_('task_id', changedTaskIds)`.

---

### Finding 6: Missing Integration Points in `TaskService`

**Severity:** MEDIUM
**Location:** Section 5, "Where to call SyncService.logChange()"
**Description:**
The spec only lists 5 integration points for `TaskService`, but the service contains several other critical DB write methods that need sync coverage:
- `uncompleteTask`: Currently missing.
- `updateTaskTitle`: Currently missing.
- `restoreTask`: Currently missing.
- `permanentlyDeleteTask`: Currently missing.
- `emptyTrash`: Currently missing.
- `createMultipleTasks` (Bulk imports): Currently missing.
- `deleteTaskWithChildren`: Currently missing.

**Suggested fix:**
Expand the integration points list to cover all methods in `TaskService` and `TagService` that perform `db.insert`, `db.update`, or `db.delete` operations.

---

### Finding 7: Realtime Subscription Missing `task_tags`

**Severity:** MEDIUM
**Location:** Section 4, `_subscribeToRemoteChanges` method
**Description:**
The realtime subscription only listens for changes to the `tasks` and `tags` tables. Changes to `task_tags` made on another device will not trigger a local `pull()`. This means tag associations will not update in real-time until a task or tag record itself is also modified.

**Suggested fix:**
Add a third subscription in `_subscribeToRemoteChanges` for the `task_tags` table.

---

### Finding 8: Sub-millisecond Collisions in LWW Logic

**Severity:** LOW
**Location:** Section 4, `_mergeTask` and `_mergeTag` methods
**Description:**
The merge logic uses `remoteUpdated > localUpdated` comparison. Since local timestamps are stored as epoch milliseconds and Supabase uses `TIMESTAMPTZ` (microsecond precision), there is a risk of collision if two updates happen within the same millisecond. Additionally, if the timestamps are exactly equal, the local version wins by default, which might not be intended for remote-heavy workflows like MCP.

**Suggested fix:**
Consider using `>=` or a tie-breaker (like string comparison of record IDs) if timestamps are equal, although for a single-primary-user app, the current logic is likely "good enough."

---

## Summary

**Total findings:** 8
**Critical:** 2
**High:** 3
**Medium:** 2
**Low:** 1

**Overall assessment:**
The specification provides a solid architectural foundation but contains several **implementation-blocking bugs** and **data integrity risks**. The most critical issues are the failure to maintain the `updated_at` column locally (which will cause the LWW logic to overwrite local data) and the schema mismatches in `task_tags` that will lead to application crashes. Additionally, the performance of bulk sync operations needs to be improved by utilizing Supabase's batch APIs rather than looping over individual records. Once these issues are addressed, the spec will be ready for implementation.
