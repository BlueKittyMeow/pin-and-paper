#!/usr/bin/env dart
// Script to set up Test 7 performance testing data
// Uses TaskService API to properly create hierarchical tasks

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import '../lib/services/database_service.dart';
import '../lib/services/task_service.dart';

void main() async {
  print('🚀 Performance Test Data Setup Script (v2)');
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
    print('   Expected locations:');
    print('     - ~/Documents/pin_and_paper.db');
    print('     - ~/.local/share/pin_and_paper/pin_and_paper.db');
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
  print('🔨 Creating test data using TaskService...');

  try {
    // Set test database path
    DatabaseService.setTestDatabasePath(dbPath);

    // Initialize services
    final taskService = TaskService();

    // Create 10 parent tasks
    final parentTasks = <String, dynamic>{};

    for (int i = 1; i <= 10; i++) {
      final parent = await taskService.createTask('Performance Test Parent $i');
      parentTasks[parent.id] = i;
      print('  ✓ Created parent $i: ${parent.title}');

      // Create 5 children for this parent
      for (int j = 1; j <= 5; j++) {
        final child = await taskService.createTask('Child $j of Parent $i');
        // Nest child under parent
        await taskService.updateTaskParent(child.id, parent.id, j - 1);
      }

      print('    ✓ Created 5 children for parent $i');
    }

    print('');
    print('✅ Created 60 tasks (10 parents + 50 children)');
    print('');
    print('🎯 Completing all tasks...');

    // Get all tasks we just created
    final allTasks = await taskService.getTaskHierarchy();
    final perfTasks = allTasks.where((t) =>
      t.title.startsWith('Performance Test Parent') ||
      t.title.startsWith('Child')
    ).toList();

    // Complete all tasks
    for (final task in perfTasks) {
      await taskService.toggleTaskCompletion(task);
    }

    print('✅ Completed all ${perfTasks.length} tasks');
    print('');
    print('='*50);
    print('🎉 Performance test data setup complete!');
    print('');
    print('Next steps:');
    print('  1. Restart the app to see new data');
    print('  2. Scroll to completed section');
    print('  3. Test scroll performance with 60 hierarchical tasks');
    print('  4. Monitor frame rate and responsiveness');
    print('');
    print('Note: Tasks created with titles starting with');
    print('"Performance Test Parent" and "Child"');
    print('='*50);

  } catch (e, stack) {
    print('❌ Error: $e');
    print('Stack trace:');
    print(stack);
    exit(1);
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
