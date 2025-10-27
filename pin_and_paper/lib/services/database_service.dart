import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

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

    // Future migrations will be added here
    // if (oldVersion < 3) { ... }
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
}
