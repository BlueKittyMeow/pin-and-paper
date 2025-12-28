import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/utils/constants.dart';

/// Helper class for setting up test databases
///
/// Uses sqflite_common_ffi to create in-memory databases for testing.
/// This avoids the need for path_provider and provides fast, isolated tests.
class TestDatabaseHelper {
  static bool _initialized = false;
  static Database? _database;
  static int _dbCounter = 0;

  /// Initialize sqflite_common_ffi for testing
  ///
  /// This should be called once at the start of your test suite.
  /// It sets up the FFI database factory for desktop/test environments.
  static void initialize() {
    if (_initialized) return;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _initialized = true;
  }

  /// Get a fresh in-memory test database
  ///
  /// Creates a new database with the full schema (Phase 3.2).
  /// Each call returns a new, isolated database with a unique path.
  static Future<Database> createTestDatabase() async {
    // Close any existing database first to ensure clean state
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Use unique in-memory database for each test to ensure isolation
    // Each database gets a unique identifier to prevent reuse
    _dbCounter++;
    final uniquePath = inMemoryDatabasePath + '_test_$_dbCounter';

    final db = await databaseFactory.openDatabase(
      uniquePath,
      options: OpenDatabaseOptions(
        version: AppConstants.databaseVersion,
        onCreate: _createTestDB,
        onConfigure: _onConfigure,
      ),
    );

    _database = db;
    return db;
  }

  /// Configure database (enable foreign keys)
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create test database schema (matches DatabaseService._createDB)
  static Future<void> _createTestDB(Database db, int version) async {
    // Create tasks table with Phase 3.3 schema (includes soft delete)
    await db.execute('''
      CREATE TABLE ${AppConstants.tasksTable} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        parent_id TEXT,
        position INTEGER NOT NULL DEFAULT 0,
        is_template INTEGER NOT NULL DEFAULT 0,
        due_date INTEGER,
        is_all_day INTEGER NOT NULL DEFAULT 0,
        start_date INTEGER,
        notification_type TEXT,
        notification_time INTEGER,
        deleted_at INTEGER,
        FOREIGN KEY (parent_id) REFERENCES ${AppConstants.tasksTable} (id) ON DELETE CASCADE
      )
    ''');

    // Create brain dump drafts table
    await db.execute('''
      CREATE TABLE ${AppConstants.brainDumpDraftsTable} (
        id TEXT PRIMARY KEY,
        raw_dump TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        processed INTEGER NOT NULL DEFAULT 0,
        tokens_used INTEGER,
        cost REAL,
        suggestions TEXT
      )
    ''');

    // Create API usage tracking table
    await db.execute('''
      CREATE TABLE ${AppConstants.apiUsageLogTable} (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        input_tokens INTEGER NOT NULL,
        output_tokens INTEGER NOT NULL,
        cost REAL NOT NULL,
        operation_type TEXT NOT NULL
      )
    ''');

    // Create user settings table
    await db.execute('''
      CREATE TABLE ${AppConstants.userSettingsTable} (
        id TEXT PRIMARY KEY,
        api_key TEXT,
        last_modified INTEGER NOT NULL
      )
    ''');

    // Create tags table (Phase 3.5)
    await db.execute('''
      CREATE TABLE ${AppConstants.tagsTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        color TEXT,
        created_at INTEGER NOT NULL,
        deleted_at INTEGER DEFAULT NULL
      )
    ''');

    // Create task_tags junction table (Phase 3.5)
    await db.execute('''
      CREATE TABLE ${AppConstants.taskTagsTable} (
        task_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (task_id, tag_id),
        FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES ${AppConstants.tagsTable}(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX idx_tasks_parent_id ON ${AppConstants.tasksTable}(parent_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_position ON ${AppConstants.tasksTable}(position)
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_completed ON ${AppConstants.tasksTable}(completed)
    ''');

    // Phase 3.3: Soft delete indexes
    await db.execute('''
      CREATE INDEX idx_tasks_deleted_at ON ${AppConstants.tasksTable}(deleted_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_active ON ${AppConstants.tasksTable}(deleted_at, completed, created_at DESC)
        WHERE deleted_at IS NULL
    ''');

    // Phase 3.5: Tag indexes
    await db.execute('''
      CREATE INDEX idx_tags_name ON ${AppConstants.tagsTable}(name)
    ''');

    await db.execute('''
      CREATE INDEX idx_tags_deleted_at ON ${AppConstants.tagsTable}(deleted_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_tags_tag ON ${AppConstants.taskTagsTable}(tag_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_tags_task ON ${AppConstants.taskTagsTable}(task_id)
    ''');
  }

  /// Close the test database
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Clear all data from the test database (for test cleanup)
  static Future<void> clearAllData(Database db) async {
    // Clear junction table first (foreign key constraints)
    await db.delete(AppConstants.taskTagsTable);
    await db.delete(AppConstants.tagsTable);
    await db.delete(AppConstants.tasksTable);
    await db.delete(AppConstants.brainDumpDraftsTable);
    await db.delete(AppConstants.apiUsageLogTable);
    await db.delete(AppConstants.userSettingsTable);
  }
}
