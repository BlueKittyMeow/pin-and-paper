# Phase 3.6A Review - v2

**Reviewer:** Codex  
**Date:** 2026-01-09  
**Status:** Draft

---

## Verification of Original Bugs

### Bug #1: Race conditions in async filter updates
**Status:** ⚠️ Partially Fixed

**Verification:**  
The operation-ID guard is in place and prevents stale results from overwriting `_tasks`. However, `setFilter` still mutates `_filterState` before the awaited queries and never reverts it on failure. If `_taskService.getFilteredTasks` throws (e.g., transient SQLite error), the UI shows the new filter bar even though the task list still holds old data. Users see “Work” active but the list is unfiltered.

**Remaining Concerns:**  
Defer assigning `_filterState` until after both queries succeed, or store a “pending” filter separately and revert on error. Also clear/rollback `_filterState` inside the catch block so the visible state matches actual results.

---

### Bug #2: Filtered queries ignore active/completed scope
**Status:** ✅ Fixed

**Verification:**  
`getFilteredTasks` now accepts `completed` and prepends `tasks.completed = ?` (plus `deleted_at IS NULL`) to every branch. Both active and completed lists are requested in parallel.

**Remaining Concerns:**  
None.

---

### Bug #3: FilterState.copyWith list mutation issues
**Status:** ⚠️ Partially Fixed

**Verification:**  
`copyWith` wraps provided lists with `List.unmodifiable`, but the constructor still exposes the default `const []` reference. Callers can still receive the literal and mutate it by mistake. There’s no defensive copy at construction time, so `FilterState(selectedTagIds: myList)` shares whatever list is passed in.

**Remaining Concerns:**  
Clone incoming lists in the constructor (and `fromJson`) the same way `copyWith` does so every instance always holds its own unmodifiable list.

---

### Bug #4: Equality comparison broken
**Status:** ✅ Fixed

**Verification:**  
Equality overrides now compare `selectedTagIds`, `logic`, and the new `presenceFilter` via `listEquals`. Hash code composes the same fields.

**Remaining Concerns:**  
None.

---

### Bug #5: Tag-presence toggles can contradict
**Status:** ⚠️ Partially Fixed

**Verification:**  
The enum + UI guard prevents selecting “untagged” while keeping explicit tag filters. But selecting “onlyTagged” still allows `_selectedTagIds` to stay empty, which makes “Has tags” act as a no-op filter when no specific tags are chosen. This contradicts the requirement that presence filters only make sense with tag selection.

**Remaining Concerns:**  
Enforce `_selectedTagIds.isNotEmpty` when `presenceFilter == onlyTagged` (either by auto-switching back to `any` or disabling that option until at least one tag is selected).

---

### Bug #6: addTagFilter allows duplicates/invalid IDs
**Status:** ⚠️ Partially Fixed

**Verification:**  
Empty strings and duplicates are rejected, but the plan still raw-appends `tagId` without confirming it exists. Erroneous IDs (typos, stale chips) propagate to SQL and either return zero rows or throw foreign-key errors, which then hit the `setFilter` catch path noted above.

**Remaining Concerns:**  
Resolve the optional “tagExists” TODO (or assert via `TagProvider`) before calling `setFilter`.

---

### Bug #7: _completedTasks never updated
**Status:** ✅ Fixed

**Verification:**  
`setFilter` fetches both active and completed lists and assigns `_completedTasks` alongside `_tasks`. `_refreshTasks` also reloads both lists when filters clear.

**Remaining Concerns:**  
None.

---

## New Issues Found in v2

### HIGH – Architecture – FilterState constructor still exposes mutable input
**Location:** `phase-3.6A-plan-v2.md:108-170`

**Issue Description:**  
Only `copyWith` and `fromJson` wrap incoming lists; the constructor leaves `selectedTagIds` as-is when a caller passes a mutable list. Any code that constructs `FilterState(selectedTagIds: existingList)` can mutate the underlying list later and silently change the filter mid-stream.

**Suggested Fix:**  
Mirror the defensive copy from `copyWith` inside the constructor:
```dart
const FilterState({
  List<String> selectedTagIds = const [],
  this.logic = FilterLogic.or,
  this.presenceFilter = TagPresenceFilter.any,
}) : selectedTagIds = List.unmodifiable(selectedTagIds);
```

**Impact:** Medium – immutability guarantees remain brittle and future contributors can reintroduce data races.

---

### MEDIUM – Performance – Tag counts use N×FutureBuilder with pending TODO
**Location:** `phase-3.6A-plan-v2.md:660-730`

**Issue Description:**  
`CheckboxListTile.subtitle` is a `FutureBuilder` calling `_getTaskCount(tag.id)` per row. The method is currently a TODO that returns 0, meaning task counts are misleading until Day 1-2. Even once implemented, this will issue a separate query per tag (dozens or hundreds) every time the dialog opens.

**Suggested Fix:**  
Preload tag counts from a single query (e.g., `SELECT tag_id, COUNT(*) ... GROUP BY tag_id`) before building the dialog, and pass a `Map<String,int>` into the widget. Remove the per-row FutureBuilder to avoid N+1 queries.

**Impact:** Medium – initial implementation will ship a dialog that always displays “0 tasks”, and the eventual fix risks severe performance issues.

---

### MEDIUM – UX/Consistency – Filter presence “Tagged” option does nothing alone
**Location:** `phase-3.6A-plan-v2.md:600-640`

**Issue Description:**  
Selecting “Tagged” is allowed even when `_selectedTagIds` is empty, resulting in the same behavior as “Any”. The plan claims the enum prevents impossible states, but this combination is still useless and can confuse users (the radio button changes yet nothing happens).

**Suggested Fix:**  
When `_presenceFilter` switches to `onlyTagged`, either automatically select all tags, prompt the user to pick at least one, or treat it as “has any tag” (which needs its own query). Document the intended semantics and enforce them.

**Impact:** Medium – users think they filtered to tagged tasks but see no change.

---

### LOW – Error Handling – setFilter leaves UI in inconsistent state on failure
**Location:** `phase-3.6A-plan-v2.md:360-420`

**Issue Description:**  
The catch block logs and re-emits `notifyListeners()` but retains the new `_filterState`. If the query fails, the filter bar shows the attempted filter but the list stays unfiltered. There is no Snackbar/toast acknowledging the failure even though other parts of the plan emphasize user clarity.

**Suggested Fix:**  
Capture the previous `_filterState` before mutation; if an exception occurs, restore it and show a Snackbar. Alternatively, set a `filterError` message in state so the UI can inform the user.

**Impact:** Low – inconsistent UI and silent failure; still worth addressing.

---

## Summary

**Original Bugs Addressed:** 4 / 7  
- ✅ Fully fixed: 3, 4, 7  
- ⚠️ Partially fixed: 1, 3, 5, 6  
- ❌ Not fixed: 0

**New Issues in v2:** 4 (0 Critical / 1 High / 2 Medium / 1 Low)

**Overall Assessment:** ⚠️ Needs minor adjustments

**Must Address Before Implementation:**
1. Harden FilterState constructor (and presence filter semantics) to maintain immutability and consistent UX.
2. Add tag ID validation in `addTagFilter` (or document why it isn’t needed) and consider reverting `_filterState` on query failures.
3. Replace the per-row `_getTaskCount` FutureBuilder or at least implement the TODO before shipping to avoid misleading counts.
