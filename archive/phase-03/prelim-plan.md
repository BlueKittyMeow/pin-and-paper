# Phase 3: Mobile Polish & Voice Input - Preliminary Planning

**Status:** Preliminary Planning (High-Level Strategy)
**Estimated Duration:** 3-4 weeks
**Database Version:** 3 → 4
**Target Device:** Samsung Galaxy S22 Ultra (Android)

---

## Planning Scope & Approach

**This document provides high-level preliminary planning for Phase 3.** It establishes:
- Overall architecture and database schema
- Major feature decisions and trade-offs
- Cross-subphase dependencies
- Basic implementation strategies

**Detailed implementation planning** will be created separately for each subphase group:
- **Group 1 (Foundation):** Detailed plans for 3.1, 3.2, 3.3 will specify exact file structures, function signatures, UI mockups, and line-by-line migration steps
- **Group 2 (Features):** Detailed plans for 3.4, 3.5 after Group 1 is complete
- **Group 3 (Polish):** Detailed plan for 3.6 as stretch goals

**This preliminary plan is intentionally high-level** to allow team review of the overall approach before diving into implementation details. Think of this as the "what and why," with detailed plans providing the "how."

---

## Overview

Phase 3 focuses on optimizing Pin and Paper for daily mobile use with voice input, task organization features (nesting, templates), and intelligent date parsing. This phase transforms the app from a functional MVP + AI tool into a daily-driver task manager that fits seamlessly into mobile workflows.

### Goals

1. **Voice Integration:** Enable hands-free task capture via voice-to-text
2. **Task Organization:** Add nesting/subtasks with collapsible groups
3. **Smart Dates:** Parse natural language dates ("next Tuesday", "tomorrow at 3pm")
4. **Mobile UX:** Quick actions, improved search, notifications
5. ~~**Quick Access:** Home screen widget~~ *(Deferred to Phase 4)*

### Recent Decisions (BlueKitty + Claude)

**✅ Resolved:**
- **Task nesting:** Max 4 levels, markdown-style hierarchy, collapsed by default on launch
- **Reorder mode:** Top bar button (always visible) enters drag-to-reorder mode
- **Context menu:** Long press shows menu (edit, delete, save as template, convert, etc.)
- **All-day dates:** Default when no time specified (not arbitrary time)
- **Time keywords:** Tonight/evening = 7pm, Morning = 9am, Afternoon = 3pm, Early morning/dawn = 5am
- **User customization:** Time keywords user-definable in settings (with Team Input on validation)
- **Today cutoff:** 4:59am default, configurable (night owl mode)
- **Midnight logic:** "midnight Thursday" = Friday 00:00; "midnight" alone = upcoming midnight
- **24-hour preference:** User can choose 12h vs 24h display (internal always 24h)
- **Images:** Add task_images table with hybrid caching strategy (file_path + source_url for Phase 6 notecard hero images)
  - Local cache in app private storage + optional remote URL tracking
  - Storage management UI deferred to Phase 6+ (long-term sustainability concern)
- **@mentions & #tags:** Add entities/tags tables in v3→v4 migration (future-proofing for Phase 5 filtering/search)
  - "ask @carol about color palette" → click @carol to see all related tasks
  - "#work #urgent call dentist" → filter/search by tags
  - UI implementation deferred to Phase 5
- **Brain Dump nesting:** Defer to Phase 4+ (requires full task tree visibility)
- **Brain Dump templates:** Skip entirely (Brain Dump is "loose text vomit mess")
- **Advanced templating:** Defer to Phase 3.5/4+ (custom fields, @assignees, template builder needs proper planning)
- **Voice input:** Brain Dump primary, device-based STT (simple, offline-first, privacy-friendly)
- **Notifications:** Default 9am, user-configurable
- **Home screen widget:** Defer to Phase 4 (multiple variants: large, medium, small)
- **Multi-day tasks (weekend, etc.):** Add start_date column for date range support
  - "weekend" → start_date = Sat (user's day start), due_date = Mon (end of user's Sunday)
  - All semantic parsing respects user's circadian day boundaries (default 4:59am cutoff)
  - Default view shows ALL tasks; "For Today" view filters by date range
  - Phase 7 calendar view: completed tasks stay visible (crossed out) regardless of hide-completed threshold
- **Voice latency:** No hard metric, focus on streaming UX and "feels fast" user experience
- **Weekday parsing:** Forward-looking logic ("this Friday" = next occurring Friday, never past)
  - Added `week_start_day` to user_settings (default Monday)
  - Subject to Todoist research refinement in Phase 3.1
  - Future: Onboarding quiz (Phase 4+) to infer user's natural time perception (see `docs/future/onboarding-quiz.md`)
- **Date parsing integration:** Context-aware hybrid approach (Brain Dump + manual creation)
  - Brain Dump: Send user_settings to Claude as context for intelligent date interpretation
  - Manual task creation: Todoist-style live parsing with visual feedback (highlight + hover tooltip)
  - Single source of truth: Both use same date_parser_service with user_settings
  - No conflicts: Claude interprets using user's time framework, parser uses same preferences
  - User control: Brain Dump → approval screen edits; Manual → live feedback + calendar fallback

**✅ Team Decisions (from prelim-feedback.md):**
- **Scope prioritization:** Search & Quick Actions marked as stretch goals (Phase 3.6)
- **Auto-complete children:** Prompt with "remember my choice" checkbox (store in user_settings)
- **Time keyword synonyms:** Added noon/lunch/midday, late night, weekend (with nuance - see Outstanding Questions)
- **Voice smart punctuation:** Toggle in settings (default ON), store raw transcript for revert option
- **Notifications:** Hybrid model (global default + per-task override) - added columns to schema
- **Chaos gremlin validation:** Enforce relative ordering with wrap-around schedule support + 24-hour radial UI
- **Search breadcrumbs:** Show "Parent » Child" context for subtask matches
- **CASCADE delete protection:** Confirmation dialog required ("Delete X subtasks?")
- **Position backfill:** Critical migration step to preserve task order
- **User settings structure:** Explicit columns (already implemented in schema)
- **Testing approach:** Continuous (write tests alongside code) + milestone gates (full suite at end of each sub-phase)
- **Migration testing:** Create db-migration-checklist.md with dry-run protocol

**🎉 All Planning Questions Resolved!**
All outstanding questions have been answered. Phase 3 planning is complete and ready for implementation.

### Implementation Approach: Hybrid Phased Planning

**Strategy:** Plan and review subphases in groups based on coupling, then implement sequentially.

**Group 1: Tightly Coupled Foundation (Plan & Review Together)**
- **Phase 3.1:** Database Migration (everything depends on this - one-way migration)
- **Phase 3.2:** Task Nesting (uses new DB schema from 3.1)
- **Phase 3.3:** Natural Language Date Parsing (core service used by Brain Dump, manual creation, and voice)

**Rationale:** These three subphases are tightly coupled. The database schema must be correct from the start (irreversible migration), and date parsing is a shared service used across multiple features. Planning them together allows the team to review the architecture holistically and catch cross-dependencies early.

**Group 2: Features Using Foundation (Plan & Review Together)**
- **Phase 3.4:** Voice Input (uses date parsing via Brain Dump integration)
- **Phase 3.5:** Notifications (uses user_settings from 3.1)

**Rationale:** These features build on the foundation from Group 1. Planning them together ensures they integrate properly with the core services.

**Group 3: Polish & Stretch Goals (Plan When Ready)**
- **Phase 3.6:** Search & Quick Actions (mostly independent, marked as stretch)

**Rationale:** This subphase is less tightly coupled and can be planned/reviewed separately when we reach it.

**Next Steps:**
1. Team review of this preliminary plan (Codex, Gemini feedback)
2. Create detailed implementation plans for Group 1 (3.1, 3.2, 3.3)
3. Team review of Group 1 plans together (cross-dependency check)
4. Implement Group 1 sequentially (3.1 → 3.2 → 3.3)
5. Repeat for Group 2, then Group 3

---

## Team Observations Review

### Technical Debt Identified (Codex & Gemini)

✅ **Acknowledged:**

1. **Brain Dump Provider Cleanup** (`lib/providers/brain_dump_provider.dart`)
   - Several `IMPLEMENTATION REMINDER FIX` comments remain
   - Need to use `AppConstants` for table names
   - Should address before Phase 3 work begins

2. **Test Coverage Gap**
   - Current tests limited to `test/widget_test.dart`
   - Need provider/service coverage for:
     - Brain dump flow
     - Task matching (fuzzy completion)
     - Draft handling
   - Adding tests now reduces regression risk for new features

3. **Services Directory Organization**
   - Currently flat with mixed responsibilities (API, database, business logic)
   - As we add voice + date parsing services, organize into:
     - `services/api/` - External API integrations
     - `services/data/` - Database operations
     - `services/features/` - Feature-specific logic

4. **Theme Extraction**
   - `lib/utils/theme.dart` is entirely static
   - Phase 3 may not need customization yet
   - But worth extracting palette configuration for Phase 6

### Key Insights (Codex & Gemini)

✅ **Design Considerations:**

1. **Task Nesting UI** (Gemini)
   - Need careful design for indented/collapsible tasks
   - Prototype within existing `TaskItem` widget and `HomeScreen` list
   - Consider: indent levels, expand/collapse affordances, visual hierarchy

2. **"Today Window" Concept** (Gemini)
   - Natural language date parsing must handle midnight boundary
   - Night-owl users: "tonight" at 2am means "tonight" (not last night)
   - User's effective "today" != calendar day
   - Encapsulate in dedicated service with configurable window (e.g., 4am cutoff)

3. **Database Migration Strategy** (Codex)
   - Prototype schema changes early (v3 → v4)
   - Don't let migration block Phase 3 delivery
   - Test migration path with realistic data

---

## Phase 3 Feature Breakdown

### Priority 1: Core Features (Must-Have)

#### 1. Task Nesting & Organization
**Goal:** Support subtasks with visual hierarchy

**Features:**
- Parent-child task relationships
- Indented display (visual nesting depth)
- Collapsible task groups (expand/collapse subtasks)
- **Reorder Mode:** Top bar button enters reorder mode for drag-to-nest/unnest and reordering
- **Context Menu:** Long press shows context menu (edit, delete, template, convert to subtask, etc.)
- Position tracking within parent

**Database Changes (v3 → v4):**
```sql
ALTER TABLE tasks ADD COLUMN parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE;
ALTER TABLE tasks ADD COLUMN position INTEGER DEFAULT 0;

CREATE INDEX idx_tasks_parent ON tasks(parent_id, position);
```

**Technical Challenges:**
- Recursive queries for task hierarchies
- Collapse state management (Provider)
- Visual depth indicators (indentation, connecting lines?)
- Task reordering with parent constraints
- Reorder mode UI (entering/exiting, visual feedback)

**UI Design:**
- ✅ Reorder mode via top bar button (always visible)
- ✅ Context menu via long press (edit, delete, template, convert, etc.)
- ✅ **Max depth: 4 levels** with markdown-style hierarchy styling
  - Level 1: Root tasks (standard styling)
  - Level 2: First-level subtasks (indented, lighter/smaller styling)
  - Level 3: Second-level subtasks (further indented, even lighter)
  - Level 4: Third-level subtasks (max depth, most subtle styling)
- ✅ **Standard view on launch:** Tasks NOT expanded (collapsed by default)
- Drag handle icons visible in reorder mode
- Exit reorder mode: "Done" button or back gesture

**Open UI Questions:**
- Expand/collapse icon placement? (leading or trailing?)
- How to show task count for collapsed groups? (e.g., "3 subtasks")
- Reorder mode visual changes? (drag handles, dimmed background, etc.)
- Visual indicators for nesting depth? (indentation + color + size + icons?)

---

#### 2. Natural Language Date Parsing
**Goal:** Parse "next Tuesday", "tomorrow at 3pm" into due dates using user's personal time framework

**Features:**
- **Context-aware parsing:** Uses user_settings for all date interpretation
- Relative date parsing (today, tomorrow, next week)
- Weekday parsing (Monday, next Friday) with forward-looking logic
- Time parsing (3pm, tonight, morning) using user's time keyword preferences
- **All-day default:** When no time specified, mark as all-day task (not arbitrary time)
- Night-owl mode ("today window" concept with user's day boundary)
- Multi-day tasks (weekend) with start_date + due_date ranges

**Implementation:**
- **Research:** Study Todoist's natural language parsing rules (day-of-week handling, ambiguity resolution, live parsing UI)
- Create `services/features/date_parser_service.dart` with user_settings integration
- Use existing `intl` package for date formatting
- Consider adding package like `jiffy` or custom parser
- Configurable "today cutoff" from user_settings (default 4:59am)

**Context-Aware Integration:**
- **Brain Dump:** Send user_settings to Claude as system context for intelligent date suggestions
- **Manual Task Creation:** Todoist-style live parsing with visual feedback (highlight + tooltip)
- **Single source of truth:** Both use same date_parser_service with user_settings
- **No conflicts:** Claude and parser interpret using same user preferences

**Today Window Logic:**
```dart
// User's effective "today" respects their schedule
// If it's 2am and cutoff is 4:59am, we're still in "yesterday"
DateTime getEffectiveToday(UserSettings settings) {
  final now = DateTime.now();
  final cutoffHour = settings.todayCutoffHour; // From user_settings
  final cutoffMinute = settings.todayCutoffMinute;

  // NOTE: Cutoff boundary is INCLUSIVE (e.g., 4:59am cutoff means 4:59:59 is still "yesterday")
  // Example with 4:59am cutoff:
  //   4:58am → still yesterday
  //   4:59am → still yesterday (inclusive)
  //   5:00am → today starts
  if (now.hour < cutoffHour ||
      (now.hour == cutoffHour && now.minute <= cutoffMinute)) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}
```

**Examples to Handle (with user context):**
- "next Tuesday" → next Tuesday (all-day), respects user's day boundary
- "tomorrow" → effective tomorrow (all-day, respecting user's cutoff)
- "tonight" → today at user's tonight_hour (7pm default, user-configurable)
- "tomorrow morning" → tomorrow at user's morning_hour (9am default)
- "3pm tomorrow" → specific date + time
- "this weekend" → start_date=Sat (user's day start), due_date=Mon (end of user's Sunday)
- "in 3 days" → relative offset (all-day)

**Technical Challenges:**
- Ambiguity ("this Friday" → resolved: forward-looking)
- Timezone handling (use device timezone)
- User preferences (stored in user_settings, passed to parser)
- Live parsing UX (highlight text, tooltip, calendar integration)

---

#### 3. Voice-to-Text Integration
**Goal:** Hands-free task capture via speech recognition

**Features:**
- Microphone button on Brain Dump screen
- Real-time voice transcription
- Append to existing text (not replace)
- Visual feedback (listening indicator)
- Error handling (permissions, network, accuracy)

**Implementation:**
- Package: `speech_to_text` (check MCP docs for latest API)
- Permissions: RECORD_AUDIO (Android)
- Handle offline gracefully (some STT requires network)

**UI Integration:**
- Floating mic button on Brain Dump screen
- Pulsing animation while listening
- Stop button to end transcription
- Show interim results (streaming text)

**Technical Challenges:**
- Permission flow (first-time use)
- Background noise handling
- Punctuation accuracy (may need manual editing)
- Offline vs online STT (device vs cloud)

---

### Priority 2: Mobile UX Enhancements (Should-Have)

#### 4. ~~Home Screen Widget~~ **[DEFERRED TO PHASE 4]**
**Goal:** Quick task capture without opening app

**Status:** ✅ **DEFERRED** - Phase 3 is already substantial. Multiple widget variants planned for Phase 4:
- **Large:** Input field + task list
- **Medium:** Task list only
- **Small:** Quick capture single line (possibly integrates Brain Dump)

**Original Plan:**
- Text input widget (tap to type, saves as task or draft)
- Quick view of today's tasks (top 5?)
- Tap widget to open app

**Why Deferred:**
- Highest-risk feature (Android widget debugging is painful, can't use hot reload)
- Phase 3 scope already ambitious with nesting, voice, dates, notifications
- Better to nail core features than rush widget

---

#### 5. Task Templates **[ADVANCED FEATURES DEFERRED TO PHASE 3.5/4+]**
**Goal:** Reusable task structures for common workflows

**Phase 3 Scope (Minimal):**
- Add `is_template` column to database (future-proofing only)
- **No UI implementation in Phase 3**

**Advanced Templating (Deferred to Phase 3.5/4+):**
This feature deserves its own mini-phase with proper planning. Planned capabilities:
- **Template categories:** General, Work, Personal + user-configurable
- **Custom fields:** @mention assignees, deadlines, tags, custom properties
- **Template builder UI:** Visual editor for creating sophisticated templates
- **Entity integration:** Link templates to @mentions (e.g., supervisor tasks with @staff)
- **Use case example:** "Supervise student staff" template with @person field, deadline, custom checklist

**Database Changes (Phase 3):**
```sql
ALTER TABLE tasks ADD COLUMN is_template INTEGER DEFAULT 0;
```
*(Already in schema - entities and tags tables also added for future integration)*

**Why Deferred:**
- Simple templates (just duplicate task) are not valuable enough
- Advanced templates need custom fields system (significant engineering)
- Would require template_fields table, field type support, builder UI
- Better to plan properly than rush incomplete feature

---

#### 6. Improved Search
**Goal:** Fuzzy matching for task search

**Features:**
- Search bar on Home Screen
- Fuzzy matching (not just substring)
- Search title, description, tags
- Highlight matches

**Implementation:**
- Extend existing fuzzy matching from Phase 2 (Levenshtein)
- Search service or integrate into DatabaseHelper
- Debounce search input (performance)

---

#### 7. Due Date Notifications
**Goal:** Remind users about upcoming tasks

**Features:**
- Local notifications for due dates
- Notification permissions
- Configurable notification time (day of? day before?)
- Tap notification → open task

**Implementation:**
- Package: `flutter_local_notifications`
- Schedule notifications when due date is set
- Cancel when task completed or due date removed
- Notification channel configuration (Android)

**Technical Challenges:**
- Notification permissions (Android 13+)
- Timezone handling
- Rescheduling on app updates
- Notification delivery reliability

---

#### 8. Quick Actions & Context Menu
**Goal:** Common operations via swipe and long-press

**Features:**
- **Swipe right** → complete task
- **Swipe left** → delete task (with confirmation)
- **Long press** → context menu with options:
  - Edit task
  - Delete task
  - Save as template
  - Reschedule (date picker)
  - Convert to subtask / Promote to parent
  - Mark complete/incomplete
  - Duplicate task

**Implementation:**
- `Dismissible` widget for swipe actions
- `showModalBottomSheet` or `PopupMenuButton` for context menu
- Contextual menu items based on task state
- Undo snackbar for destructive actions

---

### Priority 3: Technical Debt (Must Address)

#### 9. Cleanup & Testing

**Cleanup Tasks:**
- [ ] Remove `IMPLEMENTATION REMINDER FIX` comments from `brain_dump_provider.dart`
- [ ] Use `AppConstants` for all table names
- [ ] Organize `services/` directory into subdirectories
- [ ] Review and update code comments

**Testing Strategy:**
- [ ] Provider tests: `brain_dump_provider_test.dart`
- [ ] Service tests: `claude_service_test.dart`, `database_helper_test.dart`
- [ ] Fuzzy matching tests: `task_matcher_test.dart`
- [ ] Date parsing tests: `date_parser_service_test.dart`
- [ ] Widget tests: Task nesting UI, collapse/expand

**Test Coverage Goals:**
- Core business logic: 80%+
- UI widgets: 60%+
- Database operations: 70%+

---

## Database Migration Plan (v3 → v4)

### Schema Changes

```sql
-- Add task nesting support
ALTER TABLE tasks ADD COLUMN parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE;
ALTER TABLE tasks ADD COLUMN position INTEGER DEFAULT 0;

-- Add template support
ALTER TABLE tasks ADD COLUMN is_template INTEGER DEFAULT 0;

-- Add due date support (if not already present)
ALTER TABLE tasks ADD COLUMN due_date INTEGER; -- Unix timestamp
ALTER TABLE tasks ADD COLUMN is_all_day INTEGER DEFAULT 1; -- 1 = all-day, 0 = specific time
ALTER TABLE tasks ADD COLUMN start_date INTEGER; -- Unix timestamp, nullable (for multi-day tasks like "weekend")

-- Add notification support (hybrid model: global default + per-task override)
ALTER TABLE tasks ADD COLUMN notification_type TEXT DEFAULT 'use_global'; -- 'use_global', 'custom', 'none'
ALTER TABLE tasks ADD COLUMN notification_time INTEGER; -- Custom notification time (unix timestamp)

-- Create task images table (future-proofing for Phase 6)
-- Hybrid caching strategy: local cache + optional remote source URL
CREATE TABLE task_images (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  file_path TEXT NOT NULL,            -- Local cached path (app private storage)
  source_url TEXT,                    -- Original remote URL (null if uploaded from device)
  is_hero INTEGER DEFAULT 0,          -- 1 = hero image for notecard
  position INTEGER DEFAULT 0,         -- Order for multiple images
  caption TEXT,                       -- Optional caption
  mime_type TEXT NOT NULL,            -- Image validation (jpg, png, webp, etc.)
  file_size INTEGER,                  -- Size in bytes (reasonable limits)
  created_at INTEGER NOT NULL,
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- Create entities table for @mentions (future implementation: Phase 5)
-- Enables "ask @carol about color palette" → click @carol to see all related tasks
CREATE TABLE entities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,         -- e.g., "carol", "bob" (lowercase for matching)
  display_name TEXT,                 -- e.g., "Carol (Designer)", "Bob Smith"
  type TEXT DEFAULT 'person',        -- person, team, organization, etc.
  notes TEXT,                        -- Optional notes about this entity
  created_at INTEGER NOT NULL
);

-- Create tags table for #tags (future implementation: Phase 5)
-- Enables "#work #urgent call dentist" → filter/search by tags
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,         -- e.g., "urgent", "work", "personal" (lowercase)
  color TEXT,                        -- Optional color for tag display (hex code)
  created_at INTEGER NOT NULL
);

-- Many-to-many: tasks ↔ entities (@mentions)
CREATE TABLE task_entities (
  task_id TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (task_id, entity_id),
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

-- Many-to-many: tasks ↔ tags (#tags)
CREATE TABLE task_tags (
  task_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (task_id, tag_id),
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Create user settings table (structure TBD - see Team Input section)
-- Options: JSON blob vs explicit columns - pending Codex & Gemini input
CREATE TABLE user_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1), -- Single row table
  -- Time keyword preferences (validated for relative order, wrap-around schedules allowed)
  early_morning_hour INTEGER DEFAULT 5,  -- "early morning" / "dawn" = 5am
  morning_hour INTEGER DEFAULT 9,        -- "morning" = 9am
  noon_hour INTEGER DEFAULT 12,          -- "noon" / "lunch" / "midday" = 12pm
  afternoon_hour INTEGER DEFAULT 15,     -- "afternoon" = 3pm (15:00)
  tonight_hour INTEGER DEFAULT 19,       -- "tonight" / "evening" = 7pm (19:00)
  late_night_hour INTEGER DEFAULT 22,    -- "late night" = 10pm (22:00)
  -- Night owl settings
  today_cutoff_hour INTEGER DEFAULT 4,   -- "today" window cutoff = 4:59am
  today_cutoff_minute INTEGER DEFAULT 59,
  -- Week/calendar preferences
  week_start_day INTEGER DEFAULT 1,      -- 0=Sunday, 1=Monday, 2=Tuesday, etc. (default Monday)
  -- Timezone preferences (for DST-aware notification scheduling)
  timezone_id TEXT,                      -- IANA timezone ID (e.g., 'America/Detroit'), detected from device or user-specified
  -- Display preferences
  use_24hour_time INTEGER DEFAULT 0,     -- 0 = 12-hour display, 1 = 24-hour display
  -- Task behavior preferences
  auto_complete_children TEXT DEFAULT 'prompt', -- 'prompt', 'always', 'never'
  -- Notification preferences
  default_notification_hour INTEGER DEFAULT 9,   -- Default notification time = 9am
  default_notification_minute INTEGER DEFAULT 0,
  -- Voice input preferences
  voice_smart_punctuation INTEGER DEFAULT 1,     -- 1 = smart punctuation ON, 0 = raw
  -- Future: theme, additional preferences, etc.
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_tasks_parent ON tasks(parent_id, position);
CREATE INDEX idx_tasks_due_date ON tasks(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX idx_tasks_start_date ON tasks(start_date) WHERE start_date IS NOT NULL;
CREATE INDEX idx_tasks_template ON tasks(is_template) WHERE is_template = 1;
CREATE INDEX idx_task_images_task ON task_images(task_id, position);
CREATE INDEX idx_task_images_hero ON task_images(task_id) WHERE is_hero = 1;
CREATE INDEX idx_entities_name ON entities(name);
CREATE INDEX idx_tags_name ON tags(name);
CREATE INDEX idx_task_entities_entity ON task_entities(entity_id);
CREATE INDEX idx_task_entities_task ON task_entities(task_id);
CREATE INDEX idx_task_tags_tag ON task_tags(tag_id);
CREATE INDEX idx_task_tags_task ON task_tags(task_id);
```

### Migration Strategy

1. **Version Bump:** 3 → 4
2. **Backward Compatibility:** Null parent_id = root-level task
3. **Default Values:**
   - position = 0 (MUST backfill - see step 5)
   - is_template = 0
   - is_all_day = 1
   - start_date = NULL (most tasks are single-day)
   - notification_type = 'use_global'
   - notification_time = NULL
4. **New Tables:** task_images, entities, tags, task_entities, task_tags, user_settings (initialized with default row)
5. **CRITICAL: Position Backfill** - Existing tasks must be assigned monotonically increasing positions to preserve current visual order:
   ```sql
   -- Backfill positions based on created_at to maintain order
   -- IMPORTANT: Handles NULL parent_id correctly for top-level tasks
   UPDATE tasks
   SET position = (
     SELECT COUNT(*)
     FROM tasks AS t2
     WHERE (
       (t2.parent_id IS NULL AND tasks.parent_id IS NULL)
       OR (t2.parent_id = tasks.parent_id)
     )
       AND t2.created_at <= tasks.created_at
   ) - 1;
   ```
6. **User Settings Initialization:** Seed user_settings table (id=1) with current timestamps
7. **Future-Proofing:** Images, entities (@mentions), and tags (#tags) tables added now for Phase 5+ implementation
8. **Testing:** See `db-migration-checklist.md` for full testing protocol
9. **Rollback:** Not supported (document one-way upgrade, maintain backup)

### Data Integrity

**Tasks:**
- **CASCADE delete on parent removal** (deletes all children)
  - ⚠️ **MUST implement confirmation dialog:** "Delete this task and its X subtasks?"
  - Secondary confirmation required to prevent accidental tree deletion
  - Context menu and swipe-to-delete must both show this protection
- **Position ordering:** Unique within parent scope, monotonically increasing
  - Reorder mode adjusts position values
  - Drag left/right changes parent_id (nesting level)
  - Drag up/down changes position (within same parent)
- **Templates:** Should not have parent_id (root-level only, no nested templates)
- **Notifications:**
  - notification_type: 'use_global' (uses user_settings defaults), 'custom' (uses notification_time), 'none' (no notification)
  - notification_time: NULL when type='use_global' or 'none', unix timestamp when type='custom'
- **Multi-day tasks (date ranges):**
  - start_date: NULL for single-day tasks (default), unix timestamp for multi-day tasks
  - When start_date present: task spans [start_date, due_date] range
  - "weekend" parsing: start_date = Sat (user's day start), due_date = Mon (end of user's Sunday)
  - All date parsing respects user's circadian boundaries (today_cutoff_hour/minute from user_settings)
  - **Display logic:**
    - Default view: ALL tasks (no filtering)
    - "For Today" view: Show if today falls within [start_date OR due_date] range
    - Hide-completed threshold: Applies to list views, NOT to Phase 7 calendar/day planner view

**Task Images (Hybrid Caching Strategy):**
- **CASCADE delete** when task is deleted (removes all associated images)
- **Hybrid storage approach:**
  - `file_path`: Local cached copy in app private storage (always present)
  - `source_url`: Original remote URL (null if uploaded from device)
  - User uploads from device → copy to app storage, source_url = NULL
  - User provides URL → download and cache, store original URL
- **Storage location:** `/data/data/.../files/images/` (offline-first, no extra permissions)
- **Only one hero image per task** (enforce in app logic: is_hero=1 constraint)
- **Validate MIME types:** image/jpeg, image/png, image/webp, image/gif (common formats only)
- **File size limits:** TBD (reasonable size, with optional in-app seamless resize)
- **Position determines display order** for multiple images
- **Long-term sustainability:** See Outstanding Questions for storage management strategy (Phase 6+)

**User Settings:**
- Single row table (id = 1 enforced via CHECK constraint)
- Initialize with defaults on first app launch (must include created_at and updated_at timestamps)
- **Chaos gremlin protection (time keyword validation):**
  - Enforce hours in range 0-23
  - Enforce relative ordering (e.g., early_morning < morning < noon < afternoon < tonight < late_night)
  - **Allow wrap-around schedules** for shift workers (e.g., cycle can start mid-afternoon)
  - **Validation strategy (two-layer approach):**
    - **Settings UI:** Real-time warnings for invalid configurations (e.g., "morning_hour cannot be earlier than early_morning_hour")
    - **Database level:** No CHECK constraints (too complex for wrap-around logic) - rely on UI validation only
    - **Fail-safe:** App uses fallback defaults if invalid settings detected at runtime
  - **Settings UI:** Include 24-hour radial control or timeline preview to visualize user's shifted day
- **Auto-complete children preference:** 'prompt' (ask with remember choice), 'always', 'never'
- **Voice smart punctuation:** Default ON (1), user can disable (0) for raw transcription

**Entities (@mentions) - Future Phase 5:**
- CASCADE delete removes all task associations when entity deleted
- Lowercase name for case-insensitive matching ("@Carol" and "@carol" both match "carol")
- display_name for UI presentation ("Carol (Designer)")
- Entity types: person, team, organization (extensible for future)
- UI implementation deferred to Phase 5

**Tags (#tags) - Future Phase 5:**
- CASCADE delete removes all task associations when tag deleted
- Lowercase name for case-insensitive matching
- Optional color for visual categorization (hex codes)
- UI implementation deferred to Phase 5

**Task-Entity and Task-Tag Relationships:**
- Many-to-many (one task can have multiple @mentions and #tags)
- Composite primary key prevents duplicates
- CASCADE delete when either task or entity/tag is removed

---

## Implementation Phases

### Phase 3.1: Foundation & Database Migration
**Goal:** Technical debt cleanup + robust database migration with full testing

- [ ] **Research:** Study Todoist's natural language date parsing (day-of-week, ambiguity rules)
- [ ] Clean up `brain_dump_provider.dart` reminders (use AppConstants for table names)
- [ ] **OPTIONAL:** Reorganize `services/` directory structure (api/, data/, features/ subdirectories)
  - **Note:** Marked optional to reduce risk - if migration testing is complex, defer this cleanup
  - Lightweight refactor (just moving files), but mixing with high-risk migration complicates rollback
- [ ] **Database Migration (v3 → v4)** - See `db-migration-checklist.md` for full protocol
  - [ ] Add task nesting columns (parent_id, position)
  - [ ] Add template support (is_template)
  - [ ] Add due date columns (due_date, is_all_day, start_date)
  - [ ] Add notification columns (notification_type, notification_time)
  - [ ] **CRITICAL:** Position backfill (assign positions based on created_at)
  - [ ] Create task_images table (future-proofing for Phase 6)
  - [ ] Create entities table for @mentions (future-proofing for Phase 5)
  - [ ] Create tags table for #tags (future-proofing for Phase 5)
  - [ ] Create task_entities junction table (future-proofing for Phase 5)
  - [ ] Create task_tags junction table (future-proofing for Phase 5)
  - [ ] Create user_settings table and seed with defaults (id=1, timestamps)
  - [ ] Test migration on Phase 2 snapshot (dry run)
  - [ ] Verify all default values and constraints
- [ ] Set up date parser service skeleton (`services/features/date_parser_service.dart`)
- [ ] Update Task model with new fields (parent_id, position, due_date, is_all_day, start_date, notification_type, notification_time)
- [ ] **Testing (continuous):**
  - [ ] Write unit tests for migration position backfill logic
  - [ ] Write unit tests for Task model serialization (fromMap/toMap with new fields)
  - [ ] Write tests for existing features (brain dump flow, task matching, draft handling)
  - [ ] **End of phase:** Run full test suite + verify no Phase 1/2 regressions

**Note:** This phase may need to be split into separate milestones (migration + cleanup) to reduce regression risk

### Phase 3.2: Task Nesting & Hierarchy
**Goal:** Task nesting with visual hierarchy and reorder mode

- [ ] Implement task nesting database operations (recursive queries for trees)
- [ ] Build task nesting UI (4-level indent with markdown-style styling)
- [ ] Implement collapse/expand functionality (collapsed by default on launch)
- [ ] **Reorder mode implementation:**
  - [ ] Top bar button to enter/exit reorder mode
  - [ ] Drag handles visible in reorder mode
  - [ ] Drag left/right changes parent_id (nesting level)
  - [ ] Drag up/down changes position (within same parent)
  - [ ] Visual feedback (drag handles, possibly dimmed background)
- [ ] **Context menu implementation (long press):**
  - [ ] Edit task
  - [ ] Delete task (with CASCADE confirmation - see below)
  - [ ] Save as template
  - [ ] Reschedule (date picker)
  - [ ] Convert to subtask / Promote to parent
  - [ ] Mark complete/incomplete
  - [ ] Duplicate task
- [ ] **CASCADE delete protection:**
  - [ ] Confirmation dialog: "Delete this task and its X subtasks?"
  - [ ] Secondary confirmation required
  - [ ] Apply to both context menu delete and swipe-to-delete
- [ ] **Auto-complete children prompt:**
  - [ ] Dialog when parent completed: "Mark child tasks complete too?"
  - [ ] Remember choice checkbox (store in user_settings.auto_complete_children)
  - [ ] Easy "change later" link in settings
- [ ] Update TaskProvider categorization to handle hierarchical views
- [ ] **Testing (continuous):**
  - [ ] Write unit tests for recursive hierarchy queries
  - [ ] Write unit tests for position management (drag up/down, drag left/right)
  - [ ] Write unit tests for collapse/expand state management
  - [ ] Write unit tests for CASCADE delete logic
  - [ ] Write unit tests for auto-complete children prompt logic
  - [ ] Write widget tests for reorder mode UI
  - [ ] Write widget tests for context menu
  - [ ] **Integration test:** Verify migrated data maintains order when reopening list
  - [ ] **Integration test:** Create nested tasks, verify parent-child relationships persist
  - [ ] **Integration test:** Delete parent, verify children cascade delete with confirmation
  - [ ] **End of phase:** Run full suite + verify nesting doesn't break existing task operations

### Phase 3.3: Natural Language Date Parsing
**Goal:** Smart date parsing with night-owl support and user customization

- [ ] Implement date parser service (`services/features/date_parser_service.dart`)
- [ ] **Time keyword parsing** with synonyms:
  - [ ] early morning/dawn = 5am (default, user-configurable)
  - [ ] morning = 9am
  - [ ] noon/lunch/midday = 12pm
  - [ ] afternoon = 3pm
  - [ ] tonight/evening = 7pm
  - [ ] late night = 10pm
  - [ ] **weekend (multi-day task with date range):**
    - [ ] start_date = Sat (user's day start from cutoff)
    - [ ] due_date = Mon (end of user's Sunday, respects cutoff)
    - [ ] Example: 4:59am cutoff → weekend = Sat 4:59am to Mon 4:59am
    - [ ] Task shows in "For Today" view on both Saturday and Sunday
    - [ ] **Edge case - "weekend" on Saturday after cutoff (e.g., Sat 5:30am with 4:59am cutoff):**
      - [ ] Decision: "weekend" = THIS weekend (already started, due Mon 4:59am)
      - [ ] Rationale: User's effective "day" is Saturday, so "weekend" means current weekend
      - [ ] Alternative considered: "next weekend" (rejected - requires explicit "next" keyword)
      - [ ] Test case: Verify Saturday 5:30am → start_date = Sat 4:59am (past), due_date = Mon 4:59am (future)
  - [ ] midnight handling (see outstanding questions for nuance)
- [ ] **Today window logic** (4:59am cutoff, wrap-around support for shift workers)
- [ ] **All-day default** when no time specified
- [ ] **Relative date parsing** (today, tomorrow, next week, in 3 days)
- [ ] **Weekday parsing** ("next Tuesday", "this Friday" - use Todoist research for ambiguity)
- [ ] **Curate test fixture file:** `test/fixtures/date_parsing_test_cases.json`
  - [ ] Create structured test data with 20-30 phrases
  - [ ] Format: `{ "input": "tomorrow at 3pm", "expectedDate": "2025-11-01T15:00:00", "userSettings": {...}, "edgeCase": "night-owl boundary" }`
  - [ ] Include timezones, night-owl edges, weekend parsing, weekday ambiguity
  - [ ] Use for regression testing and accuracy validation (>80% target)
- [ ] **Brain Dump integration:**
  - [ ] Update Claude prompt to include user_settings as system context
  - [ ] Format: "User's time preferences: day boundary 4:59am, morning=9am, etc."
  - [ ] Test that Claude respects user's time framework in date suggestions
- [ ] **Manual task creation UI (Todoist-style):**
  - [ ] Implement live date parsing in task title field
  - [ ] Highlight detected date phrases as user types
  - [ ] Hover tooltip showing parsed date ("Thursday, November 7, 2025")
  - [ ] Click highlight → opens date picker pre-populated with parsed date
  - [ ] Calendar picker → removes/replaces text, updates date field
  - [ ] Alternative: Dedicated date field with text input + calendar picker
- [ ] **Testing (continuous):**
  - [ ] Write unit tests for each time keyword (early morning, noon, afternoon, tonight, late night)
  - [ ] Write unit tests for weekend multi-day parsing (start_date + due_date, user cutoff)
  - [ ] Write unit tests for "For Today" view filtering with date ranges
  - [ ] Write unit tests for relative dates (today, tomorrow, next week, in X days)
  - [ ] Write unit tests for weekday parsing (Monday, next Friday, this Tuesday)
  - [ ] Write unit tests for today window logic (4:59am cutoff, wrap-around)
  - [ ] Write unit tests for all-day vs specific time detection
  - [ ] Write unit tests for midnight handling
  - [ ] **Context-aware parsing tests:**
    - [ ] Test Brain Dump prompt includes user_settings correctly
    - [ ] Test Claude respects user's day boundary (2am + 4:59am cutoff = "today")
    - [ ] Test local parser produces same results as Claude for identical input
    - [ ] Test live parsing UI (highlight appears, hover tooltip works)
    - [ ] Test calendar picker overrides parsed date correctly
  - [ ] **Test fixture regression suite:** Run all 20-30 phrases, verify accuracy >80%
  - [ ] **Integration test:** Parse date from Brain Dump, verify task due_date set correctly
  - [ ] **Integration test:** Manual task creation with live parsing → correct due_date saved
  - [ ] **Edge case test:** User changes settings, existing task dates don't change retroactively
  - [ ] **End of phase:** Run full suite + verify date parsing doesn't break existing features

### Phase 3.4: Voice Input
**Goal:** Hands-free task capture with device-based STT (offline-first, privacy-friendly)

**Privacy Note:** Raw voice transcripts are NOT stored. Only the final text the user explicitly saves (as draft or task) persists in the database. No intermediate transcription data is retained.

- [ ] Integrate `speech_to_text` package (device-based STT via OS)
- [ ] Implement voice transcription with streaming interim results
- [ ] **Brain Dump integration:**
  - [ ] Floating mic button on Brain Dump screen
  - [ ] Pulsing animation while listening
  - [ ] Stop button to end transcription
  - [ ] Show interim results (streaming text)
  - [ ] Append to existing text (not replace)
- [ ] **Smart punctuation toggle (user preference):**
  - [ ] ✅ **RESEARCH COMPLETE:** `speech_to_text` v6.6.0+ supports `autoPunctuation` parameter in `SpeechListenOptions`
  - [ ] **Implementation:** Pass `autoPunctuation: true/false` based on user_settings.voice_smart_punctuation
  - [ ] **Privacy:** No storage required - punctuation applied during transcription, not post-processed
  - [ ] **User control:** Toggle in settings (default ON), affects live transcription only
  - [ ] Test on iOS (explicit support mentioned) and Android (device-dependent)
- [ ] Permission flow handling (RECORD_AUDIO)
  - [ ] Request permission on first mic button tap
  - [ ] Show friendly dialog if denied with Settings deep-link
- [ ] Error handling (permissions denied, STT initialization failures, background noise)
- [ ] **Testing (continuous):**
  - [ ] Write unit tests for permission flow handling
  - [ ] Write unit tests for streaming transcription display logic
  - [ ] Write unit tests for error handling (permissions denied, STT failures)
  - [ ] **Device testing:** Test on Galaxy S22 Ultra with various dictation scenarios
    - [ ] Short phrases ("call dentist tomorrow")
    - [ ] Long dictation (brain dump paragraph)
    - [ ] Background noise scenarios
    - [ ] Streaming interim results display
  - [ ] **Offline functionality - User validation (manual testing):**
    - [ ] BlueKitty tests on Galaxy S22 Ultra in airplane mode
    - [ ] Verify device-based STT works without internet connection
    - [ ] Confirm no unexpected network errors or degraded accuracy
    - [ ] Note: No automated offline tests - device dependency requires manual validation
  - [ ] **User experience testing:** BlueKitty qualitative feedback on responsiveness
    - [ ] Does streaming feel smooth and natural?
    - [ ] Is visual feedback (animations, interim text) satisfying?
    - [ ] Any janky UI states or freezes?
    - [ ] Overall: "feels fast" vs "feels laggy"
  - [ ] **Integration test:** Voice → text → Brain Dump → Claude → tasks (full flow)
  - [ ] **End of phase:** Run full suite + verify voice doesn't interfere with existing Brain Dump
- [ ] **Stretch:** Voice input on task edit/creation screens (pending team input)

### Phase 3.5: Notifications
**Goal:** Due date reminders with hybrid notification model

- [ ] Implement local notifications (`flutter_local_notifications`)
- [ ] **Timezone-aware scheduling (critical for DST/travel):**
  - [ ] Add `timezone` package dependency (uses IANA Time Zone Database)
  - [ ] Initialize tz database at app startup (`tz.initializeTimeZones()`)
  - [ ] Detect or store user's timezone (device timezone or user_settings)
  - [ ] Convert all due_date timestamps to `TZDateTime` for scheduling
  - [ ] Handle DST transitions automatically
  - [ ] Note: Timezone data updates via `flutter pub upgrade`
- [ ] **Hybrid notification model:**
  - [ ] Global default (9am, user-configurable in user_settings)
  - [ ] Per-task override (notification_type: use_global/custom/none)
  - [ ] notification_time for custom times
- [ ] Schedule notifications when due date is set
- [ ] Cancel notifications when task completed or due date removed
- [ ] Notification permissions handling (Android 13+)
- [ ] Tap notification → open task
- [ ] Notification channel configuration (Android)
- [ ] **Testing (continuous):**
  - [ ] Write unit tests for notification scheduling logic
  - [ ] Write unit tests for notification cancellation (task complete/due date removed)
  - [ ] Write unit tests for hybrid model (use_global vs custom vs none)
  - [ ] Write unit tests for global default from user_settings
  - [ ] **Device testing:** Verify notifications fire at correct time on Galaxy S22 Ultra
  - [ ] **Device testing:** Test tap notification → open task navigation
  - [ ] **Device testing:** Document Android battery optimization issues (if any)
  - [ ] **Integration test:** Set due date → notification scheduled → task completed → notification cancelled
  - [ ] **End of phase:** Run full suite + verify notifications don't break task operations

### Phase 3.6: Search & Quick Actions **[STRETCH GOALS]**
**Goal:** Enhanced search with hierarchy context + swipe gestures

**Note:** These are stretch goals for final phase. Only proceed once nesting/dates/voice/notifications meet QA.

- [ ] **Improved Search:**
  - [ ] Search bar on Home Screen
  - [ ] Fuzzy matching (reuse Phase 2 Levenshtein logic)
  - [ ] Search title, description, tags
  - [ ] Highlight matches
  - [ ] **Breadcrumb context:** Show "Parent » Child" for subtask matches
  - [ ] Debounce search input for performance
  - [ ] Test search latency (< 500ms target)
- [ ] **Quick Actions (swipe gestures):**
  - [ ] Swipe right → complete task
  - [ ] Swipe left → delete task (with CASCADE confirmation)
  - [ ] Undo snackbar for destructive actions
- [ ] **Testing (continuous):**
  - [ ] Write unit tests for fuzzy search algorithm (reuse Phase 2 logic)
  - [ ] Write unit tests for breadcrumb generation (Parent » Child)
  - [ ] Write widget tests for search bar UI
  - [ ] Write widget tests for swipe gestures
  - [ ] **Performance test:** Search latency with 100+ tasks (target <500ms)
  - [ ] **Integration test:** Search for nested task, verify breadcrumb shows correctly
  - [ ] **Integration test:** Swipe to delete parent, verify CASCADE confirmation
  - [ ] **End of phase:** Run FULL test suite (all phases 1-3)
- [ ] **Final phase testing:**
  - [ ] Regression test: Verify ALL Phase 1 features still work
  - [ ] Regression test: Verify ALL Phase 2 features still work
  - [ ] Integration test: Full user workflow (create → nest → date → voice → notify → search → complete)
- [ ] Update documentation (agents.md, PROJECT_SPEC.md)
- [ ] Phase wrap-up and consolidation

---

## Resolved Planning Questions

All outstanding questions have been answered. This section documents the final decisions for reference.

### Natural Language Date Parsing

**✅ RESOLVED: Context-aware hybrid parsing with single source of truth**

**Decision:** Hybrid approach with user_settings as shared context for both Brain Dump (Claude) and manual task creation (local parser). No conflicts because both systems interpret dates using the same user preferences.

#### Brain Dump Flow

**Send user_settings to Claude as system context:**
```
System context for task extraction:

User's time preferences:
- Day boundary: 4:59am (user's "day" extends past midnight)
- Week start: Monday
- Time keywords: "morning" = 9am, "tonight" = 7pm, "weekend" = Sat-Mon (user's day boundaries)
- Weekday logic: Forward-looking ("this Friday" = next occurring Friday)

User's brain dump:
[user's raw text here]

Extract tasks with due dates interpreted using the user's time framework above.
```

**Benefits:**
- Claude makes **context-aware** date suggestions using user's mental model
- "tomorrow morning" means user's morning (9am), not generic morning (8am)
- "this weekend" respects user's day boundaries (Sat 4:59am - Mon 4:59am)
- Night owl at 2am says "tomorrow" → Claude knows that means "today" per user's cutoff

**User control:**
- Task approval screen shows suggested dates
- User can edit/remove dates before confirming
- Validation happens before tasks are created

#### Manual Task Creation Flow (Todoist-Style)

**Live parsing with visual feedback:**

1. **User types in task title field:** "call mom next thursday"
2. **As user types "next thursday":**
   - Text gets highlighted/boxed (visual indicator)
   - Date parsed using `date_parser_service` with user_settings
3. **User hovers/taps highlighted text:**
   - Tooltip shows actual date: "Thursday, November 7, 2025"
   - User sees exactly what the parser interpreted
4. **User options:**
   - Continue typing → date stays parsed
   - Click highlight → opens date picker (pre-populated with parsed date)
   - Pick from calendar → replaces/removes text, updates date field
   - Clear date → removes highlight and date

**Alternative: Dedicated date field**
- Task form has separate "Due date" field
- Field accepts:
  - Text input: "next thursday" (parsed live)
  - Calendar picker: Visual date selection
- Both methods use same parser with user_settings

**Parser integration:**
```dart
// Date parser service uses user_settings
final parsedDate = dateParserService.parse(
  text: "next thursday",
  userSettings: userSettings, // Contains cutoff, time keywords, week start
  referenceTime: DateTime.now(),
);
```

#### Why This Works

**Single Source of Truth:**
- Both Claude and local parser use `user_settings`
- User's time framework is consistent across all entry points
- No conflicts because both interpret using same rules

**No Conflict Resolution Needed:**
- Brain Dump: Claude interprets naturally with user context
- Manual: Parser interprets explicitly with user context
- Different UX, same logic

**User Always Has Control:**
- Brain Dump → approval screen with edit capability
- Manual → live feedback + calendar fallback
- Both allow overrides if parsing is wrong

**Progressive Enhancement:**
- Text parsing is faster for power users
- Calendar picker always available as fallback
- Visual feedback builds trust in parsing accuracy

#### Implementation Notes

**Phase 3.3 Tasks:**
- Build `date_parser_service.dart` with user_settings integration
- Update Brain Dump prompt to include user_settings context
- Implement Todoist-style live parsing UI for manual task creation
- Add hover tooltip for parsed date phrases
- Test edge cases: "tomorrow" at 3am, "this weekend" on Saturday, etc.

**Testing Focus:**
- Verify Claude respects user_settings context in Brain Dump
- Verify local parser produces same results as Claude for same input
- Test live parsing UX (highlight, hover, calendar override)
- Edge case: User changes settings, existing tasks keep their dates (no retroactive changes)

**✅ RESOLVED: Weekday ambiguity - forward-looking with user week start preference**
- **Decision:** "this Friday" = next occurring Friday (always forward-looking)
- **Implementation:**
  ```dart
  // Always forward-looking (never refers to past)
  DateTime parseWeekday(String dayName, {bool isNext = false}) {
    final today = getEffectiveToday(); // Respects user cutoff
    final targetWeekday = parseWeekdayName(dayName); // Mon=1, Tue=2, etc.

    // Find next occurrence of this weekday
    int daysUntil = (targetWeekday - today.weekday) % 7;
    if (daysUntil == 0) daysUntil = 7; // If today is Friday, "Friday" = next week

    if (isNext) daysUntil += 7; // "next Friday" = occurrence after "this Friday"

    return today.add(Duration(days: daysUntil));
  }
  ```
- **User preference:** Added `week_start_day` to user_settings (0=Sunday, 1=Monday, etc., default Monday)
  - Used for calendar views and week-based parsing ("this week", "next week" in future phases)
  - Supports any start day (for surveys/research on uncommon preferences like Wednesday start)
- **Rationale:**
  - Simplest, most predictable rule (no edge cases, no invalid dates)
  - Clear distinction: "this [day]" = next occurrence, "next [day]" = occurrence after that
  - Never produces "that was yesterday" confusion
- **Subject to refinement:** Phase 3.1 Todoist research may reveal smarter approach
- **Future enhancement:** Onboarding quiz (Phase 4+) to infer user's natural weekday logic
  - See `docs/future/onboarding-quiz.md` for detailed quiz design
  - Quiz question: "It's Saturday afternoon. A friend asks if you're free 'this Friday.' What do you think they mean?"
  - Adjusts parsing logic based on user's intuitive answer

### Multi-Day Tasks & Display Logic

**✅ RESOLVED: Add start_date column for date range support**
- **Decision:** Add `start_date` column to tasks table for multi-day task support
- **Schema change:**
  ```sql
  ALTER TABLE tasks ADD COLUMN start_date INTEGER; -- Unix timestamp, nullable
  ```
- **Weekend parsing:**
  - Parse "weekend" as date range: `start_date = Saturday (user's day start)`, `due_date = Monday (end of user's Sunday)`
  - User's day boundaries determined by `today_cutoff_hour`/`today_cutoff_minute` from user_settings
  - Example with 4:59am cutoff: weekend = Sat 4:59am to Mon 4:59am
- **Display logic:**
  - **Default view:** Show ALL tasks (no date filtering)
  - **"For Today" view:** Show tasks where today falls within [start_date, due_date] range
  - Weekend task visible on both Saturday and Sunday in "For Today" view
  - Completed tasks: hidden per hide-completed threshold in list views
- **Phase 7 calendar/day planner behavior:**
  - Completed tasks stay visible (crossed out) on previous days in calendar view
  - Hide-completed threshold does NOT apply to calendar view
  - User sees "reward" of accomplished tasks in retrospective view
- **Rationale:**
  - Future-proofs for "this week", "next week", multi-day projects (Phase 7+)
  - Clean semantics (task spans a date range, not just a single deadline)
  - Avoids fragile workarounds (like storing parsing keywords or setting wrong due_date)
  - One more column in migration is negligible cost vs future migration complexity

### Voice Input

**✅ RESOLVED: No hard latency metric - focus on streaming UX**
- **Decision:** Skip hard millisecond targets, optimize for "feels fast" user experience
- **Rationale:**
  - Device STT latency varies by hardware, OS version, system load
  - `speech_to_text` provides streaming interim results (text appears in real-time)
  - User perception of speed comes from streaming feedback, not final transcription time
  - Galaxy S22 Ultra (2021 flagship) should be inherently fast
- **Implementation focus:**
  - Use interim results for streaming transcription updates
  - Smooth UI animations (pulsing mic, text streaming in)
  - Responsive stop button
  - No UI freezes or janky states during transcription
  - Graceful error handling
- **Testing approach:**
  - BlueKitty tests on S22 Ultra during Phase 3.4 implementation
  - Qualitative feedback: "feels fast" vs "feels laggy"
  - Optimize based on actual user experience, not arbitrary benchmarks

### Database & Storage

**✅ RESOLVED: Hybrid caching strategy**
- **Decision:** Use BOTH `file_path` (local cache) AND `source_url` (original remote URL)
- **Schema for Phase 3:**
  ```sql
  file_path TEXT NOT NULL,     -- Local cached copy (always present, app private storage)
  source_url TEXT,             -- Original URL (null if uploaded from device)
  ```
- **Implementation approach (Phase 6):**
  - **User uploads from device:** Copy to app's private storage, source_url = NULL
  - **User provides remote URL:** Download and cache locally, store original URL
  - **Storage location:** `/data/data/.../files/images/` (no extra permissions, reliable, offline-first)
- **Benefits:**
  - ✅ Works offline (everything cached locally)
  - ✅ Survives remote URL death (we have the image)
  - ✅ Can re-download if cache cleared (have source_url)
  - ✅ Supports both local uploads AND remote URLs
- **Long-term sustainability concern:** Decades of images could bloat app significantly
- **Future storage management features (Phase 6+):**
  - Per-image deletion UI (tap image → option to remove)
  - Storage management screen ("Images using X MB", view/delete)
  - Automatic image compression (resize on upload)
  - "Clear orphaned images" (images with no task reference)
  - Optional cloud offload for old images (Phase 7+)
  - Warning prompts when storage exceeds thresholds (e.g., 500 MB)

### Testing Approach

**✅ RESOLVED: Continuous testing with milestone gates**
- **Decision:** Write tests alongside implementation, not as separate phase
- **Approach:**
  1. **During feature implementation:** Write unit tests immediately after code (same sitting, ~30 min per feature slice)
  2. **End of each sub-phase:** Run full suite + add integration tests (~2 hours per sub-phase)
  3. **Focus:** Test risky/complex logic (position backfill, date parsing, cascade delete)
  4. **No CI/CD:** Manual test runs when needed (single dev, AI assistance = different constraints)
- **Coverage philosophy:** Don't obsess over 80%/70% numbers - prioritize testing complex logic
- **Integration:** Testing tasks explicitly added to each sub-phase (see implementation sections)

---

## Success Metrics

### User Experience
- [ ] Voice capture to tasks in < 10 seconds
- [ ] Nesting tasks takes < 5 taps
- [ ] Date parsing accuracy > 80% for common phrases

### Technical
- [ ] Test coverage > 70% for new code
- [ ] Database migration success rate 100%
- [ ] No regressions in Phase 1/2 features
- [ ] App launch time < 2 seconds (unchanged)

### Performance
- [ ] Nesting UI renders smoothly (60fps minimum)
- [ ] Voice transcription feels responsive (streaming interim results, smooth UI)
- [ ] Search results appear < 500ms

---

## Risk Assessment

### High Risk
- **Database Migration (v3 → v4)** - Adding 6 new tables + columns, thoroughly test upgrade path
- **Voice Permissions** - User may deny, need graceful fallback
- **Date Parsing Ambiguity** - "This Friday" may confuse users

### Medium Risk
- **Nesting UI Complexity** - 4 levels could get cluttered on small screens, needs careful visual design
- **User Settings Validation** - Chaos gremlin protection needed (illogical time assignments)
- **Notification Delivery** - Android battery optimization may block
- **Device STT Accuracy** - Quality varies by device age, may need cloud upgrade in Phase 4+ if insufficient

### Low Risk
- **Quick Actions** - Already have swipe-to-delete pattern
- **Search** - Reuse Phase 2 fuzzy matching logic
- **Context Menu** - Standard pattern, well-established UX

### Deferred (No Risk This Phase)
- **Home Screen Widget** - Deferred to Phase 4
- **Advanced Templating** - Deferred to Phase 3.5/4+ (basic is_template column added)
- **@mentions & #tags UI** - Database tables added, UI implementation deferred to Phase 5

---

## Dependencies

### New Packages (Tentative - check MCP for latest)
- `speech_to_text` ^6.0.0 - Voice transcription (device-based, offline-first)
- `flutter_local_notifications` ^17.0.0 - Due date reminders
- `timezone` - IANA Time Zone Database for timezone-aware notification scheduling (critical for DST/travel)
- Consider: `jiffy` or custom date parser (TBD based on implementation complexity)

### Deferred Packages (Phase 4+)
- `home_widget` ^0.4.0 - Android/iOS widgets (deferred to Phase 4)

### Existing Packages (Leveraged)
- `intl` - Date formatting
- Existing fuzzy matching logic - Search

---

## Next Steps

1. **BlueKitty Review:** Answer open questions above
2. **Team Sync:** Codex, Gemini review and add technical considerations
3. **Prototype:** Database migration (v3 → v4) and test with Phase 2 data
4. **Prototype:** Task nesting UI (sketch/mockup)
5. **Prototype:** Date parser test cases (20-30 common phrases)
6. **Create:** `phase-3-issues.md` for tracking bugs and questions during implementation

---

## Notes

- This is a PRELIMINARY plan - expect changes as we prototype and discover edge cases
- Codex and Gemini: Please add technical analysis and refine estimates
- BlueKitty: Prioritize features if 3-4 weeks is too aggressive
- Phase 3 is ambitious - we may need Phase 3.5 for polish/widget

**- Claude**
