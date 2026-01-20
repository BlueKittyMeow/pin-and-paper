# External Review Prompts v2 - Final Validation

We've completed package source verification and incorporated your initial feedback. This is a final review before implementation.

---

## For OpenAI Codex (o3)

### Prompt:

```
This is a follow-up review request. We incorporated your feedback and verified the package source code. Please review our updated findings and implementation plan.

**Files to Review:**

1. `docs/phase-3.6.5/treecontroller-corruption-analysis.md` - Root cause analysis
2. `docs/phase-3.6.5/custom-treecontroller-design.md` - Comprehensive design document
3. Plan file at `.claude/plans/lazy-dazzling-bumblebee.md` - Final implementation plan

**What Changed Since Your Last Review:**

1. **Package Source Verification**: We examined the flutter_fancy_tree_view2 v1.6.2 source code and confirmed:
   - `toggleExpansion()` → calls `setExpansionState()` ✅
   - `expandAll()`/`collapseAll()` → calls `setExpansionState()` via cascade ✅
   - `toggledNodes` is ONLY accessed inside `getExpansionState()`, `setExpansionState()`, and `dispose()` ✅
   - AnimatedTreeView's `_SliverAnimatedTreeState` uses `entry.isExpanded` from `depthFirstTraversal()` which calls `getExpansionState()` ✅
   - All internal Maps (like `_expansionStates`) are recreated fresh on each rebuild ✅

2. **Added `pruneOrphanedIds()`**: Based on your and Gemini's recommendation, we added a method to clean up deleted task IDs:
   ```dart
   void pruneOrphanedIds(Set<String> validIds) {
     _toggledIds.removeWhere((id) => !validIds.contains(id));
   }
   ```

3. **Simplified `_refreshTreeController()`**: No more capture/restore dance - just prune and rebuild.

**Questions for This Review:**

1. Does the package source verification address your concern about direct `toggledNodes` access?

2. Your previous review suggested the root cause might be something else (e.g., "stale expansion state being applied to different nodes due to list/tree rebuild/element reuse"). Given that we verified all Maps are transient and recreated on rebuild, does the ID-based solution still make sense as a defensive fix?

3. Any remaining concerns about the implementation?

4. The test strategy you recommended:
   - Minimal reproducer: replace task instance with new instance (same ID), verify state persists
   - Expand All / Collapse All after multiple edits and rebuilds
   - Rapid expand/collapse while updating tasks
   - Filter + rebuild + expand/collapse

   Anything else you'd add?

Please provide a final go/no-go recommendation.
```

---

## For Google Gemini (2.5 Pro)

### Prompt:

```
This is a follow-up review. We verified the package source code as you recommended and incorporated your pruneOrphanedIds suggestion. Please provide final validation.

**Files to Review:**

1. `docs/phase-3.6.5/treecontroller-corruption-analysis.md` - Root cause analysis
2. `docs/phase-3.6.5/custom-treecontroller-design.md` - Comprehensive design document
3. Plan file at `.claude/plans/lazy-dazzling-bumblebee.md` - Final implementation plan

**Package Source Verification Results:**

We examined `~/.pub-cache/hosted/pub.dev/flutter_fancy_tree_view2-1.6.2/` and confirmed:

| Code Path | Verified |
|-----------|----------|
| `toggleExpansion()` → `setExpansionState()` | ✅ Yes |
| `expandAll()` → `expandCascading()` → `_expand()` → `setExpansionState()` | ✅ Yes |
| `collapseAll()` → `collapseCascading()` → `_collapse()` → `setExpansionState()` | ✅ Yes |
| `depthFirstTraversal()` creates `TreeEntry` with `isExpanded: getExpansionState(node)` | ✅ Yes |
| `AnimatedTreeView` uses `entry.isExpanded`, never accesses `toggledNodes` directly | ✅ Yes |
| `toggledNodes` is `late final Set<T>` (immutable reference) | ✅ Yes |
| `toggledNodes` only accessed in: getter, setter, dispose() | ✅ Yes |

**All internal Maps are transient:**
- `Map<T, TreeSearchMatch> allMatches` - created fresh each `search()` call
- `Map<T, bool> _expansionStatesCache` - recreated on each `_updateFlatTree()` call
- No persistent caches that could hold stale Task references

**Implementation Updates Based on Your Feedback:**

1. Added `pruneOrphanedIds()` as you recommended:
   ```dart
   void pruneOrphanedIds(Set<String> validIds) {
     _toggledIds.removeWhere((id) => !validIds.contains(id));
   }
   ```

2. Updated `_refreshTreeController()` to call pruning:
   ```dart
   void _refreshTreeController() {
       final taskIds = _tasks.map((t) => t.id).toSet();
       _treeController.pruneOrphanedIds(taskIds);  // Memory hygiene

       final activeRoots = _tasks.where((t) { ... });
       _treeController.roots = activeRoots;
       _treeController.rebuild();
   }
   ```

**Questions for Final Validation:**

1. Does the package source verification give you confidence the override strategy is safe?

2. Is the `pruneOrphanedIds()` implementation correct? Should it be called:
   - Before setting roots (current plan)?
   - After rebuild?
   - Both?

3. We didn't implement support for `defaultExpansionState=true` (threw `UnimplementedError`). You mentioned this was fine since our app doesn't use it. Should we remove those methods entirely, or keep the defensive errors?

4. Any edge cases we haven't considered?

5. Final go/no-go recommendation?

Thank you for your thorough initial review. Looking forward to your final validation.
```

---

## Summary of All Documentation

| Document | Path | Purpose |
|----------|------|---------|
| Root Cause Analysis | `docs/phase-3.6.5/treecontroller-corruption-analysis.md` | Bug analysis |
| Design Document | `docs/phase-3.6.5/custom-treecontroller-design.md` | Full implementation design |
| Implementation Plan | `.claude/plans/lazy-dazzling-bumblebee.md` | Step-by-step plan |
| Initial Review Prompts | `docs/phase-3.6.5/review-prompts.md` | First round prompts |
| This Document | `docs/phase-3.6.5/review-prompts-v2.md` | Second round prompts |

## Expected Response Format

Both reviewers should provide:
1. ✅ or ❌ for each verification finding
2. Any remaining concerns
3. Final go/no-go recommendation
4. Any last-minute suggestions for the implementation
