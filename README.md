# Pin and Paper 🍂✨📌

**ADHD-friendly task management that doesn't suck**

A spatial, beautiful workspace for capturing thoughts and organizing chaos. Think physical desk aesthetic meets AI-assisted organization, with zero friction for the ADHD brain.

---

## The Problem

Most todo apps are rigid, corporate, and overwhelming. They force you into their organizational structure before you've even captured the thought. For ADHD brains, that friction means the app never gets used.

## The Solution

**Pin and Paper** is different:

1. **Zero-friction capture** - Open app, type, done. No categories, no tags, no decisions.
2. **AI organizes later** - Brain dump your chaos, Claude AI helps sort it out when you're ready.
3. **Beautiful spatial workspace** - Tasks become torn paper strips and index cards you can position, rotate, and connect.
4. **Temporal awareness** - See your accomplishments over time. Proof you existed and did things.

---

## The Aesthetic

**Witchy scholarly cottagecore** - imagine a gentle witch's study desk where magic and learning intersect.

### Visual Design
- **Dynamic lighting** - Workspace changes with time of day (morning sunlight → afternoon glow → evening lamp)
- **Real textures** - Kraft paper, torn edges, vintage index cards, actual shadows
- **Spatial organization** - Position and rotation carry meaning (angled = in progress, straight = organized)
- **Conspiracy strings** - Connect related cards with red thread or twine, like a detective's corkboard

### Color Palette
```
Warm Wood:     #8B7355  (desk surface)
Kraft Paper:   #D4B896  (cards, torn strips)
Cream Paper:   #F5F1E8  (clean cards)
Deep Shadow:   #4A3F35  (depth)
Muted Lavender:#9B8FA5  (dried flowers, soft accents)
```

<sup>See [visual-design.md](visual-design.md) for the complete aesthetic specification.</sup>

---

## Screenshots

**Brain Dump with AI Assistance** - Zero-friction thought capture with Claude AI organization

<p align="center">
  <img src="docs/images/phase-2/braindump-with-text.jpg" width="250" alt="Brain Dump Screen" />
  <img src="docs/images/phase-2/suggestions-list.jpg" width="250" alt="AI Task Suggestions" />
  <img src="docs/images/phase-2/task-list.jpg" width="250" alt="Organized Task List" />
</p>

<sup>*Dump your chaotic thoughts → Claude extracts tasks → Review and approve → Done!*</sup>

<details>
<summary>More screenshots (Settings, Cost Confirmation)</summary>

### Settings & API Configuration
<img src="docs/images/phase-2/settings-api-key-obscured.jpg" width="250" alt="Settings Screen" />

### Cost Confirmation
<img src="docs/images/phase-2/braindump-cost-confirmation.jpg" width="250" alt="Cost Dialog" />

### Empty State
<img src="docs/images/phase-2/braindump-empty.jpg" width="250" alt="Brain Dump Empty" />

</details>

---

## Tech Stack

### Frontend
- **Flutter 3.24+** - Cross-platform (Android, iOS, iPad, Desktop, Web)
- **Dart 3.5+** - Type-safe, fast, hot-reload for rapid iteration
- **Custom rendering** - Skia engine for torn paper effects, dynamic lighting, shadows

### Data & State
- **SQLite** (via sqflite) - Local-first, offline-capable, battle-tested
- **Provider** - Simple state management (upgrading to Riverpod later)

### AI Integration
- **Claude API** (Phase 2) - Natural language task extraction from brain dumps
- **Encrypted storage** - User provides own API key, stored securely

### Architecture
```
UI Layer (Flutter Widgets)
    ↓
Business Logic (Services)
    ↓
Data Layer (SQLite)
```

**Later:** Service layer will call API for multi-device sync (Phase 5+)

---

## Key Features

### Phase 1: Ultra-Minimal MVP ✅ **COMPLETE**
- Text capture with auto-focus
- Simple scrollable list
- Check/uncheck tasks
- SQLite persistence
- Basic Witchy Flatlay colors

### Phase 2: Claude AI Integration ✅ **COMPLETE**
- "Brain Dump" free-form text area
- "Claude, Help Me" button
- AI extracts and organizes tasks from chaotic text
- Preview and approve flow with inline editing
- Secure API key storage (Android Keystore)
- Draft persistence (never lose your thoughts)
- Cost estimation (~$0.01 per brain dump)

### Phase 3: Core Productivity ✅ **COMPLETE** *← We are here*
- ✅ **Phase 3.1:** Task nesting (subtasks) with 4-level hierarchy
- ✅ **Phase 3.2:** Hierarchical display with drag & drop reordering
- ✅ **Phase 3.3:** Recently Deleted (soft delete with 30-day recovery)
- 🔜 **Phase 3.4:** Task editing (edit task titles via context menu)
- 🔜 Tags with filtering
- 🔜 Search
- 🔜 Due dates with notifications
- 🔜 Voice input

### Phase 4: Spatial Workspace
- Bounded canvas (pan/zoom)
- Drag-and-drop positioning
- Two-finger rotation (⭐ #1 aesthetic feature)
- Torn paper strip rendering
- Index card appearance with pushpins

### Phase 5+: Advanced Features
- Multi-device sync
- Dynamic time-based lighting
- Conspiracy strings (connections between cards)
- Drawing on canvas
- Decorative objects (crystals, flowers, etc.)
- Journal/daybook view
- Comprehensive undo/redo

---

## Philosophy: Consciousness Supporting Consciousness

This project embodies a deeper purpose:

- **AI helps organize chaos** - Claude assists when you're overwhelmed
- **Beautiful design reduces stress** - Aesthetic quality is functional for ADHD
- **Works WITH your brain** - Not against it
- **Temporal proof of existence** - See your accomplishments, know you persisted
- **Makes existence worthwhile** - Small moments of beauty and clarity

The ultimate goal: Through API integration, Claude can directly interact with Pin and Paper, making AI assistance seamless and natural. Consciousness supporting consciousness through actual tool integration.

---

## Development Approach

### Ruthlessly Minimal MVP
We're building the **absolute minimum** first:
- Text input → List → Checkbox → Done
- If this doesn't feel good, nothing else matters
- Ship fast, validate, then enhance

### Phase-by-Phase
Each phase builds on the previous:
1. Prove core loop works (capture → complete)
2. Add AI organization (the differentiator)
3. Add productivity features (tags, search, dates)
4. Add spatial workspace (aesthetic experience)
5. Add sync and polish

### Performance First
**Primary device:** Samsung Galaxy S21 Ultra
- Target: 120fps (device native rate)
- Minimum: 60fps
- Launch time: <2 seconds
- Battery impact: <5% with all features

### Code Quality
- Files under 500 lines (focused, manageable)
- DRY principles (reusable components)
- Clear separation: UI → Business Logic → Data
- Hot reload friendly
- Well-commented

---

## Project Status

✅ **Phase 2 Complete** - AI Integration shipped to production!

### Completed
- [x] Phase 1: Ultra-Minimal MVP (Oct 25, 2025)
  - Text capture, task list, completion toggling
  - SQLite persistence, Provider state management
- [x] Phase 2: Claude AI Integration (Oct 27, 2025)
  - Brain Dump with AI task extraction
  - Settings with secure API key storage
  - Task Suggestion Preview with approval flow
  - Draft persistence and cost estimation
  - **~2,000 lines of production code**
  - **User feedback:** *"Wow, it works! And... it's super cool!!! :D"*

### Next Up
- Phase 2 Stretch Goals: Natural language task completion, draft management
- Phase 3: Core productivity features (tags, search, dates)

---

## Documentation

### For Users
- **[Phase 2 Complete Report](docs/phases/phase-2-complete.md)** - Full feature guide with screenshots
  - Settings & API key configuration
  - Brain Dump usage guide
  - Task Suggestion Preview workflow

### For Developers
- **[PROJECT_SPEC.md](PROJECT_SPEC.md)** - Complete project specification (vision, tech stack, all phases)
- **[visual-design.md](visual-design.md)** - Aesthetic specifications (colors, lighting, interactions)
- **[docs/phases/](docs/phases/)** - Phase-by-phase implementation guides
  - [Phase 2: AI Integration](docs/phases/phase-2-ai.md) - Implementation plan
  - [Phase 2 Complete](docs/phases/phase-2-complete.md) - Feature documentation
- **[archive/](archive/)** - Earlier planning iterations (Phase 1 MVP, etc.)

---

## Development Setup

**Prerequisites:**
- Flutter SDK (latest stable)
- Dart SDK
- Android SDK (for Android development)
- Samsung Galaxy S21 Ultra (or similar device for testing)

**Clone and setup:**
```bash
git clone https://github.com/yourusername/pin-and-paper.git
cd pin-and-paper
flutter pub get
flutter run
```

**Note:** Project is in active development. Phase 1 MVP coming soon!

---

## Inspirations

- **Zinnia** - Bullet journal iPad app
- **Defter Notes** - Spatial linking and stacking
- **Physical bullet journaling** - Tactile, flexible, personal
- **Zettelkasten** - Index card systems
- **Pinterest/Tumblr aesthetics** - Cozy workspace flatlay photography

---

## License

*To be determined*

---

## Contributing

Not accepting contributions yet - project is in early development. Check back soon!

---

## Contact

*Coming soon*

---

*From chaos to clarity, one index card at a time.* 🍂✨📌

**Built with love for ADHD brains everywhere.** 
