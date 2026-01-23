import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

/// Phase 3.6.5: Result wrapper for parent selection
///
/// Distinguishes between:
/// - User selecting "No Parent" (null parent)
/// - User cancelling the dialog (no change)
///
/// v3 FIX (Codex #4): Prevents accidental parent clearing on cancel
class ParentSelectorResult {
  final bool wasCancelled;
  final String? selectedParentId;

  const ParentSelectorResult.cancelled()
      : wasCancelled = true,
        selectedParentId = null;

  const ParentSelectorResult.selected(this.selectedParentId)
      : wasCancelled = false;
}

/// Phase 3.6.5: Dialog for selecting a parent task
///
/// Features:
/// - Search/filter functionality
/// - Cycle detection (excludes current task and descendants)
/// - Shows completed tasks with strikethrough (v2 decision)
/// - Uses unfiltered task list for accurate hierarchy (v3 fix)
class ParentSelectorDialog extends StatefulWidget {
  final String currentTaskId;
  final String? currentParentId;

  const ParentSelectorDialog({
    super.key,
    required this.currentTaskId,
    this.currentParentId,
  });

  /// Show the parent selector dialog
  ///
  /// Returns ParentSelectorResult or null if cancelled via back button
  static Future<ParentSelectorResult?> show({
    required BuildContext context,
    required String currentTaskId,
    String? currentParentId,
  }) {
    return showDialog<ParentSelectorResult>(
      context: context,
      builder: (context) => ParentSelectorDialog(
        currentTaskId: currentTaskId,
        currentParentId: currentParentId,
      ),
    );
  }

  @override
  State<ParentSelectorDialog> createState() => _ParentSelectorDialogState();
}

class _ParentSelectorDialogState extends State<ParentSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<Task> _allTasks = [];
  List<Task> _selectableTasks = [];
  List<Task> _filteredTasks = [];
  Set<String> _descendantIds = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadTasks() {
    final taskProvider = context.read<TaskProvider>();

    // v3 FIX (Codex #3, #10): Use full unfiltered task list
    // This ensures cycle detection works even in filtered views
    _allTasks = taskProvider.tasks;

    // Build set of descendant IDs for cycle prevention
    _descendantIds = _getDescendantIds(widget.currentTaskId);

    // Filter out current task and its descendants
    _selectableTasks = _allTasks.where((task) {
      // Can't select self
      if (task.id == widget.currentTaskId) return false;
      // Can't select descendants (would create cycle)
      if (_descendantIds.contains(task.id)) return false;
      return true;
    }).toList();

    // Initial filter state
    _filteredTasks = _selectableTasks;
  }

  /// v3 FIX (Codex #2): Build complete set of descendants using map lookup
  Set<String> _getDescendantIds(String taskId) {
    final descendants = <String>{};

    void addDescendants(String parentId) {
      for (final task in _allTasks) {
        if (task.parentId == parentId && !descendants.contains(task.id)) {
          descendants.add(task.id);
          addDescendants(task.id); // Recurse for nested descendants
        }
      }
    }

    addDescendants(taskId);
    return descendants;
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = query.isEmpty
          ? _selectableTasks
          : _selectableTasks
              .where((t) => t.title.toLowerCase().contains(query))
              .toList();
    });
  }

  void _selectParent(String? parentId) {
    Navigator.pop(context, ParentSelectorResult.selected(parentId));
  }

  void _cancel() {
    // v3 FIX (Codex #4): Return explicit cancel result
    Navigator.pop(context, const ParentSelectorResult.cancelled());
  }

  String _getBreadcrumb(Task task) {
    final breadcrumb = <String>[];
    String? currentParentId = task.parentId;

    while (currentParentId != null) {
      final parent = _allTasks.where((t) => t.id == currentParentId).firstOrNull;
      if (parent == null) break;
      breadcrumb.insert(0, parent.title);
      currentParentId = parent.parentId;
    }

    if (breadcrumb.isEmpty) return '';
    return breadcrumb.join(' > ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Parent Task'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search tasks',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Task list
            Expanded(
              child: _filteredTasks.isEmpty && _searchController.text.isNotEmpty
                  ? Center(
                      child: Text(
                        'No matching tasks',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTasks.length + 1, // +1 for "No Parent"
                      itemBuilder: (context, index) {
                        // "No Parent" option at top
                        if (index == 0) {
                          final isCurrentSelection =
                              widget.currentParentId == null;
                          return ListTile(
                            leading: Icon(
                              Icons.home,
                              color: isCurrentSelection
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              'No Parent (Root Level)',
                              style: TextStyle(
                                fontWeight: isCurrentSelection
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isCurrentSelection
                                ? Icon(
                                    Icons.check,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            onTap: () => _selectParent(null),
                          );
                        }

                        final task = _filteredTasks[index - 1];
                        final isCurrentSelection =
                            task.id == widget.currentParentId;
                        final breadcrumb = _getBreadcrumb(task);

                        return ListTile(
                          leading: Icon(
                            task.completed ? Icons.task_alt : Icons.task,
                            color: task.completed
                                ? Colors.grey
                                : isCurrentSelection
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              // v2 Decision: Show completed tasks with strikethrough
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: task.completed
                                  ? Colors.grey
                                  : isCurrentSelection
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                              fontWeight: isCurrentSelection
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: breadcrumb.isNotEmpty
                              ? Text(
                                  breadcrumb,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: isCurrentSelection
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () => _selectParent(task.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
