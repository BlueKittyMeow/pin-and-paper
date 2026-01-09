#!/usr/bin/env dart
// Script to set up Test 7 performance testing data
// Creates 10 parent tasks + 50 children (5 per parent) = 60 total
// Then completes all tasks to test completed task hierarchy performance

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

void main() async {
  print('🚀 Performance Test Data Setup Script');
  print('='*50);
  print('This will create:');
  print('  - 10 parent tasks');
  print('  - 50 child tasks (5 per parent)');
  print('  - Complete all 60 tasks');
  print('='*50);

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

  // Confirm before proceeding
  print('⚠️  WARNING: This will add 60 tasks to your database!');
  stdout.write('Continue? (y/N): ');
  final response = stdin.readLineSync()?.toLowerCase();
  if (response != 'y' && response != 'yes') {
    print('❌ Cancelled');
    exit(0);
  }

  print('');
  print('🔨 Creating test data...');

  // Open database
  final db = await openDatabase(dbPath);

  try {
    // Create tasks with hierarchy
    final parentIds = <String>[];

    // Create 10 parent tasks
    for (int i = 1; i <= 10; i++) {
      final parentId = 'perf-parent-$i';
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('tasks', {
        'id': parentId,
        'title': 'Performance Test Parent $i',
        'completed': 0,
        'position': i,
        'parent_id': null,
        'created_at': now,
        'completed_at': null,
        'deleted_at': null,
      });

      parentIds.add(parentId);
      print('  ✓ Created parent $i: Performance Test Parent $i');

      // Create 5 children for this parent
      for (int j = 1; j <= 5; j++) {
        final childId = 'perf-child-$i-$j';

        await db.insert('tasks', {
          'id': childId,
          'title': 'Child $j of Parent $i',
          'completed': 0,
          'position': j,
          'parent_id': parentId,
          'created_at': now + j,
          'completed_at': null,
          'deleted_at': null,
        });
      }

      print('    ✓ Created 5 children for parent $i');
    }

    print('');
    print('✅ Created 60 tasks (10 parents + 50 children)');
    print('');
    print('🎯 Completing all tasks...');

    // Complete all tasks
    final completedAt = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'tasks',
      {'completed': 1, 'completed_at': completedAt},
      where: "id LIKE 'perf-%'",
    );

    print('✅ Completed all 60 tasks');
    print('');
    print('='*50);
    print('🎉 Performance test data setup complete!');
    print('');
    print('Next steps:');
    print('  1. Restart the app to load new data');
    print('  2. Scroll to completed section');
    print('  3. Test scroll performance with 60 hierarchical tasks');
    print('  4. Monitor frame rate and responsiveness');
    print('');
    print('To clean up this test data later, run:');
    print('  DELETE FROM tasks WHERE id LIKE "perf-%";');
    print('='*50);

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    await db.close();
  }
}

Future<String?> _findDatabasePath() async {
  // Try common Linux locations
  final home = Platform.environment['HOME'];
  if (home == null) return null;

  final possiblePaths = [
    path.join(home, 'Documents', 'pin_and_paper.db'),  // Development location
    path.join(home, '.local', 'share', 'pin_and_paper', 'pin_and_paper.db'),
    path.join(home, '.local', 'share', 'com.example.pin_and_paper', 'pin_and_paper.db'),
  ];

  for (final dbPath in possiblePaths) {
    if (await File(dbPath).exists()) {
      return dbPath;
    }
  }

  return null;
}
