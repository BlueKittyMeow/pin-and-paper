# Phase 3 Final Plan (3.6-3.8)

**Date:** 2026-01-09 (Updated from 2025-01-05)
**Status:** Phase 3.5 ✅ COMPLETE - Executing Plan
**Strategy:** Leverage tag momentum, then complete date/notification features

---

## Completed Work

### Phase 3.5: Comprehensive Tagging System ✅ (Complete: Jan 9, 2026)
- Database v6 with tags and task_tags tables
- 160+ tests (100% passing)
- WCAG AA compliant colors
- Smart overflow handling (3 tags + "+N more")
- **Fix #C3:** Completed task hierarchy preserved for Phase 4
- Context menu refinements (right-click support)
- Breadcrumb visual indicators (↳ icon + italic)
- Version: `v3.5.0` tagged and released

---

## Approved Phase Order

### Phase 3.6A: Tag Filtering (1 week) ⭐ NEXT
**Why first:** Just completed comprehensive tag system in 3.5, strike while iron is hot!

**Features:**
1. **Clickable Tag Chips**
   - Click any tag chip → filter by that tag immediately
   - Works in main task list and completed task list
   - Visual feedback (highlighted when active filter)

2. **Tag Filter Dialog**
   - Filter icon in top bar (🏷️ or filter icon)
   - Opens tag selection dialog
   - Multi-select tags (checkboxes)
   - AND/OR logic toggle
     - AND: "Show tasks with ALL selected tags"
     - OR: "Show tasks with ANY selected tags"
   - Tag count display ("Work (12 tasks)")

3. **Active Filter Bar**
   - Shows currently selected tags as chips
   - Click X on chip to remove filter
   - "Clear all filters" button
   - Persists across app navigation (within session)

4. **Filter by Tag Presence**
   - "Show only tasks with tags" checkbox
   - "Show only tasks without tags" checkbox
   - Combine with specific tag filters

**Technical:**
- No database migration needed (all data exists)
- Enhanced TaskProvider with filter state
- FilterState model (selected tags, AND/OR mode, hasTag/noTag flags)
- Filter UI components (TagFilterDialog, ActiveFilterBar)
- Query builder in TaskService for filtered results

**Why this is perfect timing:**
- Tag infrastructure is fresh in mind
- Completes the tag feature (tags aren't useful if you can't filter by them!)
- Quick win: Clickable tags work in week 1!
- Natural extension of 3.5 work

**Estimated Time:** 1 week (5-7 days)
**Database Version:** Still v6 (no schema changes)

---

### Phase 3.6B: Universal Search (1-2 weeks)
**Why second:** Build on tag filtering infrastructure with text search

**Features:**
1. **Search UI**
   - Magnifying glass icon (🔍) in top bar
   - Search dialog with text input
   - Filter checkboxes:
     - ☐ All tasks
     - ☐ Current tasks (active/incomplete)
     - ☐ Recently completed
     - ☐ Completed (all)
   - Combine search with tag filters from 3.6A

2. **Search Capabilities**
   - Search by task title
   - Search in notes field
   - Search in tag names
   - Fuzzy matching (already have string_similarity package)
   - Case-insensitive search
   - Highlight matching text in results

3. **Search Results UI**
   - Grouped by section (Active / Completed)
   - Show hierarchy breadcrumb for context
   - Click result → navigate to task
   - Show match context (snippet of where match found)
   - Sort by relevance score

4. **Advanced Filtering** (if time permits)
   - Filter by parent/child (root tasks, subtasks, etc.)
   - Date-based filtering (due today, this week, overdue)
   - Save filter presets (stretch goal)

**Technical:**
- Add search indexes for performance:
  ```sql
  CREATE INDEX idx_tasks_title ON tasks(title);
  CREATE INDEX idx_tasks_notes ON tasks(notes);
  ```
- SearchService layer for query building
- Fuzzy matching with string_similarity package
- Search result ranking algorithm
- Search history (optional, store in SharedPreferences)

**Why after tag filtering:**
- Tag filtering infrastructure (filter state, UI) already built
- Can reuse filter bar and state management
- Search combines naturally with tag filters
- More complex than tag filtering (fuzzy matching, ranking)

**Estimated Time:** 1-2 weeks (7-10 days)
**Database Version:** Still v6 (add indexes, no schema changes)

**Enhancements from Fix #C3 Validation:**
- Universal search includes completed tasks (not just active)
- Search includes titles, notes, AND tags
- Combined with tag filters for powerful queries

---

### Phase 3.6.5: Edit Task Modal Rework (1 week) ⚠️ **REQUIRED BEFORE 3.7**

**Why required:** Current edit modal only allows title changes. Need comprehensive modal before adding natural language date parsing.

**Features:**
1. **Comprehensive Edit Modal for Active Tasks**
   - Edit all fields: title, due date, notes, tags, parent selector
   - Natural language date input field (ready for Phase 3.7)
   - Tag picker integration
   - Parent task picker (change hierarchy)
   - All-day event toggle, start date, notification settings

2. **Completed Task Metadata View** (HIGH priority)
   - Click completed task → open read-only modal
   - Display created/completed timestamps with duration calculation
   - Full hierarchy breadcrumb (not just parent)
   - Tags (clickable to filter)
   - Notes/descriptions
   - Actions: "View in Context", "Uncomplete", "Delete Permanently"
   - **Foundation for Phase 4 "card view" in spatial desk GUI**

3. **Show Completed Parents with Incomplete Children** (optional)
   - Display in completed section with visual indicator (⚠️ icon + badge)
   - Click to navigate to active task list
   - Highlight parent task in context

**Technical:**
- Refactor EditTaskDialog to support multiple modes (edit/view)
- Add timestamp display utilities
- Duration calculation helper
- "View in Context" navigation logic
- Read-only field styling for completed tasks

**Estimated Time:** 1 week (5-7 days)
**Database Version:** Still v6 (no schema changes)

**References:**
- `archive/phase-03/phase-3.6-and-3.6.5-enhancements-from-validation.md`
- Identified during Fix #C3 validation testing

---

### Phase 3.7: Natural Language Date Parsing (1-2 weeks)

**Features:**
1. **Relative Date Parsing**
   - "tomorrow" → tomorrow's date
   - "next Tuesday" → next occurrence of Tuesday
   - "in 3 days" → 3 days from now
   - "2 weeks from now" → 14 days out

2. **Absolute Date Parsing**
   - "Jan 15" → January 15th of current/next year
   - "March 3rd" → March 3rd
   - "12/25" → December 25th

3. **Time-of-Day Support**
   - "tomorrow at 3pm" → date + 3:00 PM
   - "next Tuesday morning" → date + 9:00 AM
   - "Friday evening" → date + 6:00 PM
   - Default times: morning (9am), afternoon (2pm), evening (6pm)

4. **"Today Window" Setting** (Night Owl Mode)
   - Handle midnight boundary intelligently
   - Default: 3-hour window (2am → still "today", not "tomorrow")
   - User configurable in settings (0-6 hours)
   - Example: At 1am, "tomorrow" means the date after current day
   - Example: At 1am with 3-hour window, "today" still means current day

5. **Integration Points**
   - Brain Dump: Parse dates from natural language
   - Add Task: Quick date entry field
   - Edit Task: Natural language date picker
   - Show parsed result before confirming ("Did you mean Jan 5, 2026?")

**Technical:**
- DateParserService with pattern matching
- Regular expressions for common patterns
- Timezone awareness (use device timezone)
- Handle edge cases (leap years, month boundaries, ambiguous dates)
- Integration with existing due_date field

**Examples:**
```
"Buy milk tomorrow" → due_date = 2025-01-06
"Call dentist next Tuesday at 2pm" → due_date = 2025-01-09 14:00
"Finish project in 2 weeks" → due_date = 2025-01-19
```

**Estimated Time:** 1-2 weeks
**Database Version:** Still v6 (due_date field already exists)

---

### Phase 3.8: Due Date Notifications (1-2 weeks)

**Features:**
1. **Local Notifications**
   - flutter_local_notifications package
   - Platform-specific setup (Android + iOS)
   - Notification permission handling
   - Icon and sound customization

2. **Notification Timing Options**
   - At due date/time (exact moment)
   - 15 minutes before
   - 1 hour before
   - 1 day before
   - Custom interval (user-defined)
   - Multiple notifications per task (e.g., 1 day + 1 hour)

3. **Notification Preferences**
   - Per-task notification type (stored in task.notification_type)
   - Per-task notification time (stored in task.notification_time)
   - Global defaults in settings
   - Quiet hours (don't notify between 10pm - 8am, configurable)
   - Different sounds for different priorities (optional)

4. **Notification Actions**
   - Tap notification → open task in app
   - Quick complete from notification (Android)
   - Snooze options (15min, 1hr, tomorrow)
   - Dismiss notification

5. **Smart Scheduling**
   - Schedule notifications when task created/edited
   - Reschedule all on app start (handle device reboot)
   - Cancel notifications when task completed
   - Cancel notifications when task deleted
   - Update notifications when due date changed

**Technical:**
- flutter_local_notifications package
- NotificationService layer
- Platform permissions (AndroidManifest.xml, Info.plist)
- Background task scheduling
- Notification ID management
- Integration with TaskService (create/update/delete hooks)

**Database Fields Already Exist:**
- `notification_type TEXT` (added in Phase 3.4)
- `notification_time INTEGER` (added in Phase 3.4)

**Estimated Time:** 1-2 weeks
**Database Version:** Still v6 (fields already exist!)

---

## Items Deferred to Future Phases

### Phase 6+: Widget & Voice Features
**Simple Widget (3-5 days):**
- Text input on home screen
- "Add Task" button
- Active task count
- Opens app with pre-filled text

**Complex Widget (Later):**
- Show task list in widget
- Checkboxes to complete from widget
- Multiple widget sizes (2x1, 4x1, 4x2)
- Full bidirectional sync
- iOS widget support

**Voice Input (Later):**
- speech_to_text integration
- Voice-to-task workflow
- Hands-free task capture

**Task Templates (Later):**
- Save common tasks as templates
- Template categories
- Quick create from template

**Quick Actions (Later):**
- Swipe gestures for common operations
- Custom swipe actions
- Configurable swipe behavior

---

## Final Timeline

### Completed:
1. ✅ Phase 3.5: Tagging System (Complete: Jan 9, 2026)
2. ✅ Fix #C3: Completed task hierarchy preserved
3. ✅ Manual validation: 9/9 tests passed
4. ✅ Git tag v3.5.0 created and pushed

### Phase 3.6A: Tag Filtering
- **Start:** Week of Jan 13, 2026
- **Duration:** 1 week (5-7 days)
- **Database:** v6 (no migration)
- **Tests:** Filter state tests, tag filter tests, UI tests

### Phase 3.6B: Universal Search
- **Start:** After 3.6A complete
- **Duration:** 1-2 weeks (7-10 days)
- **Database:** v6 (add indexes, no schema changes)
- **Tests:** Search tests, fuzzy matching tests, integration tests

### Phase 3.6.5: Edit Task Modal Rework ⚠️
- **Start:** After 3.6 complete
- **Duration:** 1 week (5-7 days)
- **Database:** v6 (no migration)
- **Tests:** Modal tests, metadata view tests
- **REQUIRED:** Must complete before 3.7

### Phase 3.7: Natural Language Date Parsing
- **Start:** After 3.6.5 complete
- **Duration:** 1-2 weeks
- **Database:** v6 (no migration)
- **Tests:** Date parser tests, integration tests

### Phase 3.8: Due Date Notifications
- **Start:** After 3.7 complete
- **Duration:** 1-2 weeks
- **Database:** v6 (no migration)
- **Tests:** Notification tests, scheduling tests

**Total Phase 3 Remaining:** 6-9 weeks
**Then:** 📦 Create GitHub Release (Phase 3 Complete) → Phase 4 (Workspace View)

---

## Success Criteria

### Phase 3.6A (Tag Filtering)
- ✅ Click any tag chip → immediately filters by that tag
- ✅ Tag filter dialog shows all tags with task counts
- ✅ Can filter by multiple tags (AND/OR logic works)
- ✅ Active filter bar shows selected tags
- ✅ Can remove individual filters or clear all
- ✅ Filters work on both active and completed tasks
- ✅ "Has tags" / "No tags" filters work
- ✅ Performance: Filter updates in <50ms for 1000 tasks

### Phase 3.6B (Universal Search)
- ✅ Search finds tasks by title, notes, and tags
- ✅ Fuzzy search works (finds "cal dentist" when searching "call")
- ✅ Combined filters work (search + tag filters from 3.6A)
- ✅ Performance: Search results in <100ms for 1000 tasks
- ✅ Clear search is obvious and works
- ✅ Universal search includes completed tasks
- ✅ Search results grouped by section (Active / Completed)
- ✅ Match highlighting works in results

### Phase 3.6.5 (Edit Task Modal Rework)
- ✅ Edit modal shows all task fields (title, due date, notes, tags, parent)
- ✅ Completed tasks open metadata view (read-only)
- ✅ Metadata view shows created/completed timestamps
- ✅ Duration calculation works correctly
- ✅ "View in Context" navigation works
- ✅ Clickable tags in modal filter by that tag
- ✅ Foundation ready for Phase 4 card view

### Phase 3.7 (Natural Language Date Parsing)
- ✅ Parses common relative dates ("tomorrow", "next week", "in 3 days")
- ✅ Parses absolute dates ("Jan 15", "March 3rd")
- ✅ Parses times ("3pm", "morning", "evening")
- ✅ Night owl mode works (configurable today window)
- ✅ Shows confirmation before setting parsed date
- ✅ Integration works in Brain Dump and Add Task

### Phase 3.8 (Due Date Notifications)
- ✅ Notifications fire at correct time
- ✅ Notification actions work (open task, complete, snooze)
- ✅ Quiet hours respected
- ✅ Notifications survive app restart
- ✅ Multiple notifications per task work
- ✅ Notifications cancelled when task completed/deleted

---

## Next Actions

### Completed (Jan 9, 2026):
1. ✅ Phase 3.5 implementation and validation complete
2. ✅ Manual testing: 9/9 test scenarios passed
3. ✅ Git tag v3.5.0 created and pushed
4. ✅ Phase 3.5 summary document created
5. ✅ PROJECT_SPEC.md updated with Phase 3.6-3.8 plan + GitHub release note
6. ✅ All Phase 3 docs archived to `archive/phase-03/`

### Next (Week of Jan 13, 2026):
1. 📋 Create `phase-3.6A-plan.md` (detailed implementation plan for Tag Filtering)
2. 🚀 Begin Phase 3.6A implementation (Tag Filtering)
3. 📝 Update docs/phase-03-status-review.md when starting 3.6A

---

## Why This Order Works

**3.6A (Tag Filtering) First:**
- Momentum from just completing tag system (3.5)
- Tags aren't useful without filtering capability
- Quick win in week 1 (clickable tags work!)
- Simpler than search (no fuzzy matching complexity)
- Natural extension of 3.5 infrastructure
- High immediate user value

**3.6B (Universal Search) Second:**
- Builds on filter state management from 3.6A
- Can reuse active filter bar UI
- Search naturally combines with tag filters
- More complex (fuzzy matching, ranking, indexes)
- Users already have filtering working from 3.6A

**3.6.5 (Edit Modal Rework) Third:**
- Current edit modal only allows title changes (blocker for 3.7)
- Need date picker UI before adding natural language parsing
- Completed task metadata view is HIGH user priority
- Foundation for Phase 4 spatial "card view" GUI
- Small scope (1 week) between major features
- **Critical blocker for 3.7 natural language dates**

**3.7 (Natural Language Dates) Fourth:**
- Requires comprehensive edit modal from 3.6.5
- Unblocks notifications (need dates to notify about)
- Smaller scope (1-2 weeks) after two larger phases
- Self-contained feature with clear boundaries
- High user value for quick date entry

**3.8 (Notifications) Fifth:**
- Requires date parsing from 3.7 to be useful
- Completes the "due date workflow" end-to-end
- Makes due dates actually actionable (not just metadata)
- Final polish before Phase 4
- Natural culmination of Phase 3

**Defer Widget/Voice to Phase 6+:**
- Widget: Nice-to-have, not essential to core workflow
- Voice: Can add anytime, not blocking other features
- Templates: Enhancement, not core functionality
- Focus on completing essential productivity features first
- Phase 4 (Spatial Workspace) is higher priority

---

**Status:** ✅ Phase 3.5 COMPLETE (v3.5.0) - Executing Approved Plan
**Next Step:** Create Phase 3.6 implementation plan, begin development

---

**Document History:**
- 2025-01-05: Initial plan approved by BlueKitty
- 2026-01-09: Updated with Phase 3.5 completion, added Phase 3.6.5, GitHub release note
- 2026-01-09: Subdivided Phase 3.6 into 3.6A (Tag Filtering) and 3.6B (Universal Search)

*Building the perfect task management system, one phase at a time.* 📌✨
