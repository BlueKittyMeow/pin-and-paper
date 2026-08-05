import 'package:flutter/material.dart';

/// Named UI colors for the Spatial View desk (owner directive L10,
/// CARD_DRAWINGS_PLAN.md): define colors as named constants so the app can
/// be reskinned wholesale later.
///
/// This is deliberately a *seed*, not a theme system — it starts with the
/// desk's previously-inline literals plus the hidden-drawing glyph grey.
/// New desk UI colors go here; a future reskin pass can grow this into a
/// real theme without hunting hex literals across screens.
abstract final class DeskColors {
  /// The app's accent gold/amber — selection glow, chip borders, active
  /// AppBar toggles.
  static const Color accentGold = Color(0xFFC4941A);

  /// The "void" beyond the desk's edge — the dark surround the canvas
  /// floats in.
  static const Color voidBackground = Color(0xFF0F0F17);

  /// Translucent dark fill behind small on-entity chips (resize, draw,
  /// eye).
  static const Color chipBackground = Color(0xCC16161F);

  /// The small grey pencil glyph shown on a card that has a hidden
  /// drawing (owner L10: hidden ink shouldn't be forgotten). Muted on
  /// purpose — a tell, not a control.
  static const Color hiddenDrawingGlyph = Color(0xFF8A8A93);

  /// Warm cream for small labels on dark chrome (desk-objects drawer tile
  /// names) — readable on [chipBackground] without competing with the
  /// gold accents.
  static const Color drawerLabel = Color(0xFFD8D3C8);
}
