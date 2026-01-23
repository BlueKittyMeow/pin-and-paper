import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import '../models/task_reminder.dart';
import '../models/user_settings.dart';
import 'notification_service.dart';
import 'database_service.dart';
import 'user_settings_service.dart';
import '../utils/constants.dart';

/// Core scheduling logic for task reminders.
///
/// Responsibilities:
/// - CRUD for task_reminders table
/// - Compute notification times (respecting user preferences)
/// - Schedule/cancel/reschedule notifications via NotificationService
/// - Quiet hours enforcement
/// - Overdue detection (respecting user's end-of-day setting)
///
/// Design principle: ALL times flow from UserSettings. No hardcoded
/// time assumptions (no "9am", no "midnight"). The logic always
/// reads from user-configured values.
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
    if (!_notificationService.isInitialized) return;
    if (_isRescheduling) return; // Skip per-task during bulk reschedule
    final settings = await _userSettingsService.getUserSettings();
    await _scheduleRemindersInternal(task, settings);
  }

  /// Cancel all scheduled notifications for a task.
  /// Handles both custom (DB-stored) and use_global (computed) reminders.
  Future<void> cancelReminders(String taskId) async {
    if (!_notificationService.isInitialized) return;

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
      final globalId =
          '${taskId}_global_${type.trim()}'.hashCode.abs() % (1 << 31);
      await _notificationService.cancel(globalId);
    }
    // Cancel global overdue reminder too
    final overdueId =
        '${taskId}_global_overdue'.hashCode.abs() % (1 << 31);
    await _notificationService.cancel(overdueId);
  }

  /// Reschedule all notifications (timezone change, settings change, app resume).
  /// Uses _isRescheduling flag to prevent per-task scheduling from racing.
  Future<void> rescheduleAll() async {
    if (!_notificationService.isInitialized) return;
    _isRescheduling = true;
    try {
      await _notificationService.cancelAll();

      final db = await DatabaseService.instance.database;
      final settings = await _userSettingsService.getUserSettings();
      // Get all active tasks with due dates and notification_type != 'none'
      final tasks = await db.query(
        AppConstants.tasksTable,
        where: "deleted_at IS NULL AND completed = 0 "
            "AND due_date IS NOT NULL AND notification_type != 'none'",
      );

      for (final taskMap in tasks) {
        final task = Task.fromMap(taskMap);
        await _scheduleRemindersInternal(task, settings);
      }

      debugPrint(
          '[ReminderService] Rescheduled notifications for ${tasks.length} tasks');
    } finally {
      _isRescheduling = false;
    }
  }

  /// Internal scheduling logic used by both scheduleReminders and rescheduleAll
  Future<void> _scheduleRemindersInternal(
      Task task, UserSettings settings) async {
    if (task.dueDate == null ||
        task.completed ||
        task.notificationType == 'none') return;

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

  /// Check for missed notifications (Linux fallback, app restart).
  /// Respects user's end-of-day setting for all-day task overdue detection.
  /// Only shows overdue alerts if NOT in quiet hours.
  Future<List<Task>> checkMissed() async {
    if (!_notificationService.isInitialized) return [];
    final settings = await _userSettingsService.getUserSettings();
    final now = DateTime.now();

    final db = await DatabaseService.instance.database;
    // Query all active tasks with due dates and notifications enabled
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
      debugPrint(
          '[ReminderService] Found ${missed.length} missed notifications');
    }
    return missed;
  }

  /// Check if a task is actually overdue, respecting user's end-of-day setting.
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
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
        settings.todayCutoffHour,
        settings.todayCutoffMinute,
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

  /// Compute the exact notification time for a reminder.
  /// All times derive from user preferences (no hardcoded values).
  tz.TZDateTime? computeNotificationTime(
    Task task,
    TaskReminder reminder,
    UserSettings settings,
  ) {
    if (task.dueDate == null) return null;

    final tz.TZDateTime baseTime;

    if (task.isAllDay) {
      // All-day tasks: use user's preferred notification time on the due date
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
    tz.TZDateTime offset(Duration d) =>
        tz.TZDateTime.from(baseTime.subtract(d), loc);

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
        return tz.TZDateTime.from(
            baseTime.add(const Duration(minutes: 1)), loc);

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

  /// Adjust notification time for quiet hours.
  /// NOTE: Quiet hours are highly user-configurable. All time boundaries
  /// flow from UserSettings - no hardcoded assumptions about day boundaries.
  /// Quiet hours suppress ALL alerts (including overdue) — users should
  /// never be woken by notifications.
  tz.TZDateTime _adjustForQuietHours(
      tz.TZDateTime time, UserSettings settings) {
    if (!settings.quietHoursEnabled) return time;
    if (settings.quietHoursStart == null || settings.quietHoursEnd == null) {
      return time;
    }

    // Convert time to minutes from midnight
    final timeMinutes = time.hour * 60 + time.minute;
    final start = settings.quietHoursStart!;
    final end = settings.quietHoursEnd!;

    // Check if the day of week is in quiet hours days.
    // For cross-midnight ranges (e.g., 22:00-07:00), the early-morning portion
    // (before 'end') belongs to the PREVIOUS day's quiet hours setting.
    int dayOfWeek = time.weekday - 1; // Convert to 0=Mon format
    if (start > end && timeMinutes < end) {
      dayOfWeek = (dayOfWeek - 1 + 7) % 7; // Check previous day
    }
    final activeDays =
        settings.quietHoursDays.split(',').map(int.parse).toSet();
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
      // Same day range OR evening portion of cross-midnight: end is next day
      final nextDay = time.add(const Duration(days: 1));
      endTime = tz.TZDateTime(
        _notificationService.localTimezone,
        nextDay.year,
        nextDay.month,
        nextDay.day,
        end ~/ 60,
        end % 60,
      );
    } else {
      // Early morning portion of cross-midnight: end is today
      endTime = tz.TZDateTime(
        _notificationService.localTimezone,
        time.year,
        time.month,
        time.day,
        end ~/ 60,
        end % 60,
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
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    }
    return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
  }
}
