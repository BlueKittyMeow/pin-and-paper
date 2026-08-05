import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';

import 'desk_object_entity.dart';

/// The one amethyst desk object's fixed id.
const String kAmethystDeskId = 'desk-object-amethyst';

// The amethyst's recolored siblings (2026-08-04: drawer roster variants for
// behavior testing — same painter, hue-rotated).
const String kCitrineDeskId = 'desk-object-citrine';
const String kRoseQuartzDeskId = 'desk-object-rose-quartz';
const String kFluoriteDeskId = 'desk-object-fluorite';

/// Painter hue rotation per crystal kind, in degrees. The reference painter
/// lives around ~272° purple; the shifts land citrine at golden ~46°, rose
/// quartz at pink ~340°, and fluorite at green ~142°. Iteration order is
/// also the drawer's crystal listing order.
const Map<String, double> kCrystalHueShifts = {
  kAmethystDeskId: 0,
  kCitrineDeskId: 134,
  kRoseQuartzDeskId: 68,
  kFluoriteDeskId: -130,
};

/// Paint order for the amethyst: far above any card's zIndex (cards use
/// `-Task.position`, whose magnitude grows one per created task — nowhere
/// near this), so the stone reads as a paperweight sitting ON the desk's
/// papers, never buried under them. The owner's first question after the
/// stone didn't appear was "was it buried under the other cards?" — this
/// constant is the standing answer: it can't be.
const int kAmethystZIndex = 1 << 20;

/// Default footprint: the canvas example's 150:120 stone scaled up four
/// resize-chip clicks (× 1.15⁴ ≈ 262; owner call 2026-08-04 — desk-object
/// defaults were reading too small). Aspect stays 5:4, preserved by
/// [TaskSpatialDataSource.resizeDeskObject].
const Size kAmethystDefaultSize = Size(262, 209.6);

/// A crystal chunk on the real Spatial View desk — the canvas module's
/// `AmethystChunk` painter hosted in the main app (ported from the canvas
/// example per the M4 follow-up "amethyst → real app"). One class serves
/// the whole mineral shelf: [id] selects the kind and [hueShift] (looked up
/// from [kCrystalHueShifts]) recolors the same painted stone into citrine,
/// rose quartz, or fluorite.
///
/// Not a task: placement persists in the desk_objects table (see
/// `TaskSpatialDataSource`), never the tasks table. [rotationY] is the
/// crystal mesh's 3D yaw consumed by `AmethystChunkPainter` — fixed at the
/// base-aligned pose forever; the 2D layout [rotation] stays 0 like every
/// entity in this MVP.
class AmethystDeskEntity implements DeskObjectEntity {
  AmethystDeskEntity({
    required this.position,
    this.size = kAmethystDefaultSize,
    this.id = kAmethystDeskId,
    this.zIndex = kAmethystZIndex,
  });

  @override
  final String id;

  /// Painter hue rotation for this kind (0 = amethyst).
  double get hueShift => kCrystalHueShifts[id] ?? 0;

  @override
  Offset position;

  @override
  double get rotation => 0;

  /// The crystal mesh's fixed yaw: bottom edge projects flat, so the stone
  /// rests flush on the flat-lay desk.
  final double rotationY = AmethystChunkMesh.baseAlignedYaw;

  /// Mutable: resized via the selection chips. Decor gets to be whatever
  /// size sparks joy; cards stay fixed-size.
  @override
  Size size;

  @override
  final int zIndex;
}
