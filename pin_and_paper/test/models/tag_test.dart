import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/tag.dart';

void main() {
  group('Tag Model', () {
    // Test data
    final testId = 'tag-123';
    final testName = 'work';
    final testColor = '#FF5722';
    final testCreatedAt = DateTime(2025, 1, 15, 10, 30);
    final testDeletedAt = DateTime(2025, 1, 20, 15, 45);

    test('constructor creates tag with required fields', () {
      final tag = Tag(
        id: testId,
        name: testName,
        createdAt: testCreatedAt,
      );

      expect(tag.id, testId);
      expect(tag.name, testName);
      expect(tag.createdAt, testCreatedAt);
      expect(tag.color, isNull);
      expect(tag.deletedAt, isNull);
    });

    test('constructor creates tag with all fields', () {
      final tag = Tag(
        id: testId,
        name: testName,
        color: testColor,
        createdAt: testCreatedAt,
        deletedAt: testDeletedAt,
      );

      expect(tag.id, testId);
      expect(tag.name, testName);
      expect(tag.color, testColor);
      expect(tag.createdAt, testCreatedAt);
      expect(tag.deletedAt, testDeletedAt);
    });

    test('toMap serializes all fields correctly', () {
      final tag = Tag(
        id: testId,
        name: testName,
        color: testColor,
        createdAt: testCreatedAt,
        deletedAt: testDeletedAt,
      );

      final map = tag.toMap();

      expect(map['id'], testId);
      expect(map['name'], testName);
      expect(map['color'], testColor);
      expect(map['created_at'], testCreatedAt.millisecondsSinceEpoch);
      expect(map['deleted_at'], testDeletedAt.millisecondsSinceEpoch);
    });

    test('toMap handles null fields correctly', () {
      final tag = Tag(
        id: testId,
        name: testName,
        createdAt: testCreatedAt,
      );

      final map = tag.toMap();

      expect(map['id'], testId);
      expect(map['name'], testName);
      expect(map['color'], isNull);
      expect(map['created_at'], testCreatedAt.millisecondsSinceEpoch);
      expect(map['deleted_at'], isNull);
    });

    test('fromMap deserializes all fields correctly', () {
      final map = {
        'id': testId,
        'name': testName,
        'color': testColor,
        'created_at': testCreatedAt.millisecondsSinceEpoch,
        'deleted_at': testDeletedAt.millisecondsSinceEpoch,
      };

      final tag = Tag.fromMap(map);

      expect(tag.id, testId);
      expect(tag.name, testName);
      expect(tag.color, testColor);
      expect(tag.createdAt, testCreatedAt);
      expect(tag.deletedAt, testDeletedAt);
    });

    test('fromMap handles null fields correctly', () {
      final map = {
        'id': testId,
        'name': testName,
        'color': null,
        'created_at': testCreatedAt.millisecondsSinceEpoch,
        'deleted_at': null,
      };

      final tag = Tag.fromMap(map);

      expect(tag.id, testId);
      expect(tag.name, testName);
      expect(tag.color, isNull);
      expect(tag.createdAt, testCreatedAt);
      expect(tag.deletedAt, isNull);
    });

    test('copyWith updates specified fields only', () {
      final original = Tag(
        id: testId,
        name: testName,
        color: testColor,
        createdAt: testCreatedAt,
      );

      final updated = original.copyWith(
        name: 'urgent',
        color: '#2196F3',
      );

      expect(updated.id, testId); // Unchanged
      expect(updated.name, 'urgent'); // Changed
      expect(updated.color, '#2196F3'); // Changed
      expect(updated.createdAt, testCreatedAt); // Unchanged
      expect(updated.deletedAt, isNull); // Unchanged
    });

    test('copyWith preserves fields when not specified', () {
      final original = Tag(
        id: testId,
        name: testName,
        color: testColor,
        createdAt: testCreatedAt,
        deletedAt: testDeletedAt,
      );

      final updated = original.copyWith(name: 'personal');

      expect(updated.id, testId);
      expect(updated.name, 'personal');
      expect(updated.color, testColor); // Preserved
      expect(updated.createdAt, testCreatedAt); // Preserved
      expect(updated.deletedAt, testDeletedAt); // Preserved
    });

    test('toString returns formatted string', () {
      final tag = Tag(
        id: testId,
        name: testName,
        color: testColor,
        createdAt: testCreatedAt,
      );

      expect(
        tag.toString(),
        'Tag(id: $testId, name: $testName, color: $testColor)',
      );
    });

    test('equality based on id', () {
      final tag1 = Tag(
        id: testId,
        name: testName,
        createdAt: testCreatedAt,
      );

      final tag2 = Tag(
        id: testId,
        name: 'different-name', // Different name, same id
        createdAt: DateTime.now(), // Different timestamp
      );

      expect(tag1, equals(tag2)); // Equal because same id
      expect(tag1.hashCode, equals(tag2.hashCode));
    });

    test('inequality based on different id', () {
      final tag1 = Tag(
        id: testId,
        name: testName,
        createdAt: testCreatedAt,
      );

      final tag2 = Tag(
        id: 'tag-456', // Different id
        name: testName, // Same name
        createdAt: testCreatedAt, // Same timestamp
      );

      expect(tag1, isNot(equals(tag2))); // Not equal because different id
    });

    group('validateName', () {
      test('valid name returns null', () {
        expect(Tag.validateName('work'), isNull);
        expect(Tag.validateName('urgent'), isNull);
        expect(Tag.validateName('a'), isNull); // Single character is valid
      });

      test('empty string returns error', () {
        expect(Tag.validateName(''), isNotNull);
        expect(Tag.validateName(''), contains('cannot be empty'));
      });

      test('whitespace-only string returns error', () {
        expect(Tag.validateName('   '), isNotNull);
        expect(Tag.validateName('\t\n'), isNotNull);
      });

      test('name with leading/trailing whitespace is valid (will be trimmed)', () {
        expect(Tag.validateName('  work  '), isNull);
        expect(Tag.validateName('\turgent\n'), isNull);
      });

      test('name at max length (100 chars) is valid', () {
        final maxLengthName = 'a' * 100;
        expect(Tag.validateName(maxLengthName), isNull);
      });

      test('name exceeding max length (101+ chars) returns error', () {
        final tooLongName = 'a' * 101;
        expect(Tag.validateName(tooLongName), isNotNull);
        expect(Tag.validateName(tooLongName), contains('100 characters'));
      });

      test('descriptive tag name (AO3-style) is valid', () {
        final descriptiveName = 'Alternate Universe - Coffee Shops & Cafés';
        expect(Tag.validateName(descriptiveName), isNull);
        expect(descriptiveName.length, lessThan(101));
      });
    });

    group('validateColor', () {
      test('valid hex color returns null', () {
        expect(Tag.validateColor('#FF5722'), isNull);
        expect(Tag.validateColor('#2196F3'), isNull);
        expect(Tag.validateColor('#000000'), isNull);
        expect(Tag.validateColor('#FFFFFF'), isNull);
        expect(Tag.validateColor('#aabbcc'), isNull); // Lowercase is valid
        expect(Tag.validateColor('#AaBbCc'), isNull); // Mixed case is valid
      });

      test('null color returns null (default color)', () {
        expect(Tag.validateColor(null), isNull);
      });

      test('invalid format returns error', () {
        expect(Tag.validateColor('FF5722'), isNotNull); // Missing #
        expect(Tag.validateColor('#FF57'), isNotNull); // Too short
        expect(Tag.validateColor('#FF57222'), isNotNull); // Too long
        expect(Tag.validateColor('#GG5722'), isNotNull); // Invalid hex chars
        expect(Tag.validateColor('red'), isNotNull); // Not hex at all
      });

      test('error message is descriptive', () {
        final error = Tag.validateColor('invalid');
        expect(error, contains('valid hex code'));
        expect(error, contains('#RRGGBB'));
      });
    });

    test('roundtrip serialization preserves all data', () {
      final original = Tag(
        id: testId,
        name: testName,
        color: testColor,
        createdAt: testCreatedAt,
        deletedAt: testDeletedAt,
      );

      final map = original.toMap();
      final deserialized = Tag.fromMap(map);

      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.color, original.color);
      expect(deserialized.createdAt, original.createdAt);
      expect(deserialized.deletedAt, original.deletedAt);
    });
  });
}
