import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
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

  /// Create database from scratch (fresh installs)
  ///
  /// CRITICAL: This creates the COMPLETE Phase 3 (v4) schema.
  /// Must match the end state of _migrateToV4 EXACTLY to ensure parity.
  Future<void> _createDB(Database db, int version) async {
    // ===========================================
    // 1. CREATE TASKS TABLE (with ALL Phase 3 columns)
    // ===========================================

    await db.execute('''
      CREATE TABLE ${AppConstants.tasksTable} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,

        -- Phase 3.1: Date fields
        due_date INTEGER,
        is_all_day INTEGER DEFAULT 1,
        start_date INTEGER,

        -- Phase 3.2: Nesting
        parent_id TEXT,
        position INTEGER NOT NULL DEFAULT 0,

        -- Phase 3.1: Template support
        is_template INTEGER DEFAULT 0,

        -- Phase 3.1: Notification support
        notification_type TEXT DEFAULT 'use_global',
        notification_time INTEGER,

        FOREIGN KEY (parent_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
      )
    ''');

    // ===========================================
    // 2. CREATE USER SETTINGS TABLE
    // ===========================================

    await db.execute('''
      CREATE TABLE ${AppConstants.userSettingsTable} (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        early_morning_hour INTEGER DEFAULT 5,
        morning_hour INTEGER DEFAULT 9,
        noon_hour INTEGER DEFAULT 12,
        afternoon_hour INTEGER DEFAULT 15,
        tonight_hour INTEGER DEFAULT 19,
        late_night_hour INTEGER DEFAULT 22,
        today_cutoff_hour INTEGER DEFAULT 4,
        today_cutoff_minute INTEGER DEFAULT 59,
        week_start_day INTEGER DEFAULT 1,
        timezone_id TEXT,
        use_24hour_time INTEGER DEFAULT 0,
        auto_complete_children TEXT DEFAULT 'prompt',
        default_notification_hour INTEGER DEFAULT 9,
        default_notification_minute INTEGER DEFAULT 0,
        voice_smart_punctuation INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // ===========================================
    // 3. CREATE AUXILIARY TABLES
    // ===========================================

    // Brain dump drafts (from Phase 2)
    await db.execute('''
      CREATE TABLE ${AppConstants.brainDumpDraftsTable} (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_modified INTEGER NOT NULL,
        failed_reason TEXT
      )
    ''');

    // API usage log (from Phase 2)
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

    // Task images (Phase 6 - future-proofing)
    await db.execute('''
      CREATE TABLE ${AppConstants.taskImagesTable} (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        source_url TEXT,
        is_hero INTEGER DEFAULT 0,
        position INTEGER DEFAULT 0,
        caption TEXT,
        mime_type TEXT NOT NULL,
        file_size INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
      )
    ''');

    // Entities for @mentions (Phase 5 - future-proofing)
    await db.execute('''
      CREATE TABLE ${AppConstants.entitiesTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        display_name TEXT,
        type TEXT DEFAULT 'person',
        notes TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Tags for #tags (Phase 5 - future-proofing)
    await db.execute('''
      CREATE TABLE ${AppConstants.tagsTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Junction table: tasks ↔ entities
    await db.execute('''
      CREATE TABLE ${AppConstants.taskEntitiesTable} (
        task_id TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (task_id, entity_id),
        FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE,
        FOREIGN KEY (entity_id) REFERENCES ${AppConstants.entitiesTable}(id) ON DELETE CASCADE
      )
    ''');

    // Junction table: tasks ↔ tags
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

    // ===========================================
    // 4. CREATE INDEXES (12 total, matching _migrateToV4)
    // ===========================================

    // Task indexes (with partial indexes for performance)
    await db.execute('''
      CREATE INDEX idx_tasks_parent ON ${AppConstants.tasksTable}(parent_id, position)
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_due_date ON ${AppConstants.tasksTable}(due_date) WHERE due_date IS NOT NULL
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_start_date ON ${AppConstants.tasksTable}(start_date) WHERE start_date IS NOT NULL
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_template ON ${AppConstants.tasksTable}(is_template) WHERE is_template = 1
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_created ON ${AppConstants.tasksTable}(created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_completed ON ${AppConstants.tasksTable}(completed, completed_at)
    ''');

    // Task images indexes
    await db.execute('''
      CREATE INDEX idx_task_images_task ON ${AppConstants.taskImagesTable}(task_id, position)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_images_hero ON ${AppConstants.taskImagesTable}(task_id) WHERE is_hero = 1
    ''');

    // Entity and tag indexes
    await db.execute('''
      CREATE INDEX idx_entities_name ON ${AppConstants.entitiesTable}(name)
    ''');

    await db.execute('''
      CREATE INDEX idx_tags_name ON ${AppConstants.tagsTable}(name)
    ''');

    // Junction table indexes (bidirectional lookups)
    await db.execute('''
      CREATE INDEX idx_task_entities_entity ON ${AppConstants.taskEntitiesTable}(entity_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_entities_task ON ${AppConstants.taskEntitiesTable}(task_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_tags_tag ON ${AppConstants.taskTagsTable}(tag_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_tags_task ON ${AppConstants.taskTagsTable}(task_id)
    ''');

    // Brain dump drafts index
    await db.execute('''
      CREATE INDEX idx_drafts_modified ON ${AppConstants.brainDumpDraftsTable}(last_modified DESC)
    ''');

    // API usage log index
    await db.execute('''
      CREATE INDEX idx_api_usage_timestamp ON ${AppConstants.apiUsageLogTable}(timestamp DESC)
    ''');

    // ===========================================
    // 5. SEED USER SETTINGS TABLE
    // ===========================================

    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(AppConstants.userSettingsTable, {
      'id': 1,
      'early_morning_hour': 5,
      'morning_hour': 9,
      'noon_hour': 12,
      'afternoon_hour': 15,
      'tonight_hour': 19,
      'late_night_hour': 22,
      'today_cutoff_hour': 4,
      'today_cutoff_minute': 59,
      'week_start_day': 1,
      'timezone_id': null, // Populated in Phase 3.5
      'use_24hour_time': 0,
      'auto_complete_children': 'prompt',
      'default_notification_hour': 9,
      'default_notification_minute': 0,
      'voice_smart_punctuation': 1,
      'created_at': now,
      'updated_at': now,
    });
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

    // Migrate from version 3 to 4: Phase 3 - Task nesting, dates, user settings
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
  }

  /// Phase 3 Migration: v3 → v4
  ///
  /// Adds:
  /// - Task nesting (parent_id, position)
  /// - Date support (due_date, is_all_day, start_date)
  /// - Notification support (notification_type, notification_time)
  /// - Template support (is_template)
  /// - User settings table
  /// - Task images, entities, tags tables (future-proofing)
  /// - 12 performance indexes
  ///
  /// CRITICAL: Position backfill preserves existing task order
  Future<void> _migrateToV4(Database db) async {
    // Wrap entire migration in a transaction for atomicity
    // Note: onUpgrade is already in a transaction, but being explicit
    await db.transaction((txn) async {
      // ===========================================
      // 1. ALTER EXISTING TASKS TABLE
      // ===========================================

      // Nesting support
      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN parent_id TEXT REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
      ''');

      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN position INTEGER DEFAULT 0
      ''');

      // Template support
      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN is_template INTEGER DEFAULT 0
      ''');

      // Date support
      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN due_date INTEGER
      ''');

      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN is_all_day INTEGER DEFAULT 1
      ''');

      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN start_date INTEGER
      ''');

      // Notification support
      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN notification_type TEXT DEFAULT 'use_global'
      ''');

      await txn.execute('''
        ALTER TABLE ${AppConstants.tasksTable}
        ADD COLUMN notification_time INTEGER
      ''');

      // ===========================================
      // 2. CRITICAL: POSITION BACKFILL
      // ===========================================

      // Assigns monotonically increasing positions based on created_at
      // Preserves existing visual order (newest tasks at top)
      // Handles NULL parent_id correctly for top-level tasks
      // Uses id as tie-breaker for tasks with identical timestamps
      await txn.execute('''
        UPDATE ${AppConstants.tasksTable}
        SET position = (
          SELECT COUNT(*)
          FROM ${AppConstants.tasksTable} AS t2
          WHERE (
            (t2.parent_id IS NULL AND ${AppConstants.tasksTable}.parent_id IS NULL)
            OR (t2.parent_id = ${AppConstants.tasksTable}.parent_id)
          )
            AND (
              t2.created_at < ${AppConstants.tasksTable}.created_at
              OR (t2.created_at = ${AppConstants.tasksTable}.created_at AND t2.id <= ${AppConstants.tasksTable}.id)
            )
        ) - 1
      ''');

      // ===========================================
      // 3. CREATE NEW TABLES
      // ===========================================

      // User settings (single-row table)
      await txn.execute('''
        CREATE TABLE ${AppConstants.userSettingsTable} (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          early_morning_hour INTEGER DEFAULT 5,
          morning_hour INTEGER DEFAULT 9,
          noon_hour INTEGER DEFAULT 12,
          afternoon_hour INTEGER DEFAULT 15,
          tonight_hour INTEGER DEFAULT 19,
          late_night_hour INTEGER DEFAULT 22,
          today_cutoff_hour INTEGER DEFAULT 4,
          today_cutoff_minute INTEGER DEFAULT 59,
          week_start_day INTEGER DEFAULT 1,
          timezone_id TEXT,
          use_24hour_time INTEGER DEFAULT 0,
          auto_complete_children TEXT DEFAULT 'prompt',
          default_notification_hour INTEGER DEFAULT 9,
          default_notification_minute INTEGER DEFAULT 0,
          voice_smart_punctuation INTEGER DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Task images (Phase 6 - future-proofing)
      await txn.execute('''
        CREATE TABLE ${AppConstants.taskImagesTable} (
          id TEXT PRIMARY KEY,
          task_id TEXT NOT NULL,
          file_path TEXT NOT NULL,
          source_url TEXT,
          is_hero INTEGER DEFAULT 0,
          position INTEGER DEFAULT 0,
          caption TEXT,
          mime_type TEXT NOT NULL,
          file_size INTEGER,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
        )
      ''');

      // Entities for @mentions (Phase 5 - future-proofing)
      await txn.execute('''
        CREATE TABLE ${AppConstants.entitiesTable} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          display_name TEXT,
          type TEXT DEFAULT 'person',
          notes TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      // Tags for #tags (Phase 5 - future-proofing)
      await txn.execute('''
        CREATE TABLE ${AppConstants.tagsTable} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      // Junction table: tasks ↔ entities
      await txn.execute('''
        CREATE TABLE ${AppConstants.taskEntitiesTable} (
          task_id TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (task_id, entity_id),
          FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE,
          FOREIGN KEY (entity_id) REFERENCES ${AppConstants.entitiesTable}(id) ON DELETE CASCADE
        )
      ''');

      // Junction table: tasks ↔ tags
      await txn.execute('''
        CREATE TABLE ${AppConstants.taskTagsTable} (
          task_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (task_id, tag_id),
          FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES ${AppConstants.tagsTable}(id) ON DELETE CASCADE
        )
      ''');

      // ===========================================
      // 4. CREATE INDEXES (12 total)
      // ===========================================

      // Task indexes
      await txn.execute('''
        CREATE INDEX idx_tasks_parent ON ${AppConstants.tasksTable}(parent_id, position)
      ''');

      await txn.execute('''
        CREATE INDEX idx_tasks_due_date ON ${AppConstants.tasksTable}(due_date) WHERE due_date IS NOT NULL
      ''');

      await txn.execute('''
        CREATE INDEX idx_tasks_start_date ON ${AppConstants.tasksTable}(start_date) WHERE start_date IS NOT NULL
      ''');

      await txn.execute('''
        CREATE INDEX idx_tasks_template ON ${AppConstants.tasksTable}(is_template) WHERE is_template = 1
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_tasks_created ON ${AppConstants.tasksTable}(created_at DESC)
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_tasks_completed ON ${AppConstants.tasksTable}(completed, completed_at)
      ''');

      // Task images indexes
      await txn.execute('''
        CREATE INDEX idx_task_images_task ON ${AppConstants.taskImagesTable}(task_id, position)
      ''');

      await txn.execute('''
        CREATE INDEX idx_task_images_hero ON ${AppConstants.taskImagesTable}(task_id) WHERE is_hero = 1
      ''');

      // Entity and tag indexes
      await txn.execute('''
        CREATE INDEX idx_entities_name ON ${AppConstants.entitiesTable}(name)
      ''');

      await txn.execute('''
        CREATE INDEX idx_tags_name ON ${AppConstants.tagsTable}(name)
      ''');

      // Junction table indexes (bidirectional lookups)
      await txn.execute('''
        CREATE INDEX idx_task_entities_entity ON ${AppConstants.taskEntitiesTable}(entity_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_task_entities_task ON ${AppConstants.taskEntitiesTable}(task_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_task_tags_tag ON ${AppConstants.taskTagsTable}(tag_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_task_tags_task ON ${AppConstants.taskTagsTable}(task_id)
      ''');

      // ===========================================
      // 5. SEED USER SETTINGS TABLE
      // ===========================================

      final now = DateTime.now().millisecondsSinceEpoch;

      // Note: timezone_id left NULL - will be populated on first notification setup
      // (Phase 3.5) to avoid tz initialization issues during migration
      await txn.insert(AppConstants.userSettingsTable, {
        'id': 1,
        'early_morning_hour': 5,
        'morning_hour': 9,
        'noon_hour': 12,
        'afternoon_hour': 15,
        'tonight_hour': 19,
        'late_night_hour': 22,
        'today_cutoff_hour': 4,
        'today_cutoff_minute': 59,
        'week_start_day': 1,
        'timezone_id': null, // Populated in Phase 3.5
        'use_24hour_time': 0,
        'auto_complete_children': 'prompt',
        'default_notification_hour': 9,
        'default_notification_minute': 0,
        'voice_smart_punctuation': 1,
        'created_at': now,
        'updated_at': now,
      });
    });

    debugPrint('✅ Database migrated to v4 successfully');
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
