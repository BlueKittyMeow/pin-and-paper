import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';

import '../models/task.dart';
import '../services/task_service.dart';
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

/// Builds and owns the [TaskSpatialEntity] instances behind the Spatial
/// View's [SpatialCanvas] (DRAG_DROP_CANVAS_MVP_PLAN.md Milestone 4), from a
/// one-time [Task] snapshot.
///
/// Layout ([_layout], run once at construction):
/// - Tasks with a stored [Task.canvasX]/[Task.canvasY] render there.
/// - Tasks with no stored position ("unplaced") stack in the landing tray
///   (see [taskTrayAnchor]/[taskTrayStackStep]) instead of the plan's
///   original deterministic grid — M3/M4 addendum item 11. This stacking is
///   in-memory only: nothing is written to the database until the user
///   drags a card out of the tray (same "avoid N sync-log writes on first
///   open" rationale the plan gave for the grid it supersedes), so
///   unplaced cards re-stack identically every time the Spatial View
///   reopens, until placed.
///
/// [onEntityMoved] is the only write path: it updates the entity in place,
/// notifies listeners for an immediate re-render, and fires
/// [TaskService.updateTaskCanvasPosition] without awaiting it (errors are
/// logged, not surfaced — a failed persist just means the position doesn't
/// survive restart, not a crash).
class TaskSpatialDataSource extends SpatialDataSource {
  TaskSpatialDataSource({required List<Task> tasks, required TaskService taskService, required this.canvasSize})
    : _taskService = taskService,
      _entities = _layout(tasks, canvasSize);

  final TaskService _taskService;

  /// Canvas bounds this data source was laid out for.
  final Size canvasSize;

  final List<TaskSpatialEntity> _entities;

  /// Ids currently showing their `TaskCardBack` face. View-state, not task
  /// data (M3/M4 addendum item 1) — toggled by [onEntityDoubleTapped].
  final Set<String> _flippedIds = {};

  /// Whether [id]'s card is currently showing its back face.
  bool isFlipped(String id) => _flippedIds.contains(id);

  static List<TaskSpatialEntity> _layout(List<Task> tasks, Size canvasSize) {
    final entities = <TaskSpatialEntity>[];
    final unplaced = <Task>[];
    for (final task in tasks) {
      final x = task.canvasX;
      final y = task.canvasY;
      if (x != null && y != null) {
        entities.add(TaskSpatialEntity(task: task, position: Offset(x, y)));
      } else {
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
      entities.add(TaskSpatialEntity(task: unplaced[i], position: anchor + step * i.toDouble()));
    }
    return entities;
  }

  @override
  List<SpatialEntity> getVisibleEntities(Rect viewport) => _entities;

  @override
  void onEntityMoved(String id, Offset position, double rotation) {
    final entity = _entities.firstWhere((e) => e.id == id);
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
    if (!_flippedIds.remove(id)) {
      _flippedIds.add(id);
    }
    notifyListeners();
  }
}
