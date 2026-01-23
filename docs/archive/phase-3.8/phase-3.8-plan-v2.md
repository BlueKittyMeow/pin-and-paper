# Phase 3.8 Plan - Due Date Notifications

**Version:** 2
**Created:** 2026-01-22
**Status:** Draft (Open questions resolved)

---

## Scope

From `docs/PROJECT_SPEC.md`:

- flutter_local_notifications integration
- Notification scheduling (at time, 1 hour before, 1 day before)
- Platform-specific permissions (Android + iOS + Linux)
- Quick actions from notifications
- Quiet hours setting

---

## Existing Scaffolding

Phase 3.1 already added notification fields to the data layer:

**Task model** (`lib/models/task.dart`):
- `notificationType`: 'use_global' | 'custom' | 'none'
- `notificationTime`: Custom notification DateTime (nullable)

**UserSettings model** (`lib/models/user_settings.dart`):
- `defaultNotificationHour`: Default 9
- `defaultNotificationMinute`: Default 0

**Database schema** (`lib/services/database_service.dart`):
- `notification_type TEXT DEFAULT 'use_global'`
- `notification_time INTEGER`
- `default_notification_hour INTEGER DEFAULT 9`
- `default_notification_minute INTEGER DEFAULT 0`

**Note:** The existing schema supports single notification time per task. For stacked reminders (multiple per task), we'll need a new table or serialized list field. See Schema Changes section.

---

## Resolved Design Decisions

### 1. Linux Support: YES (minimal effort)

`flutter_local_notifications` supports Linux natively via `flutter_local_notifications_linux` (D-Bus/freedesktop notifications standard). Works across GNOME, KDE, XFCE, etc. - all implement the same D-Bus protocol.

**What works:** Immediate notifications (show when app is running)
**What doesn't:** Scheduled notifications (no OS-level scheduler on Linux)
**Effort:** ~10-20 extra lines of initialization code (LinuxInitializationSettings)
**Workaround for scheduling:** On Linux, check pending notifications on app startup and fire any that are overdue. Not ideal but functional for desktop use.

### 2. Snooze: Cancel + Reschedule

Standard pattern: cancel the current notification immediately, schedule a new one at the snoozed time. No modification API exists in flutter_local_notifications.

**Snooze options:**
- 15 minutes
- 30 minutes
- 1 hour
- 3 hours
- Tomorrow morning (user's `defaultNotificationHour`)
- Custom (open DateOptionsSheet)

**No snooze limit.** Time-bounded options naturally prevent indefinite postponement.

### 3. Overdue Notifications: Opt-in, Per-Task

Overdue notifications are OFF by default. Users can enable:
- **Globally:** In Settings → Notifications → "Notify when tasks become overdue"
- **Per-task:** Override in Edit Task → Notification → "Notify if overdue"

Per-task configuration takes priority over global setting.

### 4. Multiple Reminders: Stacked

A single task can have multiple reminder times (e.g., 1 day before AND 1 hour before AND at time). This requires a schema change from the single `notification_time` field to a list.

### 5. Sound/Vibration: System Default

Use system default sound and vibration. Custom notification sounds deferred to a future phase (add to PROJECT_SPEC.md as future enhancement).

### 6. Child Tasks: Independent Notifications

**Design principle:** Each task's notifications are independent. No inheritance.

**Scenarios explored:**

| Scenario | Behavior |
|----------|----------|
| Parent has due date, child has no due date | Only parent notifies. Child has no notification. |
| Parent has due date, child has own due date | Both notify independently at their own times. |
| Parent completed → child notifications? | Only parent notification canceled. Child notifications remain active (children are independent). |
| All children completed → parent notification? | Parent notification stays until parent itself is completed. |
| Child snoozed → parent? | Independent. No effect on parent. |
| Multiple children due at similar times | Grouped notification: "3 tasks due soon" with individual items. |

**Future UX enhancement (logged in FEATURE_REQUESTS.md):**
- Parent notification card could show child tasks (each clickable)
- "Complete all child tasks" option with double-verify confirmation

**Notification storm mitigation:** When 3+ tasks are due within a 30-minute window, group into a single summary notification with expandable items (Android notification groups / iOS grouped notifications).

---

## Subphases

### 3.8.1: Package Setup & Initialization
- Add `flutter_local_notifications` package (includes Linux support)
- Add `timezone` and `flutter_timezone` packages
- Platform configuration:
  - Android: notification channel in manifest, POST_NOTIFICATIONS permission
  - iOS: notification permission request
  - Linux: LinuxInitializationSettings with D-Bus
- Initialize notification plugin at app startup
- Request permissions on first launch (with explanation dialog)
- Basic `NotificationService` singleton with show/cancel/initialize methods

### 3.8.2: Schema Changes & Notification Scheduling
- **Schema migration:** Replace single `notification_time` with `task_reminders` table:
  ```sql
  CREATE TABLE task_reminders (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    reminder_type TEXT NOT NULL,  -- 'at_time', 'before_1h', 'before_1d', 'before_custom', 'overdue'
    offset_minutes INTEGER,       -- For custom: minutes before due date
    enabled INTEGER DEFAULT 1,
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
  );
  ```
- Schedule notifications when due date is set/updated
- Reschedule all reminders on task update
- Cancel all reminders on task delete/complete
- Handle all-day tasks: notify at user's `defaultNotificationHour` on the reminder day
- Today Window integration: respect effective "today" for overdue calculations

### 3.8.3: Notification Preferences UI
- **Per-task:** Edit Task Dialog → Notification section
  - Toggle: Use global / Custom / None
  - If Custom: Multi-select reminder times (at time, 1h before, 1d before, custom)
  - Toggle: Notify if overdue (per-task override)
- **Global defaults** in Settings → Notifications:
  - Default reminder timing (multi-select: at time, 1h before, 1d before)
  - Notify when overdue (global toggle, default OFF)
  - Quiet hours (start time, end time, days of week)
  - Permission status indicator + re-request button
- **Quiet hours logic:**
  - If notification would fire during quiet hours, delay to quiet hours end - NOT SURE ABOUT THIS actually - we should think more on this. 
  - Default: disabled (null start/end)

### 3.8.4: Quick Actions, Snooze & Polish
- Notification tap → open app, navigate to specific task (deep link by task ID)
- Action buttons:
  - "Complete" → mark task done, cancel remaining reminders
  - "Snooze" → show snooze options (15m, 30m, 1h, 3h, tomorrow, custom)
  - "Cancel notifications" -> cancels all upcoming reminders for the task
- Notification grouping (3+ tasks due within 30 min → summary notification)
- Handle app restart: on startup, check for missed notifications and fire/group them
- Linux fallback: on app open, check overdue scheduled items and show immediately
- Badge count: use `flutter_local_notifications` badge support (Android/iOS only)

---

## Technical Approach

### Package Selection
- `flutter_local_notifications: ^18.x` - cross-platform (Android, iOS, Linux)
- `timezone: ^0.9.x` - TZ-aware DateTime
- `flutter_timezone: ^3.x` - detect device timezone
- No Firebase needed (all local)

### Architecture

```
NotificationService (singleton)
├── initialize() - plugin setup, permissions
├── scheduleReminders(Task) - schedule all reminder notifications for a task
├── cancelReminders(Task) - cancel all notifications for a task
├── rescheduleAll() - recalculate on timezone change or app resume
├── snooze(notificationId, Duration) - cancel + reschedule
├── handleAction(action) - process Complete/Snooze from notification
└── checkMissed() - Linux/restart: fire overdue notifications
```

- Integrates with `TaskService` - called on create/update/delete/complete
- Reads `UserSettings` for global defaults and quiet hours
- Reads `task_reminders` table for per-task configuration
- Uses Android notification channels (one channel: "Task Reminders")

### Platform Matrix

| Feature | Android | iOS | Linux |
|---------|---------|-----|-------|
| Immediate notifications | Yes | Yes | Yes |
| Scheduled notifications | Yes (zonedSchedule) | Yes (zonedSchedule) | No (check on app open) |
| Actions (Complete/Snooze) | Yes | Yes | Varies by DE |
| Badge count | Yes | Yes | No |
| Notification grouping | Yes | Yes | No |
| Quiet hours | App-level | App-level | App-level |
| Permission required | Android 13+ | Always | No |

### Notification ID Strategy

Each task can have multiple reminders. Notification IDs need to be deterministic and unique:
```dart
// Encode task ID hash + reminder type into a 32-bit int
int getNotificationId(String taskId, String reminderType) {
  return (taskId.hashCode & 0xFFFF) << 16 | reminderType.hashCode & 0xFFFF;
}
```

---

## Dependencies

- `flutter_local_notifications: ^18.x`
- `timezone: ^0.9.x`
- `flutter_timezone: ^3.x`
- Existing: Task model, UserSettings, database_service (schema migration needed)

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Permission denied on first prompt | No notifications ever | Explanation dialog + re-request in Settings |
| Timezone change (travel) | Stale scheduled times | Reschedule all on app resume / TZ change |
| Device reboot (Android OEM) | Lost scheduled notifications | Re-check on app open, reschedule if missing |
| Notification ID collision | Wrong task opened | Use deterministic hash strategy, test thoroughly |
| Too many notifications (storm) | User disables all | Grouping when 3+ in 30-min window |
| Linux no scheduling | Missed reminders on desktop | Check + fire on app open, document limitation |

---

## Future Enhancements (deferred)

- Custom notification sounds (per Phase 3.9 preferences)
- Location-based reminders ("remind me when I get home")
- Recurring task notifications
- Widget showing upcoming due tasks
- Wear OS / watchOS notification mirroring

---

## Success Criteria

- Tasks with due dates trigger timely notifications (at configured times)
- Multiple stacked reminders per task work correctly
- Overdue notifications only fire when user opts in (global or per-task)
- Notifications are cancelable per-task and globally
- Quiet hours respected (delayed, not dropped)
- Tapping notification navigates to the specific task
- Quick actions (Complete/Snooze) work from notification tray
- Snooze reschedules correctly with chosen interval
- Notification grouping prevents notification storms
- No battery drain (scheduled alarms, not polling)
- Linux shows notifications when app is open (graceful degradation)
- Works after app restart / device reboot
