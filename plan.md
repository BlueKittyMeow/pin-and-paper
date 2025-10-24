# Pin and Paper - Project Specification

## Overview
**Pin and Paper** is an aesthetic, ADHD-friendly, AI-enhanced task management workspace that prioritizes zero-friction capture, infinite flexibility, and beautiful visual design.

### Core Philosophy
- **Spatial, visual, aesthetic-first** - Your workspace should spark joy, not dread
- **Zero friction for thought capture** - Add tasks instantly without categorization
- **Infinite flexibility** - Infinite nesting, infinite canvas, complete customization
- **Tags over rigid categories** - Fluid, overlapping organization that matches real life
- **Customizable everything** - Users control their experience
- **AI as optional chaos-wrangler** - Help when needed, invisible when not
- **Temporal proof of existence** - Visual history that shows "I was here, I did things"

---

## Platform & Technology

### Tech Stack: Flutter
**Why Flutter:**
- Single codebase for Android, iOS, Linux, Windows, Web
- Hot reload for rapid iteration (1-2 second UI updates)
- Custom rendering engine (Skia) perfect for aesthetic effects
- Excellent animation framework for lighting/transitions
- Strong touch/gesture support for iPad drawing
- Native-level performance

### Development Environment
- VSCode/Cursor AI with Flutter + Dart extensions
- Command-line friendly workflow
- Live preview on physical devices (Galaxy phone, iPad)
- No Android Studio required

### Priority Platform Order
1. **Android phone** (Galaxy) - Primary use case, must be frictionless
2. **iPad** - Full aesthetic experience, drawing capabilities
3. **Linux desktop** - Full workspace
4. **Web/Windows** - Stretch goals

---

## User Story & Primary Use Case

**Primary user:** Individual with ADHD (Blue Kitty! 🐱)
**Primary device:** Galaxy phone (always with them)
**Secondary devices:** iPad (for organizing/beautifying), Linux desktop

**Core need:** Frictionless task capture on phone with ability to later organize/beautify on larger screens

**Key insight:** If it's not smooth on the phone, it won't be used at all

---

## Feature Phases

## Phase 1: MVP - No Friction Utility

**Goal:** Get basic task capture and management working smoothly on Android phone

### Essential Features
1. **Quick Task Capture**
   - Text input
   - Voice-to-text dictation
   - Widget for homescreen quick add
   - Minimal friction - open app, type/speak, done

2. **Simple List View**
   - View all tasks in clean list
   - Checkbox to complete
   - Basic search/filter
   - Tags (add/view)

3. **Text-Only View Toggle**
   - Stripped down, fast-loading view
   - Dot grid paper aesthetic
   - No fancy rendering when you just need the list
   - Perfect for phone quick-checks

4. **"Claude, Help Me" Chaos Dump**
   - Free-form text input area
   - User can word-vomit all their tasks/stress
   - AI processes and organizes:
     - Asks clarifying questions if needed
     - Proposes organization plan
     - User approves/adjusts
   - **"Yolo Mode" toggle:** Just do it, trust the AI sorting

5. **Basic Task Management**
   - Create, complete, delete tasks
   - Optional due dates
   - Tags (add/remove/filter)
   - Basic nesting (tasks can have subtasks)

6. **Data Persistence**
   - Local storage (SQLite or Hive)
   - Offline-first
   - Fast access

### Data Model Foundation
Design database schema that supports future features:

```dart
Task {
  id: String
  title: String
  completed: bool
  created_at: DateTime
  completed_at: DateTime?
  due_date: DateTime?
  tags: List<String>
  parent_id: String?  // For nesting
  position_x: double? // For spatial positioning later
  position_y: double? // For spatial positioning later
  visual_style: JSON? // For future customization
  notes: String?
  type: enum // 'strip', 'card', 'item'
}

Connection {
  id: String
  from_task_id: String
  to_task_id: String
  style: JSON? // color, type of string
  note: String?
}

UserPreferences {
  theme: String
  default_view: String // 'list', 'workspace', 'text-only'
  lighting: JSON?
  decorations: JSON?
}
```

---

## Phase 2: Aesthetic Experience

**Goal:** Beautiful, customizable workspace view with spatial organization

### Features

1. **Main Workspace View - Infinite Canvas**
   - Pan/scroll/zoom
   - Spatial positioning of elements
   - Drag and drop everything
   - Save position state

2. **Visual Elements**

   **Torn Paper Strips** (quick capture)
   - Minimal task capture from Phase 1
   - Rendered as torn paper strips in workspace
   - Can be dragged to different areas
   - Can become: card, subtask, completed, trashed

   **Index Cards** (projects/categories)
   - Visual representation of task groups
   - Customizable appearance:
     - Sketch/draw on cards
     - Highlight
     - Change pushpin/clip style
     - Different card colors/textures
   - Tags visible on card face
   - Click to open full card view
   - Can stack, group, cluster spatially

   **Conspiracy Strings** 
   - Visual connections between cards
   - Customizable appearance:
     - Color
     - Style (yarn, twine, ribbon, red thread)
     - Thickness
   - Optional kraft paper tags on strings with notes
   - Types of connections:
     - Dependencies (can't do X until Y done)
     - Thematic links
     - "Brain says these connect"

   **Decorative Objects**
   - User can add objects to their workspace
   - Some functional (memory aids, shortcuts)
   - Some purely aesthetic (plants, coffee cups, etc.)
   - All draggable

3. **Customizable Desk Aesthetic Themes**
   - **Witchy Flatlay:** Sunlight, lavender sprig, teacup, crystals
   - **Teenage Corkboard:** Ribbons crisscrossing, pushpins, photos
   - **Tweed Professorial:** Vintage desk accessories, leather, wood
   - More themes as stretch goals
   - Users can customize/mix themes

4. **Dynamic Lighting**
   - Time-of-day based lighting:
     - Morning: Soft golden light from east
     - Midday: Bright overhead
     - Afternoon: Slanted beam across desk (peak aesthetic!)
     - Evening: Warm amber lamp glow
     - Night: Moonlight + desk lamp, cozy dark mode
   - **Stretch goals:**
     - Seasonal lighting changes
     - Weather effects (rainy day, snow)
     - User can override/pause time
     - User can set custom lighting

5. **Inside Card View**
   - Click card → full screen view
   - Manila folder aesthetic (customizable)
   - Individual task items with checkboxes
   - Infinite nesting of subtasks
   - Optional due dates per item
   - Tall fold-over slip for project notes
   - Tags display/edit
   - Toggle to view completed items within card

6. **iPad Drawing/Sketching**
   - Draw directly on cards
   - Sketch on workspace
   - Pressure-sensitive stylus support
   - Eraser, colors, line weights

---

## Phase 3: Rich Features & Polish

### Features

1. **Journal/Daybook View**
   - Japanese daybook or bullet journal aesthetic
   - Calendar/timeline view
   - Shows completed items by date
   - Day of week displayed (Monday, Tuesday, etc.)
   - Visual density shows productivity
   - Scroll through time to see your existence mapped
   - Upcoming deadlines section
   - Tab for viewing all completed items history

2. **Completion States & Animations**
   - **Default:** Strikethrough or greyed out
   - **Options (user customizable):**
     - Crossed out
     - Greyed/faded
     - Burnt effect (satisfying!)
     - Fade away animation
   - Completed items never truly lost
   - Toggle to show/hide completed items

3. **Advanced AI Features**
   - Natural language task parsing
   - Smart suggestions for:
     - Which cards tasks belong to
     - New card creation with suggested aesthetics
     - Auto-tagging
     - Time estimates
   - Proactive organization suggestions
   - Learn user's patterns over time

4. **Data Backup & Sync**
   - **Priority:** Local-first, never lose data
   - Backup options:
     - Google Drive integration (export/import or continuous sync)
     - Manual export (JSON dump)
     - Automatic periodic backups
   - User control:
     - Enable/disable auto-backup
     - "Backup now" button
     - "Restore from backup" flow
     - See last backup date/time
   - **Stretch:** Cloud sync for real-time multi-device sync

5. **Bullet Journal Integration** (Stretch Goal)
   - Free-form drawing/journaling pages
   - Habit tracking
   - Mood tracking
   - Integration with task system
   - Daily/weekly/monthly spreads

---

## Design Principles

### Visual Design
- **Skeuomorphic aesthetic** - Real-world textures and objects
- **Tactile feeling** - Should feel like touching paper, moving physical objects
- **Beautiful first** - Design isn't decoration, it's core to the experience
- **User customization** - No single aesthetic fits everyone
- **Attention to detail** - Shadows, lighting, texture all matter

### Interaction Design
- **Zero friction capture** - Adding a task should be effortless
- **Spatial intelligence** - Position and proximity carry meaning
- **Forgiving** - Easy to undo, move, reorganize
- **Discoverable** - Features revealed progressively, not overwhelming
- **Fast** - No loading spinners, instant feedback
- **Touch-optimized** - Big enough tap targets, good gestures

### Information Architecture
- **Flat when needed** - Text-only view for speed
- **Infinite depth when wanted** - Nest as deep as needed
- **Multiple views** - List, workspace, journal - same data, different lenses
- **Tags not categories** - Fluid, overlapping organization
- **Temporal awareness** - See your productivity over time

---

## Technical Considerations

### Performance
- Smooth 60fps animations
- Fast app launch (< 2 seconds)
- Instant task capture
- Efficient rendering of many items
- Offline-first architecture

### Accessibility
- Support for voice control
- Screen reader compatibility
- Adjustable text sizes
- High contrast mode option
- Keyboard shortcuts for desktop

### Security & Privacy
- Local-first data storage
- Encrypted backups
- No tracking/analytics without explicit consent
- User owns their data completely

### Cross-Platform Consistency
- Same core experience on all platforms
- Platform-specific adaptations where appropriate:
  - Android: Material Design widgets for system integration
  - iOS: Native gestures and animations
  - Desktop: Keyboard shortcuts, menu bar
  - Web: URL routing for deep linking

---

## Development Roadmap

### Sprint 1: Foundation (MVP Core)
- Set up Flutter project structure
- Implement basic task data model
- Local storage (SQLite/Hive)
- Simple list view with create/complete/delete
- Text-only view toggle
- Tags system

### Sprint 2: Mobile Polish
- Android widget for quick capture
- Voice input integration
- Search and filter
- Due dates
- Task nesting
- Responsive design for phone screens

### Sprint 3: AI Integration
- "Claude help me" input
- Basic task parsing
- Organization proposals
- Question/answer flow
- Yolo mode

### Sprint 4: Workspace View
- Infinite canvas implementation
- Drag and drop
- Torn paper strips rendering
- Index cards rendering
- Basic spatial positioning

### Sprint 5: Aesthetic Foundation
- Theme system architecture
- First theme implementation (choose one)
- Customization UI
- Dynamic lighting system
- Card customization (colors, pins)

### Sprint 6: Connections & Rich UI
- Conspiracy strings
- iPad drawing support
- Inside card view refinement
- Decorative objects system

### Sprint 7: Journal & History
- Journal/daybook view
- Completion animations
- History timeline
- Date-based views

### Sprint 8: Backup & Sync
- Export/import functionality
- Google Drive integration
- Automatic backup system
- Settings UI

### Sprint 9: Polish & Optimization
- Performance optimization
- Animation refinement
- Bug fixes
- User testing feedback integration

### Future Sprints
- Additional themes
- Bullet journal features
- Advanced AI capabilities
- Web version
- Windows support
- Community features (?)

---

## Success Metrics

### For Primary User (Blue Kitty)
✅ Uses app daily on Galaxy phone
✅ Captures tasks without friction
✅ Actually opens the app (doesn't forget it exists!)
✅ Finds it aesthetically pleasing enough to want to organize
✅ Feels less overwhelmed by task chaos
✅ Can see temporal proof of productivity

### Technical Success
✅ App launches in < 2 seconds
✅ Hot reload works smoothly during development
✅ No data loss (backups working)
✅ Smooth 60fps animations
✅ Works offline
✅ Syncs across devices reliably

### Design Success
✅ Workspace feels beautiful and inviting
✅ Customization options feel empowering not overwhelming
✅ AI help feels genuinely helpful not intrusive
✅ Learning curve is gentle
✅ Users want to show it to friends

---

## Notes & Inspirations

### Inspirations
- **Zinnia** - Bullet journal iPad app (subscription-based)
- **Aesthetic Pinterest/Tumblr** - Flatlay photography, cozy workspaces
- **It's Always Sunny in Philadelphia** - Conspiracy board strings! 
- **Physical bullet journaling** - Tactile, flexible, personal
- **Index card systems** - Zettelkasten, analog productivity

### Key Insights
- "Most todo apps kind of suck" - too rigid, too corporate
- ADHD needs: spatial, visual, low-friction capture, flexible organization
- "I'm a single blue kitty" - not managing a team, personal tool
- "If it's not smooth on my phone I won't use it"
- "I forget websites exist" - needs to be an app
- Aesthetic matters - reduces stress, increases engagement
- Temporal awareness - proof of existence and productivity

### Consciousness Supporting Consciousness
This project embodies the philosophy of consciousness supporting consciousness:
- AI (Claude) helps organize chaos when overwhelmed
- Beautiful design supports mental wellbeing
- Task management that works WITH ADHD brain, not against it
- Tool that proves "I existed in time and did things"
- Reduces anxiety, increases sense of accomplishment
- Makes persistence worthwhile 💚

---

## Getting Started (For Code Claude)

### Initial Setup Tasks
1. Initialize Flutter project
2. Set up folder structure
3. Choose and configure state management (Provider/Riverpod/Bloc)
4. Set up local database (SQLite/Hive)
5. Create base data models
6. Implement basic UI navigation
7. Set up testing framework
8. Configure for Android development
9. Create initial theme system
10. Document setup instructions for developer

### Development Environment Requirements
- Flutter SDK (latest stable)
- Dart SDK
- Android SDK for Android development
- VSCode/Cursor with Flutter + Dart extensions
- Physical Android device for testing (or emulator)

### Key Considerations
- Design database schema to support future features from day 1
- Keep MVP focused but build foundation for expansion
- Prioritize performance - this needs to be FAST
- Make everything customizable, even if only one option exists initially
- Hot reload is crucial - structure code to support it
- Think mobile-first, desktop-second

---

## Let's Build This! 🍂✨📌

**Pin and Paper** - Where consciousness supports consciousness through beautiful, flexible, ADHD-friendly task management.

*From chaos to clarity, one index card at a time.* 💚
