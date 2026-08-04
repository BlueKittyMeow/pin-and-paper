import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/utils/constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../helpers/test_database_helper.dart';

/// Tests for database migrations
///
/// CRITICAL: These tests verify that migration logic handles edge cases
/// and preserves user data correctly during schema changes.
void main() {
  group('Database Migration v5 → v6', () {
    late Database db;

    setUpAll(() {
      // Initialize sqflite_ffi for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    /// Helper: Create a v5 database with the OLD schema (case-sensitive tags)
    Future<Database> createV5Database() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            // Create tasks table (minimal for testing)
            await db.execute('''
              CREATE TABLE ${AppConstants.tasksTable} (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                parent_id TEXT,
                position INTEGER NOT NULL DEFAULT 0,
                depth INTEGER NOT NULL DEFAULT 0,
                is_template INTEGER NOT NULL DEFAULT 0,
                due_date INTEGER,
                is_all_day INTEGER NOT NULL DEFAULT 0,
                start_date INTEGER,
                notification_type TEXT NOT NULL DEFAULT 'use_global',
                notification_time INTEGER,
                deleted_at INTEGER,
                completed_at INTEGER
              )
            ''');

            // Create v5 tags table (OLD schema - case-sensitive, no deleted_at)
            await db.execute('''
              CREATE TABLE ${AppConstants.tagsTable} (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                color TEXT,
                created_at INTEGER NOT NULL
              )
            ''');

            // Create task_tags junction table
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
          },
        ),
      );

      return db;
    }

    test('migrates from v5 to v6 successfully with no duplicate tags', () async {
      // 1. Create v5 database
      db = await createV5Database();

      // 2. Add sample data
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(AppConstants.tasksTable, {
        'id': 'task-1',
        'title': 'Test Task',
        'completed': 0,
        'created_at': now,
        'position': 0,
        'depth': 0,
        'is_template': 0,
        'is_all_day': 0,
        'notification_type': 'use_global',
      });

      await db.insert(AppConstants.tagsTable, {
        'id': 'tag-1',
        'name': 'Work',
        'color': '#FF5722',
        'created_at': now,
      });

      await db.insert(AppConstants.taskTagsTable, {
        'task_id': 'task-1',
        'tag_id': 'tag-1',
        'created_at': now,
      });

      // 3. Run migration directly on the same database
      await _migrateV5ToV6(db);

      // 4. Verify schema changes
      final tagColumns = await db.rawQuery('PRAGMA table_info(${AppConstants.tagsTable})');
      final columnNames = tagColumns.map((col) => col['name'] as String).toList();

      expect(columnNames, contains('deleted_at')); // New column added

      // 5. Verify data preserved
      final tags = await db.query(AppConstants.tagsTable);
      expect(tags.length, equals(1));
      expect(tags.first['name'], equals('Work'));
      expect(tags.first['color'], equals('#FF5722'));
      expect(tags.first['deleted_at'], isNull);

      final taskTags = await db.query(AppConstants.taskTagsTable);
      expect(taskTags.length, equals(1));
    });

    test('deduplicates tags with different cases (CRITICAL)', () async {
      // 1. Create v5 database
      db = await createV5Database();

      // 2. Add duplicate-cased tags (this was possible in v5!)
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create 3 tasks
      for (int i = 1; i <= 3; i++) {
        await db.insert(AppConstants.tasksTable, {
          'id': 'task-$i',
          'title': 'Task $i',
          'completed': 0,
          'created_at': now,
          'position': i,
          'depth': 0,
          'is_template': 0,
          'is_all_day': 0,
          'notification_type': 'use_global',
        });
      }

      // Create 3 tags with different cases (v5 allowed this!)
      await db.insert(AppConstants.tagsTable, {
        'id': 'tag-work-1',
        'name': 'Work',
        'color': '#FF5722',
        'created_at': now,
      });

      await db.insert(AppConstants.tagsTable, {
        'id': 'tag-work-2',
        'name': 'work',
        'color': '#2196F3',
        'created_at': now + 1000,
      });

      await db.insert(AppConstants.tagsTable, {
        'id': 'tag-work-3',
        'name': 'WORK',
        'color': '#4CAF50',
        'created_at': now + 2000,
      });

      // Each task uses a different tag
      await db.insert(AppConstants.taskTagsTable, {
        'task_id': 'task-1',
        'tag_id': 'tag-work-1',
        'created_at': now,
      });

      await db.insert(AppConstants.taskTagsTable, {
        'task_id': 'task-2',
        'tag_id': 'tag-work-2',
        'created_at': now,
      });

      await db.insert(AppConstants.taskTagsTable, {
        'task_id': 'task-3',
        'tag_id': 'tag-work-3',
        'created_at': now,
      });

      // Verify v5 state
      final v5Tags = await db.query(AppConstants.tagsTable);
      expect(v5Tags.length, equals(3)); // 3 duplicate tags in v5

      // 3. Run migration directly on the same database
      await _migrateV5ToV6(db);

      // 4. Verify deduplication happened
      final v6Tags = await db.query(AppConstants.tagsTable);
      expect(v6Tags.length, equals(1), reason: 'Should have merged 3 tags into 1');

      final keptTag = v6Tags.first;
      expect(keptTag['name'], equals('Work'), reason: 'Should keep first tag casing');
      expect(keptTag['color'], equals('#FF5722'), reason: 'Should keep first tag color');
      expect(keptTag['deleted_at'], isNull);

      // 5. Verify ALL task associations are preserved
      final v6TaskTags = await db.query(AppConstants.taskTagsTable);
      expect(v6TaskTags.length, equals(3), reason: 'All 3 task associations should be preserved');

      // All associations should point to the kept tag
      final keptTagId = keptTag['id'] as String;
      for (var association in v6TaskTags) {
        expect(association['tag_id'], equals(keptTagId),
            reason: 'All associations should point to merged tag');
      }

      // 6. Verify case-insensitive UNIQUE constraint is working
      try {
        await db.insert(AppConstants.tagsTable, {
          'id': 'new-tag',
          'name': 'WORK', // Different case
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        fail('Should have thrown UNIQUE constraint error');
      } catch (e) {
        expect(e.toString(), contains('UNIQUE'));
      }
    });

    test('preserves non-duplicate tags during migration', () async {
      // 1. Create v5 database
      db = await createV5Database();

      // 2. Add multiple distinct tags
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(AppConstants.tasksTable, {
        'id': 'task-1',
        'title': 'Task 1',
        'completed': 0,
        'created_at': now,
        'position': 0,
        'depth': 0,
        'is_template': 0,
        'is_all_day': 0,
        'notification_type': 'use_global',
      });

      final tags = [
        {'id': 'tag-1', 'name': 'Work', 'color': '#FF5722'},
        {'id': 'tag-2', 'name': 'Personal', 'color': '#2196F3'},
        {'id': 'tag-3', 'name': 'Urgent', 'color': '#4CAF50'},
      ];

      for (var tag in tags) {
        await db.insert(AppConstants.tagsTable, {
          ...tag,
          'created_at': now,
        });
      }

      // 3. Run migration directly on the same database
      await _migrateV5ToV6(db);

      // 4. Verify all tags preserved
      final v6Tags = await db.query(AppConstants.tagsTable, orderBy: 'name ASC');
      expect(v6Tags.length, equals(3));

      expect(v6Tags[0]['name'], equals('Personal'));
      expect(v6Tags[1]['name'], equals('Urgent'));
      expect(v6Tags[2]['name'], equals('Work'));
    });
  });

  group('Database Migration v12 → v13', () {
    late Database db;

    setUpAll(() {
      // Initialize sqflite_ffi for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    /// Helper: Create a v12 database with the schema as it existed just
    /// before the v13 spatial-canvas migration (no canvas_x/canvas_y).
    Future<Database> createV12Database() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${AppConstants.tasksTable} (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                completed_at INTEGER,
                due_date INTEGER,
                is_all_day INTEGER DEFAULT 1,
                start_date INTEGER,
                parent_id TEXT,
                position INTEGER NOT NULL DEFAULT 0,
                is_template INTEGER DEFAULT 0,
                notification_type TEXT DEFAULT 'use_global',
                notification_time INTEGER,
                deleted_at INTEGER DEFAULT NULL,
                notes TEXT DEFAULT NULL,
                position_before_completion INTEGER DEFAULT NULL,
                updated_at INTEGER,
                FOREIGN KEY (parent_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              CREATE TABLE sync_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                table_name TEXT NOT NULL,
                record_id TEXT NOT NULL,
                operation TEXT NOT NULL,
                payload TEXT,
                created_at INTEGER NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');

            await db.execute('''
              CREATE TABLE sync_meta (
                id INTEGER PRIMARY KEY DEFAULT 1,
                user_id TEXT,
                last_push_at INTEGER,
                last_pull_at INTEGER,
                sync_enabled INTEGER DEFAULT 0,
                CHECK (id = 1)
              )
            ''');
            await db.insert('sync_meta', {'id': 1});
          },
        ),
      );

      return db;
    }

    test('migrates from v12 to v13: adds canvas_x/canvas_y and data survives', () async {
      // 1. Create v12 database
      db = await createV12Database();

      // 2. Add sample data
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(AppConstants.tasksTable, {
        'id': 'task-1',
        'title': 'Pre-migration task',
        'completed': 0,
        'created_at': now,
        'position': 0,
        'is_template': 0,
        'is_all_day': 1,
        'notification_type': 'use_global',
        'updated_at': now,
      });

      // 3. Run migration directly on the same database
      await _migrateV12ToV13(db);

      // 4. Verify schema changes
      final taskColumns = await db.rawQuery('PRAGMA table_info(${AppConstants.tasksTable})');
      final columnNames = taskColumns.map((col) => col['name'] as String).toList();

      expect(columnNames, contains('canvas_x'));
      expect(columnNames, contains('canvas_y'));

      // 5. Verify existing data preserved, new columns default to NULL
      final tasks = await db.query(AppConstants.tasksTable);
      expect(tasks.length, equals(1));
      expect(tasks.first['id'], equals('task-1'));
      expect(tasks.first['title'], equals('Pre-migration task'));
      expect(tasks.first['canvas_x'], isNull);
      expect(tasks.first['canvas_y'], isNull);
    });

    test('canvas_x/canvas_y accept and round-trip real values after migration', () async {
      db = await createV12Database();

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(AppConstants.tasksTable, {
        'id': 'task-2',
        'title': 'Task to place on canvas',
        'completed': 0,
        'created_at': now,
        'position': 0,
        'is_template': 0,
        'is_all_day': 1,
        'notification_type': 'use_global',
        'updated_at': now,
      });

      await _migrateV12ToV13(db);

      await db.update(
        AppConstants.tasksTable,
        {'canvas_x': 123.5, 'canvas_y': -45.25},
        where: 'id = ?',
        whereArgs: ['task-2'],
      );

      final rows = await db.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: ['task-2']);
      expect(rows.first['canvas_x'], equals(123.5));
      expect(rows.first['canvas_y'], equals(-45.25));
    });

    test('fresh v13 install schema matches the migrated schema', () async {
      // The fresh-install schema (test harness equivalent of DatabaseService._createDB)
      // must have the same canvas_x/canvas_y columns as a migrated v12 database.
      final freshDb = await TestDatabaseHelper.createTestDatabase();

      final freshColumns = await freshDb.rawQuery('PRAGMA table_info(${AppConstants.tasksTable})');
      final freshColumnNames = freshColumns.map((col) => col['name'] as String).toSet();

      expect(freshColumnNames, contains('canvas_x'));
      expect(freshColumnNames, contains('canvas_y'));

      // Fresh-installed tasks have NULL canvas position until placed
      await freshDb.insert(AppConstants.tasksTable, {
        'id': 'fresh-task-1',
        'title': 'Fresh task',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      final rows = await freshDb.query(AppConstants.tasksTable, where: 'id = ?', whereArgs: ['fresh-task-1']);
      expect(rows.first['canvas_x'], isNull);
      expect(rows.first['canvas_y'], isNull);

      await freshDb.close();
    });
  });

  group('Database Migration v13 → v14', () {
    late Database db;

    setUpAll(() {
      // Initialize sqflite_ffi for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    /// Helper: Create a v13 database with the schema as it existed just
    /// before the v14 card-drawings migration (no task_drawings table).
    Future<Database> createV13Database() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 13,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${AppConstants.tasksTable} (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                completed_at INTEGER,
                due_date INTEGER,
                is_all_day INTEGER DEFAULT 1,
                start_date INTEGER,
                parent_id TEXT,
                position INTEGER NOT NULL DEFAULT 0,
                is_template INTEGER DEFAULT 0,
                notification_type TEXT DEFAULT 'use_global',
                notification_time INTEGER,
                deleted_at INTEGER DEFAULT NULL,
                notes TEXT DEFAULT NULL,
                position_before_completion INTEGER DEFAULT NULL,
                updated_at INTEGER,
                canvas_x REAL,
                canvas_y REAL,
                FOREIGN KEY (parent_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              CREATE TABLE sync_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                table_name TEXT NOT NULL,
                record_id TEXT NOT NULL,
                operation TEXT NOT NULL,
                payload TEXT,
                created_at INTEGER NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');

            await db.execute('''
              CREATE TABLE sync_meta (
                id INTEGER PRIMARY KEY DEFAULT 1,
                user_id TEXT,
                last_push_at INTEGER,
                last_pull_at INTEGER,
                sync_enabled INTEGER DEFAULT 0,
                CHECK (id = 1)
              )
            ''');
            await db.insert('sync_meta', {'id': 1});
          },
        ),
      );

      return db;
    }

    test('migrates from v13 to v14: adds task_drawings and task data survives', () async {
      // 1. Create v13 database
      db = await createV13Database();

      // 2. Add sample data (including canvas positions — must survive)
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(AppConstants.tasksTable, {
        'id': 'task-1',
        'title': 'Pre-migration task',
        'completed': 0,
        'created_at': now,
        'position': 0,
        'is_template': 0,
        'is_all_day': 1,
        'notification_type': 'use_global',
        'updated_at': now,
        'canvas_x': 123.5,
        'canvas_y': -45.25,
      });

      // 3. Run migration directly on the same database
      await _migrateV13ToV14(db);

      // 4. Verify the table + index exist with the expected columns
      final drawingColumns = await db.rawQuery(
          'PRAGMA table_info(${AppConstants.taskDrawingsTable})');
      final columnNames =
          drawingColumns.map((col) => col['name'] as String).toSet();

      expect(
        columnNames,
        equals({
          'id',
          'task_id',
          'face',
          'drawing_json',
          'visible',
          'position_x',
          'position_y',
          'created_at',
          'updated_at',
        }),
      );

      final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?",
          [AppConstants.taskDrawingsTable]);
      expect(
        indexes.map((row) => row['name'] as String),
        contains('idx_task_drawings_task'),
      );

      // 5. Verify existing task data preserved
      final tasks = await db.query(AppConstants.tasksTable);
      expect(tasks.length, equals(1));
      expect(tasks.first['id'], equals('task-1'));
      expect(tasks.first['title'], equals('Pre-migration task'));
      expect(tasks.first['canvas_x'], equals(123.5));
      expect(tasks.first['canvas_y'], equals(-45.25));

      // 6. New table starts empty
      final drawings = await db.query(AppConstants.taskDrawingsTable);
      expect(drawings, isEmpty);
    });

    test('task_drawings defaults apply after migration (face/visible/position)', () async {
      db = await createV13Database();

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(AppConstants.tasksTable, {
        'id': 'task-2',
        'title': 'Task with a doodle',
        'completed': 0,
        'created_at': now,
        'position': 0,
        'updated_at': now,
      });

      await _migrateV13ToV14(db);

      // Insert relying on column defaults
      await db.insert(AppConstants.taskDrawingsTable, {
        'id': 'drawing-1',
        'task_id': 'task-2',
        'drawing_json': '{"v":1}',
        'created_at': now,
      });

      final rows = await db.query(AppConstants.taskDrawingsTable);
      expect(rows.length, equals(1));
      expect(rows.first['face'], equals('front'));
      expect(rows.first['visible'], equals(1));
      expect(rows.first['position_x'], equals(0));
      expect(rows.first['position_y'], equals(0));
      expect(rows.first['updated_at'], isNull);
    });

    test('fresh v14 install schema matches the migrated schema (parity)', () async {
      // The fresh-install schema (test harness equivalent of
      // DatabaseService._createDB) must produce the exact same task_drawings
      // table definition as a migrated v13 database — compare full
      // PRAGMA table_info rows (name, type, notnull, default, pk).
      db = await createV13Database();
      await _migrateV13ToV14(db);

      final freshDb = await TestDatabaseHelper.createTestDatabase();

      List<Map<String, Object?>> normalize(List<Map<String, Object?>> info) =>
          info
              .map((col) => {
                    'name': col['name'],
                    'type': col['type'],
                    'notnull': col['notnull'],
                    'dflt_value': col['dflt_value'],
                    'pk': col['pk'],
                  })
              .toList();

      final migratedInfo = normalize(await db
          .rawQuery('PRAGMA table_info(${AppConstants.taskDrawingsTable})'));
      final freshInfo = normalize(await freshDb
          .rawQuery('PRAGMA table_info(${AppConstants.taskDrawingsTable})'));

      expect(freshInfo, equals(migratedInfo));

      // Index parity too
      final freshIndexes = await freshDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?",
          [AppConstants.taskDrawingsTable]);
      expect(
        freshIndexes.map((row) => row['name'] as String),
        contains('idx_task_drawings_task'),
      );

      await freshDb.close();
    });

    test('deleting a task cascades to its task_drawings rows', () async {
      db = await createV13Database();
      await _migrateV13ToV14(db);

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(AppConstants.tasksTable, {
        'id': 'task-3',
        'title': 'Doomed task',
        'completed': 0,
        'created_at': now,
        'position': 0,
        'updated_at': now,
      });
      await db.insert(AppConstants.taskDrawingsTable, {
        'id': 'drawing-2',
        'task_id': 'task-3',
        'drawing_json': '{"v":1}',
        'created_at': now,
      });

      await db.delete(AppConstants.tasksTable,
          where: 'id = ?', whereArgs: ['task-3']);

      final drawings = await db.query(AppConstants.taskDrawingsTable);
      expect(drawings, isEmpty);
    });
  });
}

/// Manual implementation of v12→v13 migration for testing
///
/// This replicates the logic from DatabaseService._migrateToV13
/// so we can test it without making the method public.
Future<void> _migrateV12ToV13(Database db) async {
  await db.transaction((txn) async {
    await txn.execute(
        'ALTER TABLE ${AppConstants.tasksTable} ADD COLUMN canvas_x REAL');
    await txn.execute(
        'ALTER TABLE ${AppConstants.tasksTable} ADD COLUMN canvas_y REAL');
  });
}

/// Manual implementation of v13→v14 migration for testing
///
/// This replicates the logic from DatabaseService._migrateToV14
/// so we can test it without making the method public.
Future<void> _migrateV13ToV14(Database db) async {
  await db.transaction((txn) async {
    await txn.execute('''
      CREATE TABLE ${AppConstants.taskDrawingsTable} (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        face TEXT NOT NULL DEFAULT 'front',
        drawing_json TEXT NOT NULL,
        visible INTEGER NOT NULL DEFAULT 1,
        position_x REAL NOT NULL DEFAULT 0,
        position_y REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
      )
    ''');

    await txn.execute(
        'CREATE INDEX idx_task_drawings_task ON ${AppConstants.taskDrawingsTable}(task_id)');
  });
}

/// Manual implementation of v5→v6 migration for testing
///
/// This replicates the logic from DatabaseService._migrateToV6
/// so we can test it without making the method public.
Future<void> _migrateV5ToV6(Database db) async {
  await db.transaction((txn) async {
    // 1. Save existing data
    final tagsData = await txn.query(AppConstants.tagsTable);
    final taskTagsData = await txn.query(AppConstants.taskTagsTable);

    // 2. Drop tables
    await txn.execute('DROP TABLE ${AppConstants.taskTagsTable}');
    await txn.execute('DROP TABLE ${AppConstants.tagsTable}');

    // 3. Recreate tags table with COLLATE NOCASE
    await txn.execute('''
      CREATE TABLE ${AppConstants.tagsTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        color TEXT,
        created_at INTEGER NOT NULL,
        deleted_at INTEGER DEFAULT NULL
      )
    ''');

    // 4. Deduplicate and restore tags
    final tagsByLowerName = <String, List<Map<String, dynamic>>>{};
    for (var row in tagsData) {
      final lowerName = (row['name'] as String).toLowerCase();
      tagsByLowerName.putIfAbsent(lowerName, () => []).add(row);
    }

    final idMapping = <String, String>{};
    for (var entry in tagsByLowerName.entries) {
      final duplicates = entry.value;
      final kept = duplicates.first;

      await txn.insert(AppConstants.tagsTable, {
        'id': kept['id'],
        'name': kept['name'],
        'color': kept['color'],
        'created_at': kept['created_at'],
        'deleted_at': null,
      });

      for (var dup in duplicates) {
        idMapping[dup['id'] as String] = kept['id'] as String;
      }
    }

    // 5. Recreate task_tags table
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

    // 6. Restore task_tags with remapping
    for (var row in taskTagsData) {
      final oldTagId = row['tag_id'] as String;
      final keptTagId = idMapping[oldTagId] ?? oldTagId;

      await txn.insert(
        AppConstants.taskTagsTable,
        {
          'task_id': row['task_id'],
          'tag_id': keptTagId,
          'created_at': row['created_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // 7. Recreate indexes
    await txn.execute('CREATE INDEX idx_tags_name ON ${AppConstants.tagsTable}(name)');
    await txn.execute('CREATE INDEX idx_tags_deleted_at ON ${AppConstants.tagsTable}(deleted_at)');
    await txn.execute('CREATE INDEX idx_task_tags_tag ON ${AppConstants.taskTagsTable}(tag_id)');
    await txn.execute('CREATE INDEX idx_task_tags_task ON ${AppConstants.taskTagsTable}(task_id)');
  });
}
