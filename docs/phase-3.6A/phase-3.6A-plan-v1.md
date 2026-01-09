# Phase 3.6A Plan: Tag Filtering

**Version:** 1
**Created:** 2026-01-09
**Status:** Draft - Ready for Implementation
**Branch:** `phase-3.6A-tag-filtering`

---

## Overview

**Goal:** Enable users to filter tasks by tags, completing the tagging system started in Phase 3.5

**Why now:**
- Just completed comprehensive tagging system in Phase 3.5
- Tags aren't useful without filtering capability
- Quick win (1 week) with immediate user value
- Natural extension of fresh tag infrastructure

**Estimated Duration:** 1 week (5-7 days)

---

## Scope

### Phase 3.6A Features

#### 1. Clickable Tag Chips
- Click any tag chip → immediately filter by that tag
- Works in main task list (active tasks)
- Works in completed task list
- Visual feedback when tag is active filter (highlighted/selected state)
- Single-tag quick filter (most common use case)

#### 2. Tag Filter Dialog
- **UI Location:** Filter icon in top app bar (🏷️ or ⚙️ filter icon)
- **Dialog Contents:**
  - List of all tags with task counts (e.g., "Work (12 tasks)")
  - Checkbox for each tag (multi-select)
  - AND/OR logic toggle
    - AND: "Show tasks with ALL selected tags"
    - OR: "Show tasks with ANY selected tags"
  - "Apply" and "Cancel" buttons
  - Search field within tag list (if many tags exist)

#### 3. Active Filter Bar
- Displays below app bar when filters are active
- Shows selected tags as chips
- Each chip has "X" button to remove that filter
- "Clear all filters" button when multiple filters active
- Compact design (doesn't take too much vertical space)
- Persists across navigation (within app session)

#### 4. Filter by Tag Presence
- Checkbox: "Show only tasks with tags"
- Checkbox: "Show only tasks without tags"
- Can combine with specific tag filters
- Use case: Find untagged tasks to organize

### Out of Scope (3.6B or later)
- ❌ Text search (that's Phase 3.6B)
- ❌ Fuzzy matching (3.6B)
- ❌ Date-based filtering (3.6B stretch goal or 3.7)
- ❌ Filter presets/saved filters (future enhancement)

---

## Technical Approach

### 1. Data Layer

**FilterState Model** (`lib/models/filter_state.dart`)
```dart
class FilterState {
  final List<String> selectedTagIds;
  final FilterLogic logic; // AND or OR
  final bool showOnlyWithTags;
  final bool showOnlyWithoutTags;

  FilterState({
    this.selectedTagIds = const [],
    this.logic = FilterLogic.or,
    this.showOnlyWithTags = false,
    this.showOnlyWithoutTags = false,
  });

  bool get isActive => selectedTagIds.isNotEmpty ||
                       showOnlyWithTags ||
                       showOnlyWithoutTags;

  // copyWith, toJson, fromJson methods
}

enum FilterLogic { and, or }
```

**TaskService Enhancements** (`lib/services/task_service.dart`)
- `Future<List<Task>> getFilteredTasks(FilterState filter)`
- Query builder for tag filtering with AND/OR logic
- Efficient SQL queries (avoid N+1 with tag joins)

**SQL Query Approach:**
```sql
-- OR logic (ANY of selected tags)
SELECT DISTINCT tasks.* FROM tasks
INNER JOIN task_tags ON tasks.id = task_tags.task_id
WHERE task_tags.tag_id IN (?, ?, ?)
AND tasks.deleted_at IS NULL
ORDER BY tasks.position;

-- AND logic (ALL of selected tags)
SELECT tasks.* FROM tasks
WHERE tasks.id IN (
  SELECT task_id FROM task_tags
  WHERE tag_id IN (?, ?, ?)
  GROUP BY task_id
  HAVING COUNT(DISTINCT tag_id) = ?
)
AND tasks.deleted_at IS NULL
ORDER BY tasks.position;

-- Show only with tags
SELECT DISTINCT tasks.* FROM tasks
INNER JOIN task_tags ON tasks.id = task_tags.task_id
WHERE tasks.deleted_at IS NULL;

-- Show only without tags
SELECT tasks.* FROM tasks
WHERE tasks.id NOT IN (
  SELECT DISTINCT task_id FROM task_tags
)
AND tasks.deleted_at IS NULL;
```

### 2. State Management

**TaskProvider Enhancements** (`lib/providers/task_provider.dart`)
```dart
class TaskProvider extends ChangeNotifier {
  // Existing fields...
  FilterState _filterState = FilterState();

  FilterState get filterState => _filterState;
  bool get hasActiveFilters => _filterState.isActive;

  Future<void> setFilter(FilterState filter) async {
    _filterState = filter;
    await _refreshFilteredTasks();
    notifyListeners();
  }

  Future<void> addTagFilter(String tagId) async {
    // Add single tag to filter
  }

  Future<void> removeTagFilter(String tagId) async {
    // Remove single tag from filter
  }

  Future<void> clearFilters() async {
    _filterState = FilterState();
    await _refreshTasks();
    notifyListeners();
  }

  Future<void> _refreshFilteredTasks() async {
    if (_filterState.isActive) {
      _tasks = await _taskService.getFilteredTasks(_filterState);
    } else {
      await _refreshTasks(); // Show all
    }
  }
}
```

### 3. UI Components

**New Widgets:**

1. **TagFilterDialog** (`lib/widgets/tag_filter_dialog.dart`)
   - Full-screen or modal dialog
   - Tag list with checkboxes
   - AND/OR toggle (SegmentedButton or Switch)
   - Tag count display per tag
   - Apply/Cancel buttons

2. **ActiveFilterBar** (`lib/widgets/active_filter_bar.dart`)
   - Horizontal chip list
   - Scrollable if many filters
   - Compact height (~48px)
   - Material 3 design (elevated surface)

3. **FilterableTagChip** (`lib/widgets/filterable_tag_chip.dart`)
   - Extends existing CompactTagChip
   - Adds onTap handler for filtering
   - Visual state: normal / selected / disabled
   - Reusable in task list and completed list

**Modified Widgets:**

1. **TaskListScreen** (`lib/screens/task_list_screen.dart`)
   - Add filter icon to app bar
   - Add ActiveFilterBar below app bar (when filters active)
   - Pass TaskProvider filter state to task list

2. **CompletedTasksScreen** (`lib/screens/completed_tasks_screen.dart`)
   - Same filter UI as TaskListScreen
   - Share filter state (TaskProvider)
   - Consistent UX across both screens

### 4. UI/UX Details

**Filter Icon:**
- Material Icons: `Icons.filter_list` or `Icons.label` (tag icon)
- Positioned in app bar (top right, before settings)
- Badge/indicator when filters are active

**Active Filter Bar:**
- Background: `Theme.colorScheme.surfaceContainerHighest`
- Padding: 8px horizontal, 8px vertical
- Chip spacing: 8px
- "Clear all" button: TextButton on right side
- Animate in/out (slide down when active)

**Tag Chip States:**
- Normal: Default tag color
- Selected (in filter): Border highlight or elevated
- Disabled: Grayed out (when tag has no matching tasks)

**AND/OR Toggle:**
- SegmentedButton: `[AND] [OR]`
- Default: OR (most intuitive for users)
- Tooltip explaining difference:
  - AND: "Show tasks with ALL selected tags"
  - OR: "Show tasks with ANY selected tags"

---

## Database Changes

**None required!** ✅

- All data exists (tags table, task_tags junction table)
- Queries use existing schema
- No migration needed
- Database version stays at v6

---

## Testing Strategy

### Unit Tests

**FilterState Tests** (`test/models/filter_state_test.dart`)
- [ ] Test FilterState creation
- [ ] Test isActive logic
- [ ] Test copyWith method
- [ ] Test JSON serialization (if needed)

**TaskService Filter Tests** (`test/services/task_service_filter_test.dart`)
- [ ] Test OR logic (any tag)
- [ ] Test AND logic (all tags)
- [ ] Test "has tags" filter
- [ ] Test "no tags" filter
- [ ] Test combined filters
- [ ] Test empty filter (returns all)
- [ ] Test performance with 100+ tasks

### Widget Tests

**TagFilterDialog Tests** (`test/widgets/tag_filter_dialog_test.dart`)
- [ ] Test dialog displays all tags
- [ ] Test tag selection (checkboxes)
- [ ] Test AND/OR toggle
- [ ] Test apply button updates filter state
- [ ] Test cancel button dismisses without changes

**ActiveFilterBar Tests** (`test/widgets/active_filter_bar_test.dart`)
- [ ] Test displays selected tags
- [ ] Test remove individual filter (X button)
- [ ] Test clear all button
- [ ] Test doesn't show when no filters active

**FilterableTagChip Tests** (`test/widgets/filterable_tag_chip_test.dart`)
- [ ] Test tap triggers filter
- [ ] Test visual states (normal, selected)

### Integration Tests

**Filter Workflow Tests** (`test_driver/tag_filter_integration_test.dart`)
- [ ] Test click tag chip → filter by tag
- [ ] Test open filter dialog → select multiple tags → apply
- [ ] Test AND vs OR logic with 2+ tags
- [ ] Test clear filters returns to all tasks
- [ ] Test filters work on completed tasks
- [ ] Test filters persist across navigation (active/completed switch)
- [ ] Test "has tags" / "no tags" filters

### Manual Testing

**Create manual test plan:** `docs/phase-3.6A/phase-3.6A-manual-test-plan.md`
- Use existing template from `docs/templates/manual-test-plan-template.md`
- Cover all filter scenarios
- Test on real device (Galaxy S22 Ultra)
- Validate performance with many tasks

---

## Implementation Plan

### Day 1-2: Core Infrastructure
1. Create FilterState model
2. Add filter methods to TaskService
3. Write SQL queries for AND/OR logic
4. Add filter state to TaskProvider
5. Write unit tests for FilterState and TaskService

### Day 3-4: UI Components
1. Create TagFilterDialog widget
2. Create ActiveFilterBar widget
3. Make TagChip clickable (FilterableTagChip)
4. Write widget tests

### Day 5: Integration
1. Add filter icon to TaskListScreen app bar
2. Add ActiveFilterBar to TaskListScreen
3. Wire up filter dialog and click handlers
4. Apply same to CompletedTasksScreen

### Day 6: Testing & Polish
1. Write integration tests
2. Manual testing on device
3. Performance testing (100+ tasks)
4. UI polish (animations, colors, spacing)
5. Fix any bugs found

### Day 7: Validation & Documentation
1. Full manual test plan execution
2. Create phase-3.6A-validation-v1.md
3. Update PROJECT_SPEC.md
4. Update README.md
5. Prepare for merge to main

---

## Success Criteria

**Must have (blocking for completion):**
- ✅ Click any tag chip → immediately filters by that tag
- ✅ Tag filter dialog shows all tags with task counts
- ✅ Can filter by multiple tags (AND/OR logic works correctly)
- ✅ Active filter bar shows selected tags
- ✅ Can remove individual filters or clear all
- ✅ Filters work on both active and completed tasks
- ✅ "Has tags" / "No tags" filters work
- ✅ Performance: Filter updates in <50ms for 1000 tasks
- ✅ All tests passing (unit + widget + integration)

**Nice to have (stretch goals):**
- ⏸️ Search field within tag filter dialog (if many tags)
- ⏸️ Smooth animations (filter bar slide in/out)
- ⏸️ Filter state persistence across app restarts (SharedPreferences)

---

## Dependencies

**Existing packages:**
- ✅ provider (state management)
- ✅ sqflite (database queries)
- ✅ flutter (Material 3 widgets)

**No new package dependencies required!**

---

## Risks & Mitigation

**Risk 1: Complex SQL queries for AND logic**
- Mitigation: Test thoroughly with various tag combinations
- Mitigation: Add performance tests with 1000+ tasks

**Risk 2: Filter state management complexity**
- Mitigation: Keep FilterState immutable (easier to reason about)
- Mitigation: Clear separation between TaskProvider and FilterState

**Risk 3: UI clutter with many active filters**
- Mitigation: Active filter bar is scrollable
- Mitigation: "Clear all" button for quick reset

**Risk 4: User confusion about AND vs OR**
- Mitigation: Clear labels and tooltips
- Mitigation: Default to OR (more intuitive)
- Mitigation: Manual testing with real user (BlueKitty!)

---

## Open Questions

**For BlueKitty:**
1. Should filter state persist across app restarts? (SharedPreferences)
   - Pro: User doesn't lose their filter when closing app
   - Con: Might be confusing if they forgot they had filters active

2. Should we show a "no results" message when filters return empty?
   - Current: Just shows empty list
   - Alternative: "No tasks match your filters" with "Clear filters" button

3. What icon for the filter button?
   - Option A: `Icons.filter_list` (traditional filter icon)
   - Option B: `Icons.label` (tag icon, more specific to tags)

---

## References

**Planning Documents:**
- `docs/phase-03-final-plan.md` - Overall Phase 3.6 plan
- `docs/PROJECT_SPEC.md` - Phase 3.6A scope (lines 456-466)
- `archive/phase-03/phase-3.6-and-3.6.5-enhancements-from-validation.md` - User validation findings

**Previous Phase:**
- `archive/phase-03/phase-3.5-summary.md` - Phase 3.5 learnings
- `archive/phase-03/phase-3.5-fix-c3-validation-summary.md` - Validation results

**Code Reference:**
- `lib/services/tag_service.dart` - Existing tag loading logic
- `lib/providers/tag_provider.dart` - Tag state management
- `lib/widgets/compact_tag_chip.dart` - Existing tag chip widget

---

**Status:** ✅ Ready for review and implementation
**Next Step:** Get BlueKitty's approval, answer open questions, begin Day 1 implementation

---

**Document Version:** 1.0
**Created By:** Claude
**Date:** 2026-01-09
