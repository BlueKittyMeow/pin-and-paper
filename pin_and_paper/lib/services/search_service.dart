import 'package:sqflite/sqflite.dart';
import 'package:string_similarity/string_similarity.dart';
import '../models/task.dart';
import '../models/search_result.dart';
import '../models/filter_state.dart';

/// Service for fuzzy search across tasks with relevance scoring
///
/// Phase 3.6B: Universal Search
/// - Two-stage filtering: SQL LIKE for candidates, then Dart fuzzy scoring
/// - Supports search scopes (all/current/recentlyCompleted/completed)
/// - Integrates with Phase 3.6A tag filtering
/// - Performance instrumentation (<100ms target)
/// - Comprehensive error handling
class SearchService {
  final Database _db;

  SearchService(this._db);

  /// Performs fuzzy search across tasks
  /// Returns results with relevance scores
  ///
  /// v4.1: Complete implementation with error handling and performance instrumentation
  Future<List<SearchResult>> search({
    required String query,
    required SearchScope scope,
    FilterState? tagFilters,
  }) async {
    try {
      // v4: Separate timing for SQL vs scoring (HIGH FIX #2)
      final totalStopwatch = Stopwatch()..start();
      final sqlStopwatch = Stopwatch()..start();

      // 1. Get all potential matches from database
      final candidates = await _getCandidates(query, scope, tagFilters);
      final sqlTime = sqlStopwatch.elapsedMilliseconds;

      // 2. Score each candidate with fuzzy matching
      final scoringStopwatch = Stopwatch()..start();
      final scored = _scoreResults(candidates, query);
      final scoringTime = scoringStopwatch.elapsedMilliseconds;

      // 3. Sort by relevance score (descending) with stable tie-breaker (v3 - Codex)
      scored.sort((a, b) {
        final scoreDiff = b.score.compareTo(a.score);
        if (scoreDiff != 0) return scoreDiff;
        // Tie-breaker: use position for stable ordering
        return a.task.position.compareTo(b.task.position);
      });

      totalStopwatch.stop();
      final totalTime = totalStopwatch.elapsedMilliseconds;

      // v4: Detailed performance logging (HIGH FIX #2)
      if (totalTime > 100) {
        print('⚠️ Search performance issue detected:');
        print('   Total: ${totalTime}ms (target: <100ms)');
        print('   SQL query: ${sqlTime}ms (${(sqlTime / totalTime * 100).toStringAsFixed(0)}%)');
        print('   Dart scoring: ${scoringTime}ms (${(scoringTime / totalTime * 100).toStringAsFixed(0)}%)');
        print('   Candidates: ${candidates.length}');
        print('   Results: ${scored.length}');

        if (sqlTime > 80) {
          print('   → SQL query is slow - consider FTS5 (see docs/phase-3.6B/fts5-analysis.md)');
        }
        if (scoringTime > 50) {
          print('   → Dart scoring is slow - consider background isolate or reduce candidates');
        }
      } else {
        // Log successful fast searches too (for documentation)
        print('✅ Search completed in ${totalTime}ms (SQL: ${sqlTime}ms, Scoring: ${scoringTime}ms, ${scored.length} results)');
      }

      return scored;
    } on DatabaseException catch (e) {
      print('Database error during search: $e');
      throw SearchException('Failed to query database: ${e.message}');
    } on FormatException catch (e) {
      print('Format error during search (likely bad query): $e');
      throw SearchException('Invalid search query: ${e.message}');
    } catch (e, stackTrace) {
      print('Unexpected error during search: $e\n$stackTrace');
      throw SearchException('Search failed unexpectedly');
    }
  }

  Future<List<TaskWithTags>> _getCandidates(
    String query,
    SearchScope scope,
    FilterState? tagFilters,
  ) async {
    // v4.1 CRITICAL FIX (Codex): Declare outside try for error logging access
    String sql = '';
    List<dynamic> args = [];

    try {
      // v3: Use SQL LIKE for initial filtering (no indexes help leading-wildcard)
      // NOTE: LIKE '%query%' cannot use B-tree indexes (Gemini finding)

      final conditions = <String>[];
      args = <dynamic>[]; // Assign to outer variable

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
          args.add(cutoff.millisecondsSinceEpoch); // FIXED
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
        // NOTE: Task model doesn't have notes field yet, only searching title and tags
        conditions.add('''
          (LOWER(tasks.title) LIKE ? ESCAPE '\\\\'
           OR LOWER(tags.name) LIKE ? ESCAPE '\\\\')
        ''');
        final pattern = '%$escapedQuery%';
        args.addAll([pattern, pattern]);
      }

      // v4.1 HIGH FIX (Codex): Apply tag filters whenever present (not just when tags selected)
      // This ensures presence filters (onlyTagged/onlyUntagged) work even with empty selectedTagIds
      if (tagFilters != null) {
        _applyTagFilters(conditions, args, tagFilters);
      }

      // v4 FIX: Removed redundant DISTINCT (GROUP BY sufficient)
      // v4.1 CRITICAL FIX: Assign to outer variable for error logging
      //
      // v4.1 MEDIUM (Codex note): LIMIT 200 candidate cap trade-off
      // - Caps candidates BEFORE scoring (sorted by position, not relevance)
      // - Can miss relevant results if >200 tasks match LIKE filter
      // - ACCEPTABLE because:
      //   * Prevents scoring 1000+ tasks on queries like "a" or "the"
      //   * Ensures search stays under 100ms even with poor queries
      //   * Most searches return <50 results
      //   * Position-based ordering is reasonable proxy for task relevance
      // - If users complain about missed results: consider adaptive cap based on query length
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
        LIMIT 200  -- v3: Candidate cap to prevent runaway queries (trade-off documented above)
      ''';

      final results = await _db.rawQuery(sql, args);
      return results.map((row) => TaskWithTags.fromMap(row)).toList();
    } on DatabaseException catch (e) {
      print('SQL error in _getCandidates: $e\nSQL: $sql\nArgs: $args');
      rethrow; // Let search() handle it
    } catch (e) {
      print('Error parsing search candidates: $e');
      rethrow;
    }
  }

  // v4.1 UPDATED (Codex HIGH fix): Reuse Phase 3.6A filter logic for consistency
  void _applyTagFilters(
    List<String> conditions,
    List<dynamic> args,
    FilterState filters,
  ) {
    // Reuse exact logic from TaskService.getFilteredTasks()
    // This ensures search behavior matches main list filtering

    // v4.1 HIGH FIX: Only apply tag ID logic when tags are actually selected
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

    // v4.1 HIGH FIX (Codex): ALWAYS apply presence filter (even when selectedTagIds is empty)
    // This allows "only tagged" or "only untagged" searches without specific tags
    // v4 FIX: Corrected enum values (verified from Phase 3.6A)
    // Tag presence filter
    switch (filters.presenceFilter) {
      case TagPresenceFilter.any:
        // No filter
        break;
      case TagPresenceFilter.onlyTagged: // CORRECTED (not .tagged)
        conditions.add('tags.id IS NOT NULL');
        break;
      case TagPresenceFilter.onlyUntagged: // CORRECTED (not .untagged)
        conditions.add('tags.id IS NULL');
        break;
    }
  }

  // ============================================================================
  // Scoring methods - Fuzzy matching and match highlighting
  // ============================================================================

  /// Score all candidates using fuzzy matching
  ///
  /// v4.1: Complete implementation with error handling
  /// - Weighted scoring (title 70%, tags 30% - notes field not yet available)
  /// - Error handling for individual task scoring failures
  /// - Match position finding for highlighting
  List<SearchResult> _scoreResults(List<TaskWithTags> candidates, String query) {
    final results = <SearchResult>[];

    for (final taskWithTags in candidates) {
      try {
        final task = taskWithTags.task;

        // Calculate relevance score using string_similarity
        final titleScore = _fuzzyScore(task.title, query);

        // NOTE: Task model doesn't have notes field yet
        // When notes are added, adjust weights to: title 60%, notes 30%, tags 10%
        // For now: title 70%, tags 30%
        final tagScore = _getTagScore(taskWithTags.tagNames, query);

        // Weighted scoring (adjusted for missing notes field)
        final finalScore = (titleScore * 0.7) + (tagScore * 0.3);

        // Find match positions for highlighting
        final matches = _findMatches(task, taskWithTags.tagNames, query);

        results.add(SearchResult(
          task: task,
          score: finalScore,
          matches: matches,
        ));
      } catch (e) {
        // v4: Log but continue scoring other results
        print('Error scoring task ${taskWithTags.task.id}: $e');
        // Skip this result
      }
    }

    return results;
  }

  /// Calculate fuzzy match score between text and query
  ///
  /// v3 FIX (Codex): Handle short queries (<2 chars) where fuzzy matching fails
  /// - Short queries use contains-based scoring
  /// - Longer queries use string_similarity package
  /// - Returns score from 0.0 to 1.0
  double _fuzzyScore(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    // Short query optimization: use contains-based scoring
    if (lowerQuery.length < 2) {
      return lowerText.contains(lowerQuery) ? 1.0 : 0.0;
    }

    // Use string_similarity package for longer queries
    return StringSimilarity.compareTwoStrings(lowerText, lowerQuery);
  }

  /// Calculate tag relevance score using GROUP_CONCAT data
  ///
  /// v3 FIX (Codex): Implement tag scoring
  /// - Simple contains check for tag names
  /// - Could be enhanced with fuzzy matching if needed
  double _getTagScore(String? tagNames, String query) {
    if (tagNames == null || tagNames.isEmpty) return 0.0;

    final lowerTags = tagNames.toLowerCase();
    final lowerQuery = query.toLowerCase();

    // Simple contains check for tags
    // Could be enhanced with fuzzy matching if needed
    return lowerTags.contains(lowerQuery) ? 1.0 : 0.0;
  }

  /// Find all match positions in task fields for highlighting
  ///
  /// v3 FIX (Codex): Implement match position finding
  /// - Finds matches in title and tag names (notes not yet available)
  /// - Returns MatchPositions object for UI highlighting
  MatchPositions _findMatches(Task task, String? tagNames, String query) {
    // Find all occurrences of query in task fields
    // Return positions for highlighting
    final titleMatches = _findInString(task.title, query);

    // NOTE: Task model doesn't have notes field yet
    // When notes are added, include: _findInString(task.notes!, query)
    final notesMatches = <MatchRange>[];

    final tagMatches = tagNames != null
        ? _findInString(tagNames, query)
        : <MatchRange>[];

    return MatchPositions(
      titleMatches: titleMatches,
      notesMatches: notesMatches,
      tagMatches: tagMatches,
    );
  }

  /// Find all occurrences of query in text (case-insensitive)
  ///
  /// v3 FIX (Codex): Implement substring finding
  /// - Case-insensitive search
  /// - Allows overlapping matches
  /// - Returns list of MatchRange objects
  List<MatchRange> _findInString(String text, String query) {
    final matches = <MatchRange>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int startIndex = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, startIndex);
      if (index == -1) break;

      matches.add(MatchRange(index, index + query.length));
      startIndex = index + 1; // Allow overlapping matches
    }

    return matches;
  }
}

/// Search scope for filtering tasks
///
/// Phase 3.6B: Controls which tasks are searched
enum SearchScope {
  /// Search all tasks (active and completed)
  all,

  /// Search only current (incomplete) tasks
  current,

  /// Search tasks completed in the last 30 days
  recentlyCompleted,

  /// Search all completed tasks
  completed,
}

/// Custom exception for search errors
///
/// Phase 3.6B: Provides user-friendly error messages
/// - Used for database errors, format errors, and unexpected failures
/// - Allows UI to display helpful error messages to users
class SearchException implements Exception {
  final String message;

  SearchException(this.message);

  @override
  String toString() => 'SearchException: $message';
}
