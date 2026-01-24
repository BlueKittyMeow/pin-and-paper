import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../utils/constants.dart';
import 'database_service.dart';

/// Service for managing quiz completion state and persisted responses.
///
/// Uses the quiz_responses database table (single-row, id=1) to store
/// quiz answers and earned badge IDs for "Explain My Settings" and
/// "Your Time Personality" features.
class QuizService {
  final DatabaseService _dbService = DatabaseService.instance;

  /// Check if user has completed the onboarding quiz.
  Future<bool> hasCompletedOnboardingQuiz() async {
    final db = await _dbService.database;
    final result = await db.query(
      AppConstants.quizResponsesTable,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (result.isEmpty) return false;
    return (result.first['completed'] as int?) == 1;
  }

  /// Get quiz completion timestamp.
  Future<DateTime?> getQuizCompletedAt() async {
    final db = await _dbService.database;
    final result = await db.query(
      AppConstants.quizResponsesTable,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (result.isEmpty) return null;
    final timestamp = result.first['completed_at'] as int?;
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Save quiz completion with answers and earned badges.
  ///
  /// Uses ConflictAlgorithm.replace so retaking the quiz overwrites
  /// the previous response.
  Future<void> saveQuizCompletion({
    required Map<int, String> answers,
    required List<String> badgeIds,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final answersJson = jsonEncode(
      answers.map((k, v) => MapEntry(k.toString(), v)),
    );
    final badgesJson = jsonEncode(badgeIds);

    await db.insert(
      AppConstants.quizResponsesTable,
      {
        'id': 1,
        'quiz_version': 1,
        'completed': 1,
        'completed_at': now,
        'answers': answersJson,
        'badges_earned': badgesJson,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get saved quiz answers (for "Explain My Settings" and quiz retake prefill).
  Future<Map<int, String>?> getSavedAnswers() async {
    final db = await _dbService.database;
    final result = await db.query(
      AppConstants.quizResponsesTable,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (result.isEmpty) return null;

    final answersJson = result.first['answers'] as String?;
    if (answersJson == null) return null;

    final decoded = jsonDecode(answersJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(int.parse(k), v as String));
  }

  /// Get earned badge IDs (for "Your Time Personality" display).
  Future<List<String>?> getEarnedBadgeIds() async {
    final db = await _dbService.database;
    final result = await db.query(
      AppConstants.quizResponsesTable,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (result.isEmpty) return null;

    final badgesJson = result.first['badges_earned'] as String?;
    if (badgesJson == null) return null;

    final decoded = jsonDecode(badgesJson) as List<dynamic>;
    return decoded.cast<String>();
  }

  /// Get the quiz version that was completed.
  Future<int?> getQuizVersion() async {
    final db = await _dbService.database;
    final result = await db.query(
      AppConstants.quizResponsesTable,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (result.isEmpty) return null;
    return result.first['quiz_version'] as int?;
  }

  /// Reset quiz state (for "Retake Quiz").
  ///
  /// Deletes the quiz_responses row entirely, allowing the user
  /// to retake the quiz from scratch.
  Future<void> resetQuiz() async {
    final db = await _dbService.database;
    await db.delete(
      AppConstants.quizResponsesTable,
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
