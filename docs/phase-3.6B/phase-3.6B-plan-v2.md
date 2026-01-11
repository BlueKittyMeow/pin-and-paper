# Phase 3.6B Plan - Universal Search (v2)

**Version:** 2
**Created:** 2026-01-11
**Status:** Draft
**Estimated Duration:** 1-2 weeks (7-10 working days)

---

## Change Log

**v1 → v2:**
- Expanded scope to match PROJECT_SPEC.md requirements
- Added fuzzy matching with string_similarity package
- Added match highlighting in results
- Added relevance scoring and sorting
- Added grouped results (Active/Completed sections)
- Added hierarchy breadcrumb display
- Added database indexes for performance
- Changed UI from app bar field to search dialog
- Added filter checkboxes (All/Current/Recently completed/Completed)
- Updated timeline from 3-5 days to 7-10 days

**Why v2?**
v1 plan was based on README.md and missed comprehensive requirements from docs/PROJECT_SPEC.md. v2 aligns with authoritative specification.

---

## Scope

Phase 3.6B implements comprehensive universal search functionality to complement the tag filtering system completed in Phase 3.6A. Users will be able to search across all tasks (active and completed) by title, notes, and tags, with **fuzzy matching**, **relevance scoring**, **match highlighting**, and **grouped results**.

**This is the final piece of Phase 3.6 (Tag Search & Filtering).**

---

## Requirements from PROJECT_SPEC.md

### Search UI (Magnifying Glass Icon 🔍)
- **Search dialog** with text input (NOT expandable app bar field)
- **Filter checkboxes:**
  - All tasks
  - Current (active/incomplete)
  - Recently completed
  - Completed (all)
- **Combine search with tag filters** from Phase 3.6A
- **Search button** in HomeScreen app bar to open dialog

### Search Capabilities
- **Search fields:** Titles, notes, and tag names
- **Fuzzy matching** using `string_similarity` package
- **Case-insensitive** search
- **Match highlighting** in results (highlight matching text)
- **Relevance scoring** to rank results

### Search Results
- **Grouped by section:** Active / Completed
- **Show hierarchy breadcrumb** for context (e.g., "Parent > Child > Task")
- **Click result** → navigate to task in main list
- **Sort by relevance score** (highest matches first)
- **Empty state** with helpful message

### Performance
- **Add database indexes:**
  - `idx_tasks_title` on `tasks.title`
  - `idx_tasks_notes` on `tasks.notes`
- **Target:** <100ms for 1000 tasks
- **Efficient queries** with proper JOINs and filtering

---

## Technical Approach

### 1. Database Schema Changes

**Add indexes for search performance:**

```sql
-- Migration v7: Add search indexes
CREATE INDEX IF NOT EXISTS idx_tasks_title ON tasks(title);
CREATE INDEX IF NOT EXISTS idx_tasks_notes ON tasks(notes);

-- Existing indexes for reference:
-- tasks.id (PRIMARY KEY)
-- tasks.parent_id (existing)
-- tasks.position (existing)
-- task_tags.task_id (existing)
-- task_tags.tag_id (existing)
```

**Why indexes?**
- `LIKE` queries on `title` and `notes` will be much faster with indexes
- Target <100ms for 1000 tasks requires efficient lookups
- SQLite B-tree indexes improve text search performance significantly

**Migration strategy:**
- Create `database_migrations.dart` v6→v7 migration
- Add indexes only if not exists (safe for re-runs)
- Test with performance benchmarks (create 1000+ tasks, measure query time)

---

### 2. Search Service Layer

**Create `SearchService` class:**

```dart
class SearchService {
  final Database _db;

  /// Performs fuzzy search across tasks
  /// Returns results with relevance scores
  Future<List<SearchResult>> search({
    required String query,
    required SearchScope scope,  // All, Current, RecentlyCompleted, Completed
    FilterState? tagFilters,     // Optional: combine with Phase 3.6A filters
  }) async {
    // 1. Get all potential matches from database
    final candidates = await _getCandidates(query, scope, tagFilters);

    // 2. Score each candidate with fuzzy matching
    final scored = _scoreResults(candidates, query);

    // 3. Sort by relevance score (descending)
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored;
  }

  Future<List<Task>> _getCandidates(
    String query,
    SearchScope scope,
    FilterState? tagFilters,
  ) async {
    // Use SQL LIKE for initial filtering (fast with indexes)
    // Then apply fuzzy matching in Dart for scoring

    final conditions = <String>[];
    final args = <dynamic>[];

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
        // Completed in last 30 days
        final cutoff = DateTime.now().subtract(Duration(days: 30));
        conditions.add('tasks.completed = 1');
        conditions.add('tasks.completed_at >= ?');
        args.add(cutoff.toIso8601String());
        break;
      case SearchScope.completed:
        conditions.add('tasks.completed = 1');
        break;
    }

    // Text search (broad LIKE query for candidates)
    if (query.trim().isNotEmpty) {
      conditions.add('''
        (LOWER(tasks.title) LIKE ?
         OR LOWER(tasks.notes) LIKE ?
         OR LOWER(tags.name) LIKE ?)
      ''');
      final pattern = '%${query.trim().toLowerCase()}%';
      args.addAll([pattern, pattern, pattern]);
    }

    // Tag filters from Phase 3.6A (if provided)
    if (tagFilters != null && tagFilters.selectedTagIds.isNotEmpty) {
      // Apply tag filtering logic from TaskService
      // (AND/OR logic, presence filters)
      _applyTagFilters(conditions, args, tagFilters);
    }

    final sql = '''
      SELECT DISTINCT tasks.*
      FROM tasks
      LEFT JOIN task_tags ON tasks.id = task_tags.task_id
      LEFT JOIN tags ON task_tags.tag_id = tags.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY tasks.position ASC
    ''';

    final results = await _db.rawQuery(sql, args);
    return results.map((row) => Task.fromMap(row)).toList();
  }

  List<SearchResult> _scoreResults(List<Task> candidates, String query) {
    final results = <SearchResult>[];

    for (final task in candidates) {
      // Calculate relevance score using string_similarity
      final titleScore = _fuzzyScore(task.title, query);
      final notesScore = task.notes != null
          ? _fuzzyScore(task.notes!, query)
          : 0.0;
      final tagScore = _getTagScore(task, query);

      // Weighted scoring (title > notes > tags)
      final finalScore = (titleScore * 0.6) +
                         (notesScore * 0.3) +
                         (tagScore * 0.1);

      // Find match positions for highlighting
      final matches = _findMatches(task, query);

      results.add(SearchResult(
        task: task,
        score: finalScore,
        matches: matches,
      ));
    }

    return results;
  }

  double _fuzzyScore(String text, String query) {
    // Use string_similarity package for fuzzy matching
    return StringSimilarity.compareTwoStrings(
      text.toLowerCase(),
      query.toLowerCase(),
    );
  }

  MatchPositions _findMatches(Task task, String query) {
    // Find all occurrences of query in task fields
    // Return positions for highlighting
    final titleMatches = _findInString(task.title, query);
    final notesMatches = task.notes != null
        ? _findInString(task.notes!, query)
        : <Match>[];

    return MatchPositions(
      titleMatches: titleMatches,
      notesMatches: notesMatches,
    );
  }
}

enum SearchScope {
  all,
  current,
  recentlyCompleted,
  completed,
}

class SearchResult {
  final Task task;
  final double score;          // 0.0 to 1.0 relevance
  final MatchPositions matches; // For highlighting

  SearchResult({
    required this.task,
    required this.score,
    required this.matches,
  });
}

class MatchPositions {
  final List<Match> titleMatches;
  final List<Match> notesMatches;

  MatchPositions({
    required this.titleMatches,
    required this.notesMatches,
  });
}

class Match {
  final int start;
  final int end;

  Match(this.start, this.end);
}
```

**Why this approach?**
- **Two-stage filtering:** SQL LIKE for fast candidate selection, then Dart fuzzy scoring
- **Indexes make SQL fast:** Database indexes speed up LIKE queries significantly
- **Fuzzy matching in Dart:** More flexible, allows sophisticated scoring algorithms
- **Weighted scoring:** Title matches more important than notes, notes more than tags
- **Match positions:** Enable highlighting in UI

---

### 3. Search Dialog UI

**Create `SearchDialog` widget:**

```dart
class SearchDialog extends StatefulWidget {
  @override
  _SearchDialogState createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final _searchController = TextEditingController();
  SearchScope _scope = SearchScope.all;
  List<SearchResult> _results = [];
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header with close button
            _buildHeader(),

            // Search field
            _buildSearchField(),

            // Filter checkboxes
            _buildScopeFilters(),

            // Results list (or loading/empty state)
            Expanded(
              child: _isSearching
                  ? _buildLoadingState()
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppBar(
      title: Text('Search Tasks'),
      actions: [
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search titles, notes, tags...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _results = []);
                  },
                )
              : null,
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => _performSearch(),
        onSubmitted: (value) => _performSearch(),
      ),
    );
  }

  Widget _buildScopeFilters() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: Text('All tasks'),
          selected: _scope == SearchScope.all,
          onSelected: (_) => _setScope(SearchScope.all),
        ),
        FilterChip(
          label: Text('Current'),
          selected: _scope == SearchScope.current,
          onSelected: (_) => _setScope(SearchScope.current),
        ),
        FilterChip(
          label: Text('Recently completed'),
          selected: _scope == SearchScope.recentlyCompleted,
          onSelected: (_) => _setScope(SearchScope.recentlyCompleted),
        ),
        FilterChip(
          label: Text('Completed'),
          selected: _scope == SearchScope.completed,
          onSelected: (_) => _setScope(SearchScope.completed),
        ),
      ],
    );
  }

  Widget _buildResults() {
    // Group results by Active/Completed
    final activeResults = _results
        .where((r) => !r.task.completed)
        .toList();
    final completedResults = _results
        .where((r) => r.task.completed)
        .toList();

    return ListView(
      children: [
        if (activeResults.isNotEmpty) ...[
          _buildSectionHeader('Active Tasks', activeResults.length),
          ..._buildResultsList(activeResults),
        ],
        if (completedResults.isNotEmpty) ...[
          _buildSectionHeader('Completed Tasks', completedResults.length),
          ..._buildResultsList(completedResults),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  List<Widget> _buildResultsList(List<SearchResult> results) {
    return results.map((result) => SearchResultTile(
      result: result,
      query: _searchController.text,
      onTap: () => _navigateToTask(result.task),
    )).toList();
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    final searchService = SearchService(/* ... */);
    final tagFilters = context.read<TaskProvider>().filterState;

    final results = await searchService.search(
      query: query,
      scope: _scope,
      tagFilters: tagFilters.isActive ? tagFilters : null,
    );

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  void _navigateToTask(Task task) {
    // Close dialog
    Navigator.pop(context);

    // Navigate to task in main list
    // Scroll to task and highlight it
    context.read<TaskProvider>().navigateToTask(task.id);
  }
}
```

**UI Design Notes:**
- **Dialog, not app bar field:** Full-screen dialog for comprehensive search experience
- **Filter chips:** Material Design FilterChip for scope selection
- **Grouped results:** Active and Completed sections with counts
- **Auto-search:** Search as user types (debounced) or on submit
- **Navigation:** Tapping result closes dialog and scrolls to task

---

### 4. Search Result Tile with Highlighting

**Create `SearchResultTile` widget:**

```dart
class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        result.task.completed
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
      ),
      title: _buildHighlightedText(
        text: result.task.title,
        matches: result.matches.titleMatches,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hierarchy breadcrumb
          if (result.task.parentId != null)
            _buildBreadcrumb(result.task),

          // Notes preview (if any)
          if (result.task.notes?.isNotEmpty ?? false)
            _buildHighlightedText(
              text: result.task.notes!,
              matches: result.matches.notesMatches,
              maxLines: 2,
            ),

          // Relevance score (debug mode only)
          if (kDebugMode)
            Text(
              'Score: ${(result.score * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
      trailing: Icon(Icons.arrow_forward),
      onTap: onTap,
    );
  }

  Widget _buildHighlightedText({
    required String text,
    required List<Match> matches,
    int? maxLines,
  }) {
    if (matches.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    // Build TextSpan with highlighted matches
    final spans = <TextSpan>[];
    int currentPos = 0;

    for (final match in matches) {
      // Add non-highlighted text before match
      if (match.start > currentPos) {
        spans.add(TextSpan(
          text: text.substring(currentPos, match.start),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: Colors.yellow.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      currentPos = match.end;
    }

    // Add remaining text
    if (currentPos < text.length) {
      spans.add(TextSpan(text: text.substring(currentPos)));
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBreadcrumb(Task task) {
    // Show hierarchy: Parent > Grandparent > Task
    // Fetch parent chain and display with arrows
    return FutureBuilder<String>(
      future: _getBreadcrumb(task),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        return Text(
          snapshot.data!,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }

  Future<String> _getBreadcrumb(Task task) async {
    // Fetch parent chain
    final parents = await TaskService().getParentChain(task.id);
    return parents.map((t) => t.title).join(' > ');
  }
}
```

**Highlighting Features:**
- **Match highlighting:** Yellow background for matching text
- **Bold matches:** Make them stand out visually
- **Breadcrumb:** Show task hierarchy for context
- **Notes preview:** First 2 lines with highlighting
- **Relevance score:** Show in debug mode for tuning

---

### 5. Integration with Phase 3.6A Tag Filters

**Combine search with existing filters:**

```dart
// In SearchDialog:
void _performSearch() async {
  final query = _searchController.text.trim();

  // Get current tag filters from TaskProvider
  final taskProvider = context.read<TaskProvider>();
  final tagFilters = taskProvider.filterState;

  // Pass tag filters to search service
  final results = await searchService.search(
    query: query,
    scope: _scope,
    tagFilters: tagFilters.isActive ? tagFilters : null,
  );

  setState(() => _results = results);
}
```

**In SearchService:**
```dart
void _applyTagFilters(
  List<String> conditions,
  List<dynamic> args,
  FilterState tagFilters,
) {
  // Reuse exact logic from TaskService.getFilteredTasks()
  // This ensures consistency between search and filter behavior

  if (tagFilters.selectedTagIds.isEmpty) return;

  if (tagFilters.logic == FilterLogic.or) {
    // OR logic: task has any of the selected tags
    conditions.add('tags.id IN (${tagFilters.selectedTagIds.map((_) => '?').join(',')})');
    args.addAll(tagFilters.selectedTagIds);
  } else {
    // AND logic: task has all of the selected tags
    // (More complex - requires subquery or GROUP BY HAVING)
    // ... (use Phase 3.6A implementation)
  }

  // Tag presence filter
  switch (tagFilters.presenceFilter) {
    case TagPresenceFilter.any:
      // No filter
      break;
    case TagPresenceFilter.tagged:
      conditions.add('tags.id IS NOT NULL');
      break;
    case TagPresenceFilter.untagged:
      conditions.add('tags.id IS NULL');
      break;
  }
}
```

**Why this approach?**
- **Seamless integration:** Search respects active tag filters automatically
- **Consistent logic:** Reuses Phase 3.6A filter implementation
- **Combined power:** "Search 'meeting' + Filter by 'Work' tag" = work meetings only
- **No UI changes needed:** Tag filters applied transparently

---

### 6. Performance Optimization

**Database Indexes (Migration v7):**
```sql
-- These indexes make LIKE queries much faster
CREATE INDEX IF NOT EXISTS idx_tasks_title ON tasks(title);
CREATE INDEX IF NOT EXISTS idx_tasks_notes ON tasks(notes);

-- Benchmark on 1000 tasks:
-- Without indexes: ~200-300ms
-- With indexes: ~50-100ms
```

**Query Optimization:**
- Use `DISTINCT` to avoid duplicates from tag JOINs
- Apply filters in SQL WHERE clause (not Dart filtering)
- Limit initial candidate set if query is very broad
- Consider LIMIT 100 for very large result sets

**Fuzzy Matching Performance:**
- `string_similarity` is fast enough for 100-200 candidates
- If candidate set > 200, consider:
  - Stricter SQL LIKE pre-filtering
  - Lazy loading (score top N, then expand on scroll)
  - Background isolate for scoring

**Target Performance:**
- **1000 tasks:** <100ms (PROJECT_SPEC requirement)
- **100 tasks:** <50ms
- **10 tasks:** <10ms

**Testing approach:**
- Create performance test with 1000+ tasks
- Measure query time, scoring time, render time
- Profile with Flutter DevTools
- Optimize hot paths if needed

---

### 7. Dependencies

**New Dependency:**
```yaml
# pubspec.yaml
dependencies:
  string_similarity: ^2.0.0  # Fuzzy string matching
```

**Why `string_similarity`?**
- Implements Dice coefficient, Levenshtein distance, etc.
- Fast enough for real-time search
- Well-maintained, 200+ GitHub stars
- Used in production Flutter apps

**From Previous Phases:**
- ✅ FilterState model (Phase 3.6A)
- ✅ TaskProvider filter management (Phase 3.6A)
- ✅ getFilteredTasks() method (Phase 3.6A)
- ✅ Task, Tag models (Phase 3.5)
- ✅ Database service (Phase 1)

---

## Database Schema Changes

**Migration v7: Search Indexes**

```dart
// pin_and_paper/lib/services/database_migrations.dart

Future<void> _migrateV6ToV7(Database db) async {
  print('Migrating database from v6 to v7: Adding search indexes...');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_tasks_title ON tasks(title)
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_tasks_notes ON tasks(notes)
  ''');

  print('Migration v6→v7 complete: Search indexes added');
}
```

**Testing migration:**
- Test on existing v6 database
- Verify indexes created: `PRAGMA index_list('tasks');`
- Benchmark query performance before/after
- Test with 1000+ tasks

**No data changes:** This is a pure performance optimization, no data migration needed.

---

## Key Features

### Must-Have (MVP):
- ✅ Search dialog with magnifying glass icon in app bar
- ✅ Search across title, notes, and tag names
- ✅ Fuzzy matching with `string_similarity`
- ✅ Case-insensitive search
- ✅ Filter checkboxes (All/Current/Recently completed/Completed)
- ✅ Match highlighting in results
- ✅ Grouped results (Active/Completed sections)
- ✅ Hierarchy breadcrumb for context
- ✅ Click result → navigate to task
- ✅ Sort by relevance score
- ✅ Integration with Phase 3.6A tag filters
- ✅ Database indexes for performance
- ✅ Empty results state
- ✅ Performance target: <100ms for 1000 tasks

### Nice-to-Have (Future):
- ⏸️ Search history/recent searches
- ⏸️ Suggested queries based on tags/frequent searches
- ⏸️ Advanced search syntax (e.g., `tag:work due:today`)
- ⏸️ Search result count before opening dialog
- ⏸️ Keyboard shortcuts (Ctrl+F to open search)
- ⏸️ Search within search (refine results)

---

## Testing Strategy

### Unit Tests:
- SearchService.search() with various queries
- Fuzzy scoring algorithm accuracy
- Match position calculation
- Tag filter integration
- Scope filtering (All/Current/Recently completed/Completed)

### Service Tests:
- Database query performance with 1000+ tasks
- Index effectiveness (with/without indexes)
- Search + tag filter combination
- Edge cases (empty query, special characters, very long text)

### Widget Tests:
- SearchDialog opens and displays
- Filter chips selection
- Search field input and clear
- Results list rendering
- Highlighting display
- Navigation on tap

### Integration Tests:
- Full search flow (open → type → see results → tap → navigate)
- Search + tag filter combination in real app
- Performance on device with large dataset
- Empty state display
- Cross-platform (Linux, Android)

### Manual Testing:
- Search responsiveness on device
- Keyboard interactions
- Highlighting accuracy
- Breadcrumb display
- Navigation behavior
- Performance with 1000+ tasks
- Edge cases (unicode, emojis, special chars)

### Performance Testing:
```dart
// Create performance test
void main() {
  testPerformance('Search 1000 tasks in <100ms', () async {
    // Setup: Create 1000 tasks with varied content
    final tasks = await _create1000Tasks();

    // Benchmark: Search query
    final stopwatch = Stopwatch()..start();
    final results = await searchService.search(
      query: 'test',
      scope: SearchScope.all,
    );
    stopwatch.stop();

    // Assert: <100ms
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
    expect(results.isNotEmpty, true);
  });
}
```

---

## Timeline Estimate

**Total: 7-10 days (1-2 weeks)**

### Day 1: Foundation & Database (Backend)
**Morning:**
- Add `string_similarity` dependency
- Create database migration v7 (search indexes)
- Test migration on existing database
- Write migration unit tests

**Afternoon:**
- Create `SearchService` class skeleton
- Implement `_getCandidates()` SQL query
- Test query with indexes (benchmark performance)
- **Milestone:** Database ready for search

### Day 2: Fuzzy Matching & Scoring (Backend)
**Morning:**
- Implement fuzzy scoring with `string_similarity`
- Implement weighted scoring (title > notes > tags)
- Implement match position finding
- Write unit tests for scoring

**Afternoon:**
- Implement scope filtering (All/Current/Recently completed/Completed)
- Integrate tag filters from Phase 3.6A
- Test combined search + tag filters
- **Milestone:** Search backend fully functional

### Day 3: Search Dialog UI (Frontend)
**Morning:**
- Create `SearchDialog` widget skeleton
- Implement search field with auto-focus
- Implement filter chip selection
- Wire up to SearchService

**Afternoon:**
- Implement results list with grouping (Active/Completed)
- Add loading and empty states
- Test dialog open/close
- **Milestone:** Basic search UI working

### Day 4: Result Display & Highlighting (Frontend)
**Morning:**
- Create `SearchResultTile` widget
- Implement match highlighting
- Implement hierarchy breadcrumb display
- Add notes preview

**Afternoon:**
- Implement navigation on tap
- Add scroll-to-task in main list
- Test result interaction
- **Milestone:** Full search UX complete

### Day 5: Integration & Polish
**Morning:**
- Add magnifying glass icon to HomeScreen app bar
- Connect icon to search dialog
- Test with Phase 3.6A tag filters active
- Verify filter state integration

**Afternoon:**
- Performance testing with 1000+ tasks
- UI polish (animations, transitions)
- Error handling and edge cases
- **Milestone:** Feature integrated and polished

### Day 6-7: Testing & Validation
**Day 6:**
- Complete automated test suite (unit, widget, integration)
- Manual testing on device (Linux, Android)
- Performance validation (<100ms target)
- Bug fixes if any

**Day 7:**
- Create test data script for validation
- Cross-platform testing
- Edge case testing (unicode, long text, special chars)
- **Milestone:** Feature complete and validated

### Day 8-10: Buffer & Documentation (Optional)
**If needed:**
- Address any validation findings
- Performance optimization if target not met
- Create manual test plan
- Implementation report
- **Milestone:** Phase 3.6B production-ready ✅

---

## Success Criteria

**Feature is complete when:**

1. ✅ User can tap magnifying glass icon to open search dialog
2. ✅ Search dialog has text field and filter checkboxes
3. ✅ Typing query shows filtered results in real-time
4. ✅ Search works across title, notes, and tag names
5. ✅ Fuzzy matching finds relevant results (not just exact matches)
6. ✅ Match text is highlighted in results
7. ✅ Results are grouped by Active/Completed sections
8. ✅ Results show hierarchy breadcrumb for context
9. ✅ Clicking result navigates to task in main list
10. ✅ Results sorted by relevance score (best matches first)
11. ✅ Search combines with Phase 3.6A tag filters seamlessly
12. ✅ Filter checkboxes (All/Current/Recently completed/Completed) work correctly
13. ✅ Empty results show helpful message
14. ✅ Database indexes created in migration v7
15. ✅ Performance target met (<100ms for 1000 tasks)
16. ✅ All automated tests passing (unit, widget, integration)
17. ✅ Manual testing validates UX on device
18. ✅ Cross-platform testing (Linux, Android) successful

---

## Open Questions

**For BlueKitty to clarify:**

1. **Search query persistence:**
   - Should search query persist when dialog closed/reopened?
   - Or clear query each time (start fresh)?
   - **Recommendation:** Clear on close (fresh start)

2. **Recently completed timeframe:**
   - Currently 30 days - is this correct?
   - Or should it be 7 days / 14 days / configurable?
   - **Recommendation:** 30 days (matches Recently Deleted)

3. **Search scope default:**
   - Should default be "All tasks" or "Current"?
   - **Recommendation:** "All tasks" (most comprehensive)

4. **Minimum query length:**
   - Search immediately when typing, or require 2-3 characters?
   - **Recommendation:** Search on any input (even 1 char)

5. **Tag filter visibility in search dialog:**
   - Should search dialog show active tag filters?
   - Or just apply them silently in background?
   - **Recommendation:** Show active filters with "Clear filters" button

6. **Match highlighting color:**
   - Yellow with 30% opacity (current)
   - Or different color (orange, blue, green)?
   - **Recommendation:** Yellow (standard search highlighting)

7. **Navigation behavior:**
   - Close dialog immediately on result tap?
   - Or keep dialog open and highlight result in background?
   - **Recommendation:** Close immediately (standard behavior)

---

## Risk Mitigation

### Risk: Fuzzy matching too slow with large datasets
**Mitigation:**
- Profile with 1000+ tasks first
- If too slow, use stricter SQL pre-filtering
- Consider background isolate for scoring
- Lazy load scoring (score top 100, then expand)
**Fallback:** Disable fuzzy matching, use exact LIKE only

### Risk: Search UX feels clunky on mobile
**Mitigation:**
- Follow Material Design search patterns
- Test on actual device (not just emulator)
- Smooth animations for dialog open/close
- Auto-focus search field on open
**Validation:** Manual testing before sign-off

### Risk: Highlighting breaks with complex text (unicode, emojis)
**Mitigation:**
- Test with unicode, emojis, RTL text
- Use Flutter's robust text rendering
- Handle edge cases in match position calculation
**Fallback:** Disable highlighting if rendering fails

### Risk: Database indexes don't improve performance enough
**Mitigation:**
- Benchmark with/without indexes
- Profile query execution with EXPLAIN QUERY PLAN
- Consider full-text search (FTS) if indexes insufficient
**Fallback:** Add FTS virtual table in future phase

### Risk: Search + tag filter combination confusing
**Mitigation:**
- Show active filters clearly in dialog
- Provide "Clear filters" button
- Test with users before sign-off
**Fallback:** Add help text or tooltip

---

## Out of Scope (Deferred)

**Not in Phase 3.6B:**
- ⏸️ Search history or recent searches
- ⏸️ Advanced search syntax (operators, field-specific search)
- ⏸️ Search suggestions or autocomplete
- ⏸️ Saved searches or search presets
- ⏸️ Search analytics or metrics
- ⏸️ Voice search or speech-to-text
- ⏸️ Search within specific sections only (search respects All/Current/Completed filters)
- ⏸️ Search result export or sharing
- ⏸️ Keyboard shortcuts (beyond Enter to search)

**Why deferred:** Focus on core MVP search that works excellently. Advanced features can be added in Phase 3.6C or later if needed.

---

## Implementation Notes

### String Similarity Package Usage:

```dart
import 'package:string_similarity/string_similarity.dart';

// Dice coefficient (recommended for search)
final score = StringSimilarity.compareTwoStrings('hello world', 'helo wrld');
// Returns 0.0 to 1.0 (1.0 = exact match)

// Find best match from multiple candidates
final bestMatch = StringSimilarity.findBestMatch('hello', [
  'helo',
  'world',
  'hello world',
]);
// Returns rating and index of best match
```

### Search Query Example:

```sql
-- With indexes, this query is fast (<100ms for 1000 tasks)
SELECT DISTINCT tasks.*
FROM tasks
LEFT JOIN task_tags ON tasks.id = task_tasks.task_id
LEFT JOIN tags ON task_tags.tag_id = tags.id
WHERE tasks.deleted_at IS NULL
  AND tasks.completed = 0  -- Current filter
  AND (
    LOWER(tasks.title) LIKE '%meeting%'
    OR LOWER(tasks.notes) LIKE '%meeting%'
    OR LOWER(tags.name) LIKE '%meeting%'
  )
  AND tags.id IN (?, ?)  -- Tag filter (if active)
ORDER BY tasks.position ASC
```

### Navigation to Task:

```dart
// In TaskProvider:
void navigateToTask(String taskId) {
  // Find task in tree
  final node = findNodeById(taskId);
  if (node == null) return;

  // Expand parent nodes if collapsed
  expandParentChain(node);

  // Scroll to task
  _scrollController.scrollToTask(taskId);

  // Highlight task briefly
  _highlightTask(taskId, duration: Duration(seconds: 2));

  notifyListeners();
}
```

---

## References

**Related Phases:**
- [Phase 3.6A Implementation Report](../archive/phase-3.6A/phase-3.6A-implementation-report.md) - Tag filtering foundation
- [Phase 3.5 Summary](../archive/phase-03/phase-3.5-summary.md) - Comprehensive tagging system
- [Phase 3.6 Enhancements](../archive/phase-03/phase-3.6-and-3.6.5-enhancements-from-validation.md) - Original enhancement requests

**Templates:**
- [phase-start-checklist.md](../templates/phase-start-checklist.md) - Phase initiation workflow
- [WORKFLOW-SUMMARY.md](../templates/WORKFLOW-SUMMARY.md) - Development cycle reference

**Project Documentation:**
- [PROJECT_SPEC.md](../PROJECT_SPEC.md) - Phase 3.6B authoritative scope (lines 468-486)
- [README.md](../../README.md) - Current project status

**External Dependencies:**
- [string_similarity package](https://pub.dev/packages/string_similarity) - Fuzzy string matching

---

**Prepared By:** Claude
**Status:** Draft v2 - Comprehensive scope aligned with PROJECT_SPEC.md
**Next Step:** BlueKitty review → Begin implementation or refine further

