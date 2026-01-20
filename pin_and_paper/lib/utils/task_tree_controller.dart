import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';

/// Custom TreeController that tracks expansion state by task ID
/// instead of object reference.
///
/// This is a defensive fix that decouples expansion state from object identity,
/// eliminating potential issues when Task objects are replaced during updates.
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

  /// Clear all expansion state (useful for reset scenarios)
  void clearExpansionState() {
    _toggledIds.clear();
  }
}
