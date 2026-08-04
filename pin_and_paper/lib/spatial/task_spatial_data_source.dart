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
import '../services/drawing_service.dart';
import '../services/task_service.dart';
import 'amethyst_desk_entity.dart';
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
const int kRecentCompletedCount = 10;

/// Top-left anchor of the recently-completed stack: upper-right of the
/// desk, mirroring the landing tray's lower-right inbox — glanceable, out
/// of the way of live work.
Offset completedStackAnchor(Size canvasSize) => Offset(canvasSize.width - 300, 80);

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
/// snapshot, plus the one [AmethystDeskEntity] desk object.
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
/// survive restart, not a crash). The amethyst persists its position/size
/// via [SharedPreferences] instead — it's decor, not a task.
class TaskSpatialDataSource extends SpatialDataSource {
  TaskSpatialDataSource({
    required List<Task> tasks,
    required TaskService taskService,
    required this.canvasSize,
    DrawingService? drawingService,
  }) : _taskService = taskService,
      _drawingService = drawingService ?? DrawingService(),
      _amethyst = AmethystDeskEntity(
        // Dead center of the desk by default — the stone must be
        // unmissable on first open (its example-app ancestor tucked itself
        // into a corner and the owner assumed it was buried). Dragging it
        // persists wherever it lands.
        position: Offset(
          (canvasSize.width - kAmethystDefaultSize.width) / 2,
          (canvasSize.height - kAmethystDefaultSize.height) / 2,
        ),
      ) {
    _layout(tasks);
    initialized = Future.wait([_restoreAmethyst(), _loadDrawings()]);
  }

  final TaskService _taskService;
  final DrawingService _drawingService;

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

  final AmethystDeskEntity _amethyst;

  bool _trayArranged = false;

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
      if (all.isNotEmpty) notifyListeners();
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

  // -- Amethyst persistence (SharedPreferences — decor, not task data) ----
  static const _kAmethystXKey = 'spatial_amethyst_x';
  static const _kAmethystYKey = 'spatial_amethyst_y';
  static const _kAmethystWidthKey = 'spatial_amethyst_width';

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
    final anchor = taskTrayAnchor(canvasSize);
    final step = taskTrayStackStep(unplaced.length);
    for (var i = 0; i < unplaced.length; i++) {
      _tray.add(TaskSpatialEntity(task: unplaced[i], position: anchor + step * i.toDouble()));
    }
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
    final anchor = taskTrayAnchor(canvasSize);
    final step = taskTrayStackStep(_tray.length);
    for (var i = 0; i < _tray.length; i++) {
      _tray[i].position = anchor + step * i.toDouble();
    }
  }

  @override
  List<SpatialEntity> getVisibleEntities(Rect viewport) {
    final trayVisible = _trayArranged || _tray.length <= kTaskTrayRenderCap
        ? _tray
        : _tray.sublist(_tray.length - kTaskTrayRenderCap);
    return [..._placed, ...trayVisible, ..._recentCompleted, _amethyst];
  }

  @override
  void onEntityMoved(String id, Offset position, double rotation) {
    if (id == kAmethystDeskId) {
      _amethyst.position = position;
      notifyListeners();
      unawaited(_persistAmethyst());
      return;
    }
    final stackIndex = _recentCompleted.indexWhere((e) => e.id == id);
    if (stackIndex >= 0) {
      // The done pile is read-only: finished cards can't be placed. Re-fan
      // the pile and notify — the dragged card snaps back — and persist
      // nothing.
      for (var i = 0; i < _recentCompleted.length; i++) {
        _recentCompleted[i].position = completedStackAnchor(canvasSize) + kTaskTrayBaseStep * i.toDouble();
      }
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
    if (id == kAmethystDeskId) return; // the stone has no back face
    // Double-tapping during an override adopts what's on screen as the new
    // manual state first, then toggles the tapped card — so the rest of
    // the view doesn't jump back to pre-override faces mid-gesture.
    if (_flipViewMode != FlipViewMode.manual) _materializeFlipView();
    if (!_flippedIds.remove(id)) {
      _flippedIds.add(id);
    }
    notifyListeners();
  }

  /// Uniformly scales the amethyst by [factor], growing/shrinking from its
  /// center (position compensates by half the size delta) so it doesn't
  /// appear to slide toward its own top-left corner. Width clamped to
  /// [90, 280] with the 150:120 aspect preserved — same rules as the canvas
  /// example it was ported from.
  void resizeAmethyst(double factor) {
    final oldSize = _amethyst.size;
    final newWidth = (oldSize.width * factor).clamp(90.0, 280.0);
    final newSize = Size(newWidth, newWidth * (kAmethystDefaultSize.height / kAmethystDefaultSize.width));
    _amethyst.position += Offset((oldSize.width - newSize.width) / 2, (oldSize.height - newSize.height) / 2);
    _amethyst.size = newSize;
    notifyListeners();
    unawaited(_persistAmethyst());
  }

  Future<void> _restoreAmethyst() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_kAmethystXKey);
      final y = prefs.getDouble(_kAmethystYKey);
      if (x != null && y != null) {
        _amethyst.position = Offset(x, y);
      }
      final width = prefs.getDouble(_kAmethystWidthKey);
      if (width != null) {
        _amethyst.size = Size(width, width * (kAmethystDefaultSize.height / kAmethystDefaultSize.width));
      }
      notifyListeners();
    } catch (e) {
      // No preferences backend (e.g. bare unit tests): the defaults stand.
      debugPrint('TaskSpatialDataSource: amethyst restore skipped: $e');
    }
  }

  Future<void> _persistAmethyst() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kAmethystXKey, _amethyst.position.dx);
      await prefs.setDouble(_kAmethystYKey, _amethyst.position.dy);
      await prefs.setDouble(_kAmethystWidthKey, _amethyst.size.width);
    } catch (e) {
      debugPrint('TaskSpatialDataSource: failed to persist amethyst: $e');
    }
  }
}
