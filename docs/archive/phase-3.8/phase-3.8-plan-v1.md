# Phase 3.8 Plan - Due Date Notifications

**Version:** 1
**Created:** 2026-01-22
**Status:** Draft

---

## Scope

From `docs/PROJECT_SPEC.md`:

- flutter_local_notifications integration
- Notification scheduling (at time, 1 hour before, 1 day before)
- Platform-specific permissions (Android + iOS)
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

---

## Subphases

### 3.8.1: flutter_local_notifications Setup
- Add `flutter_local_notifications` package
- Add `timezone` and `flutter_timezone` packages (for scheduled notifications)
- Platform configuration (Android manifest, iOS plist)
- Initialize notification plugin at app startup
- Request permissions on first launch (with graceful decline)
- Basic notification service with send/cancel methods

### 3.8.2: Notification Scheduling Logic
- Schedule notifications when due date is set/updated
- Notification timing options:
  - At time (exact due date/time)
  - 1 hour before
  - 1 day before
  - Custom offset
- Reschedule on task update, cancel on task delete/complete
- Handle all-day tasks (notify at user's `defaultNotificationHour`)
- Today Window integration (respect user's effective "today" start)

### 3.8.3: Notification Preferences UI
- Per-task notification type in Edit Task Dialog (use_global / custom / none)
- Global default notification timing in Settings
- Quiet hours setting (start/end times, days of week)
- Permission status indicator + re-request button

### 3.8.4: Quick Actions & Polish
- Notification tap → open app to specific task
- Action buttons on notification (Complete, Snooze 1hr, Snooze 1day)
- Notification grouping (multiple tasks due at same time)
- Badge count (optional, platform-dependent)
- Handle app killed/restarted (persist scheduled notifications)

---

## Technical Approach

### Package Selection
- `flutter_local_notifications` - mature, well-maintained, cross-platform
- `timezone` + `flutter_timezone` - TZ-aware scheduling
- No Firebase/push notifications needed (all local)

### Architecture
- New `NotificationService` singleton (mirrors `DateParsingService` pattern)
- Integrates with `TaskService` - schedule/cancel on task CRUD operations
- Reads `UserSettings` for defaults and quiet hours
- Platform channel for Android notification channels

### Platform Considerations
- **Android 13+**: POST_NOTIFICATIONS runtime permission required
- **Android <13**: Automatic permission
- **iOS**: Request permission via flutter_local_notifications
- **Linux**: Not natively supported - skip or use desktop_notifications package
- **Web**: Not applicable

### Quiet Hours
- Store start/end times in UserSettings
- Before scheduling, check if notification time falls in quiet hours
- If so, delay to first moment after quiet hours end
- Default: disabled (null start/end)

---

## Dependencies

- `flutter_local_notifications: ^18.x` (latest stable)
- `timezone: ^0.9.x`
- `flutter_timezone: ^3.x`
- Existing: Task model, UserSettings model, database schema (all ready)

---

## Open Questions

1. **Linux support:** Skip notifications entirely on Linux, or use a desktop notification package? (Pin and Paper is primarily mobile-first)
  - What are pros/cons? Different distros will use different notif packages yes? What are our options here? 
2. **Snooze behavior:** When snoozed, does it create a new notification or modify the existing scheduled one?
  - What are best practices here for mobile apps like ours? 
3. **Overdue notifications:** Should tasks that become overdue trigger a notification, or only pre-due-date reminders?
  - overdue tasks should ONLY trigger a notification if user configs this as a preference in their notification settings in app (or per-task as a one-off) - NOTE - I am highly in favor of per-task configuration for these. 
4. **Multiple reminders per task:** Allow stacking (e.g., both 1 day before AND 1 hour before)?
  - Yes let's allow stacking
5. **Notification sound/vibration:** Custom or system default?
  - System default to start. Add custom config to the docs/PROJECT_SPEC.md doc as a future improvement. 
6. **Child tasks:** Are there any issues we might run into here? 
  - Explore several logical ux/ui scenarios

---

## Risks

- Permission denial on first prompt → user never gets notifications. Mitigate with clear explanation UI and re-request button in settings.
- Timezone changes (travel) → stale scheduled notifications. Mitigate by rescheduling on app resume.
- Device reboot clears scheduled notifications on some Android OEMs. Mitigate with boot receiver or re-check on app open.

---

## Success Criteria

- Tasks with due dates trigger timely notifications
- Notifications are cancelable per-task and globally
- Quiet hours respected
- Tapping notification navigates to the task
- Quick actions (complete/snooze) work from notification
- No battery drain (scheduled alarms, not polling)
