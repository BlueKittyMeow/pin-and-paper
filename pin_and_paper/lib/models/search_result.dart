import 'task.dart';

/// Result from a search operation with relevance scoring and match positions
///
/// Phase 3.6B: Universal Search
/// - Contains the matched task
/// - Relevance score (0.0 to 1.0) for ranking
/// - Match positions for highlighting in UI
class SearchResult {
  final Task task;
  final double score; // 0.0 to 1.0 relevance
  final MatchPositions matches; // For highlighting

  SearchResult({
    required this.task,
    required this.score,
    required this.matches,
  });
}

/// Task with concatenated tag names from SQL GROUP_CONCAT
///
/// Phase 3.6B: Used internally by SearchService for efficient tag scoring
/// - Avoids N+1 queries for tag data
/// - Tag names are space-separated from GROUP_CONCAT(tags.name, ' ')
class TaskWithTags {
  final Task task;
  final String? tagNames; // Space-separated tag names from GROUP_CONCAT

  TaskWithTags({required this.task, this.tagNames});

  factory TaskWithTags.fromMap(Map<String, dynamic> map) {
    return TaskWithTags(
      task: Task.fromMap(map),
      tagNames: map['tag_names'] as String?,
    );
  }
}

/// Match positions for highlighting search terms in UI
///
/// Phase 3.6B: Contains all match positions across different fields
/// - titleMatches: Positions where query matches in task title
/// - notesMatches: Positions where query matches in task notes
/// - tagMatches: Positions where query matches in tag names
class MatchPositions {
  final List<MatchRange> titleMatches;
  final List<MatchRange> notesMatches;
  final List<MatchRange> tagMatches;

  MatchPositions({
    required this.titleMatches,
    required this.notesMatches,
    this.tagMatches = const [],
  });
}

/// Range of a match within a string (start and end positions)
///
/// Phase 3.6B: Renamed from "Match" to avoid collision with dart:core Match
/// - start: Starting index of the match (inclusive)
/// - end: Ending index of the match (exclusive)
class MatchRange {
  final int start;
  final int end;

  MatchRange(this.start, this.end);
}
