import 'package:string_similarity/string_similarity.dart';
import '../models/task.dart';

class TaskMatchingService {
  static const double CONFIDENT_THRESHOLD = 0.75;  // 75% similarity = auto-match
  static const double POSSIBLE_THRESHOLD = 0.30;    // 30% = show as option (lowered for debugging)

  // Extract action from completion phrase
  String extractAction(String input) {
    // Remove completion indicators and articles
    final cleaned = input.toLowerCase()
      // Remove completion words (with optional trailing space)
      .replaceAll(RegExp(r'\b(i|ive|finished|done|completed|did)\b\s*'), '')
      // Remove articles
      .replaceAll(RegExp(r'\b(the|a|an)\b\s*'), '')
      .trim();

    return cleaned;
  }

  // Find best matching tasks
  List<TaskMatch> findMatches(String input, List<Task> tasks) {
    final action = extractAction(input);
    if (action.isEmpty) return [];

    final incompleteTasks = tasks.where((t) => !t.completed).toList();
    final matches = <TaskMatch>[];

    for (final task in incompleteTasks) {
      final taskLower = task.title.toLowerCase();
      double similarity;

      // Priority 1: Exact substring match (100%)
      if (taskLower.contains(action)) {
        similarity = 1.0;
      }
      // Priority 2: Individual words match
      else {
        final actionWords = action.split(RegExp(r'\s+'));
        final taskWords = taskLower.split(RegExp(r'\s+'));

        // Count how many action words appear in task
        int matchedWords = 0;
        for (final actionWord in actionWords) {
          if (actionWord.length < 2) continue; // Skip single chars

          for (final taskWord in taskWords) {
            if (taskWord.contains(actionWord) || actionWord.contains(taskWord)) {
              matchedWords++;
              break;
            }
          }
        }

        // Calculate similarity based on word matches
        if (actionWords.isNotEmpty) {
          similarity = matchedWords / actionWords.length;
        } else {
          similarity = 0.0;
        }

        // If no word matches, try fuzzy matching as fallback
        if (similarity == 0.0) {
          similarity = StringSimilarity.compareTwoStrings(action, taskLower);
        }
      }

      if (similarity >= POSSIBLE_THRESHOLD) {
        matches.add(TaskMatch(task: task, similarity: similarity));
      }
    }

    // Sort by similarity (highest first)
    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches;
  }

  // Get best match if confident
  TaskMatch? getConfidentMatch(String input, List<Task> tasks) {
    final matches = findMatches(input, tasks);
    if (matches.isEmpty) return null;

    final best = matches.first;
    return best.similarity >= CONFIDENT_THRESHOLD ? best : null;
  }
}

class TaskMatch {
  final Task task;
  final double similarity;

  TaskMatch({required this.task, required this.similarity});
}
