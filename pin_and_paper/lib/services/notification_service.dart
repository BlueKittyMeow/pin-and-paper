import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../utils/constants.dart';
import 'user_settings_service.dart';

/// Top-level background action handler (must be top-level or static)
/// NOTE: For v1, all actions use showsUserInterface: true so this handler
/// is primarily a safety net. True background handling (isolate DB access)
/// is deferred to a future polish phase (see FEATURE_REQUESTS.md).
@pragma('vm:entry-point')
void onBackgroundNotificationAction(NotificationResponse response) {
  debugPrint('[Notification] Background action: ${response.actionId}');
  // All actions handled in foreground via showsUserInterface: true
}

/// Platform wrapper for flutter_local_notifications.
///
/// Responsibilities:
/// - Initialize the notification plugin and timezone data
/// - Schedule/cancel/show notifications
/// - Handle permissions (request + check)
/// - Handle notification taps and actions
///
/// Does NOT contain scheduling logic (that's ReminderService in 3.8.2).
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  tz.Location? _localTimezone;

  /// Whether the notification service has been initialized
  bool get isInitialized => _initialized;

  /// Callback for handling notification taps in foreground
  /// Set by the app to enable navigation to a specific task
  void Function(String? taskId)? onNotificationTapped;

  /// Initialize the notification plugin and timezone data
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Detect timezone: prefer user override from settings, fallback to device
    try {
      final settings = await UserSettingsService().getUserSettings();
      final String timezoneName;
      if (settings.timezoneId != null) {
        timezoneName = settings.timezoneId!;
      } else {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        timezoneName = tzInfo.identifier;
      }
      _localTimezone = tz.getLocation(timezoneName);
      tz.setLocalLocation(_localTimezone!);
    } catch (e) {
      debugPrint('[NotificationService] Timezone detection failed: $e');
      _localTimezone = tz.getLocation('UTC');
      tz.setLocalLocation(_localTimezone!);
    }

    // Platform-specific initialization settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We request manually with explanation
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
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationAction,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _initialized = true;
    debugPrint(
        '[NotificationService] Initialized with timezone: ${_localTimezone?.name}');
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
    debugPrint(
        '[NotificationService] Foreground action: ${response.actionId}, payload: ${response.payload}');
    if (response.actionId == null || response.actionId!.isEmpty) {
      // Notification body tapped - navigate to task
      onNotificationTapped?.call(response.payload);
    }
    // Action-specific handling will be added by ReminderService in 3.8.2
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
    // iOS: would need to check via the plugin's pending capabilities
    // Linux: always true (no permission model)
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
  ///
  /// Automatically falls back to inexact scheduling if exact alarm
  /// permission is not granted (Android 12+).
  /// Skips scheduling if the time is in the past.
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
      debugPrint(
          '[NotificationService] Skipping past notification: $scheduledTime');
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
      matchDateTimeComponents: null, // One-shot, not recurring
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

  /// Get pending notification count (for potential badge display)
  Future<int> getPendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  /// Get notification that launched the app (cold start)
  /// Returns the notification response if the app was launched by tapping a notification
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
