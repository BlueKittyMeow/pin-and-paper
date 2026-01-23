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

---

## Summary

**Total Issues Found:** [X]

**By Severity:**
- CRITICAL: [count]
- HIGH: [count]
- MEDIUM: [count]
- LOW: [count]

**By Type:**
- Bug: [count]
- Performance: [count]
- Architecture: [count]
- Security: [count]
- Test Coverage: [count]

---

## Verdict

**Release Ready:** [YES / NO / YES WITH FIXES]

**Must Fix Before Release:**
- [List CRITICAL and HIGH issues]

**Can Defer:**
- [List MEDIUM and LOW issues]

---

**Review completed by:** Codex
**Date:** [YYYY-MM-DD]
**Confidence level:** [High / Medium / Low]
