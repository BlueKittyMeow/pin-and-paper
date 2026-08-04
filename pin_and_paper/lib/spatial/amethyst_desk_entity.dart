import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';

/// The one amethyst desk object's fixed id.
const String kAmethystDeskId = 'desk-object-amethyst';

/// Paint order for the amethyst: far above any card's zIndex (cards use
/// `-Task.position`, whose magnitude grows one per created task — nowhere
/// near this), so the stone reads as a paperweight sitting ON the desk's
/// papers, never buried under them. The owner's first question after the
/// stone didn't appear was "was it buried under the other cards?" — this
/// constant is the standing answer: it can't be.
const int kAmethystZIndex = 1 << 20;

/// Default footprint, matching the canvas example's stone (150:120 aspect,
/// preserved by [TaskSpatialDataSource.resizeAmethyst]).
const Size kAmethystDefaultSize = Size(150, 120);

/// The amethyst chunk on the real Spatial View desk — the canvas module's
/// `AmethystChunk` desk object hosted in the main app (ported from the
/// canvas example per the M4 follow-up "amethyst → real app").
///
/// Not a task: position and size persist via `SharedPreferences` (see
/// `TaskSpatialDataSource`), never the tasks table. [rotationY] is the
/// crystal mesh's 3D yaw consumed by `AmethystChunkPainter` — fixed at the
/// base-aligned pose forever; the 2D layout [rotation] stays 0 like every
/// entity in this MVP.
class AmethystDeskEntity implements SpatialEntity {
  AmethystDeskEntity({required this.position, this.size = kAmethystDefaultSize});

  @override
  final String id = kAmethystDeskId;

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
  int get zIndex => kAmethystZIndex;
}
