class AppConstants {
  // Database
  static const String databaseName = 'pin_and_paper.db';
  static const int databaseVersion = 9; // Phase 3.8: Due Date Notifications (task_reminders + notification settings)

  // Table names
  static const String tasksTable = 'tasks';
  static const String brainDumpDraftsTable = 'brain_dump_drafts'; // Phase 2
  static const String apiUsageLogTable = 'api_usage_log'; // Phase 2 Stretch

  // Phase 3 tables
  static const String userSettingsTable = 'user_settings';
  static const String taskImagesTable = 'task_images';
  static const String entitiesTable = 'entities';
  static const String tagsTable = 'tags';
  static const String taskEntitiesTable = 'task_entities';
  static const String taskTagsTable = 'task_tags';
  static const String taskRemindersTable = 'task_reminders'; // Phase 3.8

  // Phase 3.8: Notification constants
  static const String notificationChannelId = 'pin_paper_task_reminders';
  static const String notificationChannelName = 'Task Reminders';
  static const String notificationChannelDescription = 'Notifications for upcoming task due dates';
  static const String notificationGroupKey = 'pin_paper_task_group';

  // App metadata
  static const String appName = 'Pin and Paper';
  static const String appVersion = '3.7.0'; // Phase 3.7: NL Date Parsing

  // Performance targets
  static const int maxTasksInMemory = 500;
  static const Duration autoSaveDelay = Duration(milliseconds: 500);

  // Phase 2: Claude AI
  static const int maxBrainDumpLength = 10000; // Characters
  static const double typicalCostPerDump = 0.01; // USD
}
