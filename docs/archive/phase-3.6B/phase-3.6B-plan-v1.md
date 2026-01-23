# Phase 3.6B Plan - Universal Search

**Version:** 1
**Created:** 2026-01-11
**Status:** Draft
**Estimated Duration:** 1-2 weeks

---

## Scope

Phase 3.6B implements universal search functionality to complement the tag filtering system completed in Phase 3.6A. Users will be able to search across all tasks (active and completed) by title, notes, and tags, with search results respecting the current filter state for powerful combined queries.

**This is the final piece of Phase 3.6 (Tag Search & Filtering).**

---

## Subphases

Since this is a focused feature with tight integration points, treating as single subphase:

- **3.6B:** Universal Search Implementation
  - Search UI (magnifying glass icon, search field)
  - Search service (query logic across titles, notes, tags)
  - Integration with existing filter state
  - Search results display
  - Search persistence and clear functionality

---

## Context from Phase 3.6A

**Completed in 3.6A:**
- ✅ Tag filtering with multi-select (AND/OR logic)
- ✅ Tag presence filters (any/tagged/untagged)
- ✅ Active filter bar with chip removal
- ✅ FilterState model for managing filter state
- ✅ TaskProvider methods: `setFilter()`, `clearFilters()`, `removeTagFilter()`
- ✅ `getFilteredTasks()` and `countFilteredTasks()` in TaskService

**Integration Points:**
- Search must work WITH filter state (not replace it)
- Search query + filters = combined powerful queries
- Example: "Search 'meeting' + Filter by 'Work' tag" = work meetings only

---

## Technical Approach

### 1. Search State Management

**Add to FilterState model:**
```dart
class FilterState {
  final String searchQuery;  // NEW
  final List<String> selectedTagIds;
  final FilterLogic logic;
  final TagPresenceFilter presenceFilter;

  // Empty search query = no search filter
  bool get hasSearchQuery => searchQuery.isNotEmpty;
  bool get isActive => hasSearchQuery || selectedTagIds.isNotEmpty || presenceFilter != TagPresenceFilter.any;
}
```

**Why add to FilterState:**
- Search is a type of filter (limits visible tasks)
- Needs to persist with other filters
- Serializes to JSON for potential future persistence
- Clean integration with existing `setFilter()` flow

### 2. Database Query Enhancement

**Update `TaskService.getFilteredTasks()`:**
- Add search query parameter support
- Use SQLite `LIKE` for text search
- Search across: `title`, `notes`, `tags.name` (via JOIN)
- Case-insensitive search: `LOWER(title) LIKE LOWER(?)`

**Example query structure:**
```sql
SELECT DISTINCT tasks.*
FROM tasks
LEFT JOIN task_tags ON tasks.id = task_tags.task_id
LEFT JOIN tags ON task_tags.tag_id = tags.id
WHERE tasks.deleted_at IS NULL
  AND tasks.completed = ?
  AND (
    -- Search query (if provided)
    LOWER(tasks.title) LIKE LOWER('%query%')
    OR LOWER(tasks.notes) LIKE LOWER('%query%')
    OR LOWER(tags.name) LIKE LOWER('%query%')
  )
  AND (
    -- Tag filters (existing logic)
    ...
  )
```

### 3. UI Components

**Search Field Location:**
- **App bar** - Magnifying glass icon (collapsed state)
- **Tap icon** → Expands to search TextField
- **Similar to Material Design search pattern**

**Component Structure:**
```
HomeScreen AppBar
├─ Leading: App icon (if needed)
├─ Title/Search:
│   ├─ Default: "Pin and Paper" title + search icon
│   └─ Expanded: TextField with clear button
└─ Actions: Filter button, Reorder button, Brain Dump, Settings
```

**Search TextField Features:**
- Auto-focus when expanded
- Clear button (X) when text entered
- Submit on Enter key or search icon tap
- Collapse on cancel
- Preserve search query when collapsed (show chip like filters)

### 4. Active Filter Bar Updates

**Current state (Phase 3.6A):**
- Shows selected tag chips
- Shows "Clear All" button
- Handles tag removal

**Updates needed:**
- Add search query chip (if search active)
- "Search: [query]" with X button to clear
- Position search chip first (before tag chips)
- Clear All clears both search and tag filters

### 5. Search Experience Flow

**User Journey:**
1. Tap magnifying glass icon
2. Search field expands, keyboard appears
3. Type query, press Enter (or tap search icon)
4. Search query applies, results update
5. Search chip appears in filter bar
6. Can add tag filters on top of search
7. Can remove search via chip X button or collapse field

**Empty Results:**
- Show "No tasks match your search" message
- Offer to clear search or adjust filters
- Consistent with existing empty filtered view

---

## Dependencies

### From Previous Phases:
- ✅ FilterState model (Phase 3.6A)
- ✅ TaskProvider filter management (Phase 3.6A)
- ✅ ActiveFilterBar widget (Phase 3.6A)
- ✅ getFilteredTasks() method (Phase 3.6A)

### External Dependencies:
- None (uses existing Flutter widgets and sqflite)

---

## Database Changes

**None required!** ✅

- Existing schema supports search
- `title` and `notes` fields already indexed
- Tag search via existing `task_tags` and `tags` tables
- Search uses WHERE clauses, no schema changes needed

---

## Key Features

### Must-Have (MVP):
- ✅ Search field in app bar (expandable)
- ✅ Search across title, notes, and tag names
- ✅ Case-insensitive search
- ✅ Integration with existing filters (combined queries)
- ✅ Search query chip in active filter bar
- ✅ Clear search functionality
- ✅ Empty results state

### Nice-to-Have (Future):
- ⏸️ Search history/suggestions
- ⏸️ Advanced search syntax (e.g., `tag:work due:today`)
- ⏸️ Search highlighting in results
- ⏸️ Search performance metrics/analytics

---

## Performance Considerations

### Query Optimization:
- Use `LIKE` with indexed columns (title, notes already indexed)
- DISTINCT to avoid duplicate results from tag JOIN
- Limit search to reasonable result sets (existing pagination if needed)

### Expected Performance:
- Search query should complete <50ms for typical dataset (100-1000 tasks)
- Tag JOIN may slow down for 10,000+ tasks, but acceptable for target use case
- Can optimize later with FTS (Full Text Search) if needed

### Testing Targets:
- 100 tasks: <10ms
- 1,000 tasks: <50ms
- 5,000 tasks: <100ms (stretch goal)

---

## Testing Strategy

### Unit Tests:
- FilterState with searchQuery field
- JSON serialization with search query
- FilterState.isActive includes search check

### Service Tests:
- getFilteredTasks() with search query parameter
- Search across title only
- Search across notes only
- Search across tag names
- Search combined with tag filters
- Case-insensitive search verification

### Widget Tests:
- Search icon tap expands field
- Typing query updates state
- Submit applies search
- Cancel clears and collapses
- Clear button removes search

### Integration Tests:
- Full search flow (tap → type → submit → results)
- Search + filter combination
- Clear search via chip X button
- Empty results state

### Manual Testing:
- Search responsiveness on device
- Keyboard interactions
- Search + filter combinations
- Edge cases (special characters, very long queries)

---

## Timeline Estimate

**Total: 3-5 days**

### Day 1: Search State & Database (Foundation)
- Update FilterState model with searchQuery
- Update TaskService.getFilteredTasks() to support search
- Write unit tests for FilterState changes
- Write service tests for search queries
- **Milestone:** Search backend functional

### Day 2: Search UI (App Bar)
- Implement expandable search field in HomeScreen AppBar
- Search icon → TextField expansion/collapse
- Submit on Enter, clear button
- Connect to TaskProvider filter state
- **Milestone:** Search UI functional

### Day 3: Filter Bar Integration
- Add search chip to ActiveFilterBar
- Position search chip first
- Wire up remove search functionality
- Update "Clear All" to include search
- **Milestone:** Full integration complete

### Day 4: Testing & Polish
- Complete automated test suite
- Manual testing on device
- Performance validation
- Empty results state polish
- Edge case handling
- **Milestone:** Feature complete

### Day 5: Validation & Documentation (Buffer)
- Team validation
- Bug fixes if any
- Implementation report
- **Milestone:** Phase 3.6B validated ✅

---

## Success Criteria

**Feature is complete when:**

1. ✅ User can tap magnifying glass to open search
2. ✅ Search field expands/collapses smoothly
3. ✅ Typing and submitting query shows filtered results
4. ✅ Search works across title, notes, and tag names
5. ✅ Search is case-insensitive
6. ✅ Search query combines with existing tag filters
7. ✅ Search chip appears in active filter bar
8. ✅ User can clear search via chip X button
9. ✅ "Clear All" clears both search and filters
10. ✅ Empty results show helpful message
11. ✅ All automated tests passing
12. ✅ Performance targets met (<50ms typical search)
13. ✅ Manual testing validates UX

---

## Open Questions

**For BlueKitty to clarify:**

1. **Search field placement:**
   - Option A: App bar (replaces title when expanded) ← **Recommended**
   - Option B: Below app bar (persistent search field)
   - Option C: Floating search button (FAB-style)

2. **Search query persistence:**
   - Should search query persist across app restarts?
   - Or clear on app close (filter state persists, search doesn't)?

3. **Search scope:**
   - Search only title + notes + tags? ← **Recommended for MVP**
   - Or also include parent task breadcrumbs?
   - Or also include due dates (e.g., "tomorrow")?

4. **Empty search query behavior:**
   - Empty = show all tasks (current behavior) ← **Recommended**
   - Empty = show placeholder/hint
   - Empty = disable search until user types

5. **Search results ordering:**
   - Maintain current task ordering (position/hierarchy) ← **Recommended**
   - Or prioritize by relevance (title match > notes match > tag match)?

---

## Risk Mitigation

### Risk: Search too slow on large datasets
**Mitigation:**
- Profile query performance with 5,000 tasks
- Add database indexes if needed
- Consider FTS (Full Text Search) for future optimization
- Start with simple LIKE queries (good enough for MVP)

### Risk: Search UX feels clunky
**Mitigation:**
- Follow Material Design search patterns
- Smooth animations for expand/collapse
- Clear visual feedback for search active state
- Manual testing on device before validation

### Risk: Search + filter combination confusing
**Mitigation:**
- Clear visual separation (search chip first)
- Helpful empty state messages
- "Clear All" makes it easy to reset
- Tooltips or help text if needed

---

## Out of Scope (Deferred)

**Not in Phase 3.6B:**
- ⏸️ Search history or suggestions
- ⏸️ Advanced search syntax (operators like AND, OR, NOT)
- ⏸️ Search highlighting in results
- ⏸️ Saved searches or search presets
- ⏸️ Search analytics or metrics
- ⏸️ Voice search
- ⏸️ Search within specific task fields (title-only search)

**Why deferred:** Focus on MVP search that works well. Can add advanced features in Phase 3.6C if needed.

---

## Implementation Notes

### FilterState Changes:
```dart
// Before (Phase 3.6A)
class FilterState {
  final List<String> selectedTagIds;
  final FilterLogic logic;
  final TagPresenceFilter presenceFilter;
}

// After (Phase 3.6B)
class FilterState {
  final String searchQuery;  // NEW - defaults to ''
  final List<String> selectedTagIds;
  final FilterLogic logic;
  final TagPresenceFilter presenceFilter;

  bool get hasSearchQuery => searchQuery.trim().isNotEmpty;
  bool get isActive => hasSearchQuery || selectedTagIds.isNotEmpty || presenceFilter != TagPresenceFilter.any;
}
```

### TaskService Query Pattern:
```dart
Future<List<Task>> getFilteredTasks(
  FilterState filter, {
  required bool completed,
}) async {
  final conditions = <String>[];
  final args = <dynamic>[];

  // Existing: completed filter
  conditions.add('tasks.completed = ?');
  args.add(completed ? 1 : 0);

  // Existing: deleted filter
  conditions.add('tasks.deleted_at IS NULL');

  // NEW: Search query
  if (filter.hasSearchQuery) {
    conditions.add('''
      (LOWER(tasks.title) LIKE ?
       OR LOWER(tasks.notes) LIKE ?
       OR LOWER(tags.name) LIKE ?)
    ''');
    final searchPattern = '%${filter.searchQuery.toLowerCase()}%';
    args.addAll([searchPattern, searchPattern, searchPattern]);
  }

  // Existing: Tag filters
  // ... (existing tag filter logic)

  final query = '''
    SELECT DISTINCT tasks.*
    FROM tasks
    LEFT JOIN task_tags ON tasks.id = task_tags.task_id
    LEFT JOIN tags ON task_tags.tag_id = tags.id
    WHERE ${conditions.join(' AND ')}
    ORDER BY tasks.position ASC
  ''';

  return await db.rawQuery(query, args);
}
```

---

## References

**Related Phases:**
- [Phase 3.6A Implementation Report](../archive/phase-3.6A/phase-3.6A-implementation-report.md) - Tag filtering foundation
- [Phase 3.5 Summary](../archive/phase-03/phase-3.5-summary.md) - Comprehensive tagging system

**Templates:**
- [phase-start-checklist.md](../templates/phase-start-checklist.md) - Phase initiation workflow
- [WORKFLOW-SUMMARY.md](../templates/WORKFLOW-SUMMARY.md) - Development cycle reference

**Project Documentation:**
- [README.md](../../README.md) - Phase 3.6B scope and current project status

---

**Prepared By:** Claude
**Status:** Draft v1 - Ready for BlueKitty's review
**Next Step:** Refine plan based on feedback → Create v2 if needed → Begin implementation
