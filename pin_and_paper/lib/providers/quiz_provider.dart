import 'package:flutter/material.dart' hide Badge;

import '../models/badge.dart';
import '../models/quiz_question.dart';
import '../services/quiz_inference_service.dart';
import '../services/quiz_service.dart';
import '../services/user_settings_service.dart';
import '../utils/quiz_questions.dart';

/// State management for the onboarding quiz.
///
/// Tracks current question, user answers, custom time selections,
/// and handles quiz submission (settings inference + badge calculation + persistence).
class QuizProvider extends ChangeNotifier {
  final QuizService _quizService = QuizService();
  final QuizInferenceService _inferenceService = QuizInferenceService();
  final UserSettingsService _settingsService = UserSettingsService();

  // Quiz state
  int _currentQuestionIndex = 0;
  final Map<int, String> _answers = {};
  final Map<int, TimeOfDay> _customTimes = {};

  // Submission state
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Badge>? _earnedBadges;

  // Getters
  List<QuizQuestion> get questions => QuizQuestions.all;
  int get currentQuestionIndex => _currentQuestionIndex;
  QuizQuestion get currentQuestion => questions[_currentQuestionIndex];
  Map<int, String> get answers => Map.unmodifiable(_answers);
  Map<int, TimeOfDay> get customTimes => Map.unmodifiable(_customTimes);
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<Badge>? get earnedBadges => _earnedBadges;

  bool get isFirstQuestion => _currentQuestionIndex == 0;
  bool get isLastQuestion => _currentQuestionIndex == questions.length - 1;

  /// Whether the current question has been answered.
  bool get currentQuestionAnswered =>
      _answers.containsKey(currentQuestion.id);

  /// Progress through the quiz (0.0 to 1.0).
  double get progress => (currentQuestionIndex + 1) / questions.length;

  /// Select an answer for a question.
  void selectAnswer(int questionId, String answerId) {
    _answers[questionId] = answerId;
    // Clear any custom time if switching away from custom option
    if (!answerId.contains('custom')) {
      _customTimes.remove(questionId);
    }
    notifyListeners();
  }

  /// Select an answer with a custom time (for time picker options).
  ///
  /// The answerId is constructed as "{baseId}_{hour}" (e.g., "q3_custom_20").
  void selectAnswerWithTime(
    int questionId,
    String answerId, {
    required TimeOfDay customTime,
  }) {
    _answers[questionId] = answerId;
    _customTimes[questionId] = customTime;
    notifyListeners();
  }

  /// Navigate to the next question.
  void nextQuestion() {
    if (!isLastQuestion) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  /// Navigate to the previous question.
  void previousQuestion() {
    if (!isFirstQuestion) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Jump to a specific question by index.
  void goToQuestion(int index) {
    if (index >= 0 && index < questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  /// Submit the quiz: infer settings, calculate badges, persist everything.
  ///
  /// Returns true on success, false on failure.
  Future<bool> submitQuiz() async {
    // Guard against double-submit
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Get current settings as base
      final currentSettings = await _settingsService.getUserSettings();

      // 2. Infer new settings from quiz answers
      final inferredSettings = _inferenceService.inferSettings(
        _answers,
        currentSettings,
      );

      // 3. Calculate earned badges
      _earnedBadges = _inferenceService.calculateBadges(_answers);

      // 4. Save inferred settings to database
      await _settingsService.updateUserSettings(inferredSettings);

      // 5. Persist quiz responses (answers + badges) for Explain/Personality features
      await _quizService.saveQuizCompletion(
        answers: _answers,
        badgeIds: _earnedBadges!.map<String>((b) => b.id).toList(),
      );

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save quiz results: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Load previous quiz answers for retake (prefills from current settings).
  Future<void> loadPrefillFromSettings() async {
    final settings = await _settingsService.getUserSettings();
    final prefilled = _inferenceService.prefillFromSettings(settings);
    _answers.addAll(prefilled);
    notifyListeners();
  }

  /// Reset quiz state for a fresh start.
  void reset() {
    _currentQuestionIndex = 0;
    _answers.clear();
    _customTimes.clear();
    _isSubmitting = false;
    _errorMessage = null;
    _earnedBadges = null;
    notifyListeners();
  }
}
