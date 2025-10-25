import 'package:sqflite/sqflite.dart';
import '../models/task.dart';
import '../utils/constants.dart';
import 'database_service.dart';

class TaskService {
  final DatabaseService _dbService = DatabaseService.instance;

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
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return task;
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

  // Helper: Generate unique ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
