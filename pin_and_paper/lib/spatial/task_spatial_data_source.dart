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
    initialized = Future.wait([_restoreDeskObjects(), _loadDrawings()]);
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

  bool _donePileFanned = false;

  /// Whether the done pile is currently fanned down the right edge (true)
  /// or stacked in its zone (false). Toggled by tapping the pile's outline
  /// box on empty felt (see [onCanvasTapped]).
  bool get donePileFanned => _donePileFanned;

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
    if (_donePileFanned) {
      const margin = 40.0;
      final x = canvasSize.width - kCardSize.width - margin;
      final top = completedStackAnchor(canvasSize).dy;
      // The fan must stop short of the landing tray's corner (owner
      // screenshot 2026-08-04 night: a 10-card fan ran straight into the
      // inbox stack).
      final bottomLimit = taskTrayAnchor(canvasSize).dy - kCardSize.height - 24;
      final n = _recentCompleted.length;
      final availableHeight = math.max(0.0, bottomLimit - top);
      // Floor of kCardSize.height (never overlap at all), capped above by
      // the old "don't spread wastefully thin" ceiling. Below the floor,
      // the card above starts shingling over the TOP of the card below —
      // exactly where its accent bar and title sit — not just its
      // tags/date footer (owner report 2026-08-06, phone APK: at the app's
      // real desk-panel canvas size a full kRecentCompletedCount pile
      // squeezed naive `availableHeight / (n - 1)` spacing to ~123px,
      // 17px short of a card's 140px height, clipping the title of every
      // card but the topmost). This didn't show up against this file's own
      // unit tests' more generous canvas fixture — see
      // task_spatial_data_source_test.dart's cramped-canvas regression
      // case, added alongside this fix.
      final spacing = n <= 1
          ? 0.0
          : math.max(kCardSize.height, math.min(kCardSize.height + 16.0, availableHeight / (n - 1)));
      // How many cards one column holds at that floor before running past
      // the tray corner; the rest wrap into a second column just to the
      // left rather than crowd — the same "add a column instead of
      // shrinking" escape valve the landing tray's arrange grid uses for a
      // deep inbox ([_positionTrayAsGrid]'s `layer`).
      final perColumn = spacing <= 0 ? n : math.max(1, (availableHeight / spacing).floor() + 1);
      // _recentCompleted is oldest-first; the newest takes the top slot of
      // the first column.
      for (var i = 0; i < n; i++) {
        final fanIndex = n - 1 - i;
        final column = fanIndex ~/ perColumn;
        final slot = fanIndex % perColumn;
        _recentCompleted[i].position =
            Offset(x - (kCardSize.width + 16.0) * column, top + spacing * slot);
      }
    } else {
      for (var i = 0; i < _recentCompleted.length; i++) {
        _recentCompleted[i].position =
            completedStackAnchor(canvasSize) + kTaskTrayBaseStep * i.toDouble();
      }
    }
  }

  @override
  void onCanvasTapped(Offset position) {
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
  /// been applied. Awaited by tests; the app lets it land whenever it lands
  /// (a frame or two after first paint, via notifyListeners).
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
      ..._placed,
      ...trayVisible,
      ..._recentCompleted,
      for (final id in deskObjectIds)
        if (_placedDeskObjectIds.contains(id)) _deskObjectById(id),
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
