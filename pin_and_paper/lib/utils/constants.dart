class AppConstants {
  // Database
  static const String databaseName = 'pin_and_paper.db';
  static const int databaseVersion = 8; // Phase 3.6.5: Edit Task Modal Rework (notes + position_before_completion)

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
