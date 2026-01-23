import 'package:uuid/uuid.dart';

/// Reminder types that can be scheduled for a task.
/// These are string constants used in the database and for notification ID generation.
class ReminderType {
  static const String atTime = 'at_time'; // At exact due time
  static const String before1h = 'before_1h'; // 1 hour before
  static const String before1d = 'before_1d'; // 1 day before
  static const String beforeCustom = 'before_custom'; // Custom offset
  static const String overdue = 'overdue'; // When task becomes overdue

  static const List<String> all = [
    atTime,
    before1h,
    before1d,
    beforeCustom,
    overdue
  ];

  /// Human-readable label for UI display
  static String label(String type) {
    switch (type) {
      case atTime:
        return 'At due time';
      case before1h:
        return '1 hour before';
      case before1d:
        return '1 day before';
      case beforeCustom:
        return 'Custom';
      case overdue:
        return 'When overdue';
      default:
        return type;
    }
  }

  /// Offset in minutes for standard types (null for at_time/overdue)
  static int? defaultOffset(String type) {
    switch (type) {
      case before1h:
        return 60;
      case before1d:
        return 1440; // 24 * 60
      default:
        return null;
    }
  }
}

/// A scheduled reminder for a task.
///
/// Each task can have multiple reminders (e.g., "1 hour before" AND "at due time").
/// Tasks with notificationType == 'use_global' use computed reminders from UserSettings;
/// tasks with 'custom' use reminders stored in the task_reminders table.
class TaskReminder {
  final String id;
  final String taskId;
  final String reminderType; // One of ReminderType constants
  final int? offsetMinutes; // For 'before_custom': minutes before due date
  final bool enabled;

  TaskReminder({
    String? id,
    required this.taskId,
    required this.reminderType,
    this.offsetMinutes,
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  /// Generate a deterministic notification ID for this reminder.
  /// Uses hashCode bounded to 31-bit positive int (Android requirement).
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
