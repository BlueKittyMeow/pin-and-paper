# Implementation Plan: TaskTreeController Fix

## Status: APPROVED (Gemini GO, Codex Conditional GO - conditions addressed)

## Problem Summary

The TreeController exhibits bizarre behavior:
1. Expand All button doesn't work
2. Clicking one task expands a different task
3. Parent shows expanded (▼) but children aren't visible

## Root Cause (Corrected per Codex Review)

**What we know:**
- Task objects are replaced during updates: `_tasks[index] = updatedTask`
- The bug manifests after multiple task modifications

**Clarification:** Dart's `HashSet` with stable `==`/`hashCode` should NOT accumulate duplicates. The exact corruption mechanism is unclear. Possible factors: Flutter rebuild cycles, widget caching, race conditions.

**Why ID-based solution is still correct:**
- Decouples expansion state from object identity
- Defensive fix that eliminates a class of potential issues
- Both reviewers approve this approach

## Solution: Custom TaskTreeController

### File 1: `lib/utils/task_tree_controller.dart` (NEW)

```dart
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

### File 2: `lib/providers/task_provider.dart` (MODIFY)

**Changes:**

1. Add import:
```dart
import '../utils/task_tree_controller.dart';
```

2. Change type declaration (~line 98):
```dart
// Before
late TreeController<Task> _treeController;

// After
late TaskTreeController _treeController;
```

3. Change initialization (~line 68):
```dart
// Before
_treeController = TreeController<Task>(
  roots: [],
  childrenProvider: (Task task) => _tasks.where((t) => t.parentId == task.id),
  parentProvider: (Task task) => _findParent(task.parentId),
);

// After
_treeController = TaskTreeController(
  roots: [],
  childrenProvider: (Task task) => _tasks.where((t) => t.parentId == task.id),
  parentProvider: (Task task) => _findParent(task.parentId),
);
```

4. Simplify `_refreshTreeController()` (~line 247):
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

### Why No Automatic Pruning?

**Issue:** `_tasks` can be filtered when filters are active. Pruning with filtered IDs would lose expansion state for hidden tasks.

**Decision:** Don't prune automatically. Memory impact is negligible (UUIDs ~36 bytes; 10K deleted tasks = 360KB). Orphaned IDs are harmless.

### File 3: `test/utils/task_tree_controller_test.dart` (NEW)

Key test cases:
- State persists when Task object is replaced (same ID, new instance)
- `clearExpansionState` works
- Inherited methods (`toggleExpansion`, `expandAll`, `collapseAll`) work through overrides
- Filter applied → cleared: expansion state preserved

## Package Source Verification ✅

| Code Path | Verified |
|-----------|----------|
| `toggleExpansion()` → `setExpansionState()` | ✅ Yes |
| `expandAll()`/`collapseAll()` → `setExpansionState()` | ✅ Yes |
| `toggledNodes` only in getter/setter/dispose | ✅ Yes |
| AnimatedTreeView uses `getExpansionState()` | ✅ Yes |

## External Review Summary

| Reviewer | Verdict | Addressed |
|----------|---------|-----------|
| **Gemini** | ✅ GO | N/A |
| **Codex** | ⚠️ Conditional GO | ✅ Root cause docs corrected, ✅ Pruning issue resolved |

## Implementation Steps

1. Create `lib/utils/task_tree_controller.dart`
2. Update imports in `task_provider.dart`
3. Change `_treeController` type and initialization
4. Simplify `_refreshTreeController()` (remove capture/restore)
5. Create unit tests
6. Build and manual verification

## Verification

1. **Build**: `cd pin_and_paper && flutter build linux`
2. **Run tests**: `flutter test`
3. **Manual testing**:
   - Test Expand All button - all parents respond
   - Test individual expand - only THAT task toggles
   - Test completion - child visible under parent AND in completed section
   - Test uncomplete - expansion state preserved
   - Test filter → clear filter - expansion state preserved
   - Rapid operations - no corruption under stress
