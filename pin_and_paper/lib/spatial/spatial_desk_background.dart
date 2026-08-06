import 'package:flutter/material.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart' show kCardSize;

import 'task_spatial_data_source.dart'
    show donePileZoneRect, kTaskTrayZoneSize, taskTrayAnchor;

/// Amber gold used throughout the desk's dark-theme accent language.
const Color _kAccentGold = Color(0xFFC4941A);

/// The Spatial View's desk backdrop, passed as `SpatialCanvas.background`.
///
/// The desk is now a MODELED desk (Blender, bundle v1, 2026-08-05/06 —
/// see PIN_AND_PAPER_ASSET_HANDOFF.md in the dev harness): layered webp
/// renders sharing one camera contract. Bottom-up: the floor shadow
/// (rendered in the desk's own bent projection so the feet ground
/// physically), the desk itself, then a swappable desk-mat layer in the
/// same pixel frame. The canvas binds to the desk's inner cut-in panel;
/// the drawer band below the surface is pure decoration hanging over the
/// floor backdrop, so this widget's Stack must not clip.
///
/// Also here: subtle rounded outlines + labels for the landing tray zone
/// and the done pile (desk furniture, not decoration).
///
/// Purely decorative: `SpatialCanvas` already wraps `background` in
/// `IgnorePointer`, so this widget carries no state and never needs to
/// handle input itself.
/// Where the desk image sits relative to the canvas origin. The canvas IS
/// the desk's inner cut-in panel, which lives at (152.5, 152.5) in the
/// asset — so the image is offset up-left by that much, letting the
/// wooden rim, bevel, and drawer band surround the interactive surface as
/// pure decoration. Tied to the bundle's camera contract (manifest.json:
/// panel_rect).
const Offset kDeskImageOffset = Offset(-152.5, -152.5);

/// Full pixel size of `desk_modeled.webp` (and the mat layers, which
/// share its frame); displayed 1:1 in canvas logical px.
const Size kDeskImageSize = Size(2128, 2992);

/// The floor-shadow layer's frame: the desk frame padded 384px on every
/// side (same camera, wider crop), so it anchors at
/// `kDeskImageOffset − (384, 384)`. Contract from bundle v1 manifest.
const double kDeskShadowPadding = 384;

/// Full pixel size of `shadow_floor.webp`.
const Size kDeskShadowSize = Size(2896, 3760);

/// Shadow strength against the floor backdrop — same read as the app's
/// prop shadows (~40% per the handoff; tune with owner on device).
const double kDeskShadowOpacity = 0.40;

/// The swappable desk mats, keyed by variant name — each a full-frame
/// layer composited over the desk at the same position (no offset math).
/// Future: settings/unlockable UI picks the variant ("change desk pads"
/// pipeline); new variants come from one `--mat <name>` farm render.
const Map<String, String> kDeskMatAssets = {
  'greenfelt': 'assets/images/spatial/mat_greenfelt.webp',
};

/// The currently active mat variant (compile-time until the mat-picker UI
/// exists).
const String kActiveDeskMat = 'greenfelt';

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
        // Floor shadow FIRST (under the desk). It pans with the desk —
        // anchored to it, not to the screen-space floor backdrop — and
        // shares the desk's projection, so the feet land exactly where
        // they visually stand.
        Positioned(
          left: kDeskImageOffset.dx - kDeskShadowPadding,
          top: kDeskImageOffset.dy - kDeskShadowPadding,
          width: kDeskShadowSize.width,
          height: kDeskShadowSize.height,
          child: Opacity(
            opacity: kDeskShadowOpacity,
            child: Image.asset(
              'assets/images/spatial/shadow_floor.webp',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        Positioned(
          left: kDeskImageOffset.dx,
          top: kDeskImageOffset.dy,
          width: kDeskImageSize.width,
          height: kDeskImageSize.height,
          child: Image.asset(
            'assets/images/spatial/desk_modeled.webp',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
        // The desk mat: same pixel frame as the desk, stacked over it.
        Positioned(
          left: kDeskImageOffset.dx,
          top: kDeskImageOffset.dy,
          width: kDeskImageSize.width,
          height: kDeskImageSize.height,
          child: Image.asset(
            kDeskMatAssets[kActiveDeskMat]!,
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
