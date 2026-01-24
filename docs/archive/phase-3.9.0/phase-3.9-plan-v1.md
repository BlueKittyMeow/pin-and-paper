# Phase 3.9 Plan - Onboarding Quiz & User Preferences

**Version:** 1
**Created:** 2026-01-23
**Status:** Draft

---

## Scope

**Source:** `docs/PROJECT_SPEC.md` (line 528-536)

Phase 3.9 is the final subphase of Phase 3 (Core Productivity). It adds a scenario-based onboarding quiz that infers user time perception preferences, plus comprehensive settings UI for all user-configurable preferences that currently lack exposure.

**Subphases:**
- 3.9.1: Onboarding quiz framework and scenario engine
- 3.9.2: Time perception quiz scenarios and inference logic
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

---

## Subphase Details

### 3.9.1: Onboarding Quiz Framework

**Goal:** Create a reusable quiz/wizard UI framework and flow integration.

**Features:**
- Quiz screen with progress indicator (dots or progress bar)
- Card-based question layout with scenario descriptions
- Multiple-choice answer selection (tap to select, visually highlighted)
- "Skip Quiz" button (applies sensible defaults)
- Navigation: back/forward between questions, skip individual questions
- Quiz state management (tracks answers, calculates results)
- First-launch detection (show quiz on first app open, or when settings reset)

**Integration points:**
- `main.dart` or `HomeScreen`: detect first launch → show quiz
- Quiz results write to `UserSettings` via `UserSettingsService`
- "Retake Quiz" button in Settings navigates back to quiz screen

### 3.9.2: Time Perception Scenarios

**Goal:** Infer user's time perception through natural scenarios rather than asking for raw numbers.

**Scenario examples (draft — to be refined with BlueKitty):**

1. **Night owl detection:**
   > "It's 2 AM and you just finished a project. If you add a task 'do this today', when should it be due?"
   - "Later this morning (after I sleep)" → cutoff = 4-5 AM
   - "Right now counts as today" → cutoff = 0 (midnight)
   - "Tomorrow — I'm going to bed soon" → cutoff = 2-3 AM

2. **Morning definition:**
   > "Someone says 'let's meet in the morning'. What time do you expect?"
   - "7-8 AM" → morningHour = 7
   - "9-10 AM" → morningHour = 9
   - "After 10 AM" → morningHour = 10

3. **Evening/tonight:**
   > "A friend texts 'I'll call you tonight'. When do you expect the call?"
   - "Around 6-7 PM" → tonightHour = 18
   - "8-9 PM" → tonightHour = 20
   - "10 PM or later" → tonightHour = 22

4. **Week start:**
   > "When you think about 'next week', which day starts it?"
   - "Sunday" → weekStartDay = 0
   - "Monday" → weekStartDay = 1

5. **Notification timing:**
   > "You have a task due at 3 PM. When should we remind you?"
   - "At the time it's due" → at_time only
   - "An hour before" → before_1h
   - "The night before and again 1 hour before" → before_1d, before_1h

6. **Quiet hours:**
   > "When should we NEVER send notifications?"
   - "10 PM - 7 AM" / "11 PM - 8 AM" / "I don't mind anytime" / Custom

**Inference logic:** Each answer maps to one or more UserSettings fields. Multiple questions can influence the same field (e.g., two night-owl questions → confidence-weighted cutoff hour).

### 3.9.3: Comprehensive Preferences UI

**Goal:** Expose ALL user-configurable preferences in the Settings screen, organized logically.

**New Settings sections (additions to existing screen):**

1. **Time & Schedule** (new section)
   - Night owl mode: "My day starts at" time picker (→ todayCutoffHour/Minute)
   - Week starts on: day picker (→ weekStartDay)
   - Time format: 12h / 24h toggle (→ use24HourTime)
   - Timezone: device default or manual override (→ timezoneId)

2. **Date Parsing** (new section)
   - Time keywords: expandable section showing what "morning", "afternoon", etc. mean
   - Each keyword has a time picker to adjust the hour
   - Preview: "morning → 9:00 AM" (updates live)

3. **Task Behavior** (new section, or expand existing)
   - Auto-complete children: Prompt / Always / Never (→ autoCompleteChildren)

4. **Notifications** (existing — Phase 3.8, already done)
   - No changes needed, already comprehensive

5. **Quiz & Onboarding** (new section, at bottom)
   - "Retake Onboarding Quiz" button
   - "Explain My Settings" button
   - "Reset All to Defaults" with confirmation

### 3.9.4: Explain & Retake Features

**Goal:** Help users understand their current settings and easily reconfigure.

**"Explain My Settings":**
- Opens a read-only summary card/dialog showing current settings in plain English
- Example: "Your day starts at 4:59 AM (night owl mode). 'Morning' means 9 AM. Week starts Monday. Notifications: enabled, quiet 10 PM - 7 AM."
- Each setting shows its source: "Set by quiz" or "Manually configured"

**"Retake Quiz":**
- Navigates back to the quiz screen
- Pre-fills with current answers (if determinable from current settings)
- Completing the quiz overwrites relevant settings
- "Skip" exits without changing anything

---

## Technical Approach

### Architecture
- **QuizScreen** (new): Full-screen wizard with PageView or Stepper
- **QuizProvider** (new ChangeNotifier): Manages quiz state, answer collection, result computation
- **PreferencesSection** widgets: Modular settings sections for the expanded Settings screen
- **UserSettingsService**: Already handles reads/writes — no changes needed
- **SettingsProvider**: May need minor additions for new UI state

### Database
- **No schema changes expected.** All fields already exist in `user_settings` table.
- Possible addition: `quiz_completed` boolean flag (or use shared_preferences for first-launch detection)

### Navigation
- First launch → Quiz screen (before HomeScreen)
- Settings → "Retake Quiz" → Quiz screen
- Quiz completion → HomeScreen (with updated settings applied)

---

## Dependencies

- Phase 3.7 (DateParsingService with todayCutoff) — ✅ Complete
- Phase 3.8 (Notification preferences in Settings) — ✅ Complete
- UserSettings model with all fields — ✅ Already exists
- UserSettingsService CRUD — ✅ Already exists

No external package dependencies expected.

---

## Open Questions

1. **Quiz length:** How many scenarios? (6-8 seems right for not being tedious, but enough to be useful)
2. **Quiz aesthetics:** Should the quiz match the app's cottagecore aesthetic (paper textures, warm colors) or be a clean onboarding flow?
3. **First-launch only?** Or also show after major updates that add new settings?
4. **Date parsing toggle:** PROJECT_SPEC mentions "Quick Add toggle" — is this a global on/off for NL date parsing in the quick-add bar? (The feature already works, would this disable it?)
5. **Tag system preferences:** PROJECT_SPEC mentions this — what specific tag preferences? (Max visible tags count? Default tag color? Sort order?)

---

## Risk Assessment

- **LOW risk overall** — This phase adds UI over existing backend fields. No data model changes, no new services, no platform-specific code.
- **Main risk:** Quiz UX — needs to feel natural and not tedious. Bad quiz design = users skip it.
- **Mitigation:** Sensible defaults mean skipping the quiz is perfectly fine. Quiz is enhancement, not requirement.

---

**Prepared By:** Claude
**Date:** 2026-01-23
