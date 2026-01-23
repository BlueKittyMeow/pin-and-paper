import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Custom TextEditingController that highlights a range of text
///
/// Phase 3.7: Used for highlighting detected dates in task title fields
///
/// Key features:
/// - Inline text highlighting with custom styles
/// - Web platform workaround (highlighting disabled due to cursor issues)
/// - Maintains full text editing capabilities
///
/// Implementation notes:
/// - This uses buildTextSpan() override, which is the correct Flutter pattern
///   for inline highlighting. RichText widget is NOT editable and cannot be used.
/// - TapGestureRecognizer CANNOT be used on TextSpans in editable TextFields.
///   Flutter asserts: 'readOnly && !obscureText' (editable.dart:1346).
///   Tap detection is handled via TextField.onTap + cursor position check instead.
class HighlightedTextEditingController extends TextEditingController {
  TextRange? highlightRange;

  HighlightedTextEditingController({
    String? text,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Web workaround: disable highlighting on web platform
    // Issue: Flutter web has cursor positioning issues with complex TextSpans
    // Impact: Web users see parsed dates in preview but no visual highlighting
    // This is a minor cosmetic limitation - full functionality preserved
    if (kIsWeb || highlightRange == null) {
      return TextSpan(style: style, text: text);
    }

    // Full highlighting for mobile/desktop (works perfectly)
    final range = highlightRange!;
    final baseStyle = style ?? const TextStyle();

    // Validate range
    if (range.start < 0 || range.end > text.length || range.start >= range.end) {
      return TextSpan(style: style, text: text);
    }

    return TextSpan(
      style: baseStyle,
      children: [
        // Text before highlight
        if (range.start > 0)
          TextSpan(text: text.substring(0, range.start)),

        // Highlighted text (visual only)
        // Tap detection is handled by TextField.onTap in task_input.dart
        // and edit_task_dialog.dart (cursor position check against highlightRange)
        TextSpan(
          text: text.substring(range.start, range.end),
          style: baseStyle.copyWith(
            backgroundColor: Colors.blue.withValues(alpha: 0.2),
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),

        // Text after highlight
        if (range.end < text.length)
          TextSpan(text: text.substring(range.end)),
      ],
    );
  }

  /// Set the highlight range and trigger rebuild
  void setHighlight(TextRange? range) {
    if (highlightRange != range) {
      highlightRange = range;
      notifyListeners(); // Trigger TextField rebuild
    }
  }

  /// Clear the highlight
  void clearHighlight() {
    if (highlightRange != null) {
      highlightRange = null;
      notifyListeners();
    }
  }
}
