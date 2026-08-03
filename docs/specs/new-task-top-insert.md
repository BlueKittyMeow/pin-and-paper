# Spec: New tasks appear at the top of the list

**Date:** 2026-08-02 · **Author:** Fable 5 · **Status:** Reviewed (Sonnet, PASS WITH CHANGES, amendments folded in) — ready to implement
**Bug:** Tasks created in the app appear at the *bottom* of the task list.

## Root cause

`TaskService.createTask` assigns `position = MAX(position) + 1` among active root
tasks (`task_service.dart:26-34`). The tree view's displayed order comes from
Dart-side sorts over the raw integer: `TaskProvider._sortTasks`
(`task_provider.dart:989-1014`, manual mode = ascending `position.compareTo`)
for roots and `task_hierarchy_provider.dart:26-28` (always ascending) for
children. Highest position = newest = sorted last. The SQL paths
(`getTaskHierarchy()` sort_key, `getFilteredTasks` DESC) are *not* what orders
the main tree — but they directly order `parent_selector_dialog.dart:83` and
must be made consistent, and the CTE's `printf('%05d')` corrupts ordering once
negative positions exist.

## Chosen approach: insert at top via `MIN(position) − 1`

New tasks take a position *below* the current minimum (going negative over time).
Single-row write, no sibling shifting, no sync-log churn (contrast the MCP
server's `shift_sibling_positions` pattern, criticized in
`docs/specs/fable-full-project-review.md`). No schema change: local `position`
is `INTEGER NOT NULL DEFAULT 0`, no CHECK (`database_service.dart:82`); Supabase
likewise (`docs/specs/supabase-schema.sql:14`). Drag-reorder already normalizes
sibling positions to `0..N-1` via `_reindexSiblings`
(`task_service.dart:1323-1369`, orders ASC then reassigns — order-preserving
with negatives), which harmlessly erases negatives.

## Changes (all in `pin_and_paper/lib/`)

1. **`services/task_service.dart` — `createTask` (~line 26):**
   replace the MAX query with
   `SELECT COALESCE(MIN(position), 1) - 1 AS next_position FROM tasks WHERE parent_id IS NULL AND deleted_at IS NULL`
   and use it directly. Update comments.

2. **`services/task_service.dart` — `createMultipleTasks` (~line 73):**
   batch must display top-most-first in given order, above existing tasks.
   Count approved suggestions first (`n`), query `MIN(position)` (call it `m`,
   default 1), start at `m − n` and increment per inserted task. First approved
   suggestion gets the smallest position → appears first. (Verified: last
   inserted gets `m−1 < m`, so the whole batch sits above existing tasks.)

3. **`services/task_service.dart` — `getTaskHierarchy` (lines 165, 175):**
   `printf('%05d', position)` mis-sorts negatives (SQLite pads including the
   sign: `-0010` sorts *after* `-0002` lexicographically). Replace **both**
   occurrences with `printf('%011d', position + 1000000000)` — non-negative,
   fixed-width, string order == numeric order.

4. **`services/task_service.dart` — `getFilteredTasks` (lines 280, 296, 307, 320, 329):**
   flip all five `ORDER BY tasks.position DESC` → `ASC`. Under the new
   semantics smallest position = newest; ASC keeps these newest-first and
   consistent with the tree view. (Directly fixes parent-selector dialog order.)

5. **`services/task_service.dart` — `getAllTasks` (~line 130):**
   flip `position DESC` → `ASC` and fix the comment. (Unused by UI; exercised
   by tests only.)

6. **Drag-reorder staleness fix (REQUIRED — review gap #4).**
   `onNodeAccepted` (`task_provider.dart:1100-1122`) passes the raw snapshot
   `details.targetNode.position` into `updateTaskParent`
   (`task_service.dart:696`), but the same-parent branch reindexes remaining
   siblings to `0..N-1` *before* using it — so a stale raw position lands the
   dragged task in the wrong slot. Today that only bites when positions are
   non-compact (soft-delete gaps); under MIN−1 it becomes the steady state
   (trace in review: drag X "above Y" with positions {−2,−1,0} → X lands at
   very top, not above Y).
   **Fix in the provider:** let `t` = index of the target node in (siblings of
   `newParentId`, sorted ascending by `position`, dragged task removed). Then
   `whenAbove → newPosition = t`; `whenBelow → newPosition = t + 1` (verified
   algebraically and by hand-trace in second review; the existing count-based
   `whenInside` path is correct as-is). Same computation for the cross-parent
   branch. No service-signature change.
   **Filtered-view guard (required):** when `_filterProvider.hasActiveFilters`,
   `_tasks` is the filtered subset, so compute `t` from a DB query for the true
   sibling list (siblings of `newParentId`, `deleted_at IS NULL`, ascending
   position, dragged task excluded) — extending the existing
   `needsDbQuery && hasActiveFilters` guard that `whenInside` already has
   (`task_provider.dart:1125-1137`) to `whenAbove`/`whenBelow`.

7. **Cosmetic while touching `updateTaskParent`:** same-parent Step 3 shift
   (`task_service.dart:743-748`) lacks the `AND id != ?` exclusion the
   cross-parent branch has (`:788-796`). Currently harmless (Step 4
   overwrites), but add the matching exclusion for symmetry.

## Explicitly out of scope

- MCP server create/insert logic (position 0 + shift-all). Follow-up: adopt
  MIN−1 there too.
- Sibling-shift sync gaps (review finding H-3) — separate fix.
- `search_service.dart:172` already ASC; `getRecentlyDeletedTasks` sort_key
  printf is dead code (final ORDER BY is `deleted_at DESC`) — both untouched.
- `_migrateToV4` backfill comment (`database_service.dart:577-595`) is
  version-gated legacy; optionally refresh its comment, nothing more.

## Invariants to preserve

- `updateTaskParent` same-parent and cross-parent flows: temporary
  `position: -1` sentinel is transaction-internal and excluded from reindex
  (verified); with change #6 the final order must be correct for arbitrary
  pre-existing negative positions.
- `uncompleteTask` restore (`task_service.dart:492-502`): plain `>=` integer
  comparison — works with negatives, unchanged.
- Sync payloads carry `position` as-is; a not-yet-updated device still using
  MAX+1 puts its own new tasks at the bottom until upgraded (acceptable,
  single-user).

## Tests

Known breakage to fix (enumerated by review — don't grep-and-hope):

- `test/services/task_service_soft_delete_test.dart:392-415` — hardcodes
  MAX+1 growth (0,1,2,3). Update expectations to MIN−1 (0,−1,−2,−3); the
  *point* of the test (soft-deleted tasks ignored in the calculation) must be
  preserved — task4 must get MIN−1 over non-deleted tasks only.
- `test/providers/task_provider_completed_hierarchy_test.dart:309-357` —
  "Multiple roots" assumes creation order == ascending position. Under MIN−1
  the later root sorts first; update the assertions (or creation order) to
  the new newest-first semantics.
- `test/services/task_service_test.dart:546-571` — still passes, but its
  "ordered by position DESC (newest first)" comment becomes wrong; update it.

New tests to add:

- create two tasks → second has smaller position; tree/provider order shows it first.
- `getTaskHierarchy` ordering correct with mixed negative/positive positions and nesting (exercises the printf fix).
- bulk create: approved suggestions appear in order at the top.
- `getFilteredTasks` returns smallest-position-first.
- **same-parent drag reorder with pre-existing negative positions** (guards change #6): with roots {−2,−1,0}, dragging the bottom task above the middle one must place it exactly there.
- **same-parent drag reorder while a tag filter is active** (guards the filtered-view DB-query guard in change #6).
- cross-parent move with negative source/destination positions.

**Env note:** run only the affected test files (`flutter test test/<file>`);
the 22 `flutter_js` date-parsing failures on Linux are a known missing-native-lib
issue, not regressions. No Android/desktop builds.
