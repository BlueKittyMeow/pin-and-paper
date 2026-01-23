# Phase 3.6.5 Plan - Edit Task Modal Rework

**Version:** 1
**Created:** 2026-01-19
**Status:** Draft
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
  - 🆕 Notes/description field
  - 🆕 Tag management (inline)
  - 🆕 Parent task selector (change nesting)
- **UX Note:** Already agreed to remove confusing "+ Add Tag" chip; context menu only
- **Rationale:** Must have robust editing UI before adding natural language date parsing features

**2. Completed Task Metadata View (HIGH priority)**
- **Current limitation:** Clicking completed task does nothing
- **Add read-only metadata modal:**
  - Show: created/completed timestamps, duration calculation
  - Show: tags, notes, full hierarchy breadcrumb
  - Actions: "View in Context", "Uncomplete", "Delete Permanently"
- **Use case:** Task history, journaling, "temporal proof of existence" (core philosophy)
- **Foundation:** Will inform Phase 4 "card view" in spatial desk GUI

**3. Show Completed Parents with Incomplete Children (MEDIUM priority)**
- **Current behavior:** Completed parent disappears from completed list if children still active
- **Enhancement:**
  - Display completed parent in completed section even if children incomplete
  - Visual indicator: dimmed text, icon, or "X incomplete children" badge
  - Clicking navigates to active task list to show context
  - Optional: Make this a user preference

---

## Grouping Strategy

**This is a single-focus phase (no subphases):**
- Phase 3.6.5 implements all features together in one cohesive update
- Features are tightly coupled (edit modal + metadata view use similar UI patterns)
- Small enough scope for ~1 week implementation

**No separate grouping needed** (not Phase 3.6.5A/B/C)

---

## Technical Approach

### 1. Edit Modal Expansion

**Current implementation:**
- File: `pin_and_paper/lib/widgets/edit_task_dialog.dart` (likely - needs verification)
- Currently shows: TextField for title only

**Additions needed:**
- Due date picker widget (reuse from task creation if exists)
- Multi-line TextField for notes
- Tag picker integration (reuse from Phase 3.5)
- Parent selector dropdown/dialog (show task hierarchy, allow re-parenting)
- Form validation
- Cancel/Save buttons

**UI considerations:**
- May need ScrollView if content exceeds screen height
- Preserve existing "tap outside to dismiss" behavior
- Consider keyboard handling (especially for notes field)

### 2. Completed Task Metadata View

**New implementation:**
- Create new dialog: `completed_task_metadata_dialog.dart`
- Read-only display (no editing)
- Show all task fields + computed values (duration)
- Action buttons at bottom

**Data requirements:**
- Task model already has: created_at, completed_at, tags, notes (if implemented), parent_id
- Compute duration: `completed_at - created_at`
- Build breadcrumb: Traverse parent hierarchy (similar to Phase 3.6B breadcrumb logic)

**Actions:**
1. **View in Context:** Navigate to parent task in active list, expand hierarchy, highlight task
2. **Uncomplete:** Set completed=false, completed_at=null, move back to active list
3. **Delete Permanently:** Soft delete (set deleted_at) or hard delete (confirm with user)

### 3. Completed Parents Visual Indicator

**Implementation location:**
- File: `pin_and_paper/lib/widgets/task_item.dart` (likely)
- Modify completed task rendering

**Visual options:**
1. Dimmed text + "(3 incomplete children)" badge
2. Special icon (e.g., partially filled circle)
3. Different background color/opacity

**Navigation:**
- On tap: Switch to active tasks tab, expand parent, scroll to first incomplete child

---

## Dependencies

### Code Dependencies
- Phase 3.5 tagging system (for tag picker integration)
- Phase 3.4 due date functionality (for date picker)
- Phase 3.2 hierarchical display (for parent selector)
- Phase 3.6B breadcrumb logic (for hierarchy display in metadata view)

### Prerequisite Work
- ⚠️ **Verify Task.notes field exists** - PROJECT_SPEC mentions notes, but Phase 3.6B comments say "Task.notes not yet implemented"
  - If notes field doesn't exist: Add to Task model + database migration
  - If exists: Proceed with integration

### Blocking Phases
- **Phase 3.7** is blocked until this phase completes
- Phase 3.7 needs due date picker in edit modal for natural language parsing

---

## Timeline Estimate

**Total:** ~1 week (5-7 working days)

**Breakdown:**
- Day 1: Verify current edit modal, plan UI expansion, check Task.notes field
- Day 2-3: Expand edit modal (due date picker, notes, tags, parent selector)
- Day 4: Implement completed task metadata view
- Day 5: Add completed parent visual indicator + navigation
- Day 6-7: Testing, polish, bug fixes

**Uncertainty factors:**
- Task.notes field implementation (if needed): +1-2 days
- Parent selector complexity (if hierarchy deeply nested): +0.5-1 day

---

## Open Questions

1. **Task.notes field:** Does it exist in Task model? If not, needs schema migration (v8?)
2. **Edit modal size:** Will all fields fit on screen or need ScrollView?
3. **Parent selector UX:** Dropdown list? Tree picker? Simplified search?
4. **Completed parent indicator:** Which visual approach? (dimmed text, icon, badge, color)
5. **Uncomplete action:** Should it restore original position in hierarchy or move to bottom?
6. **Delete permanently vs soft delete:** Current system uses soft delete - keep consistent?

---

## Success Criteria

**Phase complete when:**
- ✅ Edit modal allows editing title, due date, notes, tags, and parent
- ✅ Completed task metadata view shows all task details and actions work
- ✅ Completed parents with incomplete children are visible with indicator
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
- Phase 3.6B (breadcrumb logic to reference)
- Phase 3.7 (blocked on this phase)

**Code to review:**
- `pin_and_paper/lib/models/task.dart` - Task model fields
- `pin_and_paper/lib/widgets/edit_task_dialog.dart` - Current edit modal (if exists)
- `pin_and_paper/lib/widgets/task_item.dart` - Task display logic
- `pin_and_paper/lib/services/database_service.dart` - Schema version, migrations

---

**Plan Status:** Draft v1 - Ready for review
**Next Step:** Review with BlueKitty → iterate → create detailed implementation plan
