import 'package:flutter/material.dart';
import '../utils/tag_colors.dart';

/// Dialog for picking a color from preset Material Design colors
///
/// Phase 3.5: Tags feature
/// - Displays 12 preset colors in a grid
/// - Returns selected color as hex string
/// - Follows AlertDialog pattern
class ColorPickerDialog extends StatefulWidget {
  final String? initialColor;

  const ColorPickerDialog({
    super.key,
    this.initialColor,
  });

  /// Show the color picker dialog
  ///
  /// Returns selected color hex string or null if cancelled
  static Future<String?> show({
    required BuildContext context,
    String? initialColor,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late String selectedColorHex;

  @override
  void initState() {
    super.initState();
    // Use initial color or default
    selectedColorHex = widget.initialColor ??
        TagColors.colorToHex(TagColors.defaultColor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Color'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: TagColors.presetColors.length,
          itemBuilder: (context, index) {
            final color = TagColors.presetColors[index];
            final colorHex = TagColors.colorToHex(color);
            final isSelected = colorHex == selectedColorHex;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedColorHex = colorHex;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        // Phase 3.5: Accessibility fix (Gemini review findings)
                        color: TagColors.getTextColor(colorHex),
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selectedColorHex),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
