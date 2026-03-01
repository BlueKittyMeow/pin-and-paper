# Sync Implementation Plan Review — Codex

**Document under review:** Implementation plan + sync-layer-spec.md v2.0
**Reviewer:** Codex
**Date:** 2026-03-01

---

## Instructions

We are about to implement full Supabase sync for Pin and Paper. The implementation plan and canonical spec are written — we need you to review the **proposed design** for logic bugs, edge cases, and gaps **before we start coding**.

Record ALL findings in THIS document. **Do not modify any other files.**

### Documents to review

Read these carefully — they contain the full design:

1. **`docs/specs/sync-layer-spec.md`** — Canonical spec (v2.0). Focus on:
   - **Section 4** (Sync Service API): `push()`, `pull()`, `fullPush()`, `_pushEntry()`, `_pullTaskTags()`, realtime subscriptions, connectivity handling
   - **Section 5** (Integration Points): All 15 TaskService + 3 TagService write sites
   - **Section 6** (LWW conflict resolution)
   - **Section 7** (Offline behavior)

2. **Implementation plan** (read inline below since it's in `.claude/plans/`):

   **Step 1:** Add `supabase_flutter: ^2.8.0` and `google_sign_in: ^6.2.0` to pubspec.yaml

   **Step 2:** Instrument TaskService — add `updated_at` and `logChange()` to all 14 write methods:
   - createTask, createMultipleTasks, toggleTaskCompletion, uncompleteTask, updateTask, updateTaskTitle, updateTaskParent, softDeleteTask, restoreTask, deleteTaskWithChildren, permanentlyDeleteTask (delegates), emptyTrash, cleanupExpiredDeletedTasks, cleanupOldDeletedTasks
   - Pattern: set `updated_at = DateTime.now().millisecondsSinceEpoch` in write map, call `SyncService.instance.logChange()` after write
   - For `updateTaskParent()`: log only the moved task's UPDATE (parent_id + position), let fullPush reconcile sibling positions

   **Step 3:** Instrument TagService — add `updated_at` and `logChange()` to 3 write methods:
   - createTag (INSERT), addTagToTask (INSERT task_tags), removeTagFromTask (DELETE task_tags)

   **Step 4:** Add network operations to existing SyncService (which already has local logic: logChange, merge, type conversions, preparePushEntry, pullTaskTags):
   - `push()` — chronological order, one entry at a time via `_pushEntry()`
   - `fullPush()` — bulk upsert all local data
   - `pull()` — fetch remote changes since lastPullAt, merge via existing mergeTask/mergeTag/pullTaskTags
   - `_pushEntry()` — uses existing `preparePushEntry()` then makes Supabase REST call
   - `_subscribeToRemoteChanges(userId)` — realtime on tasks, tags, task_tags
   - `_listenForConnectivity()` — on reconnect → push then pull
   - `_schedulePush()` — 2s debounce, called from logChange()
   - `initialize()`, `enableSync()`, `disableSync()`, `dispose()`
   - Auth state listener — on sign-out → disable sync, clear meta

   **Step 5:** Add `Supabase.initialize()` + `SyncService.instance.initialize()` to main.dart (wrapped in try/catch for offline startup)

   **Step 6:** AuthService — Google OAuth via `getOAuthSignInUrl()` + `launchUrl()` with copy/paste URL fallback for desktop

   **Step 7-8:** Settings UI sync toggle + UI refresh callback on pull

   **Additional fixes from review:**
   - Add `updatedAt` field to Task and Tag models (toMap/fromMap/copyWith)
   - Fix `preparePushEntry()` missing `recordId` in delete return (lines 410, 425)
   - Make tag conversion methods public

### Context files (read for reference)

- `pin_and_paper/lib/services/sync_service.dart` — Existing local logic (already implemented and tested)
- `pin_and_paper/lib/services/task_service.dart` — 14 write methods to instrument
- `pin_and_paper/lib/services/tag_service.dart` — 3 write methods to instrument
- `pin_and_paper/lib/models/task.dart` — Task model (needs updatedAt)
- `pin_and_paper/lib/models/tag.dart` — Tag model (needs updatedAt)
- `pin_and_paper/lib/main.dart` — App entry point

### What to look for

1. **Push logic bugs** — Is chronological push order sufficient? What happens if `_pushEntry()` fails mid-way (some entries pushed, some not)? Are all entries marked synced even if some failed?

2. **Pull logic bugs** — Could `pull()` overwrite a local change that hasn't been pushed yet? The LWW uses `>=` (remote wins on tie) — is this safe when local `updated_at` was just set by logChange?

3. **Transaction + logChange ordering** — Several TaskService methods use `db.transaction()`. The plan says to call `logChange()` after the transaction. Is there a race window where pull could see the DB change but logChange hasn't been called yet?

4. **updateTaskParent simplification** — The plan says "log only the moved task, let fullPush reconcile siblings." Could this cause position inconsistency on remote between pushes? What if another push happens before fullPush?

5. **Realtime + pull debounce** — Remote change triggers debounced pull (500ms). Could rapid MCP changes cause stale pulls? Is the debounce timer properly cancelled and restarted?

6. **Connectivity reconnect** — On reconnect, we push then pull. What if push fails but pull succeeds? Could pull then overwrite unpushed local changes?

7. **fullPush ordering** — fullPush upserts tasks, then tags, then task_tags. Should tags go before tasks (since task_tags reference both)? Actually, tasks and tags are independent, task_tags depends on both.

8. **Auth edge cases** — What if user signs in on one device but never enables sync? What if auth token expires mid-push?

9. **Model updatedAt gap** — If `updated_at` is only added to models but not to `createTask()` in the Task constructor, will `task.toMap()` emit a null `updated_at` for new tasks?

10. **Anything else** — Race conditions, data loss scenarios, performance, security.

### How to report

For each finding, rate severity:
- **CRITICAL** — Must fix before implementation. Data loss or corruption risk.
- **HIGH** — Should fix. Incorrect behavior in realistic scenarios.
- **MEDIUM** — Worth discussing. Design tradeoff or minor edge case.
- **LOW** — Nit or suggestion. Won't cause problems but could be better.

---

## Findings

### Finding 1: Pull can overwrite unpushed local changes (tasks/tags)

**Severity:** HIGH  
**Location:** Spec v2.0 Section 4 (pull + LWW), plan Step 4  
**Description:** The plan uses LWW with remote-wins-on-tie and does not mention guarding merges when there are pending local ops for the same task/tag (only task_tags has a pending-op guard). If local edits are queued but not pushed, a pull can overwrite them if remote `updated_at` is ahead (clock skew or concurrent edits).  
**Suggested fix:** Before merging a remote row, check sync_log for unsynced ops for that record and skip/defers merge, or use a conflict-aware LWW that considers local pending ops.

---

### Finding 2: Push failure handling is underspecified (risk of marking unsent entries as synced)

**Severity:** HIGH  
**Location:** Spec v2.0 Section 4 (push), plan Step 4  
**Description:** The plan doesn’t specify per-entry success handling. If `_pushEntry()` fails mid-stream, you must not mark later entries as synced. If the implementation marks all pending entries as synced after any failure, local changes are lost.  
**Suggested fix:** Mark only the entries that were successfully pushed. On failure, stop processing and keep remaining entries unsynced for retry.

---

### Finding 3: Transaction + logChange ordering can lose sync on crash

**Severity:** MEDIUM  
**Location:** Plan Step 2 (instrumentation), “Transaction + logChange ordering”  
**Description:** The plan mandates `logChange()` after transactions. If the app crashes between commit and logChange, the local change is permanent but never queued for sync.  
**Suggested fix:** Consider inserting the sync_log row inside the same transaction as the data write (or immediately after commit but with a retry/repair mechanism on next startup).

---

### Finding 4: updateTaskParent logs only moved task — sibling positions drift remotely

**Severity:** MEDIUM  
**Location:** Plan Step 2 (updateTaskParent note), Spec v2.0 Section 5  
**Description:** Logging only the moved task ignores sibling reindex updates. Until a fullPush, remote devices can show incorrect ordering. If a push occurs before fullPush, the remote state becomes inconsistent with local ordering.  
**Suggested fix:** Log updates for all reindexed siblings (or implement a server-side reindex and push a single “move” operation).

---

### Finding 5: Reconnect flow can pull after failed push and overwrite locals

**Severity:** HIGH  
**Location:** Spec v2.0 Section 4 (connectivity), plan Step 4  
**Description:** The plan says “push then pull” on reconnect but doesn’t specify error gating. If push fails and pull still runs, remote LWW merges can overwrite unpushed local edits.  
**Suggested fix:** Only run pull after a successful push, or ensure pull skips records with pending local ops.

---

### Finding 6: Realtime debounce + `_isSyncing` can drop a pull

**Severity:** MEDIUM  
**Location:** Spec v2.0 Section 4 (realtime debounce), plan Step 4  
**Description:** If a debounced pull fires while `_isSyncing` is true and returns `skipped`, there’s no guarantee another pull will be scheduled. This can leave the client stale until a future trigger.  
**Suggested fix:** Track a `pendingPull` flag and re-run pull once the current sync completes.

---

### Finding 7: New-task `updated_at` must be present in payloads

**Severity:** HIGH  
**Location:** Plan Step 2 + “Model updatedAt gap”  
**Description:** The plan adds `updatedAt` to models, but unless `createTask()`/`createTag()` set it on the model (or build payloads from DB row maps), `logChange()` for INSERT may omit `updated_at`. Remote upserts could then fail or use defaults, breaking LWW.  
**Suggested fix:** Ensure INSERT payloads always include `updated_at` (set on model before toMap, or build payload from the DB write map).

---

### Finding 8: Auth user mismatch on initialize is still a risk

**Severity:** HIGH  
**Location:** Plan Step 4 (auth state listener), Spec v2.0 Section 4 (sync_meta)  
**Description:** The plan mentions clearing meta on sign-out, but does not explicitly verify that `sync_meta.user_id` matches the current auth user on startup. If a different user logs in, sync could push/pull under the wrong user context.  
**Suggested fix:** On initialize, compare stored `user_id` with current auth user; if mismatched, disable sync and clear meta before any push/pull.
