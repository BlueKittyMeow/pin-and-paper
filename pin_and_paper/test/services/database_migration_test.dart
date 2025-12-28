import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/utils/constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
