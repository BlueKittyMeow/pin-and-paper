import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';

import 'amethyst_desk_entity.dart' show kAmethystZIndex;
import 'desk_object_entity.dart';

/// The one dachshund figurine's fixed id (also its desk_objects row key).
const String kDachshundDeskId = 'desk-object-dachshund';

/// Same paperweight band as the amethyst ([kAmethystZIndex]), one higher so
/// the two desk objects have an explicit order instead of an id tie-break:
/// the pup sits on top of the stone if they ever overlap. Both stay far
/// above any card.
const int kDachshundZIndex = kAmethystZIndex + 1;

/// Default footprint. The sprite frames are square and — since the
/// final_v2_widened bundle — 1.75× wider than the dog needs, so his cast
/// shadow never clips (the frame is 0.224 m; he's 0.09 m of it). At the
/// manifest's true desk scale the box is 224 logical px (dog honest-tiny);
/// the default ships four resize-chip clicks bigger (× 1.15⁴ ≈ 392; owner
/// call 2026-08-04 on the VISUAL size, carried across the frame change so
/// the dog on screen is unchanged). The chips take him back to true scale
/// or beyond.
const Size kDachshundDefaultSize = Size(392, 392);

/// The marble longhaired dachshund figurine on the Spatial View desk — the
/// canvas module's [DachshundFigurine] sprite bundle hosted in the app.
///
/// Not a task: placement persists in the desk_objects table (DB v15) via
/// `TaskSpatialDataSource`. [stop] is the prerendered rotation stop shown,
/// cycled by double-tap (the sprite-bundle stand-in for the amethyst's
/// continuous mesh yaw); the 2D layout [rotation] stays 0 like every entity
/// in this MVP.
class DachshundDeskEntity implements DeskObjectEntity {
  DachshundDeskEntity({required this.position, this.size = kDachshundDefaultSize});

  @override
  final String id = kDachshundDeskId;

  @override
  Offset position;

  @override
  double get rotation => 0;

  /// Mutable: resized via the selection chips, same rules as the amethyst.
  @override
  Size size;

  /// Which of the seven prerendered rotation stops is showing.
  DachshundStop stop = DachshundStop.threeQLeft;

  @override
  int get zIndex => kDachshundZIndex;
}
