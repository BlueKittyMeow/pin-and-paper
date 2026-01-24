import 'package:flutter/foundation.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';
import '../utils/task_tree_controller.dart';

/// Provider for managing task hierarchy and tree UI state
///
/// Phase 3.9 Refactor: Extracted from TaskProvider to reduce file size
/// and improve separation of concerns.
///
/// Responsibilities:
/// - Manage tree controller for hierarchical task display
/// - Handle expand/collapse state for tree nodes
/// - Track reorder mode for drag-and-drop
/// - Maintain tree version for UI rebuild triggers
///
/// TaskProvider calls refreshTreeController() whenever the task list changes.
class TaskHierarchyProvider extends ChangeNotifier {
  TaskHierarchyProvider() {
    // Initialize TreeController for hierarchical view
    // Phase 3.6.5: Use TaskTreeController for ID-based expansion state (fixes corruption bug)
    _treeController = TaskTreeController(
      roots: [],
      childrenProvider: (Task task) {
        // Return children from current task list
        return _tasks.where((t) => t.parentId == task.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
      },
      parentProvider: (Task task) => _findParent(task.parentId),
    );
  }

  late TaskTreeController _treeController;
  bool _isReorderMode = false;
  int _treeVersion = 0;

  // Store task list reference for childrenProvider and parentProvider closures
  List<Task> _tasks = [];

  // Getters
  TreeController<Task> get treeController => _treeController;
  bool get isReorderMode => _isReorderMode;
  int get treeVersion => _treeVersion;

  /// Find parent task by ID
  Task? _findParent(String? parentId) {
    if (parentId == null || parentId.isEmpty) return null;
    try {
      return _tasks.firstWhere((t) => t.id == parentId);
    } catch (e) {
      return null; // Parent not found (shouldn't happen, but defensive)
    }
  }

  /// Check if all tasks in the tree are expanded
  bool get areAllExpanded {
    for (final task in _treeController.roots) {
      if (!_isTaskAndDescendantsExpanded(task)) {
        return false;
      }
    }
    return true;
  }

  /// Recursively check if a task and all its descendants are expanded
  bool _isTaskAndDescendantsExpanded(Task task) {
    final children = _treeController.childrenProvider(task);
    if (children.isNotEmpty) {
      if (!_treeController.getExpansionState(task)) {
        return false;
      }
      for (final child in children) {
        if (!_isTaskAndDescendantsExpanded(child)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Refresh TreeController with new task list
  ///
  /// Called by TaskProvider whenever the task list changes.
  /// Rebuilds the tree structure while preserving expansion state.
  ///
  /// Parameters:
  /// - `activeTasks`: List of active (non-completed) tasks to display in tree
  void refreshTreeController(List<Task> activeTasks) {
    // Update task list reference for closures
    _tasks = activeTasks;

    // Build active task roots (top-level tasks with no parent)
    final activeRoots = activeTasks
        .where((t) => t.parentId == null || t.parentId!.isEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    // Get set of all task IDs for pruning orphaned expansion states
    final taskIds = activeTasks.map((t) => t.id).toSet();

    // Prune orphaned IDs from expansion state (deleted tasks)
    _treeController.pruneOrphanedIds(taskIds);

    // Update TreeController with new roots
    _treeController.roots = activeRoots;
    _treeController.rebuild();

    // Increment version to force AnimatedTreeView rebuild
    _treeVersion++;
    // Expansion state preserved automatically by TaskTreeController (ID-based)
  }

  /// Toggle expansion state for a task
  void toggleCollapse(Task task) {
    _treeController.toggleExpansion(task);
    notifyListeners();
  }

  /// Expand all tasks in the tree
  void expandAll() {
    for (final task in _treeController.roots) {
      _expandRecursively(task);
    }
    _treeController.rebuild(); // Notify AnimatedTreeView to update
    notifyListeners();
  }

  void _expandRecursively(Task task) {
    _treeController.setExpansionState(task, true);
    for (final child in _treeController.childrenProvider(task)) {
      _expandRecursively(child);
    }
  }

  /// Collapse all tasks in the tree
  void collapseAll() {
    for (final task in _treeController.roots) {
      _collapseRecursively(task);
    }
    _treeController.rebuild(); // Notify AnimatedTreeView to update
    notifyListeners();
  }

  void _collapseRecursively(Task task) {
    _treeController.setExpansionState(task, false);
    for (final child in _treeController.childrenProvider(task)) {
      _collapseRecursively(child);
    }
  }

  /// Set reorder mode (enables drag-and-drop)
  void setReorderMode(bool enabled) {
    _isReorderMode = enabled;
    notifyListeners();
  }

  /// Expand a specific task (used when adding subtasks, completing tasks, etc.)
  void expandTask(Task task) {
    _treeController.setExpansionState(task, true);
    _treeController.rebuild();
    notifyListeners();
  }

  /// Get expansion state for a task
  bool isExpanded(Task task) {
    return _treeController.getExpansionState(task);
  }

  /// Check if a task has children in the tree
  bool hasChildren(Task task) {
    return _treeController.childrenProvider(task).isNotEmpty;
  }
}
