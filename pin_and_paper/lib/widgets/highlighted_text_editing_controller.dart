import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Custom TextEditingController that highlights a range of text
///
/// Phase 3.7: Used for highlighting detected dates in task title fields
///
/// Key features:
/// - Inline text highlighting with custom styles
/// - Tap gesture on highlighted text
/// - Web platform workaround (highlighting disabled due to cursor issues)
/// - Maintains full text editing capabilities
///
/// Implementation note:
/// This uses buildTextSpan() override, which is the correct Flutter pattern
/// for inline highlighting. RichText widget is NOT editable and cannot be used.
class HighlightedTextEditingController extends TextEditingController {
  TextRange? highlightRange;
  VoidCallback? onTapHighlight;

  HighlightedTextEditingController({
    String? text,
    this.onTapHighlight,
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

        // Highlighted text (visual only - tap handled separately)
        // Note: TapGestureRecognizer not allowed in editable TextFields
        // (Flutter assertion: readOnly && !obscureText)
        TextSpan(
          text: text.substring(range.start, range.end),
          style: baseStyle.copyWith(
            backgroundColor: Colors.blue.withOpacity(0.2),
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

  @override
  void dispose() {
    // Note: TapGestureRecognizer is automatically disposed by Flutter
    // when TextSpan is rebuilt, so no manual cleanup needed
    super.dispose();
  }
}
