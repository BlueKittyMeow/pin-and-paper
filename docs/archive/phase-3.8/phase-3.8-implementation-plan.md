# Phase 3.8 Implementation Plan - Due Date Notifications

**Version:** 3
**Created:** 2026-01-22
**Revised:** 2026-01-23 (v2: agent review findings; v3: self-review type/field/principle fixes)
**Status:** Ready for Implementation
**Reference:** `phase-3.8-plan-v2.md` (design decisions)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Subphase 3.8.1: Package Setup & Initialization](#subphase-381-package-setup--initialization)
3. [Subphase 3.8.2: Schema Changes & Notification Scheduling](#subphase-382-schema-changes--notification-scheduling)
4. [Subphase 3.8.3: Notification Preferences UI](#subphase-383-notification-preferences-ui)
5. [Subphase 3.8.4: Quick Actions, Snooze & Polish](#subphase-384-quick-actions-snooze--polish)
6. [Testing Strategy](#testing-strategy)
7. [Migration & Backward Compatibility](#migration--backward-compatibility)
8. [Platform Matrix](#platform-matrix)
9. [Risk Mitigations](#risk-mitigations)

---

## Architecture Overview

### Service Diagram

```
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ EditTaskDialog│  │SettingsScreen│  │  SnoozeSheet │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
└─────────┼──────────────────┼──────────────────┼─────────┘
          │                  │                  │
┌─────────▼──────────────────▼──────────────────▼─────────┐
│                     Provider Layer                        │
│  ┌────────────────────────────────────────────────────┐  │
│  │                  TaskProvider                       │  │
│  │  createTask() → scheduleReminders()                │  │
│  │  updateTask() → cancel + reschedule                │  │
│  │  toggleCompletion() → cancel or reschedule         │  │
│  │  deleteTask() → cancelReminders()                  │  │
│  └────────────────────────┬───────────────────────────┘  │
└───────────────────────────┼──────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────┐
│                     Service Layer                         │
│                                                           │
│  ┌─────────────────────┐    ┌──────────────────────────┐ │
│  │  ReminderService    │    │  NotificationService     │ │
│  │  (scheduling brain) │───▶│  (platform wrapper)      │ │
│  │                     │    │                          │ │
│  │ • computeTime()     │    │ • initialize()           │ │
│  │ • scheduleReminders │    │ • schedule(TZDateTime)   │ │
│  │ • cancelReminders() │    │ • cancel(id)             │ │
│  │ • rescheduleAll()   │    │ • requestPermission()    │ │
│  │ • checkMissed()     │    │ • onTap/onAction()      │ │
│  │ • isInQuietHours()  │    │                          │ │
│  └──────────┬──────────┘    └──────────────────────────┘ │
│             │                                             │
│  ┌──────────▼──────────┐    ┌──────────────────────────┐ │
│  │  TaskReminderDAO     │    │  UserSettingsService     │ │
│  │  (task_reminders     │    │  (notification prefs)    │ │
│  │   table CRUD)        │    │                          │ │
│  └──────────┬──────────┘    └──────────────────────────┘ │
└─────────────┼────────────────────────────────────────────┘
              │
┌─────────────▼────────────────────────────────────────────┐
│                     Data Layer                            │
│  ┌───────────────────────────────────────────────────┐   │
│  │              DatabaseService (SQLite)              │   │
│  │  tasks | task_reminders | user_settings           │   │
│  └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

### Data Flow: Task Created with Due Date

```
1. User saves task with due date in EditTaskDialog
2. TaskProvider.createTask() calls TaskService
3. TaskProvider checks task.notificationType:
   - 'none' → no scheduling
   - 'use_global' → read global defaults from UserSettings
   - 'custom' → read task_reminders for this task
4. ReminderService.scheduleReminders(task):
   a. Get reminder list (global defaults or task-specific)
   b. For each reminder:
      - Compute TZDateTime (due date ± offset, all-day handling)
      - Check quiet hours → push to end if needed
      - Check if time is in the past → skip
      - Call NotificationService.schedule(id, title, body, time)
5. Platform schedules alarm (Android AlarmManager / iOS UNNotification)
6. At scheduled time → notification appears
7. User taps → app opens → navigates to task
```

### Key Design Decisions

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| Quiet hours | Delay to quiet hours end; cross-midnight checks previous day | All config flows from user prefs |
| Notification IDs | `reminder.id.hashCode.abs() % (1 << 31)` | UUID-based, unique per reminder row |
| Existing `notificationType` | Keep | Still useful (use_global/custom/none) |
| Existing `notificationTime` | Obsolete, keep in schema | Backward compat, no migration risk |
| All-day overdue | After user's `todayCutoffHour:Minute` (not midnight) | Respects "user_midnight" concept |
| No hardcoded times | ALL notification times derived from user prefs | Never assume "9am" or "midnight" — always read from settings |
| Alert vs. state | Tasks MARKED overdue (data) but alerts suppressed in quiet hours | Users should never be woken by notifications |
| Quiet hours | Mandatory suppression of ALL alerts (including overdue) | Night owls with 4am end-of-day must not get 5am alerts |
| Snooze target | Uses `defaultNotificationHour` (user's preferred alert time) | Not semantically "morning" — it's the user's configured time |
| Timezone source | `UserSettings.timezoneId` ?? `FlutterTimezone.getLocalTimezone()` | Existing field, auto-detect fallback |
| Service pattern | Singleton (factory constructor) | Matches DateParsingService |
| Package versions | FLN ^19.5.0, timezone ^0.11.0, flutter_timezone ^5.0.1 | Latest stable as of Jan 2026 |
| Action buttons | All use `showsUserInterface: true` for v1 | Background isolate DB deferred |
| Exact alarms | `SCHEDULE_EXACT_ALARM` with runtime check + inexact fallback | Non-alarm app, user grants via Settings |
| cancelReminders | Also cancels computed global IDs (not just DB rows) | Prevents stale notifications |
| Trash restore | Reschedules reminders on restore if future due date | Prevents silent reminder loss |
| rescheduleAll | Uses `_isRescheduling` flag to prevent races | Serializes bulk vs per-task scheduling |

---

## Subphase 3.8.1: Package Setup & Initialization

### Files Changed

| File | Type | Description |
|------|------|-------------|
| `pubspec.yaml` | Modify | Add 3 dependencies |
| `android/app/build.gradle.kts` | Modify | compileSdk 35, desugaring, multiDex |
| `android/app/src/main/AndroidManifest.xml` | Modify | Permissions + receivers |
| `ios/Runner/AppDelegate.swift` | Modify | UNUserNotificationCenter delegate |
| `lib/utils/constants.dart` | Modify | DB version 9, table name, channel ID |
| `lib/services/notification_service.dart` | **New** | Core notification wrapper |
| `lib/widgets/permission_explanation_dialog.dart` | **New** | First-launch permission UI |
| `lib/main.dart` | Modify | Initialize NotificationService |

### 1.1 Package Dependencies

**`pubspec.yaml`** additions:

```yaml
dependencies:
  # Phase 3.8: Notifications
  flutter_local_notifications: ^19.5.0
  timezone: ^0.11.0
  flutter_timezone: ^5.0.1
```

### 1.2 Android Configuration

**`android/app/build.gradle.kts`:**

```kotlin
android {
    compileSdk = 35  // Was: flutter.compileSdkVersion (typically 34)

    defaultConfig {
        minSdk = 21  // Unchanged
        targetSdk = 35
        multiDexEnabled = true  // Add this
    }

    compileOptions {
        // Enable desugaring for java.time APIs used by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11  // Match existing project config
        targetCompatibility = JavaVersion.VERSION_11  // Match existing project config
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

**`android/app/src/main/AndroidManifest.xml`:**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Existing -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Phase 3.8: Notifications -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <application ...>
        <activity ...>
            ...
        </activity>

        <!-- Phase 3.8: Boot receiver for rescheduling after reboot -->
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>

        <!-- Phase 3.8: Scheduled notification receiver -->
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    </application>
</manifest>
```

### 1.3 iOS Configuration

**`ios/Runner/AppDelegate.swift`:**

Add to `application(_:didFinishLaunchingWithOptions:)`:

```swift
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Phase 3.8: Set notification delegate for foreground handling
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 1.4 Linux Configuration

No native file changes needed. `flutter_local_notifications` uses D-Bus on Linux automatically. Scheduled notifications are not supported on Linux (handled via `checkMissed()` fallback).

### 1.5 Constants Updates

**`lib/utils/constants.dart`:**

```dart
class AppConstants {
  // Database
  static const int databaseVersion = 9;  // Was: 8

  // Tables
  static const String taskRemindersTable = 'task_reminders';

  // Notification
  static const String notificationChannelId = 'pin_paper_task_reminders';
  static const String notificationChannelName = 'Task Reminders';
  static const String notificationChannelDescription = 'Notifications for upcoming task due dates';
  static const int notificationGroupThreshold = 3;  // Group when 3+ in 30-min window
  static const int notificationGroupWindowMinutes = 30;
  static const String notificationGroupKey = 'pin_paper_task_group';
}
```

### 1.6 NotificationService

**`lib/services/notification_service.dart`:**

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../utils/constants.dart';
import '../services/user_settings_service.dart';

/// Top-level background action handler (must be top-level or static)
/// NOTE: For v1, all actions use showsUserInterface: true so this handler
/// is primarily a safety net. True background handling (isolate DB access)
/// is deferred to a future polish phase (see FEATURE_REQUESTS.md).
@pragma('vm:entry-point')
void onBackgroundNotificationAction(NotificationResponse response) {
  debugPrint('[Notification] Background action: ${response.actionId}');
  // All actions handled in foreground via showsUserInterface: true
  // Future: implement SharedPreferences queueing for background execution
}

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  tz.Location? _localTimezone;

  /// Callback for handling notification taps in foreground
  /// Set by the app to enable navigation
  void Function(String? taskId)? onNotificationTapped;

  /// Initialize the notification plugin and timezone data
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz.initializeTimeZones();

    // Detect timezone: prefer user override from settings, fallback to device
    try {
      final settings = await UserSettingsService().getUserSettings();
      final timezoneName = settings.timezoneId
          ?? await FlutterTimezone.getLocalTimezone();
      _localTimezone = tz.getLocation(timezoneName);
      tz.setLocalLocation(_localTimezone!);
    } catch (e) {
      debugPrint('[NotificationService] Timezone detection failed: $e');
      _localTimezone = tz.getLocation('UTC');
      tz.setLocalLocation(_localTimezone!);
    }

    // Platform-specific initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,  // We request manually with explanation
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Pin and Paper',
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationAction,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialized with timezone: ${_localTimezone?.name}');
  }

  /// Create the Android notification channel
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    const channel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.high,
    );
    await androidPlugin.createNotificationChannel(channel);
  }

  /// Handle foreground notification tap/action
  void _onForegroundAction(NotificationResponse response) {
    debugPrint('[NotificationService] Foreground action: ${response.actionId}, payload: ${response.payload}');
    if (response.actionId == null || response.actionId!.isEmpty) {
      // Notification body tapped - navigate to task
      onNotificationTapped?.call(response.payload);
    }
    // Action-specific handling done by ReminderService
  }

  /// Request notification permission (call after showing explanation dialog)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    // Linux: no permission needed
    return true;
  }

  /// Check current permission status
  Future<bool> isPermissionGranted() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    // iOS: check via plugin
    // Linux: always true
    return true;
  }

  /// Check if exact alarm scheduling is permitted (Android 12+)
  /// SCHEDULE_EXACT_ALARM requires user to grant via Settings > Alarms & Reminders
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? true;
  }

  /// Schedule a notification at a specific TZDateTime
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (!_initialized) {
      debugPrint('[NotificationService] Not initialized, skipping schedule');
      return;
    }

    // Skip if time is in the past
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint('[NotificationService] Skipping past notification: $scheduledTime');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: AppConstants.notificationGroupKey,
      actions: actions,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    // Use exact scheduling if permitted, fall back to inexact otherwise
    // PERF NOTE: During rescheduleAll(), this is called per-notification.
    // Consider adding optional bool? exactAllowed param to avoid N platform
    // channel calls. For single-task scheduling this is negligible.
    final exactAllowed = await canScheduleExactAlarms();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      payload: payload,
      androidScheduleMode: exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,  // One-shot, not recurring
    );

    debugPrint('[NotificationService] Scheduled #$id at $scheduledTime');
  }

  /// Show an immediate notification (for missed/overdue on app open)
  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: AppConstants.notificationGroupKey,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: const LinuxNotificationDetails(),
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Cancel a specific notification by ID
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Get pending notification count (for badge)
  Future<int> getPendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  /// Get notification that launched the app (cold start)
  Future<NotificationResponse?> getLaunchNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse;
    }
    return null;
  }

  /// Get the local timezone location for TZDateTime creation
  tz.Location get localTimezone => _localTimezone ?? tz.UTC;

  /// Convert a DateTime to TZDateTime in local timezone
  tz.TZDateTime toLocalTZ(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, localTimezone);
  }

  /// Dispose (cleanup if needed)
  void dispose() {
    _initialized = false;
  }
}
```

### 1.7 Permission Explanation Dialog

**`lib/widgets/permission_explanation_dialog.dart`:**

```dart
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class PermissionExplanationDialog extends StatelessWidget {
  const PermissionExplanationDialog({super.key});

  /// Show the dialog and return whether permission was granted
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PermissionExplanationDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable Notifications'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pin and Paper can remind you about upcoming due dates so you never miss a deadline.',
          ),
          SizedBox(height: 12),
          Text(
            'You can configure when and how you receive reminders in Settings.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () async {
            final granted = await NotificationService().requestPermission();
            if (context.mounted) {
              Navigator.pop(context, granted);
            }
          },
          child: const Text('Enable'),
        ),
      ],
    );
  }
}
```

### 1.8 App Initialization

**`lib/main.dart`** - Add after DateParsingService initialization:

```dart
// Phase 3.8: Initialize notification service
try {
  final notificationService = NotificationService();
  await notificationService.initialize();
  debugPrint('[Phase 3.8] NotificationService initialized');
} catch (e) {
  debugPrint('[Phase 3.8] Failed to initialize NotificationService: $e');
  // Don't block app startup
}
```

### 1.9 Subphase 3.8.1 Acceptance Criteria

- [ ] App builds on Android, iOS, and Linux without errors
- [ ] `NotificationService().initialize()` completes without exception
- [ ] Timezone detection returns correct IANA timezone
- [ ] `showImmediate()` displays a notification on all platforms
- [ ] `requestPermission()` shows system dialog on Android 13+ and iOS
- [ ] `PermissionExplanationDialog` renders correctly
- [ ] Boot receiver declared in manifest (Android reboot survival)
- [ ] No runtime crashes on any platform

---

## Subphase 3.8.2: Schema Changes & Notification Scheduling

### Files Changed

| File | Type | Description |
|------|------|-------------|
| `lib/services/database_service.dart` | Modify | Migration v8→v9 |
| `lib/models/task_reminder.dart` | **New** | TaskReminder model |
| `lib/models/user_settings.dart` | Modify | New notification fields |
| `lib/services/reminder_service.dart` | **New** | Scheduling logic |
| `lib/services/task_service.dart` | Modify | Reminder CRUD methods |
| `lib/services/user_settings_service.dart` | Modify | New fields support |
| `lib/providers/task_provider.dart` | Modify | Notification lifecycle hooks |
| `lib/utils/constants.dart` | Modify | Reminder type constants |

### 2.1 Database Migration (v8 → v9)

**`lib/services/database_service.dart`** - Add migration method:

```dart
Future<void> _migrateToV9(Database db) async {
  await db.transaction((txn) async {
    // Create task_reminders table
    await txn.execute('''
      CREATE TABLE ${AppConstants.taskRemindersTable} (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        reminder_type TEXT NOT NULL,
        offset_minutes INTEGER,
        enabled INTEGER DEFAULT 1,
        FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
      )
    ''');

    // Performance indexes
    await txn.execute('''
      CREATE INDEX idx_task_reminders_task
      ON ${AppConstants.taskRemindersTable}(task_id)
    ''');
    await txn.execute('''
      CREATE INDEX idx_task_reminders_type
      ON ${AppConstants.taskRemindersTable}(task_id, reminder_type)
    ''');

    // Add notification settings to user_settings
    await txn.execute('''
      ALTER TABLE ${AppConstants.userSettingsTable}
      ADD COLUMN notify_when_overdue INTEGER DEFAULT 0
    ''');
    await txn.execute('''
      ALTER TABLE ${AppConstants.userSettingsTable}
      ADD COLUMN quiet_hours_enabled INTEGER DEFAULT 0
    ''');
    await txn.execute('''
      ALTER TABLE ${AppConstants.userSettingsTable}
      ADD COLUMN quiet_hours_start INTEGER DEFAULT NULL
    ''');
    await txn.execute('''
      ALTER TABLE ${AppConstants.userSettingsTable}
      ADD COLUMN quiet_hours_end INTEGER DEFAULT NULL
    ''');
    await txn.execute('''
      ALTER TABLE ${AppConstants.userSettingsTable}
      ADD COLUMN quiet_hours_days TEXT DEFAULT '0,1,2,3,4,5,6'
    ''');
    await txn.execute('''
      ALTER TABLE ${AppConstants.userSettingsTable}
      ADD COLUMN default_reminder_types TEXT DEFAULT 'at_time'
    ''');

    // Backfill: Migrate existing custom notification_time to task_reminders
    final customTasks = await txn.query(
      AppConstants.tasksTable,
      where: "notification_type = 'custom' AND notification_time IS NOT NULL",
    );
    for (final task in customTasks) {
      final taskId = task['id'] as String;
      await txn.insert(AppConstants.taskRemindersTable, {
        'id': '${taskId}_at_time_migrated',
        'task_id': taskId,
        'reminder_type': 'at_time',
        'offset_minutes': null,
        'enabled': 1,
      });
    }
  });
}
```

Update `_upgradeDB`:
```dart
if (oldVersion < 9) await _migrateToV9(db);
```

Also add the table to `_createDB` for fresh installs.

### 2.2 TaskReminder Model

**`lib/models/task_reminder.dart`:**

```dart
import 'package:uuid/uuid.dart';

/// Reminder types that can be scheduled for a task
class ReminderType {
  static const String atTime = 'at_time';       // At exact due time
  static const String before1h = 'before_1h';   // 1 hour before
  static const String before1d = 'before_1d';   // 1 day before
  static const String beforeCustom = 'before_custom'; // Custom offset
  static const String overdue = 'overdue';       // When task becomes overdue

  static const List<String> all = [atTime, before1h, before1d, beforeCustom, overdue];

  /// Human-readable label for UI display
  static String label(String type) {
    switch (type) {
      case atTime: return 'At due time';
      case before1h: return '1 hour before';
      case before1d: return '1 day before';
      case beforeCustom: return 'Custom';
      case overdue: return 'When overdue';
      default: return type;
    }
  }

  /// Offset in minutes for standard types (null for at_time/overdue)
  static int? defaultOffset(String type) {
    switch (type) {
      case before1h: return 60;
      case before1d: return 1440; // 24 * 60
      default: return null;
    }
  }
}

class TaskReminder {
  final String id;
  final String taskId;
  final String reminderType;  // One of ReminderType constants
  final int? offsetMinutes;   // For 'before_custom': minutes before due date
  final bool enabled;

  TaskReminder({
    String? id,
    required this.taskId,
    required this.reminderType,
    this.offsetMinutes,
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  /// Generate a deterministic notification ID for this reminder
  int get notificationId => id.hashCode.abs() % (1 << 31);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'reminder_type': reminderType,
      'offset_minutes': offsetMinutes ?? ReminderType.defaultOffset(reminderType),
      'enabled': enabled ? 1 : 0,
    };
  }

  factory TaskReminder.fromMap(Map<String, dynamic> map) {
    return TaskReminder(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      reminderType: map['reminder_type'] as String,
      offsetMinutes: map['offset_minutes'] as int?,
      enabled: (map['enabled'] as int?) != 0,
    );
  }

  TaskReminder copyWith({
    String? taskId,
    String? reminderType,
    int? offsetMinutes,
    bool? enabled,
  }) {
    return TaskReminder(
      id: id,
      taskId: taskId ?? this.taskId,
      reminderType: reminderType ?? this.reminderType,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      enabled: enabled ?? this.enabled,
    );
  }
}
```

### 2.3 UserSettings Updates

**`lib/models/user_settings.dart`** - Add fields:

```dart
// Phase 3.8: Notification preferences
final bool notifyWhenOverdue;       // Global: notify on overdue (default false)
final bool quietHoursEnabled;       // Quiet hours toggle
final int? quietHoursStart;         // Minutes from midnight (e.g., 1320 = 22:00)
final int? quietHoursEnd;           // Minutes from midnight (e.g., 420 = 07:00)
final String quietHoursDays;        // Comma-separated: "0,1,2,3,4,5,6" (0=Mon)
final String defaultReminderTypes;  // Comma-separated: "at_time,before_1h"
```

Add to `defaults()`:
```dart
notifyWhenOverdue: false,
quietHoursEnabled: false,
quietHoursStart: null,  // 22:00 when enabled
quietHoursEnd: null,    // 07:00 when enabled
quietHoursDays: '0,1,2,3,4,5,6',
defaultReminderTypes: 'at_time',
```

Add to `toMap()`, `fromMap()`, `copyWith()`.

### 2.4 ReminderService

**`lib/services/reminder_service.dart`:**

```dart
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import '../models/task_reminder.dart';
import '../models/user_settings.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../services/user_settings_service.dart';
import '../utils/constants.dart';

class ReminderService {
  // Singleton
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final NotificationService _notificationService = NotificationService();
  final UserSettingsService _userSettingsService = UserSettingsService();

  /// Prevents per-task scheduling during bulk rescheduleAll()
  bool _isRescheduling = false;

  // --- CRUD for task_reminders table ---

  /// Get all reminders for a task
  Future<List<TaskReminder>> getRemindersForTask(String taskId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      AppConstants.taskRemindersTable,
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    return maps.map((m) => TaskReminder.fromMap(m)).toList();
  }

  /// Set reminders for a task (replaces all existing)
  Future<void> setReminders(String taskId, List<TaskReminder> reminders) async {
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      // Delete existing
      await txn.delete(
        AppConstants.taskRemindersTable,
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      // Insert new
      for (final reminder in reminders) {
        await txn.insert(AppConstants.taskRemindersTable, reminder.toMap());
      }
    });
  }

  /// Delete all reminders for a task
  Future<void> deleteReminders(String taskId) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      AppConstants.taskRemindersTable,
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  // --- Scheduling Logic ---

  /// Schedule all notifications for a task based on its reminders
  Future<void> scheduleReminders(Task task) async {
    if (_isRescheduling) return; // Skip per-task during bulk reschedule
    final settings = await _userSettingsService.getUserSettings();
    await _scheduleRemindersInternal(task, settings);
  }

  /// Cancel all scheduled notifications for a task
  /// Handles both custom (DB-stored) and use_global (computed) reminders
  Future<void> cancelReminders(String taskId) async {
    // Cancel DB-stored reminders (custom type)
    final dbReminders = await getRemindersForTask(taskId);
    for (final reminder in dbReminders) {
      await _notificationService.cancel(reminder.notificationId);
    }

    // Also cancel global reminders (not in DB, computed from settings)
    // These use deterministic IDs based on taskId + type
    final settings = await _userSettingsService.getUserSettings();
    final globalTypes = settings.defaultReminderTypes.split(',');
    for (final type in globalTypes) {
      if (type.trim().isEmpty) continue;
      final globalId = '${taskId}_global_${type.trim()}'.hashCode.abs() % (1 << 31);
      await _notificationService.cancel(globalId);
    }
    // Cancel global overdue reminder too
    final overdueId = '${taskId}_global_overdue'.hashCode.abs() % (1 << 31);
    await _notificationService.cancel(overdueId);
  }

  /// Reschedule all notifications (timezone change, settings change, app resume)
  /// Uses _isRescheduling flag to prevent per-task scheduling from racing
  Future<void> rescheduleAll() async {
    _isRescheduling = true;
    try {
      await _notificationService.cancelAll();

      final db = await DatabaseService.instance.database;
      final settings = await _userSettingsService.getUserSettings();
      // Get all active tasks with due dates and notification_type != 'none'
      final tasks = await db.query(
        AppConstants.tasksTable,
        where: "deleted_at IS NULL AND completed = 0 AND due_date IS NOT NULL AND notification_type != 'none'",
      );

      for (final taskMap in tasks) {
        final task = Task.fromMap(taskMap);
        // Call scheduling logic directly (bypasses _isRescheduling guard)
        await _scheduleRemindersInternal(task, settings);
      }

      debugPrint('[ReminderService] Rescheduled notifications for ${tasks.length} tasks');
    } finally {
      _isRescheduling = false;
    }
  }

  /// Internal scheduling logic used by both scheduleReminders and rescheduleAll
  Future<void> _scheduleRemindersInternal(Task task, UserSettings settings) async {
    if (task.dueDate == null || task.completed || task.notificationType == 'none') return;

    final reminders = await _getEffectiveReminders(task, settings);
    for (final reminder in reminders) {
      if (!reminder.enabled) continue;
      final notifyTime = computeNotificationTime(task, reminder, settings);
      if (notifyTime == null) continue;
      final adjustedTime = _adjustForQuietHours(notifyTime, settings);
      final title = _buildNotificationTitle(task, reminder);
      final body = _buildNotificationBody(task, reminder);
      await _notificationService.schedule(
        id: reminder.notificationId,
        title: title,
        body: body,
        scheduledTime: adjustedTime,
        payload: task.id,
      );
    }
  }

  /// Check for missed notifications (Linux fallback, app restart)
  /// Respects user's end-of-day setting for all-day task overdue detection
  Future<List<Task>> checkMissed() async {
    final settings = await _userSettingsService.getUserSettings();
    final now = DateTime.now();

    final db = await DatabaseService.instance.database;
    // Query all active tasks with due dates and notifications enabled
    // (filtering by overdue is done in Dart to respect user's end-of-day)
    final candidateTasks = await db.query(
      AppConstants.tasksTable,
      where: "deleted_at IS NULL AND completed = 0 AND due_date IS NOT NULL "
             "AND notification_type != 'none'",
    );

    final missed = <Task>[];
    for (final taskMap in candidateTasks) {
      final task = Task.fromMap(taskMap);
      if (_isTaskOverdue(task, settings, now)) {
        missed.add(task);

        // Show immediate notification for missed reminders
        await _notificationService.showImmediate(
          id: task.id.hashCode.abs() % (1 << 31),
          title: 'Overdue: ${task.title}',
          body: 'This task was due ${_formatDueDate(task.dueDate!)}',
          payload: task.id,
        );
      }
    }

    if (missed.isNotEmpty) {
      debugPrint('[ReminderService] Found ${missed.length} missed notifications');
    }
    return missed;
  }

  /// Check if a task is actually overdue, respecting user's end-of-day setting
  /// Design principle: EVERYTHING flows from user preferences, no hardcoded
  /// midnight assumptions. The "user_midnight" concept means overdue is
  /// determined by the user's configured end-of-day time.
  bool _isTaskOverdue(Task task, UserSettings settings, DateTime now) {
    if (task.dueDate == null) return false;
    if (task.isAllDay) {
      // All-day task: overdue after user's end-of-day time on the due date
      // For a user with end-of-day at 4:00 AM, a task "due today" is not
      // overdue until 4:00 AM the next calendar day
      final endOfDay = DateTime(
        task.dueDate!.year, task.dueDate!.month, task.dueDate!.day,
        settings.todayCutoffHour, settings.todayCutoffMinute,
      );
      // If end-of-day is before noon (e.g., 4 AM), it means "next calendar day"
      final effectiveDeadline = settings.todayCutoffHour < 12
          ? endOfDay.add(const Duration(days: 1))
          : endOfDay;
      return now.isAfter(effectiveDeadline);
    } else {
      // Timed task: overdue after the exact due time
      return now.isAfter(task.dueDate!);
    }
  }

  // --- Computation Helpers ---

  /// Compute the exact notification time for a reminder
  tz.TZDateTime? computeNotificationTime(
    Task task,
    TaskReminder reminder,
    UserSettings settings,
  ) {
    if (task.dueDate == null) return null;

    final tz.TZDateTime baseTime;

    if (task.isAllDay) {
      // All-day tasks: use defaultNotificationHour on the due date
      baseTime = tz.TZDateTime(
        _notificationService.localTimezone,
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
        settings.defaultNotificationHour,
        settings.defaultNotificationMinute,
      );
    } else {
      // Timed tasks: use exact due date/time
      baseTime = _notificationService.toLocalTZ(task.dueDate!);
    }

    // Helper: TZDateTime.subtract()/add() return DateTime, not TZDateTime.
    // Must re-wrap to preserve timezone information.
    final loc = _notificationService.localTimezone;
    tz.TZDateTime offset(Duration d) => tz.TZDateTime.from(baseTime.subtract(d), loc);

    switch (reminder.reminderType) {
      case ReminderType.atTime:
        return baseTime;

      case ReminderType.before1h:
        return offset(const Duration(hours: 1));

      case ReminderType.before1d:
        return offset(const Duration(days: 1));

      case ReminderType.beforeCustom:
        if (reminder.offsetMinutes == null) return null;
        return offset(Duration(minutes: reminder.offsetMinutes!));

      case ReminderType.overdue:
        // 1 minute after due time (fires immediately once overdue)
        return tz.TZDateTime.from(baseTime.add(const Duration(minutes: 1)), loc);

      default:
        return null;
    }
  }

  /// Get effective reminders (global defaults or task-specific)
  Future<List<TaskReminder>> _getEffectiveReminders(
    Task task,
    UserSettings settings,
  ) async {
    if (task.notificationType == 'custom') {
      // Use task-specific reminders from DB
      return await getRemindersForTask(task.id);
    }

    // 'use_global' - build from global defaults
    final types = settings.defaultReminderTypes.split(',');
    final reminders = <TaskReminder>[];

    for (final type in types) {
      if (type.trim().isEmpty) continue;
      reminders.add(TaskReminder(
        id: '${task.id}_global_${type.trim()}',
        taskId: task.id,
        reminderType: type.trim(),
      ));
    }

    // Add overdue reminder if globally enabled
    if (settings.notifyWhenOverdue) {
      reminders.add(TaskReminder(
        id: '${task.id}_global_overdue',
        taskId: task.id,
        reminderType: ReminderType.overdue,
      ));
    }

    return reminders;
  }

  /// Adjust notification time for quiet hours
  /// NOTE: Quiet hours are highly user-configurable. All time boundaries
  /// flow from UserSettings - no hardcoded assumptions about day boundaries.
  tz.TZDateTime _adjustForQuietHours(tz.TZDateTime time, UserSettings settings) {
    if (!settings.quietHoursEnabled) return time;
    if (settings.quietHoursStart == null || settings.quietHoursEnd == null) return time;

    // Convert time to minutes from midnight
    final timeMinutes = time.hour * 60 + time.minute;
    final start = settings.quietHoursStart!;
    final end = settings.quietHoursEnd!;

    // Check if the day of week is in quiet hours days
    // For cross-midnight ranges (e.g., 22:00-07:00), the early-morning portion
    // (before 'end') belongs to the PREVIOUS day's quiet hours setting
    int dayOfWeek = time.weekday - 1; // Convert to 0=Mon format
    if (start > end && timeMinutes < end) {
      dayOfWeek = (dayOfWeek - 1 + 7) % 7; // Check previous day
    }
    final activeDays = settings.quietHoursDays.split(',').map(int.parse).toSet();
    if (!activeDays.contains(dayOfWeek)) return time;

    bool isInQuietHours;
    if (start < end) {
      // Same day: e.g., 22:00-23:00 (unusual but valid)
      isInQuietHours = timeMinutes >= start && timeMinutes < end;
    } else {
      // Crosses midnight: e.g., 22:00-07:00
      isInQuietHours = timeMinutes >= start || timeMinutes < end;
    }

    if (!isInQuietHours) return time;

    // Delay to quiet hours end
    tz.TZDateTime endTime;
    if (start < end || timeMinutes >= start) {
      // Same day or evening portion: end is next day
      final nextDay = time.add(const Duration(days: 1));
      endTime = tz.TZDateTime(
        _notificationService.localTimezone,
        nextDay.year, nextDay.month, nextDay.day,
        end ~/ 60, end % 60,
      );
    } else {
      // Early morning portion: end is today
      endTime = tz.TZDateTime(
        _notificationService.localTimezone,
        time.year, time.month, time.day,
        end ~/ 60, end % 60,
      );
    }

    debugPrint('[ReminderService] Quiet hours: delayed from $time to $endTime');
    return endTime;
  }

  /// Build notification title based on reminder type
  String _buildNotificationTitle(Task task, TaskReminder reminder) {
    switch (reminder.reminderType) {
      case ReminderType.atTime:
        return 'Due now';
      case ReminderType.before1h:
        return 'Due in 1 hour';
      case ReminderType.before1d:
        return 'Due tomorrow';
      case ReminderType.beforeCustom:
        final hours = (reminder.offsetMinutes ?? 0) ~/ 60;
        final mins = (reminder.offsetMinutes ?? 0) % 60;
        if (hours > 0 && mins > 0) return 'Due in ${hours}h ${mins}m';
        if (hours > 0) return 'Due in $hours hour${hours > 1 ? 's' : ''}';
        return 'Due in $mins minute${mins > 1 ? 's' : ''}';
      case ReminderType.overdue:
        return 'Overdue';
      default:
        return 'Reminder';
    }
  }

  /// Build notification body
  String _buildNotificationBody(Task task, TaskReminder reminder) {
    return task.title;
  }

  /// Format due date for display in missed notification
  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final diff = now.difference(dueDate);
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
  }
}
```

### 2.5 TaskProvider Integration Hooks

**`lib/providers/task_provider.dart`** - Add to existing methods:

```dart
final ReminderService _reminderService = ReminderService();

// In createTask(), after successful service call:
if (newTask.dueDate != null && newTask.notificationType != 'none') {
  try {
    await _reminderService.scheduleReminders(newTask);
  } catch (e) {
    debugPrint('[TaskProvider] Failed to schedule reminders: $e');
  }
}

// In updateTask(), after successful service call:
try {
  await _reminderService.cancelReminders(taskId);
  if (updatedTask.dueDate != null && updatedTask.notificationType != 'none') {
    await _reminderService.scheduleReminders(updatedTask);
  }
} catch (e) {
  debugPrint('[TaskProvider] Failed to reschedule reminders: $e');
}

// In toggleTaskCompletion(), after successful toggle:
try {
  if (updatedTask.completed) {
    await _reminderService.cancelReminders(task.id);
  } else if (updatedTask.dueDate != null &&
             updatedTask.dueDate!.isAfter(DateTime.now())) {
    await _reminderService.scheduleReminders(updatedTask);
  }
} catch (e) {
  debugPrint('[TaskProvider] Failed to update reminders on completion: $e');
}

// In deleteTaskWithConfirmation(), before soft delete:
try {
  await _reminderService.cancelReminders(taskId);
} catch (e) {
  debugPrint('[TaskProvider] Failed to cancel reminders on delete: $e');
}

// In restoreTask(), after successful restore:
try {
  final restoredTask = await _taskService.getTaskById(taskId);
  if (restoredTask != null &&
      restoredTask.dueDate != null &&
      restoredTask.dueDate!.isAfter(DateTime.now()) &&
      restoredTask.notificationType != 'none') {
    await _reminderService.scheduleReminders(restoredTask);
  }
} catch (e) {
  debugPrint('[TaskProvider] Failed to reschedule on restore: $e');
}
```

### 2.6 Subphase 3.8.2 Acceptance Criteria

- [ ] Database migrates cleanly from v8 to v9
- [ ] Fresh install creates task_reminders table
- [ ] Existing custom notification tasks are backfilled to task_reminders
- [ ] Creating a task with due date schedules notifications
- [ ] Updating a task's due date reschedules all reminders
- [ ] Completing a task cancels all its scheduled notifications
- [ ] Uncompleting a task with future due date reschedules
- [ ] Deleting a task cancels its notifications
- [ ] All-day tasks use defaultNotificationHour for timing
- [ ] Quiet hours delay works correctly (cross-midnight, same-day)
- [ ] `checkMissed()` finds and shows overdue notifications on app open
- [ ] Multiple reminder types per task schedule independently
- [ ] Overdue reminders only fire when enabled (global or per-task)

---

## Subphase 3.8.3: Notification Preferences UI

### Files Changed

| File | Type | Description |
|------|------|-------------|
| `lib/widgets/edit_task_dialog.dart` | Modify | Add Notifications section |
| `lib/screens/settings_screen.dart` | Modify | Add Notifications card |
| `lib/services/task_service.dart` | Modify | Accept notification params |
| `lib/providers/task_provider.dart` | Modify | Pass notification params |
| `lib/services/user_settings_service.dart` | Modify | Handle new fields |

### 3.1 Edit Task Dialog - Notification Section

**Insert after the Due Date section** (only visible when task has a due date):

```dart
// Phase 3.8: Notification section (only when due date is set)
if (_dueDate != null) ...[
  const Divider(height: 24),
  Text('Notifications', style: Theme.of(context).textTheme.titleSmall),
  const SizedBox(height: 8),

  // Notification type dropdown
  DropdownButtonFormField<String>(
    value: _notificationType,
    decoration: const InputDecoration(
      labelText: 'Reminder setting',
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    items: const [
      DropdownMenuItem(value: 'use_global', child: Text('Use global defaults')),
      DropdownMenuItem(value: 'custom', child: Text('Custom for this task')),
      DropdownMenuItem(value: 'none', child: Text('No reminders')),
    ],
    onChanged: (value) => setState(() => _notificationType = value!),
  ),

  // Custom reminder chips (when 'custom' selected)
  if (_notificationType == 'custom') ...[
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildReminderChip(ReminderType.atTime, 'At due time'),
        _buildReminderChip(ReminderType.before1h, '1 hour before'),
        _buildReminderChip(ReminderType.before1d, '1 day before'),
        // Custom offset chip with time picker would go here
      ],
    ),
  ],

  // Per-task overdue toggle
  SwitchListTile(
    title: const Text('Notify if overdue'),
    subtitle: const Text('Get reminded if task passes due date'),
    value: _notifyIfOverdue,
    onChanged: (value) => setState(() => _notifyIfOverdue = value),
    contentPadding: EdgeInsets.zero,
    dense: true,
  ),
],
```

**State variables to add:**
```dart
String _notificationType = 'use_global';
Set<String> _selectedReminderTypes = {};
bool _notifyIfOverdue = false;
```

**Initialize from task in `initState()`:**
```dart
_notificationType = widget.task.notificationType;
// Load custom reminders if needed (async)
if (_notificationType == 'custom') {
  _loadTaskReminders();
}
```

**Add to `_save()` return map:**
```dart
'notificationType': _notificationType,
'reminderTypes': _selectedReminderTypes.toList(),
'notifyIfOverdue': _notifyIfOverdue,
```

### 3.2 Settings Screen - Notifications Card

**Insert after "Task Display" section:**

```dart
// Phase 3.8: Notifications section
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),

        // Permission status
        FutureBuilder<bool>(
          future: NotificationService().isPermissionGranted(),
          builder: (context, snapshot) {
            final granted = snapshot.data ?? false;
            return ListTile(
              leading: Icon(
                granted ? Icons.notifications_active : Icons.notifications_off,
                color: granted ? Colors.green : Colors.red,
              ),
              title: Text(granted ? 'Notifications enabled' : 'Notifications disabled'),
              trailing: granted ? null : TextButton(
                onPressed: () async {
                  await PermissionExplanationDialog.show(context);
                  setState(() {}); // Refresh status
                },
                child: const Text('Enable'),
              ),
              contentPadding: EdgeInsets.zero,
            );
          },
        ),

        const Divider(),

        // Default reminder timing
        Text('Default reminders', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildDefaultReminderChip('at_time', 'At due time'),
            _buildDefaultReminderChip('before_1h', '1 hour before'),
            _buildDefaultReminderChip('before_1d', '1 day before'),
          ],
        ),

        const SizedBox(height: 16),

        // Notify when overdue (global)
        SwitchListTile(
          title: const Text('Notify when overdue'),
          subtitle: const Text('Get reminded when tasks pass their due date'),
          value: _notifyWhenOverdue,
          onChanged: (value) {
            setState(() => _notifyWhenOverdue = value);
            _updateNotificationSettings();
          },
          contentPadding: EdgeInsets.zero,
        ),

        const Divider(),

        // Quiet hours
        SwitchListTile(
          title: const Text('Quiet hours'),
          subtitle: const Text('Delay notifications during set times'),
          value: _quietHoursEnabled,
          onChanged: (value) {
            setState(() => _quietHoursEnabled = value);
            _updateNotificationSettings();
          },
          contentPadding: EdgeInsets.zero,
        ),

        if (_quietHoursEnabled) ...[
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Start'),
                  subtitle: Text(_formatMinutesFromMidnight(_quietHoursStart)),
                  onTap: () => _pickQuietHoursTime(isStart: true),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('End'),
                  subtitle: Text(_formatMinutesFromMidnight(_quietHoursEnd)),
                  onTap: () => _pickQuietHoursTime(isStart: false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          // Day-of-week chips
          Wrap(
            spacing: 4,
            children: List.generate(7, (i) => _buildDayChip(i)),
          ),
        ],

        const SizedBox(height: 16),

        // Test notification button
        OutlinedButton.icon(
          onPressed: () async {
            await NotificationService().showImmediate(
              id: 0,
              title: 'Test Notification',
              body: 'Pin and Paper notifications are working!',
            );
          },
          icon: const Icon(Icons.notifications_none, size: 18),
          label: const Text('Send Test Notification'),
        ),
      ],
    ),
  ),
),
```

### 3.3 TaskService Updates

**`lib/services/task_service.dart`** - Update `updateTask()` signature:

```dart
Future<Task> updateTask(
  String taskId, {
  required String title,
  DateTime? dueDate,
  bool isAllDay = true,
  String? notes,
  String? notificationType,  // NEW
}) async {
  // ... existing update logic ...

  // Add notification_type to update map if provided
  if (notificationType != null) {
    updateMap['notification_type'] = notificationType;
  }

  // ... rest of method ...
}
```

### 3.4 TaskProvider Updates

**`lib/providers/task_provider.dart`** - Update `updateTask()`:

```dart
Future<void> updateTask({
  required String taskId,
  required String title,
  DateTime? dueDate,
  bool isAllDay = true,
  String? notes,
  required List<String> tagIds,
  String? notificationType,    // NEW
  List<String>? reminderTypes, // NEW
  bool? notifyIfOverdue,       // NEW
}) async {
  // ... existing logic ...

  // Handle reminder types if custom
  if (notificationType == 'custom' && reminderTypes != null) {
    final reminders = reminderTypes.map((type) => TaskReminder(
      taskId: taskId,
      reminderType: type,
    )).toList();

    // Add overdue if per-task enabled
    if (notifyIfOverdue == true) {
      reminders.add(TaskReminder(
        taskId: taskId,
        reminderType: ReminderType.overdue,
      ));
    }

    await _reminderService.setReminders(taskId, reminders);
  }

  // Reschedule notifications (existing hook from 3.8.2)
  // ...
}
```

### 3.5 Subphase 3.8.3 Acceptance Criteria

- [ ] Edit Task Dialog shows notification section when due date is set
- [ ] Notification type dropdown (use_global/custom/none) works
- [ ] Custom reminder chips are multi-selectable
- [ ] Per-task overdue toggle persists to task_reminders table
- [ ] Settings shows correct permission status
- [ ] Permission request flow works (explanation → system prompt)
- [ ] Default reminder types are saved and applied to new tasks
- [ ] Quiet hours start/end time pickers work
- [ ] Quiet hours day-of-week chips toggle correctly
- [ ] "Send Test Notification" displays a notification
- [ ] Changing global defaults triggers `rescheduleAll()`

---

## Subphase 3.8.4: Quick Actions, Snooze & Polish

### Files Changed

| File | Type | Description |
|------|------|-------------|
| `lib/services/notification_service.dart` | Modify | Add action buttons |
| `lib/services/reminder_service.dart` | Modify | Snooze logic, grouping |
| `lib/widgets/snooze_options_sheet.dart` | **New** | Snooze picker bottom sheet |
| `lib/main.dart` | Modify | Cold-start handling, checkMissed |
| `lib/providers/task_provider.dart` | Modify | Navigation callback |

### 4.1 Notification Action Buttons

**Update `NotificationService.schedule()`** to include actions:

```dart
// Android actions
// All actions use showsUserInterface: true to bring app to foreground.
// Background isolate handling deferred to future polish (see FEATURE_REQUESTS.md).
final androidActions = <AndroidNotificationAction>[
  const AndroidNotificationAction(
    'complete',
    'Complete',
    showsUserInterface: true,
  ),
  const AndroidNotificationAction(
    'snooze',
    'Snooze',
    showsUserInterface: true,
  ),
  const AndroidNotificationAction(
    'cancel_all',
    'Cancel',
    showsUserInterface: true,
  ),
];
```

**iOS actions** - Defined via notification categories in initialization:

```dart
// In initialize(), add category configuration:
const completeCat = DarwinNotificationCategory(
  'taskReminder',
  actions: [
    DarwinNotificationAction.plain('complete', 'Complete'),
    DarwinNotificationAction.plain('snooze', 'Snooze'),
    DarwinNotificationAction.plain('cancel_all', 'Cancel'),
  ],
);

// Pass to DarwinInitializationSettings:
DarwinInitializationSettings(
  notificationCategories: [completeCat],
  // ...
);
```

### 4.2 Action Handler

**Update `_onForegroundAction` and `onBackgroundNotificationAction`:**

```dart
void _onForegroundAction(NotificationResponse response) {
  final taskId = response.payload;
  if (taskId == null) return;

  switch (response.actionId) {
    case 'complete':
      _handleComplete(taskId);
      break;
    case 'snooze':
      _handleSnooze(taskId);
      break;
    case 'cancel_all':
      _handleCancelAll(taskId);
      break;
    case null:
    case '':
      // Notification body tapped - navigate to task
      onNotificationTapped?.call(taskId);
      break;
  }
}

Future<void> _handleComplete(String taskId) async {
  // Mark task complete via TaskService
  final taskService = TaskService();
  final task = await taskService.getTaskById(taskId);
  if (task != null && !task.completed) {
    await taskService.toggleTaskCompletion(task);
    await ReminderService().cancelReminders(taskId);
  }
}

Future<void> _handleSnooze(String taskId) async {
  // For foreground: trigger snooze sheet via callback
  onSnoozeRequested?.call(taskId);
}

Future<void> _handleCancelAll(String taskId) async {
  await ReminderService().cancelReminders(taskId);
}
```

### 4.3 Snooze Options Sheet

**`lib/widgets/snooze_options_sheet.dart`:**

```dart
import 'package:flutter/material.dart';

class SnoozeOptionsSheet extends StatelessWidget {
  final String taskId;
  final void Function(Duration duration) onSnoozeSelected;

  const SnoozeOptionsSheet({
    super.key,
    required this.taskId,
    required this.onSnoozeSelected,
  });

  static Future<Duration?> show(BuildContext context, String taskId) {
    return showModalBottomSheet<Duration>(
      context: context,
      builder: (_) => SnoozeOptionsSheet(
        taskId: taskId,
        onSnoozeSelected: (d) => Navigator.pop(context, d),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Snooze reminder', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600,
            )),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('15 minutes'),
            onTap: () => onSnoozeSelected(const Duration(minutes: 15)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('30 minutes'),
            onTap: () => onSnoozeSelected(const Duration(minutes: 30)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('1 hour'),
            onTap: () => onSnoozeSelected(const Duration(hours: 1)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('3 hours'),
            onTap: () => onSnoozeSelected(const Duration(hours: 3)),
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Tomorrow'),
            subtitle: const Text('At your preferred notification time'),
            onTap: () => onSnoozeSelected(const Duration(hours: -1)), // Sentinel: snooze to user's configured time
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Pick a time...'),
            onTap: () => onSnoozeSelected(Duration.zero), // Sentinel for custom
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

### 4.4 Snooze Implementation in ReminderService

```dart
/// Snooze a reminder: cancel current, schedule new at snoozed time
Future<void> snooze(String taskId, Duration snoozeDuration) async {
  // Cancel current notifications for this task
  await cancelReminders(taskId);

  final notificationService = NotificationService();
  final settings = await _userSettingsService.getUserSettings();

  tz.TZDateTime snoozeTime;

  if (snoozeDuration == const Duration(hours: -1)) {
    // "Tomorrow at preferred time" sentinel — uses user's configured notification time
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    snoozeTime = tz.TZDateTime(
      notificationService.localTimezone,
      tomorrow.year, tomorrow.month, tomorrow.day,
      settings.defaultNotificationHour,
      settings.defaultNotificationMinute,
    );
  } else if (snoozeDuration == Duration.zero) {
    // Custom - handled by caller opening DateOptionsSheet
    return;
  } else {
    final now = tz.TZDateTime.now(tz.local);
    snoozeTime = tz.TZDateTime.from(now.add(snoozeDuration), tz.local);
  }

  // Schedule a one-shot snooze notification
  final db = await DatabaseService.instance.database;
  final taskMap = await db.query(
    AppConstants.tasksTable,
    where: 'id = ?',
    whereArgs: [taskId],
  );
  if (taskMap.isEmpty) return;

  final task = Task.fromMap(taskMap.first);
  final snoozeId = '${taskId}_snooze'.hashCode.abs() % (1 << 31);

  await notificationService.schedule(
    id: snoozeId,
    title: 'Snoozed reminder',
    body: task.title,
    scheduledTime: snoozeTime,
    payload: taskId,
  );
}
```

### 4.5 Notification Grouping

When scheduling, detect if 3+ notifications would fire within 30 minutes:

```dart
/// Check if this task's notifications should be grouped
Future<bool> _shouldGroup(tz.TZDateTime time) async {
  final pending = await _notificationService._plugin.pendingNotificationRequests();
  // Count pending within ±15 minutes of this time
  // Note: We can't easily get scheduled times from pending requests
  // Alternative: maintain a local schedule cache in SharedPreferences
  // For v1: skip grouping complexity, rely on OS-level grouping (groupKey)
  return false;
}
```

**Pragmatic approach for v1:** Use Android's `groupKey` and iOS grouped notifications. The OS handles visual grouping. Full time-window-based grouping logic can be added in a polish pass if needed.

### 4.6 Cold-Start Navigation

**`lib/main.dart`** - After NotificationService initialization:

```dart
// Phase 3.8: Check for notification-launched app
final launchNotification = await NotificationService().getLaunchNotification();
if (launchNotification != null) {
  // Store task ID for navigation after app fully loads
  _pendingNavigationTaskId = launchNotification.payload;
}

// Phase 3.8: Check for missed notifications (Linux + restart recovery)
try {
  await ReminderService().checkMissed();
} catch (e) {
  debugPrint('[Phase 3.8] Failed to check missed notifications: $e');
}
```

**Navigation setup** in app widget:

```dart
// Set up notification tap handler after MaterialApp is built
NotificationService().onNotificationTapped = (taskId) {
  if (taskId != null) {
    // Navigate to task (implementation depends on navigation setup)
    // Could use GlobalKey<NavigatorState> or GoRouter
    _navigateToTask(taskId);
  }
};
```

### 4.7 Badge Count (Android/iOS only)

After scheduling/canceling, update badge:

```dart
// In ReminderService after schedule/cancel operations:
if (Platform.isAndroid || Platform.isIOS) {
  final count = await _notificationService.getPendingCount();
  // Badge is handled automatically by flutter_local_notifications
  // via the notification channel badge setting
}
```

### 4.8 Subphase 3.8.4 Acceptance Criteria

- [ ] Tapping notification opens app and navigates to the specific task
- [ ] "Complete" action marks task done and cancels remaining reminders
- [ ] "Snooze" action shows snooze options (foreground) or uses default (background)
- [ ] "Cancel" action cancels all upcoming reminders for the task
- [ ] Snooze correctly reschedules at chosen time
- [ ] "Tomorrow" snooze uses user's defaultNotificationHour (preferred time)
- [ ] Cold-start from notification navigates to correct task
- [ ] `checkMissed()` fires overdue notifications on app open
- [ ] Linux shows immediate notifications for overdue tasks on app open
- [ ] Notifications group visually via OS grouping (Android groupKey)
- [ ] Badge count reflects pending notifications (Android/iOS)

---

## Testing Strategy

### Unit Tests

| Test File | Coverage |
|-----------|----------|
| `test/services/reminder_service_test.dart` | Scheduling logic, time computation, quiet hours |
| `test/services/notification_service_test.dart` | Initialization, permission checks (mocked plugin) |
| `test/models/task_reminder_test.dart` | Model serialization, notification ID generation |

### Key Test Cases

**ReminderService:**
```dart
group('computeNotificationTime', () {
  test('at_time returns exact due date for timed tasks');
  test('at_time returns defaultNotificationHour for all-day tasks');
  test('before_1h subtracts 1 hour from base time');
  test('before_1d subtracts 1 day from base time');
  test('before_custom uses offsetMinutes');
  test('overdue adds 1 minute to base time');
  test('returns null for task without due date');
});

group('quiet hours', () {
  test('same-day quiet hours (22:00-23:00) delays correctly');
  test('cross-midnight quiet hours (22:00-07:00) delays correctly');
  test('notification before quiet hours is not delayed');
  test('notification after quiet hours is not delayed');
  test('only active on specified days of week');
  test('disabled quiet hours returns original time');
});

group('scheduleReminders', () {
  test('use_global schedules from default reminder types');
  test('custom schedules from task_reminders table');
  test('none does not schedule anything');
  test('skips reminders in the past');
  test('completed tasks are not scheduled');
  test('tasks without due date are not scheduled');
});

group('snooze', () {
  test('cancels existing and schedules at new time');
  test('tomorrow snooze uses user preferred notification time');
  test('custom durations schedule correctly');
});
```

**TaskReminder model:**
```dart
group('notificationId', () {
  test('generates positive 31-bit integer');
  test('deterministic for same UUID');
  test('different for different UUIDs');
});
```

### Integration Tests

- TaskProvider hooks trigger scheduling on create/update/complete/delete
- Database migration v8→v9 preserves existing data
- Backfill of custom notification_time to task_reminders works

### Manual Testing Checklist

- [ ] Android: Permission request dialog appears on first launch
- [ ] Android: Notification shows at scheduled time
- [ ] Android: Action buttons work (Complete, Snooze, Cancel)
- [ ] Android: Notification survives app kill
- [ ] Android: Notification survives device reboot
- [ ] iOS: Permission request dialog appears
- [ ] iOS: Scheduled notification fires correctly
- [ ] iOS: Actions work from notification
- [ ] Linux: Immediate notification shows when app is open
- [ ] Linux: `checkMissed()` shows overdue on app open
- [ ] All platforms: Quiet hours delay works
- [ ] All platforms: Snooze reschedules correctly
- [ ] All platforms: Completing task cancels notifications
- [ ] All platforms: Cold-start navigation works

---

## Migration & Backward Compatibility

### Schema Migration (v8 → v9)

1. Create `task_reminders` table with indexes
2. Add 6 columns to `user_settings` (notification preferences)
3. Backfill: Any task with `notification_type = 'custom'` AND `notification_time IS NOT NULL` gets a `task_reminders` row with `reminder_type = 'at_time'`
4. `notification_time` column remains in schema but is unused by new code

### Field Behavior

| Field | Phase 3.1 Behavior | Phase 3.8 Behavior |
|-------|-------------------|-------------------|
| `task.notificationType` | Stored but unused | Drives reminder selection (global/custom/none) |
| `task.notificationTime` | Stored but unused | **Obsolete** - ignored, kept for schema compat |
| `user_settings.defaultNotificationHour` | Stored, 9 default | Used as base time for all-day task notifications |
| `user_settings.defaultNotificationMinute` | Stored, 0 default | Same as above |

### Rollback Safety

If Phase 3.8 is reverted:
- `task_reminders` table remains (harmless, unused)
- Extra `user_settings` columns remain (harmless, have defaults)
- No existing data is modified or removed
- App functions normally without notification code

---

## Platform Matrix

| Feature | Android | iOS | Linux |
|---------|---------|-----|-------|
| Immediate notifications | Yes | Yes | Yes (D-Bus) |
| Scheduled notifications | Yes (AlarmManager) | Yes (UNNotification) | No |
| Survives app kill | Yes | Yes | No |
| Survives reboot | Yes (boot receiver) | Yes | No |
| Action buttons | Yes (3 buttons) | Yes (3 buttons) | Varies by DE |
| Permission required | Android 13+ | Always | No |
| Badge count | Yes | Yes | No |
| Notification grouping | Yes (groupKey) | Yes (threadId) | No |
| Quiet hours | App-level | App-level | App-level |
| Exact scheduling | Yes (SCHEDULE_EXACT_ALARM) | Yes | N/A |

### Linux Fallback Strategy

Since Linux cannot schedule notifications while the app is closed:
1. On app open: `ReminderService().checkMissed()` finds overdue tasks
2. Shows immediate notifications for any tasks past their due date
3. Schedules in-memory timers for upcoming notifications (while app is open)
4. Document this limitation in app help/settings

---

## Risk Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Permission denied forever | No notifications | Settings shows status + deep link to system settings |
| Timezone change (travel) | Stale scheduled times | `rescheduleAll()` on app resume via `WidgetsBindingObserver` |
| Device reboot (OEM-specific) | Lost alarms | BOOT_COMPLETED receiver + `checkMissed()` on open |
| Notification ID collision | Wrong task opened | UUID-based IDs have very low collision probability |
| Too many notifications (storm) | User disables all | OS-level grouping via groupKey; quiet hours delay |
| DB migration fails | App crash on update | Transactional migration; rollback on failure |
| Background isolate limitations | Can't access full app state | Complete/Cancel actions use simple DB operations only |
| flutter_local_notifications breaking change | Build failure | Pin to ^19.5.0, update conservatively |

---

## Implementation Order Summary

```
3.8.1 (Setup)     → Build foundation, verify notifications work
3.8.2 (Schema)    → Data layer + scheduling brain
3.8.3 (UI)        → User-facing configuration
3.8.4 (Polish)    → Actions, snooze, edge cases
```

Each subphase builds on the previous. No subphase can be implemented out of order.

---

## Open Items for Review

1. **Notification grouping v1:** Using OS-level groupKey rather than manual time-window grouping. Sufficient for initial release? Or should we implement the 30-min window logic from day one?

2. **TaskService.getTaskById():** ✅ RESOLVED — Method does not exist. Add to TaskService during 3.8.1:
   ```dart
   Future<Task?> getTaskById(String taskId) async {
     final db = await _dbService.database;
     final maps = await db.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: [taskId]);
     if (maps.isEmpty) return null;
     return Task.fromMap(maps.first);
   }
   ```

3. **Navigation from notification:** Current app uses simple Navigator. May need a global navigator key or route-based approach for deep linking to a specific task from notification tap.

4. **Background action limitations:** The `@pragma('vm:entry-point')` background handler runs in an isolate. It can do simple DB operations but cannot access Provider state. The "Complete" action should use `TaskService` directly, not `TaskProvider`.

5. **App resume rescheduling:** Need `WidgetsBindingObserver` mixin on the app widget to detect `resumed` lifecycle state and call `rescheduleAll()`. This handles timezone changes during travel.

---

**Document Version:** 1
**Last Updated:** 2026-01-22
**Author:** Claude (with BlueKitty direction)
