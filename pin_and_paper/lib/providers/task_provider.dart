import 'dart:async'; // Phase 3.6B: For Timer (highlight functionality)
import 'dart:math'; // Phase 3.6.5: For max() in depth calculation
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Phase 3.6B: For GlobalKey, Scrollable, Curves (scroll-to-task)
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/filter_state.dart'; // Phase 3.6A
import '../models/task.dart';
import '../models/task_sort_mode.dart'; // Phase 3.7.5
import '../models/tag.dart'; // Phase 3.5
import '../models/task_suggestion.dart'; // Phase 2
import '../providers/tag_provider.dart'; // Phase 3.6A
import '../providers/task_sort_provider.dart'; // Phase 3.9 Refactor
import '../providers/task_filter_provider.dart'; // Phase 3.9 Refactor
import '../services/task_service.dart';
import '../services/tag_service.dart'; // Phase 3.5
import '../services/database_service.dart'; // Phase 3.6A: For database access
import '../services/date_parsing_service.dart'; // Phase 3.7: For Today Window
import '../services/preferences_service.dart'; // Phase 2 Stretch
import '../services/reminder_service.dart'; // Phase 3.8: Notification scheduling
import '../models/task_reminder.dart'; // Phase 3.8: For custom reminder types
import '../utils/constants.dart'; // Phase 3.6A: For AppConstants table names
import '../utils/task_tree_controller.dart'; // Phase 3.6.5: Custom TreeController fix
import '../widgets/drag_and_drop_task_tile.dart'; // Phase 3.2: For mapDropPosition extension
import '../providers/task_hierarchy_provider.dart'; // Phase 3.9: Hierarchy management

/// Phase 3.6.5: Cached incomplete descendant info for completed parents
///
/// Stores computed information about incomplete descendants for O(1) lookup.
/// Computed once per loadTasks() / toggleTaskCompletion(), not per-widget.
class IncompleteDescendantInfo {
  /// Direct children that are incomplete
  final int immediateCount;

  /// All descendants that are incomplete (including grandchildren+)
  final int totalCount;

  /// Depth of deepest incomplete descendant: 1 = immediate only, 2+ = has grandchildren+
  final int maxDepth;

  const IncompleteDescendantInfo({
    required this.immediateCount,
    required this.totalCount,
    required this.maxDepth,
  });

  /// True if any descendants are incomplete
  bool get hasIncomplete => totalCount > 0;

  /// True if incomplete descendants exist at depth > 1 (grandchildren or deeper)
  bool get hasDeepIncomplete => maxDepth > 1;

  /// Returns display string: "> 3 incomplete" or ">> 5 incomplete"
  String get displayText {
    final prefix = maxDepth > 1 ? '>>' : '>';
    final noun = totalCount == 1 ? 'incomplete' : 'incomplete';
    return '$prefix $totalCount $noun';
  }
}

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService;
  final PreferencesService _preferencesService;
  final TagService _tagService; // Phase 3.5
  final TagProvider _tagProvider; // Phase 3.6A
  final TaskSortProvider _sortProvider; // Phase 3.9 Refactor
  final TaskFilterProvider _filterProvider; // Phase 3.9 Refactor
  final TaskHierarchyProvider _hierarchyProvider; // Phase 3.9: Hierarchy management
  final ReminderService _reminderService = ReminderService(); // Phase 3.8

  TaskProvider({
    TaskService? taskService,
    PreferencesService? preferencesService,
    TagService? tagService, // Phase 3.5
    TagProvider? tagProvider, // Phase 3.6A
    required TaskSortProvider sortProvider, // Phase 3.9 Refactor: Required dependency
    required TaskFilterProvider filterProvider, // Phase 3.9 Refactor: Required dependency
    required TaskHierarchyProvider hierarchyProvider, // Phase 3.9: Required dependency
  })  : _taskService = taskService ?? TaskService(),
        _preferencesService = preferencesService ?? PreferencesService(),
        _tagService = tagService ?? TagService(), // Phase 3.5
        _tagProvider = tagProvider ?? TagProvider(), // Phase 3.6A
        _sortProvider = sortProvider, // Phase 3.9 Refactor: No fallback needed
        _filterProvider = filterProvider, // Phase 3.9 Refactor: No fallback needed
        _hierarchyProvider = hierarchyProvider { // Phase 3.9: No fallback needed

    // Phase 3.9 Refactor: Listen to sort provider changes and refresh tree
    _sortProvider.addListener(_onSortChanged);

    // Phase 3.9 Refactor: Listen to filter provider changes and apply filters
    _filterProvider.addListener(_onFilterChanged);
  }

  /// Phase 3.9 Refactor: Callback when sort provider changes
  void _onSortChanged() {
    _refreshTreeController();
    notifyListeners();
  }

  /// Phase 3.9 Refactor: Callback when filter provider changes
  Future<void> _onFilterChanged() async {
    final filter = _filterProvider.filterState;
    final operationId = _filterProvider.filterOperationId;
    // Capture previous filter for true rollback on error (Codex MEDIUM finding #2)
    final previousFilter = _previousFilterState;

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
        if (operationId == _filterProvider.filterOperationId) {
          _tasks = results[0];

          // Load tags for filtered tasks
          final taskIds = _tasks.map((t) => t.id).toList();
          _taskTags = await _tagService.getTagsForAllTasks(taskIds);

          // Re-categorize tasks with new filtered list
          _categorizeTasks();

          // Rebuild incomplete descendant cache
          _rebuildIncompleteDescendantCache();

          // Refresh tree controller (filtered view is flat, not hierarchical)
          _refreshTreeController();

          // Success! Update previous filter for next rollback
          _previousFilterState = filter;

          notifyListeners();
        }
        // Else discard stale results (newer filter already applied)
      } else {
        // No filter active - reload all tasks with hierarchy
        // Phase 3.9: Check operation ID to prevent race condition
        // (Codex MEDIUM finding #1: clear-filter can flash unfiltered results)
        if (operationId == _filterProvider.filterOperationId) {
          await loadTasks();
          // Success! Update previous filter
          _previousFilterState = filter;
        }
        // Else: newer operation already started, this clear is stale, skip
      }
    } catch (e) {
      debugPrint('Error applying filter: $e');
      // True rollback: restore previous filter state (Codex MEDIUM finding #2)
      _filterProvider.rollbackFilter(previousFilter, operationId);
      // Try to reload all tasks (if DB is available)
      try {
        await loadTasks();
      } catch (loadError) {
        debugPrint('Failed to load tasks: $loadError');
      }
    }
  }

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Phase 3.9 Refactor: Track previous filter for true rollback on error (Codex MEDIUM finding)
  FilterState _previousFilterState = FilterState.empty;

  // Phase 3.5: Tag storage (loaded with tasks)
  Map<String, List<Tag>> _taskTags = {};

  // Phase 3.5 Fix #C3: Cache completed child map for O(1) hasCompletedChildren lookup
  // Updated by completedTasksWithHierarchy, used by hasCompletedChildren (Codex review fix)
  Map<String, List<Task>> _lastCompletedChildMap = {};

  // Phase 3.5: Codex review - reentrant guard for loadTasks()
  Future<void>? _loadTasksFuture;

  // Phase 3.6.5: Guard against concurrent toggleTaskCompletion calls (race condition fix)
  bool _isTogglingCompletion = false;

  // Phase 2 Stretch: Hide completed tasks settings
  bool _hideOldCompleted = true;
  int _hideThresholdHours = 24;

  // Phase 2 Stretch: Pre-categorized lists (calculated once per load, not on every build)
  List<Task> _activeTasks = [];
  List<Task> _recentlyCompletedTasks = [];
  List<Task> _oldCompletedTasks = [];

  // Phase 3.6.5: Cached incomplete descendant info for completed parents
  // Computed once per loadTasks()/toggleTaskCompletion(), not per-widget O(1) lookup
  Map<String, IncompleteDescendantInfo> _incompleteDescendantCache = {};

  // Getters
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Phase 3.9: Hierarchy getters delegate to TaskHierarchyProvider
  bool get isReorderMode => _hierarchyProvider.isReorderMode;
  TreeController<Task> get treeController => _hierarchyProvider.treeController;
  int get treeVersion => _hierarchyProvider.treeVersion;
  bool get areAllExpanded => _hierarchyProvider.areAllExpanded;

  // Phase 3.7.5 / Phase 3.9 Refactor: Sort getters now delegate to TaskSortProvider
  TaskSortMode get sortMode => _sortProvider.sortMode;
  bool get sortReversed => _sortProvider.sortReversed;

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

  // Phase 3.6A / Phase 3.9 Refactor: Filter state getters now delegate to TaskFilterProvider
  FilterState get filterState => _filterProvider.filterState;
  bool get hasActiveFilters => _filterProvider.hasActiveFilters;

  // Phase 3.6.5: Get incomplete descendant info for a completed task
  /// Returns cached info for O(1) lookup, or null if task has no incomplete descendants
  IncompleteDescendantInfo? getIncompleteDescendantInfo(String taskId) {
    return _incompleteDescendantCache[taskId];
  }

  /// Phase 3.6.5: Check if task is a completed parent with incomplete descendants
  bool isCompletedParentWithIncomplete(String taskId) {
    return _incompleteDescendantCache[taskId]?.hasIncomplete ?? false;
  }

  // Phase 3.2: Helper to find parent task by ID
  Task? _findParent(String? parentId) {
    if (parentId == null) return null;
    try {
      return _tasks.firstWhere((t) => t.id == parentId);
    } catch (e) {
      return null;
    }
  }

  /// Phase 3.6.5: Public method to get task by ID
  /// Used by EditTaskDialog and other widgets
  Task? getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
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
  // Phase 3.9 Refactor: Delegates to TaskHierarchyProvider
  void _refreshTreeController() {
    // Phase 3.6A: Build task ID set for efficient lookup
    final taskIds = _tasks.map((t) => t.id).toSet();

    // Build active task list: tasks to show in tree view
    var activeTasks = _tasks.where((t) {
      // Phase 3.6A: In filtered views, include task if it should be shown
      if (!t.completed) return true; // Incomplete tasks always active
      return _hasIncompleteDescendants(t); // Completed with incomplete children
    }).toList();

    // Phase 3.7.5: Apply date filter
    if (_filterProvider.filterState.dateFilter != DateFilter.any) {
      activeTasks = activeTasks.where((t) {
        switch (_filterProvider.filterState.dateFilter) {
          case DateFilter.overdue:
            if (t.dueDate == null) return false;
            if (t.isAllDay) {
              final effectiveToday = DateParsingService().getCurrentEffectiveToday();
              final todayOnly = DateTime(effectiveToday.year, effectiveToday.month, effectiveToday.day);
              final dateOnly = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
              return dateOnly.isBefore(todayOnly);
            }
            return t.dueDate!.isBefore(DateTime.now());
          case DateFilter.noDueDate:
            return t.dueDate == null;
          case DateFilter.any:
            return true;
        }
      }).toList();
    }

    // Phase 3.7.5: Apply sort to tasks
    _sortTasks(activeTasks);

    // Phase 3.9 Refactor: Delegate tree refresh to TaskHierarchyProvider
    // HierarchyProvider will build roots and manage expansion state
    _hierarchyProvider.refreshTreeController(activeTasks);
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
    var completed = _tasks.where((t) {
      if (!t.completed) return false;
      if (_hasIncompleteDescendants(t)) return false;
      return true;
    }).toList();

    // Apply hide-old-completed filter (matches visibleCompletedTasks logic)
    if (_hideOldCompleted) {
      completed = completed.where((t) {
        if (t.completedAt == null) return false;
        final hoursSinceCompletion = DateTime.now().difference(t.completedAt!).inHours;
        return hoursSinceCompletion < _hideThresholdHours;
      }).toList();
    }

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

  /// Phase 3.6.5: Rebuild the incomplete descendant cache
  ///
  /// Called after loadTasks() and after any task completion changes.
  /// Uses the full task list (not filtered) for accurate detection.
  void _rebuildIncompleteDescendantCache() {
    _incompleteDescendantCache.clear();

    // Build parent-to-children map for efficient traversal
    final childrenMap = <String, List<Task>>{};
    for (final task in _tasks) {
      if (task.parentId != null && task.deletedAt == null) {
        childrenMap.putIfAbsent(task.parentId!, () => []).add(task);
      }
    }

    // For each completed task, compute its incomplete descendants
    for (final task in _tasks) {
      if (task.completed && task.deletedAt == null) {
        final info = _computeIncompleteDescendants(task.id, childrenMap);
        if (info.hasIncomplete) {
          _incompleteDescendantCache[task.id] = info;
        }
      }
    }
  }

  /// Recursive helper to compute incomplete descendants
  ///
  /// Returns info about all incomplete descendants of a task.
  /// Uses depth tracking to distinguish immediate vs deep descendants.
  IncompleteDescendantInfo _computeIncompleteDescendants(
    String taskId,
    Map<String, List<Task>> childrenMap,
  ) {
    final children = childrenMap[taskId] ?? [];

    int immediateCount = 0;
    int totalCount = 0;
    int maxDepth = 0;

    for (final child in children) {
      // Count immediate incomplete children
      if (!child.completed) {
        immediateCount++;
        totalCount++;
        maxDepth = max(maxDepth, 1);
      }

      // Recurse into grandchildren regardless of child completion status
      // (a completed child might have incomplete grandchildren)
      final childInfo = _computeIncompleteDescendants(child.id, childrenMap);
      totalCount += childInfo.totalCount;
      if (childInfo.maxDepth > 0) {
        maxDepth = max(maxDepth, childInfo.maxDepth + 1);
      }
    }

    return IncompleteDescendantInfo(
      immediateCount: immediateCount,
      totalCount: totalCount,
      maxDepth: maxDepth,
    );
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

      // Phase 3.6.5: Rebuild incomplete descendant cache for completed parent indicator
      _rebuildIncompleteDescendantCache();

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
  // Phase 3.9 Refactor: Sort preferences now loaded by TaskSortProvider
  Future<void> loadPreferences() async {
    _hideOldCompleted = await _preferencesService.getHideOldCompleted();
    _hideThresholdHours = await _preferencesService.getHideThresholdHours();
    _refreshTreeController(); // Apply current sort from sortProvider
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
  Future<void> createTask(
    String title, {
    DateTime? dueDate,
    bool isAllDay = true,
  }) async {
    if (title.trim().isEmpty) return;

    _errorMessage = null;

    try {
      final newTask = await _taskService.createTask(
        title,
        dueDate: dueDate,
        isAllDay: isAllDay,
      );
      _tasks.insert(0, newTask); // Add to beginning of list
      _categorizeTasks(); // Keep derived task buckets in sync for UI

      // Phase 3.8: Schedule notifications if task has due date and notifications enabled
      if (newTask.dueDate != null && newTask.notificationType != 'none') {
        try {
          await _reminderService.scheduleReminders(newTask);
        } catch (e) {
          debugPrint('[TaskProvider] Failed to schedule reminders: $e');
        }
      }

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

      // Phase 3.8: Schedule notifications for tasks with due dates
      for (final task in newTasks) {
        if (task.dueDate != null && task.notificationType != 'none') {
          try {
            await _reminderService.scheduleReminders(task);
          } catch (e) {
            debugPrint('[TaskProvider] Failed to schedule reminders for bulk task: $e');
          }
        }
      }

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
  // Phase 3.6.5 Fix: Auto-expand task when uncompleting to show children
  // Phase 3.6.5 Fix: Added guard to prevent concurrent calls (race condition)
  Future<void> toggleTaskCompletion(Task task) async {
    // Guard against concurrent calls - prevents race conditions causing brief empty state
    if (_isTogglingCompletion) {
      debugPrint('[toggleTaskCompletion] Skipping concurrent call for task ${task.id}');
      return;
    }
    _isTogglingCompletion = true;
    _errorMessage = null;

    try {
      final wasCompleted = task.completed;
      final updatedTask = await _taskService.toggleTaskCompletion(task);

      // Phase 3.8: Update notifications based on completion state
      try {
        if (!wasCompleted && updatedTask.completed) {
          // Task completed - cancel all reminders
          await _reminderService.cancelReminders(task.id);
        } else if (wasCompleted && !updatedTask.completed) {
          // Task uncompleted - reschedule if applicable
          if (updatedTask.dueDate != null &&
              updatedTask.notificationType != 'none') {
            await _reminderService.scheduleReminders(updatedTask);
          }
        }
      } catch (e) {
        debugPrint('[TaskProvider] Failed to update reminders on toggle: $e');
      }

      // Update in local list
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        // Phase 3.6.5 Fix: Preserve depth metadata
        // uncompleteTask loads from DB without CTE, so depth=0
        // Always preserve original depth since it's computed, not stored
        _tasks[index] = updatedTask.copyWith(depth: task.depth);
        _categorizeTasks();  // Phase 2 Stretch: Re-categorize after toggle

        // Phase 3.6.5: Rebuild incomplete descendant cache for completed parent indicator
        _rebuildIncompleteDescendantCache();

        // Phase 3.6.5 Fix: Set expansion state BEFORE refreshing tree
        // This ensures the tree is built with correct expansion state from the start
        if (wasCompleted && !updatedTask.completed) {
          // Task was uncompleted - expand it if it has children
          final hasChildren = _tasks.any((t) => t.parentId == updatedTask.id);
          if (hasChildren) {
            _hierarchyProvider.expandTask(updatedTask);
          }
        }

        if (!wasCompleted && updatedTask.completed && updatedTask.parentId != null) {
          // Task was completed - expand its parent so child stays visible
          try {
            final parent = _tasks.firstWhere((t) => t.id == updatedTask.parentId);
            _hierarchyProvider.expandTask(parent);
          } catch (_) {
            // Parent not found, skip
          }
        }

        // Phase 3.2: Refresh TreeController to update visibility
        // Now the expansion state is already set correctly
        _refreshTreeController();

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update task: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    } finally {
      _isTogglingCompletion = false;
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

  /// Phase 3.6.5: Comprehensive task update
  ///
  /// Updates multiple task fields at once:
  /// - title (required)
  /// - dueDate
  /// - notes
  /// - tags (via tagIds)
  ///
  /// NOTE: Parent changes are handled separately via changeTaskParent()
  /// to maintain proper hierarchy validation and position handling.
  ///
  /// Uses in-memory update pattern to:
  /// - Avoid full database reload
  /// - Preserve TreeController expansion state
  Future<void> updateTask({
    required String taskId,
    required String title,
    DateTime? dueDate,
    bool isAllDay = true,
    String? notes,
    required List<String> tagIds,
    String? notificationType,    // Phase 3.8
    List<String>? reminderTypes, // Phase 3.8: custom reminder types
    bool? notifyIfOverdue,       // Phase 3.8: per-task overdue toggle
  }) async {
    _errorMessage = null;

    if (title.trim().isEmpty) {
      throw ArgumentError('Task title cannot be empty');
    }

    try {
      // 1. Update task in database via service
      final updatedTask = await _taskService.updateTask(
        taskId,
        title: title.trim(),
        dueDate: dueDate,
        isAllDay: isAllDay,
        notes: notes,
        notificationType: notificationType,
      );

      // 2. Update tags
      final currentTags = _taskTags[taskId] ?? [];
      final currentTagIds = currentTags.map((t) => t.id).toSet();
      final newTagIds = tagIds.toSet();

      // Add new tags
      for (final tagId in newTagIds.difference(currentTagIds)) {
        await _tagProvider.addTagToTask(taskId, tagId);
      }
      // Remove removed tags
      for (final tagId in currentTagIds.difference(newTagIds)) {
        await _tagProvider.removeTagFromTask(taskId, tagId);
      }

      // 3. Update in-memory task list
      final index = _tasks.indexWhere((task) => task.id == taskId);
      if (index != -1) {
        // Preserve depth metadata from original task
        final originalDepth = _tasks[index].depth;
        _tasks[index] = updatedTask.copyWith(depth: originalDepth);

        // Re-categorize to keep derived lists synchronized
        _categorizeTasks();

        // Refresh TreeController to update UI without collapsing
        _refreshTreeController();
      }

      // 4. Phase 3.8: Handle custom reminders and reschedule
      try {
        // Cancel old notifications FIRST (reads old DB reminders for IDs)
        await _reminderService.cancelReminders(taskId);

        // Persist custom reminder types if applicable
        if (notificationType == 'custom' && reminderTypes != null) {
          final reminders = reminderTypes.map((type) => TaskReminder(
            taskId: taskId,
            reminderType: type,
          )).toList();
          if (notifyIfOverdue == true) {
            reminders.add(TaskReminder(
              taskId: taskId,
              reminderType: ReminderType.overdue,
            ));
          }
          await _reminderService.setReminders(taskId, reminders);
        } else if (notificationType != null && notificationType != 'custom') {
          // Switching away from custom - clear custom reminders
          await _reminderService.deleteReminders(taskId);
        }

        // Schedule new notifications based on updated task
        if (updatedTask.dueDate != null &&
            updatedTask.notificationType != 'none') {
          await _reminderService.scheduleReminders(updatedTask);
        }
      } catch (e) {
        debugPrint('[TaskProvider] Failed to update reminders: $e');
      }

      // 5. Refresh tags cache
      await refreshTags();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update task: $e';
      debugPrint(_errorMessage);
      rethrow;
    }
  }

  // ========== Phase 3.7.5 / Phase 3.9 Refactor: Sort Methods ==========
  // setSortMode and toggleSortReversed removed - now handled by TaskSortProvider

  /// Sort a list of tasks in-place based on current sort mode
  /// Phase 3.9 Refactor: Now uses TaskSortProvider's state instead of local fields
  void _sortTasks(List<Task> tasks) {
    switch (_sortProvider.sortMode) {
      case TaskSortMode.manual:
        tasks.sort((a, b) {
          final cmp = a.position.compareTo(b.position);
          return _sortProvider.sortReversed ? -cmp : cmp;
        });

      case TaskSortMode.recentlyCreated:
        tasks.sort((a, b) {
          final cmp = b.createdAt.compareTo(a.createdAt);
          return _sortProvider.sortReversed ? -cmp : cmp;
        });

      case TaskSortMode.dueSoonest:
        tasks.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) {
            return a.position.compareTo(b.position);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          final cmp = a.dueDate!.compareTo(b.dueDate!);
          return _sortProvider.sortReversed ? -cmp : cmp;
        });
    }
  }

  // ========== Phase 3.2: Hierarchy Methods ==========

  /// Enter/exit reorder mode
  /// Phase 3.9 Refactor: Now uses TaskSortProvider to change sort mode
  void setReorderMode(bool enabled) {
    _hierarchyProvider.setReorderMode(enabled);
    if (enabled && _sortProvider.sortMode != TaskSortMode.manual) {
      _sortProvider.setSortMode(TaskSortMode.manual);
      // Note: sortProvider will notify listeners which triggers _onSortChanged
      // which calls _refreshTreeController and notifyListeners
    } else {
      notifyListeners();
    }
  }

  /// Toggle collapse/expand for a task node
  void toggleCollapse(Task task) {
    _hierarchyProvider.toggleCollapse(task);
  }

  /// Phase 3.6B: Expand all tasks in the tree
  /// Phase 3.6.5 Fix: Expand ALL tasks with children (not just incomplete)
  /// This ensures completed children become visible when parent is expanded
  /// Phase 3.9 Refactor: Delegate to TaskHierarchyProvider
  void expandAll() {
    _hierarchyProvider.expandAll();
    notifyListeners();
  }

  /// Phase 3.9 Refactor: Delegate to TaskHierarchyProvider
  void collapseAll() {
    _hierarchyProvider.collapseAll();
    notifyListeners();
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
      // Phase 3.6A / Phase 3.9 Refactor: Preserve filter state after drag/drop
      if (_filterProvider.hasActiveFilters) {
        await _onFilterChanged();
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
        // Insert as previous sibling of target (take target's position)
        newParentId = details.targetNode.parentId;
        newPosition = details.targetNode.position; // Insert at target's position
        newDepth = details.targetNode.depth;
      },
      whenInside: () {
        // Insert as last child of target
        newParentId = details.targetNode.id;
        newDepth = details.targetNode.depth + 1;
        needsDbQuery = true; // Need to get actual child count

        // Auto-expand target to show new child
        _hierarchyProvider.expandTask(details.targetNode);
      },
      whenBelow: () {
        // Insert as next sibling of target (position after target)
        newParentId = details.targetNode.parentId;
        newPosition = details.targetNode.position + 1; // Insert after target
        newDepth = details.targetNode.depth;
      },
    );

    // Phase 3.6A / Phase 3.9 Refactor: If dropping "inside" and filters active, query actual sibling count
    if (needsDbQuery && _filterProvider.hasActiveFilters) {
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

      // Phase 3.8: Cancel reminders for task and all descendants before delete
      try {
        final idsToCancel = <String>[taskId];
        // Collect all descendant IDs (breadth-first)
        for (var i = 0; i < idsToCancel.length; i++) {
          final parentId = idsToCancel[i];
          for (final t in _tasks) {
            if (t.parentId == parentId && !idsToCancel.contains(t.id)) {
              idsToCancel.add(t.id);
            }
          }
        }
        for (final id in idsToCancel) {
          await _reminderService.cancelReminders(id);
        }
      } catch (e) {
        debugPrint('[TaskProvider] Failed to cancel reminders on delete: $e');
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

      // Phase 3.8: Reschedule reminders for restored task if applicable
      try {
        final restoredTask = await _taskService.getTaskById(taskId);
        if (restoredTask != null &&
            restoredTask.dueDate != null &&
            restoredTask.dueDate!.isAfter(DateTime.now()) &&
            restoredTask.notificationType != 'none') {
          await _reminderService.scheduleReminders(restoredTask);
        }
      } catch (e) {
        debugPrint('[TaskProvider] Failed to reschedule on restore: $e');
      }

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
  // PHASE 3.6A / Phase 3.9 Refactor: TAG FILTERING METHODS
  // ============================================
  // Filter methods moved to TaskFilterProvider
  // TaskProvider listens to filterProvider changes via _onFilterChanged()

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
        _filterProvider.clearFilters();
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

      // Expand parent node
      _hierarchyProvider.expandTask(parent);

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
    _sortProvider.removeListener(_onSortChanged); // Phase 3.9 Refactor
    _filterProvider.removeListener(_onFilterChanged); // Phase 3.9 Refactor
    super.dispose();
  }
}
