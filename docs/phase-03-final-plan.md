# Phase 3 Final Plan (3.6-3.8)

**Date:** 2025-01-05
**Status:** APPROVED by BlueKitty
**Strategy:** Leverage tag momentum, then complete date/notification features

---

## Approved Phase Order

### Phase 3.6: Tag Search & Filtering (2-3 weeks) ⭐ NEXT
**Why first:** Just completed comprehensive tag system in 3.5, strike while iron is hot!

**Features:**
1. **Tag-Based Filtering**
   - Filter by single tag
   - Filter by multiple tags (AND logic: "has ALL these tags")
   - Filter by multiple tags (OR logic: "has ANY of these tags")
   - Quick filter buttons in main screen
   - Clear filters easily

2. **Global Search**
   - Search by task title
   - Search in notes field
   - Fuzzy matching (already have string_similarity package)
   - Search results screen with highlighting
   - Combine search with tag filters

3. **Advanced Filtering**
   - Show only active tasks
   - Show only completed tasks
   - Show only tasks with tags
   - Show only tasks without tags
   - Filter by parent/child (root tasks, subtasks, etc.)

4. **Date-Based Filtering** (if time permits, or move to 3.7)
   - Show tasks due today
   - Show tasks due this week
   - Show overdue tasks
   - Date range picker

**Technical:**
- No database migration needed (all data exists)
- Add search indexes for performance:
  ```sql
  CREATE INDEX idx_tasks_title ON tasks(title);
  CREATE INDEX idx_tasks_notes ON tasks(notes);
  ```
- Enhanced TaskProvider with filter state
- SearchService layer for query building
- Filter UI components

**Why this is perfect timing:**
- Tag infrastructure is fresh in mind
- Can test tag filtering immediately
- Completes the tag feature (tags aren't useful if you can't filter by them!)
- Users can immediately leverage their new tags

**Estimated Time:** 2-3 weeks
**Database Version:** Still v6 (no schema changes)

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

### Immediate (This Week):
1. ✅ Fix test failures (21 soft delete tests) - Today/Tomorrow
2. ✅ Manual test Phase 3.5 tags - Tomorrow
3. ✅ Update PROJECT_SPEC.md - This week

### Phase 3.6: Tag Search & Filtering
- **Start:** Next week
- **Duration:** 2-3 weeks
- **Database:** v6 (no migration)
- **Tests:** Search tests, filter tests, integration tests

### Phase 3.7: Natural Language Date Parsing
- **Start:** After 3.6 complete
- **Duration:** 1-2 weeks
- **Database:** v6 (no migration)
- **Tests:** Date parser tests, integration tests

### Phase 3.8: Due Date Notifications
- **Start:** After 3.7 complete
- **Duration:** 1-2 weeks
- **Database:** v6 (no migration)
- **Tests:** Notification tests, scheduling tests

**Total Phase 3 Remaining:** 5-8 weeks
**Then:** Phase 4 (Workspace View) or Phase 6 (Widget/Voice/Templates)

---

## Success Criteria

### Phase 3.6 (Tag Search & Filtering)
- ✅ Can filter tasks by one or multiple tags
- ✅ Search finds tasks by title and notes
- ✅ Fuzzy search works (finds "cal dentist" when searching "call")
- ✅ Combined filters work (search + tags + dates)
- ✅ Performance: Search results in <100ms for 1000 tasks
- ✅ Clear filters is obvious and works

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

### Today:
1. ✅ Update PROJECT_SPEC.md with Phase 3.6-3.8 plan
2. 🔧 Fix 21 failing soft delete tests (Option 3)

### Tomorrow:
3. 🧪 Manual test Phase 3.5 tag UI (Option 2)

### Next Week:
4. 📋 Create phase-3.6-plan.md (detailed implementation plan)
5. 🚀 Begin Phase 3.6 implementation

---

## Why This Order Works

**3.6 (Tags) First:**
- Momentum from just completing tag system
- Tags aren't useful without filtering
- Can test and validate tags work well
- Natural extension of 3.5

**3.7 (Dates) Second:**
- Unblocks notifications (need dates to notify)
- Smaller scope (1-2 weeks)
- Self-contained feature
- High user value

**3.8 (Notifications) Third:**
- Requires date parsing to be useful
- Completes the "due date workflow"
- Makes due dates actually actionable
- Final polish before Phase 4

**Defer Widget/Voice:**
- Widget: Nice-to-have, not essential workflow
- Voice: Can add anytime, not blocking other features
- Templates: Enhancement, not core functionality
- Focus on completing essential features first

---

**Status:** ✅ APPROVED - Ready to proceed
**Next Step:** Fix test failures, then start Phase 3.6 planning

---

*Building the perfect task management system, one phase at a time.* 📌✨
