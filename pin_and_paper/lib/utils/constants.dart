class AppConstants {
  // Database
  static const String databaseName = 'pin_and_paper.db';
  static const int databaseVersion = 1;

  // Table names
  static const String tasksTable = 'tasks';

  // App metadata
  static const String appName = 'Pin and Paper';
  static const String appVersion = '0.1.0';

  // Performance targets
  static const int maxTasksInMemory = 500;
  static const Duration autoSaveDelay = Duration(milliseconds: 500);
}
