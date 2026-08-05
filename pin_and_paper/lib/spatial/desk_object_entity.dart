import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';

/// App-side contract shared by desk objects (amethyst, dachshund, ...):
/// a [SpatialEntity] whose position and size are mutable in place, so
/// `TaskSpatialDataSource` can move/resize any of them through one code
/// path. Also the dispatch type for "is this decor, not a card" checks
/// (e.g. suppressing the rounded-rect drag-lift shadow).
abstract class DeskObjectEntity implements SpatialEntity {
  set position(Offset value);
  set size(Size value);
}
