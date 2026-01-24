import 'package:flutter/foundation.dart';
import '../models/filter_state.dart';
import '../providers/tag_provider.dart';

/// Provider for managing task filter state
///
/// Phase 3.9 Refactor: Extracted from TaskProvider to reduce file size
/// and improve separation of concerns.
///
/// Responsibilities:
/// - Manage filter state (selected tags, date filters, presence filters)
/// - Provide filter manipulation methods (add/remove/clear tags)
/// - Validate filter changes (tag existence, duplicates)
/// - Race condition prevention via operation ID pattern
///
/// TaskProvider listens to this provider and applies filters by
/// loading filtered task lists from TaskService.
class TaskFilterProvider extends ChangeNotifier {
  final TagProvider _tagProvider;

  TaskFilterProvider({
    required TagProvider tagProvider,
  }) : _tagProvider = tagProvider;

  FilterState _filterState = FilterState.empty;
  int _filterOperationId = 0; // Race condition prevention

  // Getters
  FilterState get filterState => _filterState;
  bool get hasActiveFilters => _filterState.isActive;
  int get filterOperationId => _filterOperationId;

  /// Set a new filter state
  ///
  /// Uses an operation ID pattern to prevent race conditions when the user
  /// changes filters rapidly. Only the most recent operation's results are applied.
  ///
  /// Returns the operation ID for this filter change, which TaskProvider can
  /// use to determine if results should be applied.
  ///
  /// H2 (v3.1): Supports rollback on error - caller can use previousFilter
  /// and operation ID to restore state if needed.
  int setFilter(FilterState filter) {
    // Early return if filter unchanged (optimization)
    if (_filterState == filter) return _filterOperationId;

    _filterState = filter;
    _filterOperationId++; // Increment before async work
    notifyListeners(); // Notify immediately for UI updates

    return _filterOperationId;
  }

  /// Rollback to previous filter state (used on error)
  ///
  /// Only rolls back if the operation ID matches the current ID,
  /// preventing rollback of stale operations.
  void rollbackFilter(FilterState previousFilter, int operationId) {
    if (operationId == _filterOperationId) {
      _filterState = previousFilter;
      notifyListeners();
    }
  }

  /// Add a tag to the current filter
  ///
  /// Validates the tag ID and prevents duplicates.
  /// Used when user clicks a tag chip for quick filtering.
  ///
  /// M2 (v3.1): Validate tag existence using TagProvider (in-memory, faster than DB query)
  void addTagFilter(String tagId) {
    // Validate input
    if (tagId.isEmpty) {
      debugPrint('addTagFilter: empty tagId');
      return;
    }

    if (_filterState.selectedTagIds.contains(tagId)) {
      debugPrint('addTagFilter: tag $tagId already in filter');
      return; // Already filtered by this tag
    }

    // M2: Validate tag exists (use TagProvider - faster, in-memory)
    final tagExists = _tagProvider.tags.any((tag) => tag.id == tagId);
    if (!tagExists) {
      debugPrint('addTagFilter: tag $tagId does not exist');
      return; // Reject invalid tag IDs (prevents SQL errors)
    }

    // Create new filter with added tag
    final newTags = List<String>.from(_filterState.selectedTagIds)..add(tagId);
    final newFilter = _filterState.copyWith(selectedTagIds: newTags);

    setFilter(newFilter);
  }

  /// Remove a tag from the current filter
  ///
  /// If no filters remain after removal, clears the filter entirely.
  void removeTagFilter(String tagId) {
    final newTags = _filterState.selectedTagIds
        .where((id) => id != tagId)
        .toList();

    // If no filters left, clear entirely
    if (newTags.isEmpty && _filterState.presenceFilter == TagPresenceFilter.any) {
      clearFilters();
    } else {
      final newFilter = _filterState.copyWith(selectedTagIds: newTags);
      setFilter(newFilter);
    }
  }

  /// Clear all filters and show all tasks
  ///
  /// Resets filter state to empty.
  void clearFilters() {
    setFilter(FilterState.empty);
  }
}
