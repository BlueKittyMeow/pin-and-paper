# Spatial View (M3/M4) — as-built addendum to the plan of record

**Date:** 2026-08-03 · **Author:** Fable 5 · **Status:** Interrogated (Sonnet, PASS WITH CHANGES — amendments folded in), ready to implement
**Plan of record:** `pin_and_paper_dev_harness/docs/working/DRAG_DROP_CANVAS_MVP_PLAN.md`
Milestones 3–4 (approved 2026-07-17). This addendum does NOT replace it — it
records what changed between approval and now, and resolves the small
decisions the plan couldn't have known about. Implement plan + addendum
together; where they conflict, the addendum wins (it knows the as-built code).

## Milestone 3 (DB v13 + service) — no changes

Implement exactly as written. Verified (interrogation 2026-08-03):
`databaseVersion` is 12; `_upgradeDB` uses sequential `if (oldVersion < N)`
guards with each `_migrateToVN` wrapping DDL in `db.transaction`; no CHECK
constraints/triggers obstruct the ALTER TABLE; every task read uses
`SELECT *` so the new columns flow through with zero query changes.
**Write pattern answered:** `updateTaskTitle` (`task_service.dart:640-680`)
is fetch-first, then a plain sequential `db.update` FOLLOWED by
`SyncService.instance.logChange` — NOT wrapped in one transaction.
`updateTaskCanvasPosition` follows that established pattern, not the plan
pseudocode's implied atomicity.
**Verified safe (positive finding):** the MCP `update_task` edge function
builds a sparse update object and never touches unspecified columns, and
`restoreTask()` writes only `deleted_at`/`updated_at` — neither path can
null or clobber `canvas_x/canvas_y`.

## Milestone 4 deltas (the module API grew since the plan)

1. **Flip is built — use it.** `entityBuilder` should return
   `FlippableTaskCard(data, showBack, isSelected, backFields)`, not bare
   `TaskCard`. Flip state: `Set<String>` of task ids on the
   `TaskSpatialDataSource` (toggled in `onEntityDoubleTapped`,
   `notifyListeners`) — view-state, NOT task data, per the flip
   implementation notes. `TaskCardBackFields`: use `const
   TaskCardBackFields()` defaults for the POC; the settings-backed
   preference is a follow-up, not M4.
2. **Adapter maps more fields now.** `TaskCardData` grew `createdAt` and
   `notes` — map both from `Task`. `isOverdue`: do NOT use plain
   `dueDate < now`. Interrogation finding: no public "is overdue" helper
   exists — the Today-Window-aware rule is duplicated in
   `DateSuffixParser._isOverdue` (private, `date_suffix_parser.dart:166-177`)
   and inline in `TaskProvider._refreshTreeController`'s `DateFilter.overdue`
   branch (`task_provider.dart:398-405`), both built on
   `DateParsingService().getCurrentEffectiveToday()`. **Do option (a):**
   extract a small public helper (e.g. `bool isTaskOverdue(DateTime dueDate,
   {required bool isAllDay})` beside `DateParsingService`), point both
   existing call sites and the new adapter at it. Small diff, two files
   outside `lib/spatial/`, and it ends the duplication instead of adding a
   third copy.
3. **The desk look is established.** `SpatialCanvas(background: ...)` exists
   (post-plan API): kraft texture + 2px amber `#C4941A` border, same as the
   example. Copy the downscaled `SeamlessKraft1.jpg` (864KB, in
   `pin_and_paper_canvas/example/assets/`) into the app's assets. The
   default drag-lift decoration is correct for cards — do not pass
   `liftDecorationBuilder`.
4. **Card size:** import `kCardSize` from card_renderer for
   `TaskSpatialEntity.size` — don't hardcode `Size(220,140)`.
5. **zIndex under MIN−1 positions.** The plan's `zIndex = task.position`
   predates the top-insert change: positions now grow *negative* for new
   tasks, so position-as-z stacks the newest task at the BOTTOM of any
   overlap. Use `zIndex = -task.position` (still stable, newest-on-top,
   matching the list's newest-first prominence). `SpatialEntity.zIndex` is
   an int; task positions are ints — no conversion issue.
6. **Interaction behaviors that come free** (no work, but the implementer
   should expect them in testing): drag-start selects (amber glow without a
   tap), dragged/selected cards render above their zIndex tier, trackpad
   pan/pinch always drives the viewport, drag lift scale+shadow.
7. **Startup race (corrected by interrogation):** the race is real but
   predates and is unrelated to fast-launch — `loadTasks()` has always run
   from `HomeScreen.initState`'s post-frame callback. Guard STRICTLY on
   `TaskProvider.isLoading` (`task_provider.dart:233` — the same flag the
   home screen's spinner uses; true only during the very first load, always
   resolves false in a `finally`). Do NOT also guard on `tasks.isEmpty`: a
   legitimately empty task list would show the placeholder forever instead
   of a correctly-empty desk. One-shot listener for the `isLoading → false`
   transition, then snapshot.
8. **Completed/deleted policy for the POC:** render the snapshot as-is
   (hierarchy load already excludes soft-deleted; completed tasks appear as
   their struck-through card face — that's a feature). The integration
   review §5.5 preference-based hiding is a follow-up.
9. **Branch:** per the plan, main-app M3/M4 work happens on
   `claude/drag-drop-canvas-mvp-cu6uoy` in `pin-and-paper` (create from
   `main`; today's bug fixes are already on `main` and must be in the
   branch's base). **Caution:** `main`'s working tree currently carries
   uncommitted WIP (`task_provider.dart` + 5 test files — the separate
   flaky-test-teardown session's work). Do NOT commit, stash, or carry it:
   leave it untouched and create the branch only once that session has
   landed its work, or coordinate with the owner.
10. **Accepted build-size tradeoff (interrogation finding):** the
   `card_renderer → sketchpad` path dep bundles sketchpad's entire 27 MB
   asset glob (`assets/ - AP11.jpg, SeamlessKraft1.jpg, VintagePaper8.png`)
   into the app's APK, despite zero Dart-level sketchpad usage — Flutter
   ships a dependency's declared assets wholesale. ACCEPTED for the POC;
   named follow-up: narrow sketchpad's pubspec `assets:` glob (or decouple
   card_renderer) before any size-sensitive release.

## Explicitly NOT in M3/M4 (queued behind them)

- The amethyst desk object + example-style desk persistence-of-decor: the
  stone stays an example-app delight until a `desk_objects` home exists in
  the real schema. Follow-up feature, separately specced.
- Back-fields settings UI, completed-card hiding preference, live canvas
  updates while open, syncing canvas_x/y to Supabase (plan documents the
  follow-up path).

## Tests (plan's list plus)

- Adapter: overdue uses the shared cutoff rule (freeze a time near the
  cutoff boundary and assert agreement with the list view's rule).
- Flip: double-tap callback toggles the id set; entityBuilder passes
  showBack accordingly.
- zIndex: two tasks with positions {−2, 0} → newer (−2) has higher zIndex.
- Empty-snapshot guard: CanvasScreen built before loadTasks completes shows
  the placeholder, then populates.
