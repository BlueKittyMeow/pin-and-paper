# Tree Drag-and-Drop Integration Plan

**Date:** 2025-10-30
**Status:** Proposed solution for Gemini's HIGH priority feedback
**Package:** `flutter_fancy_tree_view2`
**Issue:** Fix reorderTasks logic bug in TaskProvider

---

## Problem Statement

### Gemini's Feedback (HIGH - Logic)

**Location:** `group1.md`, TaskProvider section, `reorderTasks` method

**Issue:**
The current `reorderTasks` implementation operates on `visibleTasks` (a flattened list) and calls `_taskService.reorderTasks(visible)`. This is fundamentally broken because:

1. **Doesn't account for hierarchy:** Drag-and-drop in a flat `ReorderableListView` cannot represent changes in `parent_id` (nesting/un-nesting)
2. **Incorrect position updates:** Service method expects correct `parent_id` and `position`, but provider just reorders a flat list
3. **Will corrupt data:** As soon as user tries to reorder, it will flatten hierarchy or assign incorrect parent/position values

**Impact:**
Critical logic bug that makes reorder feature non-functional and potentially destructive. Will lead to data corruption.

---

## Solution: `flutter_fancy_tree_view2` Package

### Why This Package?

After analyzing the `flutter_fancy_tree_view2` source code (cloned to `analysis/flutter_tree_view2/`), we found it implements **exactly** the UX pattern we need:

**The Hover Zone Pattern:**
- Drag task over **top 30%** of target → Insert as sibling BEFORE target
- Drag task over **middle 40%** of target → Insert as CHILD of target ✨
- Drag task over **bottom 30%** of target → Insert as sibling AFTER target

**Built-In Features:**
- ✅ Visual feedback (borders showing drop location)
- ✅ Auto-scroll when dragging near edges
- ✅ Auto-expand collapsed nodes on hover (1 second delay)
- ✅ Prevents dropping node on itself
- ✅ Prevents collapsing ancestor of dragging node
- ✅ Works with hierarchical data structures

**Package Info:**
- **pub.dev:** https://pub.dev/packages/flutter_fancy_tree_view2
- **GitHub:** https://github.com/Alyssonpp/flutter_tree_view2
- **Status:** Actively maintained (unofficial continuation of flutter_tree_view)
- **License:** MIT
- **Version:** 2.0.0+3 (as of 2024)

---

## Integration Plan

### Phase 1: Add Dependency

**pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... existing dependencies
  flutter_fancy_tree_view2: ^2.0.0
```

---

### Phase 2: Adapt Task Model

Our `Task` model already has everything needed:

```dart
class Task {
  final String id;
  final String title;
  final String? parentId;  // ✅ For hierarchy
  final int position;      // ✅ For order within parent
  final int depth;         // ✅ For UI indentation
  // ... other fields
}
```

**Add helper methods to Task model:**

```dart
class Task {
  // ... existing fields ...

  // For flutter_fancy_tree_view2 compatibility
  String? get parentIdForTree => parentId; // Expose parent ID for tree
  int get index => position;
  // Note: isLeaf check will be done via TaskProvider.hasChildren()
}
```

---

### Phase 3: Update TaskProvider

Replace the broken `reorderTasks` with proper tree drag-and-drop handling:

```dart
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';

class TaskProvider with ChangeNotifier {
  // ... existing fields ...
  List<Task> _tasks = [];

  late TreeController<Task> treeController;

  // Initialize in constructor, NOT initState (ChangeNotifier is not a StatefulWidget)
  TaskProvider() {
    treeController = TreeController<Task>(
      roots: [],  // Start empty, will be populated in loadTasks
      childrenProvider: (Task task) => _tasks.where((t) => t.parentId == task.id),
      parentProvider: (Task task) => _findParent(task.parentId),
    );
  }

  Task? _findParent(String? parentId) {
    if (parentId == null) return null;
    try {
      return _tasks.firstWhere((t) => t.id == parentId);
    } catch (e) {
      return null;
    }
  }

  bool hasChildren(String taskId) {
    return _tasks.any((t) => t.parentId == taskId);
  }

  Future<void> loadTasks() async {
    _tasks = await _taskService.getAllTasksHierarchical();

    // ✅ CRITICAL: Refresh roots after loading tasks
    treeController.roots = _tasks.where((t) => t.parentId == null);
    treeController.rebuild();

    notifyListeners();
  }

  /// Handle drag-and-drop reordering with hierarchy support
  Future<void> onNodeAccepted(TreeDragAndDropDetails<Task> details) async {
    String? newParentId;
    int newPosition;
    int newDepth;

    // Use the hover zone pattern to determine drop location
    details.mapDropPosition(
      whenAbove: () {
        // Insert as previous sibling of target
        newParentId = details.targetNode.parentId;
        newPosition = details.targetNode.position;
        newDepth = details.targetNode.depth; // ✅ Use existing depth from target
      },
      whenInside: () {
        // Insert as last child of target
        newParentId = details.targetNode.id;
        final siblings = _tasks.where((t) => t.parentId == newParentId).toList();
        newPosition = siblings.length;
        newDepth = details.targetNode.depth + 1; // ✅ Parent's depth + 1

        // Auto-expand target to show new child
        treeController.setExpansionState(details.targetNode, true);
      },
      whenBelow: () {
        // Insert as next sibling of target
        newParentId = details.targetNode.parentId;
        newPosition = details.targetNode.position + 1;
        newDepth = details.targetNode.depth; // ✅ Use existing depth from target
      },
    );

    // Validate depth limit using calculated depth (no O(N) walk needed)
    if (newDepth >= 4) {
      // Show error: "Maximum nesting depth (4 levels) reached"
      _showDepthLimitError();
      return;
    }

    // Use existing changeTaskParent method (has cycle detection + sibling reindexing)
    await changeTaskParent(
      taskId: details.draggedNode.id,
      newParentId: newParentId,
      newPosition: newPosition,
    );

    // ✅ Optimistic update: Update in-memory state BEFORE reloading from DB
    final movedTaskIndex = _tasks.indexWhere((t) => t.id == details.draggedNode.id);
    if (movedTaskIndex != -1) {
      final movedTask = _tasks[movedTaskIndex];

      // Create updated task with new parent/position/depth
      final updatedTask = Task(
        id: movedTask.id,
        title: movedTask.title,
        completed: movedTask.completed,
        createdAt: movedTask.createdAt,
        completedAt: movedTask.completedAt,
        dueDate: movedTask.dueDate,
        isAllDay: movedTask.isAllDay,
        parentId: newParentId,
        position: newPosition,
        depth: newDepth,
      );

      // Replace in list
      _tasks[movedTaskIndex] = updatedTask;
    }

    // ✅ Refresh tree controller with updated in-memory state (no DB round-trip)
    treeController.roots = _tasks.where((t) => t.parentId == null);
    treeController.rebuild();

    notifyListeners();

    // Optional: Reload from DB in background to ensure consistency
    // This is a "trust but verify" approach - uncomment if needed
    // unawaited(loadTasks());
  }

  void _showDepthLimitError() {
    // Show snackbar: "Cannot move task: Maximum nesting depth (4 levels) reached"
  }

  @override
  void dispose() {
    treeController.dispose();
    super.dispose();
  }
}
```

**Key Points:**
- ✅ Reuses existing `changeTaskParent` method (cycle detection + sibling reindexing already implemented)
- ✅ Validates depth limit using existing depth field (no O(N) calculation)
- ✅ Optimistic UI updates (updates in-memory state, no DB round-trip per drag)
- ✅ Auto-expands target when making child
- ✅ Uses `mapDropPosition` helper for clean zone logic
- ✅ Refreshes treeController.roots after state changes

---

### Phase 4: Update HomeScreen Widget

Replace `ReorderableListView` with `TreeView`:

```dart
// BEFORE (broken):
if (taskProvider.isReorderMode) {
  return ReorderableListView.builder(
    itemCount: visibleTasks.length,
    onReorder: taskProvider.reorderTasks, // ❌ Broken logic
    itemBuilder: (context, index) => TaskItem(...),
  );
}

// AFTER (fixed):
return AnimatedTreeView<Task>(
  treeController: taskProvider.treeController,
  nodeBuilder: (context, TreeEntry<Task> entry) {
    return DragAndDropTaskTile(
      entry: entry,
      onNodeAccepted: taskProvider.onNodeAccepted,
      isReorderMode: taskProvider.isReorderMode,
      isCollapsed: taskProvider.collapsedTaskIds.contains(entry.node.id),
      onToggleCollapse: () => taskProvider.toggleCollapse(entry.node.id),
      taskProvider: taskProvider, // Pass provider for hasChildren check
    );
  },
);
```

---

### Phase 5: Create DragAndDropTaskTile Widget

Adapt the example from `flutter_tree_view2` to our Task model:

```dart
class DragAndDropTaskTile extends StatelessWidget {
  const DragAndDropTaskTile({
    super.key,
    required this.entry,
    required this.onNodeAccepted,
    required this.isReorderMode,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.taskProvider, // Need provider to check hasChildren
  });

  final TreeEntry<Task> entry;
  final TreeDragTargetNodeAccepted<Task> onNodeAccepted;
  final bool isReorderMode;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final TaskProvider taskProvider;

  @override
  Widget build(BuildContext context) {
    // Check if task has children via provider
    final hasChildren = taskProvider.hasChildren(entry.node.id);

    // Only enable drag-and-drop in reorder mode
    if (!isReorderMode) {
      return TaskItem(
        task: entry.node,
        depth: entry.node.depth,
        isReorderMode: false,
        hasChildren: hasChildren,
        isCollapsed: isCollapsed,
        onToggleCollapse: onToggleCollapse,
      );
    }

    return TreeDragTarget<Task>(
      node: entry.node,
      onNodeAccepted: onNodeAccepted,
      builder: (context, TreeDragAndDropDetails<Task>? details) {
        // Show visual feedback based on hover position
        Decoration? decoration;

        if (details != null) {
          final borderSide = BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2.0,
          );

          decoration = BoxDecoration(
            border: details.mapDropPosition(
              whenAbove: () => Border(top: borderSide),           // Line on top
              whenInside: () => Border.fromBorderSide(borderSide), // Box around
              whenBelow: () => Border(bottom: borderSide),         // Line on bottom
            ),
          );
        }

        return TreeDraggable<Task>(
          node: entry.node,
          collapseOnDragStart: true,  // Auto-collapse when dragging
          expandOnDragEnd: false,      // Don't auto-expand after drop

          // Show dimmed version when dragging
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: IgnorePointer(
              child: TaskItem(
                task: entry.node,
                depth: entry.node.depth,
                isReorderMode: true,
                hasChildren: hasChildren,
                isCollapsed: isCollapsed,
                onToggleCollapse: onToggleCollapse,
              ),
            ),
          ),

          // Show elevated version as drag feedback
          feedback: IntrinsicWidth(
            child: Material(
              elevation: 4,
              child: TaskItem(
                task: entry.node,
                depth: 0, // No indentation in feedback
                isReorderMode: true,
                hasChildren: hasChildren,
                isCollapsed: isCollapsed,
                onToggleCollapse: () {}, // No-op in feedback
              ),
            ),
          ),

          // Normal tile with optional decoration
          child: TaskItem(
            task: entry.node,
            depth: entry.node.depth,
            isReorderMode: true,
            hasChildren: hasChildren,
            isCollapsed: isCollapsed,
            onToggleCollapse: onToggleCollapse,
            decoration: decoration, // Add this parameter to TaskItem
          ),
        );
      },
    );
  }
}
```

---

### Phase 6: Update TaskItem Widget

Add decoration parameter for visual feedback:

```dart
class TaskItem extends StatelessWidget {
  const TaskItem({
    super.key,
    required this.task,
    required this.depth,
    required this.isReorderMode,
    required this.hasChildren,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.decoration, // ✅ NEW: For drag-and-drop visual feedback
  });

  final Task task;
  final int depth;
  final bool isReorderMode;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Decoration? decoration; // ✅ NEW

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: depth * 24.0),
      decoration: decoration, // ✅ Apply decoration for hover feedback
      child: ListTile(
        // ... existing ListTile content
      ),
    );
  }
}
```

---

## Hover Zone Logic Extension

Add this extension to make zone logic reusable:

```dart
extension TreeDragAndDropExtension on TreeDragAndDropDetails<Task> {
  /// Splits target height into zones: top 30%, middle 40%, bottom 30%
  T mapDropPosition<T>({
    required T Function() whenAbove,
    required T Function() whenInside,
    required T Function() whenBelow,
  }) {
    final double oneThirdOfTotalHeight = targetBounds.height * 0.3;
    final double pointerVerticalOffset = dropPosition.dy;

    if (pointerVerticalOffset < oneThirdOfTotalHeight) {
      return whenAbove();  // Top 30%: Insert as sibling before
    } else if (pointerVerticalOffset < oneThirdOfTotalHeight * 2) {
      return whenInside(); // Middle 40%: Insert as child
    } else {
      return whenBelow();  // Bottom 30%: Insert as sibling after
    }
  }
}
```

---

## Migration Steps

### 1. Remove Broken Code

**Delete from TaskProvider:**
```dart
// ❌ DELETE THIS:
Future<void> reorderTasks(int oldIndex, int newIndex) async {
  final visible = visibleTasks;

  if (oldIndex < newIndex) {
    newIndex -= 1;
  }

  final task = visible.removeAt(oldIndex);
  visible.insert(newIndex, task);

  await _taskService.reorderTasks(visible);
  await loadTasks();
}
```

**Delete from TaskService:**
```dart
// ❌ DELETE THIS (or mark as deprecated):
Future<void> reorderTasks(List<Task> tasks) async {
  final db = await _databaseService.database;

  await db.transaction((txn) async {
    for (int i = 0; i < tasks.length; i++) {
      await txn.update(
        AppConstants.tasksTable,
        {
          'parent_id': tasks[i].parentId,
          'position': i,
        },
        where: 'id = ?',
        whereArgs: [tasks[i].id],
      );
    }
  });
}
```

### 2. Keep Existing Good Code

**✅ KEEP `changeTaskParent`** - It already has:
- Cycle detection (`_wouldCreateCycle`)
- Sibling reindexing (`_reindexSiblings`)
- Depth validation
- Transaction safety

**✅ KEEP `updateTaskParent` in TaskService** - It's the correct implementation

---

## Testing Strategy

### Unit Tests

```dart
group('Tree Drag-and-Drop', () {
  test('Drop above: task becomes previous sibling', () async {
    // Initial: A, A1, B
    // Drag B to top 30% of A1
    // Result: A, B (sibling), A1
  });

  test('Drop inside: task becomes child', () async {
    // Initial: A, B (both root)
    // Drag B to middle 40% of A
    // Result: A (with child B), root list has only A
  });

  test('Drop below: task becomes next sibling', () async {
    // Initial: A, A1, B
    // Drag B to bottom 30% of A
    // Result: A, B (sibling), A1
  });

  test('Rejects drop if exceeds max depth', () async {
    // Create 3-level hierarchy: A -> A1 -> A1a
    // Try to drag B to middle of A1a (would be depth 4)
    // Should show error and not move
  });

  test('Prevents dropping node on itself', () async {
    // Drag A to A
    // Should reject (TreeDragTarget handles this)
  });

  test('Prevents creating cycles', () async {
    // Hierarchy: A -> A1
    // Try to drag A to middle of A1 (A becomes child of its own child)
    // Should reject via changeTaskParent cycle detection
  });
});
```

### Widget Tests

```dart
testWidgets('Shows border on top when hovering top zone', (tester) async {
  // Build tree with tasks
  // Simulate drag to top 30% of target
  // Verify Border(top: ...) is rendered
});

testWidgets('Shows border around when hovering middle zone', (tester) async {
  // Simulate drag to middle 40% of target
  // Verify Border.fromBorderSide(...) is rendered
});

testWidgets('Auto-expands target when dropping inside', (tester) async {
  // Collapse task A
  // Drag B to middle of A
  // Verify A expands after drop
});
```

### Integration Tests

```dart
testWidgets('End-to-end: Reorder tasks with drag-and-drop', (tester) async {
  // Create hierarchy: A, B, C (all root)
  // Enter reorder mode
  // Drag C to middle of A
  // Verify database: A has child C
  // Verify UI: C is indented under A
  // Exit reorder mode
  // Verify hierarchy persists
});
```

---

## Performance Considerations

### TreeController Efficiency

The `TreeController` uses:
- **Lazy rendering:** Only renders visible nodes (not collapsed children)
- **Efficient rebuild:** Only rebuilds changed portions
- **ParentProvider optimization:** Fast ancestor lookups for cycle detection

### Database Optimization

Our existing `changeTaskParent` already:
- ✅ Uses transactions (atomic updates)
- ✅ Reindexes only affected siblings (not entire tree)
- ✅ Single query per move operation

### UI Optimization

- Auto-scrolling is debounced (doesn't spam scroll updates)
- Hover feedback is lightweight (just decoration changes)
- No unnecessary rebuilds (TreeController handles this)

---

## Benefits Summary

### Fixes Gemini's HIGH Priority Bug
- ✅ Replaces broken flat-list reordering
- ✅ Properly handles hierarchical structure
- ✅ Prevents data corruption

### Better UX
- ✅ Clear visual feedback (borders show where drop will happen)
- ✅ Intuitive hover zones (top/middle/bottom)
- ✅ Auto-scroll when dragging near edges
- ✅ Auto-expand targets when making children

### Architectural Improvements
- ✅ Reuses existing `changeTaskParent` logic (cycle detection, sibling reindexing)
- ✅ Single source of truth for hierarchy manipulation
- ✅ Clean separation of concerns (drag UI vs. business logic)

### Future-Proof
- ✅ Ready for Claude API task reorganization
- ✅ Works with any depth limit (currently 4 levels)
- ✅ Extensible for future features (multi-select drag, etc.)

---

## Risks & Mitigations

### Risk 1: New Dependency
**Concern:** Adding external package increases app size and maintenance burden
**Mitigation:**
- Package is actively maintained
- Lightweight (no heavy dependencies)
- Can fork if needed (MIT license)

### Risk 2: Learning Curve
**Concern:** Team needs to learn new widget API
**Mitigation:**
- API is similar to standard Draggable/DragTarget
- Excellent example code in package repo
- We've already analyzed the source code

### Risk 3: Migration Complexity
**Concern:** Replacing ReorderableListView might break existing behavior
**Mitigation:**
- Keep reorder mode as opt-in toggle
- Extensive testing before release
- Can implement in parallel and switch via feature flag

---

## Timeline Estimate

**Total: 2-3 days**

| Task | Time | Notes |
|------|------|-------|
| Add dependency & initial setup | 0.5 days | pubspec.yaml, basic TreeController |
| Update TaskProvider | 1 day | Replace reorderTasks, add onNodeAccepted |
| Create DragAndDropTaskTile | 0.5 days | Adapt from example code |
| Update HomeScreen | 0.5 days | Replace ReorderableListView |
| Testing | 1 day | Unit, widget, integration tests |
| Polish & edge cases | 0.5 days | Error messages, visual refinement |

---

## Open Questions

1. **Should we keep ReorderableListView as fallback?**
   - Pro: Safer migration
   - Con: More code to maintain

2. **Zone percentages - are 30/40/30 optimal?**
   - Could make configurable: 25/50/25, 20/60/20, etc.

3. **Auto-expand behavior - expand immediately or on timer?**
   - Current: 1 second delay (from package default)
   - Could make instant for faster UX

4. **Should we show "ghost" preview of where task will land?**
   - Package supports this via `feedback` widget
   - Could show indented preview

---

## Next Steps

1. **Get approval** from BlueKitty, Gemini, Codex
2. **Create feature branch:** `feature/tree-drag-drop`
3. **Update group1.md** with this plan
4. **Begin implementation** following migration steps
5. **Test thoroughly** before merging

---

## References

- **Package:** https://pub.dev/packages/flutter_fancy_tree_view2
- **Source Code:** `analysis/flutter_tree_view2/`
- **Example:** `analysis/flutter_tree_view2/example/lib/src/examples/drag_and_drop.dart`
- **Gemini's Feedback:** `docs/phase-03/group1-secondary-feedback.md`

---

**Status:** Awaiting team approval
**Created By:** BlueKitty + Claude
**Last Updated:** 2025-10-30
