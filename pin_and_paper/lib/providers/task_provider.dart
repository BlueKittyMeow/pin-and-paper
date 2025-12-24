import 'package:flutter/foundation.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';
import '../models/task_suggestion.dart'; // Phase 2
import '../services/task_service.dart';
import '../services/preferences_service.dart'; // Phase 2 Stretch

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService;
  final PreferencesService _preferencesService;

  TaskProvider({TaskService? taskService, PreferencesService? preferencesService})
      : _taskService = taskService ?? TaskService(),
        _preferencesService = preferencesService ?? PreferencesService() {
    // Phase 3.2: Initialize TreeController for hierarchical view
    _treeController = TreeController<Task>(
      roots: [],  // Start empty, populated in loadTasks
      childrenProvider: (Task task) => _tasks.where((t) => t.parentId == task.id),
      parentProvider: (Task task) => _findParent(task.parentId),
    );
  }

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Phase 3.2: Hierarchy state
  bool _isReorderMode = false;
  late TreeController<Task> _treeController;

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

  // Phase 3.2: Hierarchy getters
  bool get isReorderMode => _isReorderMode;
  TreeController<Task> get treeController => _treeController;

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

  // Phase 3.2: Helper to find parent task by ID
  Task? _findParent(String? parentId) {
    if (parentId == null) return null;
    try {
      return _tasks.firstWhere((t) => t.id == parentId);
    } catch (e) {
      return null;
    }
  }

  // Phase 3.2: Refresh TreeController roots with visible tasks
  // Respects hideOldCompleted setting for filtering
  void _refreshTreeController() {
    // Get root-level tasks (parentId == null)
    final rootTasks = _tasks.where((t) => t.parentId == null);

    // Apply visibility filtering (hide old completed tasks if enabled)
    final visibleRoots = _hideOldCompleted
        ? rootTasks.where((t) {
            // Show active tasks
            if (!t.completed) return true;

            // Show recently completed tasks
            if (t.completedAt == null) return false;
            final hoursSinceCompletion = DateTime.now().difference(t.completedAt!).inHours;
            return hoursSinceCompletion < _hideThresholdHours;
          })
        : rootTasks;

    _treeController.roots = visibleRoots;
    _treeController.rebuild();
  }

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

  // Load all tasks from database with hierarchy
  // Phase 3.2: Updated to use getTaskHierarchy() and refresh TreeController
  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Phase 3.2: Load with hierarchy information (depth computed dynamically)
      _tasks = await _taskService.getTaskHierarchy();
      _categorizeTasks();  // Categorize once after load

      // Phase 3.2: Refresh TreeController with filtered visible tasks
      _refreshTreeController();
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
    _refreshTreeController();  // Phase 3.2: Update visible tasks
    notifyListeners();
  }

  // Phase 2 Stretch: Update threshold setting
  Future<void> setHideThresholdHours(int hours) async {
    _hideThresholdHours = hours;
    await _preferencesService.setHideThresholdHours(hours);
    _categorizeTasks();  // Re-categorize with new threshold
    _refreshTreeController();  // Phase 3.2: Update visible tasks
    notifyListeners();
  }

  // Create a new task
  Future<void> createTask(String title) async {
    if (title.trim().isEmpty) return;

    _errorMessage = null;

    try {
      final newTask = await _taskService.createTask(title);
      _tasks.insert(0, newTask); // Add to beginning of list
      _categorizeTasks(); // Keep derived task buckets in sync for UI

      // Phase 3.2: Refresh TreeController with new task
      _refreshTreeController();

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

      // Phase 3.2: Refresh TreeController with new tasks
      _refreshTreeController();

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

        // Phase 3.2: Refresh TreeController to update visibility
        _refreshTreeController();

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  // ========== Phase 3.2: Hierarchy Methods ==========

  /// Enter/exit reorder mode
  void setReorderMode(bool enabled) {
    _isReorderMode = enabled;
    notifyListeners();
  }

  /// Toggle collapse/expand for a task node
  void toggleCollapse(Task task) {
    _treeController.toggleExpansion(task);
  }

  /// Move task to new parent (nest/unnest)
  Future<void> changeTaskParent({
    required String taskId,
    String? newParentId,
    required int newPosition,
  }) async {
    _errorMessage = null;

    try {
      final error = await _taskService.updateTaskParent(
        taskId,
        newParentId,
        newPosition,
      );

      if (error != null) {
        _errorMessage = error;
        notifyListeners();
        return;
      }

      // Reload tasks to reflect changes
      await loadTasks();
    } catch (e) {
      _errorMessage = 'Failed to move task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// Handle tree drag-and-drop reordering
  /// Reference: docs/phase-03/group1.md:1840-1905
  /// NOTE: Detailed drop position logic (above/inside/below) will be implemented
  /// in DragAndDropTaskTile widget based on hover zones
  Future<void> onNodeAccepted({
    required String draggedTaskId,
    required String? newParentId,
    required int newPosition,
    int? newDepth,
  }) async {
    // Validate depth limit if provided (max 4 levels: 0, 1, 2, 3)
    if (newDepth != null && newDepth >= 4) {
      _errorMessage = 'Maximum nesting depth (4 levels) reached';
      notifyListeners();
      return;
    }

    // Use existing changeTaskParent (has cycle detection + sibling reindexing)
    await changeTaskParent(
      taskId: draggedTaskId,
      newParentId: newParentId,
      newPosition: newPosition,
    );
  }

  /// Delete task with CASCADE confirmation
  /// Returns true if deleted, false if cancelled or error
  Future<bool> deleteTaskWithConfirmation(
    String taskId,
    Future<bool> Function(int) showConfirmation,
  ) async {
    _errorMessage = null;

    try {
      // Get child count for confirmation dialog
      final childCount = await _taskService.countDescendants(taskId);

      // Show confirmation if task has children
      if (childCount > 0) {
        final confirmed = await showConfirmation(childCount);
        if (!confirmed) return false;
      }

      // Delete task and all descendants from database
      final deletedCount = await _taskService.deleteTaskWithChildren(taskId);

      // CRITICAL: Reload all tasks from database to ensure consistency
      // This is safer than trying to manually remove all descendants from _tasks
      await loadTasks();

      debugPrint('Deleted $deletedCount task(s)');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }
}
