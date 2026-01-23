# Phase 3.6A Ultrathink: Tag Filtering Deep Analysis

**Created:** 2026-01-09
**Purpose:** Deep architectural analysis to identify potential issues before implementation
**Status:** Pre-implementation review (for Gemini and Codex feedback)
**Author:** Claude

---

## Executive Summary

**Goal:** Enable users to filter tasks by tags using AND/OR logic, clickable chips, and a comprehensive filter dialog.

**Core Challenge:** Integrate filtering into existing TaskProvider without breaking current functionality while maintaining performance with 1000+ tasks.

**Critical Success Factors:**
1. Filter queries must be O(N) or better (no N+1 problems)
2. State management must be clear and predictable
3. UI must not clutter existing screens
4. Filters must work identically on active and completed tasks

---

## Table of Contents

1. [Architecture Analysis](#architecture-analysis)
2. [Data Flow Deep Dive](#data-flow-deep-dive)
3. [SQL Query Design & Optimization](#sql-query-design--optimization)
4. [State Management Strategy](#state-management-strategy)
5. [UI/UX Interaction Flows](#uiux-interaction-flows)
6. [Edge Cases & Error Scenarios](#edge-cases--error-scenarios)
7. [Performance Analysis](#performance-analysis)
8. [Testing Strategy](#testing-strategy)
9. [Integration Points](#integration-points)
10. [Risk Assessment](#risk-assessment)
11. [Open Questions for Review](#open-questions-for-review)

---

## Architecture Analysis

### Current System Overview

**Existing Components:**
```
TaskProvider (lib/providers/task_provider.dart)
  ├─ Manages task list state
  ├─ Calls TaskService for data operations
  ├─ Notifies listeners on state changes
  └─ Currently has: _tasks, _completedTasks, _recentlyDeleted

TaskService (lib/services/task_service.dart)
  ├─ Database operations (CRUD)
  ├─ Hierarchical queries (WITH RECURSIVE)
  ├─ Tag loading via TagService
  └─ Transaction management

TagService (lib/services/tag_service.dart)
  ├─ Tag CRUD operations
  ├─ Batch loading (prevents N+1)
  └─ Task-tag associations

TagProvider (lib/providers/tag_provider.dart)
  ├─ Tag state management
  ├─ Separate from TaskProvider
  └─ Currently independent
```

**Key Observation:** TaskProvider and TagProvider are currently separate. Filtering will create a dependency between them.

### Proposed Architecture Changes

**New Components:**

1. **FilterState** (lib/models/filter_state.dart)
   - Immutable value object
   - Contains: selectedTagIds, logic (AND/OR), hasTag/noTag flags
   - Serializable (for future persistence if needed)

2. **TaskProvider Extensions**
   - Add `_filterState` field
   - Add filter-aware query methods
   - Keep existing methods working (backward compatibility)

3. **UI Components**
   - TagFilterDialog (new)
   - ActiveFilterBar (new)
   - FilterableTagChip (extends CompactTagChip)

**Dependency Graph:**
```
UI Layer
  ├─ TaskListScreen
  │   ├─ Reads TaskProvider.filterState
  │   ├─ Shows ActiveFilterBar if filters active
  │   └─ Opens TagFilterDialog on filter icon tap
  │
  ├─ CompletedTasksScreen
  │   └─ Same as TaskListScreen (shared filter state)
  │
  └─ FilterableTagChip (in task items)
      └─ Calls TaskProvider.addTagFilter(tagId)

State Layer
  ├─ TaskProvider
  │   ├─ Holds FilterState
  │   ├─ Calls TaskService.getFilteredTasks()
  │   └─ Notifies listeners on filter changes
  │
  └─ TagProvider
      └─ Provides tag data for filter dialog

Data Layer
  └─ TaskService
      ├─ getFilteredTasks(FilterState) - NEW
      ├─ Builds SQL queries based on filter
      └─ Returns filtered task list with hierarchy preserved
```

---

## Data Flow Deep Dive

### Scenario 1: User Clicks Tag Chip

**Flow:**
```
1. User taps "Work" tag chip on a task
   ↓
2. FilterableTagChip.onTap() fires
   ↓
3. Calls: context.read<TaskProvider>().addTagFilter("work-tag-id")
   ↓
4. TaskProvider.addTagFilter():
   - Creates new FilterState with added tag
   - Calls _refreshFilteredTasks()
   ↓
5. _refreshFilteredTasks():
   - Calls TaskService.getFilteredTasks(_filterState)
   - Updates _tasks with filtered results
   - notifyListeners()
   ↓
6. UI rebuilds:
   - TaskListScreen shows filtered tasks
   - ActiveFilterBar appears with "Work" chip
   - "Work" chip on tasks appears highlighted/selected
```

**State Changes:**
```dart
// Before
FilterState(selectedTagIds: [])

// After
FilterState(
  selectedTagIds: ["work-tag-id"],
  logic: FilterLogic.or,  // default
)
```

### Scenario 2: User Opens Filter Dialog, Selects Multiple Tags

**Flow:**
```
1. User taps filter icon (funnel) in app bar
   ↓
2. TagFilterDialog opens
   - Loads all tags from TagProvider
   - Shows current FilterState (checkboxes reflect selected tags)
   - Shows AND/OR toggle (current selection highlighted)
   ↓
3. User checks "Work" and "Urgent" tags
   ↓
4. User toggles to "AND" mode
   ↓
5. User taps "Apply"
   ↓
6. Dialog calls: Navigator.pop(context, newFilterState)
   ↓
7. Caller receives new FilterState:
   FilterState(
     selectedTagIds: ["work-id", "urgent-id"],
     logic: FilterLogic.and,
   )
   ↓
8. Calls: TaskProvider.setFilter(newFilterState)
   ↓
9. TaskProvider updates state and refreshes
   ↓
10. UI rebuilds with filtered tasks
```

**Important:** Dialog doesn't directly modify TaskProvider - it returns a new FilterState. This keeps dialog logic simple and testable.

### Scenario 3: User Removes One Filter from Active Bar

**Flow:**
```
1. User taps "X" on "Urgent" chip in ActiveFilterBar
   ↓
2. ActiveFilterBar calls: TaskProvider.removeTagFilter("urgent-id")
   ↓
3. TaskProvider.removeTagFilter():
   - Creates new FilterState without that tag
   - If no tags left, clears filter entirely
   - Calls _refreshFilteredTasks()
   ↓
4. UI rebuilds with updated filter
```

**Edge Case:** What if removing the last tag? Do we show all tasks or keep other filter flags (hasTag/noTag)?

**Decision:** If `selectedTagIds` becomes empty but `hasTag` or `noTag` is still true, keep those filters active. Only fully clear when ALL filter properties are default.

### Scenario 4: Clear All Filters

**Flow:**
```
1. User taps "Clear All" in ActiveFilterBar
   OR taps "Clear Filters" button in empty state
   ↓
2. Calls: TaskProvider.clearFilters()
   ↓
3. TaskProvider.clearFilters():
   - Sets _filterState = FilterState() // default/empty
   - Calls _refreshTasks() // NOT _refreshFilteredTasks()
   - notifyListeners()
   ↓
4. UI rebuilds showing all tasks
```

---

## SQL Query Design & Optimization

### Challenge: Efficient Tag Filtering Queries

**Problem:** Task-tag relationships are many-to-many. A task can have multiple tags, and a tag can be on multiple tasks. We need to filter efficiently without N+1 queries.

### Schema Recap

```sql
-- Tasks table
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  completed INTEGER DEFAULT 0,
  parent_id TEXT,
  position INTEGER,
  created_at INTEGER,
  completed_at INTEGER,
  deleted_at INTEGER,
  -- ... other fields
  FOREIGN KEY (parent_id) REFERENCES tasks(id)
);

-- Tags table
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color TEXT NOT NULL,
  created_at INTEGER
);

-- Junction table
CREATE TABLE task_tags (
  task_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (task_id, tag_id),
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);
```

**Indexes:** No indexes on task_tags yet. This could be a problem!

### Query 1: OR Logic (ANY of selected tags)

**User wants:** Tasks with "Work" OR "Urgent" (has at least one of these tags)

**SQL Approach:**
```sql
SELECT DISTINCT tasks.*
FROM tasks
INNER JOIN task_tags ON tasks.id = task_tags.task_id
WHERE task_tags.tag_id IN (?, ?, ?)  -- List of selected tag IDs
  AND tasks.deleted_at IS NULL
  AND tasks.completed = ?  -- 0 for active, 1 for completed
ORDER BY tasks.position;
```

**Performance Analysis:**
- **DISTINCT** is necessary because a task with both tags would appear twice
- INNER JOIN means only tasks with tags are returned (correct for OR logic)
- IN clause is efficient for small lists (2-5 tags typically)
- **Concern:** Without indexes on task_tags, this could be slow

**Index Needed:**
```sql
CREATE INDEX idx_task_tags_tag_id ON task_tags(tag_id);
CREATE INDEX idx_task_tags_task_id ON task_tags(task_id);
```

**Question:** Do these indexes already exist? Need to check database migration history.

### Query 2: AND Logic (ALL of selected tags)

**User wants:** Tasks with "Work" AND "Urgent" (has both tags)

**SQL Approach:**
```sql
SELECT tasks.*
FROM tasks
WHERE tasks.id IN (
  SELECT task_id
  FROM task_tags
  WHERE tag_id IN (?, ?, ?)  -- List of selected tag IDs
  GROUP BY task_id
  HAVING COUNT(DISTINCT tag_id) = ?  -- Must match number of selected tags
)
  AND tasks.deleted_at IS NULL
  AND tasks.completed = ?
ORDER BY tasks.position;
```

**Performance Analysis:**
- Subquery groups by task_id and counts distinct tags
- HAVING clause ensures task has ALL selected tags
- More complex than OR query but still O(N)
- **Concern:** Nested query - could be slower than JOIN for large datasets

**Alternative Approach (JOIN-based):**
```sql
-- This might be more efficient for small tag counts
SELECT tasks.*
FROM tasks
WHERE tasks.id IN (
  SELECT tt1.task_id
  FROM task_tags tt1
  WHERE tt1.tag_id = ?  -- First tag
  INTERSECT
  SELECT tt2.task_id
  FROM task_tags tt2
  WHERE tt2.tag_id = ?  -- Second tag
  -- ... repeat for each tag
)
  AND tasks.deleted_at IS NULL
  AND tasks.completed = ?;
```

**Problem:** INTERSECT approach requires dynamic query building (one INTERSECT per tag). More complex to construct.

**Decision:** Use GROUP BY + HAVING approach. It's cleaner and SQLite optimizes it well.

### Query 3: Show Only Tasks WITH Tags

**User wants:** Any task that has at least one tag

**SQL Approach:**
```sql
SELECT DISTINCT tasks.*
FROM tasks
INNER JOIN task_tags ON tasks.id = task_tags.task_id
WHERE tasks.deleted_at IS NULL
  AND tasks.completed = ?
ORDER BY tasks.position;
```

**Simple:** Just join with task_tags, any match includes the task.

### Query 4: Show Only Tasks WITHOUT Tags

**User wants:** Tasks with zero tags

**SQL Approach:**
```sql
SELECT tasks.*
FROM tasks
WHERE tasks.id NOT IN (
  SELECT DISTINCT task_id FROM task_tags
)
  AND tasks.deleted_at IS NULL
  AND tasks.completed = ?
ORDER BY tasks.position;
```

**Alternative (LEFT JOIN):**
```sql
SELECT tasks.*
FROM tasks
LEFT JOIN task_tags ON tasks.id = task_tags.task_id
WHERE task_tags.task_id IS NULL
  AND tasks.deleted_at IS NULL
  AND tasks.completed = ?
ORDER BY tasks.position;
```

**Decision:** Use LEFT JOIN approach - often faster than NOT IN subquery.

### Query 5: Combined Filters

**User wants:** Tasks with "Work" tag AND no other tags (hasTag=false means "only these tags, no extras")

**Wait, that's not what we planned!**

**Clarification needed:** What does "Show only tasks without tags" mean when combined with specific tag filters?

**Interpretation 1:** It's mutually exclusive
- Either filter by specific tags, OR show tasks without tags
- Can't do both at once

**Interpretation 2:** It's additive
- Show tasks with "Work" tag, PLUS tasks with no tags
- Essentially an OR condition

**Current plan says:** "Can combine with specific tag filters"

**Problem:** This is ambiguous. Need to clarify the interaction.

**Recommendation:** Make "Has tags" and "No tags" checkboxes mutually exclusive with specific tag selection. Gray out one when the other is active.

### Query Performance: Hierarchy Preservation

**Critical:** Filtered results must maintain task hierarchy!

**Current approach in TaskService:**
```sql
-- Existing query uses WITH RECURSIVE for hierarchy
WITH RECURSIVE task_tree AS (
  -- Base case: root tasks
  SELECT *, 0 as depth FROM tasks WHERE parent_id IS NULL
  UNION ALL
  -- Recursive case: children
  SELECT t.*, tt.depth + 1
  FROM tasks t
  JOIN task_tree tt ON t.parent_id = tt.id
)
SELECT * FROM task_tree WHERE deleted_at IS NULL;
```

**New challenge:** Apply tag filter to this recursive query.

**Option 1:** Filter AFTER building tree
```sql
WITH RECURSIVE task_tree AS (
  -- Build full tree
  ...
)
SELECT * FROM task_tree
WHERE id IN (
  -- Tag filter subquery
  SELECT task_id FROM task_tags WHERE tag_id IN (...)
);
```

**Problem:** This returns matching tasks but breaks hierarchy if parent doesn't match.

**Example:**
- Parent task: "Work project" (no tags)
  - Child task: "Write report" (tags: Work, Urgent)

If user filters by "Work" tag, child appears but parent is hidden. This breaks the tree display!

**Option 2:** Include parents if any descendant matches (recursive inclusion)

**This is complex!** Need to:
1. Find all tasks matching filter
2. Find all ancestors of those tasks
3. Return both matching tasks AND their ancestors
4. Mark which tasks actually matched vs. are included for hierarchy

**SQL for Option 2:**
```sql
WITH RECURSIVE
-- Find matching tasks
matching_tasks AS (
  SELECT tasks.id
  FROM tasks
  INNER JOIN task_tags ON tasks.id = task_tags.task_id
  WHERE task_tags.tag_id IN (?, ?)
    AND tasks.deleted_at IS NULL
),
-- Find all ancestors of matching tasks
ancestors AS (
  SELECT id FROM matching_tasks
  UNION
  SELECT tasks.parent_id
  FROM tasks
  JOIN ancestors ON tasks.id = ancestors.id
  WHERE tasks.parent_id IS NOT NULL
),
-- Build tree with hierarchy
task_tree AS (
  SELECT *, 0 as depth FROM tasks WHERE parent_id IS NULL AND id IN (SELECT id FROM ancestors)
  UNION ALL
  SELECT t.*, tt.depth + 1
  FROM tasks t
  JOIN task_tree tt ON t.parent_id = tt.id
  WHERE t.id IN (SELECT id FROM ancestors)
)
SELECT * FROM task_tree;
```

**This is getting very complex!**

**Alternative approach:** DON'T preserve full hierarchy for filtered views.

**Show only matching tasks as a flat list.** User can click "View in Context" to see full hierarchy.

**Pros:**
- Much simpler SQL
- Clearer to user (only matching tasks shown)
- Faster query execution

**Cons:**
- Loses hierarchy context in filtered view
- User might not understand parent/child relationships

**Recommendation:** Start with flat filtered list (no hierarchy preservation). Add "View in Context" action. Evaluate if hierarchy preservation is needed based on user feedback.

**Impact on UI:** Task items in filtered view show breadcrumb but no indentation/nesting. Similar to completed tasks with Fix #C3 breadcrumbs.

---

## State Management Strategy

### TaskProvider State Structure

**Current:**
```dart
class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  // ...
}
```

**Proposed Addition:**
```dart
class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  FilterState _filterState = FilterState();

  // Getters
  FilterState get filterState => _filterState;
  bool get hasActiveFilters => _filterState.isActive;

  // Filter methods
  Future<void> setFilter(FilterState filter) async { ... }
  Future<void> addTagFilter(String tagId) async { ... }
  Future<void> removeTagFilter(String tagId) async { ... }
  Future<void> clearFilters() async { ... }
  Future<void> toggleFilterLogic() async { ... }
}
```

### State Mutation Patterns

**Immutable FilterState:**
```dart
class FilterState {
  final List<String> selectedTagIds;
  final FilterLogic logic;
  final bool showOnlyWithTags;
  final bool showOnlyWithoutTags;

  const FilterState({
    this.selectedTagIds = const [],
    this.logic = FilterLogic.or,
    this.showOnlyWithTags = false,
    this.showOnlyWithoutTags = false,
  });

  FilterState copyWith({
    List<String>? selectedTagIds,
    FilterLogic? logic,
    bool? showOnlyWithTags,
    bool? showOnlyWithoutTags,
  }) {
    return FilterState(
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      logic: logic ?? this.logic,
      showOnlyWithTags: showOnlyWithTags ?? this.showOnlyWithTags,
      showOnlyWithoutTags: showOnlyWithoutTags ?? this.showOnlyWithoutTags,
    );
  }

  bool get isActive =>
      selectedTagIds.isNotEmpty ||
      showOnlyWithTags ||
      showOnlyWithoutTags;
}
```

**Why immutable?**
- Easier to reason about state changes
- No accidental mutations
- Can compare old vs new state easily
- Aligns with Flutter best practices

### Filter Update Flow

**When filter changes:**
```dart
Future<void> setFilter(FilterState filter) async {
  if (_filterState == filter) return; // No change

  _filterState = filter;

  if (filter.isActive) {
    // Apply filter
    _tasks = await _taskService.getFilteredTasks(filter, completed: false);
    _completedTasks = await _taskService.getFilteredTasks(filter, completed: true);
  } else {
    // Clear filter - reload all tasks
    await _refreshTasks();
  }

  notifyListeners();
}
```

**Question:** Should we filter both active and completed tasks, or just one at a time?

**Current screens:** TaskListScreen shows active tasks. CompletedTasksScreen shows completed tasks. They're separate screens.

**Interpretation 1:** Filter applies globally
- Changing filter on TaskListScreen also filters CompletedTasksScreen
- User expects consistent filter across app

**Interpretation 2:** Filter is per-screen
- Each screen has its own filter state
- More complex state management

**Recommendation:** Global filter (Interpretation 1). Simpler and more intuitive.

### State Persistence

**Decision:** No auto-persistence. Filters clear on app restart.

**Implementation:** FilterState stays in memory only. No SharedPreferences or database storage.

**Implication:** Keep FilterState simple - no need for serialization (yet).

---

## UI/UX Interaction Flows

### Flow 1: First-Time User Discovers Filtering

**Steps:**
```
1. User has tasks with tags (from Phase 3.5)
2. User sees tag chips on tasks
3. User taps a tag chip → tasks filter immediately
4. Active filter bar appears showing selected tag
5. User sees "1 filter active" or similar feedback
6. User taps "X" on filter chip → filter clears
```

**No onboarding needed** - discovery through interaction.

### Flow 2: Power User Uses Advanced Filtering

**Steps:**
```
1. User taps filter icon in app bar
2. Dialog opens showing all tags
3. User checks multiple tags (Work, Urgent, Today)
4. User sees "3 tags selected" counter
5. User toggles to "AND" mode
6. User taps "Apply"
7. Dialog closes, filtered tasks appear
8. Active filter bar shows all 3 tags
9. User can remove individual tags or clear all
```

### Flow 3: User Gets No Results

**Steps:**
```
1. User filters by "Work" AND "Urgent" AND "Today"
2. No tasks match all three tags
3. Task list shows empty state:
   - Icon (filter with X or sad face)
   - Text: "No tasks match your filters"
   - Button: "Clear Filters"
4. User taps "Clear Filters"
5. All tasks reappear
```

**Alternative:** Show "Relax filters" button that switches from AND to OR mode.

### Flow 4: User Switches Between Active and Completed

**Steps:**
```
1. User has filter active: "Work" tag
2. Active task list shows 5 matching tasks
3. User navigates to Completed tab
4. Completed task list shows 12 matching tasks
5. Filter bar still visible (same filter applies)
6. User removes filter
7. Both active and completed lists update
```

**Consistency:** Filter state is global, not per-screen.

---

## Edge Cases & Error Scenarios

### Edge Case 1: Tag Deleted While Filter Active

**Scenario:**
```
1. User filters by "Work" tag
2. User navigates to tag management (future feature)
3. User deletes "Work" tag
4. What happens to active filter?
```

**Options:**
A. Filter remains with deleted tag ID → shows no results (tag doesn't exist)
B. Filter automatically removes deleted tag
C. Filter shows error state

**Recommendation:** Option B - silently remove deleted tag from filter. If filter becomes empty, clear it.

**Implementation:** TagService fires event when tag deleted → TaskProvider listens and updates filter.

**Problem:** We don't have event system yet!

**Simpler approach:** When filter query returns empty for unexpected reason, assume tag was deleted and clear filter.

**Actually:** Tag deletion should cascade delete task_tags entries (already in schema with ON DELETE CASCADE). So filtered query just returns fewer results. No special handling needed.

### Edge Case 2: All Tasks Filtered Out

**Scenario:**
```
1. User has 10 tasks
2. User filters by "Urgent" tag
3. No tasks have "Urgent" tag
4. Empty state shows
```

**Handled by:** Empty results state (design included).

### Edge Case 3: Filter Dialog Opened While Filter Active

**Scenario:**
```
1. User has "Work" filter active (from clicking chip)
2. User opens filter dialog
3. Dialog should show "Work" checkbox already checked
4. User checks "Urgent" also
5. User taps "Apply"
6. Filter updates to show both tags
```

**Implementation:**
```dart
TagFilterDialog({
  required FilterState initialFilter,
  // ...
})

// Dialog internal state initialized from initialFilter
```

### Edge Case 4: User Rapidly Clicks Multiple Tag Chips

**Scenario:**
```
1. User clicks "Work" chip
2. Filter starts applying (async call to database)
3. User immediately clicks "Urgent" chip
4. Another filter call fires
5. Race condition: which filter wins?
```

**Problem:** Async operations can complete out of order.

**Solution 1:** Debounce filter updates (wait 300ms after last change)
**Solution 2:** Cancel previous filter operation when new one starts
**Solution 3:** Use operation ID/sequence number, ignore stale results

**Recommendation:** Solution 3 - simple and reliable.

```dart
int _filterOperationId = 0;

Future<void> setFilter(FilterState filter) async {
  _filterOperationId++;
  final currentOperation = _filterOperationId;

  // Simulate async work
  final results = await _taskService.getFilteredTasks(filter);

  // Only apply if this is still the latest operation
  if (currentOperation == _filterOperationId) {
    _tasks = results;
    notifyListeners();
  }
  // Otherwise discard stale results
}
```

### Edge Case 5: Filter + Reorder Mode Interaction

**Scenario:**
```
1. User has "Work" filter active (5 tasks showing)
2. User enters reorder mode
3. User drags task to new position
4. User exits reorder mode
5. User clears filter
6. All tasks appear - is "Work" task in correct position?
```

**Question:** Should reordering be allowed when filter is active?

**Option A:** Disable reorder mode when filter active
- Simpler logic
- Prevents confusion about where task goes in full list

**Option B:** Allow reordering in filtered view
- More flexible
- Risk: User might not realize they're reordering within filtered subset

**Recommendation:** Option A - disable reorder button when filter active. Show tooltip: "Clear filters to reorder tasks."

**Implementation:** Check `hasActiveFilters` before showing reorder button.

### Edge Case 6: Hierarchy Confusion

**Scenario (if we show hierarchy in filtered view):**
```
1. User filters by "Work" tag
2. Parent task has no tags
3. Child task has "Work" tag
4. Should parent appear in filtered view?
```

**Already discussed:** Start with flat list (no hierarchy in filtered view). Use breadcrumbs to show context.

---

## Performance Analysis

### Performance Targets

**Requirements:**
- Filter update: <50ms for 1000 tasks
- Dialog open: <100ms (load all tags)
- Chip tap: <50ms (instant feedback)

### Bottleneck Analysis

**Potential bottlenecks:**

1. **SQL Query Execution**
   - Complex AND queries with GROUP BY
   - Subqueries for hasTag/noTag
   - Recursive queries if hierarchy preserved

2. **Tag Loading**
   - Need all tags for filter dialog
   - Current TagService.getAllTags() - is it cached?

3. **State Updates**
   - notifyListeners() triggers rebuild of entire task list
   - O(N) rebuild for N tasks

4. **UI Rendering**
   - ActiveFilterBar with multiple chips
   - Task list with highlighted chips
   - Flutter rebuild performance

### Optimization Strategies

**1. Database Indexes**
```sql
CREATE INDEX IF NOT EXISTS idx_task_tags_task_id ON task_tags(task_id);
CREATE INDEX IF NOT EXISTS idx_task_tags_tag_id ON task_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed);
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON tasks(deleted_at);
```

**Check:** Do these indexes exist? Need to verify current schema.

**2. Query Result Caching**
- Cache filtered results until filter changes
- Don't re-query if filter unchanged
- Invalidate cache when tasks modified

**3. Tag Caching**
- TagProvider already loads all tags
- Reuse for filter dialog (don't reload)

**4. Selective Rebuilds**
- Use Consumer<TaskProvider> not Provider
- Only rebuild widgets that need filtered data
- Keep ActiveFilterBar separate widget

**5. Lazy Loading (future)**
- If >1000 tasks, paginate results
- Load first 100, then more on scroll
- Not needed for MVP (most users have <100 tasks)

### Performance Testing Plan

**Test scenarios:**
```
1. 10 tasks, 3 tags → baseline
2. 100 tasks, 10 tags → typical usage
3. 1000 tasks, 20 tags → stress test
4. Rapid filter changes (5 clicks/second)
5. AND query with 5 tags selected
6. Filter + scroll (does list lag?)
```

**Measurement:**
- Use Dart DevTools Timeline
- Measure SQL query time (add logging)
- Measure widget rebuild count
- Check for frame drops (60fps target)

---

## Testing Strategy

### Unit Tests

**FilterState Tests:**
```dart
test('FilterState.isActive returns true when tags selected', () {
  final filter = FilterState(selectedTagIds: ['tag1']);
  expect(filter.isActive, true);
});

test('FilterState.copyWith creates new instance', () {
  final filter1 = FilterState(logic: FilterLogic.or);
  final filter2 = filter1.copyWith(logic: FilterLogic.and);
  expect(filter2.logic, FilterLogic.and);
  expect(filter1.logic, FilterLogic.or); // Original unchanged
});

test('FilterState with empty tags is not active', () {
  final filter = FilterState();
  expect(filter.isActive, false);
});
```

**TaskService Filter Query Tests:**
```dart
test('getFilteredTasks with OR logic returns tasks with any tag', () async {
  // Setup: Create tasks with different tags
  final task1 = await createTask(title: 'Task 1', tagIds: ['work']);
  final task2 = await createTask(title: 'Task 2', tagIds: ['urgent']);
  final task3 = await createTask(title: 'Task 3', tagIds: ['personal']);

  // Filter by 'work' OR 'urgent'
  final filter = FilterState(
    selectedTagIds: ['work', 'urgent'],
    logic: FilterLogic.or,
  );

  final results = await taskService.getFilteredTasks(filter);

  expect(results.length, 2);
  expect(results.map((t) => t.title), containsAll(['Task 1', 'Task 2']));
});

test('getFilteredTasks with AND logic returns tasks with all tags', () async {
  // Setup
  final task1 = await createTask(title: 'Task 1', tagIds: ['work', 'urgent']);
  final task2 = await createTask(title: 'Task 2', tagIds: ['work']); // Missing 'urgent'

  // Filter by 'work' AND 'urgent'
  final filter = FilterState(
    selectedTagIds: ['work', 'urgent'],
    logic: FilterLogic.and,
  );

  final results = await taskService.getFilteredTasks(filter);

  expect(results.length, 1);
  expect(results.first.title, 'Task 1');
});

test('getFilteredTasks excludes deleted tasks', () async {
  final task1 = await createTask(title: 'Active', tagIds: ['work']);
  final task2 = await createTask(title: 'Deleted', tagIds: ['work']);
  await taskService.softDeleteTask(task2.id);

  final filter = FilterState(selectedTagIds: ['work']);
  final results = await taskService.getFilteredTasks(filter);

  expect(results.length, 1);
  expect(results.first.title, 'Active');
});
```

**TaskProvider Filter Tests:**
```dart
testWidgets('addTagFilter updates filter state', (tester) async {
  final provider = TaskProvider(mockTaskService);

  await provider.addTagFilter('tag-id');

  expect(provider.filterState.selectedTagIds, ['tag-id']);
  expect(provider.hasActiveFilters, true);
});

testWidgets('clearFilters resets to empty state', (tester) async {
  final provider = TaskProvider(mockTaskService);
  await provider.addTagFilter('tag-id');

  await provider.clearFilters();

  expect(provider.filterState.isActive, false);
  expect(provider.hasActiveFilters, false);
});
```

### Widget Tests

**TagFilterDialog Tests:**
```dart
testWidgets('TagFilterDialog shows all tags', (tester) async {
  final tags = [
    Tag(id: '1', name: 'Work', color: '#FF0000'),
    Tag(id: '2', name: 'Urgent', color: '#00FF00'),
  ];

  await tester.pumpWidget(
    MaterialApp(
      home: TagFilterDialog(
        tags: tags,
        initialFilter: FilterState(),
      ),
    ),
  );

  expect(find.text('Work'), findsOneWidget);
  expect(find.text('Urgent'), findsOneWidget);
});

testWidgets('TagFilterDialog returns new filter on apply', (tester) async {
  FilterState? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<FilterState>(
              context: context,
              builder: (_) => TagFilterDialog(
                tags: mockTags,
                initialFilter: FilterState(),
              ),
            );
          },
          child: Text('Open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  // Check first tag
  await tester.tap(find.byType(Checkbox).first);
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();

  expect(result, isNotNull);
  expect(result!.selectedTagIds.length, 1);
});
```

**ActiveFilterBar Tests:**
```dart
testWidgets('ActiveFilterBar shows selected tags', (tester) async {
  final filter = FilterState(selectedTagIds: ['tag1', 'tag2']);
  final tags = [
    Tag(id: 'tag1', name: 'Work', color: '#FF0000'),
    Tag(id: 'tag2', name: 'Urgent', color: '#00FF00'),
  ];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ActiveFilterBar(
          filterState: filter,
          tags: tags,
          onRemoveTag: (_) {},
          onClearAll: () {},
        ),
      ),
    ),
  );

  expect(find.text('Work'), findsOneWidget);
  expect(find.text('Urgent'), findsOneWidget);
  expect(find.text('Clear All'), findsOneWidget);
});

testWidgets('ActiveFilterBar calls onRemoveTag when X tapped', (tester) async {
  String? removedTag;

  // ... setup widget with onRemoveTag: (id) => removedTag = id

  await tester.tap(find.byIcon(Icons.close).first);

  expect(removedTag, isNotNull);
});
```

### Integration Tests

**Full Filter Workflow:**
```dart
testWidgets('End-to-end: Click chip -> filter -> clear', (tester) async {
  // Setup app with test data
  await tester.pumpWidget(MyApp(testMode: true));
  await tester.pumpAndSettle();

  // Verify initial state (all tasks visible)
  expect(find.byType(TaskItem), findsNWidgets(10));

  // Tap a tag chip on first task
  await tester.tap(find.text('Work').first);
  await tester.pumpAndSettle();

  // Verify filtered (fewer tasks)
  expect(find.byType(TaskItem), findsNWidgets(3));

  // Verify active filter bar appeared
  expect(find.byType(ActiveFilterBar), findsOneWidget);

  // Tap clear filters
  await tester.tap(find.text('Clear All'));
  await tester.pumpAndSettle();

  // Verify all tasks visible again
  expect(find.byType(TaskItem), findsNWidgets(10));
  expect(find.byType(ActiveFilterBar), findsNothing);
});
```

---

## Integration Points

### 1. Existing TaskProvider Methods

**Must not break:**
- `loadTasks()` - Initial load, should respect filter if active
- `addTask()` - New task might not match filter, needs handling
- `updateTask()` - Updated task might no longer match filter
- `deleteTask()` - Simpler, just remove from list
- `toggleTaskCompletion()` - Moves task between active/completed

**Strategy:** Add optional `respectFilter` parameter to these methods.

```dart
Future<void> loadTasks({bool respectFilter = true}) async {
  if (respectFilter && _filterState.isActive) {
    _tasks = await _taskService.getFilteredTasks(_filterState);
  } else {
    _tasks = await _taskService.getAllTasks();
  }
  notifyListeners();
}
```

### 2. Task Creation Flow

**Scenario:**
```
1. User has "Work" filter active
2. User creates new task (doesn't have "Work" tag)
3. What happens?
```

**Option A:** New task doesn't appear (not in filter)
- User might be confused ("where did my task go?")

**Option B:** Temporarily show all tasks
- Breaks filter expectation

**Option C:** Auto-add filtered tag to new task
- Unexpected behavior (modifying user's task)

**Recommendation:** Option A with snackbar message:
"Task created (not visible in current filter)"

### 3. Drag & Drop in Filtered View

**Already decided:** Disable reorder mode when filter active.

**Implementation:**
```dart
// In TaskListScreen
final canReorder = !Provider.of<TaskProvider>(context).hasActiveFilters;

// Gray out reorder button with tooltip
IconButton(
  icon: Icon(Icons.reorder),
  onPressed: canReorder ? _enterReorderMode : null,
  tooltip: canReorder
    ? 'Reorder tasks'
    : 'Clear filters to reorder',
)
```

### 4. Completed Tasks Screen

**Shares filter state** with TaskListScreen.

**Implementation:** Both screens use same `TaskProvider` instance. No special handling needed.

---

## Risk Assessment

### High Risk

**1. SQL Query Performance**
- **Risk:** Complex AND queries slow with 1000+ tasks
- **Mitigation:** Add indexes, performance test early
- **Fallback:** Simplify to OR-only if AND is too slow

**2. State Management Complexity**
- **Risk:** Race conditions with async filter updates
- **Mitigation:** Operation ID pattern to ignore stale results
- **Fallback:** Add loading state, prevent rapid clicks

**3. UI Clutter**
- **Risk:** Active filter bar takes too much space on small screens
- **Mitigation:** Collapsible filter bar, compact design
- **Fallback:** Show icon instead of full chips when space limited

### Medium Risk

**4. Filter + Task Modification Interactions**
- **Risk:** Creating/updating tasks while filter active confuses users
- **Mitigation:** Show snackbar messages, clear communication
- **Fallback:** Auto-clear filter on task creation (if feedback is negative)

**5. Tag Deletion Edge Case**
- **Risk:** Deleting tag while filter active leaves broken state
- **Mitigation:** Cascade delete handles database, auto-refresh filter
- **Fallback:** Manual filter clear by user

**6. Hierarchy Display Confusion**
- **Risk:** Flat filtered list loses context
- **Mitigation:** Use breadcrumbs, "View in Context" action
- **Fallback:** Add hierarchy preservation if users complain

### Low Risk

**7. Empty Results State**
- **Risk:** Users don't understand why list is empty
- **Mitigation:** Clear message + "Clear Filters" button
- **Low risk:** This is standard UX pattern

**8. Filter Dialog Complexity**
- **Risk:** Too many options overwhelms users
- **Mitigation:** Start simple (just tags + AND/OR toggle)
- **Low risk:** Similar to email filters, familiar pattern

---

## Open Questions for Review

### For Gemini & Codex:

**Architecture:**
1. Is the FilterState model design sound? Any missing fields?
2. Should TaskProvider hold filter state, or create separate FilterProvider?
3. Is immutable FilterState the right approach, or use mutable?

**SQL Queries:**
4. Are the proposed SQL queries optimal? Better alternatives?
5. Do we need additional indexes? Which ones?
6. Should we preserve hierarchy in filtered view, or show flat list?

**Performance:**
7. Will operation ID pattern prevent race conditions effectively?
8. Any other performance concerns with proposed architecture?
9. Is <50ms filter update realistic for 1000 tasks?

**Edge Cases:**
10. What should happen when task created while filter active?
11. Should "has tags" and "no tags" be mutually exclusive with specific tags?
12. How to handle tag deletion while that tag is in active filter?

**UI/UX:**
13. Is disabling reorder mode when filter active the right choice?
14. Should filter be global (both screens) or per-screen?
15. Is Icons.filter_alt the clearest icon choice?

**Testing:**
16. Are the proposed test scenarios comprehensive enough?
17. Any critical test cases missing?
18. Should we add integration tests for all edge cases?

**Code Organization:**
19. Should FilterState be in lib/models/ or lib/services/?
20. Should we create a FilterService layer, or keep logic in TaskProvider?

---

## Conclusion

This ultrathink document covers:
- ✅ Complete architecture analysis
- ✅ Detailed data flow scenarios
- ✅ SQL query design with performance analysis
- ✅ State management strategy
- ✅ UI/UX interaction flows
- ✅ Comprehensive edge case analysis
- ✅ Performance considerations
- ✅ Testing strategy
- ✅ Integration point analysis
- ✅ Risk assessment

**Major open questions:**
1. Hierarchy preservation vs. flat filtered list
2. "Has tags" / "No tags" interaction with specific tag filters
3. TaskProvider vs. separate FilterProvider
4. Task creation behavior when filter active

**Recommendations for review:**
- Focus on SQL query optimization (biggest performance risk)
- Validate state management approach (race conditions)
- Clarify edge case handling (tag deletion, task creation)
- Confirm flat filtered list is acceptable UX

**Next steps after review:**
1. Address feedback from Gemini/Codex
2. Update phase-3.6A-plan-v1.md with any changes
3. Begin Day 1 implementation with confidence

---

**Document Status:** Ready for team review
**Estimated Review Time:** 30-45 minutes
**Priority Areas:** SQL queries, state management, edge cases

**Prepared By:** Claude
**Date:** 2026-01-09
**Version:** 1.0
