# Phase 3.2 Implementation: Task Nesting & Hierarchical UI

**Subphase:** 3.2
**Status:** 🔄 IN PROGRESS
**Started:** 2025-12-22
**Estimated Duration:** 3-5 days

---

## Quick Links

- **Detailed Spec:** [group1.md](./group1.md) (Lines 726-844)
- **Database Schema:** Already implemented in Phase 3.1 (parent_id, position columns)
- **Bug Tracker:** [phase-03-bugs.md](./phase-03-bugs.md)
- **Team Findings:** [codex-findings.md](./codex-findings.md), [gemini-findings.md](./gemini-findings.md)

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
   - Store preference in user_settings

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
- [ ] Implement `getTaskHierarchy()` - Load full task tree
- [ ] Implement `getTaskWithChildren()` - Load single task + children
- [ ] Implement `updateTaskPosition()` - Reorder within parent
- [ ] Implement `updateTaskParent()` - Change nesting level (with validation)
- [ ] Implement `deleteTaskWithChildren()` - CASCADE delete with count
- [ ] Add 4-level depth validation

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
- [ ] Create custom tile for tree view
- [ ] Implement drag handles (visible in reorder mode)
- [ ] Handle vertical drag (position change)
- [ ] Handle horizontal drag (parent change)
- [ ] Visual feedback during drag
- [ ] Snap to valid drop targets

#### Context Menu
- [ ] Implement long-press detection
- [ ] Create context menu bottom sheet/popup
- [ ] Add all menu actions (9 total)
- [ ] Implement CASCADE delete confirmation dialog
- [ ] Implement auto-complete children dialog
- [ ] Wire up to TaskService methods

#### Testing
- [ ] Unit tests: Hierarchical query logic
- [ ] Unit tests: Position management
- [ ] Unit tests: Depth validation
- [ ] Widget tests: TreeView rendering
- [ ] Widget tests: Reorder mode UI
- [ ] Widget tests: Context menu
- [ ] Integration test: Create nested tasks
- [ ] Integration test: Reorder tasks
- [ ] Integration test: Delete parent with children
- [ ] Integration test: Auto-complete children flow

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
