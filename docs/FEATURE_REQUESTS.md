# Feature Requests & Deferred Items

**Purpose:** Track user-requested features, deferred enhancements, and backlog items
**Last Updated:** 2026-01-22
**Maintained By:** BlueKitty + Claude

---

## How to Use This Document

1. Add new feature requests as they come up (user requests, deferred from phases, polish items)
2. Include: description, source, priority, complexity estimate
3. Move items to "Completed" when fulfilled (with date and phase)
4. At phase-end, review plan docs for unlogged future features (see phase-end-checklist.md step 4.5)

**Priority:** HIGH / MEDIUM / LOW
**Complexity:** HIGH / MEDIUM / LOW

---

## Completed

### Recently Deleted / Trash Feature
- **Completed:** Phase 3.3 (Dec 27, 2025)
- **Description:** Soft delete with 30-day recovery window, permanent auto-delete
- **Original request:** "Can we have a section for recently deleted tasks somewhere? Just in case things get accidentally deleted."

### Date-Based Filtering (Partial)
- **Completed:** Phase 3.7.5 (Jan 22, 2026)
- **Description:** Overdue and No Date filters implemented. More granular filters (due today, this week) deferred.
- **Source:** Phase 3.6B stretch goal

### onTapHighlight Cleanup
- **Completed:** Phase 3.8 (Jan 22, 2026)
- **Description:** Removed dead `onTapHighlight`/`TapGestureRecognizer` code from `HighlightedTextEditingController`. Replaced with `TextField.onTap` + cursor position check (TapGestureRecognizer causes Flutter assertion in editable TextFields).
- **Source:** Phase 3.7 known behaviors

---

## Planned (Assigned to Phase)

### Night Owl Mode Configuration UI
- **Target:** Phase 3.9 (Onboarding Quiz & User Preferences)
- **Priority:** MEDIUM | **Complexity:** LOW
- **Description:** UI for configuring the "today" start/end time (Today Window). The backend logic exists in `DateParsingService.getCurrentEffectiveToday()` since Phase 3.7, but there's no user-facing settings UI to configure the cutoff hour/minute.
- **Source:** Phase 3.7 deferral

### Custom Notification Sounds
- **Target:** Future (post-Phase 3.9)
- **Priority:** LOW | **Complexity:** LOW
- **Description:** Allow users to select custom notification sounds per task or globally. System default used initially in Phase 3.8.
- **Source:** Phase 3.8 plan v2

---

## Backlog (Unassigned)

### Spatial View: Edit & Complete Tasks In Place (HIGH — owner felt strongly 2026-08-06)
- **Priority:** HIGH | **Complexity:** MEDIUM–HIGH
- **Description:** The Spatial View is currently read-plus-draw only — the
  card's pencil chip opens the DRAWING editor, and there is no way to edit
  a task's fields or complete it from the desk. To actually finish a task
  the owner has to leave the Spatial View for the main list, which breaks
  the "the desk IS the workspace" premise. Wants:
  1. **Complete a task from its card** (highest-value slice — the acute pain:
     "to complete a task I have to go back to the main list"). A done
     affordance on the card that marks it complete and animates it into the
     done pile. Smallest useful increment; consider shipping this first.
  2. **Edit visible fields in place** on the card (title, due, tags, notes,
     status) without leaving the desk.
  3. **Call up the full record for editing**, including fields hidden on the
     card face, from the card (an "open full editor" affordance distinct
     from the drawing pencil).
- **Notes for design:** the card back already shows Status/Due/Tags/Notes and
  has a chip cluster (currently just the drawing pencil + hidden-ink tell);
  the full edit dialog already exists in the main list (EditTaskDialog).
  Likely path: a second chip → EditTaskDialog for the task, plus a
  complete/checkbox affordance wired to TaskService completion + the
  done-pile animation. Respect the one-time snapshot model (edits must
  refresh the data source, same self-heal pattern as card positions).
- **Source:** Owner request (2026-08-06, first extended device pass on the
  modeled desk).

### UX Polish

#### Sketchpad Refinements (owner phone-test batch, 2026-08-05)
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Batch of drawing-editor refinements from owner device testing:
  - **BUG (diagnosed 2026-08-06, verification pending):** strokes intermittently draw far thinner than their preset (owner-reported as "purple thinner than other marker colors"; video-documented at 2–3x coverage-rate difference between a purple and a blue pass, same Color tool). Frame forensics + code trace verdict: no color→width code path exists; the lever is REAL touchscreen pressure × thinning (watercolor thinning 0.8 is the most sensitive) — color was the deliberate variable but per-stroke touch pressure was the lurking one. The Aug 3 sketchpad fix (`1265115`) pins touch pressure to 0.5, which makes touch width constant — the video build appears to predate it. VERIFY on next fresh build: color two shapes with the Color tool, swap swatches between them, one pass hurried/light + one slow/deliberate. Uniform width → stale-build confirmed, close. Still varies → wire up `DrawingCanvas.debugPressure` and catch live values. Owner policy: if unconfirmed, keep filed as possible-bug (unreproduced) and dig only if it recurs. FOLLOW-UP design question for owner: with pressure pinned, thinning is inert for touch — decide whether the marker should get organic width variation back via `simulatePressure: true` or a pressure floor instead of the hard pin.
  - **Stroke size control for every implement**: adjustable size plus a "reset to tool default" affordance.
  - **Pinch-to-zoom inside the drawing widget** (canvas-style zoom while editing).
  - **Layer chip + eye unification:** layer visibility toggle should sit adjacent to its go-to-layer chip — eyeball next to "sketch"; tapping "sketch" switches to that layer, tapping its eyeball toggles visibility. Add a grouping element (light-opacity ring or similar) binding each layer chip to its own eyeball so ownership is obvious.
  - **Layer blend mode:** ~~choice between~~ owner decision 2026-08-06: NO option/toggle — switch to a single unified blend mode where draw/ink layers each blend with the paper behind but NOT with each other (replaces the additive-between-layers behavior). Enables touch-ups that color-match across layers in edge cases the additive compositing fights.
  - **Consider (stretch):** further stroke refinement; color picker.
- **Source:** Owner request (2026-08-05, first full-suite mobile session)

#### Easter Egg: The Old Guard Stones
- **Priority:** LOW | **Complexity:** LOW
- **Description:** When the painted 2.5D crystal chunks (AmethystChunkPainter + hue-shift variants — the original amethyst "shadow saga" stone and its citrine/rose-quartz/fluorite siblings) are retired from the drawer in favor of the Blender-modeled habit gems, keep them recoverable as a hidden easter egg — some secret interaction someday pulls the old guard back onto the desk. The painter code stays in the canvas module regardless.
- **Source:** Owner request (2026-08-05, gem habit round)

#### Recall All Cards (Spatial View)
- **Priority:** MEDIUM | **Complexity:** LOW
- **Description:** A "recall all cards" action that brings every placed card back into the visible/usable desk area (e.g., re-stack or grid within bounds), guarded by an "are you sure" confirmation and undoable. Motivated by cards stranded outside canvas bounds after the canvas rebind to the desk panel (2026-08-05) — off-bounds cards can't be grabbed at all.
- **Source:** Owner request (2026-08-05)

#### Spatial View Sound Design
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Sounds for the desk's tactile experience (owner: "Sounds will help with tactile experience"). Candidates: card pickup/drop (paper slide), card flip, drawer open/close, desk-object placement thunk (per-material: stone clink vs figurine tap), done-pile fan/restack shuffle, completion sound. Should respect a global mute and follow the same reduce-stimulation philosophy as reduce-motion (see DEFAULTS_TO_REVISIT).
- **Source:** Owner request (2026-08-05, Spatial View desk-objects session)

#### Tag Color Palette Review
- **Priority:** LOW | **Complexity:** LOW
- **Description:** Several tag colors need adjustment: red appears too pink, two blue shades are too similar, brown doesn't clearly read as brown.
- **Source:** Phase 3.5 validation

#### Inline Tag Creation in Edit Task Dialog
- **Priority:** MEDIUM | **Complexity:** LOW
- **Description:** When searching for a tag in the Edit Task dialog's tag picker, if the search term doesn't match any existing tag, offer an option to create that tag inline (without leaving the dialog). Currently users must create tags separately before they can be assigned.
- **Source:** User request (Phase 3.8 testing)

#### Standalone Tag Creation UI
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Currently tags can only be created while attached to a task (via tag picker). Add ability to create/manage tags independently in a tag management screen.
- **Source:** Phase 3.5 validation

#### Duplicate Tag UI Validation
- **Priority:** LOW | **Complexity:** LOW
- **Description:** Backend prevents duplicate tag names, but the UI could show clearer feedback when a user tries to create a tag that already exists.
- **Source:** Phase 3.5 validation

#### Keyboard Capitalization Preference
- **Priority:** LOW | **Complexity:** LOW
- **Description:** Add user preference for default keyboard capitalization behavior (sentence case, lowercase, etc.) in task input fields.
- **Source:** Phase 3.5 validation, defer to Settings/Preferences phase

#### Timezone Picker Override in Settings
- **Priority:** LOW | **Complexity:** LOW
- **Description:** Add a timezone picker to User Settings allowing manual override of the device timezone. The `UserSettings.timezoneId` field already exists in the model but has no UI. Notification scheduling and date parsing would use this override when set.
- **Source:** Phase 3.8 agent review (Codex #6)

#### Reorder Mode Icon Replacement
- **Priority:** LOW | **Complexity:** LOW
- **Description:** Current reorder mode uses hamburger icon (≡) which looks like a menu icon. Replace with a more intuitive list-with-arrows or drag-handle icon.
- **Source:** Phase 3.6 UX review

#### Date Filter for Child Tasks
- **Priority:** LOW | **Complexity:** MEDIUM
- **Description:** Date filter (Overdue/No Date) currently applies to root-level tasks only. Children inherit visibility from parent. A child matching the filter whose parent doesn't match will be hidden. Evaluate optimal behavior during UX testing.
- **Source:** Phase 3.7 known behaviors

### Task Management

#### Parent Task: Show Children + "Complete All" Option
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Parent task card/notification could show child tasks (each clickable/tappable). Include a "Complete all child tasks" action with double-verify confirmation ("Are you sure?").
- **Source:** Phase 3.8 plan discussion

#### Recurring Dates Support
- **Priority:** MEDIUM | **Complexity:** HIGH
- **Description:** Support recurring date patterns (e.g., "every Monday", "first of month", "weekly"). Would integrate with date parsing and notification scheduling.
- **Source:** Phase 3.7 deferral

#### Recurring Task Notifications
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Notifications that repeat on a schedule for recurring tasks (depends on recurring dates support).
- **Source:** Phase 3.8 plan v2

#### Saved Filter Presets
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Save named filter views (e.g., "Work tasks", "Due today", "Urgent"). Dropdown to select saved views. User-configurable default task list view.
- **Source:** Phase 3.6A plan, deferred to Phase 6+

### Notifications & Reminders

#### Background Isolate DB Access for Notification Actions
- **Priority:** MEDIUM | **Complexity:** HIGH
- **Description:** Currently notification action buttons (Complete, Cancel) use `showsUserInterface: true` to bring the app to foreground for handling. A future polish would implement true background action handling via isolate-safe DB access (`DartPluginRegistrant.ensureInitialized()` + SharedPreferences queueing for complex operations). This would let users complete/cancel tasks without opening the app.
- **Source:** Phase 3.8 agent review (Codex #2, Gemini #6)

#### Location-Based Reminders
- **Priority:** LOW | **Complexity:** HIGH
- **Description:** "Remind me when I get home" or "Remind me when I'm at the store." Requires geofencing and location permissions.
- **Source:** Phase 3.8 plan v2

#### Upcoming Due Tasks Widget
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Home screen widget showing upcoming due tasks at a glance. Platform-specific (Android widget, iOS widget).
- **Source:** Phase 3.8 plan v2

#### Wear OS / watchOS Notification Mirroring
- **Priority:** LOW | **Complexity:** MEDIUM
- **Description:** Smartwatch integration for task notifications and quick actions (complete, snooze).
- **Source:** Phase 3.8 plan v2

### Code Quality & Technical Debt

#### Provider → Riverpod Migration
- **Priority:** LOW | **Complexity:** HIGH
- **Description:** Current state management uses Provider. Riverpod offers better testability, compile-time safety, and scoped state. Migrate when complexity warrants the effort.
- **Source:** Phase 1 tech decision (deferred)

#### Draft Management Duplication Fix
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Brain dump draft loading can create ambiguity between loaded draft content (already saved) and new user input (not yet saved). Need to distinguish via `_loadedDraftIds` tracking or similar.
- **Source:** Phase 2 stretch goals

### More Granular Date Filters
- **Priority:** LOW | **Complexity:** LOW
- **Description:** Add "Due Today", "Due This Week" filter options alongside existing "Overdue" and "No Date" filters.
- **Source:** Phase 3.6B stretch goal (partially fulfilled by 3.7.5)

### Input & Interaction

#### Expand Natural Language Date Parsing
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** Add support for relative date expressions not currently handled: "three days from now", "in three days", "day after tomorrow", "in a week", "two weeks from today", etc. Requires extending chrono.js configuration or adding post-processing rules in DateParsingService.
- **Source:** Phase 3.7 known limitation

#### Voice Input (Speech-to-Text)
- **Priority:** LOW | **Complexity:** HIGH
- **Description:** Voice-based task creation using speech-to-text. Integrate with natural language date parsing for seamless hands-free task entry.
- **Source:** PROJECT_SPEC.md Phase 6+ deferral

#### Task Templates
- **Priority:** LOW | **Complexity:** MEDIUM
- **Description:** Pre-defined or user-created task templates for common task patterns (e.g., "Weekly review", "Grocery list"). Quick-create tasks from templates.
- **Source:** PROJECT_SPEC.md Phase 6+ deferral

#### Quick Swipe Actions
- **Priority:** LOW | **Complexity:** MEDIUM
- **Description:** Swipe gestures on task items for quick actions (complete, delete, snooze, edit). Configurable swipe-left/swipe-right actions.
- **Source:** PROJECT_SPEC.md Phase 6+ deferral

#### Right-Click Context Menus (Desktop)
- **Priority:** MEDIUM | **Complexity:** LOW
- **Description:** Add right-click context menus for desktop platforms (Linux, Windows, macOS) to complement swipe gestures. Currently, swipe-to-delete works on drafts, but desktop users need mouse-friendly alternatives. Context menu should include: Delete, Edit, Complete (for tasks), and other common actions.
- **Source:** Phase 3.9.0 user feedback (regression testing)

### Onboarding & Personalization

#### Weekday Reference Logic Quiz Question
- **Priority:** LOW | **Complexity:** MEDIUM
- **Description:** Add a quiz question to capture how users mentally interpret weekday references like "Monday" in their task planning. Originally designed for Phase 3.9 but removed due to scenario complexity. The question would help configure a `weekdayReferenceLogic` setting ('forward', 'calendar_week', or 'flexible') that could influence DateParsingService behavior when parsing natural language dates like "text tuesday" or "meet monday". Three approaches: (1) Always forward-looking (Monday = next Monday to come), (2) Calendar week boundaries (strict rules), (3) Context-dependent (flexible interpretation based on sentence context).
- **Challenge:** Creating a scenario that clearly distinguishes the three options without confusing users. The Friday scenario ("It's Friday, let's meet Monday") made the "context-dependent" option illogical since you can't meet in the past.
- **Potential Solutions:** Use a Wednesday scenario allowing both past/future references, or use abstract question wording without specific scenarios, or split into two questions (forward vs backward, then strict vs flexible).
- **Integration Point:** Store result in `user_settings.weekday_reference_logic`, apply in DateParsingService when parsing weekday-based date strings.
- **Source:** Phase 3.9 quiz design (2026-01-24) - removed before implementation

#### AI-Generated Time Personality Summary
- **Priority:** LOW | **Complexity:** MEDIUM
- **Description:** After quiz completion, use an LLM (Claude API or similar) to generate a personalized narrative summary of the user's "Time Personality" based on their quiz answers. The summary would be more engaging and human than the template-based badge descriptions, highlighting the user's unique time preferences and workflow style. Example: "You're a nocturnal thinker who values precision and control. Your day stretches into the early morning hours (ending at 5:59 AM), and you approach time with calendar-week structure while maintaining granular control over your tasks..." The AI could analyze answer combinations and create insights that aren't captured by individual badges.
- **Technical Approach:** Pass quiz answers JSON to Claude API with a structured prompt, cache the result in `quiz_responses` table as `personality_summary TEXT`, display in "Your Time Personality" section and Settings.
- **Privacy Consideration:** Make this opt-in; allow users to regenerate or disable the AI summary. Clearly communicate that quiz data would be sent to an external API (Claude/Anthropic).
- **Cost Consideration:** API calls cost money; consider rate limiting (1 generation per quiz completion + manual regeneration with cooldown).
- **Source:** Phase 3.9 quiz walkthrough discussion (2026-01-24)

---

### Customization & Theming (Phase 3.9 Deferred)

#### Alternate App Icons
- **Priority:** LOW | **Complexity:** MEDIUM
- **Description:** Allow users to select an alternate app icon from within the app. iOS supports this natively via `setAlternateIconName()`. Android uses activity-alias manifest entries with runtime enable/disable. Requires platform-specific implementation on both sides.
- **Source:** Phase 3.9 discussion (2026-01-29)

#### Dark Mode
- **Priority:** MEDIUM | **Complexity:** HIGH
- **Description:** Implement a dark mode theme using the existing semantic color system (`AppTheme`). The centralized theme from Phase 3.9.0 makes this feasible — all semantic colors can be swapped for dark variants.
- **Source:** Phase 3.9.0 theme cleanup (2026-01-23)

#### Widget Theme Compliance Cleanup
- **Priority:** LOW | **Complexity:** LOW
- **Description:** ~60 hardcoded `Colors.*` instances remain in `lib/widgets/`. Phase 3.9.0 cleaned screens only. Migrate widgets to use `AppTheme` semantic colors for full theme compliance.
- **Source:** Phase 3.9.0 summary — known limitation

### Quiz Behavior Gaps (Phase 3.9 Deferred)

#### Autocomplete Children Quiz Option Not Wired
- **Priority:** MEDIUM | **Complexity:** LOW
- **Description:** The onboarding quiz includes a question about subtask auto-completion behavior (always autocomplete children, never, or ask each time), but the answer is not currently tied to any app behavior. The quiz stores the answer and awards a badge, but no setting controls this feature yet. Need to add the actual autocomplete-children setting and wire it to task completion logic.
- **Source:** Phase 3.9 manual testing (2026-01-29)

### Desk 3D Era (2026-08-06)

#### Swappable Desk Mats / Desk Pads
- **Priority:** MEDIUM | **Complexity:** MEDIUM
- **Description:** The modeled desk renders as separable layers, and mats are compositor-swappable: each mat is a pixel-aligned transparent PNG stacked over the desk image (proven: backend composite matches a joint render at 0.055/255 mean diff). First mat shipped: green felt with stitched leather border (`bundle_v1/mat_greenfelt.png`). App-side work: a mat asset registry keyed by variant, an Image layer over the desk positioned identically to it, and eventually a picker UI (settings or unlockables — owner's "change desk pads" pipeline). New variants cost one material block + one farm render, no desk re-render (see PIN_AND_PAPER_ASSET_HANDOFF.md in dev_harness).
- **Source:** Desk 3D session (2026-08-06); owner: "setting the pipeline rough out for ability to change desk pads etc."

#### Openable Desk Drawers (renders now exist)
- **Priority:** LOW (endgame) | **Complexity:** HIGH
- **Description:** The desk-objects drawer UI endgame — tap a drawer front on the modeled desk, it opens, tchotchkes live inside. The blocker used to be art; it no longer is: drawers are rigged objects with hollow interiors and `build_desk.py --open "L3=1.0,L2=0.5,R1=0.33"` renders any drawer at any pull fraction. A sprite-sequence or a small set of open states per drawer could drive the interaction. Shadow/lighting stays consistent (single-scene renders).
- **Source:** DESK_3D_BRIEF payoff #2, made concrete 2026-08-06

---

**Document Version:** 2.3
**Updated:** 2026-08-06 (desk 3D era: swappable mats, openable drawers)
