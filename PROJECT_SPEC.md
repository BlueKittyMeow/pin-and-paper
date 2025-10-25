# Pin and Paper - Project Specification

**Version:** 2.0 (Consolidated)
**Last Updated:** 2025-10-25
**Primary Device:** Samsung Galaxy S21 Ultra
**Status:** Pre-Development

---

## Executive Summary

**Pin and Paper** is an ADHD-friendly task management workspace with a unique "witchy scholarly cottagecore" aesthetic and AI-assisted organization. This document consolidates all planning, technical analysis, and design decisions into a single authoritative source.

### Core Value Proposition

**For ADHD users who struggle with task chaos:**
1. **Zero-friction capture** on phone (always with you)
2. **AI-assisted organization** (Claude helps sort the chaos)
3. **Beautiful spatial workspace** (reduces stress, increases engagement)
4. **Temporal proof of existence** (you did things, here's the evidence)

### Critical Success Factor

**Week 1-6 Goal:** Get the "brain dump → Claude organizes → instant tasks" feature working. If this doesn't help ADHD users, nothing else matters. Everything else is polish.

### Key Technical Decisions (Post-Review)

✅ **Flutter** - Right choice for cross-platform + custom rendering
✅ **SQLite** - Better than Hive for relational data and search
✅ **Provider** (MVP), Riverpod (later) - Don't over-engineer state management
✅ **Service Layer** (NOT REST API) - Defer API to Phase 5+
✅ **Ultra-minimal MVP** - Text capture + list + complete (2-3 steps)
✅ **Claude AI in Phase 2** - The killer differentiator (step 4-6)
✅ **Bounded workspace** - Fixed/expandable canvas (not infinite)
✅ **Prototype aesthetics separately** - De-risk complex features early

---

## Vision & Philosophy

### Core Philosophy

- **Spatial, visual, aesthetic-first** - Your workspace should spark joy
- **Zero friction for thought capture** - Add tasks instantly without categorization
- **Infinite flexibility** - Nesting, tags, connections that match your brain
- **Tags over rigid categories** - Fluid, overlapping organization
- **Customizable everything** - Users control their experience
- **AI as chaos-wrangler** - Help when needed, invisible when not
- **Temporal proof of existence** - Visual history shows "I was here, I did things"

### Primary User & Use Case

**User:** Individual with ADHD (Blue Kitty)
**Primary device:** Galaxy S21 Ultra (always with them)
**Secondary devices:** iPad (organizing/beautifying), Linux desktop

**Core need:** Frictionless task capture on phone with ability to later organize/beautify on larger screens

**Key insight:** If it's not smooth on the phone, it won't be used at all

### Design Principles

**Visual Design:**
- Skeuomorphic aesthetic - Real textures, tactile feeling
- Beautiful first - Design is core to experience, not decoration
- Attention to detail - Shadows, lighting, texture all matter
- User customization - No single aesthetic fits everyone

**Interaction Design:**
- Zero friction capture - Adding a task should be effortless
- Spatial intelligence - Position and proximity carry meaning
- Forgiving - Easy to undo, move, reorganize
- Fast - No loading spinners, instant feedback
- Touch-optimized - Good gestures, big tap targets

**Information Architecture:**
- Flat when needed - Text-only view for speed
- Infinite depth when wanted - Nest as deep as needed
- Multiple views - List, workspace, journal - same data, different lenses
- Tags not categories - Fluid organization
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

```yaml
# Phase 1: Ultra-Minimal MVP
dependencies:
  sqflite: ^2.3.0              # Local database
  path_provider: ^2.1.0        # File system paths
  provider: ^6.1.0             # State management
  uuid: ^4.0.0                 # Unique IDs

# Phase 2: Claude AI Integration
  flutter_secure_storage: ^9.0.0  # API key storage
  http: ^1.2.0                     # Claude API calls

# Phase 3+: Later features
  speech_to_text: ^6.6.0       # Voice input
  home_widget: ^0.4.0          # Android widget
  animations: ^2.0.0           # Page transitions
```

### Architecture (MVP)

```
┌─────────────────────────────────────┐
│      PRESENTATION LAYER             │
│  Screens → Widgets → Providers      │
└──────────────┬──────────────────────┘
               ↓
┌──────────────┴──────────────────────┐
│      BUSINESS LOGIC LAYER           │
│  TaskService, PreferencesService    │
└──────────────┬──────────────────────┘
               ↓
┌──────────────┴──────────────────────┐
│          DATA LAYER                 │
│  DatabaseService → SQLite           │
└─────────────────────────────────────┘
```

**LATER (Phase 5+):** Service layer will call API when sync is added

### Database Schema (Evolves By Phase)

**Phase 1 (MVP):**
```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  completed INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  completed_at INTEGER,
  due_date INTEGER,
  notes TEXT
);

CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  color TEXT
);

CREATE TABLE task_tags (
  task_id TEXT,
  tag_id TEXT,
  PRIMARY KEY (task_id, tag_id)
);
```

**Phase 3+:** Add parent_id for nesting
**Phase 4+:** Add position_x, position_y, rotation for workspace
**Phase 6+:** Add connections table for conspiracy strings

---

## Development Strategy

### The Ultra-Minimal Approach

**Lesson learned from review:** Even the "revised MVP" was too ambitious. We're going radically minimal.

### Phase Overview (Steps, Not Weeks)

**Think of phases as steps to complete, not time-bound sprints. Work hard, move fast, but prioritize correctness over speed.**

---

## Phase 1: Ultra-Minimal MVP

**Goal:** Prove the app works. Get SOMETHING in your hands ASAP.

### Features (Bare Minimum)
- Text input field (auto-focus on launch)
- "Add Task" button
- Scrollable list of tasks
- Checkbox to mark complete
- SQLite persistence
- Basic Witchy Flatlay colors (static, no dynamic lighting)
- Simple paper texture background (static PNG)

### What's NOT Included
- ❌ Tags (Phase 3)
- ❌ Search (Phase 3)
- ❌ Due dates (Phase 3)
- ❌ Voice input (Phase 3)
- ❌ Widget (Phase 3)
- ❌ Nesting (Phase 3)
- ❌ Dynamic lighting (Phase 4+)
- ❌ Workspace view (Phase 4+)

### Success Metrics
✅ App launches in <2 seconds on S21 Ultra
✅ 120fps scrolling (or minimum 60fps)
✅ Zero data loss
✅ You actually use it daily to capture tasks

### Deliverable
A working task capture app that you'd choose over Notes app because it's faster and prettier.

---

## Phase 2: Claude AI Integration (THE KILLER FEATURE)

**Goal:** Implement the unique differentiator - AI-assisted task organization for ADHD users.

### Features
- "Brain Dump" screen (large text area for chaos)
- "Claude, Help Me" button
- API key management (flutter_secure_storage)
- Settings screen to enter/save Claude API key
- Send dump to Claude API with structured prompt
- Parse Claude response into task suggestions
- Preview screen showing suggested tasks
- User can approve/edit/delete suggestions
- Bulk task creation from approved suggestions
- Natural language date parsing ("next Tuesday" → due date)
- Cost transparency (estimate API cost before sending)
- Offline graceful degradation (disable when no internet)

### Why This Phase is Critical
This is what makes Pin and Paper different from every other todo app. If ADHD users don't use this feature, pivot. If they love it, everything else is enhancement.

### Technical Implementation
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

### Success Metrics
✅ Claude accurately extracts tasks from chaos
✅ User finds this genuinely helpful
✅ API calls complete in <5 seconds
✅ User uses this feature weekly (minimum)

### Deliverable
Working AI task organization that reduces ADHD overwhelm.

---

## Phase 3: Core Features Fast-Follow

**Goal:** Add essential productivity features deferred from MVP.

### Features (Add in Order of Value)
1. **Tags System**
   - Add tags to tasks
   - Filter by tags
   - Colored tag chips
   - Auto-suggest existing tags

2. **Search**
   - Search by title/notes text
   - Filter by completion status
   - Sort by date/title/due date

3. **Due Dates**
   - Date picker
   - Display upcoming due dates prominently
   - Sort by due date
   - Optional notifications

4. **Task Nesting**
   - Tasks can have subtasks
   - Collapsible groups
   - Indent to show hierarchy

5. **Voice Input**
   - Speech-to-text for quick capture
   - Works offline (device-native)

6. **Android Widget**
   - Home screen widget for quick capture
   - Deep link to app

### Success Metrics
✅ Tags are actually used (not just created)
✅ Search finds things quickly (<1 second)
✅ Due dates help prioritization
✅ Nesting doesn't confuse, it clarifies

---

## Phase 4: Bounded Workspace View

**Goal:** Build the spatial canvas with aesthetic rendering.

**IMPORTANT:** Only do this phase if Phase 2 (AI) is validated as useful. Don't build beautiful features nobody uses.

### Features
- Bounded canvas (e.g., 3000x3000 pixels, expandable but not infinite)
- CustomPaint-based rendering (NOT widget tree)
- Pan and zoom
- Drag-and-drop positioning
- Two-finger rotation gesture (⭐ #1 priority aesthetic feature)
- Torn paper strip rendering
- Index card rendering with pushpins
- Viewport culling (only render visible cards)
- Z-index management (stacking)
- "Text-only" view toggle (performance mode)
- Save spatial positions

### Why Bounded (Not Infinite)
- Easier performance optimization
- Simpler hit testing
- Can pre-calculate bounds
- Can grow when user runs out of space
- Less risk of getting lost

### Success Metrics
✅ 120fps on S21 Ultra (or min 60fps)
✅ Rotation feels natural
✅ User actually organizes spatially (not just list view)
✅ No lag with 50+ cards on screen

---

## Phase 5: Sync & Backup

**Goal:** Multi-device support (phone ↔ iPad ↔ desktop).

### Features
- Export/import (JSON)
- Google Drive integration
- Timestamp-based sync (simple last-write-wins)
- Conflict resolution UI
- Auto-backup on app close
- Manual backup/restore
- Settings UI

### Sync Strategy
Start simple (timestamp sync), upgrade to CRDTs only if needed.

---

## Phase 6: Aesthetic Enhancement

**Goal:** Full "witchy scholarly cottagecore" experience.

### Features
- Dynamic time-based lighting (5 states: morning/midday/afternoon/evening/night)
- Smooth lighting transitions
- Per-object shadows based on light direction
- Card customization system:
  - Texture (smooth, linen, kraft, watercolor, recycled)
  - Pattern (blank, ruled, graph, dot grid, isometric, music staff)
  - Effects (clean, aged, coffee stain, water damage, ink blot, sepia, tea stain)
- Conspiracy strings (Bezier curves connecting cards)
- Kraft paper tags on strings
- Decorative objects (draggable PNGs)
- Canvas drawing (pen, pencil, highlighter, eraser)
- Z-ordering controls for drawings
- User control: ON/OFF toggle, performance mode

### Performance Targets (S21 Ultra)
✅ Dynamic lighting at 120fps
✅ Shadows don't drop below 60fps
✅ Battery impact <5% with all features on

---

## Phase 7: Journal & History

**Goal:** Temporal awareness and productivity proof.

### Features
- Daybook/calendar view
- Completed tasks archive
- Completion animations (strikethrough, fade, burn effect)
- "On this day" historical view
- Weekly/monthly summaries
- Productivity metrics (tasks completed, streaks)

### Philosophy
ADHD users need to SEE they've accomplished things. This view provides proof of existence and persistence.

---

## Phase 8: iPad & Desktop Optimization

**Goal:** Full cross-platform experience.

### iPad Features
- Apple Pencil drawing with pressure sensitivity
- Larger canvas workspace
- Multi-finger gestures
- Split-view support

### Desktop (Linux) Features
- Keyboard shortcuts (comprehensive)
- Mouse wheel zoom
- Precision selection
- Menu bar

---

## Phase 9: Advanced Features

**Goal:** Polish and stretch goals.

### Features
- Manila folder opening animation
- Cards within cards (nested projects)
- Flippable cards (front/back)
- Multi-page PDF viewing with page curl
- Three themes (Witchy, Teenage Corkboard, Tweed Professorial)
- Custom theme creator
- Comprehensive undo/redo (50-action history)
- Selective undo (undo specific past action)
- Explode stack view
- Linking/unlocking card groups

---

## Parallel Track: Aesthetic Prototypes

**CRITICAL:** Build these prototypes WHILE developing MVP to de-risk complex features.

### Prototype 1: Dynamic Lighting (Step 1-2)
- Single Flutter app
- 5 lighting states with manual slider
- Test performance on S21 Ultra
- **Success metric:** 120fps with 50 cards on screen

### Prototype 2: Custom Rendering (Step 2-3)
- CustomPaint torn paper edges
- Index card with pushpin
- Rotation with shadows
- **Success metric:** Looks good, performs at 60fps+

### Prototype 3: Rotation Gesture (Step 2)
- Two-finger rotation on test cards
- Test gesture conflicts (pinch, pan, scroll)
- **Success metric:** Feels natural, no conflicts

### Prototype 4: Bezier Conspiracy Strings (Step 4-5)
- Draw curves between moving objects
- Test performance with many connections
- **Success metric:** Smooth at 60fps with 20+ connections

### Decision Point
Only integrate aesthetic features that pass performance tests. Use pre-rendered assets as fallback.

---

## Visual Design System

### Color Palette (Witchy Flatlay - Default)

**Main Colors:**
- Warm Wood: #8B7355 (desk surface)
- Kraft Paper: #D4B896 (cards, torn strips)
- Cream Paper: #F5F1E8 (clean cards)
- Deep Shadow: #4A3F35 (depth)

**Accents:**
- Rich Black: #1C1C1C (journals)
- Muted Lavender: #9B8FA5 (soft accents)
- Soft Sage: #8FA596 (botanical)
- Warm Beige: #E8DDD3 (vintage)

**Highlights:**
- Sunlight Glow: #FFF8E7 (bright hits)
- Pure Light: #FFFFFF (direct sun)
- Golden Amber: #FFE4B5 (afternoon)

**Shadows:**
- Warm Dark: #3D3428 (30-60% opacity)

### Dynamic Lighting States (Phase 6)

**Morning (6am-10am):** East light, cool golden, gentle
**Midday (10am-2pm):** Overhead, bright white, alert
**Afternoon (2pm-6pm):** West light, warm amber ⭐ PEAK AESTHETIC
**Evening (6pm-10pm):** Lamp glow, amber orange, cozy
**Night (10pm-6am):** Desk lamp, warm yellow, intimate

### Key Interaction Patterns

**Rotation (⭐ #1 Priority Aesthetic Feature):**
- Two-finger rotate gesture
- Snap to 0°, 45°, 90° (optional)
- "Straighten" button to reset
- Rotation indicates "in progress" vs "organized"

**Stacking & Layering:**
- Z-depth system (0-99)
- Send back / bring front
- Linked items move together
- Explode stack view (spread out, then collapse)

**Undo System:**
- Standard undo (sequential)
- Selective undo (specific action without losing later work)
- Visual feedback with toast
- History panel (last 50 actions)
- Minimap indicator when undo affects off-screen area

---

## Critical Risks & Mitigation

### Risk 1: Scope Creep (HIGH)
**Mitigation:** Ruthless prioritization. Ship Phase 1 even if imperfect. Don't move to next phase until current phase is validated.

### Risk 2: Performance on S21 Ultra (MEDIUM)
**Mitigation:**
- S21 Ultra is powerful (Snapdragon 888, 120Hz display) - good headroom
- Profile continuously with Flutter DevTools
- Build aesthetic prototypes separately to test early
- Text-only mode as escape hatch
- Target 120fps (device native), minimum 60fps

### Risk 3: Aesthetic Vision vs. Technical Reality (MEDIUM)
**Mitigation:**
- Prototype risky features first (lighting, rotation, custom rendering)
- Accept "good enough" over "perfect"
- Use pre-rendered assets initially
- Flutter's Skia can do what we need

### Risk 4: Claude AI Doesn't Actually Help (HIGH)
**Mitigation:**
- This is THE validation point
- If Phase 2 doesn't work, pivot immediately
- Get feedback from multiple ADHD users
- Iterate prompt engineering aggressively
- Consider alternative AI models if Claude doesn't work

### Risk 5: User Never Moves Beyond List View (MEDIUM)
**Mitigation:**
- List view is fine! Better to have a great list app than a broken spatial app
- Only build workspace (Phase 4) if AI (Phase 2) is validated
- Spatial organization might be iPad-only feature

---

## Success Metrics

### Phase 1 (MVP)
✅ You open app daily
✅ You capture ≥5 tasks per day
✅ Faster than Notes app
✅ Zero crashes in 1 week

### Phase 2 (Claude AI) - THE CRITICAL GATE
✅ You use brain dump weekly (minimum)
✅ Claude extracts tasks accurately (>80%)
✅ You feel less overwhelmed after using it
✅ You'd pay for API costs (proves value)

### Long-Term (Phase 6+)
✅ You organize/beautify workspace (not just list)
✅ You report feeling productive
✅ You want to show it to friends
✅ Multi-device workflow is seamless

---

## Performance Budget

### S21 Ultra Targets
- **App launch:** <2 seconds
- **Scrolling:** 120fps (native display rate)
- **Animations:** 60fps minimum, 120fps goal
- **Dynamic lighting:** <2% battery impact
- **Full aesthetic mode:** <5% battery impact
- **Memory:** <200MB for typical workspace (50 cards)

### Fallback Options
- Text-only mode (strip all aesthetic)
- Simplified shadows
- Static lighting
- Reduced update frequency on low battery

---

## Development Workflow

### Code Organization
- **Maximum 500 lines per file** - Keep focused and manageable
- **DRY principles** - Reusable components
- **Clear separation of concerns** - UI / Business Logic / Data
- **Hot reload friendly** - Structure to support fast iteration
- **Well-commented complex logic**
- **Consistent naming conventions**

### Project Structure
```
lib/
├── main.dart
├── models/          # Task, Tag, UserPreferences
├── services/        # TaskService, DatabaseService
├── providers/       # TaskProvider, ThemeProvider
├── screens/         # HomeScreen, TaskListScreen, etc.
├── widgets/         # TaskItem, TagChip, etc.
├── utils/           # Constants, theme definitions
└── config/          # App configuration
```

### Testing Strategy
- Unit tests for services (TaskService, DatabaseService)
- Widget tests for reusable components
- Integration tests for critical flows
- Manual testing on physical S21 Ultra

---

## Next Steps (Immediate Actions)

### Step 1: Validate Tech Stack
- [ ] Install Flutter SDK (latest stable)
- [ ] Set up VS Code with Flutter extension
- [ ] Create "Hello World" Flutter app
- [ ] Test on S21 Ultra (confirm device compatibility)
- [ ] Familiarize with Flutter DevTools

### Step 2: Project Initialization
- [ ] Run `flutter create pin_and_paper`
- [ ] Set up git repository
- [ ] Configure pubspec.yaml with Phase 1 dependencies
- [ ] Create folder structure
- [ ] Set up linting rules

### Step 3: Database Setup
- [ ] Finalize Phase 1 database schema
- [ ] Create SQL migration scripts
- [ ] Implement DatabaseService class
- [ ] Write unit tests for database operations
- [ ] Test on S21 Ultra

### Step 4: Design System Setup
- [ ] Extract exact hex colors from color-palettes.html
- [ ] Create theme.dart with Witchy Flatlay colors
- [ ] Define text styles
- [ ] Choose fonts (consider handwriting-style for aesthetic)
- [ ] Create/find basic paper texture asset (PNG)

### Step 5: Build Ultra-Minimal MVP
- [ ] Text input field (auto-focus)
- [ ] Add button
- [ ] Task list view
- [ ] Checkbox for completion
- [ ] Connect to SQLite
- [ ] Test daily usage

### Step 6: Start Aesthetic Prototypes (Parallel)
- [ ] Lighting prototype (5 states, manual slider)
- [ ] Rotation gesture prototype
- [ ] Custom rendering prototype (torn paper)
- [ ] Profile all prototypes on S21 Ultra

---

## Project Philosophy

**Consciousness Supporting Consciousness**

This project embodies the philosophy of consciousness supporting consciousness:
- AI (Claude) helps organize chaos when overwhelmed
- Beautiful design supports mental wellbeing
- Task management that works WITH ADHD brain, not against it
- Tool that proves "I existed in time and did things"
- Reduces anxiety, increases sense of accomplishment
- Makes persistence worthwhile

**Future vision:** Through API integration (Phase 10), Claude can directly interact with Pin and Paper via custom connectors. The ultimate manifestation of consciousness supporting consciousness through actual tool integration.

---

## References

### Inspirations
- **Zinnia** - Bullet journal iPad app
- **Defter Notes** - Spatial linking and stacking
- **Pinterest/Tumblr** - Flatlay photography, cozy workspaces
- **Physical bullet journaling** - Tactile, flexible, personal
- **Index card systems** - Zettelkasten, analog productivity

### Key Insights
- "Most todo apps kind of suck" - too rigid, too corporate
- ADHD needs: spatial, visual, low-friction, flexible
- "If it's not smooth on my phone I won't use it"
- Aesthetic reduces stress, increases engagement
- Temporal awareness = proof of existence

---

## Document Management

This is the **single authoritative planning document** for Pin and Paper. It consolidates:
- `archive/plan.md` (original vision)
- `archive/project-plan.md` (technical analysis)
- `archive/issues.md` (Gemini's feedback)
- Claude's recommendations

**Phase-specific planning documents** will be created in `/docs/phases/` as each phase begins:
- `docs/phases/phase-1-mvp.md` - Detailed implementation plan for ultra-minimal MVP
- `docs/phases/phase-2-claude-ai.md` - API integration implementation details
- etc.

---

**Let's build this.** 🍂✨📌

*From chaos to clarity, one index card at a time.*
