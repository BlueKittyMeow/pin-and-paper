import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart' show kCardSize;

import '../models/task.dart';

/// Wraps a [Task] as a [SpatialEntity] for the Spatial View's [SpatialCanvas]
/// (DRAG_DROP_CANVAS_MVP_PLAN.md Milestone 4).
///
/// [task] is an immutable snapshot captured when the Spatial View opened
/// (`CanvasScreen`'s job) — this class does not refresh it. [position] is
/// session-mutable state, separate from [Task.canvasX]/[Task.canvasY]:
/// dragging updates this entity's [position] (for immediate re-render) and
/// fires [TaskSpatialDataSource]'s persistence write, but the wrapped [task]
/// object itself is never mutated. Reopening the Spatial View builds a fresh
/// snapshot from whatever got persisted, per the plan's accepted
/// "canvas is a snapshot" POC limitation.
class TaskSpatialEntity implements SpatialEntity {
  TaskSpatialEntity({required this.task, required Offset position}) : _position = position;

  /// The wrapped task.
  final Task task;

  Offset _position;

  @override
  String get id => task.id;

  @override
  Offset get position => _position;

  /// Written by [TaskSpatialDataSource.onEntityMoved] when the user drags
  /// this card. See the class doc comment for why this is deliberately not
  /// mirrored back onto [task].
  set position(Offset value) => _position = value;

  /// No rotation gesture in this MVP milestone; always upright.
  @override
  double get rotation => 0;

  /// Matches the card renderer's tuned footprint rather than a hardcoded
  /// literal, per M3/M4 addendum item 4.
  @override
  Size get size => kCardSize;

  /// Newest task on top. M3/M4 addendum item 5: `Task.position` grows
  /// *negative* for new top-level tasks (new-task-top-insert), so negating
  /// it keeps "newest = highest zIndex" true — using `task.position` as-is
  /// would stack new cards at the bottom of any overlap instead.
  @override
  int get zIndex => -task.position;
}
