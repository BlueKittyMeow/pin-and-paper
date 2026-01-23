# Phase 3 Revised Plan (3.6-3.8)

**Date:** 2025-01-05
**Status:** Planning
**Based on:** BlueKitty's priority feedback

---

## Background

**Completed So Far:**
- ✅ Phase 3.1: Task Nesting
- ✅ Phase 3.2: Hierarchical Display & Drag/Drop
- ✅ Phase 3.3: Recently Deleted (Soft Delete)
- ✅ Phase 3.4: Task Editing (due dates, notes)
- ✅ Phase 3.5: Comprehensive Tagging System

**Current Database:** v6

---

## Priority Classification

### MUST HAVE (Essential)
1. **Natural language date parsing** - "next Tuesday" → due date
2. **Search and tag filtering** - Find tasks quickly
3. **Notifications for due dates** - Actually get reminded

### SHOULD CONSIDER
4. **Home screen widget** - Quick capture (3-5 days for simple version)

### CAN DEFER (Update roadmap)
5. ~~Voice input~~ → Defer to Phase 6+
6. ~~Task templates~~ → Defer to Phase 6+

---

## Proposed Subphases

### Phase 3.6: Search & Filtering (2-3 weeks)

**Goal:** Make tasks discoverable and filterable

**Features:**
1. **Global Search**
   - Search by task title
   - Search in notes
   - Fuzzy matching (already have string_similarity package)
   - Search results screen with highlighting
   - Recent searches

2. **Tag-Based Filtering**
   - Filter by one or multiple tags (AND/OR logic)
   - "Show only tasks with tag X"
   - Combine with search
   - Filter UI in main screen

3. **Date-Based Filtering**
   - Show tasks due today
   - Show tasks due this week
   - Show overdue tasks
   - Date range picker for custom filtering

4. **Combined Filters**
   - Search + tags + dates
   - Save filter presets (optional stretch goal)

**Technical:**
- No database migration needed (all data exists)
- Add indexes for search performance:
  - `CREATE INDEX idx_tasks_title ON tasks(title)`
  - `CREATE INDEX idx_tasks_notes ON tasks(notes)`
- Provider methods for filtering
- Search service layer

**Estimated Time:** 2-3 weeks
**Database Version:** Still v6 (no schema changes)

---

### Phase 3.7: Natural Language Date Parsing (1-2 weeks)

**Goal:** Parse "next Tuesday" and set due dates intelligently

**Features:**
1. **Date Parser**
   - "tomorrow" → tomorrow's date
   - "next Tuesday" → next occurrence of Tuesday
   - "in 3 days" → 3 days from now
   - "Jan 15" → January 15th
   - "2 weeks from now" → 14 days out

2. **Time-of-Day Support**
   - "tomorrow at 3pm" → date + time
   - "next Tuesday morning" → date + 9am
   - Default times: morning (9am), afternoon (2pm), evening (6pm)

3. **"Today Window" Setting**
   - Handle midnight boundary for night owls
   - Default: 3 hours (so "tomorrow" at 2am means today+1, not today)
   - User configurable in settings

4. **Integration Points**
   - Brain dump screen: parse dates from text
   - Add task screen: natural language input
   - Edit task: quick date entry
   - Show parsed result before confirming

**Technical:**
- Use existing intl package for date formatting
- Create DateParserService
- Regular expressions for pattern matching
- Handle edge cases (leap years, month boundaries)
- Timezone awareness

**Key Challenges:**
- Ambiguous inputs ("Tuesday" - next or this week?)
- Relative dates ("in a month" from when?)
- User's effective "today" (night owl mode)

**Estimated Time:** 1-2 weeks
**Database Version:** Still v6 (no schema changes)

**Reference:** Already researched in Phase 3 planning docs

---

### Phase 3.8: Due Date Notifications (1-2 weeks)

**Goal:** Actually remind users about due dates

**Features:**
1. **Local Notifications**
   - Package: flutter_local_notifications
   - Platform-specific setup (Android, iOS)
   - Notification permissions handling

2. **Notification Types**
   - At due date/time
   - 1 hour before
   - 1 day before
   - Custom intervals (user configurable)

3. **Notification Settings**
   - Enable/disable notifications per task
   - Default notification type (store in task.notification_type)
   - Custom notification time (store in task.notification_time)
   - Global notification preferences

4. **Notification Actions**
   - Tap to open task
   - Quick complete from notification
   - Snooze options

5. **Background Scheduling**
   - Schedule notifications when task created/edited
   - Reschedule on app start (in case device rebooted)
   - Cancel when task completed/deleted

**Technical:**
- Database: notification_type and notification_time already exist (Phase 3.4)
- Add flutter_local_notifications package
- Platform-specific permissions (AndroidManifest.xml, Info.plist)
- Notification service layer
- Integration with TaskService

**Estimated Time:** 1-2 weeks
**Database Version:** Still v6 (fields already exist!)

---

### Phase 3.9: Home Screen Widget (3-5 days) [OPTIONAL]

**Goal:** Quick task capture without opening app

**Simple Version (Recommended):**
1. **Widget Features**
   - Text input field
   - "Add Task" button
   - Opens app with pre-filled text
   - Shows count of active tasks (optional)

2. **Widget Sizes**
   - Small (2x1): Just button + count
   - Medium (4x1): Input + button + count

3. **Interaction**
   - Tap input → opens app to add task screen with text
   - Tap count → opens app to main screen

**Technical:**
- Package: home_widget
- Android-specific (iOS widgets more complex, defer)
- Widget configuration activity
- Shared preferences for widget state
- No hot reload (slower development)

**Future Enhancement (Phase 6+):**
- Show list of recent tasks
- Checkboxes in widget
- Multiple widget types
- iOS widget support

**Estimated Time:** 3-5 days
**Database Version:** Still v6

---

## Revised Phase 3 Timeline

### Phase 3.6: Search & Filtering
- **Duration:** 2-3 weeks
- **Priority:** MUST HAVE
- **Complexity:** Medium-High

### Phase 3.7: Natural Language Date Parsing
- **Duration:** 1-2 weeks
- **Priority:** MUST HAVE (Essential!)
- **Complexity:** Medium

### Phase 3.8: Due Date Notifications
- **Duration:** 1-2 weeks
- **Priority:** MUST HAVE
- **Complexity:** Medium

### Phase 3.9: Home Screen Widget (Optional)
- **Duration:** 3-5 days
- **Priority:** SHOULD CONSIDER
- **Complexity:** Low-Medium

**Total Time:** 5-8 weeks (without widget) OR 5.5-9 weeks (with widget)

---

## Recommended Order

**Option A: Skip Widget for Now**
1. Phase 3.6: Search & Filtering (2-3 weeks)
2. Phase 3.7: Natural Language Date Parsing (1-2 weeks)
3. Phase 3.8: Notifications (1-2 weeks)
4. **→ Move to Phase 4: Workspace View**
5. Add widget later if needed

**Total:** 5-8 weeks, then Phase 4

**Option B: Include Simple Widget**
1. Phase 3.6: Search & Filtering (2-3 weeks)
2. Phase 3.7: Natural Language Date Parsing (1-2 weeks)
3. Phase 3.8: Notifications (1-2 weeks)
4. Phase 3.9: Simple Widget (3-5 days)
5. **→ Move to Phase 4: Workspace View**

**Total:** 5.5-9 weeks, then Phase 4

**Option C: Reorder for Quick Win**
1. Phase 3.7: Natural Language Date Parsing (1-2 weeks) ← Quick win!
2. Phase 3.6: Search & Filtering (2-3 weeks)
3. Phase 3.8: Notifications (1-2 weeks)
4. Phase 3.9: Widget (3-5 days) [optional]
5. **→ Move to Phase 4**

**Total:** Same as Option B, but date parsing comes first

---

## My Recommendation

**Go with Option C (Reordered):**

**Why start with date parsing?**
- It's ESSENTIAL (you emphasized this)
- Smaller scope (1-2 weeks vs 2-3 weeks)
- Quick win builds momentum
- Can use it immediately in Brain Dump
- Unblocks notifications (need dates to notify)

**Why defer widget?**
- Only saves 30 seconds vs opening app
- Less impactful than search/dates/notifications
- Android-specific (doesn't help iPad/desktop)
- Can add anytime later
- Widget debugging is slower (no hot reload)

**Proposed Final Order:**
1. ✅ Fix test failures (today/tomorrow)
2. ✅ Manual test Phase 3.5 (tomorrow)
3. 🎯 **Phase 3.6: Natural Language Date Parsing** (1-2 weeks)
4. 🎯 **Phase 3.7: Search & Filtering** (2-3 weeks)
5. 🎯 **Phase 3.8: Notifications** (1-2 weeks)
6. ⏸️ **Defer widget to Phase 6+**
7. 🚀 **Phase 4: Workspace View** (4-5 weeks)

**Total before Phase 4:** 5-8 weeks

---

## Items to Defer (Update Roadmap)

**Move to Phase 6+ (Polish & Enhancement):**
- Voice input (speech_to_text)
- Task templates
- Home screen widget (if not done in 3.9)
- Quick actions (swipe gestures)

**These are valuable but not essential for core workflow**

---

## Next Actions

### Immediate:
1. ✅ Get your approval on this plan
2. Update PROJECT_SPEC.md with revised Phase 3 scope
3. Fix test failures (Option 3 from our plan)
4. Manual test Phase 3.5 (Option 2)

### This Week:
5. Create phase-3.6-plan.md (Natural Language Date Parsing)
6. Research date parsing libraries/patterns
7. Begin Phase 3.6 implementation

---

## Questions for You

1. **Do you approve Option C (Date Parsing → Search → Notifications, defer widget)?**
2. **Any changes to the proposed features in 3.6, 3.7, 3.8?**
3. **Should we include widget in Phase 3.9, or defer to Phase 6+?**
4. **Any other MUST HAVE features I'm missing?**

---

**Status:** Awaiting approval to proceed
**Next Step:** Get BlueKitty's sign-off, then fix tests and begin 3.6 planning
