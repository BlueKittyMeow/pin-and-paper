import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

/// Phase 3.6A: Setup test data for manual testing
///
/// Creates:
/// - 5 tags with different colors
/// - 10 tasks (mix of tagged/untagged)
/// - Some tasks with multiple tags
/// - Some tasks with no tags

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final uuid = const Uuid();

  // Find database path (path_provider uses ~/Documents on Linux)
  final home = Platform.environment['HOME']!;
  final dbPath = '$home/Documents/pin_and_paper.db';
  print('Opening database: $dbPath');

  final db = await openDatabase(
    dbPath,
    version: 6,
    onCreate: (db, version) async {
      print('Database does not exist, creating schema...');
      await _createSchema(db);
    },
    onOpen: (db) async {
      // Check if tables exist
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tags'"
      );

      if (result.isEmpty) {
        print('Tables do not exist, creating schema...');
        await _createSchema(db);
      }
    },
  );

  // Get current timestamp for created_at fields
  final now = DateTime.now().millisecondsSinceEpoch;

  // Create 5 tags with different colors
  final tags = [
    {'id': uuid.v4(), 'name': 'Urgent', 'color': '#FF5722'},      // Red-Orange
    {'id': uuid.v4(), 'name': 'Work', 'color': '#2196F3'},        // Blue
    {'id': uuid.v4(), 'name': 'Personal', 'color': '#4CAF50'},    // Green
    {'id': uuid.v4(), 'name': 'Shopping', 'color': '#FF9800'},    // Orange
    {'id': uuid.v4(), 'name': 'Ideas', 'color': '#9C27B0'},       // Purple
  ];

  print('\nCreating ${tags.length} tags...');
  for (final tag in tags) {
    await db.insert('tags', {
      'id': tag['id'],
      'name': tag['name'],
      'color': tag['color'],
      'created_at': now,
      'deleted_at': null,
    });
    print('  ✓ ${tag['name']} (${tag['color']})');
  }

  // Create 10 tasks with varying tag assignments
  final tasks = [
    // Multiple tags (Urgent + Work)
    {'title': 'Fix critical bug in production', 'tags': [tags[0]['id'], tags[1]['id']]},

    // Multiple tags (Work + Ideas)
    {'title': 'Brainstorm new features for Q2', 'tags': [tags[1]['id'], tags[4]['id']]},

    // Single tag (Urgent)
    {'title': 'Call dentist about appointment', 'tags': [tags[0]['id']]},

    // Single tag (Personal)
    {'title': 'Plan weekend camping trip', 'tags': [tags[2]['id']]},

    // Multiple tags (Shopping + Personal)
    {'title': 'Buy groceries for dinner party', 'tags': [tags[3]['id'], tags[2]['id']]},

    // Single tag (Work)
    {'title': 'Review code for PR #247', 'tags': [tags[1]['id']]},

    // No tags
    {'title': 'Clean garage', 'tags': []},

    // Single tag (Ideas)
    {'title': 'Research new productivity methods', 'tags': [tags[4]['id']]},

    // No tags
    {'title': 'Water the plants', 'tags': []},

    // Multiple tags (Urgent + Personal)
    {'title': 'Renew passport before expiry', 'tags': [tags[0]['id'], tags[2]['id']]},
  ];

  print('\nCreating ${tasks.length} tasks...');
  int position = tasks.length;
  for (final task in tasks) {
    final taskId = uuid.v4();

    await db.insert('tasks', {
      'id': taskId,
      'title': task['title'],
      'completed': 0,
      'position': position--,
      'created_at': now,
      'completed_at': null,
      'due_date': null,
      'is_all_day': 1,
      'start_date': null,
      'parent_id': null,
      'is_template': 0,
      'notification_type': 'use_global',
      'notification_time': null,
      'deleted_at': null,
    });

    final taskTags = task['tags'] as List;
    if (taskTags.isNotEmpty) {
      for (final tagId in taskTags) {
        await db.insert('task_tags', {
          'task_id': taskId,
          'tag_id': tagId,
          'created_at': now,
        });
      }
      print('  ✓ ${task['title']} (${taskTags.length} tags)');
    } else {
      print('  ✓ ${task['title']} (no tags)');
    }
  }

  await db.close();

  print('\n✅ Test data created successfully!');
  print('\nSummary:');
  print('  - ${tags.length} tags created');
  print('  - ${tasks.length} tasks created');
  print('  - Mix of tasks with 0, 1, and 2+ tags');
}

/// Create minimal schema (just the tables we need for test data)
Future<void> _createSchema(Database db) async {
  // Tasks table (minimal columns)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS tasks (
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
      FOREIGN KEY (parent_id) REFERENCES tasks(id) ON DELETE CASCADE
    )
  ''');

  // Tags table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS tags (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      color TEXT,
      created_at INTEGER NOT NULL,
      deleted_at INTEGER DEFAULT NULL
    )
  ''');

  // Junction table: tasks ↔ tags
  await db.execute('''
    CREATE TABLE IF NOT EXISTS task_tags (
      task_id TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (task_id, tag_id),
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
    )
  ''');

  print('Schema created successfully');
}
