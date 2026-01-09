import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/filter_state.dart';

void main() {
  group('FilterState Model', () {
    // Test data
    final testTagIds = ['tag1', 'tag2', 'tag3'];

    group('Constructor and Factory', () {
      test('factory constructor creates filter with default values', () {
        final filter = FilterState();

        expect(filter.selectedTagIds, isEmpty);
        expect(filter.logic, FilterLogic.or);
        expect(filter.presenceFilter, TagPresenceFilter.any);
        expect(filter.isActive, false);
      });

      test('factory constructor creates filter with provided values', () {
        final filter = FilterState(
          selectedTagIds: testTagIds,
          logic: FilterLogic.and,
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        expect(filter.selectedTagIds, testTagIds);
        expect(filter.logic, FilterLogic.and);
        expect(filter.presenceFilter, TagPresenceFilter.onlyTagged);
        expect(filter.isActive, true);
      });

      test('M1: factory returns same empty instance for default params', () {
        final filter1 = FilterState();
        final filter2 = FilterState();
        final empty = FilterState.empty;

        // All should be the same instance (optimization)
        expect(identical(filter1, empty), true);
        expect(identical(filter2, empty), true);
        expect(identical(filter1, filter2), true);
      });

      test('empty static constant provides zero-allocation default', () {
        final filter = FilterState.empty;

        expect(filter.selectedTagIds, isEmpty);
        expect(filter.logic, FilterLogic.or);
        expect(filter.presenceFilter, TagPresenceFilter.any);
        expect(filter.isActive, false);
      });
    });

    group('L7: Immutability', () {
      test('selectedTagIds cannot be modified externally', () {
        final filter = FilterState(selectedTagIds: ['tag1', 'tag2']);

        // Attempt to modify the list should throw
        expect(
          () => filter.selectedTagIds.add('tag3'),
          throwsUnsupportedError,
        );

        // Original unchanged
        expect(filter.selectedTagIds, ['tag1', 'tag2']);
      });

      test('selectedTagIds from constructor is copied', () {
        final originalList = ['tag1', 'tag2'];
        final filter = FilterState(selectedTagIds: originalList);

        // Modify original list
        originalList.add('tag3');

        // Filter's list should be unchanged
        expect(filter.selectedTagIds, ['tag1', 'tag2']);
      });

      test('list passed to factory is not retained', () {
        final mutableList = ['tag1'];
        final filter = FilterState(selectedTagIds: mutableList);

        // Modify the original list
        mutableList.clear();
        mutableList.add('tag2');

        // Filter should still have original values
        expect(filter.selectedTagIds, ['tag1']);
      });
    });

    group('isActive Logic', () {
      test('returns false for empty filter', () {
        final filter = FilterState.empty;
        expect(filter.isActive, false);
      });

      test('returns true when tags are selected', () {
        final filter = FilterState(selectedTagIds: ['tag1']);
        expect(filter.isActive, true);
      });

      test('returns true when presence filter is onlyTagged', () {
        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyTagged,
        );
        expect(filter.isActive, true);
      });

      test('returns true when presence filter is onlyUntagged', () {
        final filter = FilterState(
          presenceFilter: TagPresenceFilter.onlyUntagged,
        );
        expect(filter.isActive, true);
      });

      test('returns true when both tags and presence filter are set', () {
        final filter = FilterState(
          selectedTagIds: ['tag1'],
          presenceFilter: TagPresenceFilter.onlyTagged,
        );
        expect(filter.isActive, true);
      });
    });

    group('copyWith', () {
      test('creates new filter with updated selectedTagIds', () {
        final original = FilterState(
          selectedTagIds: ['tag1'],
          logic: FilterLogic.and,
        );

        final copy = original.copyWith(selectedTagIds: ['tag2', 'tag3']);

        expect(copy.selectedTagIds, ['tag2', 'tag3']);
        expect(copy.logic, FilterLogic.and); // Unchanged
        expect(original.selectedTagIds, ['tag1']); // Original unchanged
      });

      test('creates new filter with updated logic', () {
        final original = FilterState(
          selectedTagIds: ['tag1'],
          logic: FilterLogic.or,
        );

        final copy = original.copyWith(logic: FilterLogic.and);

        expect(copy.logic, FilterLogic.and);
        expect(copy.selectedTagIds, ['tag1']); // Unchanged
      });

      test('creates new filter with updated presenceFilter', () {
        final original = FilterState(
          presenceFilter: TagPresenceFilter.any,
        );

        final copy = original.copyWith(
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        expect(copy.presenceFilter, TagPresenceFilter.onlyTagged);
      });

      test('preserves immutability after copyWith', () {
        final original = FilterState(selectedTagIds: ['tag1']);
        final copy = original.copyWith(selectedTagIds: ['tag2']);

        // Both should have unmodifiable lists
        expect(() => original.selectedTagIds.add('tag3'), throwsUnsupportedError);
        expect(() => copy.selectedTagIds.add('tag3'), throwsUnsupportedError);
      });

      test('returns new instance even if no changes', () {
        final original = FilterState(selectedTagIds: ['tag1']);
        final copy = original.copyWith();

        // Values should be equal
        expect(copy.selectedTagIds, original.selectedTagIds);
        expect(copy.logic, original.logic);
        expect(copy.presenceFilter, original.presenceFilter);
      });
    });

    group('JSON Serialization', () {
      test('toJson serializes all fields correctly', () {
        final filter = FilterState(
          selectedTagIds: testTagIds,
          logic: FilterLogic.and,
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        final json = filter.toJson();

        expect(json['selectedTagIds'], testTagIds);
        expect(json['logic'], 'and');
        expect(json['presenceFilter'], 'onlyTagged');
      });

      test('toJson handles empty filter', () {
        final filter = FilterState.empty;
        final json = filter.toJson();

        expect(json['selectedTagIds'], isEmpty);
        expect(json['logic'], 'or');
        expect(json['presenceFilter'], 'any');
      });

      test('fromJson deserializes all fields correctly', () {
        final json = {
          'selectedTagIds': testTagIds,
          'logic': 'and',
          'presenceFilter': 'onlyTagged',
        };

        final filter = FilterState.fromJson(json);

        expect(filter.selectedTagIds, testTagIds);
        expect(filter.logic, FilterLogic.and);
        expect(filter.presenceFilter, TagPresenceFilter.onlyTagged);
      });

      test('fromJson handles missing fields with defaults', () {
        final json = <String, dynamic>{};
        final filter = FilterState.fromJson(json);

        expect(filter.selectedTagIds, isEmpty);
        expect(filter.logic, FilterLogic.or);
        expect(filter.presenceFilter, TagPresenceFilter.any);
      });

      test('L1: fromJson handles invalid enum names gracefully', () {
        final json = {
          'selectedTagIds': ['tag1'],
          'logic': 'invalid_logic',
          'presenceFilter': 'invalid_filter',
        };

        // Should not throw, should return empty filter
        final filter = FilterState.fromJson(json);

        expect(filter, FilterState.empty);
      });

      test('L1: fromJson handles malformed JSON gracefully', () {
        final json = {
          'selectedTagIds': 'not_a_list', // Wrong type
          'logic': 123, // Wrong type
        };

        // Should not throw, should return empty filter
        final filter = FilterState.fromJson(json);

        expect(filter, FilterState.empty);
      });

      test('toJson/fromJson round trip preserves data', () {
        final original = FilterState(
          selectedTagIds: testTagIds,
          logic: FilterLogic.and,
          presenceFilter: TagPresenceFilter.onlyUntagged,
        );

        final json = original.toJson();
        final restored = FilterState.fromJson(json);

        expect(restored, original);
      });
    });

    group('Equality', () {
      test('identical filters are equal', () {
        final filter1 = FilterState(
          selectedTagIds: ['tag1', 'tag2'],
          logic: FilterLogic.and,
        );
        final filter2 = FilterState(
          selectedTagIds: ['tag1', 'tag2'],
          logic: FilterLogic.and,
        );

        expect(filter1, filter2);
        expect(filter1.hashCode, filter2.hashCode);
      });

      test('filters with different selectedTagIds are not equal', () {
        final filter1 = FilterState(selectedTagIds: ['tag1']);
        final filter2 = FilterState(selectedTagIds: ['tag2']);

        expect(filter1, isNot(filter2));
      });

      test('filters with different logic are not equal', () {
        final filter1 = FilterState(
          selectedTagIds: ['tag1'],
          logic: FilterLogic.or,
        );
        final filter2 = FilterState(
          selectedTagIds: ['tag1'],
          logic: FilterLogic.and,
        );

        expect(filter1, isNot(filter2));
      });

      test('filters with different presenceFilter are not equal', () {
        final filter1 = FilterState(
          presenceFilter: TagPresenceFilter.any,
        );
        final filter2 = FilterState(
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        expect(filter1, isNot(filter2));
      });

      test('tag order matters for equality', () {
        final filter1 = FilterState(selectedTagIds: ['tag1', 'tag2']);
        final filter2 = FilterState(selectedTagIds: ['tag2', 'tag1']);

        expect(filter1, isNot(filter2));
      });

      test('empty filters are equal', () {
        final filter1 = FilterState.empty;
        final filter2 = FilterState();

        expect(filter1, filter2);
        expect(filter1.hashCode, filter2.hashCode);
      });
    });

    group('toString', () {
      test('provides readable string representation', () {
        final filter = FilterState(
          selectedTagIds: ['tag1', 'tag2'],
          logic: FilterLogic.and,
          presenceFilter: TagPresenceFilter.onlyTagged,
        );

        final str = filter.toString();

        expect(str, contains('FilterState'));
        expect(str, contains('[tag1, tag2]'));
        expect(str, contains('and'));
        expect(str, contains('onlyTagged'));
        expect(str, contains('isActive: true'));
      });

      test('empty filter toString works', () {
        final str = FilterState.empty.toString();

        expect(str, contains('FilterState'));
        expect(str, contains('isActive: false'));
      });
    });

    group('Enum Values', () {
      test('FilterLogic has correct values', () {
        expect(FilterLogic.values.length, 2);
        expect(FilterLogic.values, contains(FilterLogic.or));
        expect(FilterLogic.values, contains(FilterLogic.and));
      });

      test('FilterLogic names are correct', () {
        expect(FilterLogic.or.name, 'or');
        expect(FilterLogic.and.name, 'and');
      });

      test('TagPresenceFilter has correct values', () {
        expect(TagPresenceFilter.values.length, 3);
        expect(TagPresenceFilter.values, contains(TagPresenceFilter.any));
        expect(TagPresenceFilter.values, contains(TagPresenceFilter.onlyTagged));
        expect(TagPresenceFilter.values, contains(TagPresenceFilter.onlyUntagged));
      });

      test('TagPresenceFilter names are correct', () {
        expect(TagPresenceFilter.any.name, 'any');
        expect(TagPresenceFilter.onlyTagged.name, 'onlyTagged');
        expect(TagPresenceFilter.onlyUntagged.name, 'onlyUntagged');
      });
    });
  });
}
