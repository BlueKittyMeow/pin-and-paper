# Phase 3.6A: v3 → v3.1 Fix Plan

**Date:** 2026-01-09
**Status:** Ready to Apply
**Total Fixes:** 15 (3 HIGH + 5 MEDIUM + 7 LOW)

---

## Executive Summary

This document details all fixes to be applied when creating plan v3.1 from v3.

**Why v3.1?**
- v3 has 3 blocking bugs that prevent compilation/correct behavior
- v3 has 2 inconsistencies where implementation contradicts recommendations
- v3 has several easy wins that significantly improve robustness

**Total Effort:** ~2 hours of fixes + testing
**Benefit:** Start Day 1 with bulletproof plan, no surprises

---

## HIGH Priority Fixes (Blocking Bugs)

### Fix H1: Replace `const FilterState()` with `FilterState.empty`

**Issue:** Factory constructors cannot be const, code won't compile

**Locations to fix:**
1. Line 437: `FilterState _filterState = const FilterState();`
2. Line 563: `await setFilter(const FilterState());`
3. Line 1259: `const filter = FilterState();`
4. Line 1260: `const filter = FilterState(selectedTagIds: ['tag1']);` (keep - this is ok)
5. Any other `const FilterState()` in test code

**Changes:**
```dart
// BEFORE (won't compile):
FilterState _filterState = const FilterState();
await setFilter(const FilterState());

// AFTER:
FilterState _filterState = FilterState.empty;
await setFilter(FilterState.empty);
```

**Also update FilterState class documentation:**
```dart
/// Default filter state (no filters active).
/// Use this instead of FilterState() for zero allocation.
static const FilterState empty = FilterState._(
  const <String>[],
  FilterLogic.or,
  TagPresenceFilter.any,
);
```

---

### Fix H2: Guard Error Rollback with Operation ID Check

**Issue:** Race condition - if operation A fails while operation B is running, rolls back to wrong state

**Location:** Line 498-506 (setFilter catch block)

**Change:**
```dart
// BEFORE (buggy):
} catch (e) {
  // FIX #4: Rollback to previous filter state on error
  _filterState = previousFilter;
  notifyListeners(); // Update UI to show previous filter

  debugPrint('Error applying filter: $e');
  // TODO: Show error to user via Snackbar
  // (Requires passing callback or using global messenger key)
}

// AFTER (fixed):
} catch (e) {
  // FIX #4: Rollback to previous filter state on error
  // Only rollback if no newer operation has started
  if (currentOperation == _filterOperationId) {
    _filterState = previousFilter;
    notifyListeners(); // Update UI to show previous filter

    debugPrint('Error applying filter: $e');
    // TODO: Show error to user via Snackbar
    // (Requires passing callback or using global messenger key)
  } else {
    // Newer operation already running, don't touch state
    debugPrint('Error applying filter (operation $currentOperation), but newer operation ($_filterOperationId) is active: $e');
  }
}
```

---

### Fix H3: Integrate Empty Results State into TaskListScreen

**Issue:** Empty results widget is defined but never used

**Location:** Line 1140-1150 (TaskListScreen body)

**Change:**
```dart
// BEFORE:
Expanded(
  child: ListView.builder(
    controller: _scrollController,
    itemCount: taskProvider.tasks.length,
    itemBuilder: (context, index) {
      // ... task item builder
    },
  ),
),

// AFTER:
Expanded(
  child: taskProvider.tasks.isEmpty
      ? (taskProvider.hasActiveFilters
          ? _buildEmptyFilteredState(context, taskProvider)
          : _buildEmptyTaskListState(context))
      : ListView.builder(
          controller: _scrollController,
          itemCount: taskProvider.tasks.length,
          itemBuilder: (context, index) {
            // ... task item builder
          },
        ),
),
```

**Add helper methods:**
```dart
Widget _buildEmptyFilteredState(BuildContext context, TaskProvider taskProvider) {
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

Widget _buildEmptyTaskListState(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'No active tasks',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap + to create a task',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
```

---

## MEDIUM Priority Fixes (Consistency & UX)

### Fix M1: Return `FilterState.empty` from Factory for Default Params

**Issue:** Factory always allocates new object, even for default empty filter

**Location:** Line 154-164 (FilterState factory)

**Change:**
```dart
// BEFORE:
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

// AFTER:
factory FilterState({
  List<String> selectedTagIds = const [],
  FilterLogic logic = FilterLogic.or,
  TagPresenceFilter presenceFilter = TagPresenceFilter.any,
}) {
  // Optimization: Return const empty for default parameters
  if (selectedTagIds.isEmpty &&
      logic == FilterLogic.or &&
      presenceFilter == TagPresenceFilter.any) {
    return FilterState.empty;
  }

  return FilterState._(
    List<String>.unmodifiable(selectedTagIds),
    logic,
    presenceFilter,
  );
}
```

**Update documentation:**
```dart
/// Create a filter state with immutable list guarantee.
///
/// FIX #1 (Codex v2): Factory constructor ensures all instances have
/// unmodifiable lists, even when created with `FilterState(selectedTagIds: myList)`.
/// This prevents accidental mutations that would break immutability.
///
/// Optimization: Returns the const `FilterState.empty` singleton when called
/// with default parameters to avoid unnecessary allocations.
factory FilterState({
  // ...
})
```

---

### Fix M2: Use TagProvider Instead of Database Query in addTagFilter

**Issue:** Plan recommends TagProvider (fast) but implements DB query (slow)

**Location:** Line 528-533 (addTagFilter validation)

**Change:**
```dart
// BEFORE:
// FIX #5: Validate tag exists in database
final tag = await _tagService.getTag(tagId);
if (tag == null) {
  debugPrint('addTagFilter: tag $tagId does not exist');
  return; // Reject invalid tag IDs
}

// AFTER:
// FIX #5: Validate tag exists (use TagProvider - faster, in-memory)
// Note: Requires injecting TagProvider into TaskProvider
final tagExists = _tagProvider.tags.any((tag) => tag.id == tagId);
if (!tagExists) {
  debugPrint('addTagFilter: tag $tagId does not exist');
  return; // Reject invalid tag IDs
}
```

**Update TaskProvider constructor:**
```dart
class TaskProvider extends ChangeNotifier {
  final TaskService _taskService;
  final TagService _tagService;
  final TagProvider _tagProvider;  // NEW: Injected for tag validation

  List<Task> _tasks = [];
  List<Task> _completedTasks = [];

  TaskProvider({
    required TaskService taskService,
    required TagService tagService,
    required TagProvider tagProvider,  // NEW
  })  : _taskService = taskService,
        _tagService = tagService,
        _tagProvider = tagProvider;

  // ...
}
```

**Note:** This requires passing TagProvider when creating TaskProvider. Update all provider initialization code accordingly.

---

### Fix M3: Add `completed` Parameter to TagFilterDialog

**Issue:** Dialog always shows active task counts, even when filtering completed tasks

**Location:**
- Line 638-650 (TagFilterDialog class)
- Line 676 (_loadTagCounts method)
- Line 1156-1173 (_showFilterDialog in TaskListScreen)

**Changes:**

1. Update TagFilterDialog class:
```dart
class TagFilterDialog extends StatefulWidget {
  final FilterState initialFilter;
  final List<Tag> allTags;
  final bool showCompletedCounts;  // NEW: Which counts to show

  const TagFilterDialog({
    Key? key,
    required this.initialFilter,
    required this.allTags,
    required this.showCompletedCounts,  // NEW
  }) : super(key: key);

  @override
  State<TagFilterDialog> createState() => _TagFilterDialogState();
}
```

2. Update _loadTagCounts:
```dart
Future<void> _loadTagCounts() async {
  try {
    final tagService = context.read<TagService>();
    final counts = await tagService.getTaskCountsByTag(
      completed: widget.showCompletedCounts,  // Use widget param
    );

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
```

3. Update TaskListScreen dialog invocation:
```dart
Future<void> _showFilterDialog(BuildContext context) async {
  final taskProvider = context.read<TaskProvider>();
  final tagProvider = context.read<TagProvider>();

  final result = await showDialog<FilterState>(
    context: context,
    builder: (_) => TagFilterDialog(
      initialFilter: taskProvider.filterState,
      allTags: tagProvider.tags,
      showCompletedCounts: false,  // NEW: Active tasks screen
    ),
  );

  if (result != null && context.mounted) {
    await taskProvider.setFilter(result);
  }
}
```

4. Same for CompletedTasksScreen:
```dart
showCompletedCounts: true,  // Completed tasks screen
```

---

### Fix M4: Add "Clear All" Button to TagFilterDialog

**Issue:** No way to clear filters from within dialog (requires closing and clicking filter bar)

**Location:** Line 829-848 (dialog actions)

**Change:**
```dart
// BEFORE:
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

// AFTER:
actions: [
  TextButton(
    onPressed: () {
      // Return empty filter to clear all filters
      HapticFeedback.mediumImpact();
      Navigator.pop(context, FilterState.empty);
    },
    child: const Text('Clear All'),
  ),
  const Spacer(),
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
```

---

### Fix M5: Add Empty State to TagFilterDialog When No Tags

**Issue:** Dialog shows blank ListView when no tags exist

**Location:** Line 786-825 (dialog tag list)

**Change:**
```dart
// BEFORE:
Expanded(
  child: ListView.builder(
    shrinkWrap: true,
    itemCount: _displayedTags.length,
    itemBuilder: (context, index) {
      final tag = _displayedTags[index];
      // ...
    },
  ),
),

// AFTER:
Expanded(
  child: _displayedTags.isEmpty
      ? _buildEmptyState()
      : ListView.builder(
          shrinkWrap: true,
          itemCount: _displayedTags.length,
          itemBuilder: (context, index) {
            final tag = _displayedTags[index];
            // ...
          },
        ),
),
```

**Add helper method to _TagFilterDialogState:**
```dart
Widget _buildEmptyState() {
  final noTagsAtAll = widget.allTags.isEmpty;

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noTagsAtAll ? Icons.label_off : Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            noTagsAtAll
                ? 'No tags yet'
                : 'No tags match "$_searchQuery"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (noTagsAtAll) ...[
            const SizedBox(height: 8),
            Text(
              'Create tags in Tag Management',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

---

## LOW Priority Fixes (Robustness & Polish)

### Fix L1: Add Error Handling to fromJson

**Issue:** Invalid enum names cause uncaught exceptions

**Location:** Line 205-213 (FilterState.fromJson)

**Change:**
```dart
// BEFORE:
factory FilterState.fromJson(Map<String, dynamic> json) {
  return FilterState(
    selectedTagIds: List<String>.from(json['selectedTagIds'] ?? []),
    logic: FilterLogic.values.byName(json['logic'] ?? 'or'),
    presenceFilter: TagPresenceFilter.values.byName(
      json['presenceFilter'] ?? 'any',
    ),
  );
}

// AFTER:
factory FilterState.fromJson(Map<String, dynamic> json) {
  try {
    return FilterState(
      selectedTagIds: List<String>.from(json['selectedTagIds'] ?? []),
      logic: FilterLogic.values.byName(json['logic'] ?? 'or'),
      presenceFilter: TagPresenceFilter.values.byName(
        json['presenceFilter'] ?? 'any',
      ),
    );
  } catch (e) {
    debugPrint('Error deserializing FilterState, returning empty: $e');
    return FilterState.empty;
  }
}
```

---

### Fix L2: Optimize Ghost Tag Filtering

**Issue:** O(n*m) nested iteration, should be O(n+m) with Set

**Location:** Line 913-915 (ActiveFilterBar ghost tag filtering)

**Change:**
```dart
// BEFORE:
final validTagIds = filterState.selectedTagIds
    .where((id) => allTags.any((t) => t.id == id))  // O(n*m)
    .toList();

// AFTER:
// Optimization: Pre-compute Set of tag IDs for O(1) lookup
final allTagIds = allTags.map((t) => t.id).toSet();  // O(m)
final validTagIds = filterState.selectedTagIds
    .where((id) => allTagIds.contains(id))  // O(n)
    .toList();
```

---

### Fix L3: Optimize Performance Test Setup with Batch Inserts

**Issue:** 1000 sequential INSERTs are very slow

**Location:** Line 1428-1441 (performance test)

**Change:**
```dart
// BEFORE:
test('performance: <50ms for 1000 tasks', () async {
  // Create 1000 tasks with various tags
  for (int i = 0; i < 1000; i++) {
    await _createTask(db, 'task$i', tags: ['tag${i % 10}']);
  }
  // ...
});

// AFTER:
test('performance: <50ms for 1000 tasks', () async {
  // Create 1000 tasks with various tags using batch insert
  final batch = db.batch();

  for (int i = 0; i < 1000; i++) {
    final taskId = 'task$i';
    final tagId = 'tag${i % 10}';

    batch.insert('tasks', {
      'id': taskId,
      'title': 'Task $i',
      'completed': 0,
      'deleted_at': null,
      'position': i,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    batch.insert('task_tags', {
      'task_id': taskId,
      'tag_id': tagId,
    });
  }

  await batch.commit(noResult: true);

  // Now test query performance
  const filter = FilterState(selectedTagIds: ['tag1', 'tag2', 'tag3']);

  final stopwatch = Stopwatch()..start();
  await taskService.getFilteredTasks(filter, completed: false);
  stopwatch.stop();

  expect(stopwatch.elapsedMilliseconds, lessThan(50));
});
```

---

### Fix L4: Document Haptic Feedback Platform Support

**Issue:** No documentation about platform differences

**Location:** Add new section after line 1217 (after UI/UX Details)

**Add section:**
```markdown
### 6. Platform Support

**Haptic Feedback:**
- **iOS:** Full support (light/medium/heavy impact, system haptics)
- **Android:** Support varies by device (some lack haptic motors)
  - Most modern devices (2018+) have linear resonance actuators (LRAs)
  - Budget devices may have older ERM motors or no haptic feedback
- **Web:** Not supported (calls are no-ops, no errors thrown)
- **Desktop (Windows/Linux/macOS):** Not supported (calls are no-ops)

All `HapticFeedback` calls gracefully degrade on unsupported platforms.

**Material 3 Components:**
- Fully supported on iOS 15+, Android 5.0+
- SegmentedButton requires Flutter 3.7+ (we're on 3.24)
- Badge widget requires Flutter 3.10+ (we're on 3.24)

---
```

---

### Fix L5: Pass TagService as Constructor Parameter to Dialog

**Issue:** Using context.read in async method from initState is fragile

**Location:** Line 638-650 (TagFilterDialog) and 669-670 (_loadTagCounts)

**Change:**

1. Update TagFilterDialog constructor:
```dart
class TagFilterDialog extends StatefulWidget {
  final FilterState initialFilter;
  final List<Tag> allTags;
  final bool showCompletedCounts;
  final TagService tagService;  // NEW: Injected service

  const TagFilterDialog({
    Key? key,
    required this.initialFilter,
    required this.allTags,
    required this.showCompletedCounts,
    required this.tagService,  // NEW
  }) : super(key: key);

  @override
  State<TagFilterDialog> createState() => _TagFilterDialogState();
}
```

2. Update _loadTagCounts:
```dart
Future<void> _loadTagCounts() async {
  try {
    // Use injected service instead of context.read
    final counts = await widget.tagService.getTaskCountsByTag(
      completed: widget.showCompletedCounts,
    );

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
```

3. Update dialog invocation in TaskListScreen:
```dart
Future<void> _showFilterDialog(BuildContext context) async {
  final taskProvider = context.read<TaskProvider>();
  final tagProvider = context.read<TagProvider>();
  final tagService = context.read<TagService>();  // NEW

  final result = await showDialog<FilterState>(
    context: context,
    builder: (_) => TagFilterDialog(
      initialFilter: taskProvider.filterState,
      allTags: tagProvider.tags,
      showCompletedCounts: false,
      tagService: tagService,  // NEW
    ),
  );

  if (result != null && context.mounted) {
    await taskProvider.setFilter(result);
  }
}
```

---

### Fix L6: Add Database Schema Verification Step to Day 1

**Issue:** No verification that Phase 3.5 schema is correct

**Location:** Line 1925-1958 (Day 1-2 implementation plan)

**Change:**
```markdown
### Day 1-2: Core Infrastructure ✅ All Critical Fixes

**Day 1 Morning: Database Verification (NEW)**
- [ ] Create `scripts/verify_schema.dart` helper script
- [ ] Run schema verification:
  - [ ] Check `tasks` table exists with required columns
  - [ ] Check `tags` table exists with required columns
  - [ ] Check `task_tags` junction table exists
  - [ ] Verify indexes exist:
    - `idx_task_tags_task_id`
    - `idx_task_tags_tag_id`
    - `idx_tasks_completed`
    - `idx_tasks_deleted_at`
    - `idx_tasks_position`
- [ ] Document any missing indexes for creation
- [ ] Run sample queries to verify schema works

**Day 1 Morning: FilterState Model** (continues as before)
- [ ] Create `lib/models/filter_state.dart`
- ...
```

**Add verification script skeleton:**
```dart
// scripts/verify_schema.dart
//
// Run with: dart run scripts/verify_schema.dart
//
// Verifies that the database schema from Phase 3.5 is correct
// and has all required indexes for Phase 3.6A filtering.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<void> main() async {
  print('Phase 3.6A: Database Schema Verification\n');

  // Open database
  final dbPath = await getDatabasesPath();
  final db = await openDatabase(
    join(dbPath, 'pin_and_paper.db'),
    version: 6,
  );

  print('✓ Database opened successfully\n');

  // Verify tables
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
  );

  print('Tables found:');
  for (final table in tables) {
    print('  - ${table['name']}');
  }
  print('');

  // Verify indexes
  final indexes = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name;"
  );

  print('Indexes found:');
  for (final index in indexes) {
    print('  - ${index['name']}');
  }
  print('');

  // Check for required indexes
  final requiredIndexes = [
    'idx_task_tags_task_id',
    'idx_task_tags_tag_id',
    'idx_tasks_completed',
    'idx_tasks_deleted_at',
    'idx_tasks_position',
  ];

  print('Required index verification:');
  for (final indexName in requiredIndexes) {
    final exists = indexes.any((idx) => idx['name'] == indexName);
    print('  ${exists ? "✓" : "✗"} $indexName');
  }
  print('');

  await db.close();
  print('Verification complete!');
}
```

---

### Fix L7: Add Missing Concurrency and Immutability Tests

**Issue:** Test coverage gaps for edge cases

**Location:** After line 1443 (add to test plan)

**Add tests:**
```dart
// In test/providers/task_provider_test.dart

group('TaskProvider Concurrency', () {
  test('concurrent setFilter calls handled correctly', () async {
    // Setup: Create provider with mock services
    final taskProvider = TaskProvider(
      taskService: mockTaskService,
      tagService: mockTagService,
      tagProvider: mockTagProvider,
    );

    // Prepare two different filters
    final filterA = FilterState(selectedTagIds: ['tag1']);
    final filterB = FilterState(selectedTagIds: ['tag2']);

    // Start both operations concurrently
    final future1 = taskProvider.setFilter(filterA);
    final future2 = taskProvider.setFilter(filterB);

    // Wait for both to complete
    await Future.wait([future1, future2]);

    // Result should be filterB (last one wins)
    expect(taskProvider.filterState, filterB);

    // Tasks should match filterB's results
    verify(mockTaskService.getFilteredTasks(filterB, completed: false)).called(1);
  });

  test('rapid filter changes use operation ID correctly', () async {
    final taskProvider = TaskProvider(
      taskService: mockTaskService,
      tagService: mockTagService,
      tagProvider: mockTagProvider,
    );

    // Simulate rapid filter changes (user clicking multiple tags quickly)
    final futures = <Future>[];
    for (int i = 0; i < 10; i++) {
      futures.add(taskProvider.setFilter(
        FilterState(selectedTagIds: ['tag$i']),
      ));
    }

    await Future.wait(futures);

    // Should end up with the last filter
    expect(taskProvider.filterState.selectedTagIds, ['tag9']);
  });
});

// In test/models/filter_state_test.dart

group('FilterState Immutability', () {
  test('selectedTagIds cannot be modified externally', () {
    final filter = FilterState(selectedTagIds: ['tag1', 'tag2']);

    // Attempt to modify the list
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

  test('factory returns same empty instance for default params', () {
    final filter1 = FilterState();
    final filter2 = FilterState();
    final empty = FilterState.empty;

    // All should be the same instance (optimization)
    expect(identical(filter1, empty), true);
    expect(identical(filter2, empty), true);
    expect(identical(filter1, filter2), true);
  });
});
```

---

### Fix L8: Add Integration Test for Empty Results Flow

**Issue:** Missing test for important edge case flow

**Location:** After line 1896 (add to integration tests)

**Add test:**
```dart
// In test_driver/tag_filter_integration_test.dart

testWidgets('empty results state shown when all filtered tasks completed', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Setup: Create 2 tasks with "Work" tag, 1 task without any tags
  await _createTask(tester, 'Work task 1', tags: ['Work']);
  await _createTask(tester, 'Work task 2', tags: ['Work']);
  await _createTask(tester, 'Personal task', tags: []);

  // Apply "Work" filter
  await tester.tap(find.text('Work').first); // Click tag chip
  await tester.pumpAndSettle();

  // Should show 2 tasks
  expect(tester.widgetList(find.byType(TaskItem)).length, 2);

  // Complete both Work tasks
  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox).first); // Now the second one
  await tester.pumpAndSettle();

  // Should show empty results state (not blank screen)
  expect(find.text('No tasks match your filters'), findsOneWidget);
  expect(find.byIcon(Icons.filter_alt_off), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Clear Filters'), findsOneWidget);

  // Filter should still be active (shown in filter bar)
  expect(find.text('Clear All'), findsOneWidget);

  // Clear filters
  await tester.tap(find.widgetWithText(FilledButton, 'Clear Filters'));
  await tester.pumpAndSettle();

  // Should now show the one remaining active task (Personal)
  expect(tester.widgetList(find.byType(TaskItem)).length, 1);
  expect(find.text('Personal task'), findsOneWidget);

  // Filter bar should be hidden
  expect(find.text('Clear All'), findsNothing);
});
```

---

## Implementation Order

### Phase 1: Apply Fixes (~1.5 hours)
1. Copy v3 to v3.1
2. Apply all HIGH fixes (H1, H2, H3)
3. Apply all MEDIUM fixes (M1-M5)
4. Apply all LOW fixes (L1-L8)

### Phase 2: Update Documentation (~30 minutes)
5. Update "Changes from v2" section to "Changes from v2 to v3.1"
6. Update version number to 3.1
7. Update any affected line number references
8. Add new test cases to test plan sections

### Phase 3: Review & Commit (~15 minutes)
9. Final review of v3.1
10. Verify all fixes are applied correctly
11. Commit with comprehensive message

---

## Summary

**Total Fixes:** 15
- **HIGH:** 3 blocking bugs
- **MEDIUM:** 5 consistency & UX improvements
- **LOW:** 7 robustness & polish enhancements

**Estimated Total Time:** ~2 hours

**Benefit:**
- ✅ Code compiles (H1)
- ✅ No race conditions (H2)
- ✅ Good UX for empty results (H3)
- ✅ Consistent with our own recommendations (M2)
- ✅ Robust error handling (L1)
- ✅ Better test coverage (L7, L8)
- ✅ Ready for Day 1 with no surprises

---

**Status:** Ready to apply to create plan v3.1
