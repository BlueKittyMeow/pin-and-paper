# Codex Validation - Phase 3.8

**Phase:** 3.8 - Due Date Notifications
**Implementation Report:** [phase-3.8-implementation-report.md](./phase-3.8-implementation-report.md)
**Validation Doc:** [phase-3.8-validation-v1.md](./phase-3.8-validation-v1.md)
**Phase Summary:** [phase-3.8-summary.md](./phase-3.8-summary.md)
**Review Date:** 2026-01-23
**Reviewer:** Codex
**Status:** Complete

---

## Purpose

This document is for **Codex** to validate Phase 3.8 **after implementation is complete**.

Phase 3.8 adds a full notification system for task due dates. The implementation spans 5 subphases and introduces 5 new files plus significant modifications to existing services and UI.

**NEVER SIMULATE OTHER AGENTS' RESPONSES.**
Only document YOUR OWN findings here.

**RECORD ONLY - DO NOT MODIFY CODE**
- Your job is to **record findings to THIS file only**
- Do NOT make any changes to the codebase
- Claude will review your findings and implement fixes separately

---

## Reference Documents

Please review these docs for context before diving into code:
- **Implementation Report:** `docs/phase-3.8/phase-3.8-implementation-report.md` — Full breakdown of all 5 subphases, decisions, and architecture
- **Plan (final):** `docs/phase-3.8/phase-3.8-plan-v2.md` — Original design decisions and scope
- **Implementation Plan:** `docs/phase-3.8/phase-3.8-implementation-plan.md` — Detailed code-level plan with pseudocode
- **Your pre-implementation findings:** `docs/phase-3.8/codex-findings.md` — Issues you raised before implementation

---

## Validation Scope

**New files to review (most critical):**
- [ ] `lib/models/task_reminder.dart` — ReminderType constants, TaskReminder model, notification ID generation
- [ ] `lib/services/notification_service.dart` — Platform wrapper, initialization, scheduling, actions
- [ ] `lib/services/reminder_service.dart` — Core scheduling logic, quiet hours, overdue detection, snooze
- [ ] `lib/widgets/permission_explanation_dialog.dart` — Permission request UI
- [ ] `lib/widgets/snooze_options_sheet.dart` — Snooze presets bottom sheet

**Modified files to review:**
- [ ] `lib/models/user_settings.dart` — 8 new notification preference fields
- [ ] `lib/services/database_service.dart` — v9 + v10 migrations
- [ ] `lib/providers/task_provider.dart` — Notification lifecycle hooks on CRUD
- [ ] `lib/screens/settings_screen.dart` — Notifications card UI
- [ ] `lib/widgets/edit_task_dialog.dart` — Per-task notification section
- [ ] `lib/screens/home_screen.dart` — Notification action callbacks
- [ ] `lib/services/task_service.dart` — notificationType parameter
- [ ] `lib/main.dart` — checkMissed() on startup

---

## Key Areas to Focus On

### 1. ReminderService Scheduling Logic (HIGHEST PRIORITY)
The brain of the system. Please verify:
- `_scheduleRemindersInternal()` correctly computes notification times for all reminder types
- `_adjustForQuietHours()` handles cross-midnight correctly (start > end in minutes)
- `_isTaskOverdue()` correctly uses the user's todayCutoffHour/Minute (especially the "before noon = next calendar day" logic)
- `rescheduleAll()` doesn't have race conditions with the `_isRescheduling` flag
- `snooze()` duration sentinels (-1h = "Tomorrow", 0 = custom) are handled safely
- `checkMissed()` won't spam notifications on every app launch (only fires for genuinely overdue tasks)
- The `notificationsEnabled` master toggle correctly gates all scheduling paths

### 2. Notification ID Determinism
- IDs are: `'${taskId}_global_${type}'.hashCode.abs() % (1 << 31)`
- Verify: no collision risks, IDs survive app restart, cancel uses same ID formula
- Edge case: what happens if `hashCode` returns negative? (`.abs()` handles it, but verify no overflow)

### 3. TaskProvider Lifecycle Hooks
- Every CRUD operation correctly schedules/cancels notifications
- `deleteTaskWithConfirmation` cascade: BFS descendant collection is correct
- `toggleTaskCompletion`: completing cancels, uncompleting reschedules
- Exception handling: notification failures don't block task operations (wrapped in try/catch)

### 4. Circular Dependency Resolution
- NotificationService uses callback fields (`onSnoozeRequested`, `onCompleteRequested`, etc.)
- Callbacks are wired in HomeScreen.initState
- Verify: what happens if callbacks are null when a notification action fires? (e.g., app opened from notification before HomeScreen builds)

### 5. Database Migrations
- v9: task_reminders table + 6 columns on user_settings
- v10: notifications_enabled column
- Verify: fresh install schema matches end-state of migrations
- Verify: no data loss if user has existing data

### 6. Race Conditions & Async Safety
- Multiple rapid settings changes trigger multiple `rescheduleAll()` calls — is this safe?
- `checkMissed()` runs on startup while UI is building — any interaction issues?
- Snooze from notification while app is in background — callback wiring timing

---

## Also Raise Any Concerns About

- **Anything else you notice** — code quality, potential bugs, architectural issues, missing error handling, etc.
- **Issues from your pre-implementation findings** (codex-findings.md) that may not have been addressed
- **Test coverage gaps** — what's not tested that should be?

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
- [ ] Foreign key relationships maintained
- [ ] No potential data loss scenarios
- [ ] State management consistent (no stale state)

### Performance
- [ ] No N+1 query patterns
- [ ] No unnecessary widget rebuilds
- [ ] No inefficient loops or algorithms
- [ ] Database indexes used appropriately
- [ ] No blocking operations on UI thread

### Security
- [ ] Input validation on user data
- [ ] No sensitive data logged or exposed

---

## Methodology

```bash
# View all Phase 3.8 changes
git diff main..phase-3.8 -- pin_and_paper/lib/

# Review specific new files
cat pin_and_paper/lib/services/reminder_service.dart
cat pin_and_paper/lib/services/notification_service.dart
cat pin_and_paper/lib/models/task_reminder.dart

# Check the migrations
grep -A 50 "_migrateToV9" pin_and_paper/lib/services/database_service.dart
grep -A 15 "_migrateToV10" pin_and_paper/lib/services/database_service.dart

# Check lifecycle hooks in TaskProvider
grep -A 5 "reminderService\|_reminderService\|ReminderService" pin_and_paper/lib/providers/task_provider.dart

# Check fresh install schema matches migration end-state
grep -A 30 "CREATE TABLE.*userSettingsTable" pin_and_paper/lib/services/database_service.dart
```

---

## Findings

_Review the files above and add issues using this format:_

### Issue Format

```markdown
### Issue #[N]: [Brief Title]

**File:** `path/to/file.dart:line`
**Type:** [Bug / Performance / Architecture / Security / Test Coverage]
**Severity:** [CRITICAL / HIGH / MEDIUM / LOW]

**Description:**
[What's wrong and why it matters]

**Current Code:**
[Problematic code snippet]

**Suggested Fix:**
[How to fix it]

**Impact:**
[What breaks if not fixed]
```

---

## [Your findings go here]

### Issue #1: Notification permission never requested

**File:** `pin_and_paper/lib/screens/settings_screen.dart:258`
**Type:** Bug
**Severity:** HIGH

**Description:**
The notifications toggle updates settings and reschedules reminders, but the app never requests OS notification permission or shows the PermissionExplanationDialog. On iOS and Android 13+, users will not receive any notifications because permission is never requested.

**Current Code:**
```dart
onChanged: (value) {
  setState(() => _notificationsEnabled = value);
  _updateNotificationSettings();
},
```

**Suggested Fix:**
When enabling notifications, show `PermissionExplanationDialog.show(...)` and call `NotificationService().requestPermission()` before saving settings or scheduling. If permission is denied, revert the toggle and surface feedback.

**Impact:**
Notifications silently fail on permissioned platforms; core Phase 3.8 feature appears broken.

### Issue #2: checkMissed ignores overdue/quiet-hours preferences

**File:** `pin_and_paper/lib/services/reminder_service.dart:172`
**Type:** Bug
**Severity:** HIGH

**Description:**
`checkMissed()` claims to respect quiet hours and overdue settings, but it only checks `notificationsEnabled`. It will emit overdue notifications even if `notifyWhenOverdue` is off or the current time is within quiet hours.

**Current Code:**
```dart
if (!settings.notificationsEnabled) return []; // Master toggle off
...
if (_isTaskOverdue(task, settings, now)) {
  await _notificationService.showImmediate(...);
}
```

**Suggested Fix:**
Gate `checkMissed()` by `settings.notifyWhenOverdue` (and per-task overdue preferences if applicable) and skip immediate notifications when `_adjustForQuietHours(...)` would defer them.

**Impact:**
Users receive overdue notifications they explicitly disabled or during quiet hours.

### Issue #3: checkMissed spams overdue notifications on every launch

**File:** `pin_and_paper/lib/services/reminder_service.dart:172`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
`checkMissed()` has no dedupe/last-seen tracking. Any overdue task triggers a new immediate notification on every app start, which can quickly become noisy.

**Current Code:**
```dart
for (final taskMap in candidateTasks) {
  if (_isTaskOverdue(task, settings, now)) {
    await _notificationService.showImmediate(...);
  }
}
```

**Suggested Fix:**
Persist a last-notified timestamp (global or per-task) or record a "missed notification sent" marker to prevent repeats across launches.

**Impact:**
Overdue tasks generate repeated notifications on each app open.

### Issue #4: Custom reminder updates leave stale scheduled notifications

**File:** `pin_and_paper/lib/providers/task_provider.dart:857`
**Type:** Bug
**Severity:** HIGH

**Description:**
When editing a task, `setReminders()` or `deleteReminders()` is called before `cancelReminders()`. Since `cancelReminders()` relies on the current DB rows to find IDs, it cancels the newly written reminders instead of the previously scheduled ones. Old scheduled notifications are left active.

**Current Code:**
```dart
await _reminderService.setReminders(taskId, reminders);
...
await _reminderService.cancelReminders(taskId);
```

**Suggested Fix:**
Cancel first (using existing DB reminders), then update DB reminders, then reschedule. Alternatively, capture old reminder IDs before replacing them.

**Impact:**
Users can receive notifications for reminder settings that were removed or changed.

### Issue #5: Snoozed notifications are never canceled on task completion/deletion

**File:** `pin_and_paper/lib/services/reminder_service.dart:86`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
`cancelReminders()` cancels custom and global reminders, but does not cancel the snooze notification (`${taskId}_snooze`). Completing or deleting a task after snoozing can still trigger the snoozed alert.

**Current Code:**
```dart
final dbReminders = await getRemindersForTask(taskId);
...
final overdueId = '${taskId}_global_overdue'.hashCode.abs() % (1 << 31);
await _notificationService.cancel(overdueId);
```

**Suggested Fix:**
Also cancel the snooze ID inside `cancelReminders()` or persist snoozes in the reminders table.

**Impact:**
Completed/deleted tasks can still notify after snooze.

### Issue #6: Quiet-hours day parsing can throw on empty selection

**File:** `pin_and_paper/lib/services/reminder_service.dart:411`
**Type:** Bug
**Severity:** MEDIUM

**Description:**
`settings.quietHoursDays.split(',').map(int.parse)` will throw `FormatException` if the stored string is empty (possible if user deselects all days). That aborts scheduling/rescheduling.

**Current Code:**
```dart
final activeDays =
    settings.quietHoursDays.split(',').map(int.parse).toSet();
```

**Suggested Fix:**
Filter/trim empty values before parsing, or treat empty as “no quiet hours days.”

**Impact:**
Quiet-hours scheduling can crash and prevent notifications from rescheduling.

### Issue #7: Notification actions can be dropped on cold start

**File:** `pin_and_paper/lib/screens/home_screen.dart:32`
**Type:** Architecture
**Severity:** MEDIUM

**Description:**
Action callbacks are registered only after the first frame. If the app is launched from a notification action, the plugin can dispatch the response before HomeScreen sets callbacks, causing the action to be ignored.

**Current Code:**
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<TaskProvider>().loadTasks();
  _setupNotificationCallbacks();
});
```

**Suggested Fix:**
Register callbacks earlier (e.g., in main) and/or replay `getLaunchNotification()` once the UI is ready.

**Impact:**
Tapping “Complete/Snooze/Dismiss” on a cold start can do nothing.

### Issue #8: Notification IDs rely on hashCode stability

**File:** `pin_and_paper/lib/models/task_reminder.dart:71`
**Type:** Architecture
**Severity:** LOW

**Description:**
Notification IDs are derived from `String.hashCode`, which is not guaranteed stable across app restarts or platforms. If it changes, cancellation by ID will fail.

**Current Code:**
```dart
int get notificationId => id.hashCode.abs() % (1 << 31);
```

**Suggested Fix:**
Use a stable hash (crc32/xxhash) or persist a numeric notification ID in the DB.

**Impact:**
Potential inability to cancel previously scheduled notifications after restart.

---

## Summary

**Total Issues Found:** 8

**By Severity:**
- CRITICAL: 0
- HIGH: 3
- MEDIUM: 4
- LOW: 1

---

## Verdict

**Release Ready:** NO

**Must Fix Before Release:**
- Issue #1: Notification permission never requested
- Issue #2: checkMissed ignores overdue/quiet-hours preferences
- Issue #4: Custom reminder updates leave stale scheduled notifications

**Can Defer:**
- Issue #3: checkMissed spams overdue notifications on every launch
- Issue #5: Snoozed notifications are never canceled on task completion/deletion
- Issue #6: Quiet-hours day parsing can throw on empty selection
- Issue #7: Notification actions can be dropped on cold start
- Issue #8: Notification IDs rely on hashCode stability

---

**Review completed by:** Codex
**Date:** 2026-01-23
**Confidence level:** Medium
