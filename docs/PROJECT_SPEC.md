# Pin and Paper - Project Specification

**Version:** 3.0 (Fully Consolidated)
**Last Updated:** 2025-10-28
**Primary Device:** Samsung Galaxy S21 Ultra
**Current Phase:** Phase 3 (Planning)

---

## Executive Summary

**Pin and Paper** is an ADHD-friendly task management workspace with AI-assisted organization and a unique "witchy scholarly cottagecore" aesthetic. This document consolidates all planning, technical analysis, and design decisions into a single authoritative source.

### Core Value Proposition

**For ADHD users who struggle with task chaos:**
1. **Zero-friction capture** on phone (always with you)
2. **AI-assisted organization** (Claude helps sort the chaos)
3. **Beautiful spatial workspace** (reduces stress, increases engagement)
4. **Temporal proof of existence** (you did things, here's the evidence)

### Critical Success Factor

The "brain dump → Claude organizes → instant tasks" feature is the killer differentiator. ✅ **This has been validated and works!** Everything else is enhancement.

### Current Status

✅ **Phase 1:** Ultra-Minimal MVP - Complete (Oct 25, 2025)
✅ **Phase 2:** Claude AI Integration - Complete (Oct 27, 2025)
✅ **Phase 2 Stretch Goals:** Complete (Oct 28, 2025)
🔜 **Phase 3:** Mobile Polish & Voice Input - Planning

---

## Vision & Philosophy

### Core Philosophy

- **Spatial, visual, aesthetic-first** - Your workspace should spark joy, not dread
- **Zero friction for thought capture** - Add tasks instantly without categorization
- **Infinite flexibility** - Infinite nesting, tags, connections that match real life
- **Tags over rigid categories** - Fluid, overlapping organization
- **Customizable everything** - Users control their experience
- **AI as optional chaos-wrangler** - Help when needed, invisible when not
- **Temporal proof of existence** - Visual history that shows "I was here, I did things"

### Primary User & Use Case

**User:** Individual with ADHD (Blue Kitty 🐱)
**Primary device:** Galaxy S21 Ultra (always with them)
**Secondary devices:** iPad (organizing/beautifying), Linux desktop

**Core need:** Frictionless task capture on phone with ability to later organize/beautify on larger screens

**Key insight:** If it's not smooth on the phone, it won't be used at all

### Design Principles

**Visual Design:**
- Skeuomorphic aesthetic - Real-world textures, tactile feeling
- Beautiful first - Design is core to experience, not decoration
- Attention to detail - Shadows, lighting, texture all matter
- User customization - No single aesthetic fits everyone

**Interaction Design:**
- Zero friction capture - Adding a task should be effortless
- Spatial intelligence - Position and proximity carry meaning
- Forgiving - Easy to undo, move, reorganize
- Discoverable - Features revealed progressively, not overwhelming
- Fast - No loading spinners, instant feedback
- Touch-optimized - Big tap targets, good gestures

**Information Architecture:**
- Flat when needed - Text-only view for speed
- Infinite depth when wanted - Nest as deep as needed
- Multiple views - List, workspace, journal - same data, different lenses
- Tags not categories - Fluid, overlapping organization
- Temporal awareness - See productivity over time

---

## Tech Stack

### Core Technologies

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Framework** | Flutter 3.24+ | Cross-platform, Skia rendering, hot reload |
| **Language** | Dart 3.5+ | Required for Flutter |
| **IDE** | VS Code or Cursor AI | Flutter DevTools integration |
| **Local Database** | SQLite (sqflite) | Relational data, search, battle-tested |
| **State Management** | Provider (MVP) → Riverpod (later) | Start simple, refactor when needed |
| **Voice Input** | speech_to_text | Device-native, works offline |
| **Path Drawing** | CustomPaint | Torn paper edges, curves |

### Key Flutter Packages (By Phase)

**Phase 1 (MVP):**
```yaml
sqflite: ^2.3.0              # Local database
path_provider: ^2.1.0        # File system paths
provider: ^6.1.0             # State management
uuid: ^4.0.0                 # Unique IDs for tasks
intl: ^0.19.0                # Date formatting
path: ^1.9.1                 # Path manipulation
```

**Phase 2 (AI Integration):**
```yaml
http: ^1.2.0                        # Claude API requests
flutter_secure_storage: ^9.0.0     # Secure API key storage (Android Keystore)
connectivity_plus: ^6.0.0          # Internet connectivity (List API)
```

**Phase 2 Stretch Goals:**
```yaml
shared_preferences: ^2.2.0      # UI preferences (hide completed)
string_similarity: ^2.0.0        # Fuzzy matching (local, no API cost)
```

**Phase 3+ (Future):**
```yaml
speech_to_text: ^6.6.0       # Voice input (Phase 3)
home_widget: ^0.4.0          # Android home screen widget (Phase 3)
# More packages added in later phases
```

### Why These Technologies?

**Why Flutter?**
- Single codebase for Android, iOS, iPad, Linux, Windows, Web
- Skia rendering engine perfect for aesthetic effects (torn paper, shadows, lighting)
- Hot reload for rapid iteration (1-2 second UI updates)
- Strong gesture support for two-finger rotation and spatial interactions
- Native-level performance (60-120fps achievable)

**Why SQLite (not Hive)?**
- Relational data model matches our needs (parent_id for nesting, connections between tasks)
- Full SQL queries for complex search/filtering
- Indexed queries for performance
- ACID compliant, data integrity
- Battle-tested, mature, reliable
- Better than Hive for relationships and search

**Why Provider → Riverpod?**
- Start simple with Provider for MVP (minimal boilerplate, faster development)
- Migrate to Riverpod when complexity increases (Phase 3+)
- Better testing and compile-time safety with Riverpod
- Don't over-engineer the MVP

**Why Service Layer (not REST API yet)?**
- Local-first architecture for MVP (no server needed)
- Service layer encapsulates business logic cleanly
- Can add REST API later for sync without major refactoring
- Faster MVP development (defer API infrastructure to Phase 10)

**Why Bounded Workspace (not infinite canvas)?**
- **Performance:** Easier viewport culling, pre-calculated bounds
- **UX:** Users understand edges better than infinite space
- **Technical:** Simpler hit testing and gesture handling
- **Pragmatic:** Can expand when user runs out of space (but not truly infinite)
- **Decision made:** After technical analysis, infinite canvas was deemed too complex for Phase 4

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                 PRESENTATION LAYER                  │
│                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │ Home Screen │  │  List View  │  │ Add Task   │ │
│  └─────────────┘  └─────────────┘  └────────────┘ │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │         Task Provider (State)                │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                          ▲
                          │
┌─────────────────────────▼───────────────────────────┐
│                  BUSINESS LOGIC LAYER               │
│                                                     │
│  ┌──────────────┐  ┌───────────────┐              │
│  │ Task Service │  │ Claude Service│              │
│  │ Settings Svc │  │ Prefs Service │              │
│  └──────────────┘  └───────────────┘              │
└─────────────────────────────────────────────────────┘
                          ▲
                          │
┌─────────────────────────▼───────────────────────────┐
│                     DATA LAYER                      │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │       Database Service (SQLite Wrapper)      │  │
│  └──────────────────────────────────────────────┘  │
│                          │                          │
│  ┌──────────────────────▼──────────────────────┐  │
│  │          sqflite (SQLite Database)          │  │
│  └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Database Schema Evolution

**Phase 1: MVP Schema (Database Version 1)**
```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,                    -- UUID
  title TEXT NOT NULL,
  completed INTEGER DEFAULT 0,            -- Boolean (0 or 1)
  created_at INTEGER NOT NULL,            -- Unix timestamp
  completed_at INTEGER,                   -- Unix timestamp
  due_date INTEGER,                       -- Unix timestamp (optional)
  notes TEXT,
  priority INTEGER DEFAULT 0              -- 0=none, 1=low, 2=medium, 3=high
);

CREATE INDEX idx_tasks_created ON tasks(created_at DESC);
CREATE INDEX idx_tasks_completed ON tasks(completed, completed_at);
CREATE INDEX idx_tasks_due ON tasks(due_date);
```

**Phase 2: AI Integration (Database Version 2)**
```sql
CREATE TABLE brain_dump_drafts (
  id TEXT PRIMARY KEY,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_modified INTEGER NOT NULL,
  failed_reason TEXT
);

CREATE INDEX idx_drafts_modified ON brain_dump_drafts(last_modified DESC);
```

**Phase 2 Stretch Goals: (Database Version 3)**
```sql
CREATE TABLE api_usage_log (
  id TEXT PRIMARY KEY,
  timestamp INTEGER NOT NULL,
  operation_type TEXT NOT NULL,
  input_tokens INTEGER NOT NULL,
  output_tokens INTEGER NOT NULL,
  estimated_cost_usd REAL NOT NULL,
  model TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_api_usage_timestamp ON api_usage_log(timestamp DESC);
```

**Phase 3: Task Nesting (Database Version 4 - Planned)**
```sql
ALTER TABLE tasks ADD COLUMN parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE;
ALTER TABLE tasks ADD COLUMN position INTEGER DEFAULT 0; -- Order within parent

CREATE INDEX idx_tasks_parent ON tasks(parent_id, position);
```

**Phase 4: Spatial Positioning (Database Version 5 - Planned)**
```sql
ALTER TABLE tasks ADD COLUMN position_x REAL;        -- Canvas X coordinate
ALTER TABLE tasks ADD COLUMN position_y REAL;        -- Canvas Y coordinate
ALTER TABLE tasks ADD COLUMN rotation REAL DEFAULT 0; -- Rotation in degrees
ALTER TABLE tasks ADD COLUMN z_index INTEGER DEFAULT 0; -- Stacking order
ALTER TABLE tasks ADD COLUMN visual_style TEXT;      -- JSON blob for card appearance
```

**Phase 6+: Connections (Database Version 6+ - Planned)**
```sql
CREATE TABLE connections (
  id TEXT PRIMARY KEY,
  from_task_id TEXT NOT NULL,
  to_task_id TEXT NOT NULL,
  type TEXT DEFAULT 'free',              -- 'dependency', 'thematic', 'free'
  style TEXT,                             -- JSON for visual style (string color, etc.)
  note TEXT,                              -- Note on the kraft paper tag
  created_at INTEGER NOT NULL,
  FOREIGN KEY (from_task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (to_task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE INDEX idx_connections_from ON connections(from_task_id);
CREATE INDEX idx_connections_to ON connections(to_task_id);
```

---

## Complete Phase Roadmap

### ✅ Phase 1: Ultra-Minimal MVP (Complete - Oct 25, 2025)

**Goal:** Get basic task capture and management working smoothly on Android phone

**Features Implemented:**
- Quick text capture with auto-focus
- Simple scrollable list view
- Check/uncheck tasks (completion toggling)
- SQLite persistence (database version 1)
- Basic Witchy Flatlay colors and theme
- Task creation, editing, deletion

**Duration:** 4-6 weeks (actual)
**Lines of Code:** ~1,000 lines
**Database Version:** 1

**Documentation:** `archive/phase-1-mvp.md`

---

### ✅ Phase 2: Claude AI Integration (Complete - Oct 27, 2025)

**Goal:** Add "brain dump → Claude organizes → instant tasks" - THE KILLER FEATURE

**Features Implemented:**
- Settings screen with secure API key storage (Android Keystore)
- "Brain Dump" screen with large text area for free-form thought capture
- "Claude, Help Me" button that sends text to Claude API
- Task Suggestion Preview with inline editing and approval flow
- Draft persistence (auto-save on error, never lose text)
- Cost estimation and transparency (~$0.01 per brain dump)
- Bulk task creation (performance optimized, single transaction)
- Internet connectivity checking
- Test Connection feature with visual feedback

**Technical Highlights:**
- Database migration v1 → v2 (brain_dump_drafts table)
- Secure storage using flutter_secure_storage
- Upsert logic for drafts (no UUID leak)
- Single transaction bulk operations (smooth UX)

**Duration:** 2-3 weeks (actual)
**Lines of Code:** ~2,000 lines
**Database Version:** 2

**User Feedback:**
> "Wow, it works! And... it's super cool!!! :D I'm kind of shocked at how well it works haha." — BlueKitty

**Documentation:** `archive/phase-2.md`, `archive/phase-2-issues.md`

---

### ✅ Phase 2 Stretch Goals (Complete - Oct 28, 2025)

**Goal:** Polish and power-user features to enhance core Brain Dump + AI workflow

**Features Implemented:**
1. **Hide Completed Tasks** (time-based with customizable threshold)
   - Recently completed visible (< 24 hours, configurable)
   - Old completed hidden (reduces clutter)
   - Faint + strikethrough for recent completions

2. **Natural Language Task Completion**
   - "I finished calling dentist" → fuzzy matches "Call dentist"
   - Local string matching (no API cost, works offline)
   - Quick Complete screen with confidence indicators

3. **Draft Management UI**
   - Multi-select drafts to combine
   - Character limit warning (10,000 char max)
   - Swipe to delete individual drafts

4. **Brain Dump Review Bottom Sheet**
   - View original brain dump text during review
   - Toggleable (swipe down to hide)
   - Verify Claude captured everything

5. **Cost Tracking Dashboard**
   - API usage logging (input/output tokens, cost)
   - Monthly and total spend tracking
   - Detailed usage history
   - Reset usage data option

6. **Improved Loading States**
   - Progressive loading messages
   - Success animations
   - Better error feedback

**Technical Highlights:**
- Database migration v2 → v3 (api_usage_log table)
- Efficient task categorization (calculate once, not per build)
- Local fuzzy matching (Levenshtein distance)
- Draft duplication prevention (tracked in future planning)

**Duration:** 3-4 weeks (actual)
**Lines of Code:** ~1,500 lines
**Database Version:** 3

**Documentation:** `archive/phase-2.md` (consolidated with core Phase 2)

---

### 🔜 Phase 3: Mobile Polish & Voice Input (3-4 weeks estimated)

**Goal:** Optimize for daily use on Galaxy phone

**Planned Features:**
- Voice-to-text integration (speech_to_text package)
- Home screen widget for quick capture (home_widget package)
- Task nesting (subtasks with indentation)
- Collapsible task groups
- Improved search (fuzzy matching)
- Natural language date parsing ("next Tuesday" → due date)
  - Handles midnight boundary issues (night owl mode)
  - Context-aware parsing (user's effective "today")
- Task templates (common tasks as templates)
- Notifications for due dates
- Quick actions (swipe gestures for common operations)

**Database Changes:**
- Version 3 → 4
- Add parent_id and position columns for nesting

**Key Technical Challenges:**
- Date parsing around midnight (solved with "today window" setting)
- Android widget debugging (can't use hot reload)
- Voice input permissions and error handling

**Documentation:** Will be created during implementation

---

### Phase 4: Bounded Workspace View (4-5 weeks estimated)

**Goal:** Build spatial workspace with fixed/expandable canvas

**Planned Features:**
- Bounded canvas with pan/zoom (e.g., 3000x3000 pixel area)
- CustomPaint-based card rendering (NOT widget tree for performance)
- Drag-and-drop positioning
- Two-finger rotation gesture
- Pinch-to-resize
- Viewport culling (only render visible cards)
- Z-index management (stacking order)
- "Text-only" view toggle (performance mode)
- Torn paper strip aesthetic (custom clipping)
- Index card appearance (pushpins/clips)
- Canvas can grow when user runs out of space

**Database Changes:**
- Version 4 → 5
- Add position_x, position_y, rotation, z_index, visual_style columns

**Key Technical Challenges:**
- Performance with 50+ cards (solved with CustomPaint + viewport culling)
- Gesture conflicts (rotation vs pan/zoom)
- Hit testing for rotated cards
- Memory management for large canvases

**Why Bounded (not infinite)?**
- Performance: Easier viewport culling, pre-calculated bounds
- UX: Users understand edges better
- Technical: Simpler hit testing
- Pragmatic: Can expand, but not truly infinite

**Documentation:** Will be created during implementation

---

### Phase 5: Sync & Backup (3-4 weeks estimated)

**Goal:** Multi-device support (Galaxy phone ↔ iPad ↔ Linux desktop)

**Planned Features:**
- Export/import (JSON or custom format)
- Google Drive integration (backup/restore)
- Basic sync (timestamp-based last-write-wins)
- Conflict resolution UI
- Auto-backup on app close
- Manual backup/restore controls
- "Last synced" timestamp display
- Sync status indicators

**Sync Strategy:**
- Start with timestamp-based sync (simple)
- Later consider CRDTs for better conflict resolution
- Offline-first always (sync when online, never block user)

**Key Technical Challenges:**
- Conflict resolution (what if same task edited on 2 devices?)
- Large data sync (optimize payload size)
- Auth for Google Drive
- Network failures and retry logic

**Documentation:** Will be created during implementation

---

### Phase 6: Aesthetic Enhancement (4-5 weeks estimated)

**Goal:** Bring "witchy scholarly cottagecore" aesthetic to life

**Planned Features:**
- Dynamic time-based lighting (5 states: morning, midday, afternoon, evening, night)
- Smooth lighting transitions (animated)
- Per-object shadows based on light direction
- Card customization (texture + pattern + effects)
- Conspiracy strings (Bezier curves connecting cards)
- Kraft paper tags on strings
- Decorative objects (draggable PNG objects: crystals, flowers, coffee cups)
- Canvas drawing (pen, pencil, highlighter)
- Z-ordering controls (send back, bring front)
- Multiple themes (Witchy Flatlay, Teenage Corkboard, Tweed Professorial)

**Database Changes:**
- Version 5 → 6
- Add connections table

**Key Technical Challenges:**
- Dynamic lighting performance (shadows for many objects)
- Battery drain from animations
- Custom shaders for lighting effects
- Bezier curve drawing performance

**Performance Strategy:**
- Time updates every 15 minutes (not continuous)
- User ON/OFF toggle for dynamic lighting
- Performance mode (disables shadows)

**Documentation:** Will be created during implementation

---

### Phase 7: Journal & History (2-3 weeks estimated)

**Goal:** Temporal awareness and productivity tracking

**Planned Features:**
- Daybook/calendar view (Japanese daybook aesthetic)
- Completed tasks archive
- Completion animations (strikethrough, fade, burn effect - user customizable)
- "On this day" historical view
- Weekly/monthly summaries
- Productivity metrics (tasks completed, streaks)
- Visual density shows productivity
- Scroll through time to see existence mapped
- Upcoming deadlines section
- Toggle to show/hide completed items

**Key Technical Challenges:**
- Efficient date-based queries
- Archive performance with 1000+ completed tasks
- Animation performance

**Documentation:** Will be created during implementation

---

### Phase 8: iPad & Desktop Optimization (3-4 weeks estimated)

**Goal:** Optimize for larger screens and stylus input

**iPad Features:**
- Apple Pencil drawing with pressure sensitivity
- Larger canvas workspace
- Multi-finger gestures
- Split-view support
- Optimized for 120Hz ProMotion displays

**Desktop (Linux) Features:**
- Keyboard shortcuts (Ctrl+N new task, Ctrl+F search, etc.)
- Mouse wheel zoom
- Precision selection with mouse
- Menu bar (optional)
- Multiple windows (possibly)

**Key Technical Challenges:**
- Flutter stylus support (less mature than native)
- Platform-specific code (pressure sensitivity requires platform channels)
- Keyboard shortcut system
- Drawing latency on iPad

**Trade-offs:**
- Flutter drawing won't match Procreate/native apps
- Accept limitations, focus on organization not professional drawing

**Documentation:** Will be created during implementation

---

### Phase 9: Advanced Features (3-4 weeks estimated)

**Goal:** Stretch goals and polish

**Planned Features:**
- Manila folder opening animation (card detail view)
- Cards within cards (nested projects)
- Flippable cards (front/back)
- Three theme system (Witchy, Teenage, Tweed) with full customization
- Custom theme creator (save/load/share)
- Comprehensive undo/redo system (50-action history)
- Selective undo (undo specific past action)
- Bullet journal integration (habit tracking, mood tracking, free-form pages)

**Key Technical Challenges:**
- Undo/redo with spatial operations (rotation, positioning)
- State management for deep undo history
- Theme serialization and sharing

**Documentation:** Will be created during implementation

---

### Phase 10: MCP Server & API Layer (4-5 weeks estimated)

**Goal:** Build API layer and MCP connector for external Claude integration

**Planned Features:**
- RESTful API design with clear documentation
- API server (Dart shelf or Node.js/Express)
- Authentication (API keys, OAuth)
- API documentation (OpenAPI/Swagger)
- Rate limiting and security
- MCP Server implementation (Model Context Protocol)
- Custom Claude connector for Claude Desktop/claude.ai
- Webhook support for automations

**API Endpoints (Planned):**
```
Tasks:
  GET /api/v1/tasks          - List all tasks (with filters)
  GET /api/v1/tasks/:id      - Get single task
  POST /api/v1/tasks         - Create new task
  PUT /api/v1/tasks/:id      - Update task
  DELETE /api/v1/tasks/:id   - Delete task
  POST /api/v1/tasks/:id/complete - Mark complete

AI Integration:
  POST /api/v1/ai/organize   - Chaos dump for AI organization
  POST /api/v1/ai/parse      - Parse natural language into tasks

Workspace:
  GET /api/v1/workspace      - Get workspace state
  PUT /api/v1/workspace      - Update workspace configuration
```

**MCP Server Use Cases:**
```
User (in Claude chat): "Add 'research Victorian mourning jewelry' to my novel research card"
Claude: *calls Pin and Paper API*
Claude: "Added to your Novel Research card! 💚"
```

**Key Technical Challenges:**
- API security and rate limiting
- Authentication system
- MCP protocol implementation
- Claude custom connector approval process

**Documentation:** Will be created during implementation

---

## Success Metrics

### Phase 1-2 Success Criteria (Validated ✅)

**Technical Metrics:**
- ✅ App launches in <2 seconds on Galaxy phone
- ✅ 60fps scrolling in task list (achieved 120fps on Galaxy S21 Ultra)
- ✅ Zero data loss (all tasks persist correctly)
- ✅ Zero crashes in user testing

**User Metrics:**
- ✅ User opens app daily
- ✅ User captures 5+ tasks per day
- ✅ "Brain dump → Claude organizes" works reliably
- ✅ User reports feeling "less overwhelmed"

**Validation:**
> "Wow, it works! And... it's super cool!!! :D" — BlueKitty

### Phase 3+ Success Criteria (To Validate)

**User Engagement:**
- Users actually use workspace view (not just list)
- Users organize/beautify their workspace
- Users report feeling "productive" and "less chaotic"
- Users show the app to friends (organic growth)

**Multi-Device (Phase 5):**
- Seamless workflow between phone, iPad, desktop
- Users trust sync (no lost data)
- Sync is invisible (just works)

**Aesthetic (Phase 6):**
- Users spend time customizing card appearance
- Users appreciate time-based lighting changes
- App is screenshot-worthy (shareable on social media)

**Temporal Awareness (Phase 7):**
- Users can see their accomplishments over time
- Completed task history provides "proof I existed"
- Users feel motivated by seeing progress

---

## Risk Assessment

### Critical Risks

**Risk 1: Performance on Older Android Devices**
- **Impact:** High - Could make app unusable
- **Probability:** Medium
- **Mitigation:**
  - Test on mid-range devices (Galaxy A-series)
  - Viewport culling for workspace view
  - CustomPaint instead of widget trees
  - Text-only performance mode
  - Profile with Flutter DevTools regularly

**Risk 2: Scope Creep**
- **Impact:** Critical - Could result in abandoned project
- **Probability:** High (feature list is very ambitious)
- **Mitigation:**
  - Ruthless prioritization (ship phases incrementally)
  - User testing gates (validate before next phase)
  - Time-box features (if >2 weeks, cut scope or defer)
  - Build in public (accountability)

**Risk 3: Aesthetic Vision vs. Technical Reality**
- **Impact:** Medium-High - Core differentiator
- **Probability:** Medium
- **Mitigation:**
  - Build simple first, iterate toward beauty
  - Prototype complex interactions early
  - Accept Flutter won't match native iOS
  - Good enough is better than perfect

### Medium Risks

**Risk 4: Multi-Device Sync Complexity (Phase 5)**
- **Impact:** Medium
- **Probability:** Medium
- **Mitigation:**
  - Start with simplest approach (timestamp-based)
  - Use Google Drive (not custom server)
  - Defer complex conflict resolution
  - Robust export/import as fallback

**Risk 5: iPad Stylus Experience (Phase 8)**
- **Impact:** Medium (iPad is secondary platform)
- **Probability:** Medium
- **Mitigation:**
  - Set expectations (organizing, not professional drawing)
  - Use community packages
  - Accept limitations
  - Focus on Galaxy phone (primary platform)

---

## Historical Decisions

This section documents major architectural and scope decisions made during planning.

### Decision 1: Flutter over Native (Pre-Development)
**Context:** Need cross-platform support (Android, iOS, iPad, Desktop)
**Options Considered:**
1. Flutter (cross-platform)
2. Native (Swift for iOS, Kotlin for Android)
3. React Native

**Decision:** Flutter
**Rationale:**
- Single codebase for all platforms
- Skia rendering perfect for custom aesthetics
- Hot reload critical for design iteration
- Strong performance (60-120fps achievable)

**Date:** Pre-development (Oct 2025)

---

### Decision 2: SQLite over Hive (Pre-Development)
**Context:** Need local database for offline-first architecture
**Options Considered:**
1. SQLite (relational)
2. Hive (NoSQL key-value)

**Decision:** SQLite
**Rationale:**
- Relational data model (parent_id, connections)
- Full SQL for complex queries
- Better search performance with indexes
- ACID compliance
- Battle-tested

**Trade-off:** Slightly more boilerplate than Hive
**Date:** Pre-development (Oct 2025)

---

### Decision 3: Provider First, Riverpod Later (Phase 1)
**Context:** Need state management for MVP
**Options Considered:**
1. Provider (simple)
2. Riverpod (advanced)
3. Bloc (complex)

**Decision:** Start with Provider, migrate to Riverpod in Phase 3+
**Rationale:**
- Provider is simpler, faster MVP development
- Can migrate to Riverpod when complexity increases
- Don't over-engineer early phases

**Date:** Phase 1 (Oct 2025)

---

### Decision 4: Bounded Workspace (Not Infinite Canvas) (Phase 2 Planning)
**Context:** Original vision included "infinite canvas" for Phase 4
**Options Considered:**
1. Infinite canvas (original plan)
2. Bounded/expandable canvas (revised)

**Decision:** Bounded canvas (e.g., 3000x3000 pixels, can grow)
**Rationale:**
- Performance: Easier viewport culling, bounds checking
- UX: Users understand edges better than infinite space
- Technical: Simpler hit testing, gesture handling
- Pragmatic: Still expandable when needed

**Trade-off:** Not truly "infinite" but more practical
**Date:** Phase 2 planning (Oct 2025)
**Documented:** project-plan.md (now archived as archive/project-plan-original.md)

---

### Decision 5: Service Layer Only (Defer REST API) (Phase 2 Planning)
**Context:** Original plan emphasized "API-first architecture" from day 1
**Options Considered:**
1. Build REST API immediately
2. Service layer only, add API in Phase 10

**Decision:** Service layer only, defer REST API to Phase 10
**Rationale:**
- Local-first MVP doesn't need HTTP server
- Service layer provides clean abstraction
- Can add REST API later without major refactoring
- 2-3x faster MVP development

**Trade-off:** API integration deferred to Phase 10
**Date:** Phase 2 planning (Oct 2025)
**Documented:** project-plan.md (now archived as archive/project-plan-original.md)

---

### Decision 6: Claude AI in Phase 2 (Not Phase 3) (Phase 1 Complete)
**Context:** Original plan had Claude AI as Phase 3 "Rich Features"
**Options Considered:**
1. AI as Phase 3 feature (original plan)
2. AI as Phase 2 (revised priority)

**Decision:** Move Claude AI to Phase 2 (immediately after MVP)
**Rationale:**
- This is THE killer differentiator for ADHD users
- Must validate this ASAP (if it doesn't work, pivot)
- Everything else is enhancement

**Result:** ✅ Phase 2 validated successfully - users love it!
**Date:** Phase 1 complete (Oct 2025)

---

### Decision 7: Phase 2 Stretch Goals (Phase 2 Complete)
**Context:** Phase 2 AI Integration successful, but identified polish opportunities
**Options Considered:**
1. Move directly to Phase 3
2. Polish Phase 2 with stretch goals

**Decision:** Implement Phase 2 Stretch Goals before Phase 3
**Rationale:**
- Natural language completion is high-value, low-cost (local fuzzy matching)
- Draft management prevents data loss anxiety
- Cost tracking builds trust
- Better to perfect current features than rush to new ones

**Result:** ✅ All stretch goals complete - major UX improvements
**Date:** Phase 2 complete (Oct 2025)

---

## Development Conventions

### Code Quality Standards

- **File Size:** Keep files under 500 lines (focused, manageable)
- **DRY Principles:** Don't Repeat Yourself - reusable components
- **Separation of Concerns:** UI → Business Logic → Data layers
- **Hot Reload Friendly:** Structure code to support fast iteration
- **Mobile-First:** Prioritize Galaxy phone, adapt for larger screens
- **Well-Commented:** Complex logic should have clear explanations

### Performance Standards

- **Target:** 120fps on Galaxy S21 Ultra (native refresh rate)
- **Minimum:** 60fps on mid-range devices
- **Launch Time:** <2 seconds cold start
- **Battery Impact:** <5% per hour of active use
- **Memory:** Keep under 200MB for list view, under 400MB for workspace view

### Testing Standards

- **Unit Tests:** All service layer methods
- **Widget Tests:** Key UI interactions
- **Integration Tests:** Critical user flows (create task, brain dump, sync)
- **Manual Testing:** Every phase on physical Galaxy S21 Ultra
- **Performance Profiling:** Use Flutter DevTools regularly

---

## Next Steps

**Current Phase:** Planning Phase 3 (Mobile Polish & Voice Input)

**Immediate Actions:**
1. Review Phase 3 requirements with BlueKitty
2. Research natural language date parsing approaches
3. Prototype voice input integration
4. Plan database migration v3 → v4 (nesting support)
5. Create Phase 3 implementation document

**Questions to Answer:**
- Voice input: Device native or cloud-based?
- Date parsing: "Today window" setting - what default (3 hours)?
- Task nesting: Maximum depth limit (prevent infinite recursion)?
- Home screen widget: High priority or defer to Phase 4?

---

**Document Status:** ✅ Consolidated and Complete
**Last Review:** October 28, 2025
**Next Review:** After Phase 3 completion

**See Also:**
- `visual-design.md` - Complete aesthetic specification
- `docs/future/` - Detailed future phase research
- `archive/` - Historical planning documents and completed phases

---

*From chaos to clarity, one index card at a time.* 🍂✨📌

**Built with love for ADHD brains everywhere.** 💚
