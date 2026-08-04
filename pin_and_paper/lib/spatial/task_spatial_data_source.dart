import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart' show kCardSize;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
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
/// - Tasks with a stored [Task.canvasX]/[Task.canvasY] render there.
/// - Completed tasks with no stored position are omitted entirely: the tray
///   is an inbox of work waiting to be placed, and a finished task has no
///   business queuing in it. (A completed task the user has placed on the
///   desk still renders at its stored position — deliberate placement wins —
///   unless the persisted [hideCompletedPlaced] pref tucks it away.)
/// - Remaining tasks with no stored position ("unplaced") stack in the
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
  TaskSpatialDataSource({required List<Task> tasks, required TaskService taskService, required this.canvasSize})
    : _taskService = taskService,
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
    initialized = _restorePrefs();
  }

  final TaskService _taskService;

  /// Canvas bounds this data source was laid out for.
  final Size canvasSize;

  /// Tasks with a stored canvas position, rendered exactly there.
  final List<TaskSpatialEntity> _placed = [];

  /// Unplaced (tray) tasks, oldest first, holding their current in-memory
  /// positions (stacked or arranged). Dragging one moves it to [_placed].
  final List<TaskSpatialEntity> _tray = [];

  final AmethystDeskEntity _amethyst;

  bool _trayArranged = false;

  /// Whether the tray is currently spread out as a grid (true) or stacked
  /// in the landing tray (false). Toggled by [setTrayArranged].
  bool get trayArranged => _trayArranged;

  bool _hideCompletedPlaced = false;

  /// Whether placed completed cards are hidden from the desk. Unlike the
  /// tray's unconditional completed-task exclusion, placed cards were put
  /// there deliberately, so hiding them is the user's call — persisted
  /// across sessions under [kHideCompletedPlacedKey] (default: shown).
  bool get hideCompletedPlaced => _hideCompletedPlaced;

  /// Toggle [hideCompletedPlaced]. View-state only: the hidden cards keep
  /// their stored canvas positions and reappear exactly where they were.
  void setHideCompletedPlaced(bool hide) {
    if (hide == _hideCompletedPlaced) return;
    _hideCompletedPlaced = hide;
    notifyListeners();
    unawaited(_persistHideCompletedPlaced());
  }

  /// Completes when persisted view prefs have been applied: the amethyst's
  /// position/size and [hideCompletedPlaced]. Awaited by tests; the app
  /// lets it land whenever it lands (a frame or two after first paint, via
  /// notifyListeners).
  late final Future<void> initialized;

  /// Ids currently showing their `TaskCardBack` face. View-state, not task
  /// data (M3/M4 addendum item 1) — toggled by [onEntityDoubleTapped].
  final Set<String> _flippedIds = {};

  /// Whether [id]'s card is currently showing its back face.
  bool isFlipped(String id) => _flippedIds.contains(id);

  // -- View prefs (SharedPreferences — view-state, not task data) ---------
  static const _kAmethystXKey = 'spatial_amethyst_x';
  static const _kAmethystYKey = 'spatial_amethyst_y';
  static const _kAmethystWidthKey = 'spatial_amethyst_width';

  /// SharedPreferences key backing [hideCompletedPlaced]. Public so tests
  /// can seed/inspect it.
  static const kHideCompletedPlacedKey = 'spatial_hide_completed_placed';

  void _layout(List<Task> tasks) {
    final unplaced = <Task>[];
    for (final task in tasks) {
      final x = task.canvasX;
      final y = task.canvasY;
      if (x != null && y != null) {
        _placed.add(TaskSpatialEntity(task: task, position: Offset(x, y)));
      } else if (!task.completed) {
        unplaced.add(task);
      }
    }

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
    final placedVisible = _hideCompletedPlaced ? _placed.where((e) => !e.task.completed) : _placed;
    return [...placedVisible, ...trayVisible, _amethyst];
  }

  @override
  void onEntityMoved(String id, Offset position, double rotation) {
    if (id == kAmethystDeskId) {
      _amethyst.position = position;
      notifyListeners();
      unawaited(_persistAmethyst());
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

  Future<void> _restorePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hideCompletedPlaced = prefs.getBool(kHideCompletedPlacedKey) ?? false;
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
      debugPrint('TaskSpatialDataSource: view-pref restore skipped: $e');
    }
  }

  Future<void> _persistHideCompletedPlaced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHideCompletedPlacedKey, _hideCompletedPlaced);
    } catch (e) {
      debugPrint('TaskSpatialDataSource: failed to persist hide-completed pref: $e');
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
