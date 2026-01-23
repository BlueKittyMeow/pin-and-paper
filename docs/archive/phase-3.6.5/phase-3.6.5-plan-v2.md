# Phase 3.6.5 Plan - Edit Task Modal Rework

**Version:** 2
**Created:** 2026-01-19
**Updated:** 2026-01-20
**Status:** Ready for Implementation
**Blocking For:** Phase 3.7 (Natural Language Date Parsing)

---

## Scope

Phase 3.6.5 is a **required prerequisite** for Phase 3.7. The current edit task modal only allows changing the task title. This phase expands the edit modal to support comprehensive task editing and adds a metadata view for completed tasks.

**Source:** `docs/PROJECT_SPEC.md` lines 495-518

### Core Features

**1. Comprehensive Edit Modal (CRITICAL - Blocking for 3.7)**
- **Current limitation:** Can only edit task title
- **Expand to include:**
  - ✅ Title (already implemented)
  - 🆕 Due date picker (needed before Phase 3.7 natural language parsing)
  - 🆕 Notes/description field (requires migration v8 - field doesn't exist yet)
  - 🆕 Tag management (inline)
  - 🆕 Parent task selector (change nesting)
- **UX Note:** Already agreed to remove confusing "+ Add Tag" chip; context menu only
- **Rationale:** Must have robust editing UI before adding natural language date parsing features

**2. Completed Task Metadata View (HIGH priority)**
- **Current limitation:** Clicking completed task does nothing
- **Add read-only metadata modal:**
  - Show: created/completed timestamps, duration calculation
  - Show: tags, notes (when implemented), full hierarchy breadcrumb
  - Actions: "View in Context", "Uncomplete", "Delete Permanently"
- **Use case:** Task history, journaling, "temporal proof of existence" (core philosophy)
- **Foundation:** Will inform Phase 4 "card view" in spatial desk GUI

**3. Show Completed Parents with Incomplete Children (MEDIUM priority)**
- **Current behavior:** Completed parent disappears from completed list if children still active
- **Enhancement:**
  - Display completed parent in completed section even if children incomplete
  - Visual indicator: **Dimmed background box** (decision: v2)
  - NO strikethrough (reserved for actual completed tasks as distinguisher)
  - Clicking navigates to active task list to show context
- **Strikethrough convention (NEW - v2):**
  - ✅ Actual completed tasks: Strikethrough
  - ❌ Completed parents with incomplete children: NO strikethrough (visual distinction)

---

## Grouping Strategy

**This is a single-focus phase (no subphases):**
- Phase 3.6.5 implements all features together in one cohesive update
- Features are tightly coupled (edit modal + metadata view use similar UI patterns)
- Small enough scope for ~1 week implementation

**No separate grouping needed** (not Phase 3.6.5A/B/C)

---

## Technical Approach

### 0. Prerequisites - Add Task.notes Field (Migration v8)

**⚠️ CRITICAL DEPENDENCY:**
- Task.notes field **does NOT exist** in current schema (confirmed via code inspection)
- Database version: 7 (Phase 3.6B)
- **Must add before edit modal implementation**

**Implementation:**
```dart
// Task model (task.dart)
final String? notes; // Add to Task class

// Database migration v8 (database_service.dart)
Future<void> _migrateToV8(Database db) async {
  await db.execute('ALTER TABLE tasks ADD COLUMN notes TEXT');
}

// Update constants.dart
static const int databaseVersion = 8; // Phase 3.6.5: Edit Modal Rework
```

### 1. Edit Modal Expansion

**Current implementation:**
- File: `pin_and_paper/lib/widgets/edit_task_dialog.dart` (needs verification)
- Currently shows: TextField for title only

**Additions needed:**
- Due date picker widget (reuse from task creation if exists)
- Multi-line TextField for notes (3-5 lines, expandable)
- Tag picker integration (reuse from Phase 3.5)
- Parent selector with search (see section 1.1)
- Form validation
- Cancel/Save buttons

**UI considerations:**
- **Decision (v2):** Try without ScrollView first, add if needed during implementation
- Preserve existing "tap outside to dismiss" behavior
- Keyboard handling for notes field (multiline)

**Layout approach:**
```
┌─────────────────────────────┐
│ Edit Task                   │
├─────────────────────────────┤
│ Title: [TextField]          │
│                             │
│ Parent: [Search Selector]   │
│                             │
│ Due Date: [Date Picker]     │
│                             │
│ Tags: [Chip List + Picker]  │
│                             │
│ Notes:                      │
│ [MultiLine TextField]       │
│                             │
│                             │
│                             │
├─────────────────────────────┤
│     [Cancel]     [Save]     │
└─────────────────────────────┘
```

#### 1.1 Parent Selector Implementation

**Decision (v2):** Simplified search and select

**Approach:**
1. TextField with search icon
2. Type to filter task list (fuzzy search on titles)
3. Show filtered results in dropdown
4. Click to select
5. Show current parent name (with "Clear" button)

**Completed task display:**
- **Decision (v2):** Show with strikethrough AND dimmed text
- Allows selecting completed parent if needed
- Visual distinction prevents accidental selection

**Special cases:**
- "No Parent (Root Level)" option at top
- Current task excluded from list (can't parent to self)
- Children of current task excluded (can't create cycle)

### 2. Completed Task Metadata View

**New implementation:**
- Create new dialog: `completed_task_metadata_dialog.dart`
- Read-only display (no editing)
- Show all task fields + computed values (duration)
- Action buttons at bottom

**Data requirements:**
- Task model has: created_at, completed_at, tags, notes (after migration), parent_id
- Compute duration: `completed_at - created_at` → format as "X days Y hours"
- Build breadcrumb: Traverse parent hierarchy (reuse Phase 3.6B breadcrumb logic)

**Layout:**
```
┌─────────────────────────────┐
│ Task Details                │
├─────────────────────────────┤
│ Title: [Task title]         │
│                             │
│ Status: ✓ Completed         │
│                             │
│ Hierarchy: [Breadcrumb]     │
│                             │
│ Created: Jan 15, 2026       │
│ Completed: Jan 19, 2026     │
│ Duration: 4 days 3 hours    │
│                             │
│ Tags: [Chip] [Chip]         │
│                             │
│ Notes:                      │
│ [Notes text or "No notes"]  │
│                             │
├─────────────────────────────┤
│ [View in Context]           │
│ [Uncomplete]                │
│ [Delete Permanently]        │
└─────────────────────────────┘
```

**Actions:**
1. **View in Context:** Navigate to parent task in active list, expand hierarchy, scroll to uncompleted
2. **Uncomplete:**
   - **Decision (v2):** Restore original position in hierarchy
   - Set completed=false, completed_at=null
   - Restore position value, move back to active list
3. **Delete Permanently:**
   - **Decision (v2):** Keep soft delete system (30-day hard delete)
   - Set deleted_at timestamp
   - Move to "Recently Deleted" section

### 3. Completed Parents Visual Indicator

**Implementation location:**
- File: `pin_and_paper/lib/widgets/task_item.dart`
- Modify completed task rendering

**Visual approach (v2 DECISION):**
- **Dimmed background box** (reduce opacity 0.6)
- **NO strikethrough** (distinguishes from actual completed tasks)
- Badge: "(X incomplete children)" in gray text
- Regular completed tasks: Strikethrough + normal background

**Strikethrough convention (NEW):**
```dart
// Actual completed task (all children complete or no children)
Text(
  task.title,
  style: TextStyle(
    decoration: TextDecoration.lineThrough, // ✅ Has strikethrough
  ),
)

// Completed parent with incomplete children
Container(
  decoration: BoxDecoration(
    color: Colors.grey.withOpacity(0.3), // Dimmed box
  ),
  child: Text(
    task.title,
    // NO decoration: TextDecoration.lineThrough ❌
  ),
)
```

**Navigation:**
- On tap: Switch to active tasks tab, expand parent, scroll to first incomplete child
- Reuse Phase 3.6B scroll-to-task logic with highlighting

---

## Dependencies

### Code Dependencies
- Phase 3.5 tagging system (for tag picker integration)
- Phase 3.4 due date functionality (for date picker)
- Phase 3.2 hierarchical display (for parent selector)
- Phase 3.6B breadcrumb logic (for hierarchy display in metadata view)
- Phase 3.6B scroll-to-task (for "View in Context" navigation)

### Prerequisite Work
- ⚠️ **CONFIRMED:** Task.notes field does NOT exist
  - Add to Task model (String? notes)
  - Database migration v8: ALTER TABLE tasks ADD COLUMN notes TEXT
  - Update toMap() and fromMap() in Task model
  - Update copyWith() method

### Blocking Phases
- **Phase 3.7** is blocked until this phase completes
- Phase 3.7 needs due date picker in edit modal for natural language parsing

---

## Timeline Estimate

**Total:** ~1 week (5-7 working days)

**Breakdown:**
- **Day 1:** Add Task.notes field (migration v8), verify current edit modal implementation
- **Day 2-3:** Expand edit modal (due date picker, notes TextField, tags, parent selector)
- **Day 4:** Implement completed task metadata view with all actions
- **Day 5:** Add completed parent visual indicator (dimmed box, no strikethrough) + navigation
- **Day 6-7:** Testing, polish, handle edge cases, bug fixes

**Reduced uncertainty:**
- Task.notes implementation: Day 1 (no longer uncertain)
- Parent selector: Simplified search approach (reduced complexity)

---

## Design Decisions (v2)

### Open Questions - RESOLVED ✅

1. **Task.notes field:** ✅ Does NOT exist - add in migration v8 (Day 1)
2. **Edit modal size:** ✅ Try without ScrollView first, add if needed
3. **Parent selector UX:** ✅ Simplified search and select
4. **Completed parent indicator:** ✅ Dimmed background box, NO strikethrough
5. **Completed parent in selector:** ✅ Show with strikethrough AND dimmed
6. **Uncomplete action:** ✅ Restore original position in hierarchy
7. **Delete permanently:** ✅ Keep soft delete system (30-day hard delete)

### Strikethrough Convention (NEW - v2)

**Visual hierarchy for completed tasks:**
- **Fully completed task:** Strikethrough text
  - Task is marked complete AND (has no children OR all children complete)
  - Visual: Clear "done" indicator

- **Completed parent with incomplete children:** Dimmed box, NO strikethrough
  - Task is marked complete BUT has active children
  - Visual: Distinguishes "in progress subtree" from "fully done"

**Benefits:**
- Immediate visual distinction between "done" and "partially done"
- Strikethrough reserved for truly complete work
- Dimmed box indicates "hierarchical complexity" (has active children)

---

## Success Criteria

**Phase complete when:**
- ✅ Migration v8 adds Task.notes field to database and model
- ✅ Edit modal allows editing title, due date, notes, tags, and parent
- ✅ Parent selector shows simplified search with strikethrough for completed
- ✅ Completed task metadata view shows all task details and actions work
- ✅ "View in Context" navigates and highlights correctly
- ✅ "Uncomplete" restores original position in hierarchy
- ✅ "Delete Permanently" uses soft delete (deleted_at)
- ✅ Completed parents with incomplete children show dimmed box (NO strikethrough)
- ✅ Actual completed tasks have strikethrough (WITH strikethrough)
- ✅ Navigation from completed parent to active children works
- ✅ No regressions in existing task editing functionality
- ✅ All new UI follows existing design patterns (Material Design + Witchy Flatlay aesthetic)
- ✅ Build succeeds with 0 compilation errors
- ✅ Phase 3.7 can proceed (due date picker available in edit modal)

---

## References

**Planning docs:**
- `docs/PROJECT_SPEC.md` lines 495-518 (authoritative scope)
- `archive/phase-03/phase-3.6-and-3.6.5-enhancements-from-validation.md` (detailed user stories)
- `README.md` lines 160-162 (timeline and next steps)

**Related phases:**
- Phase 3.4 (task editing foundation)
- Phase 3.5 (tag picker to reuse)
- Phase 3.6B (breadcrumb logic and scroll-to-task to reference)
- Phase 3.7 (blocked on this phase)

**Code to review:**
- `pin_and_paper/lib/models/task.dart` - Task model (add notes field)
- `pin_and_paper/lib/widgets/edit_task_dialog.dart` - Current edit modal
- `pin_and_paper/lib/widgets/task_item.dart` - Task display logic (strikethrough convention)
- `pin_and_paper/lib/services/database_service.dart` - Add migration v8
- `pin_and_paper/lib/utils/constants.dart` - Update databaseVersion to 8

---

## Changes from v1

**Resolved Open Questions:**
- All 7 open questions answered with clear decisions
- Task.notes field status confirmed (does NOT exist)

**New Design Decisions:**
- Strikethrough convention formalized (completed tasks vs completed parents)
- Parent selector approach finalized (simplified search)
- Visual indicator specified (dimmed box, no strikethrough)
- Action behaviors clarified (restore position, soft delete)

**Reduced Uncertainty:**
- Timeline more accurate (Task.notes is Day 1 task)
- Technical approach refined with specific UI layouts
- Edge cases identified and handled

---

**Plan Status:** ✅ Ready for Implementation (v2)
**Next Step:** Begin implementation starting with Day 1 (migration v8)
