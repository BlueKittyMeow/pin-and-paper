import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/task_suggestion.dart'; // Phase 2
import '../utils/constants.dart';
import 'database_service.dart';

class TaskService {
  final DatabaseService _dbService = DatabaseService.instance;
  final Uuid _uuid = const Uuid();

  // Create a new task
  Future<Task> createTask(String title) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Task title cannot be empty');
    }

    final task = Task(
      id: _generateId(),
      title: title.trim(),
      createdAt: DateTime.now(),
    );

    final db = await _dbService.database;
    await db.insert(
      AppConstants.tasksTable,
      task.toMap(),
      // Removed ConflictAlgorithm.replace to prevent silent data loss
      // Default is ConflictAlgorithm.abort which throws on duplicate IDs
    );

    return task;
  }

  // Phase 2: Create multiple tasks in a single transaction (for bulk imports)
  // This is CRITICAL for performance - prevents UI stuttering when adding 10+ tasks
  Future<List<Task>> createMultipleTasks(List<TaskSuggestion> suggestions) async {
    if (suggestions.isEmpty) return [];

    final db = await _dbService.database;
    final List<Task> createdTasks = [];

    // Use a transaction for atomicity and performance
    // All tasks are created in one database operation instead of N operations
    await db.transaction((txn) async {
      for (final suggestion in suggestions) {
        // Only create approved tasks
        if (!suggestion.approved) continue;

        final task = Task(
          id: suggestion.id, // Reuse suggestion ID (already UUID from ClaudeService)
          title: suggestion.title,
          createdAt: DateTime.now(),
        );

        await txn.insert(
          AppConstants.tasksTable,
          task.toMap(),
        );

        createdTasks.add(task);
      }
    });

    return createdTasks;
  }

  // Get all tasks (ordered by creation date, newest first)
  Future<List<Task>> getAllTasks() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tasksTable,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // Toggle task completion status
  Future<Task> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(
      completed: !task.completed,
      completedAt: !task.completed ? DateTime.now() : null,
    );

    final db = await _dbService.database;
    await db.update(
      AppConstants.tasksTable,
      updatedTask.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    return updatedTask;
  }

  // Get count of incomplete tasks
  Future<int> getIncompleteTaskCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tasksTable} WHERE completed = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Get count of completed tasks
  Future<int> getCompletedTaskCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tasksTable} WHERE completed = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Helper: Generate unique ID using UUID v4
  // This prevents ID collisions during rapid/bulk task creation
  String _generateId() {
    return _uuid.v4();
  }
}
