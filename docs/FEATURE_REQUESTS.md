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

### UX Polish

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

---

**Document Version:** 2.0
**Restructured:** 2026-01-22 (from single feature request to comprehensive backlog)
