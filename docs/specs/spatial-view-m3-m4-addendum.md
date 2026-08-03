# Spatial View (M3/M4) — as-built addendum to the plan of record

**Date:** 2026-08-03 · **Author:** Fable 5 · **Status:** Draft, pending interrogation
**Plan of record:** `pin_and_paper_dev_harness/docs/working/DRAG_DROP_CANVAS_MVP_PLAN.md`
Milestones 3–4 (approved 2026-07-17). This addendum does NOT replace it — it
records what changed between approval and now, and resolves the small
decisions the plan couldn't have known about. Implement plan + addendum
together; where they conflict, the addendum wins (it knows the as-built code).

## Milestone 3 (DB v13 + service) — no changes

Implement exactly as written. Two verifications for the implementer:
`databaseVersion` is currently 12 (`constants.dart`), and follow the
existing `_upgradeDB` guard/`_migrateToVn` conventions and the
`updateTaskTitle` write pattern precisely, including `logChange` in the same
transaction if that's the established pattern (check `updateTaskTitle`).

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
   `dueDate < now`; reuse the app's existing overdue semantics (the
   today-cutoff logic the list view uses — find its exact source and share
   it, don't duplicate the rule).
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
7. **Startup interplay:** `CanvasScreen` snapshots `TaskProvider.tasks` in
   `initState`. Post fast-launch, providers load after first frame — if the
   user opens Spatial View before the initial `loadTasks()` completes, the
   snapshot may be empty. Guard: if the provider reports loading/empty,
   show a lightweight "desk is being set" placeholder and rebuild the data
   source when the provider notifies (listen once, then snapshot).
8. **Completed/deleted policy for the POC:** render the snapshot as-is
   (hierarchy load already excludes soft-deleted; completed tasks appear as
   their struck-through card face — that's a feature). The integration
   review §5.5 preference-based hiding is a follow-up.
9. **Branch:** per the plan, main-app M3/M4 work happens on
   `claude/drag-drop-canvas-mvp-cu6uoy` in `pin-and-paper` (create from
   `main`; today's bug fixes are already on `main` and must be in the
   branch's base).

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
