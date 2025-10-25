import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Task> get incompleteTasks =>
      _tasks.where((task) => !task.completed).toList();

  List<Task> get completedTasks =>
      _tasks.where((task) => task.completed).toList();

  int get incompleteCount => incompleteTasks.length;
  int get completedCount => completedTasks.length;

  // Load all tasks from database
  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _taskService.getAllTasks();
    } catch (e) {
      _errorMessage = 'Failed to load tasks: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new task
  Future<void> createTask(String title) async {
    if (title.trim().isEmpty) return;

    _errorMessage = null;

    try {
      final newTask = await _taskService.createTask(title);
      _tasks.insert(0, newTask); // Add to beginning of list
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to create task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(Task task) async {
    _errorMessage = null;

    try {
      final updatedTask = await _taskService.toggleTaskCompletion(task);

      // Update in local list
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }
}
