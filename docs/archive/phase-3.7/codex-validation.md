# Codex Validation - Phase 3.7

**DO NOT edit this template directly!**
This is a live validation document for Phase 3.7.

---

**Phase:** 3.7 - Natural Language Date Parsing + Sort/Filter
**Implementation Report:** [phase-3.7-implementation-report.md](./phase-3.7-implementation-report.md)
**Validation Doc:** [phase-3.7-validation-v1.md](./phase-3.7-validation-v1.md)
**Review Date:** 2026-01-22
**Reviewer:** Codex
**Status:** Pending Review

---

## Purpose

This document is for **Codex** to validate Phase 3.7 **after implementation is complete**.

Review all changes implemented in Phase 3.7 and look for any/all errors or problems.

**NEVER SIMULATE OTHER AGENTS' RESPONSES.**
Only document YOUR OWN findings here.

**📝 RECORD ONLY - DO NOT MODIFY CODE 📝**
- Your job is to **record findings to THIS file only**
- Do NOT make any changes to the codebase (no editing source files, tests, configs, etc.)
- Do NOT create, modify, or delete any files outside of this document
- Claude will review your findings and implement fixes separately

---

## Validation Scope

**Phase 3.7 implemented two major features:**

1. **Natural Language Date Parsing** (Phases 1-4): Real-time NL date detection in task titles via chrono.js/flutter_js, with inline highlighting and DateOptionsSheet for quick date selection.

2. **Phase 3.7.5 - Live Clock + Sort + Date Filters**: Live date/time in AppBar, sort-by functionality (Manual/Recently Created/Due Soonest), and date-based filters (Overdue/No Date) in the filter dialog.

**Files to review:**
- [ ] `lib/services/date_parsing_service.dart` - Core NL parsing via flutter_js + chrono.js
- [ ] `lib/widgets/date_options_sheet.dart` - Bottom sheet for date options
- [ ] `lib/widgets/highlighted_text_editing_controller.dart` - Inline text highlighting
- [ ] `lib/utils/date_formatter.dart` - Human-friendly date formatting
- [ ] `lib/utils/date_suffix_parser.dart` - Parse/strip date suffixes from titles
- [ ] `lib/utils/debouncer.dart` - Debounce utility
- [ ] `lib/widgets/live_clock.dart` - Live date/time widget
- [ ] `lib/models/task_sort_mode.dart` - Sort mode enum
- [ ] `lib/models/filter_state.dart` - DateFilter enum addition
- [ ] `lib/providers/task_provider.dart` - Sort state, date filter, tree refresh changes
- [ ] `lib/screens/home_screen.dart` - LiveClock, sort PopupMenuButton
- [ ] `lib/widgets/task_input.dart` - Real-time date parsing in Quick Add
- [ ] `lib/widgets/edit_task_dialog.dart` - Date parsing + DateOptionsSheet in edit
- [ ] `lib/widgets/task_item.dart` - Due date display, overdue styling, clickable suffix
- [ ] `lib/widgets/tag_filter_dialog.dart` - Renamed to "Filter", date filter section
- [ ] `lib/widgets/active_filter_bar.dart` - Date filter chip display
- [ ] `lib/services/preferences_service.dart` - Sort persistence
- [ ] `lib/main.dart` - flutter_js initialization

**Test files to review:**
- [ ] `test/services/date_parsing_service_test.dart`
- [ ] `test/utils/date_formatter_test.dart`
- [ ] `test/utils/debouncer_test.dart`
- [ ] `test/widgets/date_options_sheet_test.dart`
- [ ] `test/widgets/highlighted_text_editing_controller_test.dart`
- [ ] `test/integration/date_parsing_integration_test.dart`
- [ ] `test/performance/date_parsing_perf_test.dart`

---

## Specific Areas to Examine Closely

### 1. JavaScript Interop Edge Cases (date_parsing_service.dart)
The app uses flutter_js to run chrono.js via QuickJS FFI. Check for:
- What happens if flutter_js fails to initialize (no JS runtime available)?
- Are there any uncaught exceptions from JS evaluation?
- Is the singleton pattern correct? Could there be initialization race conditions?
- Does `dispose()` properly clean up the JS runtime?
- What happens with malformed/adversarial input strings?

### 2. Sort Logic Correctness (task_provider.dart)
The `_sortTasks()` method sorts root-level tasks. Check:
- Is the null-handling for `dueDate` correct in "Due Soonest" mode?
- Does reverse sort work correctly for all modes?
- Are there edge cases where sort order could be unstable (tasks with identical sort keys)?
- Does resetting to Manual sort on reorder mode entry work correctly?
- Could `_refreshTreeController()` be called before sort preferences are loaded?

### 3. Date Filter Application (task_provider.dart)
The date filter is applied in-memory in `_refreshTreeController()`. Check:
- Is the overdue check correct? (comparing `dueDate` to `DateTime.now()`)
- Does it handle timezone/UTC correctly? (dates stored as UTC strings)
- What happens when filtering children whose parent is filtered out?
- Is the filter applied before or after sort? Does order matter?

### 4. Date Suffix Parsing (date_suffix_parser.dart)
This utility strips date text from titles and re-appends it. Check:
- Are there edge cases where stripping could remove legitimate text?
- Is the regex matching robust for all date formats chrono.js produces?
- What happens with empty titles after stripping?

### 5. Timer Lifecycle (live_clock.dart)
- Is the Timer properly disposed when the widget is removed?
- Could there be a setState-after-dispose issue if the timer fires during disposal?

---

## Review Checklist

### Code Correctness
- [ ] No null safety violations
- [ ] No race conditions or async issues
- [ ] Error handling covers edge cases
- [ ] No memory leaks (dispose patterns correct)
- [ ] No potential crashes (bounds checks, null access)

### Data Integrity
- [ ] Database queries correct (no SQL injection, proper escaping)
- [ ] Data validation at boundaries
- [ ] State management consistent (no stale state)
- [ ] UTC/local date handling consistent

### Performance
- [ ] No N+1 query patterns
- [ ] No unnecessary widget rebuilds
- [ ] No inefficient loops or algorithms
- [ ] Timer intervals appropriate (not too frequent)

### Security
- [ ] JavaScript evaluation is sandboxed (no user input passed unsafely to JS)
- [ ] Input validation on date strings
- [ ] No sensitive data logged

### Test Coverage
- [ ] Key logic paths have tests
- [ ] Edge cases covered (null dates, empty strings, timezone boundaries)
- [ ] Tests actually assert meaningful behavior

---

## Methodology

```bash
# Find Phase 3.7 files
find pin_and_paper/lib -name "*date*" -o -name "*clock*" -o -name "*sort*"

# Search for potential issues
grep -r "DateTime.now()" pin_and_paper/lib/
grep -r "dispose" pin_and_paper/lib/widgets/live_clock.dart
grep -r "evaluate" pin_and_paper/lib/services/date_parsing_service.dart

# Check for TODOs
grep -r "TODO\|FIXME\|HACK" pin_and_paper/lib/

# Review the git changes
git diff main..HEAD -- pin_and_paper/lib/
git log --oneline main..HEAD
```

---

## Findings

_Use the format below for each issue found._

### Issue Format

```markdown
### Issue #[N]: [Brief Title]

**File:** `path/to/file.dart:line`
**Type:** [Bug / Performance / Architecture / Security / Test Coverage]
**Severity:** [CRITICAL / HIGH / MEDIUM / LOW]

**Description:**
[What's wrong and why it matters]

**Current Code:**
\`\`\`dart
[Problematic code]
\`\`\`

**Suggested Fix:**
\`\`\`dart
[Fixed code]
\`\`\`

**Impact:**
[What breaks if not fixed]
```

---

## [Your findings go here]

_Start reviewing and add issues above using the format._

### Issue #1: Overdue filter marks all-day tasks due today as overdue

**File:** `pin_and_paper/lib/providers/task_provider.dart:291`
**Type:** Bug
**Severity:** HIGH

**Description:**
The overdue filter compares `dueDate` to `DateTime.now()` without considering `isAllDay`. All-day tasks due today are treated as overdue immediately after midnight. This produces incorrect filter results and user confusion.

**Current Code:**
```dart
final now = DateTime.now();
activeRoots = activeRoots.where((t) {
  switch (_filterState.dateFilter) {
    case DateFilter.overdue:
      return t.dueDate != null && t.dueDate!.isBefore(now);
```

**Suggested Fix:**
```dart
final effectiveToday = DateParsingService().getCurrentEffectiveToday();
activeRoots = activeRoots.where((t) {
  if (_filterState.dateFilter == DateFilter.overdue) {
    if (t.dueDate == null) return false;
    if (t.isAllDay) {
      final dateOnly = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      final todayOnly = DateTime(effectiveToday.year, effectiveToday.month, effectiveToday.day);
      return dateOnly.isBefore(todayOnly);
    }
    return t.dueDate!.isBefore(DateTime.now());
  }
  ...
});
```

**Impact:**
Overdue filter is inaccurate for all-day tasks, especially around midnight and within the Today Window.

### Issue #2: Date filter only applied to root tasks, hides matching children

**File:** `pin_and_paper/lib/providers/task_provider.dart:277`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
The date filter is applied after the root list is built, so only root tasks are filtered. Children that match the date filter but whose parent does not match are excluded from the tree, resulting in missing tasks in filtered views.

**Current Code:**
```dart
var activeRoots = _tasks.where((t) { ... }).toList();
if (_filterState.dateFilter != DateFilter.any) {
  activeRoots = activeRoots.where((t) { ... }).toList();
}
```

**Suggested Fix:**
```dart
// Apply date filter to the full task list first, then derive roots
final filteredTasks = _applyDateFilter(_tasks, _filterState.dateFilter);
final taskIds = filteredTasks.map((t) => t.id).toSet();
final activeRoots = filteredTasks.where((t) {
  if (t.parentId != null && taskIds.contains(t.parentId)) return false;
  ...
}).toList();
```

**Impact:**
Filtered views can omit matching tasks that are nested under non-matching parents.

### Issue #3: Expansion state lost when filters are active due to pruning

**File:** `pin_and_paper/lib/providers/task_provider.dart:272`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
`pruneOrphanedIds` is called with the current (filtered) `_tasks` list. When tag/date filters are active, this drops expansion state for tasks outside the filtered list, so clearing filters collapses previously expanded nodes.

**Current Code:**
```dart
final taskIds = _tasks.map((t) => t.id).toSet();
_treeController.pruneOrphanedIds(taskIds);
```

**Suggested Fix:**
```dart
// Option A: Skip pruning when filters are active
if (!_filterState.isActive) {
  _treeController.pruneOrphanedIds(taskIds);
}
// Option B: Use an unfiltered task ID set if available
```

**Impact:**
Filter toggles unexpectedly reset expansion state, degrading UX.

### Issue #4: Sort preferences load does not re-sort existing tree

**File:** `pin_and_paper/lib/providers/task_provider.dart:545`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
Sort preferences are loaded asynchronously, but `_refreshTreeController()` is not called afterward. If tasks load before preferences finish, the tree remains in manual order while the UI indicates a different sort mode.

**Current Code:**
```dart
_sortMode = TaskSortMode.values.firstWhere(...);
_sortReversed = await _preferencesService.getSortReversed();
notifyListeners();
```

**Suggested Fix:**
```dart
_sortMode = ...
_sortReversed = ...
_refreshTreeController();
notifyListeners();
```

**Impact:**
Saved sort modes may not apply on app launch until the next manual refresh.

### Issue #5: Highlighted dates are not clickable despite API suggesting they are

**File:** `pin_and_paper/lib/widgets/highlighted_text_editing_controller.dart:17`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
`HighlightedTextEditingController` exposes `onTapHighlight`, and callers pass handlers, but the implementation never uses it. Highlighted text is visual-only, so DateOptionsSheet cannot be opened by tapping highlighted text in Edit Task or Quick Add.

**Current Code:**
```dart
TextSpan(
  text: text.substring(range.start, range.end),
  style: baseStyle.copyWith(...),
),
```

**Suggested Fix:**
```dart
// Option A: Add a separate "Edit date" chip/button next to the preview
// Option B: Use a read-only overlay/gesture detector (if keeping tap UX)
// Avoid TapGestureRecognizer inside editable TextField if it triggers assertions
```

**Impact:**
User-facing behavior does not match the spec (“tap highlighted text to edit/remove”).

### Issue #6: Overdue suffix detection ignores Today Window for all-day tasks

**File:** `pin_and_paper/lib/utils/date_suffix_parser.dart:165`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
`_isOverdue` uses `DateTime.now()` for all-day tasks, so tasks due “yesterday” are marked overdue during the Today Window (e.g., 2am) even though the app treats it as “still yesterday.”

**Current Code:**
```dart
final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
return dateOnly.isBefore(today);
```

**Suggested Fix:**
```dart
final effectiveToday = DateParsingService().getCurrentEffectiveToday();
final today = DateTime(effectiveToday.year, effectiveToday.month, effectiveToday.day);
return dateOnly.isBefore(today);
```

**Impact:**
Date suffix coloring and “overdue” labeling are inconsistent with the Today Window logic.

---

## Summary

**Total Issues Found:** 6

**By Severity:**
- CRITICAL: 0
- HIGH: 1
- MEDIUM: 5
- LOW: 0

**By Type:**
- Bug: 6
- Performance: 0
- Architecture: 0
- Security: 0
- Test Coverage: 0

---

## Verdict

**Release Ready:** YES WITH FIXES

**Must Fix Before Release:**
- Issue #1 (Overdue filter for all-day tasks)

**Can Defer:**
- Issue #2 (date filter hides matching children)
- Issue #3 (expansion state pruned under filters)
- Issue #4 (sort prefs not applied until refresh)
- Issue #5 (highlight not clickable)
- Issue #6 (overdue suffix ignores Today Window)

---

**Review completed by:** Codex
**Date:** 2026-01-22
**Confidence level:** Medium
