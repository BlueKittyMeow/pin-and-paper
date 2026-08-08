import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart' show kCardSize;
import 'package:pin_and_paper_sketchpad/sketchpad.dart' show LayerStack;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/task_drawing.dart';
import '../services/desk_object_service.dart';
import '../services/drawing_service.dart';
import '../services/task_service.dart';
import 'amethyst_desk_entity.dart';
import 'dachshund_desk_entity.dart';
import 'desk_object_entity.dart';
import 'task_spatial_entity.dart';

/// Tray zone footprint, for the desk background's outline (see
/// `SpatialDeskBackground`). Sized to contain one card's footprint plus the
/// full fan of stack offsets before [taskTrayStackStep] tightens.
const Size kTaskTrayZoneSize = Size(260, 200);

/// Default per-card stack offset within the landing tray, before tightening.
const Offset kTaskTrayBaseStep = Offset(7, 5);

/// Past this many unplaced cards, [taskTrayStackStep] shrinks the per-card
/// offset so the stack can't escape [kTaskTrayZoneSize].
const int kTaskTrayTightenThreshold = 15;

/// At most this many tray cards are actually emitted as canvas entities
/// while the tray is stacked (the topmost ones). A card 30-deep in the
/// tightened stack is invisible and ungrabbable anyway — every card under
/// the top few shows at most a sliver of edge — but each one emitted still
/// costs a full textured card widget on open (owner report 2026-08-03: the
/// Spatial View "took a decent amount of time to load" with a 100+-card
/// inbox). The buried cards still exist as data: they surface as the stack
/// depletes on reopen, and the arrange toggle ([TaskSpatialDataSource
/// .setTrayArranged]) always spreads ALL of them.
const int kTaskTrayRenderCap = 20;

/// Margin used both by the arranged-tray grid and its cell spacing.
const double kTrayArrangeMargin = 20.0;

/// How many most-recently-finished cards show in the right-side
/// "recently completed" stack (owner request 2026-08-03). Older completions
/// simply drop off the pile; the full history lives in the list view.
/// Trimmed 10 → 8 (owner 2026-08-04 night): a 10-card fan down the right
/// edge ran into the landing tray's corner.
const int kRecentCompletedCount = 8;

/// Top-left anchor of the recently-completed stack: upper-right of the
/// desk, mirroring the landing tray's lower-right inbox — glanceable, out
/// of the way of live work.
Offset completedStackAnchor(Size canvasSize) => Offset(canvasSize.width - 300, 80);

/// Bounding-box furniture drawn around the done pile (owner request
/// 2026-08-04), mirroring the landing tray's outline. Same footprint as
/// [kTaskTrayZoneSize] so the two read as a matched set.
const Size kDonePileZoneSize = Size(260, 200);

/// The done pile's outline rect in canvas coordinates — the base card sits
/// centered in it. Also the felt-tap target that fans the pile out along
/// the right edge / restacks it ([TaskSpatialDataSource.onCanvasTapped]).
Rect donePileZoneRect(Size canvasSize) {
  final anchor = completedStackAnchor(canvasSize);
  return Rect.fromLTWH(
    anchor.dx - (kDonePileZoneSize.width - kCardSize.width) / 2,
    anchor.dy - (kDonePileZoneSize.height - kCardSize.height) / 2,
    kDonePileZoneSize.width,
    kDonePileZoneSize.height,
  );
}

/// How card faces are shown: per-card manual flips, or a temporary
/// everyone-shows-this-face override for quick scanning (owner request
/// 2026-08-03). Overrides are view-only — the per-card manual states are
/// kept and restored on return to [manual] — unless explicitly committed
/// via [TaskSpatialDataSource.commitFlipView].
enum FlipViewMode { manual, allFronts, allBacks }

/// Top-left anchor of the landing tray: unplaced ("new") task cards stack
/// here, bottom-right of the desk, like index cards dropped in an inbox.
///
/// M3/M4 addendum item 11 (supersedes the plan's deterministic grid for
/// null-position tasks).
Offset taskTrayAnchor(Size canvasSize) => Offset(canvasSize.width - 300, canvasSize.height - 220);

/// Per-card stack offset for a tray holding [unplacedCount] cards. Tightens
/// past [kTaskTrayTightenThreshold] so a large inbox doesn't spill past
/// [kTaskTrayZoneSize] — addendum item 11's "tighten if >~15" note.
Offset taskTrayStackStep(int unplacedCount) {
  if (unplacedCount <= kTaskTrayTightenThreshold) return kTaskTrayBaseStep;
  final scale = kTaskTrayTightenThreshold / unplacedCount;
  return Offset(kTaskTrayBaseStep.dx * scale, kTaskTrayBaseStep.dy * scale);
}

/// Builds and owns the entities behind the Spatial View's [SpatialCanvas]
/// (DRAG_DROP_CANVAS_MVP_PLAN.md Milestone 4), from a one-time [Task]
/// snapshot, plus whichever desk objects ([GemDeskEntity],
/// [DachshundDeskEntity]) are placed rather than in the drawer.
///
/// Layout (run once at construction):
/// - Completed tasks never mix with live work on the desk (owner decision
///   2026-08-03): the [kRecentCompletedCount] most recently finished fan
///   out as a read-only "done" pile at [completedStackAnchor]; older
///   completions drop off. Dragging a pile card snaps back — finished
///   cards can't be placed. A placed completed task keeps its stored
///   canvas_x/canvas_y in the DB, so uncompleting it restores it to its
///   exact desk spot.
/// - Remaining tasks with a stored [Task.canvasX]/[Task.canvasY] render
///   there.
/// - Tasks with no stored position ("unplaced") stack in the
///   landing tray (see [taskTrayAnchor]/[taskTrayStackStep]) instead of the
///   plan's original deterministic grid — M3/M4 addendum item 11. This
///   stacking is in-memory only: nothing is written to the database until
///   the user drags a card out of the tray (same "avoid N sync-log writes on
///   first open" rationale the plan gave for the grid it supersedes), so
///   unplaced cards re-stack identically every time the Spatial View
///   reopens, until placed. While stacked, only the top [kTaskTrayRenderCap]
///   tray cards are emitted as entities (load-time cap; see that constant).
///
/// The arrange toggle ([setTrayArranged]) spreads the whole tray into a
/// reading-order grid (newest first, top-left) so every inbox card is
/// visible and grabbable at once. Arranged positions are as in-memory as the
/// stack's: dragging a card (from stack or grid) is what places it for real.
///
/// [onEntityMoved] is the only task write path: it updates the entity in
/// place, notifies listeners for an immediate re-render, and fires
/// [TaskService.updateTaskCanvasPosition] without awaiting it (errors are
/// logged, not surfaced — a failed persist just means the position doesn't
/// survive restart, not a crash). Desk objects persist via the
/// desk_objects table ([DeskObjectService]) instead — decor, not tasks.
///
/// The constructor's [Task] snapshot can be stale for canvas_x/canvas_y —
/// its caller (`CanvasScreen`) hands over `TaskProvider.tasks`, and nothing
/// patches that cache after a drag persists (unlike e.g. `updateTaskTitle`,
/// which does patch it). [_restoreCanvasPositions] re-reads positions
/// straight from SQLite after [_layout] runs and reconciles, the same
/// "don't trust the snapshot, re-read the table" pattern
/// [_restoreDeskObjects] already used for desk objects — see that method's
/// doc comment for the full bug story (owner report 2026-08-05).
class TaskSpatialDataSource extends SpatialDataSource {
  TaskSpatialDataSource({
    required List<Task> tasks,
    required TaskService taskService,
    required this.canvasSize,
    DrawingService? drawingService,
    DeskObjectService? deskObjectService,
  }) : _taskService = taskService,
      _drawingService = drawingService ?? DrawingService(),
      _deskObjectService = deskObjectService ?? DeskObjectService(),
      _gems = {
        // Amethyst dead center of the desk by default — the stone must be
        // unmissable on first open (its example-app ancestor tucked itself
        // into a corner and the owner assumed it was buried). Its recolored
        // siblings stagger diagonally from there (their default spot only
        // matters when placed without a view center). zIndexes: amethyst
        // keeps the base, the dachshund owns base+1, crystals take +2/+3/+4
        // — unique paint order for every desk object.
        for (final (i, id) in kGemVariantsById.keys.indexed)
          id: GemDeskEntity(
            id: id,
            zIndex: kAmethystZIndex + (i == 0 ? 0 : i + 1),
            position: Offset(
              (canvasSize.width - kAmethystDefaultSize.width) / 2 + 46.0 * i,
              (canvasSize.height - kAmethystDefaultSize.height) / 2 + 34.0 * i,
            ),
          ),
      },
      _dachshund = DachshundDeskEntity(
        // Default spot only matters the first time he's placed without a
        // stored position: just right of the stone's default. His widened
        // FRAME overlaps the stone's box, but the visible dog (central ~40%
        // of the frame, visual half-width ~78) clears the stone's 131.
        position: Offset(
          (canvasSize.width - kDachshundDefaultSize.width) / 2 + 260,
          (canvasSize.height - kDachshundDefaultSize.height) / 2,
        ),
      ) {
    _layout(tasks);
    initialized = Future.wait([_restoreDeskObjects(), _loadDrawings(), _restoreCanvasPositions()]);
  }

  final TaskService _taskService;
  final DrawingService _drawingService;
  final DeskObjectService _deskObjectService;

  /// Canvas bounds this data source was laid out for.
  final Size canvasSize;

  /// Tasks with a stored canvas position, rendered exactly there.
  final List<TaskSpatialEntity> _placed = [];

  /// Unplaced (tray) tasks, oldest first, holding their current in-memory
  /// positions (stacked or arranged). Dragging one moves it to [_placed].
  final List<TaskSpatialEntity> _tray = [];

  /// The most recently finished tasks, oldest-shown first, fanned at
  /// [completedStackAnchor]. Read-only: never draggable, never persisted.
  final List<TaskSpatialEntity> _recentCompleted = [];

  final Map<String, GemDeskEntity> _gems;
  final DachshundDeskEntity _dachshund;

  /// Which desk objects are on the desk (vs. in the drawer). The amethyst
  /// starts placed — it predates the drawer, and a v14→v15 upgrade must not
  /// make the stone vanish. The dachshund starts in the drawer.
  final Set<String> _placedDeskObjectIds = {kAmethystDeskId};

  bool _trayArranged = false;

  // -- Tag-tap spotlight (owner idea 2026-08-06, tentative -- first-pass for
  // device feel-testing) --------------------------------------------------

  /// The tag currently spotlit, or null when nothing is. View-state only --
  /// deliberately never persisted (a fresh Spatial View open always starts
  /// un-spotlit, per the owner's design note) and never written anywhere
  /// but here. Identified by tag id (matches [TagChip.id]/the main app's
  /// `Tag.id`), the same identity `TaskCardAdapter` already uses when it
  /// maps a `Tag` to a `TagChip` -- not by name, which isn't guaranteed
  /// unique.
  String? _spotlitTag;

  /// See [_spotlitTag]. `CanvasScreen` reads this (via the data source it
  /// already listens to) to decide which desk cards ghost.
  String? get spotlitTag => _spotlitTag;

  /// Ids of [_placed] entities that currently carry [_spotlitTag], as last
  /// reported by [setSpotlightMatches]. Drives [getVisibleEntities]'s
  /// paint-order raise (owner idea 2026-08-06 addendum: "raise the matching
  /// cards' paint order ABOVE the non-matching ones"). This data source has
  /// no route to tag data of its own -- tags live in `TaskProvider`/
  /// `TagService`, never on [Task] itself (see class doc) -- so this is
  /// fed in from outside rather than computed here. Reset to empty
  /// whenever the spotlit tag changes, so a stale match set from a
  /// previous tag can never survive a switch or a clear.
  Set<String> _spotlightMatchIds = const {};

  /// Placed (on-desk) entity ids, for whichever layer computes tag
  /// membership (`CanvasScreen`, via `TaskProvider.getTagsForTask`) to know
  /// which ids to test before calling [setSpotlightMatches]. Tray and
  /// done-pile cards are deliberately excluded -- the raise is placed-only
  /// (see [getVisibleEntities]).
  List<String> get placedEntityIds => [for (final e in _placed) e.id];

  /// Tells the data source which [placedEntityIds] currently carry
  /// [_spotlitTag], so [getVisibleEntities] can temporarily raise their
  /// paint order as a group (see that method's doc comment for the
  /// mechanism). Ids outside [_placed] are harmless -- [getVisibleEntities]
  /// only ever tests membership against [_placed] itself, so tray/done-pile/
  /// desk-object ids or stale ids from a since-moved card are silently
  /// inert. No-op while nothing is spotlit, so a stray call after
  /// [clearSpotlight] can't resurrect a raise. Deliberately does NOT call
  /// notifyListeners -- callers are expected to invoke this synchronously
  /// as part of the same rebuild that already reads [spotlitTag] (e.g.
  /// right before handing entities to the canvas), not as an isolated
  /// state change needing its own repaint.
  void setSpotlightMatches(Set<String> placedIds) {
    if (_spotlitTag == null) return;
    _spotlightMatchIds = placedIds;
  }

  /// Tag-chip tap handler: spotlighting is a toggle on the tapped tag, not
  /// a stack -- tapping the ALREADY-spotlit tag clears it (owner spec:
  /// "tapping the same tag again clears the spotlight"), tapping any other
  /// tag switches straight to it (no need to clear first).
  void spotlightTag(String tagId) {
    _spotlitTag = _spotlitTag == tagId ? null : tagId;
    _spotlightMatchIds = const {};
    notifyListeners();
  }

  /// Clears the spotlight, if any -- fired by a tap on empty felt (owner
  /// spec), alongside [onCanvasTapped]'s existing done-pile-fan collapse.
  /// No-op (no spurious notify) when nothing is spotlit.
  void clearSpotlight() {
    if (_spotlitTag == null) return;
    _spotlitTag = null;
    _spotlightMatchIds = const {};
    notifyListeners();
  }

  bool _donePileFanned = false;

  /// Whether the done pile is currently fanned down the right edge (true)
  /// or stacked in its zone (false). Toggled by tapping the pile's outline
  /// box on empty felt (see [onCanvasTapped]).
  bool get donePileFanned => _donePileFanned;

  bool _donePileOverflowsFan = false;

  /// True once the done pile is fanned AND [kRecentCompletedCount] cards
  /// don't fit as one non-overlapping column within the fan's safe
  /// vertical band (see [_positionDonePile]'s spacing floor). Always false
  /// while stacked ([_donePileFanned] false).
  ///
  /// `CanvasScreen` reads this to decide how to present the fanned state:
  /// an on-desk fan when it fits, or a scrollable tray overlay (modeled on
  /// the desk-objects drawer) when it doesn't — owner decision 2026-08-06,
  /// superseding an earlier attempt at wrapping the overflow into a second
  /// on-desk fan column. The desk itself stays at its neat compact stack
  /// while overflowing ([_positionDonePile] falls back to
  /// [_positionCompletedStack]) — "no fan on the desk in that case" was the
  /// explicit call, not a degraded multi-column fan.
  bool get donePileOverflowsFan => _donePileOverflowsFan;

  /// The done pile, newest-first — the browsing order for
  /// [donePileOverflowsFan]'s tray (owner decision 2026-08-06). Internally
  /// [_recentCompleted] is oldest-first (see that field's doc comment for
  /// why); this is a read-only reversed view for UI consumers.
  List<TaskSpatialEntity> get recentCompletedNewestFirst => _recentCompleted.reversed.toList();

  /// Fans the done pile out along the desk's right edge so every recent
  /// completion is visible at once, or restacks it (owner request
  /// 2026-08-04). View-state only — nothing persists.
  void toggleDonePileFanned() {
    _donePileFanned = !_donePileFanned;
    _positionDonePile();
    notifyListeners();
  }

  /// Lays the done pile out per [_donePileFanned]: a cascade down the
  /// right edge (newest at top, and — via its higher zIndexOverride — on
  /// top of the card below it), or the compact anchor-fan.
  void _positionDonePile() {
    if (_recentCompleted.isEmpty) return;
    if (!_donePileFanned) {
      _donePileOverflowsFan = false;
      _positionCompletedStack();
      return;
    }
    const margin = 40.0;
    final x = canvasSize.width - kCardSize.width - margin;
    final top = completedStackAnchor(canvasSize).dy;
    // The fan must stop short of the landing tray's corner (owner
    // screenshot 2026-08-04 night: a 10-card fan ran straight into the
    // inbox stack).
    final bottomLimit = taskTrayAnchor(canvasSize).dy - kCardSize.height - 24;
    final n = _recentCompleted.length;
    final availableHeight = math.max(0.0, bottomLimit - top);
    // A card's own height is the spacing floor: below it, the card above
    // starts shingling over the TOP of the card below — exactly where its
    // accent bar and title sit, not just its tags/date footer (owner
    // report 2026-08-06, phone APK: at the app's real desk-panel canvas
    // size a full kRecentCompletedCount pile squeezed naive
    // `availableHeight / (n - 1)` spacing to ~123px, 17px short of a
    // card's 140px height, clipping the title of every card but the
    // topmost). This didn't show up against this file's own unit tests'
    // more generous canvas fixture — see
    // task_spatial_data_source_test.dart's cramped-canvas regression case.
    final idealSpacing = n <= 1 ? 0.0 : availableHeight / (n - 1);
    _donePileOverflowsFan = n > 1 && idealSpacing < kCardSize.height;
    if (_donePileOverflowsFan) {
      // Doesn't fit one column at the floor. An earlier fix wrapped the
      // overflow into a second on-desk column; the owner's call
      // (2026-08-06) was simpler: no fan on the desk at all in that case
      // — CanvasScreen shows the scrollable tray instead
      // (see [donePileOverflowsFan]) — so the desk itself just stays at
      // its neat compact stack.
      _positionCompletedStack();
      return;
    }
    // Capped above by the old "don't spread wastefully thin" ceiling, but
    // that can never pull it back below the floor above (idealSpacing is
    // already >= kCardSize.height in this branch).
    final spacing = n <= 1 ? 0.0 : math.min(kCardSize.height + 16.0, idealSpacing);
    // _recentCompleted is oldest-first; the newest takes the top slot.
    for (var i = 0; i < n; i++) {
      _recentCompleted[i].position = Offset(x, top + spacing * (n - 1 - i));
    }
  }

  /// The compact anchor-fan: every card's small stack offset from
  /// [completedStackAnchor], the pile's non-fanned resting state and also
  /// what stays on the desk while [_donePileOverflowsFan] is true (the
  /// tray takes over browsing duty in that case).
  void _positionCompletedStack() {
    for (var i = 0; i < _recentCompleted.length; i++) {
      _recentCompleted[i].position = completedStackAnchor(canvasSize) + kTaskTrayBaseStep * i.toDouble();
    }
  }

  @override
  void onCanvasTapped(Offset position) {
    // Tag-tap spotlight (owner idea 2026-08-06): any felt tap clears it,
    // same "tap off to dismiss" shape as the done-pile fan below. Runs
    // first and unconditionally -- it's independent of the fan/pile
    // handling that follows, so both can react to the same tap.
    clearSpotlight();
    // Fanned: any felt tap collapses the fan back into its box. Stacked:
    // the pile's outline box is the control that fans it out. (Taps ON
    // cards never get here — entities win the hit test first; see
    // [onEntityTapped] for the other half of tap-off-to-dismiss.)
    if (_donePileFanned) {
      toggleDonePileFanned();
      return;
    }
    if (_recentCompleted.isNotEmpty && donePileZoneRect(canvasSize).contains(position)) {
      toggleDonePileFanned();
    }
  }

  @override
  void onEntityTapped(String id) {
    // The other half of "any tap OFF the fanned cards dismisses them"
    // (owner 2026-08-04 night): tapping some OTHER card or desk object
    // collapses the fan too. Tapping a fanned card itself keeps the fan
    // open — that's inspecting, not dismissing.
    if (_donePileFanned && !_recentCompleted.any((e) => e.id == id)) {
      toggleDonePileFanned();
    }
  }

  /// Set by [dispose]; the async restore paths check it so a restore that
  /// lands after disposal (screen closed immediately, common in tests)
  /// doesn't notify a dead ChangeNotifier.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Whether the tray is currently spread out as a grid (true) or stacked
  /// in the landing tray (false). Toggled by [setTrayArranged].
  bool get trayArranged => _trayArranged;

  /// Completes when the amethyst's persisted position/size (if any) has
  /// been applied, drawings have loaded, AND fresh canvas_x/canvas_y have
  /// been re-read from SQLite for every placed/tray card ([_restoreCanvasPositions] —
  /// the fix for the stale-snapshot "cards don't come back" bug, see that
  /// method's doc comment). Awaited by tests; the app lets it land whenever
  /// it lands (a frame or two after first paint, via notifyListeners).
  late final Future<void> initialized;

  /// Ids currently showing their `TaskCardBack` face. View-state, not task
  /// data (M3/M4 addendum item 1) — toggled by [onEntityDoubleTapped].
  final Set<String> _flippedIds = {};

  FlipViewMode _flipViewMode = FlipViewMode.manual;

  /// Current face-view mode. [FlipViewMode.manual] shows each card per its
  /// own double-tap state; the override modes force every card to one face
  /// for quick scanning without touching the per-card states.
  FlipViewMode get flipViewMode => _flipViewMode;

  /// Switch face-view modes. Same mode is a no-op; [FlipViewMode.manual]
  /// returns to the per-card states, untouched by the override.
  void setFlipViewMode(FlipViewMode mode) {
    if (mode == _flipViewMode) return;
    _flipViewMode = mode;
    notifyListeners();
  }

  /// "Keep these faces": adopt the current override as the new per-card
  /// manual state — allFronts unflips every card, allBacks flips every
  /// card — then return to [FlipViewMode.manual]. No-op in manual mode.
  void commitFlipView() {
    if (_flipViewMode == FlipViewMode.manual) return;
    _materializeFlipView();
    notifyListeners();
  }

  void _materializeFlipView() {
    _flippedIds.clear();
    if (_flipViewMode == FlipViewMode.allBacks) {
      for (final e in [..._placed, ..._tray, ..._recentCompleted]) {
        _flippedIds.add(e.id);
      }
    }
    _flipViewMode = FlipViewMode.manual;
  }

  /// Whether [id]'s card is currently showing its back face.
  bool isFlipped(String id) => switch (_flipViewMode) {
    FlipViewMode.manual => _flippedIds.contains(id),
    FlipViewMode.allFronts => false,
    FlipViewMode.allBacks => true,
  };

  // -- Card drawings (M-D5) ----------------------------------------------

  /// Loaded drawing rows, keyed taskId -> face -> row. Populated once at
  /// construction by [_loadDrawings] (one bulk query — never per-task);
  /// kept current by [toggleDrawingVisible] / [refreshDrawingFor].
  final Map<String, Map<String, TaskDrawing>> _drawings = {};

  /// Parsed [LayerStack]s, lazily built from [_drawings] and keyed
  /// `taskId/face`. Cached so the canvas can hand `DrawingPreview` the
  /// SAME stack instance across rebuilds — the preview's picture cache
  /// keys on stack identity + revision, so a fresh parse per rebuild
  /// would re-record the picture every frame during pans/drags (the §5
  /// perf rule: cards never pay per-frame tessellation). A null value
  /// caches "this JSON failed to parse" so a corrupt row is logged once,
  /// not per frame.
  final Map<String, LayerStack?> _drawingStacks = {};

  Future<void> _loadDrawings() async {
    try {
      final all = await _drawingService.getAllDrawings();
      for (final drawing in all) {
        (_drawings[drawing.taskId] ??= {})[drawing.face] = drawing;
      }
      if (all.isNotEmpty && !_disposed) notifyListeners();
    } catch (e) {
      // Same contract as the amethyst restore: a failed load means bare
      // cards, not a crash.
      debugPrint('TaskSpatialDataSource: drawings load skipped: $e');
    }
  }

  /// The stored drawing JSON for [taskId]'s [face], or null when that face
  /// has no drawing.
  String? drawingJsonFor(String taskId, {String face = TaskDrawing.faceFront}) =>
      _drawings[taskId]?[face]?.drawingJson;

  /// The parsed [LayerStack] for [taskId]'s [face], or null when that face
  /// has no drawing (or its JSON is corrupt). Cached per (task, face) —
  /// see [_drawingStacks] for why identity stability matters.
  LayerStack? drawingStackFor(String taskId, {String face = TaskDrawing.faceFront}) {
    final json = drawingJsonFor(taskId, face: face);
    if (json == null) return null;
    final key = '$taskId/$face';
    if (_drawingStacks.containsKey(key)) return _drawingStacks[key];
    LayerStack? stack;
    try {
      stack = LayerStack.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('TaskSpatialDataSource: unreadable drawing for $key: $e');
    }
    _drawingStacks[key] = stack;
    return stack;
  }

  /// Whether [taskId]'s [face] drawing is currently shown. False when the
  /// face has no drawing at all — "visible" describes a drawing, so use
  /// [drawingJsonFor] to distinguish "hidden" from "none".
  bool isDrawingVisible(String taskId, {String face = TaskDrawing.faceFront}) =>
      _drawings[taskId]?[face]?.visible ?? false;

  /// Whether any face of [taskId] has a drawing that is toggled hidden —
  /// drives the grey pencil tell (owner L10) so hidden ink isn't
  /// forgotten.
  bool hasHiddenDrawing(String taskId) {
    final faces = _drawings[taskId];
    if (faces == null) return false;
    return faces.values.any((d) => !d.visible);
  }

  /// Flips the show/hide toggle for [taskId]'s [face] drawing: in-memory
  /// update + notify for an immediate repaint, then fire-and-forget
  /// persistence — the exact [onEntityMoved]/[_persist] pattern. No-op if
  /// that face has no drawing.
  void toggleDrawingVisible(String taskId, {String face = TaskDrawing.faceFront}) {
    final current = _drawings[taskId]?[face];
    if (current == null) return;
    final next = !current.visible;
    _drawings[taskId]![face] = TaskDrawing(
      id: current.id,
      taskId: current.taskId,
      face: current.face,
      drawingJson: current.drawingJson,
      visible: next,
      positionX: current.positionX,
      positionY: current.positionY,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    notifyListeners();
    unawaited(_persistDrawingVisible(taskId, face, next));
  }

  Future<void> _persistDrawingVisible(String taskId, String face, bool visible) async {
    try {
      await _drawingService.setTaskDrawingVisible(taskId, visible, face: face);
    } catch (e) {
      debugPrint('TaskSpatialDataSource: failed to persist drawing visibility for $taskId/$face: $e');
    }
  }

  /// Re-reads one task's drawing rows (both faces) from the database and
  /// notifies. The canvas screen calls this after the drawing editor
  /// saves, so the card's overlay reflects the fresh ink without
  /// rebuilding the whole data source.
  Future<void> refreshDrawingFor(String taskId) async {
    try {
      final faces = <String, TaskDrawing>{};
      for (final face in const [TaskDrawing.faceFront, TaskDrawing.faceBack]) {
        final drawing = await _drawingService.getDrawingForTask(taskId, face: face);
        if (drawing != null) faces[face] = drawing;
        _drawingStacks.remove('$taskId/$face');
      }
      if (faces.isEmpty) {
        _drawings.remove(taskId);
      } else {
        _drawings[taskId] = faces;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('TaskSpatialDataSource: failed to refresh drawings for $taskId: $e');
    }
  }

  // -- Desk objects (desk_objects table, DB v15 — decor, not task data) ---

  /// Legacy amethyst persistence: the three SharedPreferences keys that
  /// held the stone's spot before the desk_objects table existed. Read as
  /// a fallback when the stone has no row yet (one-time upgrade path);
  /// never written anymore.
  static const _kAmethystXKey = 'spatial_amethyst_x';
  static const _kAmethystYKey = 'spatial_amethyst_y';
  static const _kAmethystWidthKey = 'spatial_amethyst_width';

  /// Drawer catalog order: every desk-object kind the app knows, whether
  /// placed or not — the mineral shelf first, then the pup.
  static final List<String> deskObjectIds =
      List.unmodifiable([...kGemVariantsById.keys, kDachshundDeskId]);

  DeskObjectEntity _deskObjectById(String id) {
    if (id == kDachshundDeskId) return _dachshund;
    return _gems[id] ?? (throw ArgumentError('unknown desk object: $id'));
  }

  /// Whether [id] is currently on the desk (drawer shows it ghosted) as
  /// opposed to available in the drawer.
  bool isDeskObjectPlaced(String id) => _placedDeskObjectIds.contains(id);

  /// Takes [id] out of the drawer and sets it on the desk. With a
  /// [viewCenter] (canvas coords — pass the controller's visibleRect
  /// center), the object lands centered in the user's current view; without
  /// one, it returns to wherever it last sat (its restored/default
  /// position). No-op if already placed.
  void placeDeskObject(String id, {Offset? viewCenter}) {
    if (!_placedDeskObjectIds.add(id)) return;
    final entity = _deskObjectById(id);
    if (viewCenter != null) {
      entity.position = _clampToCanvas(
        viewCenter - Offset(entity.size.width / 2, entity.size.height / 2),
        entity.size,
      );
    }
    notifyListeners();
    unawaited(_persistDeskObject(id));
  }

  /// Puts [id] back in the drawer. Its position/size/pose are kept, so
  /// re-placing without a view center restores it exactly. No-op if not
  /// placed.
  void removeDeskObject(String id) {
    if (!_placedDeskObjectIds.remove(id)) return;
    notifyListeners();
    unawaited(_persistDeskObject(id));
  }

  Offset _clampToCanvas(Offset topLeft, Size size) => Offset(
    topLeft.dx.clamp(0.0, math.max(0.0, canvasSize.width - size.width)),
    topLeft.dy.clamp(0.0, math.max(0.0, canvasSize.height - size.height)),
  );

  void _layout(List<Task> tasks) {
    final unplaced = <Task>[];
    final completed = <Task>[];
    for (final task in tasks) {
      if (task.completed) {
        completed.add(task); // finished work goes to the done pile, not the desk
        continue;
      }
      final x = task.canvasX;
      final y = task.canvasY;
      if (x != null && y != null) {
        _placed.add(TaskSpatialEntity(task: task, position: Offset(x, y)));
      } else {
        unplaced.add(task);
      }
    }

    // Done pile: newest completion on top. Ascending completedAt puts the
    // newest last in the fan — largest offset AND highest zIndexOverride,
    // so offset fan and paint order agree, same principle as the tray.
    completed.sort((a, b) {
      final at = a.completedAt?.millisecondsSinceEpoch ?? 0;
      final bt = b.completedAt?.millisecondsSinceEpoch ?? 0;
      return at.compareTo(bt);
    });
    final recent = completed.length <= kRecentCompletedCount
        ? completed
        : completed.sublist(completed.length - kRecentCompletedCount);
    _recentCompleted.addAll([
      for (var i = 0; i < recent.length; i++)
        TaskSpatialEntity(
          task: recent[i],
          position: completedStackAnchor(canvasSize) + kTaskTrayBaseStep * i.toDouble(),
          zIndexOverride: i,
        ),
    ]);

    // Oldest first: the largest position (least negative/most positive) is
    // the oldest task under new-task-top-insert, so sorting descending by
    // position puts the oldest at index 0 (smallest stack offset) and the
    // newest last (largest offset). That agrees with TaskSpatialEntity's
    // zIndex (-position, newest highest) about which card physically reads
    // as "on top" of the tray.
    unplaced.sort((a, b) => b.position.compareTo(a.position));
    final base = _trayStackBase(unplaced.length);
    final step = taskTrayStackStep(unplaced.length);
    for (var i = 0; i < unplaced.length; i++) {
      _tray.add(TaskSpatialEntity(task: unplaced[i], position: base + step * i.toDouble()));
    }
  }

  /// Base (i = 0) position for a stacked tray of [count] cards: the whole
  /// fan envelope — base card plus `step * (count - 1)` of drift — centered
  /// on [taskTrayAnchor] (where a lone card sits centered in the outline).
  /// Without this the visible top of a deep stack reads as shoved into the
  /// box's bottom-right corner (owner screenshot 2026-08-04 night).
  Offset _trayStackBase(int count) {
    final extent = taskTrayStackStep(count) * math.max(0, count - 1).toDouble();
    return taskTrayAnchor(canvasSize) - extent / 2;
  }

  /// Spread the tray into a grid (true) or restack it (false). Positions
  /// are assigned in-memory only, mirroring the stack's no-DB-writes rule.
  void setTrayArranged(bool arranged) {
    if (arranged == _trayArranged) return;
    _trayArranged = arranged;
    if (arranged) {
      _positionTrayAsGrid();
    } else {
      _positionTrayAsStack();
    }
    notifyListeners();
  }

  /// Reading-order grid, newest card first at the top-left — the same
  /// priority order as the task list and as the stack's "newest on top".
  /// Past one full desk of cards, the grid restarts with a small diagonal
  /// offset per layer (deliberate overlap, same as the canvas example's
  /// seed grid) rather than escaping the canvas.
  void _positionTrayAsGrid() {
    const margin = kTrayArrangeMargin;
    final cellWidth = kCardSize.width + margin;
    final cellHeight = kCardSize.height + margin;
    final columns = math.max(1, ((canvasSize.width - margin) / cellWidth).floor());
    final rows = math.max(1, ((canvasSize.height - margin) / cellHeight).floor());
    final capacity = columns * rows;

    for (var i = 0; i < _tray.length; i++) {
      // _tray is oldest-first; slot 0 (top-left) goes to the newest.
      final gridIndex = _tray.length - 1 - i;
      final layer = gridIndex ~/ capacity;
      final slot = gridIndex % capacity;
      final row = slot ~/ columns;
      final col = slot % columns;
      _tray[i].position =
          Offset(margin + col * cellWidth, margin + row * cellHeight) + Offset(14.0 * layer, 14.0 * layer);
    }
  }

  void _positionTrayAsStack() {
    final base = _trayStackBase(_tray.length);
    final step = taskTrayStackStep(_tray.length);
    for (var i = 0; i < _tray.length; i++) {
      _tray[i].position = base + step * i.toDouble();
    }
  }

  @override
  List<SpatialEntity> getVisibleEntities(Rect viewport) {
    final trayVisible = _trayArranged || _tray.length <= kTaskTrayRenderCap
        ? _tray
        : _tray.sublist(_tray.length - kTaskTrayRenderCap);
    return [
      ..._spotlightRaisedPlaced(),
      ...trayVisible,
      ..._recentCompleted,
      for (final id in deskObjectIds)
        if (_placedDeskObjectIds.contains(id)) _deskObjectById(id),
    ];
  }

  /// [_placed], unless a tag is spotlit AND [_spotlightMatchIds] names some
  /// of them -- owner addendum 2026-08-06: a tagged card buried deep in a
  /// stack should be reachable without dragging a dozen other cards off it
  /// first. When active, the matching entities are wrapped in
  /// [_SpotlightRaisedEntity], which reports a synthetic [SpatialEntity
  /// .zIndex] but otherwise passes its id/position/rotation/size straight
  /// through -- [TaskSpatialEntity.zIndex] itself is never touched, so
  /// nothing here is persisted or mutated on the wrapped entity, and this
  /// method (called fresh on every canvas build, per [SpatialCanvas
  /// .getVisibleEntities]'s doc comment) simply stops wrapping the moment
  /// [_spotlitTag] goes null or [_spotlightMatchIds] empties -- an exact,
  /// automatic revert to normal z-order with no separate "restore" step.
  ///
  /// The raised group's zIndex values start one above the highest zIndex
  /// among its non-matching PLACED siblings, so the WHOLE group clears
  /// every other card in the same stack in one lift, never fighting each
  /// other for a single top slot: the owner explicitly ruled out "every
  /// matching card fights to be the single top card simultaneously" as a
  /// failure mode to avoid. Within the group, matches keep their OWN
  /// relative order (their pre-raise zIndex ascending, tied by id -- the
  /// same tie-break [SpatialCanvas]'s own sort uses) rather than sharing
  /// one zIndex, which would leave their mutual order to that id tie-break
  /// -- arbitrary, and unrelated to "newest on top" like the rest of this
  /// class's ordering.
  ///
  /// Deliberately does NOT reach for a ceiling above tray/done-pile cards
  /// or desk objects: those live in disjoint screen regions from the
  /// placed-card stack (the landing tray, the done pile, the amethyst's
  /// fixed spot), so their zIndex never actually overlaps a placed card
  /// on screen, and desk objects in particular are deliberately pinned to
  /// a very high zIndex ([kAmethystZIndex] et al) as an always-on-top
  /// "paperweight" -- outranking that would visually bury the amethyst
  /// under a raised card, which is not this feature's job to disturb.
  ///
  /// If every placed card already matches (no non-matching sibling to
  /// clear) or none do, this is a no-op: there's nothing to raise above.
  ///
  /// Scoped to [_placed] only, per owner spec: tray and done-pile cards are
  /// already exempt from the spotlight's ghost dimming (`CanvasScreen
  /// ._spotlightGhost`), so they stay exempt from the raise too.
  List<TaskSpatialEntity> _spotlightRaisedPlaced() {
    if (_spotlitTag == null || _spotlightMatchIds.isEmpty) return _placed;

    final matches = <TaskSpatialEntity>[];
    final rest = <TaskSpatialEntity>[];
    for (final entity in _placed) {
      (_spotlightMatchIds.contains(entity.id) ? matches : rest).add(entity);
    }
    if (matches.isEmpty || rest.isEmpty) return _placed;

    final ceiling = rest.map((e) => e.zIndex).reduce(math.max);

    matches.sort((a, b) {
      final byZ = a.zIndex.compareTo(b.zIndex);
      return byZ != 0 ? byZ : a.id.compareTo(b.id);
    });
    return [
      ...rest,
      for (final (i, entity) in matches.indexed) _SpotlightRaisedEntity(entity, ceiling + 1 + i),
    ];
  }

  @override
  void onEntityMoved(String id, Offset position, double rotation) {
    if (deskObjectIds.contains(id)) {
      _deskObjectById(id).position = position;
      notifyListeners();
      unawaited(_persistDeskObject(id));
      return;
    }
    final stackIndex = _recentCompleted.indexWhere((e) => e.id == id);
    if (stackIndex >= 0) {
      // The done pile is read-only: finished cards can't be placed. Re-lay
      // the pile (respecting its current stacked/fanned mode) and notify —
      // the dragged card snaps back — and persist nothing.
      _positionDonePile();
      notifyListeners();
      return;
    }
    final trayIndex = _tray.indexWhere((e) => e.id == id);
    final TaskSpatialEntity entity;
    if (trayIndex >= 0) {
      // Dragging a tray card places it: it leaves the (in-memory) tray for
      // good and gets a real persisted canvas position.
      entity = _tray.removeAt(trayIndex);
      _placed.add(entity);
    } else {
      entity = _placed.firstWhere((e) => e.id == id);
    }
    entity.position = position;
    notifyListeners();
    unawaited(_persist(id, position));
  }

  Future<void> _persist(String id, Offset position) async {
    try {
      await _taskService.updateTaskCanvasPosition(id, position.dx, position.dy);
    } catch (e) {
      debugPrint('TaskSpatialDataSource: failed to persist position for $id: $e');
    }
  }

  /// Completes [id]'s task from the desk (owner request 2026-08-06 — the
  /// highest-value slice of in-place editing: finishing a task no longer
  /// requires leaving the Spatial View for the main list). Reuses
  /// [TaskService.toggleTaskCompletion] for the actual write, AWAITED
  /// first — unlike [onEntityMoved]'s fire-and-forget optimistic update,
  /// completion is a one-way trip into the read-only done pile with no
  /// in-app undo (see class doc's "no undo needed, the done pile is the
  /// safety net"), so this favors correctness over instant local feedback:
  /// a failed write leaves the card exactly where it was rather than
  /// showing "done" without having actually persisted that.
  ///
  /// On success, the entity leaves [_placed]/[_tray] and joins
  /// [_recentCompleted] at [completedStackAnchor] as the newest (highest
  /// zIndex) member, evicting the oldest past [kRecentCompletedCount] —
  /// the same cap [_layout] enforces at construction, just applied
  /// incrementally instead of over the whole history at once. The done
  /// pile is then re-laid via [_positionDonePile] (respects whichever of
  /// stacked/fanned is current), and — if the card came from the tray — the
  /// tray is re-laid too (grid or stack, whichever is active), the same
  /// "don't leave a gap where the departed card sat" cleanup
  /// [_restoreCanvasPositions] already does for a tray card that graduates
  /// to [_placed] there.
  ///
  /// No-op if [id] doesn't name a currently placed/tray task entity —
  /// covers desk objects, an already-completed pile card, and unknown ids.
  /// `CanvasScreen`'s complete chip only ever fires this for a selected,
  /// not-yet-completed task card, but this stays defensive rather than
  /// trusting the caller.
  Future<void> completeTask(String id) async {
    final placedIndex = _placed.indexWhere((e) => e.id == id);
    final trayIndex = placedIndex >= 0 ? -1 : _tray.indexWhere((e) => e.id == id);
    final entity = placedIndex >= 0 ? _placed[placedIndex] : (trayIndex >= 0 ? _tray[trayIndex] : null);
    if (entity == null) return;

    final Task updatedTask;
    try {
      updatedTask = await _taskService.toggleTaskCompletion(entity.task);
    } catch (e) {
      debugPrint('TaskSpatialDataSource: failed to complete task $id: $e');
      return; // the write never landed -- leave the card exactly where it was
    }

    if (placedIndex >= 0) {
      _placed.removeAt(placedIndex);
    } else {
      _tray.removeAt(trayIndex);
    }

    _recentCompleted.add(
      TaskSpatialEntity(
        task: updatedTask,
        position: completedStackAnchor(canvasSize),
        zIndexOverride: _recentCompleted.isEmpty
            ? 0
            : _recentCompleted.map((e) => e.zIndex).reduce(math.max) + 1,
      ),
    );
    while (_recentCompleted.length > kRecentCompletedCount) {
      _recentCompleted.removeAt(0); // oldest drops off the pile, same as _layout's initial cap
    }
    _positionDonePile();

    if (trayIndex >= 0) {
      if (_trayArranged) {
        _positionTrayAsGrid();
      } else {
        _positionTrayAsStack();
      }
    }

    if (!_disposed) notifyListeners();
  }

  /// Owner bug report 2026-08-05 (phone APK): Spatial View → task list →
  /// back to Spatial View kept desk-object positions but lost card
  /// positions. Root cause was upstream of this class: [_layout] trusts the
  /// [Task] snapshot handed to the constructor (per its doc comment, "a
  /// one-time [Task] snapshot"), and that snapshot is `CanvasScreen`'s copy
  /// of `TaskProvider.tasks` — a cache [_persist] above has no handle on and
  /// never touches. `updateTaskTitle`/`updateTask` patch that cache's Task
  /// in place after their write; the canvas position write path never did,
  /// so TaskProvider kept serving the pre-drag (often still-`null`)
  /// canvas_x/canvas_y for that task on every subsequent screen build until
  /// something else forced a full `loadTasks()` (e.g. an app restart) — at
  /// which point [_layout] re-buckets the card into the tray as "unplaced",
  /// exactly the "lost" position the owner saw.
  ///
  /// Desk objects never had this failure mode because [_restoreDeskObjects]
  /// never trusts a snapshot at all: it re-reads the desk_objects table
  /// itself on every construction, straight from [_deskObjectService],
  /// independent of whatever `CanvasScreen`/`TaskProvider` passed in. This
  /// mirrors that pattern for cards instead of trying to keep
  /// `TaskProvider`'s cache honest (which `TaskSpatialDataSource` has no
  /// reference to, and per `task_spatial_entity.dart`'s doc comment,
  /// deliberately never mutates the wrapped [Task] anyway): re-read every
  /// task's canvas_x/canvas_y straight from SQLite via [_taskService] after
  /// [_layout] has already run against the (possibly stale) snapshot, and
  /// reconcile —
  /// - A [_placed] entity's position is refreshed to whatever the DB says
  ///   now, in case it drifted between the snapshot and this read landing.
  /// - A [_tray] entity that the fresh DB row shows a real position for was
  ///   only in the tray because the stale snapshot showed it unplaced; it
  ///   graduates to [_placed] at that position, and the remaining tray is
  ///   re-stacked (grid or stack, whichever mode is current) so it doesn't
  ///   leave a hole where the graduated card sat.
  /// Completed tasks are left alone entirely — the done pile's "never mixes
  /// with live work" invariant (see class doc) isn't this method's call to
  /// revisit, and a completed task can't reach here anyway ([_layout] never
  /// puts one in [_placed] or [_tray]).
  Future<void> _restoreCanvasPositions() async {
    try {
      final rows = await _taskService.getAllTasks();
      final byId = {for (final row in rows) row.id: row};
      var changed = false;

      for (final entity in _placed) {
        final fresh = byId[entity.id];
        final x = fresh?.canvasX;
        final y = fresh?.canvasY;
        if (fresh == null || fresh.completed || x == null || y == null) continue;
        final restored = Offset(x, y);
        if (entity.position != restored) {
          entity.position = restored;
          changed = true;
        }
      }

      final graduated = <TaskSpatialEntity>[];
      for (final entity in _tray) {
        final fresh = byId[entity.id];
        final x = fresh?.canvasX;
        final y = fresh?.canvasY;
        if (fresh == null || fresh.completed || x == null || y == null) continue;
        entity.position = Offset(x, y);
        graduated.add(entity);
      }
      if (graduated.isNotEmpty) {
        _tray.removeWhere(graduated.contains);
        _placed.addAll(graduated);
        // Re-lay the remaining tray in whatever mode it's currently in, so
        // the departed card(s) don't leave a gap in the stack/grid.
        if (_trayArranged) {
          _positionTrayAsGrid();
        } else {
          _positionTrayAsStack();
        }
        changed = true;
      }

      if (changed && !_disposed) notifyListeners();
    } catch (e) {
      // Same contract as the desk-objects/drawings restores: a failed read
      // means the snapshot's (possibly stale) positions stand, not a crash.
      debugPrint('TaskSpatialDataSource: canvas position restore skipped: $e');
    }
  }

  @override
  void onEntityDoubleTapped(String id) {
    if (deskObjectIds.contains(id)) {
      // Double-tap turns any sprite desk object to its next prerendered
      // rotation stop — the sprite-bundle counterpart of flipping a card.
      // (The gems rotate now too, as of habit_v1 — owner: "we can ROTATE
      // them!!")
      final entity = _deskObjectById(id);
      if (entity is DachshundDeskEntity) entity.stop = entity.stop.next;
      if (entity is GemDeskEntity) entity.stop = entity.stop.next;
      notifyListeners();
      unawaited(_persistDeskObject(id));
      return;
    }
    // Double-tapping during an override adopts what's on screen as the new
    // manual state first, then toggles the tapped card — so the rest of
    // the view doesn't jump back to pre-override faces mid-gesture.
    if (_flipViewMode != FlipViewMode.manual) _materializeFlipView();
    if (!_flippedIds.remove(id)) {
      _flippedIds.add(id);
    }
    notifyListeners();
  }

  /// Uniformly scales desk object [id] by [factor], growing/shrinking from
  /// its center (position compensates by half the size delta) so it doesn't
  /// appear to slide toward its own top-left corner. Width clamps and
  /// aspect are per kind (all square now that the whole shelf is sprite
  /// frames). Mins keep their original "small enough to tuck anywhere"
  /// values; the dachshund's bounds are BOX widths scaled with his widened
  /// frame.
  void resizeDeskObject(String id, double factor) {
    final entity = _deskObjectById(id);
    final (minWidth, maxWidth) = switch (id) {
      kDachshundDeskId => (112.0, 1176.0),
      _ => (90.0, 490.0),
    };
    final oldSize = entity.size;
    final newWidth = (oldSize.width * factor).clamp(minWidth, maxWidth);
    final newSize = Size(newWidth, newWidth);
    entity.position += Offset((oldSize.width - newSize.width) / 2, (oldSize.height - newSize.height) / 2);
    entity.size = newSize;
    notifyListeners();
    unawaited(_persistDeskObject(id));
  }

  /// Legacy name for the stone's resize — kept because the chips and
  /// existing tests grew up with it; new code should call
  /// [resizeDeskObject].
  void resizeAmethyst(double factor) => resizeDeskObject(kAmethystDeskId, factor);

  Future<void> _restoreDeskObjects() async {
    var amethystRestored = false;
    try {
      final rows = await _deskObjectService.getAll();
      for (final row in rows) {
        if (!deskObjectIds.contains(row.id)) continue; // future kinds: ignore
        final entity = _deskObjectById(row.id);
        if (row.placed) {
          _placedDeskObjectIds.add(row.id);
        } else {
          _placedDeskObjectIds.remove(row.id);
        }
        final x = row.x, y = row.y;
        if (x != null && y != null) entity.position = Offset(x, y);
        final width = row.width;
        // Square frames across the shelf (painted-era rows stored the same
        // width; their 0.8-aspect heights just become square on restore).
        if (width != null) entity.size = Size(width, width);
        if (row.id == kAmethystDeskId) amethystRestored = true;
        final stop = SpriteStop.values[row.variant.clamp(0, SpriteStop.values.length - 1)];
        if (entity is DachshundDeskEntity) entity.stop = stop;
        if (entity is GemDeskEntity) entity.stop = stop;
      }
    } catch (e) {
      // Same contract as the drawings load: a failed read means default
      // placement, not a crash.
      debugPrint('TaskSpatialDataSource: desk objects restore skipped: $e');
    }
    if (!amethystRestored) await _restoreAmethystFromLegacyPrefs();
    if (!_disposed) notifyListeners();
  }

  /// One-time upgrade path: no desk_objects row for the stone yet, so its
  /// pre-v15 SharedPreferences spot (if any) still speaks for it. No row is
  /// written here — the next move/resize/place writes one, and until then
  /// the prefs keep working.
  Future<void> _restoreAmethystFromLegacyPrefs() async {
    try {
      final amethyst = _gems[kAmethystDeskId]!;
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_kAmethystXKey);
      final y = prefs.getDouble(_kAmethystYKey);
      if (x != null && y != null) {
        amethyst.position = Offset(x, y);
      }
      final width = prefs.getDouble(_kAmethystWidthKey);
      if (width != null) {
        amethyst.size = Size(width, width);
      }
    } catch (e) {
      // No preferences backend (e.g. bare unit tests): the defaults stand.
      debugPrint('TaskSpatialDataSource: amethyst restore skipped: $e');
    }
  }

  Future<void> _persistDeskObject(String id) async {
    try {
      final entity = _deskObjectById(id);
      await _deskObjectService.save(
        id: id,
        placed: _placedDeskObjectIds.contains(id),
        x: entity.position.dx,
        y: entity.position.dy,
        width: entity.size.width,
        variant: switch (entity) {
          DachshundDeskEntity() => entity.stop.index,
          GemDeskEntity() => entity.stop.index,
          _ => 0,
        },
      );
    } catch (e) {
      debugPrint('TaskSpatialDataSource: failed to persist desk object $id: $e');
    }
  }
}

/// A transient stand-in for one placed [TaskSpatialEntity] that reports a
/// raised [zIndex] for the tag-tap spotlight's group-raise
/// ([TaskSpatialDataSource._spotlightRaisedPlaced]); every other property
/// (id, position, rotation, size) passes straight through, sourced from
/// [source] at construction time. Built fresh on every
/// [TaskSpatialDataSource.getVisibleEntities] call and never stored --
/// [source] itself is never touched, so this is purely a paint-order fact
/// for one frame, not a mutation. That's what makes the raise fully
/// reversible with no explicit "restore" path: once the spotlight clears
/// (or the tag switches, or its match set empties), [getVisibleEntities]
/// simply stops constructing these and callers see [source]'s own zIndex
/// again, unchanged.
class _SpotlightRaisedEntity extends TaskSpatialEntity {
  _SpotlightRaisedEntity(TaskSpatialEntity source, this._raisedZIndex)
    : super(task: source.task, position: source.position);

  final int _raisedZIndex;

  @override
  int get zIndex => _raisedZIndex;
}
