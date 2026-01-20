import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';

/// Custom TreeController that tracks expansion state by task ID
/// instead of object reference, fixing the corruption bug.
///
/// The root cause of the expansion state corruption was that when tasks
/// are updated, we replace task objects with new instances. The base
/// TreeController uses Set-based tracking with object references, which
/// causes stale references when tasks are replaced.
///
/// This controller solves the problem by:
/// 1. Tracking expansion state by task.id (String) instead of Task object
/// 2. Overriding getExpansionState() to check the ID set
/// 3. Overriding setExpansionState() to add/remove IDs
///
/// All TreeController methods (toggleExpansion, expandAll, etc.) go through
/// these overrides, so the ID-based tracking works for all operations.
class TaskTreeController extends TreeController<Task> {
  /// Internal storage: expansion state by task ID
  /// When defaultExpansionState=false: contains IDs of EXPANDED tasks
  final Set<String> _toggledIds = {};

  TaskTreeController({
    required super.roots,
    required super.childrenProvider,
    super.parentProvider,
    super.defaultExpansionState,
  });

  @override
  bool getExpansionState(Task node) {
    return _toggledIds.contains(node.id) ^ defaultExpansionState;
  }

  @override
  void setExpansionState(Task node, bool expanded) {
    expanded ^ defaultExpansionState
        ? _toggledIds.add(node.id)
        : _toggledIds.remove(node.id);
  }

  /// Remove IDs that are no longer in the valid set (memory hygiene).
  ///
  /// This prevents the _toggledIds set from growing indefinitely with
  /// deleted task IDs. Recommended by both Codex and Gemini reviewers.
  ///
  /// Call this periodically during tree rebuilds to keep memory usage
  /// bounded.
  void pruneOrphanedIds(Set<String> validIds) {
    _toggledIds.removeWhere((id) => !validIds.contains(id));
  }

  /// Clear all expansion state (useful for reset scenarios)
  void clearExpansionState() {
    _toggledIds.clear();
  }
}
