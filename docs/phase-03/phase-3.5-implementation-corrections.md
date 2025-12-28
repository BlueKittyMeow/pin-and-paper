# Phase 3.5 Implementation Spec - Critical Corrections

**Document:** phase-3.5-implementation.md v2.0
**Purpose:** Key code corrections from Codex review
**Status:** Applied - Ready for Implementation

---

## Critical Code Additions

### 1. TagService: Add Batch Tag Loading (Fixes N+1)

**Add this method to TagService class:**

```dart
/// Batch load tags for multiple tasks (fixes N+1 query problem)
/// Returns map of taskId -> List<Tag>
Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds) async {
  if (taskIds.isEmpty) return {};

  final database = await _db.database;
  final placeholders = List.filled(taskIds.length, '?').join(',');

  final maps = await database.rawQuery('''
    SELECT tt.task_id, t.*
    FROM ${AppConstants.taskTagsTable} tt
    JOIN ${AppConstants.tagsTable} t ON tt.tag_id = t.id
    WHERE tt.task_id IN ($placeholders)
      AND t.deleted_at IS NULL
    ORDER BY t.name ASC
  ''', taskIds);

  // Group by task_id
  final result = <String, List<Tag>>{};
  for (var map in maps) {
    final taskId = map['task_id'] as String;
    // Create Tag from map (skip task_id column)
    final tagMap = Map<String, dynamic>.from(map)..remove('task_id');
    final tag = Tag.fromMap(tagMap);
    result.putIfAbsent(taskId, () => []).add(tag);
  }

  return result;
}
```

---

### 2. TagService: Update Filtering Queries with Proper SQL

**Replace getTasksForTags() with:**

```dart
/// Get tasks matching ANY of the given tags (OR logic)
/// Includes depth/parent data for tree, excludes soft-deleted tasks/tags
Future<List<Task>> getTasksForTags(List<String> tagIds) async {
  if (tagIds.isEmpty) return [];

  final database = await _db.database;
  final placeholders = List.filled(tagIds.length, '?').join(',');

  final maps = await database.rawQuery('''
    SELECT DISTINCT t.*
    FROM ${AppConstants.tasksTable} t
    JOIN ${AppConstants.taskTagsTable} tt ON t.id = tt.task_id
    JOIN ${AppConstants.tagsTable} g ON tt.tag_id = g.id
    WHERE tt.tag_id IN ($placeholders)
      AND t.deleted_at IS NULL
      AND g.deleted_at IS NULL
    ORDER BY t.position ASC
  ''', tagIds);

  return maps.map((map) => Task.fromMap(map)).toList();
}
```

**Replace getTasksForTagsAND() with:**

```dart
/// Get tasks matching ALL of the given tags (AND logic)
/// Includes depth/parent data for tree, excludes soft-deleted tasks/tags
Future<List<Task>> getTasksForTagsAND(List<String> tagIds) async {
  if (tagIds.isEmpty) return [];

  final database = await _db.database;
  final count = tagIds.length;
  final placeholders = List.filled(count, '?').join(',');

  final maps = await database.rawQuery('''
    SELECT t.*
    FROM ${AppConstants.tasksTable} t
    WHERE t.id IN (
      SELECT tt.task_id
      FROM ${AppConstants.taskTagsTable} tt
      JOIN ${AppConstants.tagsTable} g ON tt.tag_id = g.id
      WHERE tt.tag_id IN ($placeholders)
        AND g.deleted_at IS NULL
      GROUP BY tt.task_id
      HAVING COUNT(DISTINCT tt.tag_id) = ?
    )
    AND t.deleted_at IS NULL
    ORDER BY t.position ASC
  ''', [...tagIds, count]);

  return maps.map((map) => Task.fromMap(map)).toList();
}
```

**Replace getTagUsageCounts() with:**

```dart
/// Get usage counts for all tags (excludes soft-deleted tasks)
Future<Map<String, int>> getTagUsageCounts() async {
  final database = await _db.database;

  final maps = await database.rawQuery('''
    SELECT
      tt.tag_id,
      COUNT(t.id) as count
    FROM ${AppConstants.taskTagsTable} tt
    JOIN ${AppConstants.tasksTable} t ON tt.task_id = t.id
    WHERE t.deleted_at IS NULL
    GROUP BY tt.tag_id
  ''');

  return {
    for (var map in maps)
      map['tag_id'] as String: map['count'] as int,
  };
}
```

**Remove palette methods** (getAllPalettes, createPalette, deletePalette) - deferred to 3.5c

---

### 3. TaskProvider: Fix Tag Loading (Fixes N+1 + Assignment Bug)

**Replace loadTasks() tag loading section with:**

```dart
Future<void> loadTasks() async {
  _errorMessage = null;

  try {
    // Load all tasks with hierarchy
    _tasks = await _taskService.getAllTasksWithHierarchy();

    // Batch load ALL tags in single query (fixes N+1)
    final taskIds = _tasks.map((t) => t.id).toList();
    final tagsMap = await _tagService.getTagsForAllTasks(taskIds);

    // Attach tags to tasks (fixes assignment bug)
    _tasks = _tasks.map((task) {
      final tags = tagsMap[task.id] ?? [];
      return task.copyWith(tags: tags);
    }).toList();

    _categorizeTasks();
    _refreshTreeController();
    notifyListeners();
  } catch (e) {
    _errorMessage = 'Failed to load tasks: $e';
    debugPrint(_errorMessage);
    rethrow;
  }
}
```

---

### 4. TaskProvider: Fix Filtering Architecture

**Replace _applyTagFilters() with:**

```dart
Future<void> _applyTagFilters() async {
  if (_tagProvider == null || !_tagProvider!.hasActiveFilters) {
    // No filters - reload all tasks
    await loadTasks();
    return;
  }

  final tagIds = _tagProvider!.activeFilters.toList();
  final isAND = _tagProvider!.isFilterModeAND;

  // Get filtered tasks with hierarchy intact
  final filteredTasks = isAND
      ? await _tagService.getTasksForTagsAND(tagIds)
      : await _tagService.getTasksForTags(tagIds);

  // Batch load tags for filtered tasks
  final taskIds = filteredTasks.map((t) => t.id).toList();
  final tagsMap = await _tagService.getTagsForAllTasks(taskIds);

  // Attach tags
  _tasks = filteredTasks.map((task) {
    final tags = tagsMap[task.id] ?? [];
    return task.copyWith(tags: tags);
  }).toList();

  // Categorize filtered tasks
  _categorizeTasks();

  // Refresh tree with filtered tasks (CRITICAL FIX)
  _refreshTreeController();

  notifyListeners();
}
```

---

### 5. TaskProvider: Fix Listener Lifecycle Leak

**Add to TaskProvider class:**

```dart
TagProvider? _tagProvider;

void setTagProvider(TagProvider tagProvider) {
  // Remove listener from old provider if exists (fixes memory leak)
  _tagProvider?.removeListener(_onTagFiltersChanged);

  _tagProvider = tagProvider;
  tagProvider.addListener(_onTagFiltersChanged);
}

@override
void dispose() {
  // Clean up listener before disposing (fixes memory leak)
  _tagProvider?.removeListener(_onTagFiltersChanged);
  super.dispose();
}
```

---

### 6. TaskProvider: Fix Hide-Completed Interaction

**Replace _categorizeTasks() with:**

```dart
void _categorizeTasks() {
  final now = DateTime.now();
  final hasActiveFilters = _tagProvider?.hasActiveFilters ?? false;

  _activeTasks = _tasks.where((task) => !task.completed).toList();

  _recentlyCompletedTasks = _tasks.where((task) {
    if (!task.completed) return false;
    if (task.completedAt == null) return false;

    // CRITICAL: Tag filters override hide-completed setting
    // User explicitly filtered, show ALL matching completed tasks
    if (hasActiveFilters) return true;

    // Otherwise respect hide-completed setting
    if (!_hideOldCompleted) return true;

    final age = now.difference(task.completedAt!);
    return age.inHours < 24;
  }).toList();
}
```

---

## Summary of File Changes

| Section | Change | Line (approx) |
|---------|--------|---------------|
| Design Decision #4 | Remove saved palettes | ~32 |
| File Structure | Remove tag_palette.dart | ~49 |
| TagPalette Model | Replace with note (deferred) | ~192 |
| Database Migration | Remove tag_palettes table | ~242 |
| TagService | Add getTagsForAllTasks | After line ~290 |
| TagService | Update getTasksForTags SQL | ~452 |
| TagService | Update getTasksForTagsAND SQL | ~471 |
| TagService | Update getTagUsageCounts SQL | ~490 |
| TagService | Remove palette methods | ~575 |
| TaskProvider | Fix loadTasks tag loading | ~600 |
| TaskProvider | Fix _applyTagFilters | ~630 |
| TaskProvider | Add listener cleanup | ~650 |
| TaskProvider | Fix _categorizeTasks | ~680 |

---

## Testing Implications

**New tests needed:**
1. Test getTagsForAllTasks with 100+ tasks (ensure single query)
2. Test filtering updates tree view (not just derived lists)
3. Test listener cleanup (no memory leaks)
4. Test tag filter + hide-completed interaction
5. Test soft-deleted tasks excluded from counts

---

**Status:** All corrections documented
**Next Step:** Update phase-3.5-implementation.md inline or reference this doc during implementation
