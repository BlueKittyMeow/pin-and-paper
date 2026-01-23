# Phase 3.6B Implementation Review

**Date:** 2026-01-11
**Status:** Review Complete (Gemini)
**Reviewer:** Gemini

---

## Feedback Collection

### Gemini's Feedback

**Status:** Review Complete

### HIGH - Data - SQL Index Ineffectiveness with LIKE

**Location:** Section 2 "SearchService", `_getCandidates` method SQL query

**Issue Description:**
The plan proposes using `CREATE INDEX` on `title` and `notes` to speed up search. However, the query uses `LIKE '%query%'` (with a leading wildcard). In standard SQLite, B-Tree indexes **cannot** be used for `LIKE` queries that start with a wildcard. The database will perform a full table scan for every search, rendering the indexes mostly useless for this specific query pattern.

**Suggested Fix:**
1.  **Acceptance:** For 1000 tasks, a full table scan is likely still <10ms, so this might be acceptable for the current scale. Acknowledge this limitation in the code comments.
2.  **Alternative:** For true scalability, use SQLite's FTS5 (Full Text Search) extension, which supports efficient text indexing. This is likely out of scope for Phase 3.6B but should be noted as the "real" fix for performance.
3.  **Optimization:** Ensure the query filters by `completed` *before* the LIKE clause so the index on `completed` can reduce the scan set size.

**Impact:**
The performance target of <100ms will likely still be met due to small dataset size, but the indexes will not function as intended for text search, potentially misleading future optimization efforts.

---

### HIGH - Performance - FutureBuilder in List Items

**Location:** Section 3 "Search Dialog UI", `_buildTagFilters` -> `_selectedTagIds.map` loop

**Issue Description:**
The plan uses `FutureBuilder` inside the `Wrap` to load each tag's details (`TagService().getTagById(tagId)`).
```dart
return FutureBuilder<Tag?>(
  future: TagService().getTagById(tagId),
  builder: (context, snapshot) { ... }
);
```
This triggers an asynchronous database fetch for *every single tag chip* every time the widget builds. This will cause UI jank and unnecessary database load, especially if there are multiple selected tags.

**Suggested Fix:**
Pre-load the full `Tag` objects when the dialog initializes or when `_selectedTagIds` changes. Store `List<Tag> _selectedTags` in the state instead of just IDs, or fetch them all in one batch operation (`getTagsByIds`) when the state changes.

**Impact:**
UI jank and "pop-in" effect for tag chips, plus inefficient database usage (N+1 query pattern).

---

### MEDIUM - Logic - SearchService Missing DISTINCT

**Location:** Section 2 "SearchService", `_getCandidates` method

**Issue Description:**
The query joins `task_tags` and `tags`.
```sql
SELECT DISTINCT tasks.*
FROM tasks
LEFT JOIN task_tags ON tasks.id = task_tags.task_id
LEFT JOIN tags ON task_tags.tag_id = tags.id
...
```
While `DISTINCT` is present, `LEFT JOIN` on tags can multiply the number of rows processed before the DISTINCT reduction if a task has many tags. More importantly, the `tagIds` filter logic in the Dart code:
```dart
if (tagIds != null && tagIds.isNotEmpty) {
  conditions.add('tags.id IN (${tagIds.map((_) => '?').join(',')})');
  args.addAll(tagIds);
}
```
This filter is applied *after* the join. If a task has 5 tags and we search for 1, the join creates 5 rows, filters down to 1, then DISTINCTs.

**Suggested Fix:**
The query logic is generally sound, but verify that `DISTINCT` is applied correctly by SQLite to return unique Task objects. The current plan seems correct here (`SELECT DISTINCT tasks.*`), but it's worth double-checking that `Task.fromMap` handles the resulting row structure correctly (it should, as it ignores extra columns from joined tables usually).

**Impact:**
Potential performance overhead if tasks have huge numbers of tags, but likely minor.

---

### MEDIUM - UX - Breadcrumb Loading

**Location:** Section 4 "Search Result Tile", `_buildBreadcrumb`

**Issue Description:**
Similar to the tag chips, the breadcrumb uses a `FutureBuilder` inside every list tile:
```dart
return FutureBuilder<String>(
  future: _getBreadcrumb(task),
  ...
);
```
For a list of 50 search results, this fires 50 async recursive SQL queries to build parent chains as the user scrolls. This will cause scroll lag.

**Suggested Fix:**
1.  **Join Pre-fetch:** Modify the main search query to join with the parent table (for 1 level) or use a recursive CTE to fetch the path string *during* the search query.
2.  **Batch Load:** Or, load breadcrumbs for the current page of results in `_performSearch`.
3.  **Optimization:** Since `getTaskHierarchy` already exists and is likely cached or fast, consider using the `TaskProvider`'s existing knowledge of the tree if available, rather than hitting the DB for every cell.

**Impact:**
Scroll performance degradation in the search results list.

---

### MEDIUM - Logic - Search Tag Filter Logic Discrepancy

**Location:** Section 2 "Search Service Layer", `_getCandidates` method

**Issue Description:**
The plan explicitly states: "Simple OR logic for search: task has ANY of the selected tags (Simpler than Phase 3.6A AND/OR logic)".
In Phase 3.6A, the main tag filter supports both AND and OR logic. In Search (3.6B), selecting multiple tags will *always* use OR logic. Users might expect consistency (e.g., searching for tasks that are both "Work" AND "Urgent" plus the text "meeting").

**Suggested Fix:**
Confirm with BlueKitty if this simplification is intentional and acceptable. If "AND" logic is desired for search tags, the query generation will need to match the complexity of Phase 3.6A's query builder (using `GROUP BY ... HAVING`).

**Impact:**
Potential user confusion due to inconsistent filtering behavior between main list and search.

---

### MEDIUM - Architecture - Missing Navigation Primitives

**Location:** Implementation Notes "Navigation to Task"

**Issue Description:**
The pseudo-code relies on `findNodeById` and `expandParentChain`:
```dart
final node = findNodeById(taskId);
expandParentChain(node);
```
It is not confirmed if `TreeController` or `TaskProvider` currently exposes these specific methods. Navigating to a deeply nested, collapsed node in a virtualized tree view is a non-trivial algorithmic problem.

**Suggested Fix:**
Verify if `flutter_fancy_tree_view` provides a built-in way to expand to a specific node ID. If not, a helper method to traverse the parent chain (using `Task.parentId` from the database) and recursively call `expand()` on the controller will need to be implemented as part of this phase.

**Impact:**
"Click result -> navigate to task" feature might be blocked or require significantly more effort than estimated if these primitives don't exist.

---

### LOW - Architecture - String Similarity Dependency

**Location:** Section 7 "Dependencies"

**Issue Description:**
The plan introduces `string_similarity ^2.0.0`.

**Suggested Fix:**
Ensure this package is compatible with the project's Dart SDK version constraints. Also, `StringSimilarity.compareTwoStrings` is O(N*M). For very long notes fields, this could be slow. Consider truncating notes before comparison if performance issues arise.

**Impact:**
Potential version conflict or minor performance edge case.

---

### LOW - UX - Stale Search State

**Location:** Section 3 "Search Dialog UI", `_restoreSearchState`

**Issue Description:**
When restoring state, `_performSearch()` is called. Since this is async, the dialog might initially show an empty list or old results before the new search completes.

**Suggested Fix:**
Set `_isSearching = true` synchronously inside `_restoreSearchState` if a query exists, so the user sees a loading indicator immediately instead of a flash of empty content.

**Impact:**
Minor visual polish.

---

### Codex's Feedback

**Status:** Review Complete

### HIGH - Integration - "Apply Active Tags" Ignores FilterState Semantics

**Location:** Section 5 "Integration with Phase 3.6A Tag Filters" and Section 2 `_getCandidates` tag filter clause

**Issue Description:**
When users tap "Apply active tags," they likely expect the same semantics as their current Phase 3.6A filter (AND/OR logic and presence filter). The plan hardcodes OR-only tag logic (`tags.id IN (...)`) and ignores `FilterState.logic` and any "untagged/only tagged" presence filter. This will return broader (or entirely different) results than the active filter view, which is surprising and breaks the Phase 3.6A mental model.

**Suggested Fix:**
Option A: Pass the full `FilterState` into `SearchService` and reuse the Phase 3.6A SQL builder so "Apply active tags" preserves AND/OR and presence semantics.
Option B: Add an explicit "Match any / Match all" toggle in the dialog and map it to `FilterState.logic` when importing active filters. If presence filter is "untagged only," support it with a `NOT EXISTS` subquery or show a clear message that it cannot be applied.

**Impact:**
Search results will not match the user's active tag filter expectations, causing confusion and distrust in search accuracy.
- Codex

---

### HIGH - Logic - Recently Completed Uses Wrong Timestamp Type

**Location:** Section 2 "SearchService", `SearchScope.recentlyCompleted` clause in `_getCandidates`

**Issue Description:**
The plan uses `cutoff.toIso8601String()` for `tasks.completed_at >= ?`. In this codebase, timestamps are stored as integer epoch millis. Comparing integers to ISO strings will return incorrect results (often empty).

**Suggested Fix:**
Use `cutoff.millisecondsSinceEpoch` (or whatever the Task model stores) and add `tasks.completed_at IS NOT NULL` to the clause.

**Impact:**
"Recently completed" results will be wrong or empty, breaking a core search scope.
- Codex

---

### HIGH - Logic - Tag Scoring/Highlighting Data Not Available

**Location:** Section 2 "SearchService", `_scoreResults`, `_getTagScore`, `_findMatches`

**Issue Description:**
`_getTagScore` is referenced but not defined, and `Task` objects returned by `SELECT DISTINCT tasks.*` contain no tag names. Without tag data per task, the 10% tag relevance weight and tag matching cannot be computed correctly. `_findInString` is also undefined, so highlight matching logic is incomplete.

**Suggested Fix:**
Fetch tag names alongside tasks in the candidate query (for example `GROUP_CONCAT(tags.name) AS tag_names`), or batch-load tags by task ID in one query and cache them in a map. Define `_getTagScore` to use those tag names, and document/implement `_findInString` (case-insensitive, overlapping matches).

**Impact:**
Tag relevance scoring will be incorrect or skipped, and match highlighting cannot be implemented as specified.
- Codex

---

### MEDIUM - Logic - No Debounce or Stale Result Guard

**Location:** Section 3 "SearchDialog", `_performSearch` + `onChanged`

**Issue Description:**
`onChanged` calls `_performSearch()` directly with no debounce. Multiple async searches can race, and slower searches can overwrite newer results. `_performSearch` also calls `setState` after `await` without checking `mounted`.

**Suggested Fix:**
Add a debounce `Timer` (for example 200-300ms) and a monotonically increasing `_searchOperationId` so only the latest search updates state. Always `if (!mounted) return;` before `setState` after awaits.

**Impact:**
Flickering or incorrect results during rapid typing; possible `setState() called after dispose` crashes.
- Codex

---

### MEDIUM - Logic - LIKE Wildcards Not Escaped

**Location:** Section 2 "SearchService", SQL pattern construction

**Issue Description:**
The query builds `LIKE '%${query}%'` without escaping `%` or `_`. User queries containing `%`, `_`, or `\\` will be interpreted as wildcards, producing incorrect matches.

**Suggested Fix:**
Escape `%` and `_` in the query string (for example replace `%` with `\\%`, `_` with `\\_`) and add `ESCAPE '\\'` to the SQL clause.

**Impact:**
Incorrect results for queries containing wildcard characters.
- Codex

---

### MEDIUM - Logic - Short Query Scoring and Unstable Sort

**Location:** Section 2 "SearchService", `_fuzzyScore` and sorting

**Issue Description:**
`StringSimilarity.compareTwoStrings` returns 0 for very short strings (length < 2), so single-character queries will produce identical scores for most results. `List.sort` is not stable in Dart, so result order can shuffle on each keystroke.

**Suggested Fix:**
For short queries, switch to a contains-based score (for example `text.contains(query)` -> 1.0 else 0.0) or use a simple prefix score. Add a deterministic tie-breaker (for example `tasks.position ASC` or `created_at DESC`) when scores are equal.

**Impact:**
Poor relevance ordering and unstable UX for short queries, despite the requirement to search on any input length.
- Codex

---

### LOW - Architecture - `Match` Name Collides with `dart:core`

**Location:** Section 2 "SearchService", `class Match`

**Issue Description:**
Declaring a custom `Match` class shadows `dart:core`'s `Match` type. If `_findInString` uses `RegExp`, it will return `Match` objects that conflict with this custom type.

**Suggested Fix:**
Rename to `MatchRange`, `TextMatchRange`, or similar.

**Impact:**
Potential type confusion and extra friction when implementing match-finding logic.
- Codex

---

## Summary of Issues Found (Codex)

| Priority | Category | Count | Examples |
|----------|----------|-------|----------|
| CRITICAL | - | 0 | - |
| HIGH | Logic/Integration | 3 | Tag filter semantics, recently completed timestamp, tag scoring data |
| MEDIUM | Logic/Perf | 3 | Debounce/race, LIKE escaping, short query scoring |
| LOW | Arch | 1 | Match name collision |

**Total Issues:** 7

## Summary of Issues Found (Round 1 & 2)

| Priority | Category | Count | Examples |
|----------|----------|-------|----------|
| CRITICAL | - | 0 | - |
| HIGH | Data/Perf | 2 | SQL Index misuse, FutureBuilder N+1 (Tags) |
| MEDIUM | Logic/UX | 4 | Breadcrumb loading (FutureBuilder), SQL logic, Search logic discrepancy, Navigation primitives |
| LOW | Arch/UX | 2 | Dependency check, Stale search state |

**Total Issues:** 8

## Sign-Off

- [x] **Gemini:** Approved with fixes (See HIGH/MEDIUM issues regarding SQL Index usage, FutureBuilder performance, and Navigation primitives).
- [ ] **Codex:** Approved with fixes (See Codex's Feedback and Summary).
