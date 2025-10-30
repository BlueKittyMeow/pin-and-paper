# Phase 3 Group 1: Detailed Implementation Plan

**Subphases:** 3.1 (Database Migration), 3.2 (Task Nesting), 3.3 (Natural Language Date Parsing)
**Planning Level:** Detailed implementation (file structures, function signatures, UI mockups, line-by-line steps)
**Status:** Implementation Ready
**Estimated Duration:** 1-1.5 weeks

---

## Table of Contents

1. [Overview & Dependencies](#overview--dependencies)
2. [Phase 3.1: Database Migration (v3 → v4)](#phase-31-database-migration-v3--v4)
3. [Phase 3.2: Task Nesting & Hierarchy](#phase-32-task-nesting--hierarchy)
4. [Phase 3.3: Natural Language Date Parsing](#phase-33-natural-language-date-parsing)
5. [Cross-Phase Integration](#cross-phase-integration)
6. [Testing Strategy](#testing-strategy)
7. [Risk Mitigation](#risk-mitigation)

---

## Overview & Dependencies

### Why Plan Together?

Group 1 subphases are **tightly coupled**:
- **3.1 (Migration)** creates the database foundation everything depends on
- **3.2 (Nesting)** consumes the new schema (parent_id, position columns)
- **3.3 (Date Parsing)** is a shared service used across the app

**Critical:** Database migration is one-way and irreversible. The schema MUST be correct before implementation.

### Group 1 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Phase 3.1: Migration                  │
│  Database v3 → v4: Add parent_id, position, due_date   │
│  New tables: user_settings, task_images, entities...   │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌───────────────────┐    ┌────────────────────┐
│ Phase 3.2: Nesting│    │ Phase 3.3: Dates   │
│ Uses: parent_id,  │    │ Uses: due_date,    │
│       position    │    │       start_date   │
└───────────────────┘    └────────────────────┘
        │                         │
        └────────────┬────────────┘
                     ▼
           ┌──────────────────┐
           │ Integrated App   │
           │ (Foundation for  │
           │  Group 2: Voice, │
           │   Notifications) │
           └──────────────────┘
```

### Current Codebase State (Phase 2)

**Database Version:** 3
**Location:** `lib/utils/constants.dart:4`

**Current Task Schema:**
```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  completed INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  completed_at INTEGER
)
```

**Note on due_date:** PROJECT_SPEC.md documented `due_date`, `notes`, and `priority` in the
Phase 1 schema, but these were never implemented. The actual Phase 1 implementation only
includes 5 columns (id, title, completed, created_at, completed_at). We are adding
`due_date` and related columns NOW in Phase 3 for the first time.

**Task Model:** `lib/models/task.dart`
```dart
class Task {
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;
  // No parent_id, position, due_date yet
}
```

---

## Phase 3.1: Database Migration (v3 → v4)

### Goals

1. Add task nesting columns (parent_id, position)
2. Add date columns (due_date, is_all_day, start_date)
3. Add template and notification columns
4. Create 6 new tables (user_settings, task_images, entities, tags, junctions)
5. Create 12 performance indexes
6. Backfill position column to preserve task order
7. Ensure zero data loss with rollback capability

### Migration Checklist Reference

**Comprehensive testing protocol:** `docs/phase-03/db-migration-checklist.md`

This plan provides implementation details. The checklist provides step-by-step verification.

---

### Step 1: Update Database Version

**File:** `lib/utils/constants.dart`

```dart
// BEFORE (Phase 2)
static const int databaseVersion = 3; // Phase 2 Stretch: Added api_usage_log table

// AFTER (Phase 3)
static const int databaseVersion = 4; // Phase 3: Task nesting, dates, user settings
```

---

### Step 2: Extend Task Model

**File:** `lib/models/task.dart`

**Current Model:**
```dart
class Task {
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
    this.completedAt,
  });

  // toMap, fromMap methods...
}
```

**NEW Model (Phase 3):**
```dart
class Task {
  // Existing fields
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Phase 3.1: Nesting support
  final String? parentId;         // NULL = top-level task
  final int position;             // Order within parent (or root level)
  final int depth;                // Hierarchy depth (0-3, populated by queries)

  // Phase 3.1: Template support
  final bool isTemplate;          // true = task is a template

  // Phase 3.1: Date support
  final DateTime? dueDate;        // NULL = no due date
  final bool isAllDay;            // true = all-day task (no specific time)
  final DateTime? startDate;      // For multi-day tasks ("weekend")

  // Phase 3.1: Notification support
  final String notificationType;  // 'use_global', 'custom', 'none'
  final DateTime? notificationTime; // Custom notification time

  Task({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    // New fields with defaults
    this.parentId,
    this.position = 0,
    this.depth = 0,
    this.isTemplate = false,
    this.dueDate,
    this.isAllDay = true,
    this.startDate,
    this.notificationType = 'use_global',
    this.notificationTime,
  });

  /// Serialize to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      // New fields
      'parent_id': parentId,
      'position': position,
      'depth': depth,
      'is_template': isTemplate ? 1 : 0,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'is_all_day': isAllDay ? 1 : 0,
      'start_date': startDate?.millisecondsSinceEpoch,
      'notification_type': notificationType,
      'notification_time': notificationTime?.millisecondsSinceEpoch,
    };
  }

  /// Deserialize from database map
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      completed: map['completed'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      // New fields (handle NULL for backward compatibility)
      parentId: map['parent_id'] as String?,
      position: (map['position'] as int?) ?? 0,
      depth: (map['depth'] as int?) ?? 0,
      isTemplate: (map['is_template'] as int?) == 1,
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
          : null,
      isAllDay: (map['is_all_day'] as int?) == null ? true : map['is_all_day'] != 0,
      startDate: map['start_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int)
          : null,
      notificationType: (map['notification_type'] as String?) ?? 'use_global',
      notificationTime: map['notification_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['notification_time'] as int)
          : null,
    );
  }

  /// Copy with method for immutable updates
  Task copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
    DateTime? completedAt,
    String? parentId,
    int? position,
    int? depth,
    bool? isTemplate,
    DateTime? dueDate,
    bool? isAllDay,
    DateTime? startDate,
    String? notificationType,
    DateTime? notificationTime,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      parentId: parentId ?? this.parentId,
      position: position ?? this.position,
      depth: depth ?? this.depth,
      isTemplate: isTemplate ?? this.isTemplate,
      dueDate: dueDate ?? this.dueDate,
      isAllDay: isAllDay ?? this.isAllDay,
      startDate: startDate ?? this.startDate,
      notificationType: notificationType ?? this.notificationType,
      notificationTime: notificationTime ?? this.notificationTime,
    );
  }
}
```

**Testing:** Write unit tests for `toMap()` and `fromMap()` with new fields.

---

### Step 3: Create New Model Classes

#### A. UserSettings Model

**File:** `lib/models/user_settings.dart` (NEW FILE)

```dart
class UserSettings {
  final int id; // Always 1 (single-row table)

  // Time keyword preferences
  final int earlyMorningHour;  // "early morning" / "dawn"
  final int morningHour;       // "morning"
  final int noonHour;          // "noon" / "lunch" / "midday"
  final int afternoonHour;     // "afternoon"
  final int tonightHour;       // "tonight" / "evening"
  final int lateNightHour;     // "late night"

  // Night owl settings
  final int todayCutoffHour;   // "today" window cutoff hour
  final int todayCutoffMinute; // "today" window cutoff minute

  // Week/calendar preferences
  final int weekStartDay;      // 0=Sunday, 1=Monday, etc.

  // Timezone preferences
  final String? timezoneId;    // IANA timezone ID (e.g., 'America/Detroit')

  // Display preferences
  final bool use24HourTime;    // 12-hour vs 24-hour display

  // Task behavior preferences
  final String autoCompleteChildren; // 'prompt', 'always', 'never'

  // Notification preferences
  final int defaultNotificationHour;
  final int defaultNotificationMinute;

  // Voice input preferences
  final bool voiceSmartPunctuation;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    this.id = 1,
    this.earlyMorningHour = 5,
    this.morningHour = 9,
    this.noonHour = 12,
    this.afternoonHour = 15,
    this.tonightHour = 19,
    this.lateNightHour = 22,
    this.todayCutoffHour = 4,
    this.todayCutoffMinute = 59,
    this.weekStartDay = 1,
    this.timezoneId,
    this.use24HourTime = false,
    this.autoCompleteChildren = 'prompt',
    this.defaultNotificationHour = 9,
    this.defaultNotificationMinute = 0,
    this.voiceSmartPunctuation = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'early_morning_hour': earlyMorningHour,
      'morning_hour': morningHour,
      'noon_hour': noonHour,
      'afternoon_hour': afternoonHour,
      'tonight_hour': tonightHour,
      'late_night_hour': lateNightHour,
      'today_cutoff_hour': todayCutoffHour,
      'today_cutoff_minute': todayCutoffMinute,
      'week_start_day': weekStartDay,
      'timezone_id': timezoneId,
      'use_24hour_time': use24HourTime ? 1 : 0,
      'auto_complete_children': autoCompleteChildren,
      'default_notification_hour': defaultNotificationHour,
      'default_notification_minute': defaultNotificationMinute,
      'voice_smart_punctuation': voiceSmartPunctuation ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] as int,
      earlyMorningHour: map['early_morning_hour'] as int,
      morningHour: map['morning_hour'] as int,
      noonHour: map['noon_hour'] as int,
      afternoonHour: map['afternoon_hour'] as int,
      tonightHour: map['tonight_hour'] as int,
      lateNightHour: map['late_night_hour'] as int,
      todayCutoffHour: map['today_cutoff_hour'] as int,
      todayCutoffMinute: map['today_cutoff_minute'] as int,
      weekStartDay: map['week_start_day'] as int,
      timezoneId: map['timezone_id'] as String?,
      use24HourTime: map['use_24hour_time'] == 1,
      autoCompleteChildren: map['auto_complete_children'] as String,
      defaultNotificationHour: map['default_notification_hour'] as int,
      defaultNotificationMinute: map['default_notification_minute'] as int,
      voiceSmartPunctuation: map['voice_smart_punctuation'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// Create default settings (for first-time initialization)
  factory UserSettings.defaults() {
    final now = DateTime.now();
    return UserSettings(
      createdAt: now,
      updatedAt: now,
    );
  }

  UserSettings copyWith({
    int? earlyMorningHour,
    int? morningHour,
    int? noonHour,
    int? afternoonHour,
    int? tonightHour,
    int? lateNightHour,
    int? todayCutoffHour,
    int? todayCutoffMinute,
    int? weekStartDay,
    String? timezoneId,
    bool? use24HourTime,
    String? autoCompleteChildren,
    int? defaultNotificationHour,
    int? defaultNotificationMinute,
    bool? voiceSmartPunctuation,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      id: id,
      earlyMorningHour: earlyMorningHour ?? this.earlyMorningHour,
      morningHour: morningHour ?? this.morningHour,
      noonHour: noonHour ?? this.noonHour,
      afternoonHour: afternoonHour ?? this.afternoonHour,
      tonightHour: tonightHour ?? this.tonightHour,
      lateNightHour: lateNightHour ?? this.lateNightHour,
      todayCutoffHour: todayCutoffHour ?? this.todayCutoffHour,
      todayCutoffMinute: todayCutoffMinute ?? this.todayCutoffMinute,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      timezoneId: timezoneId ?? this.timezoneId,
      use24HourTime: use24HourTime ?? this.use24HourTime,
      autoCompleteChildren: autoCompleteChildren ?? this.autoCompleteChildren,
      defaultNotificationHour: defaultNotificationHour ?? this.defaultNotificationHour,
      defaultNotificationMinute: defaultNotificationMinute ?? this.defaultNotificationMinute,
      voiceSmartPunctuation: voiceSmartPunctuation ?? this.voiceSmartPunctuation,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
```

**Note:** Other models (TaskImage, Entity, Tag) are deferred to Phases 5-6. We're creating the tables now for future-proofing, but no Dart models needed yet.

---

### Step 4: Implement Database Migration

**File:** `lib/services/database_service.dart`

**Current Structure:**
```dart
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

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
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys BEFORE onCreate/onUpgrade
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // onCreate, onUpgrade methods...
}
```

**Add v3 → v4 Migration to `_upgradeDB`:**

```dart
Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  // Existing migrations (v1→v2, v2→v3) remain unchanged...

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
    await txn.execute('''
      UPDATE ${AppConstants.tasksTable}
      SET position = (
        SELECT COUNT(*)
        FROM ${AppConstants.tasksTable} AS t2
        WHERE (
          (t2.parent_id IS NULL AND ${AppConstants.tasksTable}.parent_id IS NULL)
          OR (t2.parent_id = ${AppConstants.tasksTable}.parent_id)
        )
          AND t2.created_at <= ${AppConstants.tasksTable}.created_at
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

  print('✅ Database migrated to v4 successfully');
}
```

---

### Step 5: Update AppConstants

**File:** `lib/utils/constants.dart`

Add table name constants:

```dart
class AppConstants {
  // Database configuration
  static const String databaseName = 'pin_and_paper.db';
  static const int databaseVersion = 4; // Updated from 3

  // Existing table names
  static const String tasksTable = 'tasks';
  static const String brainDumpDraftsTable = 'brain_dump_drafts';
  static const String apiUsageLogTable = 'api_usage_log';

  // NEW: Phase 3 table names
  static const String userSettingsTable = 'user_settings';
  static const String taskImagesTable = 'task_images';
  static const String entitiesTable = 'entities';
  static const String tagsTable = 'tags';
  static const String taskEntitiesTable = 'task_entities';
  static const String taskTagsTable = 'task_tags';

  // ...existing constants...
}
```

---

### Step 6: Create UserSettings Service

**File:** `lib/services/user_settings_service.dart` (NEW FILE)

```dart
import 'package:sqflite/sqflite.dart';
import '../models/user_settings.dart';
import '../utils/constants.dart';
import 'database_service.dart';

class UserSettingsService {
  final DatabaseService _databaseService = DatabaseService();

  /// Get user settings (always exists - seeded during migration)
  Future<UserSettings> getUserSettings() async {
    final db = await _databaseService.database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.userSettingsTable,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (maps.isEmpty) {
      throw Exception('User settings not found - database may not be migrated');
    }

    return UserSettings.fromMap(maps.first);
  }

  /// Update user settings
  Future<UserSettings> updateUserSettings(UserSettings settings) async {
    final db = await _databaseService.database;

    final updatedSettings = settings.copyWith(updatedAt: DateTime.now());

    await db.update(
      AppConstants.userSettingsTable,
      updatedSettings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );

    return updatedSettings;
  }

  /// Update a single time keyword (convenience method)
  Future<UserSettings> updateTimeKeyword({
    int? earlyMorningHour,
    int? morningHour,
    int? noonHour,
    int? afternoonHour,
    int? tonightHour,
    int? lateNightHour,
  }) async {
    final current = await getUserSettings();

    return updateUserSettings(current.copyWith(
      earlyMorningHour: earlyMorningHour,
      morningHour: morningHour,
      noonHour: noonHour,
      afternoonHour: afternoonHour,
      tonightHour: tonightHour,
      lateNightHour: lateNightHour,
    ));
  }

  /// Update day boundary cutoff (convenience method)
  Future<UserSettings> updateDayBoundary({
    required int hour,
    required int minute,
  }) async {
    final current = await getUserSettings();

    return updateUserSettings(current.copyWith(
      todayCutoffHour: hour,
      todayCutoffMinute: minute,
    ));
  }
}
```

---

### Step 7: Testing Phase 3.1 Migration

#### Unit Tests

**File:** `test/models/task_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart';

void main() {
  group('Task Model - Phase 3 Fields', () {
    test('toMap includes all Phase 3 fields', () {
      final task = Task(
        id: 'test-id',
        title: 'Test task',
        completed: false,
        createdAt: DateTime(2025, 1, 1),
        parentId: 'parent-id',
        position: 5,
        isTemplate: true,
        dueDate: DateTime(2025, 1, 15),
        isAllDay: false,
        startDate: DateTime(2025, 1, 14),
        notificationType: 'custom',
        notificationTime: DateTime(2025, 1, 15, 9, 0),
      );

      final map = task.toMap();

      expect(map['parent_id'], 'parent-id');
      expect(map['position'], 5);
      expect(map['is_template'], 1);
      expect(map['due_date'], DateTime(2025, 1, 15).millisecondsSinceEpoch);
      expect(map['is_all_day'], 0);
      expect(map['start_date'], DateTime(2025, 1, 14).millisecondsSinceEpoch);
      expect(map['notification_type'], 'custom');
      expect(map['notification_time'], DateTime(2025, 1, 15, 9, 0).millisecondsSinceEpoch);
    });

    test('fromMap correctly deserializes Phase 3 fields', () {
      final map = {
        'id': 'test-id',
        'title': 'Test task',
        'completed': 0,
        'created_at': DateTime(2025, 1, 1).millisecondsSinceEpoch,
        'completed_at': null,
        'parent_id': 'parent-id',
        'position': 3,
        'is_template': 1,
        'due_date': DateTime(2025, 1, 15).millisecondsSinceEpoch,
        'is_all_day': 0,
        'start_date': DateTime(2025, 1, 14).millisecondsSinceEpoch,
        'notification_type': 'custom',
        'notification_time': DateTime(2025, 1, 15, 9, 0).millisecondsSinceEpoch,
      };

      final task = Task.fromMap(map);

      expect(task.parentId, 'parent-id');
      expect(task.position, 3);
      expect(task.isTemplate, true);
      expect(task.dueDate, DateTime(2025, 1, 15));
      expect(task.isAllDay, false);
      expect(task.startDate, DateTime(2025, 1, 14));
      expect(task.notificationType, 'custom');
      expect(task.notificationTime, DateTime(2025, 1, 15, 9, 0));
    });

    test('fromMap handles NULL Phase 3 fields (backward compatibility)', () {
      final map = {
        'id': 'test-id',
        'title': 'Test task',
        'completed': 0,
        'created_at': DateTime(2025, 1, 1).millisecondsSinceEpoch,
        'completed_at': null,
        // Phase 3 fields all NULL
        'parent_id': null,
        'position': null,
        'is_template': null,
        'due_date': null,
        'is_all_day': null,
        'start_date': null,
        'notification_type': null,
        'notification_time': null,
      };

      final task = Task.fromMap(map);

      expect(task.parentId, null);
      expect(task.position, 0); // Default
      expect(task.isTemplate, false); // Default
      expect(task.dueDate, null);
      expect(task.isAllDay, true); // Default
      expect(task.startDate, null);
      expect(task.notificationType, 'use_global'); // Default
      expect(task.notificationTime, null);
    });
  });
}
```

**File:** `test/models/user_settings_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/user_settings.dart';

void main() {
  group('UserSettings Model', () {
    test('defaults factory creates valid settings', () {
      final settings = UserSettings.defaults();

      expect(settings.id, 1);
      expect(settings.earlyMorningHour, 5);
      expect(settings.morningHour, 9);
      expect(settings.todayCutoffHour, 4);
      expect(settings.todayCutoffMinute, 59);
      expect(settings.autoCompleteChildren, 'prompt');
    });

    test('toMap and fromMap round-trip correctly', () {
      final settings = UserSettings.defaults();
      final map = settings.toMap();
      final restored = UserSettings.fromMap(map);

      expect(restored.id, settings.id);
      expect(restored.earlyMorningHour, settings.earlyMorningHour);
      expect(restored.morningHour, settings.morningHour);
      expect(restored.use24HourTime, settings.use24HourTime);
    });

    test('copyWith updates specified fields only', () {
      final settings = UserSettings.defaults();
      final updated = settings.copyWith(
        morningHour: 10,
        afternoonHour: 14,
      );

      expect(updated.morningHour, 10);
      expect(updated.afternoonHour, 14);
      expect(updated.earlyMorningHour, 5); // Unchanged
      expect(updated.todayCutoffHour, 4); // Unchanged
    });
  });
}
```

#### Integration Tests

**File:** `test/services/database_service_migration_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/utils/constants.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Migration v3 → v4', () {
    late DatabaseService databaseService;

    setUp(() {
      databaseService = DatabaseService();
    });

    tearDown(() async {
      final db = await databaseService.database;
      await db.close();
      await deleteDatabase(db.path);
    });

    test('Migration creates all new columns', () async {
      final db = await databaseService.database;

      // Check tasks table has new columns
      final taskColumns = await db.rawQuery('PRAGMA table_info(${AppConstants.tasksTable})');
      final columnNames = taskColumns.map((col) => col['name'] as String).toList();

      expect(columnNames, contains('parent_id'));
      expect(columnNames, contains('position'));
      expect(columnNames, contains('is_template'));
      expect(columnNames, contains('due_date'));
      expect(columnNames, contains('is_all_day'));
      expect(columnNames, contains('start_date'));
      expect(columnNames, contains('notification_type'));
      expect(columnNames, contains('notification_time'));
    });

    test('Migration creates all new tables', () async {
      final db = await databaseService.database;

      // Get all table names
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains(AppConstants.userSettingsTable));
      expect(tableNames, contains(AppConstants.taskImagesTable));
      expect(tableNames, contains(AppConstants.entitiesTable));
      expect(tableNames, contains(AppConstants.tagsTable));
      expect(tableNames, contains(AppConstants.taskEntitiesTable));
      expect(tableNames, contains(AppConstants.taskTagsTable));
    });

    test('Migration creates all indexes', () async {
      final db = await databaseService.database;

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'"
      );
      final indexNames = indexes.map((i) => i['name'] as String).toList();

      // Check for all 12 Phase 3 indexes
      expect(indexNames, contains('idx_tasks_parent'));
      expect(indexNames, contains('idx_tasks_due_date'));
      expect(indexNames, contains('idx_tasks_start_date'));
      expect(indexNames, contains('idx_tasks_template'));
      expect(indexNames, contains('idx_task_images_task'));
      expect(indexNames, contains('idx_task_images_hero'));
      expect(indexNames, contains('idx_entities_name'));
      expect(indexNames, contains('idx_tags_name'));
      expect(indexNames, contains('idx_task_entities_entity'));
      expect(indexNames, contains('idx_task_entities_task'));
      expect(indexNames, contains('idx_task_tags_tag'));
      expect(indexNames, contains('idx_task_tags_task'));
    });

    test('Migration seeds user_settings table', () async {
      final db = await databaseService.database;

      final result = await db.query(AppConstants.userSettingsTable);

      expect(result.length, 1);
      expect(result.first['id'], 1);
      expect(result.first['morning_hour'], 9);
      expect(result.first['today_cutoff_hour'], 4);
      expect(result.first['today_cutoff_minute'], 59);
    });

    test('Position backfill assigns correct values', () async {
      final db = await databaseService.database;

      // Create test tasks with known created_at order
      await db.insert(AppConstants.tasksTable, {
        'id': 'task-1',
        'title': 'First task',
        'completed': 0,
        'created_at': DateTime(2025, 1, 1, 10, 0).millisecondsSinceEpoch,
      });

      await db.insert(AppConstants.tasksTable, {
        'id': 'task-2',
        'title': 'Second task',
        'completed': 0,
        'created_at': DateTime(2025, 1, 1, 11, 0).millisecondsSinceEpoch,
      });

      await db.insert(AppConstants.tasksTable, {
        'id': 'task-3',
        'title': 'Third task',
        'completed': 0,
        'created_at': DateTime(2025, 1, 1, 12, 0).millisecondsSinceEpoch,
      });

      // Position backfill should have already run during migration
      // Verify positions are assigned in created_at order
      final tasks = await db.query(
        AppConstants.tasksTable,
        orderBy: 'position ASC',
      );

      expect(tasks[0]['id'], 'task-1'); // position = 0
      expect(tasks[0]['position'], 0);
      expect(tasks[1]['id'], 'task-2'); // position = 1
      expect(tasks[1]['position'], 1);
      expect(tasks[2]['id'], 'task-3'); // position = 2
      expect(tasks[2]['position'], 2);
    });

    test('CASCADE delete constraint works for parent-child', () async {
      final db = await databaseService.database;

      // Create parent task
      await db.insert(AppConstants.tasksTable, {
        'id': 'parent',
        'title': 'Parent task',
        'completed': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Create child task
      await db.insert(AppConstants.tasksTable, {
        'id': 'child',
        'title': 'Child task',
        'completed': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'parent_id': 'parent',
      });

      // Verify both exist
      final beforeDelete = await db.query(AppConstants.tasksTable);
      expect(beforeDelete.length, 2);

      // Delete parent
      await db.delete(
        AppConstants.tasksTable,
        where: 'id = ?',
        whereArgs: ['parent'],
      );

      // Child should be CASCADE deleted
      final afterDelete = await db.query(AppConstants.tasksTable);
      expect(afterDelete.length, 0);
    });
  });
}
```

---

### Phase 3.1 Completion Criteria

- [ ] Database version updated to 4
- [ ] Task model extended with all Phase 3 fields
- [ ] UserSettings model created and tested
- [ ] Migration script implemented in `_upgradeDB`
- [ ] All 12 indexes created
- [ ] Position backfill logic tested with real data
- [ ] Foreign key CASCADE constraints verified
- [ ] User settings service created
- [ ] Unit tests pass for Task and UserSettings models
- [ ] Integration tests pass for migration
- [ ] Manual testing on Phase 2 snapshot database (see db-migration-checklist.md)
- [ ] Rollback procedure tested successfully

**Estimated Time:** 2-3 days

---

## Phase 3.2: Task Nesting & Hierarchy

### Goals

1. Display tasks with visual hierarchy (4-level max depth)
2. Implement expand/collapse for parent tasks
3. Add reorder mode with drag-to-nest/unnest support
4. Implement context menu (long press)
5. CASCADE delete protection with confirmation dialog
6. Auto-complete children prompt

### Architecture

```
┌──────────────────────────────────────────────────────┐
│                    HomeScreen                        │
│  ┌────────────────────────────────────────────────┐ │
│  │         TaskProvider (State)                   │ │
│  │  - Fetch hierarchical tasks                    │ │
│  │  - Track collapse/expand state                 │ │
│  │  - Handle reorder operations                   │ │
│  └───────────────┬────────────────────────────────┘ │
│                  │                                   │
│     ┌────────────┴────────────┐                     │
│     ▼                          ▼                     │
│  ┌─────────────┐          ┌────────────┐            │
│  │ TaskItem    │          │ ReorderMode│            │
│  │ - Indent    │          │ - Drag     │            │
│  │ - Expand btn│          │ - Drop     │            │
│  │ - Long press│          │ - Visual   │            │
│  └─────────────┘          └────────────┘            │
└──────────────────────────────────────────────────────┘
```

---

### Step 1: Update TaskService for Hierarchy

**File:** `lib/services/task_service.dart`

Add methods for hierarchical queries and reordering:

```dart
class TaskService {
  final DatabaseService _databaseService = DatabaseService();

  // ...existing methods (getAllTasks, createTask, etc.)...

  /// Get all tasks with hierarchy information
  /// Returns flat list ordered by parent_id and position
  Future<List<Task>> getAllTasksHierarchical() async {
    final db = await _databaseService.database;

    // Recursive CTE to get tasks with depth
    // Orders by: root position, then children under parents
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      WITH RECURSIVE task_tree AS (
        -- Base case: root-level tasks (parent_id IS NULL)
        SELECT
          *,
          0 as depth,
          printf('%05d', position) as sort_key
        FROM ${AppConstants.tasksTable}
        WHERE parent_id IS NULL

        UNION ALL

        -- Recursive case: children of tasks
        SELECT
          t.*,
          tt.depth + 1 as depth,
          tt.sort_key || '.' || printf('%05d', t.position) as sort_key
        FROM ${AppConstants.tasksTable} t
        INNER JOIN task_tree tt ON t.parent_id = tt.id
        WHERE tt.depth < 4  -- Max 4 levels (0-indexed: 0, 1, 2, 3)
      )
      SELECT * FROM task_tree
      ORDER BY sort_key
    ''');

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Update task position (for reordering within same parent)
  Future<void> updateTaskPosition(String taskId, int newPosition) async {
    final db = await _databaseService.database;

    await db.update(
      AppConstants.tasksTable,
      {'position': newPosition},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Move task to new parent (for nesting/unnesting)
  Future<void> updateTaskParent({
    required String taskId,
    String? newParentId,
    required int newPosition,
  }) async {
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      // 1. Validate depth if moving to new parent
      if (newParentId != null) {
        final depth = await _getTaskDepth(newParentId, txn);
        if (depth >= 3) {
          throw Exception('Maximum nesting depth (4 levels) exceeded');
        }
      }

      // 2. Check for cycles - prevent moving task under its own descendant
      if (newParentId != null && await _wouldCreateCycle(taskId, newParentId, txn)) {
        throw Exception('Cannot move task under its own descendant');
      }

      // 3. Get old parent for source list reindexing
      final oldTaskResult = await txn.query(
        AppConstants.tasksTable,
        columns: ['parent_id'],
        where: 'id = ?',
        whereArgs: [taskId],
      );
      final oldParentId = oldTaskResult.isNotEmpty
          ? oldTaskResult.first['parent_id'] as String?
          : null;

      // 4. Move task to new parent with new position
      await txn.update(
        AppConstants.tasksTable,
        {
          'parent_id': newParentId,
          'position': newPosition,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      // 5. Reindex siblings in SOURCE list (old parent)
      await _reindexSiblings(oldParentId, txn);

      // 6. Reindex siblings in DESTINATION list (new parent)
      await _reindexSiblings(newParentId, txn);
    });
  }

  /// Get depth of a task in the hierarchy
  Future<int> _getTaskDepth(String taskId, [dynamic dbOrTxn]) async {
    final db = dbOrTxn ?? await _databaseService.database;

    final result = await db.rawQuery('''
      WITH RECURSIVE parent_chain AS (
        SELECT id, parent_id, 0 as depth
        FROM ${AppConstants.tasksTable}
        WHERE id = ?

        UNION ALL

        SELECT t.id, t.parent_id, pc.depth + 1
        FROM ${AppConstants.tasksTable} t
        INNER JOIN parent_chain pc ON t.id = pc.parent_id
      )
      SELECT MAX(depth) as max_depth FROM parent_chain
    ''', [taskId]);

    return (result.first['max_depth'] as int?) ?? 0;
  }

  /// Check if moving taskId under newParentId would create a cycle
  Future<bool> _wouldCreateCycle(
    String taskId,
    String newParentId,
    dynamic txn,
  ) async {
    // Walk up from newParentId to root, checking if we hit taskId
    String? current = newParentId;

    while (current != null) {
      if (current == taskId) {
        return true;  // Cycle detected!
      }

      final parent = await txn.query(
        AppConstants.tasksTable,
        columns: ['parent_id'],
        where: 'id = ?',
        whereArgs: [current],
      );

      if (parent.isEmpty) break;
      current = parent.first['parent_id'] as String?;
    }

    return false;  // No cycle
  }

  /// Reindex siblings under a parent to maintain sequential positions
  Future<void> _reindexSiblings(String? parentId, dynamic txn) async {
    final siblings = await txn.query(
      AppConstants.tasksTable,
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'position ASC',
    );

    for (int i = 0; i < siblings.length; i++) {
      await txn.update(
        AppConstants.tasksTable,
        {'position': i},
        where: 'id = ?',
        whereArgs: [siblings[i]['id']],
      );
    }
  }

  /// Get children of a task
  Future<List<Task>> getChildTasks(String parentId) async {
    final db = await _databaseService.database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tasksTable,
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'position ASC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Delete task with CASCADE (returns count of deleted tasks including children)
  Future<int> deleteTaskWithChildren(String taskId) async {
    final db = await _databaseService.database;

    // Get count of children for confirmation dialog
    final childCount = await countDescendants(taskId);

    // Delete task (CASCADE will handle children automatically)
    await db.delete(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
    );

    return childCount + 1; // +1 for parent
  }

  /// Count descendants recursively
  Future<int> countDescendants(String taskId) async {
    final db = await _databaseService.database;

    final result = await db.rawQuery('''
      WITH RECURSIVE descendants AS (
        SELECT id FROM ${AppConstants.tasksTable} WHERE parent_id = ?
        UNION ALL
        SELECT t.id FROM ${AppConstants.tasksTable} t
        INNER JOIN descendants d ON t.parent_id = d.id
      )
      SELECT COUNT(*) as count FROM descendants
    ''', [taskId]);

    return (result.first['count'] as int?) ?? 0;
  }

  /// Reorder tasks in bulk (after drag-and-drop)
  Future<void> reorderTasks(List<Task> tasks) async {
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      for (int i = 0; i < tasks.length; i++) {
        await txn.update(
          AppConstants.tasksTable,
          {
            'parent_id': tasks[i].parentId,
            'position': i,
          },
          where: 'id = ?',
          whereArgs: [tasks[i].id],
        );
      }
    });
  }
}
```

---

### Step 2: Update TaskProvider for Hierarchy

**File:** `lib/providers/task_provider.dart`

Add state for hierarchy and reordering:

```dart
class TaskProvider with ChangeNotifier {
  final TaskService _taskService = TaskService();

  // Existing state
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // NEW: Hierarchy state
  Set<String> _collapsedTaskIds = {}; // IDs of collapsed parent tasks
  bool _isReorderMode = false;

  // Getters
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<String> get collapsedTaskIds => _collapsedTaskIds;
  bool get isReorderMode => _isReorderMode;

  /// Load tasks with hierarchy
  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _taskService.getAllTasksHierarchical();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load tasks: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get visible tasks (respecting collapsed state)
  List<Task> get visibleTasks {
    final visible = <Task>[];
    final hiddenParents = <String>{};

    for (final task in _tasks) {
      // Skip if any ancestor is collapsed
      if (task.parentId != null && hiddenParents.contains(task.parentId)) {
        hiddenParents.add(task.id); // Hide descendants too
        continue;
      }

      visible.add(task);

      // If this task is collapsed, hide its children
      if (_collapsedTaskIds.contains(task.id)) {
        hiddenParents.add(task.id);
      }
    }

    return visible;
  }

  /// Toggle collapse/expand for a parent task
  void toggleCollapse(String taskId) {
    if (_collapsedTaskIds.contains(taskId)) {
      _collapsedTaskIds.remove(taskId);
    } else {
      _collapsedTaskIds.add(taskId);
    }
    notifyListeners();
  }

  /// Check if task has children
  bool hasChildren(String taskId) {
    return _tasks.any((t) => t.parentId == taskId);
  }

  /// Enter/exit reorder mode
  void setReorderMode(bool enabled) {
    _isReorderMode = enabled;
    notifyListeners();
  }

  /// Reorder tasks (drag and drop)
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    final visible = visibleTasks;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final task = visible.removeAt(oldIndex);
    visible.insert(newIndex, task);

    // Update positions in database
    await _taskService.reorderTasks(visible);

    // Reload to refresh from database
    await loadTasks();
  }

  /// Move task to new parent (nest/unnest)
  Future<void> changeTaskParent({
    required String taskId,
    String? newParentId,
    required int newPosition,
  }) async {
    try {
      await _taskService.updateTaskParent(
        taskId: taskId,
        newParentId: newParentId,
        newPosition: newPosition,
      );
      await loadTasks();
    } catch (e) {
      _errorMessage = 'Failed to nest task: $e';
      notifyListeners();
    }
  }

  /// Delete task with CASCADE confirmation
  Future<bool> deleteTaskWithConfirmation(
    String taskId,
    Future<bool> Function(int) showConfirmation,
  ) async {
    try {
      // Get child count for confirmation
      final childCount = await _taskService.countDescendants(taskId);

      // Show confirmation if has children
      if (childCount > 0) {
        final confirmed = await showConfirmation(childCount);
        if (!confirmed) return false;
      }

      // Delete task (CASCADE handles children)
      await _taskService.deleteTaskWithChildren(taskId);
      await loadTasks();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete task: $e';
      notifyListeners();
      return false;
    }
  }

  // ...existing methods (createTask, toggleCompletion, etc.)...
}
```

---

### Step 3: Update HomeScreen for Hierarchy

**File:** `lib/screens/home_screen.dart`

Replace ListView with hierarchical display:

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin and Paper'),
        actions: [
          // Reorder mode toggle
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              return IconButton(
                icon: Icon(
                  taskProvider.isReorderMode ? Icons.check : Icons.reorder,
                ),
                tooltip: taskProvider.isReorderMode ? 'Done' : 'Reorder',
                onPressed: () {
                  taskProvider.setReorderMode(!taskProvider.isReorderMode);
                },
              );
            },
          ),
          // Settings, API usage, etc. (existing)
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          if (taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (taskProvider.errorMessage != null) {
            return Center(child: Text(taskProvider.errorMessage!));
          }

          final visibleTasks = taskProvider.visibleTasks;

          if (visibleTasks.isEmpty) {
            return const Center(
              child: Text('No tasks yet.\nAdd one above!'),
            );
          }

          // Reorder mode: Use ReorderableListView
          if (taskProvider.isReorderMode) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: visibleTasks.length,
              onReorder: taskProvider.reorderTasks,
              itemBuilder: (context, index) {
                final task = visibleTasks[index];
                return TaskItem(
                  key: ValueKey(task.id),
                  task: task,
                  isReorderMode: true,
                  hasChildren: taskProvider.hasChildren(task.id),
                  isCollapsed: taskProvider.collapsedTaskIds.contains(task.id),
                  onToggleCollapse: () => taskProvider.toggleCollapse(task.id),
                );
              },
            );
          }

          // Normal mode: Regular ListView
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visibleTasks.length,
            itemBuilder: (context, index) {
              final task = visibleTasks[index];
              return TaskItem(
                key: ValueKey(task.id),
                task: task,
                isReorderMode: false,
                hasChildren: taskProvider.hasChildren(task.id),
                isCollapsed: taskProvider.collapsedTaskIds.contains(task.id),
                onToggleCollapse: () => taskProvider.toggleCollapse(task.id),
              );
            },
          );
        },
      ),
      // Floating action button, bottom sheet, etc. (existing)
    );
  }
}
```

---

### Step 4: Update TaskItem Widget for Hierarchy

**File:** `lib/widgets/task_item.dart`

Add visual hierarchy and interactions:

```dart
class TaskItem extends StatelessWidget {
  final Task task;
  final bool isReorderMode;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const TaskItem({
    Key? key,
    required this.task,
    required this.isReorderMode,
    required this.hasChildren,
    required this.isCollapsed,
    required this.onToggleCollapse,
  }) : super(key: key);

  /// Get depth from Task model (populated by hierarchical query)
  int get depth {
    return task.depth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Indentation: 16px per level
    final indentation = depth * 16.0;

    return GestureDetector(
      onLongPress: isReorderMode ? null : () => _showContextMenu(context),
      child: Container(
        margin: EdgeInsets.only(
          left: 16 + indentation,
          right: 16,
          top: 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          // Leading: Expand/collapse or drag handle
          leading: _buildLeading(theme),
          // Title: Task text
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.completed ? TextDecoration.lineThrough : null,
              color: task.completed
                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                  : theme.colorScheme.onSurface,
            ),
          ),
          // Trailing: Checkbox
          trailing: Checkbox(
            value: task.completed,
            onChanged: isReorderMode
                ? null
                : (_) {
                    context.read<TaskProvider>().toggleTaskCompletion(task);
                  },
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(ThemeData theme) {
    if (isReorderMode) {
      // Reorder mode: Show drag handle
      return Icon(
        Icons.drag_handle,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      );
    }

    if (hasChildren) {
      // Parent task: Show expand/collapse button
      return IconButton(
        icon: Icon(
          isCollapsed ? Icons.chevron_right : Icons.expand_more,
        ),
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        onPressed: onToggleCollapse,
      );
    }

    // Leaf task: No leading icon
    return const SizedBox(width: 24);
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => TaskContextMenu(task: task),
    );
  }
}
```

---

### Step 5: Implement Context Menu

**File:** `lib/widgets/task_context_menu.dart` (NEW FILE)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskContextMenu extends StatelessWidget {
  final Task task;

  const TaskContextMenu({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              task.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),

          // Edit
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Open edit dialog
            },
          ),

          // Save as Template
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Save as Template'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement template save
            },
          ),

          // Convert to Subtask
          if (task.parentId == null)
            ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right),
              title: const Text('Convert to Subtask'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show parent picker
              },
            ),

          // Promote to Parent (if is subtask)
          if (task.parentId != null)
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Promote to Top Level'),
              onTap: () {
                Navigator.pop(context);
                context.read<TaskProvider>().changeTaskParent(
                  taskId: task.id,
                  newParentId: null,
                  newPosition: 0,
                );
              },
            ),

          const Divider(),

          // Delete
          ListTile(
            leading: Icon(Icons.delete, color: theme.colorScheme.error),
            title: Text(
              'Delete',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();

    final deleted = await taskProvider.deleteTaskWithConfirmation(
      task.id,
      (childCount) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task?'),
            content: Text(
              childCount > 0
                  ? 'This task has $childCount subtask(s). All subtasks will be deleted too.'
                  : 'Are you sure you want to delete this task?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
    );

    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted')),
      );
    }
  }
}
```

---

### Phase 3.2 Completion Criteria

- [ ] TaskService implements hierarchical queries
- [ ] TaskProvider manages collapse/expand state
- [ ] HomeScreen displays tasks with indentation
- [ ] ReorderableListView implemented for reorder mode
- [ ] TaskItem shows expand/collapse buttons for parents
- [ ] Drag handle visible in reorder mode
- [ ] Context menu implemented with all actions
- [ ] CASCADE delete confirmation dialog works
- [ ] Maximum nesting depth (4 levels) enforced
- [ ] Collapsed tasks hide children correctly
- [ ] Unit tests for TaskService hierarchy methods
- [ ] Widget tests for TaskItem hierarchy display
- [ ] Integration tests for reordering and nesting

**Estimated Time:** 3-4 days

---

## Phase 3.3: Natural Language Date Parsing

### Goals

1. Create date parser service with user_settings integration
2. Parse common date phrases ("tomorrow", "next Friday", "weekend")
3. Implement "today window" logic (night-owl support)
4. Create test fixture with 20-30 phrases
5. Integrate with Brain Dump (Claude context)
6. Integrate with manual task creation (live parsing UI - deferred to Phase 3.4)

### Architecture

```
┌─────────────────────────────────────────┐
│      DateParserService                  │
│  ┌───────────────────────────────────┐  │
│  │ User Settings Integration         │  │
│  │ - todayCutoffHour/Minute          │  │
│  │ - Time keywords (morning, tonight)│  │
│  │ - Week start day                  │  │
│  └───────────────┬───────────────────┘  │
│                  │                       │
│     ┌────────────┴────────────┐         │
│     ▼                          ▼         │
│  ┌────────────┐         ┌──────────┐    │
│  │Relative    │         │Absolute  │    │
│  │(tomorrow,  │         │(Jan 15,  │    │
│  │ next week) │         │ Monday)  │    │
│  └────────────┘         └──────────┘    │
└─────────────────────────────────────────┘
              │
    ┌─────────┴──────────┐
    ▼                    ▼
┌──────────┐      ┌─────────────┐
│Brain Dump│      │Manual Create│
│(Claude)  │      │(Todoist-    │
│          │      │ style - P3.4)│
└──────────┘      └─────────────┘
```

---

### Step 1: Create DateParserService

**File:** `lib/services/date_parser_service.dart` (NEW FILE)

```dart
import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import '../models/user_settings.dart';

/// Parsed date result with metadata
class ParsedDate {
  final DateTime? dateTime;     // Parsed date (null if no match)
  final bool isAllDay;          // true = all-day task
  final DateTime? startDate;    // For multi-day tasks ("weekend")
  final String? matchedPhrase;  // The text that was matched
  final bool isAmbiguous;       // true if multiple interpretations possible

  ParsedDate({
    this.dateTime,
    this.isAllDay = true,
    this.startDate,
    this.matchedPhrase,
    this.isAmbiguous = false,
  });
}

class DateParserService {
  final UserSettings userSettings;

  DateParserService(this.userSettings);

  /// Parse natural language date from text
  ParsedDate parse(String text) {
    final normalizedText = text.toLowerCase().trim();

    // Try parsers in order of specificity
    ParsedDate? result;

    // 1. Absolute dates (highest priority)
    result ??= _parseAbsoluteDate(normalizedText);

    // 2. Relative dates with time ("tomorrow at 3pm")
    result ??= _parseRelativeDateWithTime(normalizedText);

    // 3. Time keywords with dates ("tomorrow morning")
    result ??= _parseDateWithTimeKeyword(normalizedText);

    // 4. Weekdays ("next Friday")
    result ??= _parseWeekday(normalizedText);

    // 5. Relative dates ("tomorrow", "in 3 days")
    result ??= _parseRelativeDate(normalizedText);

    // 6. Time keywords only ("tonight")
    result ??= _parseTimeKeywordOnly(normalizedText);

    // 7. Multi-day ("weekend")
    result ??= _parseMultiDay(normalizedText);

    return result ?? ParsedDate(); // No match
  }

  /// Get user's effective "today" respecting day boundary
  DateTime getEffectiveToday() {
    final now = clock.now();  // Use clock for testability
    final cutoffHour = userSettings.todayCutoffHour;
    final cutoffMinute = userSettings.todayCutoffMinute;

    // Cutoff boundary is INCLUSIVE
    // Example: 4:59am cutoff means 4:59:59 is still "yesterday"
    if (now.hour < cutoffHour ||
        (now.hour == cutoffHour && now.minute <= cutoffMinute)) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  // ===========================================
  // PARSER IMPLEMENTATIONS
  // ===========================================

  /// Parse absolute dates: "Jan 15", "2025-01-15", "1/15"
  ParsedDate? _parseAbsoluteDate(String text) {
    // Split text into tokens to find date phrases within larger text
    final words = text.split(RegExp(r'\s+'));

    final formats = [
      DateFormat('yyyy-MM-dd'),     // 2025-01-15
      DateFormat('MM/dd/yyyy'),     // 01/15/2025
      DateFormat('M/d/yyyy'),       // 1/15/2025
      DateFormat('MM/dd'),          // 01/15 (needs year normalization)
      DateFormat('M/d'),            // 1/15 (needs year normalization)
      DateFormat('MMM d'),          // Jan 15 (needs year normalization)
      DateFormat('MMMM d'),         // January 15 (needs year normalization)
      DateFormat('MMM d, yyyy'),    // Jan 15, 2025
      DateFormat('MMMM d, yyyy'),   // January 15, 2025
    ];

    // Try 1-4 word windows to find date phrases
    for (int i = 0; i < words.length; i++) {
      for (int windowSize = 1; windowSize <= 4 && i + windowSize <= words.length; windowSize++) {
        final phrase = words.sublist(i, i + windowSize).join(' ');

        for (final format in formats) {
          try {
            final parsed = format.parseStrict(phrase);

            // Year normalization: if parsed year is before 2000, use current/next year
            DateTime normalized = parsed;
            if (parsed.year < 2000) {
              final now = getEffectiveToday();
              final currentYear = now.year;

              // Try current year first
              var candidate = DateTime(currentYear, parsed.month, parsed.day);

              // If date is in the past, use next year
              if (candidate.isBefore(now)) {
                candidate = DateTime(currentYear + 1, parsed.month, parsed.day);
              }

              normalized = candidate;
            }

            return ParsedDate(
              dateTime: normalized,
              isAllDay: true,
              matchedPhrase: phrase,
            );
          } catch (e) {
            // Try next format
          }
        }
      }
    }

    return null;
  }

  /// Parse relative dates with specific time: "tomorrow at 3pm"
  ParsedDate? _parseRelativeDateWithTime(String text) {
    // Pattern: (today|tomorrow) at HH:MM(am|pm)?
    final pattern = RegExp(
      r'(today|tomorrow)\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final dayKeyword = match.group(1)!.toLowerCase();
    final hour = int.parse(match.group(2)!);
    final minute = int.tryParse(match.group(3) ?? '0') ?? 0;
    final ampm = match.group(4)?.toLowerCase();

    // Calculate base date
    final effectiveToday = getEffectiveToday();
    final baseDate = dayKeyword == 'tomorrow'
        ? effectiveToday.add(const Duration(days: 1))
        : effectiveToday;

    // Convert 12-hour to 24-hour
    int hour24 = hour;
    if (ampm == 'pm' && hour != 12) {
      hour24 += 12;
    } else if (ampm == 'am' && hour == 12) {
      hour24 = 0;
    }

    final dateTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour24,
      minute,
    );

    return ParsedDate(
      dateTime: dateTime,
      isAllDay: false,
      matchedPhrase: match.group(0),
    );
  }

  /// Parse dates with time keywords: "tomorrow morning"
  ParsedDate? _parseDateWithTimeKeyword(String text) {
    // Pattern: (today|tomorrow) (morning|afternoon|tonight|evening)
    final relativeDay = RegExp(r'(today|tomorrow)').firstMatch(text);
    if (relativeDay == null) return null;

    final timeKeyword = _extractTimeKeyword(text);
    if (timeKeyword == null) return null;

    final effectiveToday = getEffectiveToday();
    final dayKeyword = relativeDay.group(1)!.toLowerCase();
    final baseDate = dayKeyword == 'tomorrow'
        ? effectiveToday.add(const Duration(days: 1))
        : effectiveToday;

    final dateTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      timeKeyword,
    );

    return ParsedDate(
      dateTime: dateTime,
      isAllDay: false,
      matchedPhrase: '$dayKeyword ${_getTimeKeywordName(timeKeyword)}',
    );
  }

  /// Parse weekdays: "Monday", "next Friday", "this Tuesday"
  ParsedDate? _parseWeekday(String text) {
    final weekdays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];

    String? targetDay;
    bool isNext = false;

    for (final day in weekdays) {
      if (text.contains(day)) {
        targetDay = day;
        isNext = text.contains('next');
        break;
      }
    }

    if (targetDay == null) return null;

    final effectiveToday = getEffectiveToday();
    final targetWeekday = weekdays.indexOf(targetDay) + 1; // 1 = Monday

    // Forward-looking logic: always find next occurrence
    int daysUntil = (targetWeekday - effectiveToday.weekday) % 7;
    if (daysUntil == 0) daysUntil = 7; // If today is Friday, "Friday" = next week

    if (isNext) daysUntil += 7; // "next Friday" = occurrence after "this Friday"

    final dateTime = effectiveToday.add(Duration(days: daysUntil));

    return ParsedDate(
      dateTime: DateTime(dateTime.year, dateTime.month, dateTime.day),
      isAllDay: true,
      matchedPhrase: isNext ? 'next $targetDay' : targetDay,
    );
  }

  /// Parse relative dates: "today", "tomorrow", "in 3 days"
  ParsedDate? _parseRelativeDate(String text) {
    final effectiveToday = getEffectiveToday();

    // "today"
    if (text == 'today') {
      return ParsedDate(
        dateTime: DateTime(effectiveToday.year, effectiveToday.month, effectiveToday.day),
        isAllDay: true,
        matchedPhrase: 'today',
      );
    }

    // "tomorrow"
    if (text == 'tomorrow') {
      final tomorrow = effectiveToday.add(const Duration(days: 1));
      return ParsedDate(
        dateTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        isAllDay: true,
        matchedPhrase: 'tomorrow',
      );
    }

    // "in X days/weeks"
    final inXPattern = RegExp(r'in\s+(\d+)\s+(day|days|week|weeks)');
    final match = inXPattern.firstMatch(text);
    if (match != null) {
      final count = int.parse(match.group(1)!);
      final unit = match.group(2)!;

      final daysToAdd = unit.startsWith('week') ? count * 7 : count;
      final targetDate = effectiveToday.add(Duration(days: daysToAdd));

      return ParsedDate(
        dateTime: DateTime(targetDate.year, targetDate.month, targetDate.day),
        isAllDay: true,
        matchedPhrase: match.group(0),
      );
    }

    return null;
  }

  /// Parse time keywords only: "tonight", "morning"
  ParsedDate? _parseTimeKeywordOnly(String text) {
    final hour = _extractTimeKeyword(text);
    if (hour == null) return null;

    final effectiveToday = getEffectiveToday();
    final dateTime = DateTime(
      effectiveToday.year,
      effectiveToday.month,
      effectiveToday.day,
      hour,
    );

    return ParsedDate(
      dateTime: dateTime,
      isAllDay: false,
      matchedPhrase: _getTimeKeywordName(hour),
    );
  }

  /// Parse multi-day tasks: "weekend"
  ParsedDate? _parseMultiDay(String text) {
    if (!text.contains('weekend')) return null;

    final effectiveToday = getEffectiveToday();

    // Find next Saturday
    int daysUntilSaturday = (DateTime.saturday - effectiveToday.weekday) % 7;
    if (daysUntilSaturday == 0 && effectiveToday.hour > userSettings.todayCutoffHour) {
      // It's Saturday after cutoff - user means THIS weekend (already started)
      daysUntilSaturday = 0;
    } else if (daysUntilSaturday == 0) {
      // It's Saturday before cutoff - next occurrence
      daysUntilSaturday = 7;
    }

    final saturday = effectiveToday.add(Duration(days: daysUntilSaturday));
    final monday = saturday.add(const Duration(days: 2)); // End of Sunday

    // Apply user's day boundary to both dates
    final startDate = DateTime(
      saturday.year,
      saturday.month,
      saturday.day,
      userSettings.todayCutoffHour,
      userSettings.todayCutoffMinute,
    );

    final dueDate = DateTime(
      monday.year,
      monday.month,
      monday.day,
      userSettings.todayCutoffHour,
      userSettings.todayCutoffMinute,
    );

    return ParsedDate(
      dateTime: dueDate,      // due_date = end of user's Sunday
      startDate: startDate,    // start_date = beginning of user's Saturday
      isAllDay: true,
      matchedPhrase: 'weekend',
    );
  }

  // ===========================================
  // HELPER METHODS
  // ===========================================

  /// Extract time keyword hour from text
  int? _extractTimeKeyword(String text) {
    if (text.contains('early morning') || text.contains('dawn')) {
      return userSettings.earlyMorningHour;
    }
    if (text.contains('morning')) {
      return userSettings.morningHour;
    }
    if (text.contains('noon') || text.contains('lunch') || text.contains('midday')) {
      return userSettings.noonHour;
    }
    if (text.contains('afternoon')) {
      return userSettings.afternoonHour;
    }
    if (text.contains('tonight') || text.contains('evening')) {
      return userSettings.tonightHour;
    }
    if (text.contains('late night')) {
      return userSettings.lateNightHour;
    }
    return null;
  }

  /// Get time keyword name from hour
  String? _getTimeKeywordName(int hour) {
    if (hour == userSettings.earlyMorningHour) return 'early morning';
    if (hour == userSettings.morningHour) return 'morning';
    if (hour == userSettings.noonHour) return 'noon';
    if (hour == userSettings.afternoonHour) return 'afternoon';
    if (hour == userSettings.tonightHour) return 'tonight';
    if (hour == userSettings.lateNightHour) return 'late night';
    return null;
  }
}
```

---

### Step 2: Create Test Fixture

**File:** `test/fixtures/date_parsing_test_cases.json` (NEW FILE)

```json
[
  {
    "input": "tomorrow",
    "expectedDate": "2025-11-01T00:00:00",
    "isAllDay": true,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Basic relative date"
  },
  {
    "input": "tomorrow at 3pm",
    "expectedDate": "2025-11-01T15:00:00",
    "isAllDay": false,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Relative date with specific time"
  },
  {
    "input": "tomorrow morning",
    "expectedDate": "2025-11-01T09:00:00",
    "isAllDay": false,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59,
      "morningHour": 9
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Time keyword with date"
  },
  {
    "input": "today",
    "expectedDate": "2025-10-30T00:00:00",
    "isAllDay": true,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-10-31T02:00:00",
    "edgeCase": "Night owl boundary - 2am is still yesterday"
  },
  {
    "input": "next Friday",
    "expectedDate": "2025-11-07T00:00:00",
    "isAllDay": true,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Weekday parsing - forward-looking"
  },
  {
    "input": "weekend",
    "expectedDate": "2025-11-03T04:59:00",
    "startDate": "2025-11-01T04:59:00",
    "isAllDay": true,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Multi-day task with user's day boundaries"
  },
  {
    "input": "weekend",
    "expectedDate": "2025-11-03T04:59:00",
    "startDate": "2025-11-01T04:59:00",
    "isAllDay": true,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-11-01T10:00:00",
    "edgeCase": "Weekend on Saturday after cutoff = THIS weekend"
  },
  {
    "input": "tonight",
    "expectedDate": "2025-10-31T19:00:00",
    "isAllDay": false,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59,
      "tonightHour": 19
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Time keyword only"
  },
  {
    "input": "in 3 days",
    "expectedDate": "2025-11-03T00:00:00",
    "isAllDay": true,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Relative offset"
  },
  {
    "input": "Jan 15",
    "expectedDate": "2026-01-15T00:00:00",
    "isAllDay": true,
    "userSettings": {
      "todayCutoffHour": 4,
      "todayCutoffMinute": 59
    },
    "currentTime": "2025-10-31T14:00:00",
    "edgeCase": "Absolute date (month name)"
  }
]
```

---

### Step 3: Write Tests for DateParserService

**File:** `test/services/date_parser_service_test.dart`

```dart
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/user_settings.dart';
import 'package:pin_and_paper/services/date_parser_service.dart';

void main() {
  group('DateParserService', () {
    late UserSettings defaultSettings;
    late DateParserService parser;

    setUp(() {
      defaultSettings = UserSettings.defaults();
      parser = DateParserService(defaultSettings);
    });

    test('parses "tomorrow"', () {
      final result = parser.parse('tomorrow');

      expect(result.dateTime, isNotNull);
      expect(result.isAllDay, true);
      expect(result.matchedPhrase, 'tomorrow');
    });

    test('parses "tomorrow at 3pm"', () {
      final result = parser.parse('tomorrow at 3pm');

      expect(result.dateTime, isNotNull);
      expect(result.isAllDay, false);
      expect(result.dateTime!.hour, 15); // 3pm = 15:00
    });

    test('parses "next Friday"', () {
      final result = parser.parse('next Friday');

      expect(result.dateTime, isNotNull);
      expect(result.isAllDay, true);
      expect(result.dateTime!.weekday, DateTime.friday);
    });

    test('respects user cutoff for "today" at 2am (before cutoff)', () {
      // Mock current time to 2025-10-31 02:00:00 (before 4:59am cutoff)
      withClock(Clock.fixed(DateTime(2025, 10, 31, 2, 0)), () {
        final settings = UserSettings.defaults();
        final parser = DateParserService(settings);

        final result = parser.parse('today');

        // At 2am with 4:59am cutoff, "today" = yesterday (Oct 30)
        expect(result.dateTime, isNotNull);
        expect(result.dateTime!.day, 30);
        expect(result.dateTime!.month, 10);
      });
    });

    test('respects user cutoff for "today" at 5am (after cutoff)', () {
      // Mock current time to 2025-10-31 05:00:00 (after 4:59am cutoff)
      withClock(Clock.fixed(DateTime(2025, 10, 31, 5, 0)), () {
        final settings = UserSettings.defaults();
        final parser = DateParserService(settings);

        final result = parser.parse('today');

        // At 5am after 4:59am cutoff, "today" = Oct 31
        expect(result.dateTime, isNotNull);
        expect(result.dateTime!.day, 31);
        expect(result.dateTime!.month, 10);
      });
    });

    test('parses "weekend" as multi-day task', () {
      final result = parser.parse('weekend');

      expect(result.dateTime, isNotNull); // due_date
      expect(result.startDate, isNotNull); // start_date
      expect(result.isAllDay, true);
      expect(result.startDate!.weekday, DateTime.saturday);
    });

    test('parses time keywords with user settings', () {
      final result = parser.parse('tomorrow morning');

      expect(result.dateTime, isNotNull);
      expect(result.isAllDay, false);
      expect(result.dateTime!.hour, defaultSettings.morningHour); // 9am
    });

    group('Test Fixture Regression Suite', () {
      late List<dynamic> testCases;

      setUpAll(() async {
        // Load test fixture
        final file = File('test/fixtures/date_parsing_test_cases.json');
        final contents = await file.readAsString();
        testCases = jsonDecode(contents) as List<dynamic>;
      });

      test('runs all test cases from fixture', () {
        int passed = 0;
        int failed = 0;

        for (final testCase in testCases) {
          final input = testCase['input'] as String;
          final expectedDateStr = testCase['expectedDate'] as String;
          final expectedDate = DateTime.parse(expectedDateStr);

          // Build user settings from test case
          final settingsMap = testCase['userSettings'] as Map<String, dynamic>;
          final settings = UserSettings.defaults().copyWith(
            todayCutoffHour: settingsMap['todayCutoffHour'] as int?,
            todayCutoffMinute: settingsMap['todayCutoffMinute'] as int?,
            morningHour: settingsMap['morningHour'] as int?,
            tonightHour: settingsMap['tonightHour'] as int?,
          );

          final parser = DateParserService(settings);

          // TODO: Mock current time from test case
          // For now, just test parsing logic

          final result = parser.parse(input);

          if (result.dateTime != null) {
            // Compare dates (ignoring time for all-day tasks)
            final matches = result.isAllDay
                ? result.dateTime!.year == expectedDate.year &&
                    result.dateTime!.month == expectedDate.month &&
                    result.dateTime!.day == expectedDate.day
                : result.dateTime == expectedDate;

            if (matches) {
              passed++;
            } else {
              failed++;
              print('FAILED: $input');
              print('  Expected: $expectedDate');
              print('  Got: ${result.dateTime}');
            }
          } else {
            failed++;
            print('FAILED: $input (no match)');
          }
        }

        final accuracy = (passed / testCases.length * 100).toStringAsFixed(1);
        print('Date parsing accuracy: $accuracy% ($passed/$testCases.length passed)');

        // Expect >80% accuracy
        expect(passed / testCases.length, greaterThan(0.8));
      });
    });
  });
}
```

---

### Phase 3.3 Completion Criteria

- [ ] DateParserService created with all parser methods
- [ ] UserSettings integration complete
- [ ] getEffectiveToday respects user's day boundary
- [ ] Test fixture created with 20-30 phrases
- [ ] Regression test suite passes (>80% accuracy)
- [ ] Unit tests for all parser methods
- [ ] Weekend edge case handled (Saturday after cutoff = this weekend)
- [ ] Forward-looking weekday logic implemented
- [ ] Time keywords use user preferences
- [ ] Multi-day tasks create both start_date and due_date

**Deferred to Phase 3.4:**
- Live parsing UI (Todoist-style highlights)
- Brain Dump integration (send user_settings to Claude)

**Estimated Time:** 2-3 days

---

## Cross-Phase Integration

### Integration Point 1: Task Creation with Dates

**Scenario:** User creates task "call dentist tomorrow morning"

**Flow:**
1. Parse input with DateParserService
2. Extract due_date from parsed result
3. Create Task with populated due_date field
4. Save to database (uses new schema from Phase 3.1)
5. Display in HomeScreen (uses hierarchy from Phase 3.2)

**Code Example (TaskService):**

```dart
Future<Task> createTaskWithParsedDate(String title) async {
  // Get user settings for parsing
  final userSettings = await UserSettingsService().getUserSettings();

  // Parse date from title
  final parser = DateParserService(userSettings);
  final parsedDate = parser.parse(title);

  // Create task with date
  final task = Task(
    id: const Uuid().v4(),
    title: title,
    completed: false,
    createdAt: DateTime.now(),
    dueDate: parsedDate.dateTime,
    isAllDay: parsedDate.isAllDay,
    startDate: parsedDate.startDate,
  );

  final db = await _databaseService.database;
  await db.insert(AppConstants.tasksTable, task.toMap());

  return task;
}
```

**Performance Optimization Note:** The above example creates a new `DateParserService` for every call, which is inefficient. In production, use service-level caching:

```dart
class TaskService {
  DateParserService? _cachedParser;
  UserSettings? _cachedSettings;

  Future<Task> createTaskWithParsedDate(String title) async {
    final userSettings = await UserSettingsService().getUserSettings();

    // Reuse parser if settings haven't changed
    if (_cachedParser == null || _cachedSettings != userSettings) {
      _cachedParser = DateParserService(userSettings);
      _cachedSettings = userSettings;
    }

    final parsedDate = _cachedParser!.parse(title);
    // ... rest of implementation
  }
}
```

This avoids repeated object creation while still respecting user settings changes.

### Integration Point 2: Hierarchical Tasks with Dates

**Scenario:** User creates subtask "buy ingredients tomorrow" under parent "make dinner"

**Flow:**
1. Parse date from title
2. Create Task with parent_id, position, and due_date
3. Display indented with date badge in UI

### Integration Point 3: Testing Full Stack

**File:** `test/integration/group1_integration_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group 1 Integration Tests', () {
    test('Create nested task with parsed date', () async {
      // 1. Migrate database to v4
      // 2. Create parent task
      // 3. Parse date from child task title
      // 4. Create child task with parent_id and due_date
      // 5. Verify hierarchy and date stored correctly
      // 6. Verify task displays with indentation and date badge
    });

    test('Reorder tasks preserves dates', () async {
      // 1. Create tasks with dates
      // 2. Reorder via drag-and-drop
      // 3. Verify positions updated
      // 4. Verify dates unchanged
    });

    test('Weekend parsing creates multi-day task', () async {
      // 1. Parse "weekend"
      // 2. Create task
      // 3. Verify start_date = Saturday, due_date = Monday
      // 4. Verify task shows in "For Today" view on both days
    });
  });
}
```

---

## Testing Strategy

### Unit Tests

**Per Subphase:**
- Phase 3.1: Task/UserSettings models, migration SQL
- Phase 3.2: TaskService hierarchy methods, TaskProvider state
- Phase 3.3: DateParserService all parsers

### Integration Tests

**Cross-subphase:**
- Task creation with parsed dates
- Hierarchical display with date badges
- Reordering preserves dates and hierarchy
- CASCADE delete with date filters

### Manual Testing Protocol

**Phase 3.1:**
1. Backup Phase 2 database
2. Run app with Phase 3 code
3. Verify migration completes without error
4. Check PRAGMA foreign_key_list for CASCADE
5. Verify user_settings row exists
6. Create new task, verify position assigned

**Phase 3.2:**
1. Create parent task
2. Create child task
3. Drag child to nest under parent
4. Verify indentation updates
5. Collapse parent, verify children hide
6. Delete parent, confirm CASCADE warning
7. Verify child deleted after confirmation

**Phase 3.3:**
1. Create task "tomorrow morning"
2. Verify due_date = tomorrow at 9am
3. Create task "weekend"
4. Verify start_date = Saturday, due_date = Monday
5. Test at 2am (before cutoff) - "today" = yesterday
6. Test all time keywords
7. Run fixture regression suite, verify >80% accuracy

---

## Risk Mitigation

### Risk 1: Migration Data Loss

**Mitigation:**
- Comprehensive backup procedure (db-migration-checklist.md)
- Test rollback procedure BEFORE production
- Dry run on Phase 2 snapshot
- Transaction wrapping (automatic rollback on error)

### Risk 2: CASCADE Deletes Accidental Data Loss

**Mitigation:**
- Confirmation dialog shows child count
- Secondary confirmation for parents with >5 children
- Undo snackbar for single deletions (non-CASCADE)
- Test CASCADE behavior in unit tests

### Risk 3: Date Parsing Ambiguity

**Mitigation:**
- Test fixture with 20-30 edge cases
- >80% accuracy target
- Ambiguous flag in ParsedDate for UI hints
- Calendar picker always available as fallback

### Risk 4: Performance with Deep Hierarchies

**Mitigation:**
- Max 4-level depth enforced in code
- Recursive CTE optimized with depth limit
- Indexes on parent_id and position
- Load testing with 100+ tasks, 3-level nesting

---

## Group 1 Completion Criteria

### Phase 3.1 Complete
- [ ] Database version = 4
- [ ] All models updated
- [ ] Migration tested on Phase 2 data
- [ ] Foreign keys verified
- [ ] User settings accessible

### Phase 3.2 Complete
- [ ] Hierarchical display works
- [ ] Collapse/expand functional
- [ ] Reorder mode implemented
- [ ] Context menu functional
- [ ] CASCADE protection works

### Phase 3.3 Complete
- [ ] DateParserService functional
- [ ] Test fixture >80% accuracy
- [ ] User settings integration complete
- [ ] Weekend edge case handled

### Integration Complete
- [ ] Tasks with dates display correctly
- [ ] Nested tasks with dates work
- [ ] Full stack tested end-to-end
- [ ] No Phase 1/2 regressions

---

## Next Steps After Group 1

**Group 2 Planning (Phase 3.4-3.5):**
- Voice Input (uses date parser via Brain Dump)
- Notifications (uses user_settings from 3.1)

**User Feedback:**
- Test with BlueKitty on Galaxy S21 Ultra
- Iterate on UX (indentation depth, drag feedback)
- Tune date parsing accuracy

**Documentation:**
- Update PROJECT_SPEC.md with Group 1 changes
- Document API changes for agents
- Update README with new features

---

**End of Group 1 Detailed Implementation Plan**
