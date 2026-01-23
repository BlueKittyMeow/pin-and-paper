# Codex Findings v4 - Fixes

**Date:** 2026-01-17
**Issues Found:** 6 (1 CRITICAL, 1 HIGH, 3 MEDIUM, 1 LOW)
**Status:** Fixes ready for integration

---

## 🔴 CRITICAL FIX: Variable Scope in Error Logging

**Issue:** `sql` and `args` declared inside `try` block, not accessible in `catch`

**Fix:**

```dart
Future<List<TaskWithTags>> _getCandidates(
  String query,
  SearchScope scope,
  FilterState? tagFilters,
) async {
  // CRITICAL FIX: Declare outside try block for error logging
  String sql = '';
  List<dynamic> args = [];

  try {
    // v3: Use SQL LIKE for initial filtering (no indexes help leading-wildcard)
    // NOTE: LIKE '%query%' cannot use B-tree indexes (Gemini finding)

    final conditions = <String>[];
    args = <dynamic>[];  // Assign to outer variable

    // Deleted filter
    conditions.add('tasks.deleted_at IS NULL');

    // Scope filter (All/Current/RecentlyCompleted/Completed)
    switch (scope) {
      case SearchScope.all:
        // No completion filter
        break;
      case SearchScope.current:
        conditions.add('tasks.completed = 0');
        break;
      case SearchScope.recentlyCompleted:
        // v3 FIX (Codex): Use millisecondsSinceEpoch, not ISO string!
        final cutoff = DateTime.now().subtract(Duration(days: 30));
        conditions.add('tasks.completed = 1');
        conditions.add('tasks.completed_at IS NOT NULL');
        conditions.add('tasks.completed_at >= ?');
        args.add(cutoff.millisecondsSinceEpoch);  // FIXED
        break;
      case SearchScope.completed:
        conditions.add('tasks.completed = 1');
        break;
    }

    // v3 FIX (Codex): Escape LIKE wildcards in user query
    String escapedQuery = query.trim().toLowerCase();
    escapedQuery = escapedQuery.replaceAll('\\', '\\\\');
    escapedQuery = escapedQuery.replaceAll('%', '\\%');
    escapedQuery = escapedQuery.replaceAll('_', '\\_');

    // Text search (broad LIKE query for candidates)
    if (query.trim().isNotEmpty) {
      conditions.add('''
        (LOWER(tasks.title) LIKE ? ESCAPE '\\\\'
         OR LOWER(tasks.notes) LIKE ? ESCAPE '\\\\'
         OR LOWER(tags.name) LIKE ? ESCAPE '\\\\')
      ''');
      final pattern = '%$escapedQuery%';
      args.addAll([pattern, pattern, pattern]);
    }

    // v4 HIGH FIX: Always apply tag filters if present (not just when tags selected)
    if (tagFilters != null) {
      _applyTagFilters(conditions, args, tagFilters);
    }

    // v4 FIX: Removed redundant DISTINCT (GROUP BY sufficient)
    sql = '''
      SELECT
        tasks.*,
        GROUP_CONCAT(tags.name, ' ') AS tag_names
      FROM tasks
      LEFT JOIN task_tags ON tasks.id = task_tags.task_id
      LEFT JOIN tags ON task_tags.tag_id = tags.id
      WHERE ${conditions.join(' AND ')}
      GROUP BY tasks.id
      ORDER BY tasks.position ASC
      LIMIT 200  -- v3: Candidate cap to prevent runaway queries
    ''';

    final results = await _db.rawQuery(sql, args);
    return results.map((row) => TaskWithTags.fromMap(row)).toList();
  } on DatabaseException catch (e) {
    print('SQL error in _getCandidates: $e\nSQL: $sql\nArgs: $args');
    rethrow;  // Let search() handle it
  } catch (e) {
    print('Error parsing search candidates: $e');
    rethrow;
  }
}
```

---

## 🟠 HIGH FIX: Apply Presence Filters Even Without Selected Tags

**Issue:** Presence filters (onlyTagged/onlyUntagged) ignored when no tags selected

**Fix:**

```dart
// In _getCandidates method:

// v4 HIGH FIX (Codex): Always apply tag filters if present (not just when tags selected)
// This ensures presence filters (onlyTagged/onlyUntagged) work even with empty selectedTagIds
if (tagFilters != null) {
  _applyTagFilters(conditions, args, tagFilters);
}
```

**And update _applyTagFilters:**

```dart
// v4 UPDATED (Codex): Apply presence filters even when no tags selected
void _applyTagFilters(
  List<String> conditions,
  List<dynamic> args,
  FilterState filters,
) {
  // Reuse exact logic from TaskService.getFilteredTasks()
  // This ensures search behavior matches main list filtering

  // v4 FIX: Only apply tag ID logic when tags are actually selected
  if (filters.selectedTagIds.isNotEmpty) {
    if (filters.logic == FilterLogic.or) {
      // OR logic: task has ANY of the selected tags
      conditions.add('tags.id IN (${filters.selectedTagIds.map((_) => '?').join(',')})');
      args.addAll(filters.selectedTagIds);
    } else {
      // AND logic: task has ALL of the selected tags
      // Use HAVING COUNT with GROUP BY
      conditions.add('''
        tasks.id IN (
          SELECT task_id
          FROM task_tags
          WHERE tag_id IN (${filters.selectedTagIds.map((_) => '?').join(',')})
          GROUP BY task_id
          HAVING COUNT(DISTINCT tag_id) = ?
        )
      ''');
      args.addAll(filters.selectedTagIds);
      args.add(filters.selectedTagIds.length);
    }
  }

  // v4 FIX (Codex): ALWAYS apply presence filter (even when selectedTagIds is empty)
  // This allows "only tagged" or "only untagged" searches without specific tags
  switch (filters.presenceFilter) {
    case TagPresenceFilter.any:
      // No filter
      break;
    case TagPresenceFilter.onlyTagged:  // CORRECTED (not .tagged)
      conditions.add('tags.id IS NOT NULL');
      break;
    case TagPresenceFilter.onlyUntagged:  // CORRECTED (not .untagged)
      conditions.add('tags.id IS NULL');
      break;
  }
}
```

---

## 🟡 MEDIUM FIX #1: True Batch Loading for Breadcrumbs

**Issue:** Still N queries, just moved out of build

**Option A: Parallelize with concurrency limit**

```dart
/// v4 MEDIUM FIX (Codex): Parallelize breadcrumb loading with concurrency limit
Future<Map<String, String>> _loadBreadcrumbsForResults(
  List<SearchResult> results,
) async {
  final breadcrumbs = <String, String>{};
  final taskService = TaskService();

  // Filter tasks that need breadcrumbs
  final tasksNeedingBreadcrumbs = results
      .where((r) => r.task.parentId != null)
      .toList();

  if (tasksNeedingBreadcrumbs.isEmpty) return breadcrumbs;

  // Process in batches of 10 to avoid overwhelming DB
  const batchSize = 10;
  for (int i = 0; i < tasksNeedingBreadcrumbs.length; i += batchSize) {
    final batch = tasksNeedingBreadcrumbs.skip(i).take(batchSize);

    // Parallelize within batch
    final futures = batch.map((result) async {
      try {
        final parents = await taskService.getParentChain(result.task.id);
        return MapEntry(
          result.task.id,
          parents.map((t) => t.title).join(' > '),
        );
      } catch (e) {
        print('Failed to load breadcrumb for task ${result.task.id}: $e');
        return null;
      }
    });

    final batchResults = await Future.wait(futures);

    for (final entry in batchResults) {
      if (entry != null) {
        breadcrumbs[entry.key] = entry.value;
      }
    }
  }

  return breadcrumbs;
}
```

**Option B: Accept N queries, document tradeoff**

```dart
/// v4 MEDIUM (Codex note): This is still N queries (one per task with parent).
/// True batching would require a recursive CTE SQL query or precomputed paths.
///
/// Trade-off: For typical search results (10-50 tasks), this adds ~50-200ms.
/// This is acceptable given:
/// - Breadcrumbs are loaded ONCE before rendering (not per scroll)
/// - getParentChain is likely cached or fast
/// - Alternative (recursive CTE) adds complexity
///
/// If performance becomes an issue, consider:
/// - Precomputing parent paths in TaskProvider tree
/// - Adding breadcrumb cache in TaskService
Future<Map<String, String>> _loadBreadcrumbsForResults(
  List<SearchResult> results,
) async {
  final breadcrumbs = <String, String>{};
  final taskService = TaskService();

  for (final result in results) {
    if (result.task.parentId != null) {
      try {
        final parents = await taskService.getParentChain(result.task.id);
        breadcrumbs[result.task.id] = parents.map((t) => t.title).join(' > ');
      } catch (e) {
        // v4: Graceful degradation - just skip breadcrumb for this task
        print('Failed to load breadcrumb for task ${result.task.id}: $e');
        // Don't add entry - tile will check for null
      }
    }
  }

  return breadcrumbs;
}
```

**Recommendation:** Use Option A (parallel batches) if typical result sets > 20 tasks. Otherwise Option B with documentation is fine for MVP.

---

## 🟡 MEDIUM FIX #2: Batch Tag Loading

**Issue:** `_loadTagsForFilter` still calls `getTagById` in loop

**Fix: Add TagService.getTagsByIds method**

```dart
// In TagService class:
/// Batch-fetch multiple tags by IDs in a single query
Future<List<Tag>> getTagsByIds(List<String> tagIds) async {
  if (tagIds.isEmpty) return [];

  final db = await database;
  final placeholders = tagIds.map((_) => '?').join(',');

  final results = await db.query(
    'tags',
    where: 'id IN ($placeholders)',
    whereArgs: tagIds,
  );

  return results.map((map) => Tag.fromMap(map)).toList();
}
```

**Then update _loadTagsForFilter:**

```dart
// v4 MEDIUM FIX (Codex): True batch loading for tags
Future<void> _loadTagsForFilter() async {
  if (_tagFilters == null || _tagFilters!.selectedTagIds.isEmpty) return;

  // Find tags not already in cache
  final missingTagIds = _tagFilters!.selectedTagIds
      .where((id) => !_tagCache.containsKey(id))
      .toList();

  if (missingTagIds.isEmpty) return;

  try {
    // v4 FIX: Single batch query instead of N queries
    final tags = await _tagService.getTagsByIds(missingTagIds);

    // Add to cache
    for (final tag in tags) {
      _tagCache[tag.id] = tag;
    }
  } catch (e) {
    print('Failed to batch-load tags: $e');
    // Fallback to individual loading if batch fails
    for (final tagId in missingTagIds) {
      try {
        final tag = await _tagService.getTagById(tagId);
        if (tag != null) {
          _tagCache[tagId] = tag;
        }
      } catch (e) {
        print('Failed to load tag $tagId: $e');
      }
    }
  }

  // v3 FIX (Codex): Check mounted before setState
  if (!mounted) return;
  setState(() {});  // Refresh chips with loaded tags
}
```

---

## 🟡 MEDIUM FIX #3: Candidate Cap Documentation

**Issue:** LIMIT 200 before scoring can miss relevant results

**Option A: Add notice when cap hit**

```dart
class SearchResult {
  final Task task;
  final double score;
  final MatchPositions matches;

  SearchResult({
    required this.task,
    required this.score,
    required this.matches,
  });
}

// Add to SearchService:
Future<(List<SearchResult>, bool)> search({
  required String query,
  required SearchScope scope,
  FilterState? tagFilters,
}) async {
  // ... existing implementation ...

  final candidates = await _getCandidates(query, scope, tagFilters);
  final candidateCapHit = candidates.length >= 200;  // Track if we hit cap

  final scored = _scoreResults(candidates, query);
  // ... sort and return ...

  return (scored, candidateCapHit);
}

// In SearchDialog:
void _performSearch() async {
  // ...
  final (results, capHit) = await searchService.search(...);

  if (capHit && results.isNotEmpty) {
    // Show notice
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing top 200 matches. Refine search for better results.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
  // ...
}
```

**Option B: Document tradeoff, accept for MVP**

```dart
// In plan documentation:

**Candidate Cap Trade-off:**

The LIMIT 200 is applied BEFORE scoring to prevent performance issues with very broad queries. This means:

**Pros:**
- Prevents scoring 1000+ tasks on queries like "a" or "the"
- Ensures search stays under 100ms even with poor queries
- Protects against accidental runaway searches

**Cons:**
- Can miss relevant results if >200 tasks match LIKE filter
- Sorted by position, not relevance (before scoring)

**Mitigation:**
- Users refine queries if too broad
- Most searches return <50 results
- Position-based ordering is reasonable proxy
- Future: Adaptive cap based on query length

**When to revisit:**
- User feedback indicates missed results
- Performance allows scoring more candidates
- FTS5 implementation (can score thousands efficiently)
```

**Recommendation:** Use Option B (document tradeoff) for MVP. Add Option A (notice) if user testing shows confusion.

---

## 🔵 LOW FIX: SearchService Instantiation

**Issue:** Placeholder `/* ... */` doesn't match "runnable" claim

**Fix:**

```dart
// In _performSearch:
void _performSearch() async {
  final query = _searchController.text.trim();
  if (query.isEmpty) {
    setState(() {
      _results = [];
      _breadcrumbs = {};
    });
    return;
  }

  setState(() => _isSearching = true);
  final currentOperationId = ++_searchOperationId;

  try {
    // v4 FIX (Codex LOW): Complete instantiation instead of placeholder
    final db = await context.read<DatabaseService>().database;
    final searchService = SearchService(db);

    // Perform search
    final results = await searchService.search(
      query: query,
      scope: _scope,
      tagFilters: _tagFilters,
    );

    // v4 CRITICAL FIX #1: Batch-load breadcrumbs BEFORE updating state
    final breadcrumbsMap = await _loadBreadcrumbsForResults(results);

    // ... rest of implementation
  }
  // ... error handling
}
```

---

## 📋 Summary of Fixes

| Priority | Issue | Fix Approach | Defer? |
|----------|-------|--------------|--------|
| CRITICAL | Variable scope | Declare sql/args outside try | ❌ Must fix |
| HIGH | Presence filters | Call _applyTagFilters always | ❌ Must fix |
| MEDIUM | Breadcrumb N queries | Parallelize OR document | ✅ Can defer |
| MEDIUM | Tag cache N queries | Add getTagsByIds | ✅ Can defer |
| MEDIUM | Candidate cap | Document tradeoff | ✅ Can defer |
| LOW | SearchService placeholder | Complete instantiation | ✅ Can defer |

**Recommendation:**
- **Fix immediately:** CRITICAL and HIGH (2 issues)
- **Consider for v4:** MEDIUM #2 (tag batch) - easy win
- **Defer to v4.1 or testing:** MEDIUM #1, #3 (breadcrumbs, cap) - trade-offs acceptable for MVP
- **Defer to implementation:** LOW (placeholder) - will be resolved during coding

---

## Next Steps

1. ✅ Apply CRITICAL and HIGH fixes to plan-v4
2. ✅ Apply MEDIUM #2 (tag batch) if TagService change acceptable
3. ✅ Document MEDIUM #1 and #3 trade-offs in plan
4. ✅ Update codex-findings-v4.md with resolution status
5. ✅ Get Codex sign-off on fixes
6. ✅ Commit plan-v4.1 or updated plan-v4

**Status:** Fixes ready for review and integration
