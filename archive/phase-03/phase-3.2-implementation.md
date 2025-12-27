# Phase 3.2 Implementation: Task Nesting & Hierarchical UI

**Subphase:** 3.2
**Status:** 🔄 IN PROGRESS
**Started:** 2025-12-22
**Updated:** 2025-12-22 (v2 - Incorporated Gemini/Codex review feedback)
**Estimated Duration:** 3-5 days

---

## Quick Links

- **Detailed Spec:** [group1.md](./group1.md) (Lines 726-844)
- **Review Feedback:** [phase-3.2-review-v1.md](./phase-3.2-review-v1.md)
- **Database Schema:** Already implemented in Phase 3.1 (parent_id, position columns)
- **Bug Tracker:** [phase-03-bugs.md](./phase-03-bugs.md)
- **Team Findings:** [codex-findings.md](./codex-findings.md), [gemini-findings.md](./gemini-findings.md)

---

## Review Feedback Incorporated (v2)

This document has been updated to address feedback from Gemini and Codex:

**✅ HIGH Priority (Addressed):**
1. Added recursive CTE specification with exact reference to group1.md:1508-1578
2. Expanded integration tests with 15+ specific scenarios
3. Added sibling reindexing (`_reindexSiblings()`) to TaskService checklist
4. Documented cycle detection (`_wouldCreateCycle()`) with error handling

**✅ MEDIUM Priority (Addressed):**
5. Added horizontal drag logic details (30/40/30 hover zones)
6. Specified updateTaskParent validation rules explicitly
7. Documented auto-complete enum values (prompt/always/never)
8. Expanded test coverage (cycles, reindexing, preferences)

**✅ LOW Priority (Addressed):**
9. Clarified DragAndDropTaskTile wraps TaskItem widget
10. Added future lazy-loading architectural note

---

## Scope

Phase 3.2 implements hierarchical task organization with visual nesting and drag-and-drop reordering.

### Features to Implement

1. **Hierarchical Query Methods** (TaskService)
   - Recursive queries for loading task trees
   - Parent-child relationship handling
   - 4-level depth limit enforcement

2. **Tree View UI** (HomeScreen)
   - AnimatedTreeView widget integration
   - 4-level visual hierarchy (markdown-style)
   - Collapsed by default on app launch
   - Expand/collapse controls

3. **Reorder Mode** (DragAndDropTaskTile)
   - Top bar button to enter/exit reorder mode
   - Drag handles visible in reorder mode
   - Drag left/right changes nesting level (parent_id)
   - Drag up/down changes position (within same parent)

4. **Context Menu** (Long press)
   - Edit task
   - Delete task (with CASCADE confirmation)
   - Save as template
   - Reschedule (date picker)
   - Convert to subtask / Promote to parent
   - Mark complete/incomplete
   - Duplicate task

5. **Auto-Complete Children Prompt**
   - Dialog when parent completed
   - "Remember my choice" checkbox
   - Store preference in user_settings (auto_complete_children field)
   - Valid values: `'prompt'` (ask each time), `'always'` (auto-complete), `'never'` (don't complete)
   - Default: `'prompt'`

6. **CASCADE Delete Protection**
   - Confirmation dialog: "Delete this task and its X subtasks?"
   - Secondary confirmation required
   - Applied to context menu delete and swipe-to-delete

---

## Implementation Checklist

### Prerequisites ✅
- [x] Database v4 migration complete (Phase 3.1)
- [x] Task model extended with parent_id, position, depth
- [x] UserSettings model with auto_complete_children preference
- [x] All HIGH/MEDIUM bugs fixed

### Phase 3.2 Tasks

#### TaskService - Hierarchical Queries
- [ ] Implement `getTaskHierarchy()` - Load full task tree using **recursive CTE**
  - Reference: `docs/phase-03/group1.md:1508-1578` (exact query specification)
  - Compute `depth` field dynamically (0-3)
  - Enforce 4-level depth limit in WHERE clause
  - Generate `sort_key` for hierarchical ordering (zero-padded)
- [ ] Implement `getTaskWithChildren()` - Load single task + children
- [ ] Implement `updateTaskPosition()` - Reorder within parent
- [ ] Implement `updateTaskParent()` - Change nesting level with validation:
  - **Cycle detection:** Use `_wouldCreateCycle()` helper (group1.md:1624-1688)
  - **Depth validation:** Prevent exceeding 4 levels
  - **Sibling reindexing:** Call `_reindexSiblings()` for source AND destination parents (group1.md:1693-1720)
  - Return errors as Result/Either (don't throw)
- [ ] Implement `_wouldCreateCycle()` - Cycle prevention helper
- [ ] Implement `_reindexSiblings()` - Contiguous position numbering helper
- [ ] Implement `deleteTaskWithChildren()` - CASCADE delete with count
- [ ] Add 4-level depth validation across all mutation operations

#### TaskProvider - State Management
- [ ] Add TreeController integration
- [ ] Add collapse/expand state management
- [ ] Add reorder mode state (isReorderMode boolean)
- [ ] Update loadTasks() to use hierarchical queries
- [ ] Add methods for tree operations (expand, collapse, move)

#### HomeScreen - UI Updates
- [ ] Replace ListView with AnimatedTreeView
- [ ] Add reorder mode toggle button (top bar)
- [ ] Implement expand/collapse controls
- [ ] Add visual depth indicators (indentation, styling)
- [ ] Default collapsed state on launch

#### DragAndDropTaskTile Widget
- [ ] Create custom tile that **wraps TaskItem widget**
  - DragAndDropTaskTile handles drag logic + affordances
  - TaskItem remains unchanged for consistent rendering
  - Promotes reusability and maintains single style source
- [ ] Implement drag handles (visible in reorder mode only)
- [ ] Handle vertical drag (position change within same parent)
- [ ] Handle horizontal drag (parent change) with hover zones:
  - **Top 30%:** Drop before target task (same level)
  - **Middle 40%:** Drop as child of target task (indent)
  - **Bottom 30%:** Drop after target task (same level)
  - Visual "ghost indent" indicator shows drop location
  - Reference: See detailed UX spec in tree-drag-drop integration notes
- [ ] Visual feedback during drag (highlight, ghost position)
- [ ] Snap to valid drop targets (enforce depth limits)
- [ ] Prevent invalid drops (cycles, depth violations)

#### Context Menu
- [ ] Implement long-press detection
- [ ] Create context menu bottom sheet/popup
- [ ] Add all menu actions (9 total)
- [ ] Implement CASCADE delete confirmation dialog
- [ ] Implement auto-complete children dialog
- [ ] Wire up to TaskService methods

#### Testing

**Unit Tests:**
- [ ] Hierarchical query logic (recursive CTE)
- [ ] Position management (reindexing)
- [ ] Depth validation (4-level limit)
- [ ] Cycle detection (`_wouldCreateCycle()`)
- [ ] Auto-complete preference persistence (prompt/always/never)

**Widget Tests:**
- [ ] TreeView rendering with nested data
- [ ] Reorder mode UI (toggle, drag handles)
- [ ] Context menu display and actions
- [ ] Visual depth indicators (indentation)

**Integration Tests - Reordering:**
- [ ] Drag subtask to root level (outdent)
- [ ] Drag root task to become subtask (indent)
- [ ] Reorder parent task with children (children move together)
- [ ] Move task from one parent to another
- [ ] Verify positions are contiguous after moves (sibling reindexing)

**Integration Tests - Depth & Cycles:**
- [ ] Attempt to create 5th level of nesting (should fail/prevent)
- [ ] Attempt to drag task under its own descendant (cycle prevention)
- [ ] Verify depth calculation after complex moves

**Integration Tests - Data Integrity:**
- [ ] Reload from database after reorder, verify position/parent_id correctness
- [ ] CASCADE delete with children, verify count and removal
- [ ] Auto-complete children flow with "remember choice" persistence

**Integration Tests - Edge Cases:**
- [ ] Move task between parents at different depths
- [ ] Reorder when parent has no other children
- [ ] Complete parent with nested descendants (auto-complete preference handling)

---

## Technical Decisions

### 1. TreeController vs Custom State
**Decision:** Use flutter_fancy_tree_view2's TreeController
**Rationale:**
- Built-in expand/collapse state management
- Efficient tree traversal
- Animation support
- Well-tested library

### 2. Reorder Mode Toggle
**Decision:** Top bar button (always visible)
**Rationale:**
- Clear entry/exit point
- Prevents accidental reordering
- Room for "Done" button to exit mode

### 3. Depth Field Storage
**Decision:** NOT persisted in database (computed on queries)
**Rationale:**
- Prevents data inconsistency
- Automatically correct on hierarchy changes
- Minimal overhead (computed in SQL query)

### 4. Default Collapsed State
**Decision:** All tasks collapsed on app launch
**Rationale:**
- Cleaner initial view
- User opens what they need
- Performance: fewer widgets rendered

### 5. Validation Strategy
**Decision:** Explicit validation with user-friendly error messages
**Cycle Prevention:**
- Use `_wouldCreateCycle()` helper before ANY parent change
- Traverse descendants recursively to detect if new parent is a descendant
- Surface errors via SnackBar/Toast (don't throw exceptions)

**Depth Enforcement:**
- Check depth before moving tasks
- Prevent operations that would exceed 4 levels
- Show clear error: "Cannot nest deeper than 4 levels"

**Sibling Reindexing:**
- Always run `_reindexSiblings()` after moves
- Ensures contiguous position values (0, 1, 2, 3...)
- Runs for BOTH source and destination parent lists

### 6. Future Lazy-Loading Consideration
**Out of scope for Phase 3.2, but architectural note:**
- Current implementation loads full tree on launch
- For very large task lists (100+ tasks), consider lazy-loading
- `flutter_fancy_tree_view2`'s TreeController supports async `childrenProvider`
- Future optimization: Load only root tasks initially, fetch children on expand
- Design with this in mind: keep `getTaskHierarchy()` separate from `getChildren(parentId)`

---

## Key Implementation References

**From group1.md (Detailed Spec):**

| Component | Lines | Description |
|-----------|-------|-------------|
| Recursive CTE Query | 1508-1578 | `getAllTasksHierarchical()` - Full hierarchical query with depth calculation |
| Cycle Detection | 1624-1688 | `_wouldCreateCycle()` - Prevents task becoming its own descendant |
| Sibling Reindexing | 1693-1720 | `_reindexSiblings()` - Ensures contiguous position values after moves |
| Update Task Parent | 1323-1344 | `updateTaskParent()` - Main parent-change method with validation |
| Auto-Complete Settings | Lines TBD | `auto_complete_children` field in UserSettings |
| Drag-Drop UX | Tree integration notes | 30/40/30 hover zones, ghost indicators |

**Error Handling Strategy:**
- Validation errors return `Result<T, Error>` or similar pattern
- Never throw exceptions for user actions (cycle/depth violations)
- Surface errors via SnackBar with clear messages
- Example: "Cannot create circular task dependencies"
- Example: "Maximum nesting depth (4 levels) reached"

---

## Files to Modify/Create

### New Files
- `lib/widgets/drag_and_drop_task_tile.dart` - Custom tree tile
- `lib/widgets/context_menu.dart` - Context menu component
- `lib/widgets/delete_confirmation_dialog.dart` - CASCADE delete dialog
- `lib/widgets/auto_complete_children_dialog.dart` - Parent completion dialog

### Modified Files
- `lib/services/task_service.dart` - Add hierarchical methods
- `lib/providers/task_provider.dart` - Add TreeController, reorder state
- `lib/screens/home_screen.dart` - Replace ListView with AnimatedTreeView
- `lib/widgets/task_item.dart` - Update for tree view integration

### Test Files
- `test/services/task_service_hierarchy_test.dart` - NEW
- `test/providers/task_provider_tree_test.dart` - NEW
- `test/widgets/drag_and_drop_task_tile_test.dart` - NEW
- `test/integration/nested_tasks_test.dart` - NEW

---

## Dependencies

### Required Packages (Already Added)
- `flutter_fancy_tree_view2: ^1.6.2` - Tree view widget

### No New Dependencies Needed
All other functionality uses existing packages.

---

## Progress Log

### 2025-12-22: Phase 3.2 Started
- ✅ Created phase-3.2-implementation.md
- ✅ All prerequisites verified
- ⏸️ Ready to begin implementation

---

## Known Issues / Blockers

**None currently.**

---

## Notes

- Phase 3.1 database migration provides all necessary schema support
- All critical bugs resolved before starting 3.2
- group1.md contains detailed specifications for all UI mockups and logic
- Coordinate with bug tracking docs for any issues found during implementation

---

**Next Step:** Start implementing hierarchical query methods in TaskService

**Assigned To:** Claude
**Review By:** BlueKitty, Codex, Gemini (ongoing)
