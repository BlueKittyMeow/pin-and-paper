# Spec: Fast app launch (defer heavy init off the first frame)

**Date:** 2026-08-02 · **Author:** Fable 5 · **Status:** Draft, pending review
**Bug:** App takes several seconds to reach a usable UI on Android.

## Root cause

`main()` (`lib/main.dart:24-86`) awaits, *before* `runApp()`:

1. `cleanupExpiredDeletedTasks()` — DB open + delete (`:36-45`)
2. `Supabase.initialize` **+ `SyncService.instance.initialize()`** (`:47-59`) —
   the latter ends with `await pull()` (`sync_service.dart:624`), a full
   **network round-trip** (multi-second on mobile; the dominant cost)
3. `DateParsingService.initialize()` (`:61-68`) — boots a QuickJS engine and
   evaluates `assets/js/chrono.min.js` (`date_parsing_service.dart:55-77`) —
   the second-biggest cost, plus `loadSettings()`
4. `NotificationService.initialize()` + `ReminderService.checkMissed()`
   (`:70-84`) — timezone DB load + plugin init + settings read

None of these are needed to render the task list: `TaskProvider.loadTasks()`
reads local SQLite independently.

## Changes (all in `pin_and_paper/lib/main.dart` unless noted)

1. **`main()` keeps only:** desktop `sqfliteFfiInit` block (must precede any DB
   use), `WidgetsFlutterBinding.ensureInitialized()`, `await
   Supabase.initialize(...)` in its existing try/catch, then `runApp()`.
   Supabase init stays synchronous-side because it is cheap (storage read, no
   awaited network) and `sync_service.dart`/`auth_service.dart` reference
   `Supabase.instance`, which throws if accessed before initialize — not worth
   the race for ~10 ms.

2. **New `Future<void> _deferredStartup()`** in `main.dart`, scheduled after
   the first frame — `WidgetsBinding.instance.addPostFrameCallback((_) {
   unawaited(_deferredStartup()); })` registered just before/at `runApp`.
   Steps run **sequentially**, each in its own try/catch mirroring the
   existing per-step catch blocks and log messages:

   a. `DateParsingService().loadSettings()` — cheap prefs read, promoted to
      first so the today-cutoff is correct before any date bucketing repaints.
      (Safe before `initialize()`: it only sets prefs-backed fields.)
   b. `TaskService().cleanupExpiredDeletedTasks()` — unchanged behavior.
   c. `DateParsingService().initialize()` — the QuickJS boot. Runs post-frame
      so its synchronous `evaluate()` chunk can no longer delay first paint.
   d. `NotificationService().initialize()` — plugin + timezone init only;
      `checkMissed()` moves to (f).
   e. `SyncService.instance.initialize()` — near-last because it contains the
      network pull; local init steps must not wait behind it. Ordering
      invariants preserved: cleanup (b) still precedes pull (e). UI refresh
      after the pull already works via `SyncService.onDataChanged` →
      `TaskProvider.refreshWithCurrentFilters` (`task_provider.dart:587-598`,
      callback registered in `home_screen.dart:100` long before the pull can
      fire) — no new wiring needed.
   f. `ReminderService().rescheduleAll()` **then** `checkMissed()` — both
      REQUIRED, after (e), per review:
      - `rescheduleAll()` heals reminders silently dropped during the window:
        `scheduleReminders()` no-ops while `!isInitialized`
        (`reminder_service.dart:82-88`), and `TaskProvider.createTask`
        (`task_provider.dart:697-703`) calls it for any due-dated task —
        nothing else ever reconciles the gap (`rescheduleAll`'s only current
        caller is a settings-screen action). Running it after the pull also
        covers reminders on remotely-created tasks.
      - `checkMissed()` after the pull preserves today's semantics: main.dart
        currently runs it after sync init, so remotely-synced overdue tasks
        alert on THIS launch, not the next one.

   Start the chain a beat after first paint (e.g.
   `Future.delayed(~300 ms)` inside the post-frame callback) so initial
   gestures/animations settle. Known residual: the QuickJS `evaluate()` calls
   in (c) are synchronous FFI on the UI isolate — post-frame scheduling stops
   them blocking first paint but a gesture in that instant can still stutter;
   accepted, profile on device before optimizing further.

3. **No API/behavior changes elsewhere.** Provider tree, `_LaunchRouter`,
   quiz routing, and screens are untouched.

## Accepted during the deferred window (~first second)

- Quick Add date parsing returns null (`date_parsing_service.dart:90-93`
  guard) — typed dates briefly not auto-detected; harmless, already the
  permanent behavior on web.
- `getCurrentEffectiveToday()` uses default 4:59 cutoff until (a) lands —
  pure-Dart defaults, no crash (`date_parsing_service.dart:227-239`).
- Sync begins a beat later; status UI reads DB-backed sync meta, which does
  not depend on `initialize()` having run.
- Missed-notification check runs seconds later than before — irrelevant at
  this timescale.

## Out of scope

- Android native splash / engine spin-up time (platform floor, untouchable
  from Dart).
- Making `pull()` incremental/resumable, startup-blocks-on-network review
  finding M-? hardening beyond this reorder, clock-skew H-4, tombstones H-5.
- Any change to `SyncService.initialize()` internals.

## Tests

- Existing suites must stay green (they don't execute `main()`).
- Extend `test/services/date_parsing_service_test.dart`: the existing
  `'handles null gracefully when not initialized'` test (lines 229-234) is
  unreliable — the singleton stays initialized from the earlier group on any
  platform where flutter_js loads, so it only tests the guard by accident on
  Linux. The pre-init assertion must call `DateParsingService().dispose()`
  (resets `_initialized`, `date_parsing_service.dart:244-248`) immediately
  before asserting `parse()` returns null.
- Real verification is on-device (Android build follows this change);
  reviewer should sanity-check the ordering argument, not demand an
  integration test.

**Env note:** targeted `flutter test` only; no builds. The 22 flutter_js
date-parsing failures on Linux are pre-existing.
