# Sync Implementation Plan Review — Gemini

**Document under review:** Implementation plan + sync-layer-spec.md v2.0
**Reviewer:** Gemini
**Date:** 2026-03-01

---

## Instructions

We are about to implement full Supabase sync for Pin and Paper. The implementation plan and canonical spec are written — we need you to review the **proposed design** for logic bugs, edge cases, and gaps **before we start coding**.

Record ALL findings in THIS document. **Do not modify any other files.**

**IMPORTANT:** This is a **design review**, not a code review. The code hasn't been written yet. Focus on finding logic bugs, race conditions, and edge cases in the proposed approach. Read the spec and existing code to understand what exists vs. what's planned.

### Documents to review

Read these carefully — they contain the full design:

1. **`docs/specs/sync-layer-spec.md`** — Canonical spec (v2.0). Focus on:
   - **Section 4** (Sync Service API): Full push/pull/realtime implementation including `_pushEntry()`, `_pullTaskTags()`, `fullPush()`, connectivity handling
   - **Section 5** (Integration Points): All 18 write sites
   - **Section 6** (LWW conflict resolution)
   - **Section 7** (Offline behavior)

2. **The implementation approach** (summarized here since it's in `.claude/plans/`):

   The existing `SyncService` has local logic already tested (35 tests): `logChange()`, `mergeTask()`, `mergeTag()`, `pullTaskTags()`, `preparePushEntry()`, type conversions, `SyncMeta`. We are adding:

   - **Service instrumentation:** Every `db.insert/update/delete` in TaskService (14 methods) and TagService (3 methods) gets `updated_at = DateTime.now().millisecondsSinceEpoch` in the write map + `SyncService.instance.logChange()` after the write
   - **Network push:** Process sync_log entries chronologically (one at a time), each via `_pushEntry()` which calls existing `preparePushEntry()` then makes the actual Supabase REST call
   - **Network pull:** Fetch tasks/tags with `updated_at > lastPullAt`, merge via existing `mergeTask()`/`mergeTag()` (LWW with `>=`), then `pullTaskTags()` (union-merge with pending-ops check)
   - **Realtime:** Subscribe to tasks, tags, task_tags changes filtered by user_id. On change → debounced `pull()` (500ms)
   - **Connectivity:** `connectivity_plus` listener → on reconnect, `push()` then `pull()`
   - **Offline:** All sync is try/catch wrapped, never blocks UI, sync_log accumulates changes, retried on reconnect
   - **Auth:** `getOAuthSignInUrl()` + `launchUrl()` with copy/paste URL fallback for desktop
   - **fullPush:** On first sync enable, bulk upsert all local tasks → tags → task_tags
   - **updateTaskParent simplification:** Log only the moved task's UPDATE, not sibling reindex. `fullPush` reconciles

   **Known fixes to apply:**
   - Add `updatedAt` to Task/Tag models (toMap/fromMap/copyWith)
   - Fix `preparePushEntry()` returning `{'type': 'delete'}` without `recordId` (lines 410, 425 of sync_service.dart)

### Context files (read for reference)

- `pin_and_paper/lib/services/sync_service.dart` — Existing local logic (the foundation we're building on)
- `pin_and_paper/lib/services/task_service.dart` — Write methods to instrument
- `pin_and_paper/lib/services/tag_service.dart` — Write methods to instrument
- `pin_and_paper/lib/models/task.dart` — Task model
- `pin_and_paper/lib/models/tag.dart` — Tag model
- `pin_and_paper/lib/main.dart` — App entry point

---

## Findings

### Finding 1: `updateTaskParent` simplification causes remote position desync

**Severity:** CRITICAL
**Location:** Implementation Approach / `TaskService.updateTaskParent`
**Description:**
The plan states: "Log only the moved task's UPDATE, not sibling reindex. fullPush reconciles." This is a major logic bug. Sibling reindexing happens on every move/reorder via `_reindexSiblings`. If those sibling updates are not logged and pushed, the remote database will have incorrect `position` values for every other task in that list level. 

Other devices pulling the data will see the old, incorrect positions for the siblings, resulting in a broken or inconsistent task order. `fullPush` only runs when sync is first enabled, so it won't fix these ongoing desyncs.

**Suggested fix:**
Every affected task in `_reindexSiblings` must have its `updated_at` advanced and a `logChange()` entry created. To minimize network noise, consider a single bulk update/push for reindexed siblings if possible, or ensure the 2s debounce in `SyncService` handles the rapid individual pushes gracefully.

---

### Finding 2: Data loss risk due to local/server clock skew in `pull()`

**Severity:** CRITICAL
**Location:** Section 4, `SyncService.pull()`
**Description:**
The spec sets `lastPullAt = DateTime.now()` after a successful pull. It then uses this timestamp in the next pull's `.gt('updated_at', since)`. 

If the local device clock is ahead of the Supabase server clock (even by a few seconds), the `lastPullAt` cursor will be set to a future time relative to the server. Subsequent pulls will skip any changes made on the server between the server's actual time and the device's future-dated cursor.

**Suggested fix:**
Never use the local device clock for sync cursors. Instead, set `lastPullAt` to the maximum `updated_at` timestamp found in the records actually received from the server during that pull. This ensures the cursor is always anchored to the server's timeline.

---

### Finding 3: Lack of batching in `fullPush` creates scaling risk

**Severity:** HIGH
**Location:** Section 4, `SyncService.fullPush()`
**Description:**
`fullPush()` reads ALL local tasks/tags and sends them to Supabase in a single `upsert()` call per table. For a power user with 1,000+ tasks, this could result in a massive JSON payload that exceeds HTTP limits or causes the Supabase REST API/PostgreSQL to time out. 

**Suggested fix:**
Implement batching in `fullPush()`. Send records in chunks (e.g., 500 at a time) to ensure reliable delivery and avoid hitting payload size or timeout limits.

---

### Finding 4: Performance bottleneck in `push()` (Sequential REST calls)

**Severity:** HIGH
**Location:** Section 4, `SyncService.push()`
**Description:**
The `push()` method iterates through `sync_log` entries and awaits a separate `_pushEntry()` call for each. This results in N sequential network requests. If a user makes many rapid changes (e.g., reordering a long list or typing notes with auto-save), `push()` will be extremely slow and could trigger rate limiting.

**Suggested fix:**
Group pending changes by `record_id` and only push the latest state for each record. Additionally, use Supabase's bulk `upsert` capability to push multiple records in a single network request where possible.

---

### Finding 5: Race condition in `initialize()` timing

**Severity:** MEDIUM
**Location:** Section 4, `SyncService.initialize()`
**Description:**
The `initialize()` method calls `pull()` first and then `_subscribeToRemoteChanges()`. Any remote changes that occur during the pull or in the brief window before the subscription is established will be missed until the next connectivity change or app restart.

**Suggested fix:**
Establish the realtime subscriptions *before* performing the initial `pull()`. This ensures that any changes happening during the pull process are caught by the subscription listener.

---

### Finding 6: `getOAuthSignInUrl()` SDK mismatch

**Severity:** MEDIUM
**Location:** Implementation Approach / `AuthService`
**Description:**
The plan mentions using `getOAuthSignInUrl()` for the auth flow. While this method exists in the underlying `gotrue` library, it is not a top-level method in `supabase_flutter`. Using the standard `signInWithOAuth()` is the recommended Flutter pattern as it handles browser launching and deep links more natively.

**Suggested fix:**
Verify the required auth flow for Linux desktop. If a manual URL is needed for the copy/paste fallback, ensure the implementation correctly accesses the underlying `gotrue` client or uses the appropriate configuration in `signInWithOAuth`.

---

### Finding 7: Model classes missing `updatedAt` field

**Severity:** LOW
**Location:** `lib/models/task.dart`, `lib/models/tag.dart`
**Description:**
As noted in the instructions, the `Task` and `Tag` models do not yet have an `updatedAt` field. This will cause the `updated_at` value to be lost when converting between maps and objects, which will break the LWW comparison logic in `SyncService`.

**Suggested fix:**
Implement the planned fix: add `updatedAt` to both models and update `fromMap`, `toMap`, and `copyWith` accordingly.

---

## Summary

**Total findings:** 7
**Critical:** 2
**High:** 2
**Medium:** 2
**Low:** 1

**Overall assessment:**
The implementation plan provides a solid path forward, but the identified **critical logic bugs** regarding reordering and clock skew must be addressed before implementation begins. Failure to do so will result in a sync layer that appears to work in simple tests but loses data or desyncs in real-world multi-device usage. Correcting the performance bottlenecks in `push` and `fullPush` is also essential for a smooth user experience.
