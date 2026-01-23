# Phase 3.9 Plan - Onboarding Quiz & User Preferences

**Version:** 2
**Created:** 2026-01-23
**Updated:** 2026-01-23
**Status:** Draft

---

## Scope

**Source:** `docs/PROJECT_SPEC.md` (line 528-536), `docs/future/onboarding-quiz.md`

Phase 3.9 is the final subphase of Phase 3 (Core Productivity). It adds a scenario-based onboarding quiz that infers user time perception preferences, a badge/personality system, and comprehensive settings UI for all user-configurable preferences that currently lack exposure.

**Subphases:**
- 3.9.0: Theme cleanup and centralization (pre-requisite)
- 3.9.1: Onboarding quiz framework and flow integration
- 3.9.2: Quiz questions, inference logic, and badge system
- 3.9.3: Comprehensive preferences UI (Settings screen expansion)
- 3.9.4: "Explain my settings" and "Retake quiz" features

---

## Context: Existing Infrastructure

Many preference fields already exist in `UserSettings` model but have NO settings UI:

| Field | Default | Has UI? | Notes |
|-------|---------|---------|-------|
| `todayCutoffHour/Minute` | 4:59 AM | ❌ | Night owl mode (Phase 3.7 backend) |
| `earlyMorningHour` | 5 | ❌ | Time keyword: "early morning" |
| `morningHour` | 9 | ❌ | Time keyword: "morning" |
| `noonHour` | 12 | ❌ | Time keyword: "noon"/"lunch" |
| `afternoonHour` | 15 | ❌ | Time keyword: "afternoon" |
| `tonightHour` | 19 | ❌ | Time keyword: "tonight" |
| `lateNightHour` | 22 | ❌ | Time keyword: "late night" |
| `weekStartDay` | 1 (Mon) | ❌ | Week start preference |
| `use24HourTime` | false | ❌ | 12h vs 24h display |
| `timezoneId` | null (device) | ❌ | Manual timezone override |
| `autoCompleteChildren` | 'prompt' | ❌ | Child task completion behavior |
| `defaultNotificationHour/Min` | 9:00 | ✅ | Via notification settings (3.8) |
| `notificationsEnabled` | true | ✅ | Master toggle (3.8) |
| `quietHours*` | various | ✅ | Quiet hours config (3.8) |
| `defaultReminderTypes` | at_time | ✅ | Reminder type chips (3.8) |
| `notifyWhenOverdue` | true | ✅ | Overdue toggle (3.8) |

**Key insight:** The quiz doesn't create new data fields — it provides a user-friendly way to populate the existing fields. Advanced users can also configure them directly in Settings.

**Current theme state:** `AppTheme` class exists with centralized Witchy Flatlay palette, BUT 6 screens have hardcoded colors (138 instances of `Colors.green`, `Colors.red`, etc.) that would break on re-theme.

---

## Asset Storage & Format Strategy

### Directory Structure

```
pin_and_paper/assets/
├── js/
│   └── chrono.min.js          # (existing)
└── images/
    ├── quiz/                  # Quiz scenario illustrations
    │   ├── clock_230am.png
    │   ├── calendar_week.png
    │   ├── time_ranges.png
    │   └── sleep_moon.png
    ├── badges/                # Photorealistic embroidered patches
    │   ├── 1x/                # Base resolution
    │   ├── 2x/                # 2x density
    │   └── 3x/                # 3x density
    └── onboarding/
        ├── welcome.png
        ├── celebration.png
        └── sash_background.png  # Diagonal scout sash for badge reveal
```

### Format Recommendations

| Asset Type | Format | Rationale |
|-----------|--------|-----------|
| **Embroidered badges** | PNG or WebP with transparency | Photorealistic style requires raster; WebP for smaller file size |
| **Quiz illustrations** | PNG or SVG | Simple illustrations can be SVG for scalability; complex ones PNG |
| **Sash background** | PNG or WebP | Fabric texture, diagonal layout for badge reveal ceremony |
| **Density variants** | @1x, @2x, @3x | Required for crisp rendering across device densities |

**Badge re-theming strategy (photorealistic):**
- **Option A (Recommended):** Generate badges in the current Witchy Flatlay palette. If theme changes in future, regenerate badge assets with new colors using the same AI prompts/templates.
- **Option B:** Use Flutter's `ColorFiltered` widget with blend modes (e.g., `BlendMode.modulate`) to apply color tints at runtime. Limited effectiveness on photorealistic imagery but can shift hue/warmth.
- **Option C:** Accept badges as part of the theme identity — they don't need to change when theme changes (like how brand logos stay consistent).

**Animation approach:** Built-in Flutter animations (`AnimationController`, `Tween`, fade/scale effects). No external packages required.

### pubspec.yaml Update

```yaml
flutter:
  assets:
    - assets/js/chrono.min.js
    - assets/images/quiz/
    - assets/images/badges/1x/
    - assets/images/badges/2x/
    - assets/images/badges/3x/
    - assets/images/onboarding/
```

---

## Subphase Details

### 3.9.0: Theme Cleanup & Centralization (Pre-requisite)

**Goal:** Prepare the codebase for easy re-theming by removing hardcoded colors and centralizing theme definitions.

**Current problems identified:**
- 6 screens have 138 instances of hardcoded `Colors.green`, `Colors.red`, `Colors.grey`
- No semantic color roles in `AppTheme` for "success", "danger", "warning", "muted"
- Tag colors are separate system (`tag_colors.dart`) — this is OK, but quiz theming needs similar structure

**Tasks:**

1. **Extend `AppTheme` with semantic color roles:**
   ```dart
   // In lib/utils/theme.dart
   class AppTheme {
     // Existing palette...

     // New: Semantic colors for UI states
     static const Color success = Color(0xFF...);  // Currently Colors.green
     static const Color danger = Color(0xFF...);   // Currently Colors.red
     static const Color warning = Color(0xFF...);  // Currently Colors.orange
     static const Color muted = Color(0xFF...);    // Currently Colors.grey
     static const Color info = Color(0xFF...);     // Currently Colors.blue
   }
   ```

2. **Create `QuizTheme` class for quiz/badge theming:**
   ```dart
   // In lib/utils/quiz_theme.dart
   class QuizTheme {
     final Color badgeBorder;
     final Color badgeBackground;
     final Color illustrationPrimary;
     final Color illustrationSecondary;
     final Color celebrationAccent;
     // etc.

     // Factory for current theme
     static QuizTheme witchyFlatlay = QuizTheme(...);
   }
   ```

3. **Migrate hardcoded colors in 6 screens:**
   - `settings_screen.dart` (13 instances)
   - `quick_complete_screen.dart` (9 instances)
   - `task_suggestion_preview_screen.dart` (6 instances)
   - `drafts_list_screen.dart` (6 instances)
   - `brain_dump_screen.dart` (4 instances)
   - `recently_deleted_screen.dart` (1 instance)

   Replace with `AppTheme.success`, `AppTheme.danger`, etc.

4. **Testing:**
   - flutter analyze (0 errors, 0 new warnings)
   - Visual regression: screens should look identical after migration
   - Widget tests should still pass

**Deliverables:**
- Updated `lib/utils/theme.dart` with semantic colors
- New `lib/utils/quiz_theme.dart`
- 6 screens refactored to use semantic colors
- Commit: "refactor(theme): Centralize colors for easy re-theming"

### 3.9.1: Onboarding Quiz Framework

**Goal:** Create a reusable quiz/wizard UI framework and flow integration.

**Features:**
- Quiz screen with progress indicator (9 dots, current question highlighted)
- Card-based question layout with scenario descriptions
- Multiple-choice answer cards (tap to select, visually highlighted)
- "Skip Quiz" button (applies sensible defaults, always visible)
- Navigation: back/forward buttons, skip individual questions
- Quiz state management via `QuizProvider` (ChangeNotifier)
- First-launch detection (show quiz on first app open)

**Implementation:**
- `lib/screens/quiz_screen.dart`: Main quiz wizard UI
- `lib/providers/quiz_provider.dart`: State management (tracks answers, computes results)
- `lib/widgets/quiz_question_card.dart`: Reusable question layout
- `lib/widgets/quiz_answer_option.dart`: Tappable answer cards
- `lib/widgets/quiz_progress_dots.dart`: Progress indicator

**Integration points:**
- `main.dart`: Detect first launch → route to QuizScreen before HomeScreen
- Quiz completion → write to UserSettings → navigate to HomeScreen
- Settings: "Retake Quiz" button → navigate to QuizScreen

**UI/UX details:**
- Duolingo-style progress dots at top
- Smooth page transitions (PageView or AnimatedSwitcher)
- Celebration screen on completion ("Your settings are ready!")
- Cottagecore aesthetic: kraft paper cards, warm shadows, cream backgrounds

### 3.9.2: Quiz Questions, Inference Logic, Badge System

**Goal:** Implement the 9 scenario questions, map answers to settings, and award personality badges.

**Quiz Questions (from onboarding-quiz.md):**

1. **Circadian Rhythm Detection** (2:30 AM scenario)
   - Answers map to `todayCutoffHour/Minute`
   - Sets badge: Night Owl 🦉 or Midnight Purist 🌙

2. **Weekday Reference Logic** ("this Friday" on Saturday)
   - Maps to internal date parsing logic
   - Sets badge: Forward Thinker ⏰ or Calendar Contextual 📆

3. **Week Start Preference**
   - Answers map to `weekStartDay` (0=Sun, 1=Mon, etc.)
   - Sets badge: Monday Starter 📅 or Sunday Traditionalist 🇺🇸

4. **Time Keyword: "Tonight"**
   - Answers map to `tonightHour` (18, 19/20, or 22)
   - Influences badges: Twilight Worker 🌆 if late

5. **Time Keyword: "Morning" (user-driven)**
   - Answers map to `morningHour` and `earlyMorningHour`
   - Sets badge: Dawn Greeter ☀️, Classic Scheduler 🕐, or Late Morning Luxurist 🌙

6. **Display Time Format** (12h vs 24h)
   - Answers map to `use24HourTime`
   - Sets badge: Military Time Enthusiast 🎖️ or AM/PM Classicist 🕰️

7. **Quick Add Date Parsing Preference**
   - New field: `enableQuickAddDateParsing` (bool)
   - No specific badge, affects UX

8. **Task Completion Behavior** (auto-complete children)
   - Answers map to `autoCompleteChildren` ('prompt', 'always', 'never')
   - Sets badge: Decisive Completer 🎯, Thoughtful Curator 🤔, or Granular Manager 🗂️

9. **Sleep Schedule - End of Day Detection**
   - Cross-validates Q1, refines `todayCutoffHour`
   - Sets badge: Early Bird 🌅 or Nocturnal Scholar 🌌

**Badge System:**

Total badges: 20+ individual badges, plus 4 special combo badges (Vampire Scholar, Sunrise Achiever, Time Anarchist, Night Ops)

**Badge data model:**
```dart
class Badge {
  final String id;           // e.g., "night_owl"
  final String emoji;        // 🦉
  final String title;        // "Night Owl"
  final String description;  // "Your Friday extends past midnight..."
  final String imagePath;    // assets/images/badges/night_owl.png
}
```

**Badge reveal flow (Scouting Sash Ceremony):**
1. Quiz completion → "Analyzing your time personality..." (2 sec loading)
2. Badge reveal screen: Scouting sash background appears (diagonal fabric texture)
3. Each earned badge fades in + bounces onto the sash (staggered, 200-300ms per badge)
4. Collection screen: completed sash with all badges + combo title
5. Settings preview: "Here's what we configured"
6. CTA: "Start capturing tasks"

**Animation implementation:**
- Uses Flutter's built-in `AnimationController` + `Tween` (no Lottie required)
- Fade + scale/bounce effect per badge
- Staggered timing for multiple badges (~5-8 seconds total reveal)
- Optional: Confetti particle effect on final badge appearance

**Deliverables:**
- 9 question screens with illustrations
- Inference engine: `QuizInferenceService.inferSettings(answers) → UserSettings`
- Badge catalog: `lib/models/badge.dart` + `lib/utils/badge_definitions.dart`
- Badge reveal screen with sash background + Flutter animations
- Photorealistic badge assets (AI-generated embroidered patches)
- Sash background asset (fabric texture, diagonal layout)

**Stretch goal (deferred):** Embroidery hoop reveal effect with Lottie animations

### 3.9.3: Comprehensive Preferences UI

**Goal:** Expose ALL user-configurable preferences in the Settings screen, organized logically.

**New Settings sections:**

1. **Time & Schedule** (new section, after Notifications)
   - Night owl mode: "My day starts at" time picker → `todayCutoffHour/Minute`
   - Week starts on: day picker dropdown → `weekStartDay`
   - Time format: 12h / 24h toggle → `use24HourTime`
   - Timezone: device default or manual picker → `timezoneId`

2. **Date Parsing** (new section, expandable)
   - Quick Add date parsing: toggle → `enableQuickAddDateParsing`
   - Time keywords: expandable section showing what "morning", "afternoon", etc. mean
     - Each keyword has an inline time picker
     - Live preview: "morning → 9:00 AM" updates as you adjust
   - Keywords: Early Morning, Morning, Noon, Afternoon, Tonight, Late Night

3. **Task Behavior** (new section)
   - Auto-complete children: Radio buttons (Prompt / Always / Never) → `autoCompleteChildren`

4. **Notifications** (existing — Phase 3.8)
   - No changes needed, already comprehensive

5. **Your Time Personality** (new section, at top or bottom)
   - Display earned badges with tooltips
   - "Retake Onboarding Quiz" button
   - "Explain My Settings" button
   - "Reset All to Defaults" with confirmation

**UI patterns:**
- ExpansionTile for collapsible sections
- Time pickers: showTimePicker() for hours/minutes
- Dropdowns for day-of-week, timezone
- Live preview labels that update as settings change
- Tooltips/help icons explaining what each setting does

**Deliverables:**
- Updated `lib/screens/settings_screen.dart` with 4 new sections
- New widgets: `TimeKeywordPicker`, `WeekStartDayPicker`, `TimezonePicker`
- Settings validation: ensure todayCutoff is valid, time keywords don't overlap nonsensically

### 3.9.4: "Explain My Settings" and "Retake Quiz" Features

**Goal:** Help users understand their current settings and easily reconfigure.

**"Explain My Settings" dialog:**
- Opens a scrollable summary card showing current settings in plain English
- Example output:
  ```
  Your Time Personality: Night Owl 🦉 + Monday Starter 📅

  • Your day starts at 4:59 AM (night owl mode)
  • "Morning" means 9:00 AM
  • "Tonight" means 7:00 PM
  • Week starts on Monday
  • Time format: 12-hour (AM/PM)
  • Auto-complete children: Ask me every time

  Configured via: Onboarding Quiz (Jan 23, 2026)
  ```
- Each setting shows its source: "Set by quiz" or "Manually adjusted"
- "Close" and "Retake Quiz" buttons at bottom

**"Retake Quiz" flow:**
- Navigates back to QuizScreen
- Pre-fills answers based on current settings (reverse inference)
  - If `todayCutoffHour == 4`, pre-select "Night Owl" answer in Q1
  - If `weekStartDay == 1`, pre-select "Monday" in Q3
- User can change answers, see new badges
- Completing quiz overwrites relevant settings (with confirmation: "This will update your current settings. Continue?")
- "Cancel" exits without changing anything

**Deliverables:**
- `lib/widgets/settings_explanation_dialog.dart`
- `QuizProvider.prefillFromSettings(UserSettings)` method
- Badge recalculation on retake
- Confirmation dialog before overwriting settings

---

## Technical Approach

### Architecture
- **QuizScreen** (new): Full-screen wizard with PageView
- **QuizProvider** (new ChangeNotifier): Manages quiz state, answer collection, badge calculation
- **QuizInferenceService** (new): Pure logic for answer → settings mapping
- **BadgeService** (new): Badge calculation and definitions
- **PreferencesSection** widgets: Modular settings sections for expanded Settings screen
- **UserSettingsService**: Already handles reads/writes — no changes needed

### Database
- **No schema changes expected** to `user_settings` table — all fields exist
- **Possible additions:**
  - `quiz_completed` (boolean) — track if user completed quiz
  - `quiz_completed_at` (DateTime) — when they completed it
  - `enable_quick_add_date_parsing` (boolean, default 1) — new field for Q7
  - OR: Store in shared_preferences for first-launch detection only

### Dependencies
- No new package dependencies required (uses built-in Flutter animations)

### Navigation
- First launch: QuizScreen → HomeScreen
- Settings → "Retake Quiz" → QuizScreen → back to Settings
- Quiz "Skip" → HomeScreen (applies defaults)

---

## Open Questions & Answers

**From v1 plan:**

1. ✅ **Quiz length:** 9 questions (answered by onboarding-quiz.md)

2. ✅ **Quiz aesthetics:** Use current Witchy Flatlay theme, but design for easy re-theming via `QuizTheme` class (allows future palette swaps without recoding)

3. ✅ **First-launch only?** First launch primarily, but also accessible via Settings → "Retake Quiz" (answered by doc)

4. ✅ **"Quick Add toggle":** Q7 asks if user wants automatic date parsing in the quick-add field. If disabled, quick-add stays plain text (no highlighting, no auto-date). Brain Dump always uses smart parsing regardless.

5. ✅ **Tag system preferences:** Not in scope for this phase (no questions in the quiz about tags). Future enhancement.

**New questions:**

6. **Badge storage:** Should earned badges be persisted to DB, or recalculated from settings on each app launch?
   - Recommendation: Recalculate from settings (simpler, single source of truth)

7. **Shift worker detection:** Doc mentions a screener question for shift workers. Include in v1 or defer to polish?
   - Recommendation: Defer to polish (adds complexity, affects all other questions)

8. **Badge sharing:** Doc mentions future team features (Phase 6+). Any groundwork needed now?
   - Recommendation: No, keep badges local for Phase 3.9

---

## Timeline Estimate

**Subphase breakdown:**

- 3.9.0: Theme cleanup (1 day)
- 3.9.1: Quiz framework (2 days)
- 3.9.2: Questions + badges + asset creation (3 days — includes AI badge generation)
- 3.9.3: Settings UI expansion (2 days)
- 3.9.4: Explain/retake features (1 day)
- Testing, polish, validation (1 day)

**Total:** ~10 days (slightly over the "1 week" estimate, but realistic for polish)

---

## Risk Assessment

- **LOW risk overall** — This phase adds UI over existing backend fields. No complex data model changes, no new services, no platform-specific code (beyond standard Flutter).

**Risks identified:**

1. **Badge asset creation:** AI-generated embroidered patches may need significant tweaking to match aesthetic. Mitigate: Start asset creation early, iterate with BlueKitty.

2. **Quiz UX:** Needs to feel natural and not tedious. Bad design = users skip it. Mitigate: Make "Skip" prominent, use engaging illustrations, keep questions at 9 (not 15+).

3. **Re-theming for photorealistic badges:** Hard to programmatically re-color. Mitigate: Accept badges as part of theme identity OR regenerate assets if theme changes.

4. **First-launch detection:** Multiple approaches (DB field, shared_preferences, flag file). Mitigate: Use shared_preferences for simplicity (no schema change).

5. **Hardcoded color migration:** 138 instances across 6 screens is tedious and error-prone. Mitigate: Do theme cleanup first (3.9.0), test thoroughly with visual regression.

---

## Dependencies (Phase Prerequisites)

- Phase 3.7 (DateParsingService with todayCutoff) — ✅ Complete
- Phase 3.8 (Notification preferences in Settings) — ✅ Complete
- UserSettings model with all fields — ✅ Already exists
- UserSettingsService CRUD — ✅ Already exists

No blockers.

---

**Prepared By:** Claude
**Date:** 2026-01-23
**Changelog:**
- v2: Added theme cleanup pre-requisite, incorporated onboarding-quiz.md details (9 questions, badge system), updated asset strategy for photorealistic badges, answered open questions
- v2.1: Updated badge reveal approach to scouting sash ceremony with built-in Flutter animations (removed Lottie dependency, simpler implementation). Embroidery hoop effect deferred as stretch goal.
