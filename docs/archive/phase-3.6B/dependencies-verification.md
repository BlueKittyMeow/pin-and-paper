# Phase 3.6B Dependencies Verification

**Date:** 2026-01-11
**Purpose:** Verify all Phase 3.6A dependencies before starting Phase 3.6B implementation

---

## ✅ VERIFIED Dependencies from Phase 3.6A

### FilterState Model (`lib/models/filter_state.dart`)
- ✅ `FilterState` class exists
- ✅ `FilterState.copyWith()` method exists (lines 76-86)
- ✅ `FilterState.toJson()` method exists (lines 91-97)
- ✅ `FilterState.fromJson()` factory exists (lines 103-116)
- ✅ `FilterState.empty` constant exists (line 59)
- ✅ `FilterState.isActive` getter exists (lines 66-71)

### Enums
- ✅ `FilterLogic` enum exists (lines 146-154)
  - Values: `FilterLogic.or`, `FilterLogic.and`
- ✅ `TagPresenceFilter` enum exists (lines 160-173)
  - ⚠️ **VALUES DIFFER FROM PLAN:**
    - Actual: `TagPresenceFilter.onlyTagged`, `TagPresenceFilter.onlyUntagged`
    - Plan used: `TagPresenceFilter.tagged`, `TagPresenceFilter.untagged`
  - **ACTION:** Update plan to use correct enum values

### TagFilterDialog Widget (`lib/widgets/tag_filter_dialog.dart`)
- ✅ `TagFilterDialog` widget exists
- ✅ Returns `FilterState` via `Navigator.pop(context, filter)` (line 466)
- ⚠️ **INTERFACE DIFFERS FROM PLAN:**
  - **Actual constructor:**
    ```dart
    TagFilterDialog({
      required FilterState initialFilter,  // ✅ (not initialFilterState)
      required List<Tag> allTags,          // ❌ MISSING from plan
      required bool showCompletedCounts,   // ❌ MISSING from plan
      required TagService tagService,      // ❌ MISSING from plan
    })
    ```
  - **Plan assumed:**
    ```dart
    TagFilterDialog({
      required FilterState initialFilterState,
    })
    ```
  - **ACTION:** Update plan to pass all required parameters

### Tag Service
- ✅ `TagService` class exists (imported in tag_filter_dialog.dart)
- ✅ `TagService().getTagById(tagId)` method exists (used in plan)
- ✅ `TagService().getTaskCountsByTag()` method exists (line 78 in dialog)

---

## ❌ MISSING Dependencies (Need to Implement in Phase 3.6B)

### TaskProvider Methods
- ❌ `TaskProvider.saveSearchState(Map)` - Does NOT exist
- ❌ `TaskProvider.getSearchState()` - Does NOT exist
- ❌ `TaskProvider.navigateToTask(String taskId)` - Does NOT exist

**ACTION:** These must be implemented in Phase 3.6B

### flutter_fancy_tree_view2 Navigation API
Based on pub.dev documentation research:

**✅ Available:**
- `TreeController.expandAncestors(node)` - Expands all parent nodes

**❌ NOT Available:**
- `findNodeById(taskId)` - Must implement ourselves
- `scrollToTask(taskId)` - Must implement ourselves
- `highlightTask(taskId)` - Must implement ourselves

**ACTION:** Implement helper methods for node finding and scrolling

---

## 📝 Required Updates to Plan v3

### 1. Fix TagPresenceFilter Enum Values

**Search and replace throughout plan:**
- `TagPresenceFilter.any` ✅ (correct)
- `TagPresenceFilter.tagged` → `TagPresenceFilter.onlyTagged` ❌
- `TagPresenceFilter.untagged` → `TagPresenceFilter.onlyUntagged` ❌

**Files to update:**
- plan-v3.md (all references)

---

### 2. Fix TagFilterDialog Usage

**Current plan code:**
```dart
void _selectTags() async {
  final selected = await showDialog<FilterState>(
    context: context,
    builder: (context) => TagFilterDialog(
      initialFilterState: _tagFilters ?? FilterState.empty(),  // WRONG
    ),
  );
  // ...
}
```

**Correct implementation:**
```dart
void _selectTags() async {
  // First, fetch all tags
  final tagService = TagService();
  final allTags = await tagService.getAllTags();

  if (!mounted) return;

  final selected = await showDialog<FilterState>(
    context: context,
    builder: (context) => TagFilterDialog(
      initialFilter: _tagFilters ?? FilterState.empty(),  // CORRECT name
      allTags: allTags,                                   // REQUIRED
      showCompletedCounts: _scope == SearchScope.completed ||
                           _scope == SearchScope.recentlyCompleted,  // REQUIRED
      tagService: tagService,                             // REQUIRED
    ),
  );

  if (selected != null && mounted) {
    setState(() {
      _tagFilters = selected;
    });
    _loadTagsForFilter();
    _debouncedSearch();
  }
}
```

---

### 3. Add State Variable for Tag Service

**SearchDialog needs:**
```dart
class _SearchDialogState extends State<SearchDialog> {
  final _searchController = TextEditingController();
  final _tagService = TagService();  // NEW: Cache service instance
  // ... rest of state
}
```

---

### 4. Implement TaskProvider Methods

**Add to TaskProvider (lib/providers/task_provider.dart):**

```dart
/// Phase 3.6B: Search state persistence (session only)
Map<String, dynamic>? _searchState;

/// Save search state for next dialog open (cleared on app restart)
void saveSearchState(Map<String, dynamic> state) {
  _searchState = state;
  // NO notifyListeners() - this is internal state
}

/// Get saved search state (returns null if not saved or app restarted)
Map<String, dynamic>? getSearchState() {
  return _searchState;
}

/// Phase 3.6B: Navigate to task from search results
Future<void> navigateToTask(String taskId) async {
  // Implementation to be added during Phase 3.6B
  // This method will:
  // 1. Find the task node in the tree
  // 2. Expand all parent nodes
  // 3. Scroll to the task
  // 4. Highlight it briefly

  // TODO: Implement during Phase 3.6B Day 6-7
  // See implementation notes in plan-v3.md

  notifyListeners();
}
```

---

### 5. Document Navigation Implementation Strategy

**Add to plan-v3.md Implementation Notes:**

```markdown
### Navigation to Task (Implementation Strategy)

**Problem:**
flutter_fancy_tree_view2 provides `expandAncestors(node)` but NO built-in methods to:
- Find a node by task ID
- Scroll to a specific node
- Highlight a node temporarily

**Solution (Phase 3.6B Day 6-7):**

#### Step 1: Find Node by ID
Since TreeView uses a flat list internally, we can iterate to find the node:

```dart
TreeNode? findNodeById(String taskId) {
  for (final node in _treeController.roots) {
    final found = _findNodeInSubtree(node, taskId);
    if (found != null) return found;
  }
  return null;
}

TreeNode? _findNodeInSubtree(TreeNode node, String taskId) {
  if (node.data.id == taskId) return node;

  for (final child in node.children) {
    final found = _findNodeInSubtree(child, taskId);
    if (found != null) return found;
  }

  return null;
}
```

#### Step 2: Expand Ancestors
Use built-in method:

```dart
final node = findNodeById(taskId);
if (node != null) {
  _treeController.expandAncestors(node);  // ✅ Built-in method
}
```

#### Step 3: Scroll to Node
Options:
- **Option A:** Use `ListView.builder` with calculated index and `scrollToIndex`
- **Option B:** Use `ScrollController.animateTo` with calculated offset
- **Option C:** Implement during Day 6-7 based on actual TreeView structure

**Recommended:** Defer implementation details to Day 6-7 when we can test directly.

#### Step 4: Highlight Node
Create a highlight state in TaskProvider:

```dart
String? _highlightedTaskId;
Timer? _highlightTimer;

void highlightTask(String taskId, {required Duration duration}) {
  _highlightedTaskId = taskId;
  notifyListeners();

  _highlightTimer?.cancel();
  _highlightTimer = Timer(duration, () {
    _highlightedTaskId = null;
    notifyListeners();
  });
}

bool isTaskHighlighted(String taskId) {
  return _highlightedTaskId == taskId;
}
```

Then in TaskTile widget:
```dart
Container(
  color: taskProvider.isTaskHighlighted(task.id)
      ? Colors.yellow.withOpacity(0.3)
      : null,
  child: // ... task tile content
)
```

**Fallback Plan:**
If scrolling proves too complex, we can:
1. Just expand the task (user scrolls manually)
2. Show a snackbar: "Task is now visible in the list"
3. Still highlight it for 2 seconds
```

---

## 📋 Implementation Checklist

**Before Day 1:**
- [ ] Update all `TagPresenceFilter.tagged` → `TagPresenceFilter.onlyTagged`
- [ ] Update all `TagPresenceFilter.untagged` → `TagPresenceFilter.onlyUntagged`
- [ ] Update `_selectTags()` to pass all required TagFilterDialog parameters
- [ ] Add `_tagService` instance variable to SearchDialog
- [ ] Add `saveSearchState/getSearchState` to TaskProvider
- [ ] Add stub `navigateToTask` to TaskProvider (implement Day 6-7)
- [ ] Update navigation documentation with implementation strategy

**Day 6-7 (Navigation Implementation):**
- [ ] Implement `findNodeById()` helper
- [ ] Test `expandAncestors()` with found node
- [ ] Research actual TreeView structure for scrolling
- [ ] Implement scroll-to-node (or fallback to just expand)
- [ ] Implement highlight animation
- [ ] Test full navigation flow

---

## ✅ Conclusion

**Dependencies verified with 2 critical interface mismatches:**
1. TagPresenceFilter enum values different
2. TagFilterDialog requires 4 parameters (not 1)

**New implementations required:**
1. TaskProvider search state methods
2. TaskProvider navigateToTask (with helpers)

**All issues documented and actionable. Plan v3 can be updated systematically.** ✅
