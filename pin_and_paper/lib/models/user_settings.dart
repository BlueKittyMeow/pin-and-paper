import 'package:clock/clock.dart';

/// Wrapper class to distinguish "parameter not provided" from "explicitly set to null"
/// in copyWith methods.
///
/// Example usage:
/// ```dart
/// settings.copyWith();  // Keep existing timezoneId
/// settings.copyWith(timezoneId: Value('America/New_York'));  // Set to new value
/// settings.copyWith(timezoneId: Value(null));  // Clear back to null
/// ```
class Value<T> {
  const Value(this.value);
  final T value;
}

class UserSettings {
  final int id; // Always 1 (single-row table)

  // Time keyword preferences
  final int earlyMorningHour; // "early morning" / "dawn"
  final int morningHour; // "morning"
  final int noonHour; // "noon" / "lunch" / "midday"
  final int afternoonHour; // "afternoon"
  final int tonightHour; // "tonight" / "evening"
  final int lateNightHour; // "late night"

  // Night owl settings
  final int todayCutoffHour; // "today" window cutoff hour
  final int todayCutoffMinute; // "today" window cutoff minute

  // Week/calendar preferences
  final int weekStartDay; // 0=Sunday, 1=Monday, etc.

  // Timezone preferences
  final String? timezoneId; // IANA timezone ID (e.g., 'America/Detroit')

  // Display preferences
  final bool use24HourTime; // 12-hour vs 24-hour display

  // Task behavior preferences
  final String autoCompleteChildren; // 'prompt', 'always', 'never'

  // Notification preferences
  final int defaultNotificationHour;
  final int defaultNotificationMinute;

  // Phase 3.8: Notification scheduling preferences
  final bool notificationsEnabled; // Master toggle: enable/disable all notifications
  final bool notifyWhenOverdue; // Global: notify when tasks become overdue
  final bool quietHoursEnabled; // Quiet hours toggle
  final int? quietHoursStart; // Minutes from midnight (e.g., 1320 = 22:00)
  final int? quietHoursEnd; // Minutes from midnight (e.g., 420 = 07:00)
  final String quietHoursDays; // Comma-separated day indices: "0,1,2,3,4,5,6" (0=Mon)
  final String defaultReminderTypes; // Comma-separated: "at_time,before_1h"

  // Voice input preferences
  final bool voiceSmartPunctuation;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    this.id = 1,
    this.earlyMorningHour = 5,
    this.morningHour = 9,
    this.noonHour = 12,
    this.afternoonHour = 15,
    this.tonightHour = 19,
    this.lateNightHour = 22,
    this.todayCutoffHour = 4,
    this.todayCutoffMinute = 59,
    this.weekStartDay = 1,
    this.timezoneId,
    this.use24HourTime = false,
    this.autoCompleteChildren = 'prompt',
    this.defaultNotificationHour = 9,
    this.defaultNotificationMinute = 0,
    this.notificationsEnabled = true,
    this.notifyWhenOverdue = false,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.quietHoursDays = '0,1,2,3,4,5,6',
    this.defaultReminderTypes = 'at_time',
    this.voiceSmartPunctuation = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'early_morning_hour': earlyMorningHour,
      'morning_hour': morningHour,
      'noon_hour': noonHour,
      'afternoon_hour': afternoonHour,
      'tonight_hour': tonightHour,
      'late_night_hour': lateNightHour,
      'today_cutoff_hour': todayCutoffHour,
      'today_cutoff_minute': todayCutoffMinute,
      'week_start_day': weekStartDay,
      'timezone_id': timezoneId,
      'use_24hour_time': use24HourTime ? 1 : 0,
      'auto_complete_children': autoCompleteChildren,
      'default_notification_hour': defaultNotificationHour,
      'default_notification_minute': defaultNotificationMinute,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'notify_when_overdue': notifyWhenOverdue ? 1 : 0,
      'quiet_hours_enabled': quietHoursEnabled ? 1 : 0,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'quiet_hours_days': quietHoursDays,
      'default_reminder_types': defaultReminderTypes,
      'voice_smart_punctuation': voiceSmartPunctuation ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] as int,
      earlyMorningHour: map['early_morning_hour'] as int,
      morningHour: map['morning_hour'] as int,
      noonHour: map['noon_hour'] as int,
      afternoonHour: map['afternoon_hour'] as int,
      tonightHour: map['tonight_hour'] as int,
      lateNightHour: map['late_night_hour'] as int,
      todayCutoffHour: map['today_cutoff_hour'] as int,
      todayCutoffMinute: map['today_cutoff_minute'] as int,
      weekStartDay: map['week_start_day'] as int,
      timezoneId: map['timezone_id'] as String?,
      use24HourTime: map['use_24hour_time'] == 1,
      autoCompleteChildren: map['auto_complete_children'] as String,
      defaultNotificationHour: map['default_notification_hour'] as int,
      defaultNotificationMinute: map['default_notification_minute'] as int,
      notificationsEnabled: (map['notifications_enabled'] as int?) != 0, // default true
      notifyWhenOverdue: (map['notify_when_overdue'] as int?) == 1,
      quietHoursEnabled: (map['quiet_hours_enabled'] as int?) == 1,
      quietHoursStart: map['quiet_hours_start'] as int?,
      quietHoursEnd: map['quiet_hours_end'] as int?,
      quietHoursDays: (map['quiet_hours_days'] as String?) ?? '0,1,2,3,4,5,6',
      defaultReminderTypes: (map['default_reminder_types'] as String?) ?? 'at_time',
      voiceSmartPunctuation: map['voice_smart_punctuation'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// Create default settings (for first-time initialization)
  factory UserSettings.defaults() {
    final now = clock.now(); // Use clock for testable timestamps
    return UserSettings(
      createdAt: now,
      updatedAt: now,
    );
  }

  UserSettings copyWith({
    int? earlyMorningHour,
    int? morningHour,
    int? noonHour,
    int? afternoonHour,
    int? tonightHour,
    int? lateNightHour,
    int? todayCutoffHour,
    int? todayCutoffMinute,
    int? weekStartDay,
    Value<String?>? timezoneId, // Wrapped in Value to enable clearing to null
    bool? use24HourTime,
    String? autoCompleteChildren,
    int? defaultNotificationHour,
    int? defaultNotificationMinute,
    bool? notificationsEnabled,
    bool? notifyWhenOverdue,
    bool? quietHoursEnabled,
    Value<int?>? quietHoursStart,
    Value<int?>? quietHoursEnd,
    String? quietHoursDays,
    String? defaultReminderTypes,
    bool? voiceSmartPunctuation,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      id: id,
      earlyMorningHour: earlyMorningHour ?? this.earlyMorningHour,
      morningHour: morningHour ?? this.morningHour,
      noonHour: noonHour ?? this.noonHour,
      afternoonHour: afternoonHour ?? this.afternoonHour,
      tonightHour: tonightHour ?? this.tonightHour,
      lateNightHour: lateNightHour ?? this.lateNightHour,
      todayCutoffHour: todayCutoffHour ?? this.todayCutoffHour,
      todayCutoffMinute: todayCutoffMinute ?? this.todayCutoffMinute,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      timezoneId: timezoneId != null ? timezoneId.value : this.timezoneId, // Unwrap Value
      use24HourTime: use24HourTime ?? this.use24HourTime,
      autoCompleteChildren: autoCompleteChildren ?? this.autoCompleteChildren,
      defaultNotificationHour:
          defaultNotificationHour ?? this.defaultNotificationHour,
      defaultNotificationMinute:
          defaultNotificationMinute ?? this.defaultNotificationMinute,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notifyWhenOverdue: notifyWhenOverdue ?? this.notifyWhenOverdue,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart != null
          ? quietHoursStart.value
          : this.quietHoursStart,
      quietHoursEnd: quietHoursEnd != null
          ? quietHoursEnd.value
          : this.quietHoursEnd,
      quietHoursDays: quietHoursDays ?? this.quietHoursDays,
      defaultReminderTypes: defaultReminderTypes ?? this.defaultReminderTypes,
      voiceSmartPunctuation:
          voiceSmartPunctuation ?? this.voiceSmartPunctuation,
      createdAt: createdAt,
      updatedAt: updatedAt ?? clock.now(), // Use clock for testable timestamps
    );
  }
}
