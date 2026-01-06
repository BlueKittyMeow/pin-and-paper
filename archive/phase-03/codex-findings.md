# Codex's Bug Hunting - Phase 3.5

**Phase:** 3.5
**Status:** 🔜 Planning
**Last Updated:** 2025-12-27

---

## Instructions for Codex

Welcome Codex! This is your bug hunting workspace for Phase 3.5. Your mission:

1. **Analyze the implementation plan** from a code architecture perspective
2. **Identify potential bugs** before they happen
3. **Review actual implementation** when code is written
4. **Stress test** the new functionality
5. **Document findings** with technical precision

**Your Strengths:**
- Code pattern analysis
- Architecture review
- Error handling evaluation
- Test coverage assessment

---

## Architecture Review

*Waiting for Codex to review the Phase 3.5 implementation plan*

---

## Bug Reports

*No implementation yet - will update once code is written*

**Bug Report Template:**
```
## Issue: [Brief descriptive title]
**File:** path/to/file.dart:line-number
**Type:** [Bug / Performance / Architecture / Documentation]
**Found:** YYYY-MM-DD

**Description:**
[Clear explanation of what's wrong, including context and why it's a problem]

**Suggested Fix:**
[Specific recommendation with code examples if applicable]

**Impact:** [High / Medium / Low]
```

---

## Code Review Checklist

*To be completed during implementation review*

- [ ] Error handling: All exceptions caught and handled appropriately
- [ ] Input validation: Edge cases covered (empty, null, very long)
- [ ] Memory management: Resources disposed properly
- [ ] State management: notifyListeners() called at right times
- [ ] SQL injection: Parameterized queries used (not string concatenation)
- [ ] Context checks: `mounted` checks before setState/Navigator
- [ ] Null safety: All nullable types handled correctly
- [ ] Performance: No unnecessary full list reloads
- [ ] Accessibility: Proper labels for screen readers
- [ ] Logging: Appropriate debug/error logging

---

## Test Coverage Analysis

*To be completed after tests are written*

**Coverage Goals:**
- [ ] Unit tests for service layer
- [ ] Unit tests for input validation
- [ ] Unit tests for error cases
- [ ] Widget tests for UI components
- [ ] Integration tests for full flows

---

## Performance Notes

*To be filled in by Codex during implementation review*

## Findings - 2025-12-27 (Phase 3.5 Implementation Spec Review)

1. **N+1 tag loading + no assignment** – The spec’s TaskProvider `loadTasks()` loops over `_tasks` and calls `await _tagService.getTagsForTask(task.id)` sequentially, then does `task = task.copyWith(tags: tags);`. This rebinds the local variable only; `_tasks[i]` never gets the updated instance. It’s also an O(N) round-trip per task. We should either modify the SQL in `getAllTasksWithHierarchy` to return tags via JOIN/aggregation or batch-fetch per task set; at minimum assign back into the list (`_tasks[index] = _tasks[index].copyWith(...)`). (Ref: docs/phase-03/phase-3.5-implementation.md §“TaskProvider Updates”).

2. **Filter application overwrites derived lists, not the source tree** – `_applyTagFilters()` only rewrites `_activeTasks`/`_recentlyCompletedTasks`. The hierarchical tree still renders `_tasks`, and `_refreshTreeController()` is never called after filtering, so tag filters won’t affect the main view. Need a clear plan: either filter `_tasks` before categorization or introduce a separate filtered view used by the tree. (Same section).

3. **Listener lifecycle leak** – `setTagProvider()` adds `_onTagFiltersChanged` as a listener but never removes it. If TaskProvider is disposed or a new TagProvider is injected (tests, ServiceLocator), the old listener persists. Add a `removeListener` in `dispose()` or when swapping providers.

4. **Hide-completed + tag filters unresolved** – `_applyTagFilters()` blindly splits filtered tasks into completed vs. active without considering the existing “hide old completed” threshold. Depending on order of operations, tag filters could appear blank even when matching tasks exist. We need explicit logic (and tests) for how tag filters interact with `_hideOldCompleted`.

5. **Custom palette table might be overkill for 3.5a** – Design decision #4 locks in preset + custom picker + user-saved palettes, and the migration adds a `tag_palettes` table. This significantly expands scope (UI, CRUD, backup) beyond “core tag management.” If we keep it, the plan needs UI/screens/tests for palette CRUD; otherwise, defer the table/migration to the stretch phase.

6. **Filtering queries undefined** – `_applyTagFilters()` references `_tagService.getTasksForTags()`/`getTasksForTagsAND()` but the SQL for these isn’t specified. Need to ensure they: (a) exclude soft-deleted tasks/tags, (b) return depth/parent info for the tree, and (c) are indexed to avoid full scans. Without explicit queries, we risk expensive joins or missing depth data.
