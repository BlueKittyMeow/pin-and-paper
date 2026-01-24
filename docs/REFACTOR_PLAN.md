# TaskProvider Refactoring Plan (Phase 3.9)

**Branch:** `refactor/split-task-provider`
**Goal:** Reduce TaskProvider from ~1,598 lines to ~600 lines by extracting specialized providers
**Reason:** Context window bloat causing issues for Claude, Gemini, and Codex

⚠️ **NOTE:** This document is temporary and should be deleted after refactoring is complete.

---

## Progress Overview

- ✅ **Phase 1: TaskSortProvider** - COMPLETED (commit 412d009)
- 🔄 **Phase 1.5: Get review feedback** - IN PROGRESS
- ⏳ **Phase 2: TaskFilterProvider** - PENDING (~170 lines to extract)
- ⏳ **Phase 3: TaskHierarchyProvider** - PENDING (~200-300 lines to extract)
- ⏳ **Phase 4: TaskNavigationProvider** - PENDING OPTIONAL (~115 lines to extract)

---

## Phase 1: TaskSortProvider ✅ COMPLETE

**Status:** Completed, committed 412d009
**Lines extracted:** ~50 lines
**New file:** `lib/providers/task_sort_provider.dart`

### What was moved:
- `_sortMode` and `_sortReversed` state
- `setSortMode()` and `toggleSortReversed()` methods
- Sort preference loading (`getSortMode()`, `getSortReversed()`)
- Sort preference persistence (`setSortMode()`, `setSortReversed()`)

### What was updated:
- TaskProvider now depends on TaskSortProvider via `ChangeNotifierProxyProvider2`
- TaskProvider listens to sort changes via `_sortProvider.addListener(_onSortChanged)`
- `_sortTasks()` delegates to `_sortProvider.sortMode` and `_sortProvider.sortReversed`
- `home_screen.dart` sort button uses `Consumer<TaskSortProvider>` instead of `Consumer<TaskProvider>`
- Proper cleanup in `dispose()`

### Review questions for Gemini/Codex:
1. Does the implementation follow the recommended pattern correctly?
2. Any edge cases or potential issues missed?
3. Any improvements to TaskSortProvider design?
4. Ready to proceed with Phase 2?

---

## Phase 2: TaskFilterProvider ⏳ PENDING

**Target:** Extract ~170 lines
**New file:** `lib/providers/task_filter_provider.dart`

### What to move from TaskProvider (lines 1300-1470):

**State:**
- `_filterState` (FilterState)
- `_filterOperationId` (int - for race condition prevention)

**Getters:**
- `filterState` → delegate to filterProvider
- `hasActiveFilters` → delegate to filterProvider

**Methods to extract:**
- `setFilter(FilterState filter)` - Main filter application logic
- `_reapplyCurrentFilter()` - Reapply after drag/drop
- `addTagFilter(String tagId)` - Add tag to filter
- `removeTagFilter(String tagId)` - Remove tag from filter
- `clearFilters()` - Clear all filters

### What stays in TaskProvider:
- The actual filtering queries (call TaskService.getFilteredTasks)
- Task list updates based on filter results
- Integration with loadTasks()

### Dependencies:
- TaskFilterProvider needs TagProvider for tag validation
- TaskProvider listens to TaskFilterProvider for filter changes
- Update `home_screen.dart` filter UI to use TaskFilterProvider

### Provider chain after Phase 2:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(TagProvider),
    ChangeNotifierProvider(TaskSortProvider),
    ChangeNotifierProvider(TaskFilterProvider),
    ChangeNotifierProxyProvider3<TagProvider, TaskSortProvider, TaskFilterProvider, TaskProvider>(...),
  ]
)
```

---

## Phase 3: TaskHierarchyProvider ⏳ PENDING

**Target:** Extract ~200-300 lines
**New file:** `lib/providers/task_hierarchy_provider.dart`

### What to move from TaskProvider:

**State:**
- `_isReorderMode` (bool)
- `_treeController` (TaskTreeController)
- `_treeVersion` (int)

**Getters:**
- `isReorderMode` → delegate
- `treeController` → delegate
- `treeVersion` → delegate
- `areAllExpanded` → move entirely

**Methods to extract:**
- `setReorderMode(bool enabled)`
- `toggleCollapse(Task task)`
- `expandAll()`
- `collapseAll()`
- `_refreshTreeController()` - CRITICAL method, coordinates with TaskProvider

### What stays in TaskProvider:
- Task data (`_tasks`)
- Child/parent finding helpers (`_findParent`, etc.)
- The actual tree building logic might stay and just notify HierarchyProvider

### Challenge:
- `_refreshTreeController()` is called from many places in TaskProvider
- Need to decide: Does HierarchyProvider own the tree refresh logic, or does it just manage state?
- Likely solution: TaskProvider calls `hierarchyProvider.refreshTree(_tasks)` instead

### UI Updates:
- Update `home_screen.dart` reorder mode toggle
- Update expand/collapse buttons
- Update AnimatedTreeView to listen to HierarchyProvider

---

## Phase 4: TaskNavigationProvider ⏳ OPTIONAL

**Target:** Extract ~115 lines
**New file:** `lib/providers/task_navigation_provider.dart`

### What to move from TaskProvider (lines 1476-1591):

**State:**
- `_searchState` (Map<String, dynamic>?)
- `_taskKeys` (Map<String, GlobalKey>)
- `_highlightedTaskId` (String?)
- `_highlightTimer` (Timer?)

**Methods to extract:**
- `saveSearchState(Map<String, dynamic> state)`
- `getSearchState()`
- `getKeyForTask(String taskId)`
- `navigateToTask(String taskId)`
- `_expandAncestors(Task task)`
- `_highlightTask(String taskId, {required Duration duration})`
- `isTaskHighlighted(String taskId)`

### Why Optional:
- These are UI convenience features, not core task management
- Lower priority than filter/hierarchy splitting
- Smallest impact on context window (~115 lines)

### Dependencies:
- Needs access to task list for finding tasks
- Needs HierarchyProvider to expand ancestors
- Could possibly stay in TaskProvider if other phases provide enough relief

---

## Final Result: TaskListProvider

**After all phases, TaskProvider becomes TaskListProvider (~600-700 lines)**

### Core responsibilities:
1. **CRUD Operations:**
   - `createTask()`, `createMultipleTasks()`
   - `updateTask()`, `updateTaskTitle()`
   - `toggleTaskCompletion()`
   - `deleteTaskWithConfirmation()`

2. **Task Loading:**
   - `loadTasks()`, `_performLoadTasks()`
   - Task hierarchy building
   - Tag loading integration

3. **Task Organization:**
   - `_categorizeTasks()` - active/recent/old buckets
   - Incomplete descendant tracking
   - Parent/child relationships

4. **Recently Deleted:**
   - `restoreTask()`
   - `permanentlyDeleteTask()`
   - `emptyTrash()`
   - `getRecentlyDeletedTasks()`

5. **Integration:**
   - Notification scheduling hooks (Phase 3.8)
   - Breadcrumb building
   - Visibility calculations

### What gets delegated:
- ✅ Sorting → TaskSortProvider
- ⏳ Filtering → TaskFilterProvider
- ⏳ Hierarchy/Tree → TaskHierarchyProvider
- ⏳ Navigation/Search → TaskNavigationProvider (optional)

---

## Testing Strategy

### After each phase:
1. ✅ Run `flutter analyze` - ensure no new errors
2. ✅ Run `flutter test` - ensure no new failures
3. ✅ Manually test affected functionality
4. ✅ Grep for missed references
5. ✅ Commit with detailed message

### Before final merge:
1. Full regression test of all features
2. Performance check (any regressions?)
3. Context window test (can Claude handle codebase better?)

---

## Risks & Mitigation

### Risk: Breaking existing functionality
**Mitigation:** Incremental approach, test after each phase

### Risk: Provider dependency hell
**Mitigation:** Keep dependencies minimal, use Proxy providers correctly

### Risk: Performance regression
**Mitigation:** Each provider should improve performance (fewer rebuilds)

### Risk: Too many providers (complexity)
**Mitigation:** Each provider has single, clear responsibility

---

## References

- **Gemini's analysis:** `docs/phase-3.9/gemini-findings.md`
- **Codex's analysis:** `docs/phase-3.9/codex-findings.md`
- **Original TaskProvider:** `pin_and_paper/lib/providers/task_provider.dart` (branch: phase-3.8)
- **Refactor branch:** `refactor/split-task-provider`

---

## Timeline Estimate

- Phase 1: ✅ 2 hours (DONE)
- Phase 1.5: 🔄 30 min (review feedback)
- Phase 2: ⏳ 2 hours (filter extraction)
- Phase 3: ⏳ 2.5 hours (hierarchy extraction - more complex)
- Phase 4: ⏳ 1.5 hours (navigation - optional)
- Final: ⏳ 1 hour (testing, merge)

**Total: 9-10 hours** (excluding Phase 4: ~7-8 hours)

---

**DELETE THIS FILE** when refactoring is complete and merged to main.
