# External Review Prompts for TaskTreeController Design

## For OpenAI Codex (o3)

### Prompt:

```
I need you to review a proposed fix for a TreeController expansion state corruption bug in a Flutter app. The bug causes bizarre behavior where clicking one task's expand button expands a different task, and the "Expand All" button stops working.

**Files to Review:**

1. Root cause analysis: `docs/phase-3.6.5/treecontroller-corruption-analysis.md`
2. Proposed solution design: `docs/phase-3.6.5/custom-treecontroller-design.md`

**Context:**
- Flutter app using `flutter_fancy_tree_view2` package for hierarchical task display
- Tasks are updated in-memory by replacing objects: `_tasks[index] = updatedTask`
- Task model has ID-based equality (`==` returns true if IDs match)
- TreeController uses `Set<Task> toggledNodes` to track expansion state
- Problem: Set accumulates stale Task object references causing lookup corruption

**Proposed Solution:**
Create a `TaskTreeController` subclass that overrides `getExpansionState()` and `setExpansionState()` to track expansion by task ID (`Set<String>`) instead of object reference (`Set<Task>`).

**Please Review:**
1. **Root cause accuracy**: Is our analysis of the bug correct? Are there other factors we might be missing?
2. **Solution correctness**: Will overriding these two methods actually fix the problem? Are there edge cases we haven't considered?
3. **Dart Set behavior**: Is our understanding of how Dart Sets handle objects with custom equality correct? Could there be other issues?
4. **AnimatedTreeView compatibility**: Will the custom controller work correctly with animations?
5. **Alternative approaches**: Are there better solutions we haven't considered?
6. **Testing strategy**: What test cases would you recommend to verify the fix?
7. **Code review**: Any issues with the proposed `TaskTreeController` implementation?

Please be thorough and critical - we want to catch any issues before implementation.
```

---

## For Google Gemini (2.5 Pro)

### Prompt:

```
I need a thorough review of a proposed fix for a complex TreeController bug in a Flutter task management app. Please read both documents carefully and provide detailed feedback.

**Files to Analyze:**

1. `docs/phase-3.6.5/treecontroller-corruption-analysis.md` - Bug analysis
2. `docs/phase-3.6.5/custom-treecontroller-design.md` - Proposed solution

**The Bug:**
The `flutter_fancy_tree_view2` TreeController's expansion state becomes corrupted over time:
- Expand All button stops working
- Clicking one task's expand arrow causes a DIFFERENT task to expand
- Parent shows expanded icon but children aren't visible

**Our Root Cause Theory:**
Task objects are replaced during updates (`_tasks[index] = newTask`). The TreeController's `toggledNodes` Set, which stores `Task` objects, accumulates both old and new Task objects with the same ID. Despite our Task model having ID-based equality, the Set's internal behavior causes lookup corruption.

**Proposed Fix:**
Subclass `TreeController<Task>` to create `TaskTreeController` that overrides:
- `getExpansionState(Task node)` → looks up by `node.id` in `Set<String>`
- `setExpansionState(Task node, bool expanded)` → stores `node.id` in `Set<String>`

**Review Focus Areas:**

1. **Dart Set Semantics**:
   - How does Dart's HashSet handle objects where `==` and `hashCode` are consistent (same ID = same hash, same equality)?
   - Could there be a scenario where the Set contains "duplicate" objects by ID?
   - Is this a known Dart issue or are we misunderstanding something?

2. **flutter_fancy_tree_view2 Internals**:
   - Are there other places in the package that store Task object references that could cause similar issues?
   - Does the package use `toggledNodes` anywhere else besides `getExpansionState` and `setExpansionState`?

3. **AnimatedTreeView Compatibility**:
   - The package's `_SliverAnimatedTreeState` tracks expansion state changes for animations
   - Will our custom controller work correctly with the animation system?
   - Are there any timing issues we should be aware of?

4. **Edge Cases**:
   - Task deleted while expanded
   - Task moved (parent changed) while expanded
   - Rapid expand/collapse operations
   - Filter applied with expanded tasks
   - Concurrent operations (multiple completions in quick succession)

5. **Alternative Solutions**:
   - Would clearing `toggledNodes` before each rebuild be sufficient?
   - Should we store expansion state in the Task model itself?
   - Is there a way to configure the base TreeController differently?

6. **Implementation Concerns**:
   - Is the XOR pattern (`^ defaultExpansionState`) correctly implemented?
   - Should we handle the `defaultExpansionState=true` case?
   - Any memory leak concerns with orphaned IDs in `_toggledIds`?

7. **Testing Recommendations**:
   - What specific test scenarios would catch regressions?
   - How can we reproduce the original bug in a test?

Please provide a detailed analysis. We want to be confident this fix is correct before implementing.
```

---

## Additional Context Files (Optional)

If Codex or Gemini need more context, these files may be helpful:

- `lib/providers/task_provider.dart` - Main provider with TreeController usage
- `lib/models/task.dart` - Task model with equality implementation
- `lib/widgets/task_item.dart` - UI widget using TreeController
- `lib/screens/home_screen.dart` - Screen with AnimatedTreeView

## Expected Output

Both reviewers should provide:
1. Confirmation or correction of root cause analysis
2. Validation or concerns about proposed solution
3. Edge cases to test
4. Any alternative approaches worth considering
5. Specific code review feedback on TaskTreeController implementation
