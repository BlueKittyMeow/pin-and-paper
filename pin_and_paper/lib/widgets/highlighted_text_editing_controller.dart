import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
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
  TapGestureRecognizer? _tapRecognizer;

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

        // Highlighted text with tap-to-refine gesture
        // task_input.dart wires onTapHighlight to open DateOptionsSheet
        // task_item.dart uses its own GestureDetector on the date suffix instead
        TextSpan(
          text: text.substring(range.start, range.end),
          style: baseStyle.copyWith(
            backgroundColor: Colors.blue.withValues(alpha: 0.2),
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
          recognizer: onTapHighlight != null
              ? (_tapRecognizer = TapGestureRecognizer()..onTap = onTapHighlight)
              : null,
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
    _tapRecognizer?.dispose();
    _tapRecognizer = null;
    super.dispose();
  }
}
