# TreeController Expansion State Corruption Analysis

## Problem Summary

The TreeController exhibits bizarre behavior after task modifications:
1. **Expand All button doesn't work** - clicking has no visible effect
2. **Wrong task expands** - clicking one task's expand arrow causes a different task to expand
3. **Visual state mismatch** - Parent shows expanded icon (▼) but children aren't visible
4. **Unpredictable completed children** - appear/disappear from completed section randomly

## Root Cause Analysis

### What We Know

The `flutter_fancy_tree_view2` package's TreeController uses a `Set<Task>` called `toggledNodes` to track expansion:

```dart
final Set<T> toggledNodes = {};
```

Our Task model uses ID-based equality:

```dart
@override
bool operator ==(Object other) => other is Task && other.id == id;

@override
int get hashCode => id.hashCode;
```

### What We Observed

1. Task objects are replaced during updates: `_tasks[index] = updatedTask`
2. After multiple task modifications, expansion state becomes corrupted
3. The bug manifests unpredictably after task completions/updates

### What We Don't Know (Corrected per Codex Review)

**Important clarification**: Dart's `HashSet` with stable `==`/`hashCode` (ID-based) should NOT accumulate duplicate objects. If two Task objects have the same ID, `set.add(taskA)` followed by `set.add(taskB)` should result in `size = 1`.

The exact mechanism causing corruption is unclear. Possible factors:
- Subtle interactions with Flutter's rebuild cycle
- Widget element caching and reuse
- TreeController internal state management
- Race conditions during rapid operations

### Why ID-Based Solution Is Still Correct

Even without knowing the exact mechanism, tracking expansion by **String ID** instead of **Task object** is the correct architectural approach because:

1. **Decouples state from object identity** - eliminates an entire class of potential issues
2. **Simpler mental model** - expansion state is tied to task ID, not object lifecycle
3. **Defensive programming** - robust against unknown edge cases
4. **Both external reviewers (Codex & Gemini) approve** this approach

## Solution: Custom TaskTreeController

Create a `TaskTreeController` subclass that overrides `getExpansionState()` and `setExpansionState()` to track by String ID:

```dart
class TaskTreeController extends TreeController<Task> {
  final Set<String> _toggledIds = {};

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
}
```

### Package Source Verification

All TreeController code paths go through the overridable methods:
- `toggleExpansion()` → calls `setExpansionState()` ✅
- `expandAll()`/`collapseAll()` → calls `setExpansionState()` ✅
- `AnimatedTreeView` → uses `getExpansionState()` ✅
- `toggledNodes` only accessed in getter/setter/dispose ✅

See: [IMPLEMENTATION_PLAN_TreeController_Fix.md](./IMPLEMENTATION_PLAN_TreeController_Fix.md) for full implementation details.

## Testing Verification

1. Build and run the app
2. Test Expand All button
3. Test individual expand/collapse
4. Test task completion (child and parent)
5. Test uncomplete operations
6. Verify no cross-task expansion corruption
