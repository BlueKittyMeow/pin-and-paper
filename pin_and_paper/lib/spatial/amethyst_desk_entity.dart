import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:pin_and_paper_canvas/spatial_canvas.dart';

import 'desk_object_entity.dart';

/// Fixed desk-object ids for the mineral shelf. The first four predate the
/// modeled gems (they were painted `AmethystChunk` hue-shift variants
/// until 2026-08-05) and KEEP their ids so existing desk_objects rows —
/// placement, size, drawer state — carry across the upgrade untouched.
const String kAmethystDeskId = 'desk-object-amethyst';
const String kCitrineDeskId = 'desk-object-citrine';
const String kRoseQuartzDeskId = 'desk-object-rose-quartz';
const String kFluoriteDeskId = 'desk-object-fluorite';

/// The drawer's fifth mineral, new with the habit_v1 bundle.
const String kObsidianDeskId = 'desk-object-obsidian';

/// Which modeled habit-bundle variant renders for each gem id. Iteration
/// order is also the drawer's mineral-shelf listing order.
const Map<String, GemVariant> kGemVariantsById = {
  kAmethystDeskId: GemVariant.amethyst,
  kCitrineDeskId: GemVariant.citrine,
  kRoseQuartzDeskId: GemVariant.roseQuartz,
  kFluoriteDeskId: GemVariant.fluorite,
  kObsidianDeskId: GemVariant.snowflakeObsidian,
};

/// Paint order for the mineral shelf's base: far above any card's zIndex
/// (cards use `-Task.position`) so stones read as paperweights sitting ON
/// the papers, never buried under them. (Name kept from the painted-stone
/// era; the dachshund's zIndex derives from it.)
const int kAmethystZIndex = 1 << 20;

/// Default footprint (square — the sprite frames are square). Carried
/// over from the painted stone's owner-approved 4-click width; manifest
/// true desk scale would be a 160px box (0.16 m frame, ppm_multiplier 2),
/// so this default shows the stones comfortably larger than life, and the
/// resize chips go both ways.
const Size kAmethystDefaultSize = Size(262, 262);

/// A modeled gem/mineral on the Spatial View desk — the canvas module's
/// [GemFigurine] habit_v1 sprites hosted in the app. One class serves the
/// whole shelf: [id] selects the kind, [variant] the sprite set. Replaces
/// the painted `AmethystChunk` stones (2026-08-05); the painter survives
/// in the canvas module, earmarked for an easter-egg return.
///
/// Not a task: placement persists in the desk_objects table; [stop] (the
/// prerendered rotation pose, cycled by double-tap like the dachshund's)
/// persists in the row's `variant` column. The 2D layout [rotation] stays
/// 0 like every entity in this MVP.
class GemDeskEntity implements DeskObjectEntity {
  GemDeskEntity({
    required this.position,
    required this.id,
    this.size = kAmethystDefaultSize,
    this.zIndex = kAmethystZIndex,
  });

  @override
  final String id;

  /// The habit-bundle sprite set for this kind.
  GemVariant get variant => kGemVariantsById[id]!;

  @override
  Offset position;

  @override
  double get rotation => 0;

  /// Which of the seven prerendered rotation stops is showing.
  SpriteStop stop = SpriteStop.threeQLeft;

  /// Mutable: resized via the selection chips. Decor gets to be whatever
  /// size sparks joy; cards stay fixed-size.
  @override
  Size size;

  @override
  final int zIndex;
}
