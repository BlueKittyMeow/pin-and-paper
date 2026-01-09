# Phase 3.6 & 3.6.5 Enhancement Planning (From Fix #C3 Validation)

**Created:** 2026-01-09
**Source:** Phase 3.5 Fix #C3 validation testing
**Status:** Planning / For Discussion

---

## Overview

During validation testing of Fix #C3 (Completed Task Hierarchy), several UX enhancements were identified that would improve the user experience. This document consolidates those suggestions and provides implementation recommendations.

---

## Phase 3.6: Tag Search & Filtering (Already Planned)

### Enhancements from Validation

**1. Universal Search (Magnifying Glass Icon)**

**Current State:**
- Quick search (⚡) only searches active/incomplete tasks
- No way to search completed tasks
- Search limited to task titles

**Requested Enhancement:**
```
Add magnifying glass icon (🔍) in top bar for universal search:
- Search box with filter checkboxes:
  □ All tasks
  □ Current tasks (active/incomplete)
  □ Recently completed
  □ Completed (all)

Search includes:
- Task titles
- Task notes/descriptions
- Tags
```

**User Story:**
> As a user, I want to search through all my tasks (active and completed) so I can find old work, reference past decisions, and see my history.

**Implementation Notes:**
- Add second icon in top bar (⚡ for quick complete, 🔍 for search)
- Search dialog with filter checkboxes
- Results grouped by section (Active / Completed)
- Highlight matching text
- Click result to navigate to task

**Priority:** HIGH - Already in Phase 3.6 scope, extend to include completed tasks

---

**2. Tag Filtering UI**

**Current State:**
- Tags display on tasks but clicking them does nothing
- No way to view all tasks with a specific tag
- No tag-based filtering

**Requested Enhancement:**
```
Add filter icon (⚙️ or 🏷️) in top bar:
- Opens tag selection dialog
- Select one or multiple tags
- View all tasks (active + completed) with selected tags
- AND/OR logic for multiple tags

Also:
- Make tag chips clickable (click to filter by that tag)
- Show tag count (e.g., "Work (12 tasks)")
```

**User Story:**
> As a user, I want to click a tag and see all tasks with that tag, so I can organize and view my work by category/project.

**Implementation Notes:**
- Clickable tag chips throughout app
- Tag selection dialog with multi-select
- AND/OR toggle for multiple tags
- Results show active and completed tasks with hierarchy preserved
- Quick filter bar (show selected tags, click X to remove)

**Priority:** HIGH - Core feature for Phase 3.6

---

## Phase 3.6.5: Edit Task Modal Rework + Metadata View

### Enhancements from Validation

**3. Completed Task Metadata View**

**Current State:**
- Clicking completed task does nothing
- No way to view full details of completed tasks
- Cannot see when task was created or completed
- Cannot view notes, tags, or original hierarchy

**Requested Enhancement:**
```
Click any completed task to open metadata view modal:

┌─────────────────────────────────────┐
│ Task Details                    [X] │
├─────────────────────────────────────┤
│ ✓ Buy groceries                     │
│                                     │
│ Created:    Jan 5, 2026 at 3:45 PM │
│ Completed:  Jan 6, 2026 at 9:12 AM │
│ Duration:   ~17 hours               │
│                                     │
│ Hierarchy:                          │
│ ↳ Shopping > Groceries > Buy groceries
│                                     │
│ Tags:                               │
│ [🔴 Urgent] [🟢 Personal]          │
│                                     │
│ Notes:                              │
│ Remember to get organic milk        │
│                                     │
│ [View in Context] [Uncomplete]     │
└─────────────────────────────────────┘
```

**Features:**
- **Read-only view** for completed tasks (unless user clicks "Uncomplete")
- **Created timestamp** - When task was originally created
- **Completed timestamp** - When task was marked complete
- **Duration** - Time between creation and completion (optional, nice-to-have)
- **Full hierarchy path** - Breadcrumb showing parent chain
- **Tags** - All tags with clickable chips to filter
- **Notes** - Full text of any notes/descriptions
- **Actions:**
  - "View in Context" - Navigate to active task list if parent exists
  - "Uncomplete" - Restore to active tasks
  - "Delete Permanently" - Remove from completed (soft delete to Recently Deleted)

**User Story:**
> As a user, I want to click on a completed task and see when I did it, how long it took, what tags it had, and any notes I wrote, so I can review my work history and see proof of my existence.

**Implementation Notes:**
- Reuse Edit Task Modal framework from Phase 3.4
- Add "read-only" mode for completed tasks
- Calculate duration from timestamps
- Show full breadcrumb (not just parent)
- Make tags clickable to filter
- Add "View in Context" button to navigate to active section

**Priority:** HIGH - Critical for task history and "temporal proof of existence"

**Related Feature:**
This modal should also work for **active tasks** (Phase 3.6.5 Edit Task Modal Rework):
- Active tasks show editable fields (title, due date, notes, tags, parent)
- Completed tasks show read-only view with metadata

---

**4. Show Completed Parents with Incomplete Children**

**Current State:**
- Parent task with incomplete descendants doesn't appear in completed section
- User marked parent complete but can't see it in completed list
- Logic is intentional (parent isn't "fully done") but can be confusing

**Validation Feedback (Test 3, line 209):**
> "SHOULD the parent task show up also in completed tasks? Right now, completing a parent shows it struck through in the regular task list but doesn't show it stricken in the completed task section."

**Requested Enhancement:**
```
Show completed parent in completed section with visual indicator:

COMPLETED TASKS
├─ ⚠️ Write report (2 incomplete)
│  ├─ ✓ Research data
│  ├─ ❌ Write conclusion (incomplete)
│  └─ ❌ Review draft (incomplete)

Alternative designs:
1. Dimmed text + warning icon
2. Badge showing "2 incomplete children"
3. Italicized with info icon
4. Color-coded (e.g., yellow = mixed state)

Clicking:
- Navigates to active task list
- Scrolls to and highlights the parent task
- Shows context with incomplete children
```

**User Story:**
> As a user, when I mark a parent task complete, I want to see it in my completed section even if some children are incomplete, because I consider that work done (even though subtasks remain). Clicking should show me the context in the active list.

**Implementation Notes:**
- Modify `completedTasksWithHierarchy` logic to include parents with `completed = 1` even if children incomplete
- Add visual indicator (icon, badge, dimmed text)
- Add tap handler to navigate to active list
- Highlight parent task when navigating (scroll to view + brief flash/glow)
- Consider user setting: "Show mixed-state parents in completed" (default: yes)

**Priority:** MEDIUM - Quality of life improvement, not critical

**Trade-offs:**
- **Pro:** User sees their completed work, feels accomplished
- **Pro:** Matches user mental model ("I finished the parent task")
- **Con:** "Completed" section shows tasks that aren't fully done
- **Con:** May confuse users ("why is this here if children incomplete?")

**Recommendation:** Implement with clear visual indicator and navigation. Make it a user preference if controversial.

---

**5. Truncate Long Titles During Drag** (Low Priority)

**Current State:**
- Very long task titles (200+ chars) display fully during drag
- Can cause visual clutter or layout issues

**Requested Enhancement:**
- Truncate task title during drag to ~100 characters + "..."
- Full title shows in normal view
- Improves drag-and-drop visual feedback

**Priority:** LOW - Edge case, minor polish

**Target:** Future polish phase (Phase 5+)

---

## Summary Table

| Enhancement | Phase | Priority | Complexity | Estimated Time |
|-------------|-------|----------|------------|----------------|
| Universal Search (🔍) | 3.6 | HIGH | Medium | 2-3 days |
| Tag Filtering UI | 3.6 | HIGH | Medium | 2-3 days |
| Completed Task Metadata View | 3.6.5 | HIGH | Medium-High | 3-4 days |
| Show Completed Parents (mixed state) | 3.6.5 or 4 | MEDIUM | Medium | 2-3 days |
| Truncate Long Titles (drag) | 5+ | LOW | Low | 1 day |

**Total for Phase 3.6:** ~4-6 days (search + filter)
**Total for Phase 3.6.5:** ~5-7 days (metadata view + completed parents + modal rework)

---

## Implementation Sequence

### Phase 3.6: Tag Search & Filtering (2-3 weeks)

**Week 1:**
- [ ] Universal search UI (magnifying glass icon + dialog)
- [ ] Search backend (query active + completed tasks)
- [ ] Filter checkboxes (All / Current / Completed)

**Week 2:**
- [ ] Tag filtering UI (filter icon + tag selection dialog)
- [ ] Clickable tag chips throughout app
- [ ] AND/OR logic for multiple tags

**Week 3:**
- [ ] Search results UI (grouped by section, highlighting)
- [ ] Tag count display ("Work (12 tasks)")
- [ ] Quick filter bar (show selected tags)
- [ ] Testing and polish

### Phase 3.6.5: Edit Task Modal Rework (1 week)

**Days 1-2:**
- [ ] Refactor Edit Task Modal to support multiple modes:
  - Edit mode (active tasks) - existing functionality
  - View mode (completed tasks) - new read-only mode
- [ ] Add completed task metadata fields:
  - Created timestamp
  - Completed timestamp
  - Duration calculation

**Days 3-4:**
- [ ] Add "View in Context" navigation
- [ ] Add full breadcrumb/hierarchy display
- [ ] Make tags clickable in modal
- [ ] Add "Uncomplete" and "Delete Permanently" actions

**Day 5:**
- [ ] (Optional) Implement "Show completed parents with incomplete children"
- [ ] Add visual indicator (icon, badge, dimmed text)
- [ ] Add navigation to active task list on click
- [ ] Testing and polish

---

## User Testing Questions

Before implementing, consider testing with users:

1. **Completed parents with incomplete children:**
   - Should they appear in completed section?
   - What visual indicator is clearest? (icon, badge, dimmed text, color)
   - Should this be a user preference?

2. **Search scope:**
   - Should default search include completed tasks, or require explicit filter?
   - Should search include notes/descriptions by default?
   - How should results be grouped/sorted?

3. **Tag filtering:**
   - Should clicking a tag immediately filter (one-click), or open selection dialog?
   - Should AND/OR logic be exposed, or automatically determined?
   - Should filters persist across app sessions?

---

## References

- **Source:** `docs/phase-03/phase-3.5-fix-c3-manual-test-plan.md` (Test 3, Test 8, Test 9)
- **Related:** `docs/PROJECT_SPEC.md` (Phase 3.6, Phase 3.6.5, Phase 4)
- **Context:** Fix #C3 validation identified these gaps during testing

---

**Document Status:** Draft - For Discussion
**Next Steps:**
1. Review with BlueKitty
2. Prioritize enhancements for Phase 3.6 and 3.6.5
3. Create detailed implementation plans
4. Update PROJECT_SPEC.md with final scope

**Maintained By:** Claude + BlueKitty
