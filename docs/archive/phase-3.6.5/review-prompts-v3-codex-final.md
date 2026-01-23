# Final Review for Codex (v3)

We've addressed all your feedback. Please provide final go/no-go.

## Files Updated

1. `docs/phase-3.6.5/treecontroller-corruption-analysis.md` - Root cause corrected
2. `docs/phase-3.6.5/custom-treecontroller-design.md` - Pruning removed, root cause corrected
3. `docs/phase-3.6.5/IMPLEMENTATION_PLAN_TreeController_Fix.md` - Final implementation plan

## Changes Made Based on Your Feedback

### 1. Root Cause Documentation Corrected

**Before (incorrect):**
> "Dart's Set implementation uses object identity for some operations... the Set accumulates BOTH old and new Task objects with the same ID, violating the Set's uniqueness invariant"

**After (corrected):**
```markdown
### What We Don't Know (Corrected per Codex Review)

**Important clarification**: Dart's `HashSet` with stable `==`/`hashCode` (ID-based)
should NOT accumulate duplicate objects. If two Task objects have the same ID,
`set.add(taskA)` followed by `set.add(taskB)` should result in `size = 1`.

The exact mechanism causing corruption is unclear. Possible factors:
- Subtle interactions with Flutter's rebuild cycle
- Widget element caching and reuse
- TreeController internal state management
- Race conditions during rapid operations
```

The solution is now framed as a **defensive fix** that decouples expansion state from object identity, rather than a direct fix for a proven cause.

### 2. Pruning Removed

**Your concern:** `_tasks` can be filtered; pruning with filtered IDs would lose expansion state for hidden tasks.

**Our fix:** Removed `pruneOrphanedIds()` entirely. Orphaned IDs stay in `_toggledIds` (harmless).

**Memory impact analysis:** UUIDs are ~36 bytes. Even 10,000 deleted tasks = 360KB. Acceptable.

**New edge case documented:**
| Scenario | Behavior |
|----------|----------|
| Filter applied | Hidden task IDs preserved → state restored when filter cleared |

### 3. Implementation Simplified

Final `TaskTreeController`:

```dart
class TaskTreeController extends TreeController<Task> {
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

  void clearExpansionState() {
    _toggledIds.clear();
  }
}
```

## Answers to Your Open Questions

1. **Is `_tasks` always the complete unfiltered list?**
   - NO, it can be filtered. That's why we removed pruning.

2. **Do you ever set `defaultExpansionState=true`?**
   - NO, we always use the default (false). Tests won't cover that case.

## Checklist

- [x] Root cause docs corrected to match Dart/verified package behavior
- [x] Pruning removed (no potential state loss under filtering)
- [x] Implementation simplified
- [x] All three docs are now consistent

## Request

Please confirm: **GO** or **NO-GO**?
