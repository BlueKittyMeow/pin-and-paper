import 'dart:async'; // Phase 3.6B: For Timer (highlight functionality)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Phase 3.6B: For GlobalKey, Scrollable, Curves (scroll-to-task)
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/filter_state.dart'; // Phase 3.6A
import '../models/task.dart';
import '../models/tag.dart'; // Phase 3.5
import '../models/task_suggestion.dart'; // Phase 2
import '../providers/tag_provider.dart'; // Phase 3.6A
import '../services/task_service.dart';
import '../services/tag_service.dart'; // Phase 3.5
import '../services/database_service.dart'; // Phase 3.6A: For database access
import '../services/preferences_service.dart'; // Phase 2 Stretch
import '../utils/constants.dart'; // Phase 3.6A: For AppConstants table names
import '../widgets/drag_and_drop_task_tile.dart'; // Phase 3.2: For mapDropPosition extension

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService;
  final PreferencesService _preferencesService;
  final TagService _tagService; // Phase 3.5
  final TagProvider _tagProvider; // Phase 3.6A

  TaskProvider({
    TaskService? taskService,
    PreferencesService? preferencesService,
    TagService? tagService, // Phase 3.5
    TagProvider? tagProvider, // Phase 3.6A
  })  : _taskService = taskService ?? TaskService(),
        _preferencesService = preferencesService ?? PreferencesService(),
        _tagService = tagService ?? TagService(), // Phase 3.5
        _tagProvider = tagProvider ?? TagProvider() { // Phase 3.6A
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

  // Phase 3.5: Tag storage (loaded with tasks)
  Map<String, List<Tag>> _taskTags = {};

  // Phase 3.5 Fix #C3: Cache completed child map for O(1) hasCompletedChildren lookup
  // Updated by completedTasksWithHierarchy, used by hasCompletedChildren (Codex review fix)
  Map<String, List<Task>> _lastCompletedChildMap = {};

  // Phase 3.5: Codex review - reentrant guard for loadTasks()
  Future<void>? _loadTasksFuture;

  // Phase 3.6A: Filter state
  FilterState _filterState = FilterState.empty;
  int _filterOperationId = 0; // Race condition prevention

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

  // Phase 3.5: Get tags for a specific task
  List<Tag> getTagsForTask(String taskId) {
    return _taskTags[taskId] ?? [];
  }

  // Phase 3.6A: Filter state getters
  FilterState get filterState => _filterState;
  bool get hasActiveFilters => _filterState.isActive;

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

  // Phase 3.5 Fix #C3: Check if a completed task has any completed children
  //
  // Uses cached child map from last completedTasksWithHierarchy call
  // for O(1) lookup instead of O(N) scan (Codex review fix)
  //
  // Returns true if at least one completed child exists
  bool hasCompletedChildren(String taskId) {
    // O(1) lookup in cached map
    return _lastCompletedChildMap.containsKey(taskId);
  }

  // Phase 3.5 Fix #C3: Recursively add completed descendants in depth-first order
  //
  // Uses prebuilt child map for O(1) lookup per task
  // Sorts children by position before adding (Codex fix)
  void _addCompletedDescendants(
    Task parent,
    Map<String, List<Task>> childMap,
    List<Task> result,
  ) {
    final children = childMap[parent.id];
    if (children == null || children.isEmpty) return;

    // Sort children by position (Codex fix)
    children.sort((a, b) => a.position.compareTo(b.position));

    // Add children in order, recursing for each
    for (final child in children) {
      result.add(child);
      _addCompletedDescendants(child, childMap, result);
    }
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
    // Phase 3.6A: Build task ID set for efficient lookup
    final taskIds = _tasks.map((t) => t.id).toSet();

    final activeRoots = _tasks.where((t) {
      // Phase 3.6A: In filtered views, treat as root if parent not in filtered results
      if (t.parentId != null) {
        // If parent exists in current task list, this is not a root
        if (taskIds.contains(t.parentId)) {
          debugPrint('[TreeRefresh] Task "${t.title}" (${t.id.substring(0, 8)}) has parent ${t.parentId?.substring(0, 8)} in filtered results - NOT a root');
          return false;
        }
        // Parent not in filtered results - treat as root
        debugPrint('[TreeRefresh] Task "${t.title}" (${t.id.substring(0, 8)}) has parent ${t.parentId?.substring(0, 8)} NOT in filtered results - treating as root');
      }
      // Original logic: true root (parentId == null) or orphaned in filtered view
      if (!t.completed) return true; // Incomplete tasks always active
      return _hasIncompleteDescendants(t); // Completed with incomplete children
    });

    debugPrint('[TreeRefresh] Setting ${activeRoots.length} roots from ${_tasks.length} total tasks');
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

  // Phase 3.5 Fix #C3: Get completed tasks with hierarchy preserved
  //
  // Returns completed tasks in tree order:
  // - Roots first (no parent OR parent not completed)
  // - Then their completed descendants
  // - Sorted by position within each level
  //
  // **CRITICAL:** Handles orphaned completed children
  // (child completed, parent incomplete) by treating them as roots
  //
  // **Performance:** O(N) using child map + Set for lookups
  List<Task> get completedTasksWithHierarchy {
    // Get all fully completed tasks (no incomplete descendants)
    final completed = _tasks.where((t) {
      if (!t.completed) return false;
      if (_hasIncompleteDescendants(t)) return false;
      return true;
    }).toList();

    // Build child map ONCE for O(N) performance (Codex fix)
    // Maps parent ID -> list of completed children
    final childMap = <String, List<Task>>{};
    for (final task in completed) {
      if (task.parentId != null) {
        childMap.putIfAbsent(task.parentId!, () => []).add(task);
      }
    }

    // Build completed ID set for O(1) membership test (Codex review fix)
    // Prevents O(N²) complexity when finding roots
    final completedIds = completed.map((t) => t.id).toSet();

    // Find roots: Tasks with no parent OR parent not in completed set
    // **CRITICAL:** This handles orphaned completed children (Codex fix)
    final roots = completed.where((t) =>
      t.parentId == null ||
      !completedIds.contains(t.parentId)  // O(1) instead of O(N)
    ).toList()
      ..sort((a, b) => a.position.compareTo(b.position)); // Codex fix: Sort roots

    // Cache child map for hasCompletedChildren to use (Codex review fix)
    _lastCompletedChildMap = childMap;

    // Build tree in depth-first order
    final result = <Task>[];
    for (final root in roots) {
      result.add(root);
      _addCompletedDescendants(root, childMap, result);
    }

    return result;
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
  // Phase 3.5: Updated to batch-load tags for all tasks
  // Codex review: Added reentrant guard to prevent race conditions
  Future<void> loadTasks() async {
    // Return existing future if load already in progress
    if (_loadTasksFuture != null) {
      return _loadTasksFuture!;
    }

    _loadTasksFuture = _performLoadTasks();
    try {
      await _loadTasksFuture;
    } finally {
      _loadTasksFuture = null;
    }
  }

  Future<void> _performLoadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Phase 3.2: Load with hierarchy information (depth computed dynamically)
      _tasks = await _taskService.getTaskHierarchy();
      _categorizeTasks();  // Categorize once after load

      // Phase 3.5: Batch-load all tags for these tasks
      final taskIds = _tasks.map((t) => t.id).toList();
      _taskTags = await _tagService.getTagsForAllTasks(taskIds);

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

  /// Refresh only tag data without reloading tasks or resetting tree state
  ///
  /// Phase 3.5: Codex review - avoid tree collapse when editing tags
  /// Use this instead of loadTasks() when only tag associations changed
  /// Preserves tree expansion state and avoids full reload
  Future<void> refreshTags() async {
    try {
      // Reload only the tag associations
      final taskIds = _tasks.map((t) => t.id).toList();
      _taskTags = await _tagService.getTagsForAllTasks(taskIds);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing tags: $e');
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

  // Phase 3.4: Update task title
  /// Updates a task's title
  ///
  /// OPTIMIZED: In-memory update to avoid:
  /// - Full database reload (Gemini feedback - performance)
  /// - TreeController collapse (Codex feedback - UX regression)
  Future<void> updateTaskTitle(String taskId, String newTitle) async {
    _errorMessage = null;

    try {
      final updatedTask = await _taskService.updateTaskTitle(taskId, newTitle);

      // Find and update the task in-memory
      final index = _tasks.indexWhere((task) => task.id == taskId);
      if (index != -1) {
        // Codex merge review: Preserve depth metadata from original task
        // (TaskService rebuilds from plain SELECT which has depth=0)
        final originalDepth = _tasks[index].depth;
        _tasks[index] = updatedTask.copyWith(depth: originalDepth);

        // Codex merge review: Re-categorize to keep derived lists synchronized
        _categorizeTasks();

        // Phase 3.4: Refresh TreeController to update UI without collapsing
        _refreshTreeController();
        notifyListeners();
      } else {
        // Fallback: reload if task not found (shouldn't happen)
        await loadTasks();
      }
    } catch (e) {
      _errorMessage = 'Failed to update task title: $e';
      debugPrint(_errorMessage);
      rethrow; // Let UI handle error display
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

  /// Phase 3.6B: Expand all tasks in the tree
  void expandAll() {
    for (final task in _tasks.where((t) => !t.completed)) {
      _treeController.expand(task);
    }
    notifyListeners();
  }

  /// Phase 3.6B: Collapse all tasks in the tree
  void collapseAll() {
    for (final task in _tasks.where((t) => !t.completed)) {
      _treeController.collapse(task);
    }
    notifyListeners();
  }

  /// Phase 3.6B: Check if all tasks are expanded
  bool get areAllExpanded {
    // Get all incomplete tasks that have children
    final tasksWithChildren = _tasks.where((task) {
      if (task.completed) return false;
      // Check if this task has any children
      return _tasks.any((child) => child.parentId == task.id);
    }).toList();

    if (tasksWithChildren.isEmpty) return false;

    // Check if all are expanded
    return tasksWithChildren.every((task) => _treeController.getExpansionState(task));
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
      // Phase 3.6A: Preserve filter state after drag/drop
      if (_filterState.isActive) {
        await _reapplyCurrentFilter();
      } else {
        await loadTasks();
      }
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
    bool needsDbQuery = false; // Track if we need to query actual sibling count

    // Determine drop location based on hover zone (30/40/30 split)
    // Uses extension from drag_and_drop_task_tile.dart
    details.mapDropPosition(
      whenAbove: () {
        // Insert as previous sibling of target
        newParentId = details.targetNode.parentId;

        // Phase 3.6A: In filtered views, we can't reliably calculate position
        // Use position 0 and let database reindexing handle it
        newPosition = 0;
        newDepth = details.targetNode.depth;
      },
      whenInside: () {
        // Insert as last child of target
        newParentId = details.targetNode.id;
        newDepth = details.targetNode.depth + 1;
        needsDbQuery = true; // Need to get actual child count

        // Auto-expand target to show new child
        _treeController.setExpansionState(details.targetNode, true);
      },
      whenBelow: () {
        // Insert as next sibling of target
        newParentId = details.targetNode.parentId;

        // Phase 3.6A: In filtered views, use position 0
        newPosition = 0;
        newDepth = details.targetNode.depth;
      },
    );

    // Phase 3.6A: If dropping "inside" and filters active, query actual sibling count
    if (needsDbQuery && _filterState.isActive) {
      final db = await DatabaseService.instance.database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM ${AppConstants.tasksTable}
        WHERE ${newParentId == null ? 'parent_id IS NULL' : 'parent_id = ?'}
          AND deleted_at IS NULL
      ''', newParentId == null ? [] : [newParentId]);
      newPosition = result.first['count'] as int;
    } else if (needsDbQuery) {
      // No filter - use in-memory count
      newPosition = _tasks.where((t) => t.parentId == newParentId).length;
    }

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

  // ============================================
  // PHASE 3.6A: TAG FILTERING METHODS
  // ============================================

  /// Reapply the current filter to refresh task list after drag/drop operations.
  ///
  /// This is like setFilter() but without the early return check, ensuring
  /// the filter is always reapplied even if the FilterState object is the same.
  Future<void> _reapplyCurrentFilter() async {
    if (!_filterState.isActive) {
      await loadTasks();
      return;
    }

    try {
      // Fetch filtered results
      final activeFuture = _taskService.getFilteredTasks(
        _filterState,
        completed: false,
      );
      final completedFuture = _taskService.getFilteredTasks(
        _filterState,
        completed: true,
      );

      final results = await Future.wait([activeFuture, completedFuture]);

      _tasks = results[0];

      // Load tags for filtered tasks
      final taskIds = _tasks.map((t) => t.id).toList();
      _taskTags = await _tagService.getTagsForAllTasks(taskIds);

      // Re-categorize tasks with new filtered list
      _categorizeTasks();

      // Refresh tree controller
      _refreshTreeController();

      notifyListeners();
    } catch (e) {
      debugPrint('Error reapplying filter: $e');
      // On error, try to reload all tasks
      await loadTasks();
    }
  }

  /// Apply a new filter to the task lists.
  ///
  /// Uses an operation ID pattern to prevent race conditions when the user
  /// changes filters rapidly. Only the most recent operation's results are applied.
  ///
  /// When filter is active: Loads filtered tasks from database
  /// When filter is cleared: Reloads all tasks with hierarchy
  ///
  /// H2 (v3.1): Rollback filter state on error to keep UI consistent
  Future<void> setFilter(FilterState filter) async {
    // Early return if filter unchanged (optimization)
    if (_filterState == filter) return;

    // H2: Capture previous state for rollback on error
    final previousFilter = _filterState;

    _filterState = filter;
    _filterOperationId++; // Increment before async work
    final currentOperation = _filterOperationId;

    notifyListeners(); // Show filter bar immediately (optimistic update)

    try {
      if (filter.isActive) {
        // Fetch filtered results (flat list, no hierarchy)
        final activeFuture = _taskService.getFilteredTasks(
          filter,
          completed: false,
        );
        final completedFuture = _taskService.getFilteredTasks(
          filter,
          completed: true,
        );

        // Await both queries in parallel
        final results = await Future.wait([activeFuture, completedFuture]);

        // Only apply results if no newer operation started
        if (currentOperation == _filterOperationId) {
          _tasks = results[0];

          // Load tags for filtered tasks
          final taskIds = _tasks.map((t) => t.id).toList();
          _taskTags = await _tagService.getTagsForAllTasks(taskIds);

          // Re-categorize tasks with new filtered list
          _categorizeTasks();

          // Refresh tree controller (filtered view is flat, not hierarchical)
          _refreshTreeController();

          notifyListeners();
        }
        // Else discard stale results (newer filter already applied)
      } else {
        // No filter active - reload all tasks with hierarchy
        await loadTasks();
      }
    } catch (e) {
      // H2: Rollback to previous filter state on error
      // Only rollback if no newer operation has started (fixes race condition)
      if (currentOperation == _filterOperationId) {
        _filterState = previousFilter;
        notifyListeners();
        debugPrint('Error applying filter: $e');
      } else {
        // Newer operation already running, don't touch state
        debugPrint('Error applying filter (operation $currentOperation), but newer operation ($_filterOperationId) is active: $e');
      }
    }
  }

  /// Add a tag to the current filter.
  ///
  /// Validates the tag ID and prevents duplicates.
  /// Used when user clicks a tag chip for quick filtering.
  ///
  /// M2 (v3.1): Validate tag existence using TagProvider (in-memory, faster than DB query)
  Future<void> addTagFilter(String tagId) async {
    // Validate input
    if (tagId.isEmpty) {
      debugPrint('addTagFilter: empty tagId');
      return;
    }

    if (_filterState.selectedTagIds.contains(tagId)) {
      debugPrint('addTagFilter: tag $tagId already in filter');
      return; // Already filtered by this tag
    }

    // M2: Validate tag exists (use TagProvider - faster, in-memory)
    final tagExists = _tagProvider.tags.any((tag) => tag.id == tagId);
    if (!tagExists) {
      debugPrint('addTagFilter: tag $tagId does not exist');
      return; // Reject invalid tag IDs (prevents SQL errors)
    }

    // Create new filter with added tag
    final newTags = List<String>.from(_filterState.selectedTagIds)..add(tagId);
    final newFilter = _filterState.copyWith(selectedTagIds: newTags);

    await setFilter(newFilter);
  }

  /// Remove a tag from the current filter.
  ///
  /// If no filters remain after removal, clears the filter entirely.
  Future<void> removeTagFilter(String tagId) async {
    final newTags = _filterState.selectedTagIds
        .where((id) => id != tagId)
        .toList();

    // If no filters left, clear entirely
    if (newTags.isEmpty && _filterState.presenceFilter == TagPresenceFilter.any) {
      await clearFilters();
    } else {
      final newFilter = _filterState.copyWith(selectedTagIds: newTags);
      await setFilter(newFilter);
    }
  }

  /// Clear all filters and show all tasks.
  ///
  /// Reloads tasks with full hierarchy.
  Future<void> clearFilters() async {
    await setFilter(FilterState.empty);
  }

  // ==========================================================================
  // Phase 3.6B: Search functionality
  // ==========================================================================

  /// Phase 3.6B: Search state persistence (session only)
  Map<String, dynamic>? _searchState;

  /// Phase 3.6B: GlobalKeys for task widgets (for scroll-to-task)
  final Map<String, GlobalKey> _taskKeys = {};

  /// Get or create a GlobalKey for a task (for scrolling)
  GlobalKey getKeyForTask(String taskId) {
    return _taskKeys.putIfAbsent(taskId, () => GlobalKey());
  }

  /// Save search state for next dialog open (cleared on app restart)
  void saveSearchState(Map<String, dynamic> state) {
    _searchState = state;
    // NO notifyListeners() - this is internal state
  }

  /// Get saved search state (returns null if not saved or app restarted)
  Map<String, dynamic>? getSearchState() {
    return _searchState;
  }

  /// Phase 3.6B: Navigate to task from search results
  ///
  /// This method:
  /// 1. Finds the task in the task list (clears filters if needed)
  /// 2. Expands all parent tasks to make it visible
  /// 3. Scrolls to the task using Scrollable.ensureVisible
  /// 4. Highlights it for 2 seconds
  Future<void> navigateToTask(String taskId) async {
    // Step 1: Find task (with filter clearing if needed)
    // FIX (Codex/Gemini): Task might be filtered out, clear filters to find it
    Task? task;
    try {
      task = _tasks.firstWhere((t) => t.id == taskId);
    } catch (e) {
      // Task not in current filtered list - clear filters and try again
      if (hasActiveFilters) {
        await clearFilters();
        try {
          task = _tasks.firstWhere((t) => t.id == taskId);
        } catch (e) {
          // Still not found after clearing filters - task might be deleted
          debugPrint('Task $taskId not found even after clearing filters');
          return;
        }
      } else {
        // No filters active but task still not found - task might be deleted
        debugPrint('Task $taskId not found in task list');
        return;
      }
    }

    // Step 2: Expand all ancestors to make task visible
    await _expandAncestors(task);

    // Step 3: Highlight temporarily (before scroll for visual feedback)
    _highlightTask(taskId, duration: Duration(seconds: 2));

    // Notify listeners to rebuild tree with expanded nodes
    notifyListeners();

    // Step 4: Scroll to task (with small delay to ensure tree rebuilds)
    // Wait for tree to rebuild with expanded nodes before scrolling
    await Future.delayed(Duration(milliseconds: 100));

    final taskKey = _taskKeys[taskId];
    if (taskKey != null && taskKey.currentContext != null) {
      try {
        await Scrollable.ensureVisible(
          taskKey.currentContext!,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3, // Position task 30% from top of viewport
        );
      } catch (e) {
        debugPrint('Failed to scroll to task: $e');
        // Fallback: Task is expanded and highlighted, user can manually scroll
      }
    }
  }

  /// Expand all ancestors of a task to make it visible in the tree
  Future<void> _expandAncestors(Task task) async {
    // Walk up the parent chain and expand each parent
    Task? current = task;
    while (current != null && current.parentId != null) {
      // Find parent task
      final parent = _findParent(current.parentId);
      if (parent == null) break;

      // Expand parent node using TreeController
      _treeController.expand(parent);

      current = parent;
    }
  }

  /// Highlight state for temporary task highlighting
  String? _highlightedTaskId;
  Timer? _highlightTimer;

  void _highlightTask(String taskId, {required Duration duration}) {
    _highlightedTaskId = taskId;
    notifyListeners();

    _highlightTimer?.cancel();
    _highlightTimer = Timer(duration, () {
      _highlightedTaskId = null;
      notifyListeners();
    });
  }

  bool isTaskHighlighted(String taskId) {
    return _highlightedTaskId == taskId;
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }
}
