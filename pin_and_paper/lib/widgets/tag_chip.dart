import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../utils/tag_colors.dart';

/// Visual representation of a tag as a colored chip
///
/// Phase 3.5: Tags feature
/// - Displays tag name with color
/// - Optional delete/close button
/// - Compact design for inline display
/// - Follows Material Design chip pattern
class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onDelete;
  final bool compact;

  const TagChip({
    super.key,
    required this.tag,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Get tag color (or default)
    final colorHex = tag.color ?? TagColors.colorToHex(TagColors.defaultColor);
    final tagColor = TagColors.hexToColor(colorHex);

    // Get appropriate text color (WCAG AA compliant)
    // Phase 3.5: Accessibility fix (Gemini review findings)
    final textColor = TagColors.getTextColor(colorHex);

    return Material(
      color: tagColor,
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        onTap: onDelete != null ? null : () {}, // Disable ink effect if deletable
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tag name with overflow handling
              // Phase 3.5: Fix #C1 - Prevent text overflow with ellipsis
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? 150 : 200,
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: compact ? 12 : 14,
                      fontWeight: compact ? FontWeight.normal : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Delete button (optional)
              if (onDelete != null) ...[
                SizedBox(width: compact ? 4 : 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.close,
                    size: compact ? 14 : 16,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact tag chip for inline display in task lists
///
/// Pre-configured TagChip with compact=true for convenience
class CompactTagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onDelete;

  const CompactTagChip({
    super.key,
    required this.tag,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TagChip(
      tag: tag,
      onDelete: onDelete,
      compact: true,
    );
  }
}
