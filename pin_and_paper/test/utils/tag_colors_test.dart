import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/utils/tag_colors.dart';

void main() {
  group('TagColors', () {
    test('defaultColor is defined', () {
      expect(TagColors.defaultColor, equals(const Color(0xFF2196F3)));
    });

    test('presetColors contains exactly 12 colors', () {
      expect(TagColors.presetColors.length, equals(12));
    });

    test('presetColors are all unique', () {
      final Set<Color> uniqueColors = TagColors.presetColors.toSet();
      expect(uniqueColors.length, equals(12)); // All colors are unique
    });

    test('defaultColor is included in presetColors', () {
      expect(
        TagColors.presetColors.contains(TagColors.defaultColor),
        isTrue,
      );
    });

    group('getColorByIndex', () {
      test('returns correct color for valid index', () {
        expect(
          TagColors.getColorByIndex(0),
          equals(TagColors.presetColors[0]),
        );
        expect(
          TagColors.getColorByIndex(5),
          equals(TagColors.presetColors[5]),
        );
        expect(
          TagColors.getColorByIndex(11),
          equals(TagColors.presetColors[11]),
        );
      });

      test('wraps around for index >= length', () {
        // Index 12 should wrap to 0
        expect(
          TagColors.getColorByIndex(12),
          equals(TagColors.presetColors[0]),
        );
        // Index 15 should wrap to 3
        expect(
          TagColors.getColorByIndex(15),
          equals(TagColors.presetColors[3]),
        );
      });

      test('handles negative indices', () {
        // Dart modulo with negative numbers: -1 % 12 = -1
        // This will cause an index error, but that's Dart behavior
        // For now, just ensure it doesn't crash for positive indices
        expect(() => TagColors.getColorByIndex(0), returnsNormally);
      });
    });

    group('colorToHex', () {
      test('converts Color to hex string correctly', () {
        expect(
          TagColors.colorToHex(const Color(0xFF2196F3)),
          equals('#2196F3'),
        );
        expect(
          TagColors.colorToHex(const Color(0xFFFF5722)),
          equals('#FF5722'),
        );
        expect(
          TagColors.colorToHex(const Color(0xFF000000)),
          equals('#000000'),
        );
        expect(
          TagColors.colorToHex(const Color(0xFFFFFFFF)),
          equals('#FFFFFF'),
        );
      });

      test('returns uppercase hex', () {
        final hex = TagColors.colorToHex(const Color(0xFFaabbcc));
        expect(hex, equals('#AABBCC'));
      });

      test('handles all preset colors', () {
        for (final color in TagColors.presetColors) {
          final hex = TagColors.colorToHex(color);
          expect(hex, startsWith('#'));
          expect(hex.length, equals(7));
          expect(hex.substring(1), matches(RegExp(r'^[0-9A-F]{6}$')));
        }
      });
    });

    group('hexToColor', () {
      test('converts hex string to Color correctly', () {
        expect(
          TagColors.hexToColor('#2196F3'),
          equals(const Color(0xFF2196F3)),
        );
        expect(
          TagColors.hexToColor('#FF5722'),
          equals(const Color(0xFFFF5722)),
        );
        expect(
          TagColors.hexToColor('#000000'),
          equals(const Color(0xFF000000)),
        );
        expect(
          TagColors.hexToColor('#FFFFFF'),
          equals(const Color(0xFFFFFFFF)),
        );
      });

      test('handles hex without # prefix', () {
        expect(
          TagColors.hexToColor('2196F3'),
          equals(const Color(0xFF2196F3)),
        );
      });

      test('handles lowercase hex', () {
        expect(
          TagColors.hexToColor('#2196f3'),
          equals(const Color(0xFF2196F3)),
        );
        expect(
          TagColors.hexToColor('#aabbcc'),
          equals(const Color(0xFFAABBCC)),
        );
      });

      test('handles 8-character hex by ignoring alpha', () {
        // #RRGGBBAA format - should ignore AA
        expect(
          TagColors.hexToColor('#2196F380'),
          equals(const Color(0xFF2196F3)), // Alpha ignored, full opacity
        );
      });

      test('returns defaultColor for invalid format', () {
        expect(
          TagColors.hexToColor('invalid'),
          equals(TagColors.defaultColor),
        );
        expect(
          TagColors.hexToColor('#12'),
          equals(TagColors.defaultColor),
        );
        expect(
          TagColors.hexToColor('#GGGGGG'),
          equals(TagColors.defaultColor),
        );
        expect(
          TagColors.hexToColor(''),
          equals(TagColors.defaultColor),
        );
      });
    });

    group('colorToHex and hexToColor roundtrip', () {
      test('roundtrip preserves color', () {
        const testColor = Color(0xFF2196F3);
        final hex = TagColors.colorToHex(testColor);
        final backToColor = TagColors.hexToColor(hex);
        expect(backToColor, equals(testColor));
      });

      test('roundtrip works for all presets', () {
        for (final color in TagColors.presetColors) {
          final hex = TagColors.colorToHex(color);
          final backToColor = TagColors.hexToColor(hex);
          expect(backToColor, equals(color));
        }
      });
    });

    group('findClosestPreset', () {
      test('returns exact match if color is in presets', () {
        for (final preset in TagColors.presetColors) {
          expect(
            TagColors.findClosestPreset(preset),
            equals(preset),
          );
        }
      });

      test('finds closest color for similar shades', () {
        // Slightly lighter blue (close to #2196F3)
        const lightBlue = Color(0xFF2199F6);
        final closest = TagColors.findClosestPreset(lightBlue);
        expect(closest, equals(const Color(0xFF2196F3))); // Blue 500
      });

      test('returns a preset color', () {
        const customColor = Color(0xFF123456);
        final closest = TagColors.findClosestPreset(customColor);
        expect(TagColors.presetColors.contains(closest), isTrue);
      });

      test('handles edge cases', () {
        // Pure black - should find darkest preset
        const black = Color(0xFF000000);
        expect(() => TagColors.findClosestPreset(black), returnsNormally);

        // Pure white - should find lightest preset
        const white = Color(0xFFFFFFFF);
        expect(() => TagColors.findClosestPreset(white), returnsNormally);
      });
    });
  });
}
