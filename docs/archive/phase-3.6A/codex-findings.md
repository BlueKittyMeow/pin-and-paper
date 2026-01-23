# Codex Findings - Phase 3.6A

**Phase:** 3.6A (Tag Filtering)
**Started:** 2026-01-09
**Status:** Active

---

## Instructions

This document tracks bugs, issues, and improvements found by GitHub Codex during Phase 3.6A implementation.

**Format for each finding:**
```markdown
## Issue: [Brief Title]
**File:** path/to/file.dart:line
**Type:** [Bug / Performance / Architecture / Documentation]
**Found:** [DATE]

**Description:**
[What's wrong]

**Suggested Fix:**
[How to fix]

**Impact:** [High / Medium / Low]

**Resolution:**
[How it was addressed, or "Deferred to Phase X"]
```

Add findings as you discover them. Claude will periodically review and address.

---

## Findings

## Issue: FilterState.copyWith reuses mutable list reference
**File:** docs/phase-3.6A/phase-3.6A-ultrathink.md (State Management Strategy)  
**Type:** Bug  
**Found:** 2026-01-09

**Description:**  
`FilterState.copyWith` forwards `selectedTagIds ?? this.selectedTagIds`. When the current state holds the default `const []`, the next filter that spreads or mutates the returned list will modify the same list instance because the reference is shared. The plan later uses `final newTags = [..._filterState.selectedTagIds, tagId];` which relies on defensive copying. But any code that forgets to copy first will mutate the FilterState instance in place, violating immutability guarantees and making equality or caching unpredictable.

**Suggested Fix:**  
Always clone the list inside `copyWith`/constructor:
```dart
FilterState copyWith({
  List<String>? selectedTagIds,
  FilterLogic? logic,
  bool? showOnlyWithTags,
  bool? showOnlyWithoutTags,
}) {
  return FilterState(
    selectedTagIds: List.unmodifiable(selectedTagIds ?? this.selectedTagIds),
    logic: logic ?? this.logic,
    showOnlyWithTags: showOnlyWithTags ?? this.showOnlyWithTags,
    showOnlyWithoutTags: showOnlyWithoutTags ?? this.showOnlyWithoutTags,
  );
}
```

**Impact:** Medium – accidental mutations break immutability and invalidate assumptions around `isActive`, equality checks, and Provider rebuilds.

**Resolution:** _Open_

---

## Issue: `_filterState == filter` always false without overriding equality
**File:** docs/phase-3.6A/phase-3.6A-ultrathink.md (Set Filter flow)  
**Type:** Bug  
**Found:** 2026-01-09

**Description:**  
The plan short-circuits `setFilter` when `_filterState == filter`, but `FilterState` does not override `==`/`hashCode`. In Dart, this comparison defaults to identity so it only returns true when both references are the same object. Every `copyWith` or dialog result produces a new instance, so the early return never triggers. That removes the whole purpose of `if (_filterState == filter) return;` and leads to unnecessary SQL work and rebuilds even when the user re-applies the same filter.

**Suggested Fix:**  
Implement `==`/`hashCode` (or extend `Equatable`) using the four fields so logically-equal states compare true:
```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is FilterState &&
      listEquals(selectedTagIds, other.selectedTagIds) &&
      logic == other.logic &&
      showOnlyWithTags == other.showOnlyWithTags &&
      showOnlyWithoutTags == other.showOnlyWithoutTags;

@override
int get hashCode => Object.hash(
  Object.hashAll(selectedTagIds),
  logic,
  showOnlyWithTags,
  showOnlyWithoutTags,
);
```

**Impact:** Medium – wasted round-trips to the database and flickering UI when applying duplicate filters.

**Resolution:** _Open_

---

## Issue: Filter mutations race during async `_taskService.getFilteredTasks`
**File:** docs/phase-3.6A/phase-3.6A-ultrathink.md (Filter update flow)  
**Type:** Architecture  
**Found:** 2026-01-09

**Description:**  
`setFilter` assigns `_filterState = filter` and then awaits `_taskService.getFilteredTasks(filter)` with no debouncing, cancellation, or operation ID guard. If the user taps several tag chips quickly, later operations may finish before earlier ones and overwrite `_tasks` with stale results. The planning doc mentions the operation-ID pattern as an idea, but the implementation section never actually wires it in. Without that guard you can end up with a filter bar showing "Work, Urgent" but the list containing only "Work" results from an earlier call.

**Suggested Fix:**  
Add the operation counter pattern (or `CancelableOperation`) directly in `setFilter` so only the latest query can mutate `_tasks`/_`_filterState`. Also consider storing `_filterState` only after the async work succeeds, or storing “in-progress filter” separately so UI doesn’t lie when the request fails.

**Impact:** High – race conditions produce incorrect task lists and confusing UI.

**Resolution:** _Open_

---

## Issue: Tag-presence toggles can contradict selected tags
**File:** docs/phase-3.6A/phase-3.6A-ultrathink.md (Edge Case 1 & requirements)  
**Type:** Bug / Functional Ambiguity  
**Found:** 2026-01-09

**Description:**  
The requirements state “Can combine with specific tag filters” for both `showOnlyWithTags` and `showOnlyWithoutTags`, meaning the UI can set `selectedTagIds = ['work']`, `showOnlyWithTags = true`, and `showOnlyWithoutTags = true` simultaneously. Those flags imply mutually exclusive SQL predicates (“has tags” vs “no tags”), so combining them makes the query unsatisfiable and will empty the list even though the UI claims the filters are valid. The plan never reconciles these states or specifies precedence.

**Suggested Fix:**  
Make the two booleans mutually exclusive in both UI and model (e.g., derive them from a single enum {any, taggedOnly, untaggedOnly}). Disable the "No tags" checkbox whenever any specific tags are selected (or automatically clear tag selections). Document the behavior explicitly.

**Impact:** Medium – users can end up with impossible filter combinations and think the feature is broken.

**Resolution:** _Open_

---

## Issue: `addTagFilter` allows duplicates and invalid IDs
**File:** docs/phase-3.6A/phase-3.6A-ultrathink.md (Edge Cases & addTagFilter snippet)  
**Type:** Bug  
**Found:** 2026-01-09

**Description:**  
`addTagFilter` blindly spreads `_filterState.selectedTagIds` and appends `tagId` without validating it. If the same chip is tapped twice (or the dialog returns duplicates) the AND SQL (`HAVING COUNT(DISTINCT tag_id) = ?`) no longer aligns with the `?` parameter because `selectedTagIds.length` counts duplicates while `COUNT(DISTINCT ...)` does not. The method also never rejects null/empty IDs, so invalid values can propagate into the query and throw at runtime.

**Suggested Fix:**  
Before calling `setFilter`, bail out when `tagId` is null/empty or already present:
```dart
if (tagId.isEmpty || _filterState.selectedTagIds.contains(tagId)) return;
final newTags = List<String>.from(_filterState.selectedTagIds)..add(tagId);
await setFilter(_filterState.copyWith(selectedTagIds: newTags));
```
Optionally verify the ID exists by checking `TagProvider.tags`.

**Impact:** Medium – duplicate entries either break AND logic or spend SQL work only to yield zero results; invalid IDs can throw.

**Resolution:** _Open_

---

## Issue: Filtered queries ignore active/completed scope
**File:** docs/phase-3.6A/phase-3.6A-plan-v1.md (TaskService SQL snippets)  
**Type:** Bug  
**Found:** 2026-01-09

**Description:**  
The SQL examples for `getFilteredTasks` never constrain `tasks.completed`. Yet TaskProvider plans to call `_taskService.getFilteredTasks(filter, completed: false)` and again with `completed: true`. Without an `AND tasks.completed = ?` predicate (or equivalent), both calls return identical rows and the app cannot distinguish active vs. completed lists. Completed tasks would leak into the active list (and vice versa) whenever filters are applied.

**Suggested Fix:**  
Add a `completed` parameter and append `AND tasks.completed = (completed ? 1 : 0)` (plus `deleted_at IS NULL`) to every query branch, including the “has tags”/“no tags” filters.

**Impact:** High – filtered results would mix active and completed tasks, breaking core UX.

**Resolution:** _Open_

---

## Issue: `_refreshFilteredTasks` never updates `_completedTasks`
**File:** docs/phase-3.6A/phase-3.6A-ultrathink.md (State Management Strategy)  
**Type:** Bug / Incomplete Implementation  
**Found:** 2026-01-09

**Description:**  
The doc states the filter is global (“Changing filter on TaskListScreen also filters CompletedTasksScreen”), but `_refreshFilteredTasks()` only assigns to `_tasks`. `_completedTasks` remains untouched until some other code reloads it, so the completed tab can show stale/unfiltered results while the filter bar insists filters are active.

**Suggested Fix:**  
Whenever `_filterState.isActive`, fetch both datasets:
```dart
final active = await _taskService.getFilteredTasks(_filterState, completed: false);
final completed = await _taskService.getFilteredTasks(_filterState, completed: true);
_tasks = active;
_completedTasks = completed;
```
Likewise, when clearing filters, refresh both lists so the views stay in sync.

**Impact:** Medium – users see different task sets between tabs even though a single global filter is advertised.

**Resolution:** _Open_

---
