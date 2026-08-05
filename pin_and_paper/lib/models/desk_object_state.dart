/// One desk object's persisted state (desk_objects table, DB v15) — one row
/// per knick-knack KIND, keyed by its fixed entity id
/// ('desk-object-amethyst', 'desk-object-dachshund', ...).
///
/// `placed` is what the drawer reads: a placed object shows ghosted in the
/// drawer and lives on the desk; an unplaced one sits in the drawer at full
/// opacity, keeping its last x/y/width/variant so putting it back on the
/// desk restores it exactly as it left.
class DeskObjectState {
  DeskObjectState({
    required this.id,
    required this.placed,
    this.x,
    this.y,
    this.width,
    this.variant = 0,
  });

  final String id;
  final bool placed;

  /// Canvas position of the object's top-left corner; null until first
  /// placed/moved (callers fall back to their kind's default spot).
  final double? x;
  final double? y;

  /// Display width; height derives from the kind's aspect. Null = default.
  final double? width;

  /// Small per-kind pose integer — the dachshund's rotation-stop index;
  /// unused (0) by the amethyst.
  final int variant;

  factory DeskObjectState.fromMap(Map<String, dynamic> map) => DeskObjectState(
        id: map['id'] as String,
        placed: (map['placed'] as int) != 0,
        x: map['x'] as double?,
        y: map['y'] as double?,
        width: map['width'] as double?,
        variant: (map['variant'] as int?) ?? 0,
      );
}
