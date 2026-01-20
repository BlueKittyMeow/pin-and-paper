# Custom TaskTreeController Design

## Executive Summary

Replace the standard `TreeController<Task>` with a custom `TaskTreeController` that tracks expansion state by **task ID** instead of **object reference**. This is a defensive fix that decouples expansion state from object identity.

## Background

### The Problem

The `flutter_fancy_tree_view2` package's TreeController uses a `Set<T> toggledNodes` to track expanded nodes. After multiple task modifications (completions, edits, etc.), expansion state becomes corrupted:

1. Expand All button not working
2. Wrong task expanding when clicking one task
3. Visual state mismatch (expanded icon but no children visible)

### Root Cause (Corrected per Codex Review)

**What we know:**
- Task objects are replaced during updates: `_tasks[index] = updatedTask`
- The bug manifests after multiple task modifications
- All TreeController code paths go through `getExpansionState()`/`setExpansionState()`

**Clarification:** Dart's `HashSet` with stable `==`/`hashCode` (ID-based) should NOT accumulate duplicate objects. The exact mechanism causing corruption is unclear. Possible factors include Flutter rebuild cycle interactions, widget caching, or race conditions.

### Why ID-Based Solution Is Correct

Even without knowing the exact mechanism:
1. **Decouples state from object identity** - eliminates an entire class of potential issues
2. **Simpler mental model** - expansion state tied to task ID, not object lifecycle
3. **Defensive programming** - robust against unknown edge cases
4. **Both reviewers (Codex & Gemini) approve** this approach

## Solution: TaskTreeController

### Design Principles

1. **Minimal Change**: Subclass TreeController, override only 2 methods
2. **Drop-in Replacement**: No changes needed to any calling code
3. **ID-Based State**: Store expansion by `String` ID, not `Task` object
4. **No Automatic Pruning**: IDs persist even when tasks are deleted (memory impact negligible)

### Implementation

```dart
// File: lib/utils/task_tree_controller.dart

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
```

### Why No Automatic Pruning?

**Issue**: `_tasks` in TaskProvider can be filtered when filters are active. If we pruned based on filtered task IDs, we'd lose expansion state for hidden tasks.

**Decision**: Don't prune automatically. The memory impact is negligible (UUIDs are ~36 bytes each; even 10,000 deleted tasks = 360KB). Orphaned IDs are harmless - they simply don't match any visible task.

### Integration Changes

**File: `lib/providers/task_provider.dart`**

1. Add import:
```dart
import '../utils/task_tree_controller.dart';
```

2. Change type declaration:
```dart
late TaskTreeController _treeController;
```

3. Change initialization:
```dart
_treeController = TaskTreeController(
  roots: [],
  childrenProvider: (Task task) => _tasks.where((t) => t.parentId == task.id),
  parentProvider: (Task task) => _findParent(task.parentId),
);
```

4. **Simplify `_refreshTreeController()`** - remove the capture/restore dance:
```dart
void _refreshTreeController() {
    // Expansion state now stored by ID - no capture/restore needed!
    final taskIds = _tasks.map((t) => t.id).toSet();

    final activeRoots = _tasks.where((t) {
      if (t.parentId != null && taskIds.contains(t.parentId)) return false;
      if (!t.completed) return true;
      return _hasIncompleteDescendants(t);
    });

    _treeController.roots = activeRoots;
    _treeController.rebuild();
    // Done! Expansion state preserved automatically by ID
}
```

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Task object replaced | ID same → expansion state preserved |
| Task deleted | ID stays in `_toggledIds` (harmless) |
| New task created | Not in `_toggledIds` → defaults to collapsed |
| Task moved (parent change) | Same ID → expansion state preserved |
| Filter applied | Hidden task IDs preserved → state restored when filter cleared |

## Package Source Verification ✅

All TreeController code paths go through the overridable methods:
- `toggleExpansion()` → calls `setExpansionState()` ✅
- `expandAll()`/`collapseAll()` → calls `setExpansionState()` ✅
- `AnimatedTreeView` → uses `getExpansionState()` ✅
- `toggledNodes` only accessed in getter/setter/dispose ✅

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `lib/utils/task_tree_controller.dart` | CREATE | Custom TreeController implementation |
| `lib/providers/task_provider.dart` | MODIFY | Use TaskTreeController, simplify refresh |
| `test/utils/task_tree_controller_test.dart` | CREATE | Unit tests for custom controller |

## Verification Checklist

- [ ] Build completes without errors
- [ ] Expand All button works
- [ ] Collapse All button works
- [ ] Individual expand/collapse works correctly
- [ ] Completing a child task: child stays visible under parent AND appears in completed section
- [ ] Uncompleting a task: expansion state preserved
- [ ] Clicking one task's arrow only affects THAT task
- [ ] Filter applied → cleared: expansion state preserved
- [ ] Rapid operations don't cause corruption
