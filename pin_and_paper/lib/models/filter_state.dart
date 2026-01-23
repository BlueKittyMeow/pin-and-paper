import 'package:flutter/foundation.dart'; // For listEquals and debugPrint

/// Phase 3.6A: Tag Filtering
///
/// Represents the current filter state for task lists.
///
/// Immutable value object with proper equality semantics.
/// All lists are unmodifiable to prevent accidental mutations.
///
/// This is the core model for Phase 3.6A tag filtering feature,
/// thoroughly reviewed and hardened through multiple review cycles.
class FilterState {
  /// Tag IDs to filter by. Empty list means no tag filter.
  /// Always unmodifiable to maintain immutability.
  final List<String> selectedTagIds;

  /// Logic for combining multiple tags (AND or OR).
  final FilterLogic logic;

  /// Filter by tag presence. Default is 'any' (no filter).
  final TagPresenceFilter presenceFilter;

  /// Phase 3.7.5: Filter by due date status.
  final DateFilter dateFilter;

  /// Private constructor - use factory constructor or named constructors.
  const FilterState._(
    this.selectedTagIds,
    this.logic,
    this.presenceFilter,
    this.dateFilter,
  );

  /// Create a filter state with immutable list guarantee.
  ///
  /// FIX #1 (Codex v2): Factory constructor ensures all instances have
  /// unmodifiable lists, even when created with `FilterState(selectedTagIds: myList)`.
  /// This prevents accidental mutations that would break immutability.
  ///
  /// M1 (v3.1): Returns the const `FilterState.empty` singleton when called with
  /// default parameters to avoid unnecessary allocations.
  factory FilterState({
    List<String> selectedTagIds = const [],
    FilterLogic logic = FilterLogic.or,
    TagPresenceFilter presenceFilter = TagPresenceFilter.any,
    DateFilter dateFilter = DateFilter.any,
  }) {
    // M1: Optimization - return const empty for default parameters
    if (selectedTagIds.isEmpty &&
        logic == FilterLogic.or &&
        presenceFilter == TagPresenceFilter.any &&
        dateFilter == DateFilter.any) {
      return FilterState.empty;
    }

    return FilterState._(
      List<String>.unmodifiable(selectedTagIds),
      logic,
      presenceFilter,
      dateFilter,
    );
  }

  /// Default filter state (no filters active).
  /// Use this instead of FilterState() for zero allocation.
  static const FilterState empty = FilterState._(
    const <String>[],
    FilterLogic.or,
    TagPresenceFilter.any,
    DateFilter.any,
  );

  /// Whether any filters are active
  bool get isActive {
    return selectedTagIds.isNotEmpty ||
        presenceFilter != TagPresenceFilter.any ||
        dateFilter != DateFilter.any;
  }

  /// Create a copy with updated fields
  ///
  /// Ensures the new selectedTagIds list is also unmodifiable.
  FilterState copyWith({
    List<String>? selectedTagIds,
    FilterLogic? logic,
    TagPresenceFilter? presenceFilter,
    DateFilter? dateFilter,
  }) {
    return FilterState(
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      logic: logic ?? this.logic,
      presenceFilter: presenceFilter ?? this.presenceFilter,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }

  /// Serialize to JSON for future persistence (Phase 6+)
  ///
  /// Uses JSON-friendly format with enum names as strings.
  Map<String, dynamic> toJson() {
    return {
      'selectedTagIds': selectedTagIds,
      'logic': logic.name,
      'presenceFilter': presenceFilter.name,
      'dateFilter': dateFilter.name,
    };
  }

  /// Deserialize from JSON for future persistence (Phase 6+).
  ///
  /// Factory constructor ensures list immutability.
  /// L1 (v3.1): Handles invalid enum names gracefully (defensive programming).
  factory FilterState.fromJson(Map<String, dynamic> json) {
    try {
      return FilterState(
        selectedTagIds: List<String>.from(json['selectedTagIds'] ?? []),
        logic: FilterLogic.values.byName(json['logic'] ?? 'or'),
        presenceFilter: TagPresenceFilter.values.byName(
          json['presenceFilter'] ?? 'any',
        ),
        dateFilter: DateFilter.values.byName(
          json['dateFilter'] ?? 'any',
        ),
      );
    } catch (e) {
      debugPrint('Error deserializing FilterState, returning empty: $e');
      return FilterState.empty;
    }
  }

  // Equality implementation for early-return optimization in setFilter
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterState &&
          runtimeType == other.runtimeType &&
          listEquals(selectedTagIds, other.selectedTagIds) &&
          logic == other.logic &&
          presenceFilter == other.presenceFilter &&
          dateFilter == other.dateFilter;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(selectedTagIds), logic, presenceFilter, dateFilter);

  @override
  String toString() {
    return 'FilterState('
        'selectedTagIds: $selectedTagIds, '
        'logic: ${logic.name}, '
        'presenceFilter: ${presenceFilter.name}, '
        'dateFilter: ${dateFilter.name}, '
        'isActive: $isActive'
        ')';
  }
}

/// Logic for combining multiple tag filters
///
/// This determines how selected tags are combined in the SQL query.
enum FilterLogic {
  /// Match tasks with ANY of the selected tags (OR logic)
  /// SQL: WHERE tag_id IN ('tag1', 'tag2', 'tag3')
  or,

  /// Match tasks with ALL of the selected tags (AND logic)
  /// SQL: Multiple EXISTS subqueries, one per tag
  and,
}

/// Filter by tag presence
///
/// Phase 3.6A: Enum pattern prevents impossible states
/// (e.g., can't select both "only tagged" and "only untagged")
enum TagPresenceFilter {
  /// Show all tasks (no presence filter)
  any,

  /// Show only tasks WITH tags
  ///
  /// FIX #3 (v3.1): "Tagged" option semantics clarified:
  /// - With specific tags selected: Show tasks with those specific tags
  /// - Without specific tags: Show tasks with ANY tag (useful query!)
  onlyTagged,

  /// Show only tasks WITHOUT any tags
  onlyUntagged,
}

/// Phase 3.7.5: Filter by due date status
enum DateFilter {
  /// Show all tasks (no date filter)
  any,

  /// Show only overdue tasks (due date in the past)
  overdue,

  /// Show only tasks with no due date set
  noDueDate,
}
