# Phase 3.6A Plan: Tag Filtering (v3)

**Version:** 3.0 (final plan - incorporates all Codex v2 feedback)
**Created:** 2026-01-09
**Updated:** 2026-01-09 (post-v2 review, added Codex v2 fixes)
**Status:** Ready for Implementation
**Branch:** `phase-3.6A-tag-filtering`

---

## Changes from v1

**Critical fixes from code review:**
1. 🔴 Added operation ID pattern to prevent race conditions
2. 🔴 Added `completed` parameter to all SQL queries (active/completed separation)
3. 🟡 Implemented `==` and `hashCode` for FilterState (prevent duplicate queries)
4. 🟡 Changed to `TagPresenceFilter` enum (prevent impossible filter states)
5. 🟡 Added `List.unmodifiable` in copyWith (immutability guarantee)
6. 🟡 Added validation to `addTagFilter` (prevent duplicates/invalid IDs)
7. 🟡 Update both `_tasks` and `_completedTasks` in setFilter (global filter consistency)

**Nice-to-have improvements (all approved):**
1. 🟢 Added `toJson`/`fromJson` methods (future-proofing for Phase 6+ persistence)
2. 🟢 Pinned "Clear All" button in ActiveFilterBar (UX polish)
3. 🟢 Dialog search state preservation + test (power user UX)

**UX polish from Gemini v2 review (all approved):**
1. 🎯 Scroll position reset when filter changes (prevent disorienting UX)
2. 🎨 Ghost tag handling in ActiveFilterBar (hide deleted tags gracefully)
3. 📳 Haptic feedback for filter interactions (tactile response)

---

## Changes from v2 (Codex v2 Feedback)

**Final hardening fixes:**
1. 🔴 **HIGH:** FilterState constructor now guarantees immutability (factory pattern)
2. 🟡 **MEDIUM:** Preload tag counts with single query (fix N+1 problem)
3. 🟡 **MEDIUM:** "Tagged" option clarified - means "has any tag" (useful query)
4. 🟡 **MEDIUM:** Error recovery with rollback (UI consistency on failure)
5. 🟢 **LOW:** Tag existence validation in addTagFilter (prevent invalid IDs)

**See:**
- `docs/phase-3.6A/review-analysis.md` - v1 fixes
- `docs/phase-3.6A/review-analysis-v2.md` - v2 fixes (Codex feedback)

---

## Overview

**Goal:** Enable users to filter tasks by tags, completing the tagging system started in Phase 3.5

**Why now:**
- Just completed comprehensive tagging system in Phase 3.5
- Tags aren't useful without filtering capability
- Quick win (1 week) with immediate user value
- Natural extension of fresh tag infrastructure

**Estimated Duration:** 1 week (5-7 days)

---

## Scope

### Phase 3.6A Features

#### 1. Clickable Tag Chips
- Click any tag chip → immediately filter by that tag
- Works in main task list (active tasks)
- Works in completed task list
- Visual feedback when tag is active filter (highlighted/selected state)
- Single-tag quick filter (most common use case)

#### 2. Tag Filter Dialog
- **UI Location:** Filter icon in top app bar (🏷️ funnel icon - `Icons.filter_alt`)
- **Dialog Contents:**
  - List of all tags with task counts (e.g., "Work (12 tasks)")
  - Checkbox for each tag (multi-select)
  - **Search field** to find tags (preserves selection state when search changes)
  - AND/OR logic toggle
    - AND: "Show tasks with ALL selected tags"
    - OR: "Show tasks with ANY selected tags"
  - Tag presence radio buttons (mutually exclusive):
    - "Any" (default)
    - "Only tagged tasks" (has at least one tag)
    - "Only untagged tasks" (has no tags)
  - "Apply" and "Cancel" buttons

#### 3. Active Filter Bar
- Displays below app bar when filters are active
- Shows selected tags as chips
- Each chip has "X" button to remove that filter
- **"Clear all filters" button pinned on right (doesn't scroll off screen)**
- Compact design (doesn't take too much vertical space)
- Persists across navigation (within app session)

#### 4. Filter by Tag Presence
- Radio button group: "Any" / "Only tagged" / "Only untagged"
- **Mutually exclusive** (can't select both "tagged" and "untagged")
- **Disabled when specific tags selected** (prevents contradictions)
- Use case: Find untagged tasks to organize

### Out of Scope (3.6B or later)
- ❌ Text search (that's Phase 3.6B)
- ❌ Fuzzy matching (3.6B)
- ❌ Date-based filtering (3.6B stretch goal or 3.7)
- ❌ Filter presets/saved filters (Phase 6+)
- ❌ Filter persistence across app restarts (Phase 6+)

---

## Technical Approach

### 1. Data Layer

#### FilterState Model (`lib/models/filter_state.dart`)

**Design principles:**
- ✅ Immutable (all fields final, no setters)
- ✅ Equality override (prevent duplicate queries)
- ✅ Defensive list handling (List.unmodifiable)
- ✅ Serializable (toJson/fromJson for future persistence)
- ✅ Impossible states prevented at model layer (enum for tag presence)

```dart
import 'package:flutter/foundation.dart'; // For listEquals

/// Represents the current filter state for task lists.
///
/// Immutable value object with proper equality semantics.
/// All lists are unmodifiable to prevent accidental mutations.
class FilterState {
  /// Tag IDs to filter by. Empty list means no tag filter.
  final List<String> selectedTagIds;

  /// Logic for combining multiple tags (AND or OR).
  final FilterLogic logic;

  /// Filter by tag presence. Default is 'any' (no filter).
  final TagPresenceFilter presenceFilter;

  /// Private constructor - use factory constructor or named constructors.
  const FilterState._(
    this.selectedTagIds,
    this.logic,
    this.presenceFilter,
  );

  /// Create a filter state with immutable list guarantee.
  ///
  /// FIX #1 (Codex v2): Factory constructor ensures all instances have
  /// unmodifiable lists, even when created with `FilterState(selectedTagIds: myList)`.
  /// This prevents accidental mutations that would break immutability.
  factory FilterState({
    List<String> selectedTagIds = const [],
    FilterLogic logic = FilterLogic.or,
    TagPresenceFilter presenceFilter = TagPresenceFilter.any,
  }) {
    return FilterState._(
      List<String>.unmodifiable(selectedTagIds),
      logic,
      presenceFilter,
    );
  }

  /// Default filter state (no filters active).
  /// Const constructor for zero allocation.
  static const FilterState empty = FilterState._(
    const <String>[],
    FilterLogic.or,
    TagPresenceFilter.any,
  );

  /// Returns true if any filters are active.
  bool get isActive =>
      selectedTagIds.isNotEmpty ||
      presenceFilter != TagPresenceFilter.any;

  /// Create a copy with modified fields.
  ///
  /// Uses factory constructor to ensure list immutability.
  FilterState copyWith({
    List<String>? selectedTagIds,
    FilterLogic? logic,
    TagPresenceFilter? presenceFilter,
  }) {
    // Factory constructor handles List.unmodifiable
    return FilterState(
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      logic: logic ?? this.logic,
      presenceFilter: presenceFilter ?? this.presenceFilter,
    );
  }

  /// Serialize to JSON for future persistence (Phase 6+).
  Map<String, dynamic> toJson() => {
        'selectedTagIds': selectedTagIds,
        'logic': logic.name,
        'presenceFilter': presenceFilter.name,
      };

  /// Deserialize from JSON for future persistence (Phase 6+).
  ///
  /// Factory constructor ensures list immutability.
  factory FilterState.fromJson(Map<String, dynamic> json) {
    return FilterState(
      selectedTagIds: List<String>.from(json['selectedTagIds'] ?? []),
      logic: FilterLogic.values.byName(json['logic'] ?? 'or'),
      presenceFilter: TagPresenceFilter.values.byName(
        json['presenceFilter'] ?? 'any',
      ),
    );
  }

  // Equality implementation for early-return optimization in setFilter
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterState &&
          listEquals(selectedTagIds, other.selectedTagIds) &&
          logic == other.logic &&
          presenceFilter == other.presenceFilter;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(selectedTagIds),
        logic,
        presenceFilter,
      );

  @override
  String toString() => 'FilterState('
      'tags: $selectedTagIds, '
      'logic: $logic, '
      'presence: $presenceFilter'
      ')';
}

/// Logic for combining multiple tag filters.
enum FilterLogic {
  /// Show tasks with ANY of the selected tags (OR logic).
  or,

  /// Show tasks with ALL of the selected tags (AND logic).
  and,
}

/// Filter by tag presence (has tags vs no tags).
///
/// Prevents impossible combinations like "show tasks with no tags AND the 'Work' tag".
enum TagPresenceFilter {
  /// No filter by tag presence (default).
  any,

  /// Show only tasks that have at least one tag.
  onlyTagged,

  /// Show only tasks that have no tags.
  onlyUntagged,
}
```

**Why this design:**
- `List.unmodifiable` prevents accidental mutations that break immutability
- `==` and `hashCode` enable early-return optimization in `setFilter`
- Enum for tag presence prevents impossible states at model layer
- `toJson`/`fromJson` added now for easy Phase 6+ persistence (no refactoring needed)
- Const constructor for default state (zero allocation)

---

#### TaskService Enhancements (`lib/services/task_service.dart`)

**New method:**
```dart
/// Get tasks matching the given filter.
///
/// The [completed] parameter controls which list to query (active or completed).
/// This ensures filtered results respect the active/completed distinction.
Future<List<Task>> getFilteredTasks(
  FilterState filter, {
  required bool completed,
}) async {
  final db = await database;

  // Base WHERE conditions (always apply)
  final baseConditions = [
    'tasks.deleted_at IS NULL',
    'tasks.completed = ?',
  ];
  final baseArgs = [completed ? 1 : 0];

  // Build query based on filter state
  String query;
  List<dynamic> args;

  if (filter.selectedTagIds.isNotEmpty) {
    // Specific tag filter
    if (filter.logic == FilterLogic.or) {
      // OR logic: tasks with ANY of the selected tags
      query = '''
        SELECT DISTINCT tasks.*
        FROM tasks
        INNER JOIN task_tags ON tasks.id = task_tags.task_id
        WHERE task_tags.tag_id IN (${List.filled(filter.selectedTagIds.length, '?').join(', ')})
          AND ${baseConditions.join(' AND ')}
        ORDER BY tasks.position;
      ''';
      args = [...filter.selectedTagIds, ...baseArgs];
    } else {
      // AND logic: tasks with ALL of the selected tags
      query = '''
        SELECT tasks.*
        FROM tasks
        WHERE tasks.id IN (
          SELECT task_id
          FROM task_tags
          WHERE tag_id IN (${List.filled(filter.selectedTagIds.length, '?').join(', ')})
          GROUP BY task_id
          HAVING COUNT(DISTINCT tag_id) = ?
        )
          AND ${baseConditions.join(' AND ')}
        ORDER BY tasks.position;
      ''';
      args = [...filter.selectedTagIds, filter.selectedTagIds.length, ...baseArgs];
    }
  } else if (filter.presenceFilter == TagPresenceFilter.onlyTagged) {
    // Show only tasks with at least one tag
    query = '''
      SELECT DISTINCT tasks.*
      FROM tasks
      INNER JOIN task_tags ON tasks.id = task_tags.task_id
      WHERE ${baseConditions.join(' AND ')}
      ORDER BY tasks.position;
    ''';
    args = baseArgs;
  } else if (filter.presenceFilter == TagPresenceFilter.onlyUntagged) {
    // Show only tasks with no tags
    query = '''
      SELECT tasks.*
      FROM tasks
      WHERE tasks.id NOT IN (
        SELECT DISTINCT task_id
        FROM task_tags
      )
        AND ${baseConditions.join(' AND ')}
      ORDER BY tasks.position;
    ''';
    args = baseArgs;
  } else {
    // No filter active - shouldn't happen, but handle gracefully
    return getTasks(completed: completed);
  }

  final maps = await db.rawQuery(query, args);
  return maps.map((map) => Task.fromMap(map)).toList();
}
```

**Why this approach:**
- ✅ `completed` parameter ensures active/completed separation
- ✅ All queries include `deleted_at IS NULL` (never show deleted tasks)
- ✅ All queries include `completed = ?` (respect active/completed scope)
- ✅ Efficient SQL with proper indexes (see Database Indexes section)
- ✅ Clear separation of OR vs AND vs presence filter logic

**Alternative considered:** Single query with dynamic WHERE clauses
- **Rejected:** Harder to read, test, and optimize
- **Chosen:** Explicit branches for each filter type (clearer intent)

---

### 2. Tag Counting

#### TagService Enhancement (`lib/services/tag_service.dart`)

**FIX #2 (Codex v2): Preload tag counts with single query**

Problem: Using FutureBuilder per tag in the dialog creates N+1 query problem.

**New method:**
```dart
/// Get task counts for all tags in a single query.
///
/// Returns a map of tag ID → task count.
/// Only counts non-deleted tasks matching the completed status.
///
/// FIX #2: Prevents N+1 query problem when opening TagFilterDialog.
Future<Map<String, int>> getTaskCountsByTag({required bool completed}) async {
  final db = await database;

  final result = await db.rawQuery('''
    SELECT
      task_tags.tag_id,
      COUNT(DISTINCT tasks.id) as task_count
    FROM task_tags
    INNER JOIN tasks ON tasks.id = task_tags.task_id
    WHERE tasks.deleted_at IS NULL
      AND tasks.completed = ?
    GROUP BY task_tags.tag_id
  ''', [completed ? 1 : 0]);

  return Map.fromEntries(
    result.map((row) => MapEntry(
      row['tag_id'] as String,
      row['task_count'] as int,
    )),
  );
}
```

**Why this is better:**
- ONE database query instead of N queries (where N = number of tags)
- Loads instantly even with 100+ tags
- No FutureBuilder in build method (cleaner code)

**Performance:**
- Current approach: 50 tags × 5ms = 250ms dialog open time
- Fixed approach: 1 query × 10ms = 10ms dialog open time (25× faster!)

---

### 3. State Management

#### TaskProvider Enhancements (`lib/providers/task_provider.dart`)

**New fields and methods:**
```dart
class TaskProvider extends ChangeNotifier {
  final TaskService _taskService;
  final TagService _tagService;

  List<Task> _tasks = [];
  List<Task> _completedTasks = [];

  // NEW: Filter state
  FilterState _filterState = const FilterState();

  // NEW: Operation ID for race condition prevention
  int _filterOperationId = 0;

  // Existing getters...
  List<Task> get tasks => _tasks;
  List<Task> get completedTasks => _completedTasks;

  // NEW: Filter state getters
  FilterState get filterState => _filterState;
  bool get hasActiveFilters => _filterState.isActive;

  // NEW: Set filter (with race condition prevention)
  /// Apply a new filter to the task lists.
  ///
  /// Uses an operation ID pattern to prevent race conditions when the user
  /// changes filters rapidly. Only the most recent operation's results are applied.
  ///
  /// Updates both active and completed task lists to maintain global filter consistency.
  ///
  /// FIX #4 (Codex v2): Rollback filter state on error to keep UI consistent.
  Future<void> setFilter(FilterState filter) async {
    // Early return if filter unchanged (equality check)
    if (_filterState == filter) return;

    // FIX #4: Capture previous state for rollback on error
    final previousFilter = _filterState;

    _filterState = filter;
    _filterOperationId++; // Increment before async work
    final currentOperation = _filterOperationId;

    notifyListeners(); // Show filter bar immediately (optimistic update)

    try {
      if (filter.isActive) {
        // Fetch filtered results for both lists
        final activeFuture = _taskService.getFilteredTasks(
          filter,
          completed: false,
        );
        final completedFuture = _taskService.getFilteredTasks(
          filter,
          completed: true,
        );

        // Await both queries in parallel
        final results = await Future.wait([activeFuture, completedFuture]);

        // Only apply results if no newer operation started
        if (currentOperation == _filterOperationId) {
          _tasks = results[0];
          _completedTasks = results[1];
          notifyListeners();
        }
        // Else discard stale results (newer filter already applied)
      } else {
        // No filter active - show all tasks
        await _refreshTasks();
      }
    } catch (e) {
      // FIX #4: Rollback to previous filter state on error
      _filterState = previousFilter;
      notifyListeners(); // Update UI to show previous filter

      debugPrint('Error applying filter: $e');
      // TODO: Show error to user via Snackbar
      // (Requires passing callback or using global messenger key)
    }
  }

  // NEW: Add single tag to filter
  /// Add a tag to the current filter.
  ///
  /// Validates the tag ID and prevents duplicates.
  /// Used when user clicks a tag chip for quick filtering.
  ///
  /// FIX #5 (Codex v2): Validate tag existence to prevent SQL errors.
  Future<void> addTagFilter(String tagId) async {
    // Validate input
    if (tagId.isEmpty) {
      debugPrint('addTagFilter: empty tagId');
      return;
    }

    if (_filterState.selectedTagIds.contains(tagId)) {
      debugPrint('addTagFilter: tag $tagId already in filter');
      return; // Already filtered by this tag
    }

    // FIX #5: Validate tag exists in database
    final tag = await _tagService.getTag(tagId);
    if (tag == null) {
      debugPrint('addTagFilter: tag $tagId does not exist');
      return; // Reject invalid tag IDs
    }

    // Create new filter with added tag
    final newTags = List<String>.from(_filterState.selectedTagIds)..add(tagId);
    final newFilter = _filterState.copyWith(selectedTagIds: newTags);

    await setFilter(newFilter);
  }

  // NEW: Remove single tag from filter
  /// Remove a tag from the current filter.
  ///
  /// If no filters remain after removal, clears the filter entirely.
  Future<void> removeTagFilter(String tagId) async {
    final newTags = _filterState.selectedTagIds
        .where((id) => id != tagId)
        .toList();

    // If no filters left, clear entirely
    if (newTags.isEmpty && _filterState.presenceFilter == TagPresenceFilter.any) {
      await clearFilters();
    } else {
      final newFilter = _filterState.copyWith(selectedTagIds: newTags);
      await setFilter(newFilter);
    }
  }

  // NEW: Clear all filters
  /// Clear all filters and show all tasks.
  Future<void> clearFilters() async {
    await setFilter(const FilterState());
  }

  // MODIFIED: Ensure _refreshTasks updates both lists
  Future<void> _refreshTasks() async {
    _tasks = await _taskService.getTasks(completed: false);
    _completedTasks = await _taskService.getTasks(completed: true);
  }

  // Existing methods (addTask, updateTask, etc.) remain unchanged
  // ...
}
```

**Why this design:**
- ✅ Operation ID prevents race conditions (only latest results applied)
- ✅ Early return on duplicate filter (equality check optimization)
- ✅ Both `_tasks` and `_completedTasks` updated (global filter consistency)
- ✅ Validation in `addTagFilter` (prevents duplicates and invalid IDs)
- ✅ Clear error handling (try-catch, debug logging)
- ✅ Immediate UI feedback (`notifyListeners` before async work)

**Race condition example (now prevented):**
1. User taps "Work" chip → Operation ID = 1, starts query
2. User taps "Urgent" chip → Operation ID = 2, starts query
3. Query 2 finishes first → Checks operation ID (2 == 2) → Applies results
4. Query 1 finishes → Checks operation ID (1 != 2) → Discards stale results ✅

---

### 3. Database Indexes

**Required indexes** (should already exist from Phase 3.5, but verify):

```sql
-- Junction table indexes (critical for join performance)
CREATE INDEX IF NOT EXISTS idx_task_tags_task_id ON task_tags(task_id);
CREATE INDEX IF NOT EXISTS idx_task_tags_tag_id ON task_tags(tag_id);

-- Task table indexes
CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed);
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON tasks(deleted_at);
CREATE INDEX IF NOT EXISTS idx_tasks_position ON tasks(position);
```

**Query performance:**
- OR query: Uses `idx_task_tags_tag_id` + `idx_tasks_completed` + `idx_tasks_deleted_at`
- AND query: Uses `idx_task_tags_tag_id` for subquery, then task indexes
- Has tags: Uses `idx_task_tags_task_id` for join
- No tags: Uses `idx_task_tags_task_id` for NOT IN subquery

**Expected performance:**
- Filter update: <50ms for 1000 tasks with 10 tags
- No additional indexes needed (existing ones are optimal)

---

### 4. UI Components

#### New Widgets

**1. TagFilterDialog** (`lib/widgets/tag_filter_dialog.dart`)

```dart
import 'package:flutter/services.dart'; // For HapticFeedback

/// Dialog for advanced tag filtering with multi-select and logic options.
///
/// Features:
/// - Multi-select tag checkboxes
/// - Search field (preserves selection state across search changes)
/// - AND/OR logic toggle
/// - Tag presence radio buttons (mutually exclusive)
/// - Task count per tag
/// - Haptic feedback for interactions (UX polish)
class TagFilterDialog extends StatefulWidget {
  final FilterState initialFilter;
  final List<Tag> allTags;

  const TagFilterDialog({
    Key? key,
    required this.initialFilter,
    required this.allTags,
  }) : super(key: key);

  @override
  State<TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends State<TagFilterDialog> {
  late Set<String> _selectedTagIds; // Preserved across search changes
  late FilterLogic _logic;
  late TagPresenceFilter _presenceFilter;
  String _searchQuery = '';

  // FIX #2 (Codex v2): Preload tag counts instead of N×FutureBuilder
  Map<String, int> _tagCounts = {};
  bool _countsLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set.from(widget.initialFilter.selectedTagIds);
    _logic = widget.initialFilter.logic;
    _presenceFilter = widget.initialFilter.presenceFilter;

    // FIX #2: Load all tag counts in one query
    _loadTagCounts();
  }

  Future<void> _loadTagCounts() async {
    try {
      final tagService = context.read<TagService>();
      final counts = await tagService.getTaskCountsByTag(completed: false);

      if (mounted) {
        setState(() {
          _tagCounts = counts;
          _countsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tag counts: $e');
      if (mounted) {
        setState(() {
          _countsLoading = false;
        });
      }
    }
  }

  // Filter displayed tags based on search query
  List<Tag> get _displayedTags {
    if (_searchQuery.isEmpty) return widget.allTags;

    final query = _searchQuery.toLowerCase();
    return widget.allTags
        .where((tag) => tag.name.toLowerCase().contains(query))
        .toList();
  }

  // Check if specific tag selection should be disabled
  bool get _tagSelectionDisabled {
    return _presenceFilter == TagPresenceFilter.onlyUntagged;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search tags',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Tag presence filter (radio buttons)
            SegmentedButton<TagPresenceFilter>(
              segments: const [
                ButtonSegment(
                  value: TagPresenceFilter.any,
                  label: Text('Any'),
                ),
                ButtonSegment(
                  value: TagPresenceFilter.onlyTagged,
                  label: Text('Tagged'),
                ),
                ButtonSegment(
                  value: TagPresenceFilter.onlyUntagged,
                  label: Text('Untagged'),
                ),
              ],
              selected: {_presenceFilter},
              onSelectionChanged: (Set<TagPresenceFilter> selected) {
                setState(() {
                  _presenceFilter = selected.first;
                  // If "untagged" selected, clear specific tag selections
                  if (_presenceFilter == TagPresenceFilter.onlyUntagged) {
                    _selectedTagIds.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // AND/OR logic toggle
            if (_selectedTagIds.length > 1)
              SegmentedButton<FilterLogic>(
                segments: const [
                  ButtonSegment(
                    value: FilterLogic.or,
                    label: Text('ANY'),
                    tooltip: 'Show tasks with ANY selected tag',
                  ),
                  ButtonSegment(
                    value: FilterLogic.and,
                    label: Text('ALL'),
                    tooltip: 'Show tasks with ALL selected tags',
                  ),
                ],
                selected: {_logic},
                onSelectionChanged: (Set<FilterLogic> selected) {
                  setState(() {
                    _logic = selected.first;
                  });
                },
              ),
            const SizedBox(height: 16),

            // Tag list (scrollable)
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _displayedTags.length,
                itemBuilder: (context, index) {
                  final tag = _displayedTags[index];
                  final isChecked = _selectedTagIds.contains(tag.id);

                  return CheckboxListTile(
                    enabled: !_tagSelectionDisabled,
                    value: isChecked,
                    title: Text(tag.name),
                    // FIX #2: Direct access to preloaded counts (no FutureBuilder!)
                    subtitle: Text('${_tagCounts[tag.id] ?? 0} tasks'),
                    secondary: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(tag.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onChanged: _tagSelectionDisabled
                        ? null
                        : (bool? value) {
                            // UX POLISH: Light haptic feedback for checkbox toggle
                            HapticFeedback.lightImpact();

                            setState(() {
                              if (value == true) {
                                _selectedTagIds.add(tag.id);
                              } else {
                                _selectedTagIds.remove(tag.id);
                              }
                            });
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Cancel
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // UX POLISH: Medium haptic feedback for major action
            HapticFeedback.mediumImpact();

            final filter = FilterState(
              selectedTagIds: _selectedTagIds.toList(),
              logic: _logic,
              presenceFilter: _presenceFilter,
            );
            Navigator.pop(context, filter);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  // FIX #2: Removed _getTaskCount method - no longer needed!
  // Tag counts are now preloaded in initState with a single query.
}
```

**Key features:**
- ✅ Search preserves selection state (uses Set<String>, not widget state)
- ✅ Mutually exclusive tag presence (radio buttons)
- ✅ Disables specific tags when "untagged" selected (prevents contradictions)
- ✅ Shows AND/OR toggle only when multiple tags selected
- ✅ Tag count per tag (preloaded with single query - FIX #2)
- ✅ Haptic feedback: Light impact for checkboxes, medium impact for Apply (tactile response)

**FIX #3 (Codex v2): "Tagged" option semantics clarified:**

The "Tagged" option can be used in two ways:
1. **With specific tags selected:** Filters to tasks with those specific tags (redundant but harmless)
2. **Without specific tags:** Filters to tasks with ANY tag (useful! Shows all categorized tasks)

This is actually a useful query: "Show me everything I've categorized" without caring which specific tags.

**SQL behavior:**
- `presenceFilter == onlyTagged` + `selectedTagIds.isEmpty` → Uses "has tags" query
- `presenceFilter == onlyTagged` + `selectedTagIds.isNotEmpty` → Uses specific tag query (with AND/OR logic)

**UI note:** We don't disable "Tagged" when no tags selected because it's a valid, useful filter.

---

**2. ActiveFilterBar** (`lib/widgets/active_filter_bar.dart`)

```dart
import 'package:flutter/services.dart'; // For HapticFeedback

/// Displays active filters below the app bar.
///
/// Shows selected tags as chips with remove buttons.
/// "Clear All" button is pinned on the right and doesn't scroll.
/// Provides haptic feedback for Clear All action (UX polish).
class ActiveFilterBar extends StatelessWidget {
  final FilterState filterState;
  final List<Tag> allTags;
  final VoidCallback onClearAll;
  final void Function(String tagId) onRemoveTag;

  const ActiveFilterBar({
    Key? key,
    required this.filterState,
    required this.allTags,
    required this.onClearAll,
    required this.onRemoveTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!filterState.isActive) {
      return const SizedBox.shrink(); // Hide when no filters
    }

    // UX POLISH: Filter out ghost tags (deleted tags that are still in filter state)
    // Instead of showing "Unknown", we hide them gracefully (self-healing UI)
    final validTagIds = filterState.selectedTagIds
        .where((id) => allTags.any((t) => t.id == id))
        .toList();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Scrollable tag chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Tag chips (only valid tags)
                  for (final tagId in validTagIds) ...[
                    _buildTagChip(context, tagId),
                    const SizedBox(width: 8),
                  ],

                  // Presence filter indicator
                  if (filterState.presenceFilter != TagPresenceFilter.any) ...[
                    _buildPresenceChip(context),
                    const SizedBox(width: 8),
                  ],

                  // Logic indicator (if multiple tags)
                  if (filterState.selectedTagIds.length > 1) ...[
                    _buildLogicIndicator(context),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),

          // Pinned "Clear All" button (doesn't scroll)
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              // UX POLISH: Medium haptic feedback for major action
              HapticFeedback.mediumImpact();
              onClearAll();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String tagId) {
    // Safe to use firstWhere without orElse since we filtered validTagIds above
    final tag = allTags.firstWhere((t) => t.id == tagId);

    return Chip(
      label: Text(tag.name),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: () => onRemoveTag(tagId),
      backgroundColor: Color(tag.color).withOpacity(0.2),
      side: BorderSide(color: Color(tag.color)),
    );
  }

  Widget _buildPresenceChip(BuildContext context) {
    final label = filterState.presenceFilter == TagPresenceFilter.onlyTagged
        ? 'Has tags'
        : 'No tags';

    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  Widget _buildLogicIndicator(BuildContext context) {
    final label = filterState.logic == FilterLogic.and ? 'ALL' : 'ANY';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
```

**Key features:**
- ✅ "Clear All" pinned on right (doesn't scroll off screen)
- ✅ Shows tag chips, presence filter, and logic indicator
- ✅ Material 3 design with proper elevation and colors
- ✅ Hides automatically when no filters active
- ✅ Ghost tag handling: Hides deleted tags gracefully instead of showing "Unknown" (self-healing UI)
- ✅ Haptic feedback: Medium impact for Clear All (tactile response)

---

**3. FilterableTagChip** (Enhancement to existing CompactTagChip)

```dart
/// Extends CompactTagChip with tap-to-filter functionality.
///
/// Used in task list to enable quick filtering by tapping a tag.
class FilterableTagChip extends StatelessWidget {
  final Tag tag;
  final bool isFiltered; // True if this tag is in active filter
  final VoidCallback onTap;

  const FilterableTagChip({
    Key? key,
    required this.tag,
    required this.isFiltered,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CompactTagChip(
        tag: tag,
        isSelected: isFiltered, // Visual feedback
      ),
    );
  }
}
```

**Usage in task list:**
```dart
FilterableTagChip(
  tag: tag,
  isFiltered: taskProvider.filterState.selectedTagIds.contains(tag.id),
  onTap: () => taskProvider.addTagFilter(tag.id),
)
```

---

#### Modified Widgets

**TaskListScreen** (`lib/screens/task_list_screen.dart`)

```dart
class _TaskListScreenState extends State<TaskListScreen> {
  late ScrollController _scrollController;
  FilterState? _previousFilterState;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _previousFilterState = context.read<TaskProvider>().filterState;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // UX POLISH: Reset scroll position when filter changes
  // Prevents user from staring at empty space if they were scrolled down
  void _checkFilterChange(TaskProvider taskProvider) {
    if (_previousFilterState != taskProvider.filterState) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0); // Reset to top
      }
      _previousFilterState = taskProvider.filterState;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final tagProvider = context.watch<TagProvider>();

    // Check for filter changes and reset scroll if needed
    _checkFilterChange(taskProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          // Filter button with badge
          IconButton(
            icon: Badge(
              isLabelVisible: taskProvider.hasActiveFilters,
              child: const Icon(Icons.filter_alt),
            ),
            tooltip: 'Filter tasks',
            onPressed: () => _showFilterDialog(context),
          ),
          // ... other actions
        ],
      ),
      body: Column(
        children: [
          // Active filter bar (shows when filters applied)
          ActiveFilterBar(
            filterState: taskProvider.filterState,
            allTags: tagProvider.tags,
            onClearAll: () => taskProvider.clearFilters(),
            onRemoveTag: (tagId) => taskProvider.removeTagFilter(tagId),
          ),

          // Task list with scroll controller
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Use our scroll controller
              itemCount: taskProvider.tasks.length,
              itemBuilder: (context, index) {
                // ... task item builder
              },
            ),
          ),
        ],
      ),
    );
  }

  // Filter dialog handler
  Future<void> _showFilterDialog(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();
    final tagProvider = context.read<TagProvider>();

    final result = await showDialog<FilterState>(
      context: context,
      builder: (_) => TagFilterDialog(
        initialFilter: taskProvider.filterState,
        allTags: tagProvider.tags,
      ),
    );

    // Check context is still mounted after async operation
    if (result != null && context.mounted) {
      await taskProvider.setFilter(result);
      // Scroll reset happens automatically in _checkFilterChange
    }
  }
}
```

**CompletedTasksScreen** - Same changes as TaskListScreen (shared global filter)

---

### 5. UI/UX Details

**Filter Icon:**
- Material Icons: `Icons.filter_alt` (funnel shape)
- Badge indicator when filters active (small dot)
- Positioned in app bar (top right, before settings)
- Tooltip: "Filter tasks"

**Active Filter Bar:**
- Background: `Theme.colorScheme.surfaceContainerHighest`
- Height: 56px (compact)
- Padding: 16px horizontal, 8px vertical
- Chip spacing: 8px
- "Clear All" button: TextButton, pinned on right
- Subtle shadow for depth

**Tag Chip States:**
- Normal: Tag color with 20% opacity background, solid border
- Filtered (selected): Full color background, elevated appearance
- Disabled: Grayed out (when tag presence is "untagged")

**Tag Presence Filter:**
- SegmentedButton with 3 options: Any / Tagged / Untagged
- Default: Any (no filter)
- Tooltips:
  - Any: "Show all tasks"
  - Tagged: "Show only tasks with at least one tag"
  - Untagged: "Show only tasks without any tags"

**AND/OR Toggle:**
- SegmentedButton: `[ANY] [ALL]`
- Only visible when 2+ tags selected
- Default: ANY (OR logic - most intuitive)
- Tooltips:
  - ANY: "Show tasks with ANY selected tag"
  - ALL: "Show tasks with ALL selected tags"

**Empty Results State:**
```dart
if (tasks.isEmpty && hasActiveFilters) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.filter_alt_off,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'No tasks match your filters',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.tonal(
          onPressed: () => taskProvider.clearFilters(),
          child: const Text('Clear Filters'),
        ),
      ],
    ),
  );
}
```

---

## Testing Strategy

### Unit Tests

**FilterState Tests** (`test/models/filter_state_test.dart`)
```dart
void main() {
  group('FilterState', () {
    test('default state is not active', () {
      const filter = FilterState();
      expect(filter.isActive, false);
    });

    test('isActive when tags selected', () {
      const filter = FilterState(selectedTagIds: ['tag1']);
      expect(filter.isActive, true);
    });

    test('isActive when presence filter set', () {
      const filter = FilterState(presenceFilter: TagPresenceFilter.onlyTagged);
      expect(filter.isActive, true);
    });

    test('copyWith creates new instance with modified fields', () {
      const original = FilterState(logic: FilterLogic.or);
      final modified = original.copyWith(logic: FilterLogic.and);

      expect(modified.logic, FilterLogic.and);
      expect(original.logic, FilterLogic.or); // Original unchanged
    });

    test('copyWith clones list (immutability)', () {
      const original = FilterState(selectedTagIds: ['tag1']);
      final modified = original.copyWith(selectedTagIds: ['tag2']);

      expect(modified.selectedTagIds, ['tag2']);
      expect(original.selectedTagIds, ['tag1']); // Original unchanged
    });

    test('equality works correctly', () {
      const filter1 = FilterState(selectedTagIds: ['tag1'], logic: FilterLogic.or);
      const filter2 = FilterState(selectedTagIds: ['tag1'], logic: FilterLogic.or);
      const filter3 = FilterState(selectedTagIds: ['tag2'], logic: FilterLogic.or);

      expect(filter1, equals(filter2));
      expect(filter1, isNot(equals(filter3)));
    });

    test('toJson/fromJson round trip', () {
      const original = FilterState(
        selectedTagIds: ['tag1', 'tag2'],
        logic: FilterLogic.and,
        presenceFilter: TagPresenceFilter.onlyTagged,
      );

      final json = original.toJson();
      final restored = FilterState.fromJson(json);

      expect(restored, equals(original));
    });
  });
}
```

**TaskService Filter Tests** (`test/services/task_service_filter_test.dart`)
```dart
void main() {
  late TaskService taskService;
  late Database db;

  setUp(() async {
    // Create in-memory database for testing
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 6,
      onCreate: (db, version) async {
        // Create schema (tasks, tags, task_tags tables)
        // ...
      },
    );
    taskService = TaskService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getFilteredTasks', () {
    test('OR logic returns tasks with ANY selected tag', () async {
      // Setup: Create tasks with tags
      await _createTask(db, 'task1', tags: ['work', 'urgent']);
      await _createTask(db, 'task2', tags: ['work']);
      await _createTask(db, 'task3', tags: ['urgent']);
      await _createTask(db, 'task4', tags: ['personal']);

      // Filter by 'work' OR 'urgent'
      const filter = FilterState(
        selectedTagIds: ['work', 'urgent'],
        logic: FilterLogic.or,
      );

      final results = await taskService.getFilteredTasks(filter, completed: false);

      // Should return tasks 1, 2, 3 (all have 'work' or 'urgent')
      expect(results.length, 3);
      expect(results.map((t) => t.title), containsAll(['task1', 'task2', 'task3']));
    });

    test('AND logic returns tasks with ALL selected tags', () async {
      // Setup: Create tasks with tags
      await _createTask(db, 'task1', tags: ['work', 'urgent']);
      await _createTask(db, 'task2', tags: ['work']);
      await _createTask(db, 'task3', tags: ['urgent']);

      // Filter by 'work' AND 'urgent'
      const filter = FilterState(
        selectedTagIds: ['work', 'urgent'],
        logic: FilterLogic.and,
      );

      final results = await taskService.getFilteredTasks(filter, completed: false);

      // Should return only task1 (has both tags)
      expect(results.length, 1);
      expect(results.first.title, 'task1');
    });

    test('onlyTagged returns tasks with at least one tag', () async {
      await _createTask(db, 'task1', tags: ['work']);
      await _createTask(db, 'task2', tags: []);

      const filter = FilterState(presenceFilter: TagPresenceFilter.onlyTagged);

      final results = await taskService.getFilteredTasks(filter, completed: false);

      expect(results.length, 1);
      expect(results.first.title, 'task1');
    });

    test('onlyUntagged returns tasks with no tags', () async {
      await _createTask(db, 'task1', tags: ['work']);
      await _createTask(db, 'task2', tags: []);

      const filter = FilterState(presenceFilter: TagPresenceFilter.onlyUntagged);

      final results = await taskService.getFilteredTasks(filter, completed: false);

      expect(results.length, 1);
      expect(results.first.title, 'task2');
    });

    test('respects completed parameter', () async {
      await _createTask(db, 'active', tags: ['work'], completed: false);
      await _createTask(db, 'done', tags: ['work'], completed: true);

      const filter = FilterState(selectedTagIds: ['work']);

      final active = await taskService.getFilteredTasks(filter, completed: false);
      final completed = await taskService.getFilteredTasks(filter, completed: true);

      expect(active.length, 1);
      expect(active.first.title, 'active');
      expect(completed.length, 1);
      expect(completed.first.title, 'done');
    });

    test('never returns deleted tasks', () async {
      await _createTask(db, 'task1', tags: ['work'], deleted: false);
      await _createTask(db, 'task2', tags: ['work'], deleted: true);

      const filter = FilterState(selectedTagIds: ['work']);

      final results = await taskService.getFilteredTasks(filter, completed: false);

      expect(results.length, 1);
      expect(results.first.title, 'task1');
    });

    test('performance: <50ms for 1000 tasks', () async {
      // Create 1000 tasks with various tags
      for (int i = 0; i < 1000; i++) {
        await _createTask(db, 'task$i', tags: ['tag${i % 10}']);
      }

      const filter = FilterState(selectedTagIds: ['tag1', 'tag2', 'tag3']);

      final stopwatch = Stopwatch()..start();
      await taskService.getFilteredTasks(filter, completed: false);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
```

### Widget Tests

**TagFilterDialog Tests** (`test/widgets/tag_filter_dialog_test.dart`)
```dart
void main() {
  group('TagFilterDialog', () {
    testWidgets('displays all tags', (tester) async {
      final tags = [
        Tag(id: '1', name: 'Work', color: 0xFF0000FF),
        Tag(id: '2', name: 'Personal', color: 0xFF00FF00),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagFilterDialog(
            initialFilter: const FilterState(),
            allTags: tags,
          ),
        ),
      ));

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('preserves selection across search changes', (tester) async {
      final tags = [
        Tag(id: '1', name: 'Work', color: 0xFF0000FF),
        Tag(id: '2', name: 'Workout', color: 0xFF00FF00),
        Tag(id: '3', name: 'Personal', color: 0xFFFF0000),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagFilterDialog(
            initialFilter: const FilterState(),
            allTags: tags,
          ),
        ),
      ));

      // Search for "Work"
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump();

      // Should show 2 results (Work, Workout)
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Personal'), findsNothing);

      // Check "Work"
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
      await tester.pump();

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // "Work" should still be checked in full list
      final workTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Work'),
      );
      expect(workTile.value, true);
    });

    testWidgets('disables tag selection when "untagged" selected', (tester) async {
      final tags = [Tag(id: '1', name: 'Work', color: 0xFF0000FF)];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagFilterDialog(
            initialFilter: const FilterState(),
            allTags: tags,
          ),
        ),
      ));

      // Select "Untagged"
      await tester.tap(find.text('Untagged'));
      await tester.pump();

      // Tag checkboxes should be disabled
      final workTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Work'),
      );
      expect(workTile.enabled, false);
    });

    testWidgets('shows AND/OR toggle when multiple tags selected', (tester) async {
      final tags = [
        Tag(id: '1', name: 'Work', color: 0xFF0000FF),
        Tag(id: '2', name: 'Urgent', color: 0xFF00FF00),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagFilterDialog(
            initialFilter: const FilterState(),
            allTags: tags,
          ),
        ),
      ));

      // Initially, no AND/OR toggle (0 tags selected)
      expect(find.text('ANY'), findsNothing);
      expect(find.text('ALL'), findsNothing);

      // Select first tag
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
      await tester.pump();

      // Still no toggle (only 1 tag)
      expect(find.text('ANY'), findsNothing);

      // Select second tag
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Urgent'));
      await tester.pump();

      // Now toggle should appear (2 tags)
      expect(find.text('ANY'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
    });

    testWidgets('returns correct filter on apply', (tester) async {
      final tags = [
        Tag(id: '1', name: 'Work', color: 0xFF0000FF),
        Tag(id: '2', name: 'Urgent', color: 0xFF00FF00),
      ];

      FilterState? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<FilterState>(
                  context: context,
                  builder: (_) => TagFilterDialog(
                    initialFilter: const FilterState(),
                    allTags: tags,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select tags
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Urgent'));
      await tester.pump();

      // Change to AND logic
      await tester.tap(find.text('ALL'));
      await tester.pump();

      // Apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Verify result
      expect(result, isNotNull);
      expect(result!.selectedTagIds, containsAll(['1', '2']));
      expect(result!.logic, FilterLogic.and);
    });
  });
}
```

**ActiveFilterBar Tests** (`test/widgets/active_filter_bar_test.dart`)
```dart
void main() {
  group('ActiveFilterBar', () {
    testWidgets('hides when no filters active', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActiveFilterBar(
            filterState: const FilterState(),
            allTags: [],
            onClearAll: () {},
            onRemoveTag: (_) {},
          ),
        ),
      ));

      expect(find.byType(ActiveFilterBar), findsOneWidget);
      expect(find.text('Clear All'), findsNothing); // Hidden
    });

    testWidgets('displays selected tags', (tester) async {
      final tags = [
        Tag(id: '1', name: 'Work', color: 0xFF0000FF),
        Tag(id: '2', name: 'Urgent', color: 0xFF00FF00),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActiveFilterBar(
            filterState: const FilterState(selectedTagIds: ['1', '2']),
            allTags: tags,
            onClearAll: () {},
            onRemoveTag: (_) {},
          ),
        ),
      ));

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
    });

    testWidgets('calls onRemoveTag when X tapped', (tester) async {
      final tags = [Tag(id: '1', name: 'Work', color: 0xFF0000FF)];
      String? removedTagId;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActiveFilterBar(
            filterState: const FilterState(selectedTagIds: ['1']),
            allTags: tags,
            onClearAll: () {},
            onRemoveTag: (tagId) => removedTagId = tagId,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removedTagId, '1');
    });

    testWidgets('Clear All button always visible (pinned)', (tester) async {
      final tags = List.generate(
        20,
        (i) => Tag(id: '$i', name: 'Tag$i', color: 0xFF0000FF),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActiveFilterBar(
            filterState: FilterState(
              selectedTagIds: List.generate(20, (i) => '$i'),
            ),
            allTags: tags,
            onClearAll: () {},
            onRemoveTag: (_) {},
          ),
        ),
      ));

      // "Clear All" should be visible even with many chips
      expect(find.text('Clear All'), findsOneWidget);

      // Should be able to scroll the chip area
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-500, 0));
      await tester.pump();

      // "Clear All" still visible after scrolling
      expect(find.text('Clear All'), findsOneWidget);
    });

    testWidgets('displays presence filter indicator', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActiveFilterBar(
            filterState: const FilterState(
              presenceFilter: TagPresenceFilter.onlyTagged,
            ),
            allTags: [],
            onClearAll: () {},
            onRemoveTag: (_) {},
          ),
        ),
      ));

      expect(find.text('Has tags'), findsOneWidget);
    });

    testWidgets('displays logic indicator for multiple tags', (tester) async {
      final tags = [
        Tag(id: '1', name: 'Work', color: 0xFF0000FF),
        Tag(id: '2', name: 'Urgent', color: 0xFF00FF00),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActiveFilterBar(
            filterState: const FilterState(
              selectedTagIds: ['1', '2'],
              logic: FilterLogic.and,
            ),
            allTags: tags,
            onClearAll: () {},
            onRemoveTag: (_) {},
          ),
        ),
      ));

      expect(find.text('ALL'), findsOneWidget);
    });

    testWidgets('hides ghost tags gracefully', (tester) async {
      // UX POLISH TEST: Ghost tag handling
      final tags = [
        Tag(id: '1', name: 'Work', color: 0xFF0000FF),
        // Note: Tag '2' is in filter state but not in allTags (deleted tag)
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActiveFilterBar(
            filterState: const FilterState(
              selectedTagIds: ['1', '2'], // '2' is a ghost tag
            ),
            allTags: tags,
            onClearAll: () {},
            onRemoveTag: (_) {},
          ),
        ),
      ));

      // Should only show 'Work', not an "Unknown" chip for tag '2'
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Unknown'), findsNothing);
    });
  });
}
```

### Integration Tests

**Filter Workflow Tests** (`test_driver/tag_filter_integration_test.dart`)
```dart
void main() {
  group('Tag Filtering Integration', () {
    testWidgets('click tag chip → filter by tag', (tester) async {
      // Launch app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Create a task with "Work" tag
      // ... (setup code)

      // Click "Work" tag chip on the task
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      // Should show filtered list (only tasks with "Work" tag)
      // Active filter bar should appear
      expect(find.text('Clear All'), findsOneWidget);
    });

    testWidgets('filter persists across active/completed navigation', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Apply filter on active screen
      // ... (apply "Work" filter)

      // Switch to completed tab
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // Filter should still be active
      expect(find.text('Clear All'), findsOneWidget);
      // Should show filtered completed tasks
    });

    testWidgets('clear filters returns to all tasks', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Apply filter
      // ... (apply filter)

      final filteredCount = tester.widgetList(find.byType(TaskItem)).length;

      // Clear filters
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      final allCount = tester.widgetList(find.byType(TaskItem)).length;

      // Should show more tasks (or same if all tasks had the tag)
      expect(allCount, greaterThanOrEqualTo(filteredCount));
      expect(find.text('Clear All'), findsNothing); // Filter bar hidden
    });

    testWidgets('AND vs OR logic works correctly', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Create test data:
      // - Task 1: Work, Urgent
      // - Task 2: Work
      // - Task 3: Urgent
      // - Task 4: Personal

      // Open filter dialog
      await tester.tap(find.byIcon(Icons.filter_alt));
      await tester.pumpAndSettle();

      // Select "Work" and "Urgent"
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Urgent'));
      await tester.pump();

      // Test OR logic (default)
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Should show tasks 1, 2, 3 (any with Work or Urgent)
      expect(tester.widgetList(find.byType(TaskItem)).length, 3);

      // Change to AND logic
      await tester.tap(find.byIcon(Icons.filter_alt));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALL'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Should show only task 1 (has both Work and Urgent)
      expect(tester.widgetList(find.byType(TaskItem)).length, 1);
    });

    testWidgets('rapid filter changes handled correctly', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Rapidly tap multiple tag chips
      await tester.tap(find.text('Work'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('Urgent'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      // Should show correct final state (all 3 tags filtered)
      expect(find.text('Work'), findsOneWidget); // In filter bar
      expect(find.text('Urgent'), findsOneWidget); // In filter bar
      expect(find.text('Personal'), findsOneWidget); // In filter bar
    });
  });
}
```

### Manual Testing

**Create manual test plan:** `docs/phase-3.6A/phase-3.6A-manual-test-plan.md`

Use template from `docs/templates/manual-test-plan-template.md`

**Test scenarios to include:**
1. Quick filter (tap tag chip)
2. Multi-tag filter with AND logic
3. Multi-tag filter with OR logic
4. Tag presence filters (has tags / no tags)
5. Filter bar interactions (remove tag, clear all)
6. Filter persistence across navigation
7. Empty results state
8. Performance with many tasks (100+)
9. Performance with many tags (50+)
10. Dialog search functionality
11. Race condition testing (rapid filter changes)
12. Active/completed separation

**Test on real device:** Galaxy S22 Ultra

---

## Implementation Plan

### Day 1-2: Core Infrastructure ✅ All Critical Fixes

**Day 1 Morning: FilterState Model**
- [ ] Create `lib/models/filter_state.dart`
- [ ] Implement FilterState class with:
  - ✅ `TagPresenceFilter` enum (prevents impossible states)
  - ✅ Equality override (`==` and `hashCode`)
  - ✅ `List.unmodifiable` in copyWith
  - ✅ `toJson`/`fromJson` methods
- [ ] Write unit tests for FilterState
  - [ ] Test isActive logic
  - [ ] Test copyWith (including list immutability)
  - [ ] Test equality comparison
  - [ ] Test toJson/fromJson round trip
  - [ ] Test enum values

**Day 1 Afternoon: TaskService**
- [ ] Add `getFilteredTasks` method to TaskService
- [ ] Implement all SQL queries with:
  - ✅ `completed` parameter (active/completed separation)
  - ✅ `deleted_at IS NULL` check
  - ✅ Proper position ordering
- [ ] Verify database indexes exist
- [ ] Write unit tests for TaskService
  - [ ] Test OR logic
  - [ ] Test AND logic
  - [ ] Test onlyTagged filter
  - [ ] Test onlyUntagged filter
  - [ ] Test completed parameter
  - [ ] Test deleted_at filtering
  - [ ] Performance test (1000 tasks)

**Day 2 Morning: TaskProvider**
- [ ] Add filter state to TaskProvider
- [ ] Implement `setFilter` with:
  - ✅ Operation ID pattern (race condition prevention)
  - ✅ Equality check early return
  - ✅ Update both _tasks and _completedTasks
  - ✅ Try-catch error handling
- [ ] Implement `addTagFilter` with:
  - ✅ Validation (empty check, duplicate check)
- [ ] Implement `removeTagFilter`
- [ ] Implement `clearFilters`
- [ ] Write unit tests for TaskProvider
  - [ ] Test setFilter operation ID pattern
  - [ ] Test addTagFilter validation
  - [ ] Test removeTagFilter logic
  - [ ] Test clearFilters
  - [ ] Test race condition scenarios

**Day 2 Afternoon: TagService Enhancement**
- [ ] Add `getTaskCountByTag` method (for dialog task counts)
- [ ] Write unit tests

---

### Day 3-4: UI Components

**Day 3 Morning: TagFilterDialog**
- [ ] Create `lib/widgets/tag_filter_dialog.dart`
- [ ] Implement with:
  - ✅ Search field (preserves selection in Set<String>)
  - ✅ Tag presence radio buttons (mutually exclusive)
  - ✅ Disable specific tags when "untagged" selected
  - ✅ AND/OR toggle (only visible with 2+ tags)
  - ✅ Task count per tag
- [ ] Write widget tests
  - [ ] Test search preserves selection ✅
  - [ ] Test tag presence mutual exclusivity
  - [ ] Test AND/OR toggle visibility
  - [ ] Test apply button returns correct filter

**Day 3 Afternoon: ActiveFilterBar**
- [ ] Create `lib/widgets/active_filter_bar.dart`
- [ ] Implement with:
  - ✅ Pinned "Clear All" button (doesn't scroll)
  - ✅ Tag chips with remove buttons
  - ✅ Presence filter indicator
  - ✅ Logic indicator (AND/ALL)
- [ ] Write widget tests
  - [ ] Test hides when no filters
  - [ ] Test displays tags correctly
  - [ ] Test "Clear All" always visible ✅
  - [ ] Test remove tag callback

**Day 4: FilterableTagChip**
- [ ] Enhance CompactTagChip with tap handler
- [ ] Add visual state for filtered tags
- [ ] Write widget tests
- [ ] Polish animations and transitions

---

### Day 5: Integration

**Morning: TaskListScreen**
- [ ] Add filter icon to app bar (with badge)
- [ ] Add ActiveFilterBar below app bar
- [ ] Wire up filter dialog
- [ ] Handle context.mounted after async
- [ ] Test quick filter (tap chip)

**Afternoon: CompletedTasksScreen**
- [ ] Apply same changes as TaskListScreen
- [ ] Test global filter behavior
- [ ] Verify both lists update correctly

---

### Day 6: Testing & Polish

**Morning: Integration Tests**
- [ ] Write tag_filter_integration_test.dart
  - [ ] Quick filter flow
  - [ ] Multi-tag filter (AND/OR)
  - [ ] Filter persistence across navigation
  - [ ] Clear filters
  - [ ] Rapid filter changes (race condition test)

**Afternoon: Manual Testing**
- [ ] Create phase-3.6A-manual-test-plan.md
- [ ] Execute test plan on Galaxy S22 Ultra
- [ ] Test performance with 100+ tasks
- [ ] Test all edge cases
- [ ] Fix any bugs found

---

### Day 7: Validation & Documentation

**Morning: Final Validation**
- [ ] Run all automated tests (unit + widget + integration)
- [ ] Re-run manual test plan
- [ ] Performance benchmarking
- [ ] Fix any remaining bugs

**Afternoon: Documentation**
- [ ] Create phase-3.6A-validation-v1.md
- [ ] Update PROJECT_SPEC.md (mark Phase 3.6A complete)
- [ ] Update README.md (if needed)
- [ ] Create summary document
- [ ] Prepare for merge to main

---

## Database Changes

**None required!** ✅

- All data exists (tags table, task_tags junction table)
- Queries use existing schema
- Indexes already exist from Phase 3.5
- No migration needed
- Database version stays at v6

---

## Success Criteria

**Must have (blocking for completion):**
- ✅ Click any tag chip → immediately filters by that tag
- ✅ Tag filter dialog shows all tags with task counts
- ✅ Can filter by multiple tags (AND/OR logic works correctly)
- ✅ Active filter bar shows selected tags
- ✅ "Clear All" button always visible (pinned on right)
- ✅ Can remove individual filters or clear all
- ✅ Filters work on both active and completed tasks
- ✅ Active/completed distinction preserved (completed parameter)
- ✅ "Has tags" / "No tags" filters work (mutually exclusive)
- ✅ No race conditions (operation ID pattern)
- ✅ Equality optimization (no duplicate queries)
- ✅ Immutable FilterState (no accidental mutations)
- ✅ Validation prevents duplicates/invalid IDs
- ✅ Performance: Filter updates in <50ms for 1000 tasks
- ✅ All tests passing (unit + widget + integration)

**Nice to have (included in v2):**
- ✅ toJson/fromJson for future persistence
- ✅ Dialog search preserves selection
- ✅ Clear All button pinned (UX polish)

**UX polish (included in v2.1 from Gemini feedback):**
- ✅ Scroll position resets to top when filter changes (prevents disorienting UX)
- ✅ Ghost tag handling: Deleted tags hidden gracefully in ActiveFilterBar
- ✅ Haptic feedback for filter interactions (checkboxes, Apply, Clear All)

**Out of Scope (deferred to future):**
- ❌ Filter state persistence (deferred - no auto-save)
- ❌ Saved filter views/presets (deferred to Phase 6+)
- ❌ Default view preference setting (deferred to Phase 6+)

---

## Dependencies

**Existing packages:**
- ✅ provider (state management)
- ✅ sqflite (database queries)
- ✅ flutter (Material 3 widgets)

**No new package dependencies required!**

---

## Risks & Mitigation

**Risk 1: Complex SQL queries for AND logic**
- ✅ Mitigated: Thorough unit tests with various tag combinations
- ✅ Mitigated: Performance tests with 1000+ tasks
- ✅ Mitigated: Proper indexes verified

**Risk 2: Filter state management complexity**
- ✅ Mitigated: Immutable FilterState with equality semantics
- ✅ Mitigated: Operation ID pattern for race conditions
- ✅ Mitigated: Clear separation of concerns (model/service/provider)

**Risk 3: UI clutter with many active filters**
- ✅ Mitigated: Active filter bar is scrollable
- ✅ Mitigated: "Clear All" button pinned and always visible
- ✅ Mitigated: Compact design (56px height)

**Risk 4: User confusion about AND vs OR**
- ✅ Mitigated: Clear labels and tooltips
- ✅ Mitigated: Default to OR (more intuitive)
- ✅ Mitigated: Only show toggle when 2+ tags selected
- ✅ Mitigated: Manual testing with real user (BlueKitty!)

**Risk 5: Impossible filter combinations**
- ✅ Mitigated: TagPresenceFilter enum (prevents impossible states)
- ✅ Mitigated: UI disables contradictory options
- ✅ Mitigated: Model layer validation

**Risk 6: Race conditions from rapid filter changes**
- ✅ Mitigated: Operation ID pattern implemented
- ✅ Mitigated: Integration test for rapid changes
- ✅ Mitigated: Manual testing scenario included

---

## Open Questions

**All questions answered!** ✅

1. ✅ **ANSWERED:** Should filter state persist across app restarts?
   - **Decision:** NO auto-persistence (filters clear on app restart)
   - **Future:** Saved filter views/presets with dropdown selection (deferred to Phase 6+)
   - **Future:** User preference for default task list view (deferred to Phase 6+)
   - **Rationale:** Keep Phase 3.6A focused on core filtering; saved views need dedicated UX design
   - See: `docs/future/future.md` - "Filter & View Management" section

2. ✅ **ANSWERED:** Should we show a "no results" message when filters return empty?
   - **Decision:** YES - Show "No tasks match your filters" with "Clear filters" button
   - Better UX than empty screen with no context

3. ✅ **ANSWERED:** What icon for the filter button?
   - **Decision:** `Icons.filter_alt` (funnel shape icon)
   - **Rationale:** Classic filter shape, clearer than hamburger lines or tag icon
   - **Note:** Hamburger icon (≡) for reorder mode is also confusing - will replace in future UX polish phase

4. ✅ **ANSWERED:** Tag presence approach?
   - **Decision:** Option A (enum)
   - **Rationale:** Prevents impossible states at model layer, clearer logic

5. ✅ **ANSWERED:** Include nice-to-have improvements?
   - **Decision:** YES - All approved (toJson/fromJson, pinned Clear All, dialog search test)
   - **Rationale:** Low effort, high future value / UX polish

---

## References

**Planning Documents:**
- `docs/phase-03-final-plan.md` - Overall Phase 3.6 plan
- `docs/PROJECT_SPEC.md` - Phase 3.6A scope (lines 456-466)
- `docs/phase-3.6A/phase-3.6A-ultrathink.md` - Comprehensive pre-implementation analysis (700+ lines)
- `docs/phase-3.6A/review-analysis.md` - Review findings and fixes
- `docs/phase-3.6A/gemini-findings.md` - Gemini review (SQL/performance)
- `docs/phase-3.6A/codex-findings.md` - Codex review (bugs/correctness)

**Previous Phase:**
- `archive/phase-03/phase-3.5-summary.md` - Phase 3.5 learnings
- `archive/phase-03/phase-3.5-fix-c3-validation-summary.md` - Validation results

**Code Reference:**
- `lib/services/tag_service.dart` - Existing tag loading logic
- `lib/providers/tag_provider.dart` - Tag state management
- `lib/widgets/compact_tag_chip.dart` - Existing tag chip widget

---

## Review Feedback Incorporated

**From Gemini (SQL/Performance Expert):**
- ✅ Added `completed` parameter to all SQL queries
- ✅ Verified index strategy sufficient
- ✅ Added toJson/fromJson for future persistence
- ✅ Pinned "Clear All" button in ActiveFilterBar
- ✅ Added dialog search + selection state test

**From Codex (Bug Detection Expert):**
- ✅ Implemented operation ID pattern (race condition prevention)
- ✅ Added equality override to FilterState
- ✅ Used List.unmodifiable in copyWith
- ✅ Changed to TagPresenceFilter enum
- ✅ Added validation to addTagFilter
- ✅ Update both _tasks and _completedTasks in setFilter
- ✅ Added error handling in setFilter

**Thank you, Gemini and Codex!** 🙏
Your v1 reviews caught 7 bugs and 4 improvements that would have caused production issues.
Your v2 reviews caught 5 additional hardening issues and provided 3 UX polish suggestions.

---

**Status:** ✅ Ready for implementation (v3 with all review fixes)
**Next Step:** Begin Day 1 implementation

---

**Document Version:** 3.0
**Created By:** Claude
**Date:** 2026-01-09
**Review Status:** Approved by Gemini + Codex (v1 + v2 reviews)
