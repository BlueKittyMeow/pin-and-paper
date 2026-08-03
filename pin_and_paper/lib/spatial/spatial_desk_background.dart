import 'package:flutter/material.dart';

import 'task_spatial_data_source.dart' show kTaskTrayZoneSize, taskTrayAnchor;

/// Amber gold used throughout the desk's dark-theme accent language.
const Color _kAccentGold = Color(0xFFC4941A);

/// The Spatial View's desk backdrop, passed as `SpatialCanvas.background`.
///
/// Two things live here (M3/M4 addendum item 3 and item 11):
/// - The desk surface itself: Lara's seamless kraft-paper texture, tiled to
///   [canvasSize], framed by a thin amber edge marking exactly where the
///   usable canvas ends — mirrors the canvas module's own `example/` app.
/// - A subtle rounded outline around the landing tray zone (where unplaced
///   tasks stack — see `TaskSpatialDataSource`'s doc comment) plus a small
///   "NEW" label, so the tray reads as desk furniture, not decoration.
///
/// Purely decorative: `SpatialCanvas` already wraps `background` in
/// `IgnorePointer`, so this widget carries no state and never needs to
/// handle input itself.
class SpatialDeskBackground extends StatelessWidget {
  const SpatialDeskBackground({super.key, required this.canvasSize});

  /// Must match the `SpatialCanvas.canvasSize` this background is painted
  /// for, so the tray outline lines up with `TaskSpatialDataSource`'s own
  /// [taskTrayAnchor] computation.
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final trayAnchor = taskTrayAnchor(canvasSize);
    // A little padding around the anchor so the outline comfortably
    // contains the stack's fan-out, not just the anchor point itself.
    const trayPadding = EdgeInsets.only(left: 24, top: 34);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/spatial/SeamlessKraft1.jpg'),
                repeat: ImageRepeat.repeat,
              ),
              border: Border.all(color: _kAccentGold, width: 2),
            ),
          ),
        ),
        Positioned(
          left: trayAnchor.dx - trayPadding.left,
          top: trayAnchor.dy - trayPadding.top,
          width: kTaskTrayZoneSize.width,
          height: kTaskTrayZoneSize.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _kAccentGold.withAlpha(90), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _TrayLabel(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrayLabel extends StatelessWidget {
  const _TrayLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'NEW',
      style: TextStyle(
        color: _kAccentGold.withAlpha(150),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}
