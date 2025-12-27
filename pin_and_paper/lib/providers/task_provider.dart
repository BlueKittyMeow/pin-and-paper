import 'package:flutter/foundation.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';
import '../models/task_suggestion.dart'; // Phase 2
import '../services/task_service.dart';
import '../services/preferences_service.dart'; // Phase 2 Stretch
import '../widgets/drag_and_drop_task_tile.dart'; // Phase 3.2: For mapDropPosition extension

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

  // Phase 3.2: Check if a task has any incomplete descendants
  bool _hasIncompleteDescendants(Task task) {
    final children = _tasks.where((t) => t.parentId == task.id);
    for (final child in children) {
      if (!child.completed) return true;
      if (_hasIncompleteDescendants(child)) return true;
    }
    return false;
  }

  // Phase 3.2: Build breadcrumb path for a task (root > parent > grandparent)
  String? getBreadcrumb(Task task) {
    if (task.parentId == null) return null; // No breadcrumb for root tasks

    List<String> path = [];
    String? currentParentId = task.parentId;

    while (currentParentId != null) {
      final parent = _findParent(currentParentId);
      if (parent == null) break;
      path.insert(0, parent.title); // Insert at beginning to build path from root
      currentParentId = parent.parentId;
    }

    return path.isEmpty ? null : path.join(' > ');
  }

  // Phase 3.2: Refresh TreeController with active tasks
  // Active = incomplete OR (completed but has incomplete descendants)
  void _refreshTreeController() {
    final activeRoots = _tasks.where((t) {
      if (t.parentId != null) return false; // Only roots
      if (!t.completed) return true; // Incomplete tasks always active
      return _hasIncompleteDescendants(t); // Completed with incomplete children
    });
    _treeController.roots = activeRoots;
    _treeController.rebuild();
  }

  // Phase 3.2: Get ALL visible completed tasks (with breadcrumbs for nested tasks)
  // Only show tasks where task AND all descendants are complete
  List<Task> get visibleCompletedTasks {
    final fullyCompletedTasks = _tasks.where((t) {
      if (!t.completed) return false; // Must be completed
      if (_hasIncompleteDescendants(t)) return false; // Must have all descendants complete
      return true;
    });

    if (!_hideOldCompleted) {
      // If not hiding old completed, show all fully completed tasks
      return fullyCompletedTasks.toList();
    }

    // Show only recently completed tasks (within threshold)
    return fullyCompletedTasks.where((t) {
      if (t.completedAt == null) return false;
      final hoursSinceCompletion = DateTime.now().difference(t.completedAt!).inHours;
      return hoursSinceCompletion < _hideThresholdHours;
    }).toList();
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
  /// Takes TreeDragAndDropDetails and uses mapDropPosition extension
  /// Reference: docs/phase-03/group1.md:1840-1905
  Future<void> onNodeAccepted(TreeDragAndDropDetails<Task> details) async {
    String? newParentId;
    int newPosition = 0;
    int newDepth = 0;

    // Determine drop location based on hover zone (30/40/30 split)
    // Uses extension from drag_and_drop_task_tile.dart
    details.mapDropPosition(
      whenAbove: () {
        // Insert as previous sibling of target
        newParentId = details.targetNode.parentId;

        // CRITICAL: Calculate actual index in current sibling list, not stored position
        final siblings = _tasks.where((t) => t.parentId == newParentId).toList();
        final targetIndex = siblings.indexWhere((t) => t.id == details.targetNode.id);
        newPosition = targetIndex >= 0 ? targetIndex : 0;
        newDepth = details.targetNode.depth;
      },
      whenInside: () {
        // Insert as last child of target
        newParentId = details.targetNode.id;
        final siblings = _tasks.where((t) => t.parentId == newParentId).toList();
        newPosition = siblings.length;
        newDepth = details.targetNode.depth + 1;

        // Auto-expand target to show new child
        _treeController.setExpansionState(details.targetNode, true);
      },
      whenBelow: () {
        // Insert as next sibling of target
        newParentId = details.targetNode.parentId;

        // CRITICAL: Calculate actual index in current sibling list, not stored position
        final siblings = _tasks.where((t) => t.parentId == newParentId).toList();
        final targetIndex = siblings.indexWhere((t) => t.id == details.targetNode.id);
        newPosition = targetIndex >= 0 ? targetIndex + 1 : 0;
        newDepth = details.targetNode.depth;
      },
    );

    // Validate depth limit (max 4 levels: 0, 1, 2, 3)
    if (newDepth >= 4) {
      _errorMessage = 'Maximum nesting depth (4 levels) reached';
      notifyListeners();
      return;
    }

    // Use existing changeTaskParent (has cycle detection + sibling reindexing)
    await changeTaskParent(
      taskId: details.draggedNode.id,
      newParentId: newParentId,
      newPosition: newPosition,
    );
  }

  /// Soft delete task with CASCADE confirmation (Phase 3.3)
  /// Moves task to "Recently Deleted" instead of permanently deleting
  /// Returns true if soft-deleted, false if cancelled or error
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

      // Soft delete task and all descendants (Phase 3.3)
      final deletedCount = await _taskService.softDeleteTask(taskId);

      // CRITICAL: Reload all tasks from database to ensure consistency
      // This is safer than trying to manually remove all descendants from _tasks
      await loadTasks();

      debugPrint('Soft-deleted $deletedCount task(s)');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to soft delete task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // PHASE 3.3: RECENTLY DELETED METHODS
  // ============================================

  /// Restore a soft-deleted task and all its descendants
  /// Returns true if restored, false if error
  Future<bool> restoreTask(String taskId) async {
    _errorMessage = null;

    try {
      final restoredCount = await _taskService.restoreTask(taskId);

      // Reload tasks to show restored tasks
      await loadTasks();

      debugPrint('Restored $restoredCount task(s)');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to restore task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Permanently delete a soft-deleted task with confirmation
  /// Returns true if permanently deleted, false if cancelled or error
  Future<bool> permanentlyDeleteTask(
    String taskId,
    Future<bool> Function() showConfirmation,
  ) async {
    _errorMessage = null;

    try {
      // Always show confirmation for permanent delete
      final confirmed = await showConfirmation();
      if (!confirmed) return false;

      // Permanent delete (hard delete)
      final deletedCount = await _taskService.permanentlyDeleteTask(taskId);

      // No need to reload main tasks since they're already filtered out
      // But reload in case we're on the Recently Deleted screen
      notifyListeners();

      debugPrint('Permanently deleted $deletedCount task(s)');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to permanently delete task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Empty trash - permanently delete all soft-deleted tasks
  /// Returns true if emptied, false if cancelled or error
  Future<bool> emptyTrash(
    Future<bool> Function(int) showConfirmation,
  ) async {
    _errorMessage = null;

    try {
      // Get count of deleted tasks for confirmation
      final deletedCount = await _taskService.countRecentlyDeletedTasks();

      if (deletedCount == 0) {
        return false; // Nothing to delete
      }

      // Show confirmation with count
      final confirmed = await showConfirmation(deletedCount);
      if (!confirmed) return false;

      // Empty trash
      final permanentlyDeletedCount = await _taskService.emptyTrash();

      notifyListeners();

      debugPrint('Emptied trash: $permanentlyDeletedCount task(s)');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to empty trash: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Get count of recently deleted tasks (for badge display)
  Future<int> getRecentlyDeletedCount() async {
    try {
      return await _taskService.countRecentlyDeletedTasks();
    } catch (e) {
      debugPrint('Failed to get recently deleted count: $e');
      return 0;
    }
  }

  /// Get recently deleted tasks for Recently Deleted screen
  Future<List<Task>> getRecentlyDeletedTasks() async {
    try {
      return await _taskService.getRecentlyDeletedTasks();
    } catch (e) {
      debugPrint('Failed to get recently deleted tasks: $e');
      return [];
    }
  }
}
