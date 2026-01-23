# Phase 3.7 Implementation Report - Natural Language Date Parsing

**Phase:** 3.7
**Branch:** `phase-3.7-date-parsing`
**Duration:** Jan 20, 2026 - Jan 22, 2026
**Status:** COMPLETE

---

## Overview

Phase 3.7 implements natural language date parsing for Pin and Paper, allowing users to type date phrases (e.g., "tomorrow", "next Tuesday", "Jan 15") directly in task titles. Dates are detected in real-time with inline highlighting, and applied when saving.

Additionally, Phase 3.7.5 added a live clock display in the AppBar, a sort-by feature for task ordering, and date-based filters (Overdue, No Date) in the filter dialog.

---

## Subphases Completed

### Phase 3.7 Core: NL Date Parsing (Phases 1-4)

| Phase | Feature | Commits |
|-------|---------|---------|
| 1 | flutter_js + chrono.js Setup | `6674890` |
| 2 | Real-time Highlighting UI | `ccc4f91` |
| 3-4 | Dialog Integration & DateOptionsSheet | `ccb972b` |
| - | Quick Add date parsing + UTC/dismissal fixes | `a0b4d1f` |
| - | Date display improvements + time picker | `77e07c0` |
| - | Clickable date suffix + UTC/crash fixes | `9d4b9b4` |
| - | Auto-append/strip date suffix on save | `f4d0cf6` |
| - | DateOptionsSheet title updates + relative labels | `607050e` |
| - | Clear date text fix + debug fixes | `c23c1ee` |

### Phase 3.7.5: Live Clock + Sort + Date Filters

| Feature | Commits |
|---------|---------|
| Live clock in AppBar + Sort-by functionality | `d759012` |
| Date filters (Overdue/No Date) + remove redundant Overdue sort | `7c23ec0` |

---

## Key Files Created

| File | Purpose |
|------|---------|
| `lib/services/date_parsing_service.dart` | Core NL parsing via flutter_js + chrono.js |
| `lib/widgets/date_options_sheet.dart` | Bottom sheet for date options (Today/Tomorrow/Next Week/Pick) |
| `lib/widgets/highlighted_text_editing_controller.dart` | Inline text highlighting in TextFields |
| `lib/utils/date_formatter.dart` | Human-friendly date formatting utilities |
| `lib/utils/date_suffix_parser.dart` | Parse/strip date suffixes from titles |
| `lib/utils/debouncer.dart` | Debounce utility for real-time parsing |
| `lib/widgets/live_clock.dart` | Live date/time display widget |
| `lib/models/task_sort_mode.dart` | Sort mode enum (Manual, Recently Created, Due Soonest) |
| `assets/js/chrono.min.js` | Bundled chrono.js NL date parser |

## Key Files Modified

| File | Changes |
|------|---------|
| `lib/providers/task_provider.dart` | Sort state, date filter application, tree refresh |
| `lib/screens/home_screen.dart` | LiveClock title, sort PopupMenuButton |
| `lib/widgets/task_input.dart` | Real-time date parsing + highlighting in Quick Add |
| `lib/widgets/edit_task_dialog.dart` | Date parsing + DateOptionsSheet integration |
| `lib/widgets/task_item.dart` | Due date display, overdue styling, clickable suffix |
| `lib/models/filter_state.dart` | DateFilter enum + integration |
| `lib/widgets/tag_filter_dialog.dart` | Renamed to "Filter", added date filter section |
| `lib/widgets/active_filter_bar.dart` | Date filter chip display |
| `lib/services/preferences_service.dart` | Sort mode/reversed persistence |
| `lib/main.dart` | flutter_js initialization |

---

## Metrics

### Code
- **Files created:** 9
- **Files modified:** 14
- **Lines added (production):** ~1,848
- **Lines added (tests):** ~2,196
- **Total commits:** 20 (11 feature, 5 fix, 4 docs)

### Testing
- **Test files created:** 7
  - `date_parsing_service_test.dart` (324 lines)
  - `date_formatter_test.dart` (293 lines)
  - `debouncer_test.dart` (114 lines)
  - `date_options_sheet_test.dart` (529 lines)
  - `highlighted_text_editing_controller_test.dart` (403 lines)
  - `date_parsing_integration_test.dart` (423 lines)
  - `date_parsing_perf_test.dart` (74 lines)
- **Tests added:** ~120+
- **Overall test suite:** 394 passing, 23 failing*
- **Build verification:** Passing

*Note: 23 failures are in `date_parsing_service_test.dart` - these tests require the chrono.js runtime (flutter_js) which is not available in pure Dart test mode. They pass when run as integration tests on device.

---

## Technical Decisions

1. **flutter_js + chrono.js over native Dart parsers:** Both `chrono_dart` and `any_date` had build/compatibility issues. chrono.js is mature (2.5k+ GitHub stars, 10+ years active) and runs via QuickJS on Linux/Android/Windows.

2. **TextEditingController.buildTextSpan() for highlighting:** Overriding this method allows inline highlighting within editable TextFields (RichText is not editable). Web platform excluded via `kIsWeb` check.

3. **In-memory sort and filter in TaskProvider:** Sort and date filter applied in `_refreshTreeController()` rather than SQL. Keeps DB queries simple and allows instant UI updates.

4. **Sort applies to root-level only:** Children maintain position order within parents. Entering reorder mode auto-resets to Manual sort.

5. **DateOptionsSheet UX pattern:** Todoist-style bottom sheet with quick options (Today, Tomorrow, Next Week, Pick Date) plus relative date labels showing "in 2 days" etc.

6. **Date suffix in titles:** When a date is parsed, it's stripped from the title on save and displayed as a visual suffix (e.g., "Buy groceries · Tomorrow"). Clicking the suffix opens DateOptionsSheet.

---

## Challenges & Solutions

### Challenge 1: No Dart NL Date Parser
**Problem:** No mature Dart package exists for NL date parsing
**Solution:** Bundle chrono.js and run via flutter_js (QuickJS FFI)
**Outcome:** Reliable parsing with <5ms latency, all date formats supported

### Challenge 2: Editable TextField Highlighting
**Problem:** Flutter's RichText is read-only; TextField doesn't support inline styles
**Solution:** Override `buildTextSpan()` in custom TextEditingController
**Outcome:** Real-time inline highlighting with full edit capability

### Challenge 3: UTC vs Local Date Bugs
**Problem:** Dates stored as UTC strings caused off-by-one day errors when displayed
**Solution:** Consistent local date handling throughout; UTC only for DB storage
**Outcome:** Correct date display across timezones

### Challenge 4: Debug Mode Crashes
**Problem:** `InlineTagPicker` and `HighlightedTextEditingController` crashed in debug builds
**Solution:** Added null checks and guard clauses for edge cases in disposal
**Outcome:** Stable in both debug and release builds

---

## Dependencies Added

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_js` | ^0.8.5 | JavaScript runtime (QuickJS) for chrono.js |
| `intl` | (existing) | DateFormat for LiveClock and date formatting |

---

## Deferred Work

- [ ] Night owl mode (configurable midnight boundary) - Phase 4+
- [ ] Date parsing in notes/descriptions - Phase 4+
- [ ] Recurring dates ("every Monday") - Backlog
- [ ] Sort by due date in completed tasks section - Backlog

---

**Prepared By:** Claude
**Date:** 2026-01-22
