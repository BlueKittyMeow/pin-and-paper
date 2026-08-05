import 'package:flutter/material.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart' show kCardSize;

import 'task_spatial_data_source.dart'
    show donePileZoneRect, kTaskTrayZoneSize, taskTrayAnchor;

/// Amber gold used throughout the desk's dark-theme accent language.
const Color _kAccentGold = Color(0xFFC4941A);

/// The Spatial View's desk backdrop, passed as `SpatialCanvas.background`.
///
/// The desk is now a REAL desk (owner-sourced executive desk photo,
/// 2026-08-05): the mahogany top surface is perspective-squared so it maps
/// EXACTLY onto the 2000×1500 canvas rect — cards sit on the actual
/// desktop — while the drawer pedestals stay visible below the canvas
/// bounds as pure decoration (never interactive; they hang in the felt
/// margin over the floor backdrop). The asset carries [kDeskImageMargin]
/// px of feathered-alpha glow on all sides, so this widget positions it
/// offset beyond the canvas rect and its Stack must not clip.
///
/// Also here: subtle rounded outlines + labels for the landing tray zone
/// and the done pile (desk furniture, not decoration).
///
/// Purely decorative: `SpatialCanvas` already wraps `background` in
/// `IgnorePointer`, so this widget carries no state and never needs to
/// handle input itself.
/// Where the desk image sits relative to the canvas origin. The canvas IS
/// the desk's inner bevel panel (owner decision 2026-08-05), which lives
/// at (154,187) in the asset — so the image is offset up-left by that
/// much, letting the wooden rim, bevel, and drawer pedestals surround the
/// interactive surface as pure decoration. Tied to the asset-generation
/// measurements (groove rect + 5px inset).
const Offset kDeskImageOffset = Offset(-154, -187);

/// Full pixel size of `desk_executive.webp` — the whole desk plus its
/// feathered glow margin; displayed 1:1 in canvas logical px.
const Size kDeskImageSize = Size(2128, 2264);

class SpatialDeskBackground extends StatelessWidget {
  const SpatialDeskBackground({super.key, required this.canvasSize});

  /// Must match the `SpatialCanvas.canvasSize` this background is painted
  /// for, so the tray outline lines up with `TaskSpatialDataSource`'s own
  /// [taskTrayAnchor] computation.
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final trayAnchor = taskTrayAnchor(canvasSize);
    // Symmetric margins so the resting base card sits CENTERED in the
    // outline (owner report 2026-08-04: the stack read as shoved into a
    // corner of its box); the fan then grows down-right from center.
    final trayPadding = EdgeInsets.only(
      left: (kTaskTrayZoneSize.width - kCardSize.width) / 2,
      top: (kTaskTrayZoneSize.height - kCardSize.height) / 2,
    );
    final doneRect = donePileZoneRect(canvasSize);

    return Stack(
      // The desk image intentionally overflows the canvas rect (glow
      // margins + drawer pedestals below); the canvas's own Stack is
      // already Clip.none.
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: kDeskImageOffset.dx,
          top: kDeskImageOffset.dy,
          width: kDeskImageSize.width,
          height: kDeskImageSize.height,
          child: Image.asset(
            'assets/images/spatial/desk_executive.webp',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
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
                child: _ZoneLabel('NEW'),
              ),
            ),
          ),
        ),
        // Done-pile furniture, the tray's mirror twin (owner request
        // 2026-08-04). The data source treats felt taps inside this rect
        // as the fan/restack toggle — the visual affordance is this box +
        // label; the hit-testing lives in TaskSpatialDataSource
        // .onCanvasTapped, since the background itself is IgnorePointer'd.
        Positioned(
          left: doneRect.left,
          top: doneRect.top,
          width: doneRect.width,
          height: doneRect.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _kAccentGold.withAlpha(90), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _ZoneLabel('RECENTLY COMPLETED'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _kAccentGold.withAlpha(150),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}
