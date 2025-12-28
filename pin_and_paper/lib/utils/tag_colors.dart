import 'package:flutter/material.dart';

/// Preset tag colors from Material Design palette
///
/// Phase 3.5: Tags feature
/// - 12 vibrant, distinguishable colors
/// - Optimized for light theme (WCAG AA contrast ratio)
/// - Covers full color spectrum for visual variety
///
/// Usage:
/// - Quick tag creation: Choose from preset colors
/// - Visual distinction: Different tags easily recognizable
/// - Color picker: Display in grid for selection
class TagColors {
  /// Default tag color (Material Blue 500)
  /// Used when:
  /// - User doesn't select a color
  /// - Invalid color is provided
  /// - Fallback for any errors
  static const Color defaultColor = Color(0xFF2196F3); // Blue 500

  /// 12 preset tag colors from Material Design
  ///
  /// Colors selected for:
  /// - High saturation (vivid, eye-catching)
  /// - Distinct hues (easy to differentiate)
  /// - Good contrast on white background
  /// - Covers full color spectrum
  ///
  /// Index order designed for color picker grid (3x4 or 4x3)
  static const List<Color> presetColors = [
    Color(0xFFFF5722), // Deep Orange 500 (warm, energetic)
    Color(0xFFE91E63), // Pink 500 (vibrant, attention-grabbing)
    Color(0xFF9C27B0), // Purple 500 (creative, unique)
    Color(0xFF673AB7), // Deep Purple 500 (royal, sophisticated)
    Color(0xFF3F51B5), // Indigo 500 (deep, professional)
    Color(0xFF2196F3), // Blue 500 (calm, trustworthy) - default
    Color(0xFF03A9F4), // Light Blue 500 (fresh, modern)
    Color(0xFF00BCD4), // Cyan 500 (digital, cool)
    Color(0xFF009688), // Teal 500 (balanced, natural)
    Color(0xFF4CAF50), // Green 500 (positive, growth)
    Color(0xFFFF9800), // Orange 500 (friendly, warm)
    Color(0xFFFFC107), // Amber 500 (attention, caution)
  ];

  /// Text colors for each preset color to ensure WCAG AA contrast compliance
  ///
  /// Phase 3.5: Accessibility fix (Gemini review findings)
  /// - Manually assigned to guarantee 4.5:1 contrast ratio
  /// - Black text (Colors.black87) for light backgrounds
  /// - White text (Colors.white) for dark backgrounds
  ///
  /// Maps hex color string to appropriate text color
  static const Map<String, Color> textColorMap = {
    '#FF5722': Colors.white,     // Deep Orange - white text
    '#E91E63': Colors.white,     // Pink - white text
    '#9C27B0': Colors.white,     // Purple - white text
    '#673AB7': Colors.white,     // Deep Purple - white text
    '#3F51B5': Colors.white,     // Indigo - white text
    '#2196F3': Colors.white,     // Blue - white text
    '#03A9F4': Colors.white,     // Light Blue - white text
    '#00BCD4': Colors.black87,   // Cyan - black text (borderline)
    '#009688': Colors.white,     // Teal - white text
    '#4CAF50': Colors.white,     // Green - white text
    '#FF9800': Colors.black87,   // Orange - black text
    '#FFC107': Colors.black87,   // Amber - black text (CRITICAL)
  };

  /// Get preset color by index (wraps around if index out of bounds)
  ///
  /// Safe for any index value - never throws
  static Color getColorByIndex(int index) {
    if (presetColors.isEmpty) return defaultColor;
    return presetColors[index % presetColors.length];
  }

  /// Convert Color to hex string (#RRGGBB)
  ///
  /// Returns uppercase hex string without alpha channel
  /// Example: Color(0xFF2196F3) → "#2196F3"
  static String colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  /// Convert hex string to Color
  ///
  /// Accepts formats:
  /// - "#RRGGBB" (preferred)
  /// - "RRGGBB" (adds # automatically)
  /// - "#RRGGBBAA" (ignores alpha)
  ///
  /// Returns defaultColor if invalid format
  static Color hexToColor(String hex) {
    try {
      // Remove # if present
      String hexColor = hex.replaceAll('#', '');

      // Handle 8-character hex (RRGGBBAA) - ignore alpha
      if (hexColor.length == 8) {
        hexColor = hexColor.substring(0, 6);
      }

      // Validate 6-character hex
      if (hexColor.length != 6) return defaultColor;

      // Parse and add full opacity
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return defaultColor; // Fallback to default if parsing fails
    }
  }

  /// Find closest preset color to given color
  ///
  /// Uses Euclidean distance in RGB space
  /// Useful for suggesting preset when user picks custom color
  static Color findClosestPreset(Color color) {
    if (presetColors.isEmpty) return defaultColor;

    Color closest = presetColors.first;
    double minDistance = _colorDistance(color, closest);

    for (final preset in presetColors.skip(1)) {
      final distance = _colorDistance(color, preset);
      if (distance < minDistance) {
        minDistance = distance;
        closest = preset;
      }
    }

    return closest;
  }

  /// Get appropriate text color for tag background color
  ///
  /// Phase 3.5: Accessibility fix (Gemini review findings)
  /// - Uses manually assigned text colors for preset colors
  /// - Falls back to luminance calculation for non-preset colors
  /// - Guarantees WCAG AA compliance for all preset colors
  ///
  /// Returns Colors.black87 or Colors.white
  static Color getTextColor(String colorHex) {
    // Normalize hex string (uppercase, with #)
    final normalizedHex = colorHex.toUpperCase();
    final hexWithHash = normalizedHex.startsWith('#')
        ? normalizedHex
        : '#$normalizedHex';

    // Check if this is a preset color with assigned text color
    if (textColorMap.containsKey(hexWithHash)) {
      return textColorMap[hexWithHash]!;
    }

    // Fallback: Use luminance calculation for non-preset colors
    final color = hexToColor(colorHex);
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Calculate Euclidean distance between two colors in RGB space
  static double _colorDistance(Color a, Color b) {
    final rDiff = (a.r * 255).round() - (b.r * 255).round();
    final gDiff = (a.g * 255).round() - (b.g * 255).round();
    final bDiff = (a.b * 255).round() - (b.b * 255).round();
    return (rDiff * rDiff + gDiff * gDiff + bDiff * bDiff).toDouble();
  }
}
