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

/// Default footprint. The sprite frames are square; 128 logical px is the
/// bundle manifest's true-scale display size (768px render at effective
/// 6000 px/m, `ppm_multiplier: 2` → half scale on the desk's global
/// 3000 px/m). That's honest for a 9 cm figurine but genuinely small next
/// to the cards — the resize chips exist so the owner can size him by eye.
const Size kDachshundDefaultSize = Size(128, 128);

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
