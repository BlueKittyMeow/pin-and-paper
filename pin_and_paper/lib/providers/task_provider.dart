import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/task_suggestion.dart'; // Phase 2
import '../services/task_service.dart';
import '../services/preferences_service.dart'; // Phase 2 Stretch

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService;
  final PreferencesService _preferencesService;

  TaskProvider({TaskService? taskService, PreferencesService? preferencesService})
      : _taskService = taskService ?? TaskService(),
        _preferencesService = preferencesService ?? PreferencesService();

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Phase 2 Stretch: Hide completed tasks settings
  bool _hideOldCompleted = true;
  int _hideThresholdHours = 24;

  // Phase 2 Stretch: Pre-categorized lists (calculated once per load, not on every build)
  List<Task> _activeTasks = [];
  List<Task> _recentlyCompletedTasks = [];
  List<Task> _oldCompletedTasks = [];

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

  // Phase 2 Stretch: Public getters for categorized lists
  List<Task> get activeTasks => _activeTasks;
  List<Task> get recentlyCompletedTasks => _recentlyCompletedTasks;
  List<Task> get oldCompletedTasks => _oldCompletedTasks;

  // For rendering: active + recently completed (old are hidden if setting enabled)
  List<Task> get visibleTasks {
    if (_hideOldCompleted) {
      return [..._activeTasks, ..._recentlyCompletedTasks];
    }
    return _tasks;  // Show all
  }

  bool get hideOldCompleted => _hideOldCompleted;
  int get hideThresholdHours => _hideThresholdHours;

  // Phase 2 Stretch: Categorize tasks after loading (called once per load, not per build)
  void _categorizeTasks() {
    final now = DateTime.now();

    _activeTasks = _tasks.where((t) => !t.completed).toList();

    _recentlyCompletedTasks = _tasks.where((t) {
      if (!t.completed) return false;
      if (t.completedAt == null) return false;

      final hoursSinceCompletion =
        now.difference(t.completedAt!).inHours;

      return hoursSinceCompletion < _hideThresholdHours;
    }).toList();

    _oldCompletedTasks = _tasks.where((t) {
      if (!t.completed) return false;
      if (t.completedAt == null) return true;  // Show if no timestamp

      final hoursSinceCompletion =
        now.difference(t.completedAt!).inHours;

      return hoursSinceCompletion >= _hideThresholdHours;
    }).toList();
  }

  // Load all tasks from database
  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _taskService.getAllTasks();
      _categorizeTasks();  // Categorize once after load
    } catch (e) {
      _errorMessage = 'Failed to load tasks: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Phase 2 Stretch: Load preferences (call during initialization)
  Future<void> loadPreferences() async {
    _hideOldCompleted = await _preferencesService.getHideOldCompleted();
    _hideThresholdHours = await _preferencesService.getHideThresholdHours();
    notifyListeners();
  }

  // Phase 2 Stretch: Update hide completed setting
  Future<void> setHideOldCompleted(bool value) async {
    _hideOldCompleted = value;
    await _preferencesService.setHideOldCompleted(value);
    notifyListeners();
  }

  // Phase 2 Stretch: Update threshold setting
  Future<void> setHideThresholdHours(int hours) async {
    _hideThresholdHours = hours;
    await _preferencesService.setHideThresholdHours(hours);
    _categorizeTasks();  // Re-categorize with new threshold
    notifyListeners();
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

  // Phase 2: Create multiple tasks from suggestions (bulk operation)
  // CRITICAL for performance - single transaction + single UI update
  Future<void> createMultipleTasks(List<TaskSuggestion> suggestions) async {
    if (suggestions.isEmpty) return;

    _errorMessage = null;

    try {
      final newTasks = await _taskService.createMultipleTasks(suggestions);
      // Add all new tasks to the beginning of the list
      _tasks.insertAll(0, newTasks);
      // CRITICAL: Re-categorize to populate activeTasks, recentlyCompletedTasks, etc.
      _categorizeTasks();
      // Single notify! Much better than N notifies for N tasks
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to create tasks: $e';
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
        _categorizeTasks();  // Phase 2 Stretch: Re-categorize after toggle
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }
}
