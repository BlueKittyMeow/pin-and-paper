class AppConstants {
  // Database
  static const String databaseName = 'pin_and_paper.db';
  static const int databaseVersion = 2; // Phase 2: Added brain_dump_drafts table

  // Table names
  static const String tasksTable = 'tasks';
  static const String brainDumpDraftsTable = 'brain_dump_drafts'; // Phase 2

  // App metadata
  static const String appName = 'Pin and Paper';
  static const String appVersion = '0.2.0'; // Phase 2: AI Integration

  // Performance targets
  static const int maxTasksInMemory = 500;
  static const Duration autoSaveDelay = Duration(milliseconds: 500);

  // Phase 2: Claude AI
  static const int maxBrainDumpLength = 10000; // Characters
  static const double typicalCostPerDump = 0.01; // USD
}
