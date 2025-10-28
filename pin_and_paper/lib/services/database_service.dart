import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../models/brain_dump_draft.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final docDir = await getApplicationDocumentsDirectory();
    final path = join(docDir.path, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // Phase 2: Handle database migrations
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    // Tasks table
    await db.execute('''
      CREATE TABLE ${AppConstants.tasksTable} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        completed_at INTEGER
      )
    ''');

    // Indexes for performance
    await db.execute('''
      CREATE INDEX idx_tasks_created
      ON ${AppConstants.tasksTable}(created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_completed
      ON ${AppConstants.tasksTable}(completed, completed_at)
    ''');

    // Phase 2: Brain dump drafts table (for draft persistence)
    await db.execute('''
      CREATE TABLE ${AppConstants.brainDumpDraftsTable} (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_modified INTEGER NOT NULL,
        failed_reason TEXT
      )
    ''');

    // Index for draft retrieval (most recent first)
    await db.execute('''
      CREATE INDEX idx_drafts_modified
      ON ${AppConstants.brainDumpDraftsTable}(last_modified DESC)
    ''');

    // Phase 2 Stretch: API usage log table (for cost tracking)
    await db.execute('''
      CREATE TABLE ${AppConstants.apiUsageLogTable} (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        operation_type TEXT NOT NULL,
        input_tokens INTEGER NOT NULL,
        output_tokens INTEGER NOT NULL,
        estimated_cost_usd REAL NOT NULL,
        model TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Index for usage retrieval (most recent first)
    await db.execute('''
      CREATE INDEX idx_api_usage_timestamp
      ON ${AppConstants.apiUsageLogTable}(timestamp DESC)
    ''');
  }

  // Phase 2: Database migration handler
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Migrate from version 1 to 2: Add brain_dump_drafts table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE ${AppConstants.brainDumpDraftsTable} (
          id TEXT PRIMARY KEY,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          last_modified INTEGER NOT NULL,
          failed_reason TEXT
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_drafts_modified
        ON ${AppConstants.brainDumpDraftsTable}(last_modified DESC)
      ''');
    }

    // Migrate from version 2 to 3: Add api_usage_log table (Phase 2 Stretch)
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE ${AppConstants.apiUsageLogTable} (
          id TEXT PRIMARY KEY,
          timestamp INTEGER NOT NULL,
          operation_type TEXT NOT NULL,
          input_tokens INTEGER NOT NULL,
          output_tokens INTEGER NOT NULL,
          estimated_cost_usd REAL NOT NULL,
          model TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_api_usage_timestamp
        ON ${AppConstants.apiUsageLogTable}(timestamp DESC)
      ''');
    }

    // Future migrations will be added here
    // if (oldVersion < 4) { ... }
  }

  Future<void> close() async {
    // Don't call the getter - it might reopen a closed connection
    // Instead, close the cached instance and null it out
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null; // Reset so next access creates fresh connection
    }
  }

  // Phase 2 Stretch: Brain dump draft methods
  Future<List<BrainDumpDraft>> getBrainDumpDrafts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.brainDumpDraftsTable,
      orderBy: 'last_modified DESC',
    );

    return maps.map((m) => BrainDumpDraft.fromMap(m)).toList();
  }

  Future<void> deleteBrainDumpDraft(String id) async {
    final db = await database;
    await db.delete(
      AppConstants.brainDumpDraftsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cleanupOldDrafts() async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    await db.delete(
      AppConstants.brainDumpDraftsTable,
      where: 'last_modified < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  // Phase 2 Stretch: API usage logging methods
  Future<void> insertApiUsageLog(Map<String, dynamic> logEntry) async {
    final db = await database;
    await db.insert(
      AppConstants.apiUsageLogTable,
      logEntry,
    );
  }
}
