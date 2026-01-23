#!/usr/bin/env dart
// Phase 3.6A: Database Schema Verification Script
//
// Run with: dart run scripts/verify_schema.dart
//
// Verifies that the database schema from Phase 3.5 is correct
// and has all required indexes for Phase 3.6A filtering.
//
// This is a read-only script - it makes no changes to the database.

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

void main() async {
  print('🔍 Phase 3.6A: Database Schema Verification');
  print('=' * 60);
  print('This script will verify:');
  print('  ✓ Required tables exist (tasks, tags, task_tags)');
  print('  ✓ Required indexes exist for optimal query performance');
  print('  ✓ Schema structure is correct');
  print('');
  print('This is READ-ONLY - no changes will be made to your database.');
  print('=' * 60);
  print('');

  // Initialize sqflite_ffi for Linux/Desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Find the database file
  final dbPath = await _findDatabasePath();
  if (dbPath == null) {
    print('❌ Could not find database file');
    print('   Expected location: ~/.local/share/pin_and_paper/pin_and_paper.db');
    print('   Please run the app at least once to create the database.');
    exit(1);
  }

  print('📂 Found database at: $dbPath');
  print('');

  // Open database (read-only mode would be ideal but sqflite doesn't support it easily)
  Database? db;
  try {
    db = await openDatabase(dbPath);
    print('✅ Database opened successfully');
    print('');

    // Run verification checks
    final results = await _runVerificationChecks(db);

    // Print summary
    print('');
    print('=' * 60);
    print('📊 VERIFICATION SUMMARY');
    print('=' * 60);

    final allPassed = results.every((r) => r.passed);
    if (allPassed) {
      print('✅ ALL CHECKS PASSED!');
      print('');
      print('Your database schema is ready for Phase 3.6A implementation.');
    } else {
      print('⚠️  SOME CHECKS FAILED');
      print('');
      print('Please review the issues above before proceeding with');
      print('Phase 3.6A implementation.');

      final failures = results.where((r) => !r.passed).toList();
      print('');
      print('Failed checks:');
      for (final failure in failures) {
        print('  ❌ ${failure.name}');
        if (failure.details != null) {
          print('     ${failure.details}');
        }
      }
    }

    print('=' * 60);

    exit(allPassed ? 0 : 1);
  } catch (e) {
    print('❌ Error during verification: $e');
    exit(1);
  } finally {
    await db?.close();
  }
}

/// Find the database path following the app's conventions
Future<String?> _findDatabasePath() async {
  // Try Linux/Desktop path
  final home = Platform.environment['HOME'];
  if (home != null) {
    final dbPath = path.join(home, '.local', 'share', 'pin_and_paper', 'pin_and_paper.db');
    if (await File(dbPath).exists()) {
      return dbPath;
    }
  }

  return null;
}

/// Represents a verification check result
class VerificationResult {
  final String name;
  final bool passed;
  final String? details;

  VerificationResult(this.name, this.passed, [this.details]);
}

/// Run all verification checks
Future<List<VerificationResult>> _runVerificationChecks(Database db) async {
  final results = <VerificationResult>[];

  // Check 1: Verify all required tables exist
  results.add(await _verifyTables(db));

  // Check 2: Verify tasks table schema
  results.add(await _verifyTasksTableSchema(db));

  // Check 3: Verify tags table schema
  results.add(await _verifyTagsTableSchema(db));

  // Check 4: Verify task_tags junction table schema
  results.add(await _verifyTaskTagsTableSchema(db));

  // Check 5: Verify all required indexes exist
  results.add(await _verifyIndexes(db));

  // Check 6: Run sample queries to verify functionality
  results.add(await _verifySampleQueries(db));

  return results;
}

/// Verify all required tables exist
Future<VerificationResult> _verifyTables(Database db) async {
  print('🔍 Checking tables...');

  try {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    );

    final tableNames = tables.map((t) => t['name'] as String).toSet();

    print('   Found ${tables.length} tables:');
    for (final table in tables) {
      print('     - ${table['name']}');
    }

    final requiredTables = {'tasks', 'tags', 'task_tags'};
    final missingTables = requiredTables.difference(tableNames);

    if (missingTables.isEmpty) {
      print('   ✅ All required tables exist');
      return VerificationResult('Tables', true);
    } else {
      print('   ❌ Missing tables: ${missingTables.join(', ')}');
      return VerificationResult(
        'Tables',
        false,
        'Missing: ${missingTables.join(', ')}'
      );
    }
  } catch (e) {
    print('   ❌ Error checking tables: $e');
    return VerificationResult('Tables', false, 'Error: $e');
  }
}

/// Verify tasks table has required columns
Future<VerificationResult> _verifyTasksTableSchema(Database db) async {
  print('');
  print('🔍 Checking tasks table schema...');

  try {
    final columns = await db.rawQuery("PRAGMA table_info(tasks);");

    final columnNames = columns.map((c) => c['name'] as String).toSet();

    final requiredColumns = {
      'id', 'title', 'completed', 'deleted_at', 'position',
      'created_at', 'updated_at', 'parent_id', 'depth', 'has_children'
    };

    final missingColumns = requiredColumns.difference(columnNames);

    if (missingColumns.isEmpty) {
      print('   ✅ All required columns exist (${requiredColumns.length} columns)');
      return VerificationResult('Tasks table schema', true);
    } else {
      print('   ❌ Missing columns: ${missingColumns.join(', ')}');
      return VerificationResult(
        'Tasks table schema',
        false,
        'Missing: ${missingColumns.join(', ')}'
      );
    }
  } catch (e) {
    print('   ❌ Error checking tasks table: $e');
    return VerificationResult('Tasks table schema', false, 'Error: $e');
  }
}

/// Verify tags table has required columns
Future<VerificationResult> _verifyTagsTableSchema(Database db) async {
  print('');
  print('🔍 Checking tags table schema...');

  try {
    final columns = await db.rawQuery("PRAGMA table_info(tags);");

    final columnNames = columns.map((c) => c['name'] as String).toSet();

    final requiredColumns = {
      'id', 'name', 'color', 'created_at', 'updated_at'
    };

    final missingColumns = requiredColumns.difference(columnNames);

    if (missingColumns.isEmpty) {
      print('   ✅ All required columns exist (${requiredColumns.length} columns)');
      return VerificationResult('Tags table schema', true);
    } else {
      print('   ❌ Missing columns: ${missingColumns.join(', ')}');
      return VerificationResult(
        'Tags table schema',
        false,
        'Missing: ${missingColumns.join(', ')}'
      );
    }
  } catch (e) {
    print('   ❌ Error checking tags table: $e');
    return VerificationResult('Tags table schema', false, 'Error: $e');
  }
}

/// Verify task_tags junction table has required columns
Future<VerificationResult> _verifyTaskTagsTableSchema(Database db) async {
  print('');
  print('🔍 Checking task_tags junction table schema...');

  try {
    final columns = await db.rawQuery("PRAGMA table_info(task_tags);");

    final columnNames = columns.map((c) => c['name'] as String).toSet();

    final requiredColumns = {'task_id', 'tag_id'};

    final missingColumns = requiredColumns.difference(columnNames);

    if (missingColumns.isEmpty) {
      print('   ✅ All required columns exist (${requiredColumns.length} columns)');
      return VerificationResult('Task_tags table schema', true);
    } else {
      print('   ❌ Missing columns: ${missingColumns.join(', ')}');
      return VerificationResult(
        'Task_tags table schema',
        false,
        'Missing: ${missingColumns.join(', ')}'
      );
    }
  } catch (e) {
    print('   ❌ Error checking task_tags table: $e');
    return VerificationResult('Task_tags table schema', false, 'Error: $e');
  }
}

/// Verify all required indexes exist
Future<VerificationResult> _verifyIndexes(Database db) async {
  print('');
  print('🔍 Checking indexes...');

  try {
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name;"
    );

    final indexNames = indexes.map((i) => i['name'] as String).toSet();

    // SQLite auto-creates indexes for PRIMARY KEY and UNIQUE constraints
    // We only check for explicitly created indexes
    final requiredIndexes = {
      'idx_task_tags_task_id',
      'idx_task_tags_tag_id',
      'idx_tasks_completed',
      'idx_tasks_deleted_at',
      'idx_tasks_position',
    };

    print('   Found ${indexes.length} indexes:');
    for (final index in indexes) {
      final name = index['name'] as String;
      final isRequired = requiredIndexes.contains(name);
      print('     ${isRequired ? '✓' : ' '} $name');
    }

    final missingIndexes = requiredIndexes.difference(indexNames);

    if (missingIndexes.isEmpty) {
      print('   ✅ All required indexes exist');
      return VerificationResult('Indexes', true);
    } else {
      print('   ⚠️  Missing indexes: ${missingIndexes.join(', ')}');
      print('   Note: These indexes are recommended for optimal performance.');
      print('   Phase 3.6A filtering will still work but may be slower.');
      // Return true but with a warning
      return VerificationResult(
        'Indexes',
        true,  // Non-blocking
        'Missing (non-critical): ${missingIndexes.join(', ')}'
      );
    }
  } catch (e) {
    print('   ❌ Error checking indexes: $e');
    return VerificationResult('Indexes', false, 'Error: $e');
  }
}

/// Run sample queries to verify database functionality
Future<VerificationResult> _verifySampleQueries(Database db) async {
  print('');
  print('🔍 Running sample queries...');

  try {
    // Query 1: Count tasks
    final taskCount = await db.rawQuery('SELECT COUNT(*) as count FROM tasks WHERE deleted_at IS NULL');
    final numTasks = taskCount.first['count'] as int;
    print('   ✓ Tasks query successful ($numTasks tasks)');

    // Query 2: Count tags
    final tagCount = await db.rawQuery('SELECT COUNT(*) as count FROM tags');
    final numTags = tagCount.first['count'] as int;
    print('   ✓ Tags query successful ($numTags tags)');

    // Query 3: Test junction table query (simulating a tag filter)
    final joinQuery = await db.rawQuery('''
      SELECT COUNT(DISTINCT tasks.id) as count
      FROM tasks
      INNER JOIN task_tags ON tasks.id = task_tags.task_id
      WHERE tasks.deleted_at IS NULL
    ''');
    final numTaggedTasks = joinQuery.first['count'] as int;
    print('   ✓ Junction table query successful ($numTaggedTasks tagged tasks)');

    // Query 4: Test completed filter
    final completedQuery = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM tasks
      WHERE deleted_at IS NULL AND completed = 1
    ''');
    final numCompleted = completedQuery.first['count'] as int;
    print('   ✓ Completed filter query successful ($numCompleted completed tasks)');

    print('   ✅ All sample queries executed successfully');
    return VerificationResult('Sample queries', true);
  } catch (e) {
    print('   ❌ Error running sample queries: $e');
    return VerificationResult('Sample queries', false, 'Error: $e');
  }
}
