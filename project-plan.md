# Pin and Paper - Project Plan & Technical Analysis
**Android MVP Development Roadmap**

**Generated:** 2025-10-25
**Status:** Pre-Development (Design → Implementation)
**Target Platform:** Android (Primary), with multi-platform expansion planned

---

## Executive Summary

Pin and Paper is an ADHD-friendly task tracking, thought capture, and journaling app with a unique "witchy scholarly cottagecore" aesthetic. After comprehensive analysis of the existing specifications (`plan.md`, `visual-design.md`), this document provides:

1. **Tech stack viability assessment** for the proposed Flutter-based approach
2. **Critical issues identified** that could derail development
3. **Revised recommendations** for the technology stack and architecture
4. **Realistic MVP scope** (trimmed from original Phase 1)
5. **Phased development roadmap** with time estimates
6. **Risk mitigation strategies**

**Key Finding:** The proposed tech stack (Flutter) is viable but requires significant scope reduction and architectural adjustments to achieve a successful MVP within a reasonable timeframe.

**IMPORTANT UPDATE (User Feedback):** Claude AI integration ("chaos dump → organized tasks") is the **#1 functional feature** and will be prioritized in Phase 2 (immediately after basic CRUD). The "infinite canvas" concept has been simplified to a fixed/bounded workspace to reduce complexity.

---

## Tech Stack Viability Analysis

### Current Plan: Flutter-Based Cross-Platform App

The existing `plan.md` proposes Flutter for the following reasons:
- Single codebase for Android, iOS, Linux, Windows, Web
- Hot reload for rapid UI iteration
- Custom rendering engine (Skia) for aesthetic effects
- Strong touch/gesture support
- Native-level performance
- Excellent animation framework

### ✅ Flutter Strengths for Pin and Paper

| Capability | Relevance | Assessment |
|------------|-----------|------------|
| **Cross-platform** | Multi-device user (Galaxy phone, iPad, Linux desktop) | ✅ Strong fit - write once, deploy everywhere |
| **Hot reload** | Rapid aesthetic iteration needed | ✅ Critical for design-heavy app |
| **Skia rendering** | Custom visual effects (torn edges, lighting, shadows) | ✅ Perfect match - full control over rendering |
| **Gesture recognition** | Two-finger rotation (#1 priority feature) | ✅ Flutter's gesture arena handles complex gestures |
| **Animation framework** | Card flips, folder opening, page curls | ✅ Built-in Animation controllers |
| **Performance** | 60fps requirement, <2s app launch | ✅ Achievable with proper optimization |
| **Offline-first** | Local data storage primary | ✅ No web dependencies needed |

**Verdict:** ✅ **Flutter is the right choice** for this project.

---

## Critical Issues Identified

### 🟡 MODERATE ISSUE #1: Workspace View Performance (REVISED)

**Problem:**
- Original design specified "infinite canvas" - now revised to **fixed/bounded workspace**
- Even with bounded workspace, rotated cards with shadows and lighting = expensive render operations
- Flutter's widget tree can become sluggish with 50+ complex widgets on screen
- Risk: Performance degradation on mid-range Android devices (Galaxy A-series, older phones)

**Impact:** Medium - Affects Phase 4+ features, not MVP

**Solution:**
- **Use bounded workspace:** Fixed area (e.g., 3000x3000 pixels) instead of infinite
- **Viewport culling:** Only render cards visible in current viewport
- **Use CustomPaint, NOT widgets:** Draw cards as canvas shapes for better performance
- **Expandable later:** Canvas can grow when user runs out of space (but not "infinite")

**Implementation:**
```dart
// GOOD: Single CustomPaint widget rendering all visible cards
CustomPaint(
  painter: WorkspaceCanvasPainter(
    visibleCards: viewportCards, // Only cards in viewport
    lightingState: currentLighting,
  ),
)

// BAD: Widget tree with 100+ individual card widgets
Column(
  children: allCards.map((card) => RotatedCard(card)).toList(), // Performance disaster
)
```

---

### 🟡 MODERATE ISSUE #2: Dynamic Lighting System Complexity

**Problem:**
- Time-based lighting with per-object shadows requires GPU-intensive operations
- 5 lighting states (morning, midday, afternoon, evening, night) with smooth transitions
- Shadow calculations for each card based on light direction + elevation
- Battery drain concern on mobile devices

**Impact:** Medium - Core aesthetic feature but optional for functionality

**Solution:**
- **Phase 1 MVP:** Static lighting (no time-based updates) OR simple overlay tint
- **Phase 2:** Time-based lighting updates (check every 15 minutes, not continuous)
- **Phase 3:** Animated transitions between lighting states
- **Phase 4:** Per-object dynamic shadows
- **User control:** ON/OFF toggle, performance mode (disables shadows)

**Recommendation:** Don't build the full lighting system for MVP. Ship a single "afternoon" lighting preset (the most aesthetic according to visual-design.md).

---

### 🟡 MODERATE ISSUE #3: Rotation Gesture Conflicts

**Problem:**
- Two-finger rotation is listed as #1 priority feature
- On mobile, this can conflict with:
  - Pinch-to-zoom gestures
  - Scroll/pan gestures
  - System gestures (Android back gesture)
- Requires careful gesture arena management

**Impact:** Medium - Core feature but solvable with good UX design

**Solution:**
- **Gesture priority:** Long-press to "pick up" card, THEN rotate/resize/move
- **Visual feedback:** Card lifts with shadow when picked up
- **Gesture modes:** Toggle between "navigate mode" (pan/zoom) and "edit mode" (rotate/move)
- **Rotation handles:** Show rotation handle icons on selected cards for precision

**Code approach:**
```dart
GestureDetector(
  onLongPressStart: (details) => _pickUpCard(cardId),
  onScaleUpdate: _isCardPickedUp ? _handleRotateResize : null,
  onPanUpdate: _isCardPickedUp ? _handleMove : _handleCanvasPan,
  child: CardWidget(),
)
```

---

### 🟡 MODERATE ISSUE #4: iPad Stylus Experience

**Problem:**
- Flutter's stylus/Apple Pencil support exists but is less mature than native iOS frameworks
- Pressure sensitivity requires platform channels (custom native code)
- Drawing latency may be higher than native apps
- Risk: iPad experience (secondary platform) may feel inferior

**Impact:** Medium - iPad is secondary to Galaxy phone

**Solution:**
- **Accept limitations:** Flutter drawing won't match Procreate/native apps
- **Set expectations:** iPad is for "organizing" not "professional drawing"
- **Use flutter_drawing_board package:** Community package with stylus support
- **Defer perfection:** Get basic drawing working, optimize later

**Verdict:** Acceptable trade-off. iPad is not primary platform (Galaxy phone is).

---

### 🔴 CRITICAL ISSUE #5: API-First Architecture Is Premature

**Problem:**
- `plan.md` emphasizes "API-first architecture" with RESTful/GraphQL endpoints
- For a single-user, local-first mobile app, this is **over-engineering**
- MVP doesn't need:
  - HTTP server
  - REST API endpoints
  - Authentication/authorization
  - API versioning
  - JSON serialization layers
- Building all this infrastructure slows down development by 2-3x

**Impact:** Critical - Will delay MVP by months

**Solution:**
- **Build Service Layer, NOT REST API**
- Create `TaskService`, `ConnectionService`, `PreferencesService` classes
- These encapsulate business logic and return Dart objects
- Later, these services can *call* a real API when sync is added
- This is "API-ready" without the overhead

**Architecture Comparison:**

```
❌ WRONG (Over-engineered for MVP):
UI → API Client → HTTP Requests → API Server → Database Service → SQLite

✅ RIGHT (Appropriate for MVP):
UI → Task Service → Database Service → SQLite

LATER (When adding sync):
UI → Task Service → [checks internet] → API Client OR Database Service
```

**Verdict:** Defer API layer to Phase 5-6 when multi-device sync is implemented.

---

### 🔴 CRITICAL PRIORITY #6: Claude AI Integration (MOVED TO PHASE 2)

**USER FEEDBACK:** This is the **#1 functional feature** - the unique value proposition that differentiates Pin and Paper from simple notes apps.

**Problem:**
- Claude API integration requires:
  - User's API key (security concern: where to store?)
  - Internet connection (conflicts with offline-first for this specific feature)
  - API costs (user provides their own API key)
  - Error handling (rate limits, network failures)

**Impact:** HIGH - This is the killer feature for ADHD users

**Solution (Phase 2 Implementation):**
- **Prioritize after MVP:** Build in Phase 2 (week 7-9), immediately after basic CRUD
- **API key storage:** Use `flutter_secure_storage` for encrypted key storage
- **User flow:**
  1. User dumps chaotic thoughts into "Brain Dump" text area
  2. Tap "Claude, Help Me" button
  3. Send to Claude API with prompt: "Organize these thoughts into tasks"
  4. Parse response (structured JSON with task list)
  5. Show preview of tasks, user can approve/edit before creating
- **Graceful offline:** If no internet, disable AI button with helpful message
- **No subsidization:** User provides their own Claude API key
- **Cost transparency:** Show estimated API cost before sending

**Verdict:** **MOVE TO PHASE 2** (not Phase 3). This is what makes the app valuable for ADHD users.

---

### 🟡 MODERATE ISSUE #7: Android Widget Complexity

**Problem:**
- Home screen widgets for quick capture are listed in Phase 1
- Flutter's Android widget support is LIMITED
- Requires native Kotlin/Java code in addition to Dart
- Debugging is harder (can't use hot reload for widgets)

**Impact:** Medium - Useful but not essential for MVP

**Solution:**
- **Defer to Phase 2:** Get the app working first
- **When implemented:** Use `home_widget` Flutter package (community-maintained bridge)
- **Alternative:** Deep linking - tap notification to open quick capture screen

**Verdict:** Remove home screen widget from MVP. Add after core app is stable.

---

## Recommended Tech Stack (REVISED)

### Core Technologies

| Component | Recommendation | Rationale |
|-----------|----------------|-----------|
| **Framework** | Flutter 3.24+ | Cross-platform, Skia rendering, strong ecosystem |
| **Language** | Dart 3.5+ | Required for Flutter |
| **IDE** | VS Code or Android Studio | Flutter DevTools integration |
| **Local Database** | SQLite (via `sqflite`) | Better for relational data than Hive |
| **State Management** | Provider (MVP), Riverpod (later) | Start simple, refactor when needed |
| **Voice Input** | `speech_to_text` package | Device-native, works offline |
| **Path Drawing** | `flutter_custom_clippers` + CustomPaint | For torn paper edges, curves |

### Key Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Core functionality
  sqflite: ^2.3.0              # Local database
  path_provider: ^2.1.0        # File system paths
  provider: ^6.1.0             # State management
  uuid: ^4.0.0                 # Unique IDs for tasks

  # UI/UX
  flutter_staggered_grid_view: ^0.7.0  # Card layouts
  animations: ^2.0.0                    # Page transitions

  # Phase 2: Claude AI Integration
  flutter_secure_storage: ^9.0.0  # API key storage (encrypted)
  http: ^1.2.0                 # Claude API calls

  # Phase 3+: Future phases
  speech_to_text: ^6.6.0       # Voice input (Phase 3)
  home_widget: ^0.4.0          # Android home screen widget (Phase 3)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mockito: ^5.4.0              # Unit testing
```

---

### Database: SQLite vs Hive Decision

**Original plan suggested Hive.** After analysis, I recommend **SQLite** instead.

| Criteria | Hive | SQLite | Winner |
|----------|------|--------|--------|
| Query complexity | ❌ No WHERE, no JOINs | ✅ Full SQL | SQLite |
| Relationships | ❌ Manual management | ✅ Foreign keys | SQLite |
| Search/filtering | ❌ Requires in-memory filtering | ✅ Indexed queries | SQLite |
| Write performance | ✅ Faster (NoSQL) | 🟡 Slightly slower | Hive |
| Maturity | 🟡 Relatively new | ✅ Battle-tested | SQLite |
| Flutter support | ✅ Pure Dart | ✅ Well-supported (sqflite) | Tie |
| Data integrity | 🟡 No constraints | ✅ ACID compliant | SQLite |

**Verdict:** Use **SQLite with sqflite package**. The data model has relationships (parent_id for nesting, connections between tasks), and search/filtering will be essential.

---

### State Management: Provider vs Riverpod

**Original plan suggested Riverpod.** I recommend starting with **Provider**.

| Criteria | Provider | Riverpod | Winner |
|----------|----------|----------|--------|
| Learning curve | ✅ Simple | ❌ Steeper | Provider |
| Boilerplate | ✅ Minimal | 🟡 More verbose | Provider |
| Compile safety | 🟡 Runtime lookups | ✅ Compile-time | Riverpod |
| Testing | 🟡 Requires mocking | ✅ Easier | Riverpod |
| MVP speed | ✅ Faster development | 🟡 More setup | Provider |

**Strategy:**
1. **Phase 1-2:** Use Provider (get MVP shipped fast)
2. **Phase 3+:** Migrate to Riverpod when complexity increases (if needed)

**Don't over-engineer the MVP.**

---

## Architecture & Project Structure

### High-Level Architecture (MVP)

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
│  │ Task Service │  │ Prefs Service │              │
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

### Detailed Project Structure

```
pin_and_paper/
├── lib/
│   ├── main.dart                          # App entry point
│   │
│   ├── models/                            # Data models
│   │   ├── task.dart                      # Task model
│   │   ├── tag.dart                       # Tag model
│   │   └── user_preferences.dart          # Settings/preferences
│   │
│   ├── services/                          # Business logic layer
│   │   ├── database_service.dart          # SQLite wrapper
│   │   ├── task_service.dart              # Task CRUD + logic
│   │   └── preferences_service.dart       # Settings management
│   │
│   ├── providers/                         # State management
│   │   ├── task_provider.dart             # Task state
│   │   └── theme_provider.dart            # Theme/lighting state
│   │
│   ├── screens/                           # Full screen views
│   │   ├── home_screen.dart               # Main app screen
│   │   ├── task_list_screen.dart          # List view of tasks
│   │   ├── add_task_screen.dart           # Quick capture screen
│   │   └── task_detail_screen.dart        # Task details/edit
│   │
│   ├── widgets/                           # Reusable components
│   │   ├── task_item.dart                 # Individual task widget
│   │   ├── tag_chip.dart                  # Tag display/selector
│   │   ├── quick_capture_bar.dart         # Bottom sheet input
│   │   └── empty_state.dart               # Empty list placeholder
│   │
│   ├── utils/                             # Utilities
│   │   ├── constants.dart                 # App constants
│   │   ├── theme.dart                     # Theme definitions
│   │   └── database_helper.dart           # SQL schema definitions
│   │
│   └── config/
│       └── app_config.dart                # Configuration values
│
├── test/                                  # Unit tests
│   ├── models/
│   ├── services/
│   └── widgets/
│
├── integration_test/                      # Integration tests
│
├── assets/                                # Static assets
│   ├── images/
│   └── fonts/
│
├── pubspec.yaml                           # Dependencies
└── README.md                              # Project documentation
```

---

## Database Schema

### Phase 1: MVP Schema (SQLite)

```sql
-- Core task table
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

-- Tag definitions
CREATE TABLE tags (
  id TEXT PRIMARY KEY,                    -- UUID
  name TEXT UNIQUE NOT NULL,
  color TEXT                              -- Hex color (e.g., '#8B7355')
);

-- Many-to-many relationship: tasks <-> tags
CREATE TABLE task_tags (
  task_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (task_id, tag_id),
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- User preferences
CREATE TABLE preferences (
  key TEXT PRIMARY KEY,
  value TEXT                              -- JSON-serialized value
);

-- Indexes for performance
CREATE INDEX idx_tasks_created ON tasks(created_at DESC);
CREATE INDEX idx_tasks_completed ON tasks(completed, completed_at);
CREATE INDEX idx_tasks_due ON tasks(due_date);
CREATE INDEX idx_tags_name ON tags(name);
```

### Phase 2: Add Nesting Support

```sql
ALTER TABLE tasks ADD COLUMN parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE;
ALTER TABLE tasks ADD COLUMN position INTEGER DEFAULT 0; -- Order within parent

CREATE INDEX idx_tasks_parent ON tasks(parent_id, position);
```

### Phase 4: Add Spatial Positioning (Workspace View)

```sql
ALTER TABLE tasks ADD COLUMN position_x REAL;        -- Canvas X coordinate
ALTER TABLE tasks ADD COLUMN position_y REAL;        -- Canvas Y coordinate
ALTER TABLE tasks ADD COLUMN rotation REAL DEFAULT 0; -- Rotation in degrees
ALTER TABLE tasks ADD COLUMN z_index INTEGER DEFAULT 0; -- Stacking order
ALTER TABLE tasks ADD COLUMN visual_style TEXT;      -- JSON blob for card appearance

-- Example visual_style JSON:
-- {
--   "texture": "kraft",
--   "pattern": "ruled",
--   "effect": "coffee_stain",
--   "attachment": "pushpin_red"
-- }
```

### Phase 6: Add Connections (Conspiracy Strings)

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

## MVP Scope (REVISED)

### Original Phase 1 (from plan.md)

The original plan's Phase 1 included:
- ✅ Quick task capture (text + voice-to-text)
- ✅ Widget for homescreen quick add
- ✅ Simple list view with checkboxes
- ✅ Text-only stripped down view (dot grid paper aesthetic)
- ✅ "Claude, Help Me" chaos dump with AI organization
- ✅ Basic task management (create, complete, delete)
- ✅ Optional due dates and tags
- ✅ Basic nesting (tasks with subtasks)
- ✅ Data persistence (SQLite or Hive, offline-first)

**Assessment:** This is actually 2-3 months of work for one developer. Too ambitious for MVP.

---

### RECOMMENDED MVP (4-6 weeks)

**Core Principle:** Get the app into the user's hands FAST. Prove the core value proposition before building the complex aesthetic features.

#### ✅ MVP Features (Must Have)

1. **Quick Text Capture**
   - Single input field on home screen
   - "Add Task" button
   - Keyboard opens immediately on launch
   - No friction, no extra taps

2. **Simple List View**
   - Scrollable list of tasks
   - Checkbox to mark complete
   - Tap to edit
   - Swipe to delete (with confirmation)
   - Simple text appearance (can add subtle paper texture)

3. **Basic CRUD Operations**
   - Create task (title + optional notes)
   - Read tasks (list view)
   - Update task (edit title/notes)
   - Delete task
   - Mark complete/incomplete

4. **Tags System**
   - Add tags to tasks (free-form text, auto-suggest existing tags)
   - Filter tasks by tag
   - Display tags as colored chips below task title

5. **Local Storage (SQLite)**
   - All data persists locally
   - Offline-first (no internet required)
   - Fast queries for search/filter

6. **Basic Search**
   - Search tasks by title/notes text
   - Filter by completion status
   - Filter by tags

7. **Due Dates (Optional)**
   - Add due date to task
   - Display tasks with upcoming due dates prominently
   - Sort by due date

8. **Simple Aesthetic**
   - Use color palette from color-palettes.html
   - Apply "Witchy Flatlay" theme colors
   - Simple paper texture background (static image)
   - NO dynamic lighting (just use "afternoon" colors)
   - NO rotation (flat list only)

#### ⏸️ DEFER to Phase 2+

These features come after MVP validation:

- 🚀 **"Claude, Help Me" AI integration (Phase 2)** ← #1 PRIORITY after MVP
- ⏸️ Voice-to-text input (Phase 3)
- ⏸️ Home screen widget (Phase 3)
- ⏸️ Task nesting/subtasks (Phase 3)
- ⏸️ Dynamic lighting system (Phase 4)
- ⏸️ Bounded workspace view with rotation (Phase 4)
- ⏸️ Rotation gestures (Phase 4)
- ⏸️ Multi-device sync (Phase 5)
- ⏸️ Conspiracy strings (Phase 6)
- ⏸️ Decorative objects (Phase 6)
- ⏸️ Drawing/sketching (Phase 6)

---

### MVP User Flow (Galaxy Phone)

**User opens app:**
1. App launches in <2 seconds
2. Keyboard auto-opens with cursor in quick capture field
3. User types task title, hits Enter or "Add" button
4. Task appears at top of list below
5. User can immediately add another task (no navigation needed)

**User manages tasks:**
1. Tap checkbox to complete
2. Tap task to edit title/notes
3. Add tags by typing #tagname in title or dedicated tag field
4. Swipe left on task to delete (confirmation dialog)
5. Filter by tag using tag chips at top

**Key Metrics:**
- ⏱️ Time from app launch to task captured: <5 seconds
- ⏱️ App launch time: <2 seconds
- 📱 Works perfectly on Galaxy phone (primary device)
- 🔒 All data persists locally, no internet needed
- 🎨 Basic aesthetic (paper texture, warm colors)

---

## Development Roadmap (REVISED)

### Phase 1: MVP Foundation (4-6 weeks)

**Goal:** Get a working app into user's hands ASAP.

#### Sprint 1: Project Setup & Core Architecture (1 week)
- [ ] Initialize Flutter project
- [ ] Set up project structure (folders, files)
- [ ] Configure dependencies (sqflite, provider, etc.)
- [ ] Create database schema and DatabaseService
- [ ] Define Task and Tag models
- [ ] Set up theme with Witchy Flatlay colors
- [ ] Basic app shell (MaterialApp, routes)

**Deliverable:** Empty app with database and theme configured.

---

#### Sprint 2: Basic Task CRUD (1 week)
- [ ] Create TaskService (business logic)
- [ ] Implement task creation (in-memory)
- [ ] Implement task retrieval (list all)
- [ ] Implement task update
- [ ] Implement task deletion
- [ ] Connect to SQLite via DatabaseService
- [ ] Write unit tests for TaskService

**Deliverable:** TaskService working with SQLite, tested.

---

#### Sprint 3: List View UI (1-1.5 weeks)
- [ ] Build TaskListScreen (main screen)
- [ ] Build TaskItem widget (individual task display)
- [ ] Implement checkbox (mark complete/incomplete)
- [ ] Implement swipe-to-delete gesture
- [ ] Add confirmation dialog for deletion
- [ ] Connect UI to TaskProvider (state management)
- [ ] Add pull-to-refresh

**Deliverable:** Functional list view with complete/delete actions.

---

#### Sprint 4: Quick Capture & Editing (1 week)
- [ ] Build quick capture input field (top of list)
- [ ] Auto-focus keyboard on app launch
- [ ] Implement "Add Task" button
- [ ] Build task edit screen (tap task to edit)
- [ ] Add notes field (multiline text input)
- [ ] Implement save/cancel buttons
- [ ] Add task detail screen

**Deliverable:** Users can create, edit, and add notes to tasks.

---

#### Sprint 5: Tags & Filtering (1-1.5 weeks)
- [ ] Implement tag model and database schema
- [ ] Build tag input widget (chips, autocomplete)
- [ ] Add tags to task creation/edit flow
- [ ] Display tags on TaskItem widget
- [ ] Build tag filter UI (tap tag to filter)
- [ ] Implement tag-based filtering in TaskService
- [ ] Add tag color picker

**Deliverable:** Full tagging system with filtering.

---

#### Sprint 6: Search, Due Dates, Polish (1 week)
- [ ] Add search bar (filter by title/notes)
- [ ] Implement due date picker
- [ ] Display tasks with upcoming due dates prominently
- [ ] Sort options (by date created, due date, alphabetical)
- [ ] Empty state UI (when no tasks)
- [ ] Loading states
- [ ] Error handling (database errors, etc.)
- [ ] App icon and splash screen
- [ ] Performance testing on Galaxy phone

**Deliverable:** Polished MVP ready for user testing.

---

**Total Phase 1 Time:** 4-6 weeks (depending on developer experience with Flutter)

**Phase 1 Success Metrics:**
- ✅ App launches in <2 seconds
- ✅ Zero-friction task capture
- ✅ Stable on Galaxy phone (no crashes)
- ✅ All data persists correctly
- ✅ User actually uses it daily (the real test!)

---

### Phase 2: Claude AI Integration (2-3 weeks) 🚀 PRIORITY

**Goal:** Add "Claude, Help Me" chaos dump feature - THE #1 FUNCTIONAL FEATURE

**Why Phase 2:** This is the unique value proposition that differentiates Pin and Paper from simple notes apps. For ADHD users, AI-assisted organization is THE killer feature.

#### Features:
- [ ] API key management (encrypted storage with flutter_secure_storage)
- [ ] Settings screen to enter/save Claude API key
- [ ] "Brain Dump" screen (large text area for free-form thought capture)
- [ ] "Claude, Help Me" button
- [ ] Send dump to Claude API with structured prompt
- [ ] Parse Claude's response into task suggestions
- [ ] Preview screen showing suggested tasks
- [ ] User can approve/edit/delete suggestions before creating
- [ ] Bulk task creation from approved suggestions
- [ ] Natural language date parsing ("next Tuesday" → due date)
- [ ] Offline graceful degradation (disable button when no internet)
- [ ] Cost transparency (estimate API cost before sending)

**Technical Implementation:**
```dart
// Prompt template
final prompt = """
You are helping someone with ADHD organize their thoughts.
They've dumped the following text. Extract actionable tasks.

Return JSON: [{"title": "...", "notes": "...", "due_date": "...", "tags": [...]}]

User's brain dump:
$userText
""";
```

**Deliverable:** AI-assisted task organization - the core differentiator.

---

### Phase 3: Mobile Polish & Voice Input (2-3 weeks)

**Goal:** Optimize for daily use on Galaxy phone.

#### Features:
- [ ] Voice-to-text integration (speech_to_text package)
- [ ] Home screen widget for quick capture (home_widget package)
- [ ] Task nesting (subtasks with indentation)
- [ ] Collapsible task groups
- [ ] Keyboard shortcuts (e.g., Enter to add task quickly)
- [ ] Improved search (fuzzy matching)
- [ ] Task templates (common tasks as templates)
- [ ] Notifications for due dates
- [ ] Quick actions (swipe gestures for common operations)

**Deliverable:** Fully optimized mobile experience.

---

### Phase 4: Bounded Workspace View (3-4 weeks)

**Goal:** Build the spatial workspace with fixed/expandable canvas.

**REVISED APPROACH:** Fixed workspace (not infinite) to reduce complexity and performance issues.

#### Features:
- [ ] Bounded canvas with pan/zoom (e.g., 3000x3000 pixel area)
- [ ] CustomPaint-based card rendering (NOT widget tree)
- [ ] Drag-and-drop positioning
- [ ] Two-finger rotation gesture
- [ ] Pinch-to-resize
- [ ] Viewport culling (only render visible cards)
- [ ] Z-index management (stacking order)
- [ ] "Text-only" view toggle (performance mode)
- [ ] Torn paper strip aesthetic (custom clipping)
- [ ] Index card appearance (pushpins/clips)
- [ ] Canvas can grow when user runs out of space (but bounded, not infinite)

**Technical Considerations:**
- Performance easier with bounded canvas (can pre-calculate bounds)
- Simpler hit testing (no need for infinite coordinate system)
- Custom rendering with Skia
- Gesture conflicts require careful handling

**Deliverable:** Functional workspace view with bounded canvas (basic aesthetics).

---

### Phase 5: Sync & Backup (3-4 weeks)

**Goal:** Multi-device support (Galaxy phone ↔ iPad ↔ Linux desktop).

#### Features:
- [ ] Export/import (JSON or custom format)
- [ ] Google Drive integration (backup/restore)
- [ ] Basic sync (timestamp-based last-write-wins)
- [ ] Conflict resolution UI
- [ ] Auto-backup on app close
- [ ] Manual backup/restore controls

**Sync Strategy:**
- Use timestamp-based sync initially (simple)
- Later: Consider CRDTs for better conflict resolution

**Deliverable:** Multi-device workflow enabled.

---

### Phase 6: Aesthetic Enhancement (4-5 weeks)

**Goal:** Bring the "witchy scholarly cottagecore" aesthetic to life.

#### Features:
- [ ] Dynamic time-based lighting (5 states)
- [ ] Smooth lighting transitions (animated)
- [ ] Per-object shadows based on light direction
- [ ] Card customization (texture + pattern + effects)
- [ ] Conspiracy strings (Bezier curves connecting cards)
- [ ] Kraft paper tags on strings
- [ ] Decorative objects (draggable PNG objects)
- [ ] Canvas drawing (pen, pencil, highlighter)
- [ ] Z-ordering controls (send back, bring front)

**Technical:**
- Custom shaders for lighting effects
- Bezier curve drawing (Path API)
- Canvas drawing with pressure sensitivity

**Deliverable:** Full aesthetic experience.

---

### Phase 7: Journal & History (2-3 weeks)

**Goal:** Temporal awareness and productivity tracking.

#### Features:
- [ ] Daybook/calendar view
- [ ] Completed tasks archive
- [ ] Completion animations (strikethrough, fade, burn effect)
- [ ] "On this day" historical view
- [ ] Weekly/monthly summaries
- [ ] Productivity metrics (tasks completed, streaks)

**Deliverable:** Proof of productivity over time.

---

### Phase 8: iPad & Desktop Optimization (3-4 weeks)

**Goal:** Optimize for larger screens and stylus input.

#### iPad Features:
- [ ] Apple Pencil drawing with pressure sensitivity
- [ ] Larger canvas workspace
- [ ] Multi-finger gestures
- [ ] Split-view support

#### Desktop (Linux) Features:
- [ ] Keyboard shortcuts
- [ ] Mouse wheel zoom
- [ ] Precision selection with mouse
- [ ] Multiple windows (possibly)

**Deliverable:** Full cross-platform experience.

---

### Phase 9: Advanced Features (3-4 weeks)

**Goal:** Stretch goals and polish.

#### Features:
- [ ] Manila folder opening animation (card detail view)
- [ ] Cards within cards (nested projects)
- [ ] Flippable cards (front/back)
- [ ] Multi-page PDF viewing (spread view, page curl)
- [ ] Three theme system (Witchy, Teenage, Tweed)
- [ ] Custom theme creator
- [ ] Comprehensive undo/redo system (50-action history)
- [ ] Selective undo (undo specific past action)

**Deliverable:** Fully-featured app matching original vision.

---

### Phase 10: MCP Server & API Layer (3-4 weeks)

**Goal:** Build API layer and MCP connector for Claude integration.

#### Features:
- [ ] RESTful API design
- [ ] API server (Node.js/Express or Dart shelf)
- [ ] Authentication (user accounts)
- [ ] API documentation (OpenAPI/Swagger)
- [ ] MCP Server implementation
- [ ] Custom Claude connector
- [ ] Rate limiting and security

**Deliverable:** API-accessible app with MCP integration.

---

## Total Development Timeline (REVISED)

| Phase | Duration | Cumulative | Notes |
|-------|----------|------------|-------|
| Phase 1: MVP | 4-6 weeks | 6 weeks | Basic CRUD, tags, search |
| **Phase 2: Claude AI** | **2-3 weeks** | **9 weeks** | **🚀 #1 Priority Feature** |
| Phase 3: Mobile Polish | 2-3 weeks | 12 weeks | Voice, widget, nesting |
| Phase 4: Bounded Workspace | 3-4 weeks | 16 weeks | Fixed canvas (not infinite) |
| Phase 5: Sync & Backup | 3-4 weeks | 20 weeks | Multi-device support |
| Phase 6: Aesthetic Enhancement | 4-5 weeks | 25 weeks | Lighting, customization |
| Phase 7: Journal & History | 2-3 weeks | 28 weeks | Temporal awareness |
| Phase 8: Multi-Platform | 3-4 weeks | 32 weeks | iPad, desktop optimization |
| Phase 9: Advanced Features | 3-4 weeks | 36 weeks | Flippable cards, undo/redo |
| Phase 10: API & MCP | 3-4 weeks | **39 weeks** | Full API layer |

**Estimated Total:** 8-9 months for one full-time developer to reach full feature parity with the original vision.

**MVP to User Testing:** 4-6 weeks
**MVP + AI Integration:** 9 weeks (2 months) ← First truly differentiated version

---

## Risk Assessment & Mitigation

### High Risks

#### 🔴 Risk 1: Performance on Older Android Devices

**Description:** Complex rendering (rotated cards, shadows, lighting) may cause lag on mid-range devices.

**Impact:** High - Could make app unusable for target users

**Probability:** High (if not carefully optimized)

**Mitigation:**
- Test continuously on Galaxy A53 (mid-range device), not just flagship phones
- Implement performance monitoring (FPS counter in debug mode)
- Build "text-only" view as performance fallback
- Use viewport culling aggressively
- Optimize with CustomPaint instead of widget trees
- Profile with Flutter DevTools regularly

**Contingency:** If performance is unacceptable, pivot to simpler UI (less rotation, no dynamic lighting).

---

#### 🔴 Risk 2: Scope Creep

**Description:** Feature list is extremely ambitious. Easy to get lost in details and never ship.

**Impact:** Critical - Could result in abandoned project

**Probability:** High (given the extensive specifications)

**Mitigation:**
- **Ruthless prioritization:** Ship MVP in 6 weeks, no exceptions
- **User testing gates:** Don't move to Phase 2 until users validate Phase 1
- **Time-box features:** If a feature takes >1 week, cut scope or defer
- **Build in public:** Share progress to maintain accountability

**Contingency:** If falling behind, cut features. Better to ship a simple working app than a complex broken one.

---

#### 🔴 Risk 3: Aesthetic Vision vs. Technical Reality

**Description:** The "witchy cottagecore" aesthetic is complex. May be impossible to achieve in Flutter without native code.

**Impact:** Medium-High - Core differentiator of the app

**Probability:** Medium

**Mitigation:**
- Build simple first, iterate toward beauty
- Use reference apps (Pinterest, Notion) to validate feasibility
- Prototype complex interactions (rotation, lighting) early
- Be willing to compromise on perfection

**Contingency:** Accept that Flutter aesthetic won't match native iOS/SwiftUI apps. Good enough is better than perfect.

---

### Medium Risks

#### 🟡 Risk 4: Flutter Learning Curve

**Description:** If developer is new to Flutter, ramp-up time could delay MVP.

**Impact:** Medium - Adds 1-2 weeks to timeline

**Probability:** Medium (depends on developer experience)

**Mitigation:**
- Complete Flutter tutorial (flutter.dev/docs/get-started/codelab)
- Study reference apps (Flutter Gallery, sample projects)
- Use ChatGPT/Claude for quick answers
- Start simple (don't use advanced features right away)

---

#### 🟡 Risk 5: Multi-Device Sync Complexity

**Description:** Syncing data between phone, iPad, desktop is hard. CRDTs? Last-write-wins? Conflict resolution?

**Impact:** Medium - Phase 5 could take longer than planned

**Probability:** Medium

**Mitigation:**
- Start with simplest approach (timestamp-based sync)
- Use established services (Google Drive, Dropbox) instead of custom server
- Defer complex conflict resolution to later phase
- Build robust export/import as fallback

---

#### 🟡 Risk 6: iPad Stylus Experience

**Description:** Flutter's stylus support may not match native apps.

**Impact:** Medium - iPad is secondary platform

**Probability:** Medium

**Mitigation:**
- Set expectations: iPad is for "organizing" not "professional drawing"
- Use community packages (flutter_drawing_board)
- Accept limitations vs. native apps
- Focus on Galaxy phone (primary platform)

---

### Low Risks

#### 🟢 Risk 7: SQLite Database

**Description:** Database corruption, migration issues, performance.

**Impact:** Low - SQLite is battle-tested

**Probability:** Low

**Mitigation:**
- Use well-maintained sqflite package
- Implement database versioning/migrations from day 1
- Regular backups to prevent data loss
- Write thorough tests for database operations

---

#### 🟢 Risk 8: Claude API Changes

**Description:** Claude API could change, breaking integrations.

**Impact:** Low - Only affects Phase 3+ features

**Probability:** Low (Anthropic has stable API)

**Mitigation:**
- Use official Anthropic SDK
- Version API calls
- Graceful error handling
- Don't couple core features to AI

---

## Success Metrics

### Phase 1 (MVP) Success Criteria

**Technical Metrics:**
- ✅ App launches in <2 seconds on Galaxy phone
- ✅ 60fps scrolling in task list
- ✅ Zero data loss (all tasks persist correctly)
- ✅ Zero crashes in 1 week of testing

**User Metrics (Most Important):**
- ✅ User opens app daily
- ✅ User captures ≥5 tasks per day
- ✅ User reports it's "faster than Notes app"
- ✅ User completes tasks (not just adding endlessly)

**Aesthetic Metrics:**
- ✅ User finds it "pleasant to look at" (even in simple MVP form)
- ✅ Colors match Witchy Flatlay palette
- ✅ Typography is readable and attractive

---

### Long-Term Success Criteria (Phase 6+)

**User Engagement:**
- Users organize/beautify their workspace (not just list view)
- Users report feeling "productive" and "less chaotic"
- Users show the app to friends (organic growth)

**Multi-Device:**
- Seamless workflow between phone, iPad, desktop
- Users trust sync (no lost data)

**Aesthetic:**
- Users spend time customizing card appearance
- Users appreciate time-based lighting changes
- App is screenshot-worthy (shareable on social media)

**Proof of Productivity:**
- Users can see their accomplishments over time
- Completed task history provides "temporal awareness"
- Users feel motivated by seeing progress

---

## Next Steps (Immediate Actions)

### 1. Validate Tech Stack Choice
- [ ] Install Flutter SDK (latest stable)
- [ ] Set up development environment (VS Code + Flutter extension)
- [ ] Create "Hello World" Flutter app
- [ ] Test on Galaxy phone (confirm device is compatible)
- [ ] Familiarize with Flutter DevTools

---

### 2. Project Initialization
- [ ] Run `flutter create pin_and_paper`
- [ ] Set up git repository
- [ ] Configure pubspec.yaml with dependencies
- [ ] Create folder structure (models, services, screens, widgets)
- [ ] Set up linting and formatting rules

---

### 3. Database Design
- [ ] Finalize MVP database schema
- [ ] Create SQL migration scripts
- [ ] Implement DatabaseService class
- [ ] Write unit tests for database operations
- [ ] Test on real device (verify SQLite works correctly)

---

### 4. Design System Setup
- [ ] Extract exact hex colors from color-palettes.html
- [ ] Create theme.dart with Witchy Flatlay colors
- [ ] Define text styles (headings, body, etc.)
- [ ] Choose fonts (consider handwriting-style font for aesthetic)
- [ ] Create basic paper texture asset (simple PNG)

---

### 5. Prototype Core Interaction
- [ ] Build minimal task list UI
- [ ] Test quick capture flow (how fast can user add task?)
- [ ] Validate checkbox interaction (tap to complete)
- [ ] Test on Galaxy phone (is it intuitive?)
- [ ] Gather feedback from target user (Blue Kitty!)

---

### 6. Establish Development Workflow
- [ ] Set up hot reload (confirm it's working)
- [ ] Create development checklist
- [ ] Set up task tracking (use this app once MVP works, until then: GitHub issues)
- [ ] Schedule daily/weekly goals
- [ ] Plan user testing sessions (weekly show-and-tell with Blue Kitty)

---

## Conclusion

Pin and Paper is an ambitious project with a unique aesthetic vision. The proposed Flutter tech stack is **viable and appropriate**, but requires **significant scope reduction** and **pragmatic architecture choices** to achieve a successful MVP.

### Key Recommendations Summary:

1. ✅ **Use Flutter** - Right choice for cross-platform, custom rendering
2. ✅ **Use SQLite, not Hive** - Better for relational data and search
3. ✅ **Start with Provider** - Don't over-engineer state management
4. 🚀 **Claude AI in Phase 2** - #1 functional feature, unique differentiator
5. ⚠️ **Bounded workspace, not infinite** - Fixed canvas reduces complexity
6. ❌ **Don't build REST API yet** - Use service layer, defer API to Phase 5+
7. ❌ **Cut MVP scope** - Remove voice, widget, nesting from Phase 1
8. ⚠️ **Performance is critical** - Test on mid-range Android devices continuously
9. ⚠️ **Aesthetic is complex** - Build simple first, iterate toward beauty
10. 🚀 **Ship fast, then add AI** - 6-week MVP + 3-week AI = 9 weeks to killer feature

**The path to success:**
1. **Week 0-6:** Ship minimal MVP (basic CRUD, tags, search)
2. **Week 7-9:** Add Claude AI integration (THE differentiator)
3. Get it into user's hands (Galaxy phone)
4. Validate that AI-assisted organization actually helps ADHD users
5. Iterate based on real usage patterns
6. Gradually add workspace view and aesthetic features

**Most Important Question:** Does the "brain dump → Claude organizes → instant tasks" flow actually reduce chaos for ADHD users? If yes, everything else is polish.

---

**Document Version:** 1.1 (Revised based on user feedback)
**Last Updated:** 2025-10-25
**Revisions:**
- Moved Claude AI integration from Phase 3 to Phase 2 (identified as #1 functional feature)
- Changed "infinite canvas" to "bounded workspace" (fixed/expandable)
- Updated timeline: 39 weeks total (down from 40)
- Emphasized AI-assisted organization as core differentiator

**Next Review:** After MVP user testing (6 weeks)
