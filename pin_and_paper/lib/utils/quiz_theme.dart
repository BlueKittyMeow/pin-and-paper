import 'package:flutter/material.dart';
import 'theme.dart';

/// Theme configuration for the onboarding quiz and badge system (Phase 3.9)
///
/// This separates quiz-specific theming from the main AppTheme, making it
/// easy to swap quiz aesthetics without affecting the rest of the app.
class QuizTheme {
  final Color badgeBorder;
  final Color badgeBackground;
  final Color sashBackground;
  final Color illustrationPrimary;
  final Color illustrationSecondary;
  final Color illustrationAccent;
  final Color celebrationAccent;
  final Color progressDotActive;
  final Color progressDotInactive;
  final Color questionCardBackground;
  final Color answerCardBackground;
  final Color answerCardSelected;

  const QuizTheme({
    required this.badgeBorder,
    required this.badgeBackground,
    required this.sashBackground,
    required this.illustrationPrimary,
    required this.illustrationSecondary,
    required this.illustrationAccent,
    required this.celebrationAccent,
    required this.progressDotActive,
    required this.progressDotInactive,
    required this.questionCardBackground,
    required this.answerCardBackground,
    required this.answerCardSelected,
  });

  /// Witchy Flatlay quiz theme (matches main app aesthetic)
  static const QuizTheme witchyFlatlay = QuizTheme(
    badgeBorder: AppTheme.warmWood,
    badgeBackground: AppTheme.creamPaper,
    sashBackground: AppTheme.kraftPaper,
    illustrationPrimary: AppTheme.deepShadow,
    illustrationSecondary: AppTheme.mutedLavender,
    illustrationAccent: AppTheme.softSage,
    celebrationAccent: AppTheme.mutedLavender,
    progressDotActive: AppTheme.deepShadow,
    progressDotInactive: AppTheme.kraftPaper,
    questionCardBackground: AppTheme.creamPaper,
    answerCardBackground: AppTheme.warmBeige,
    answerCardSelected: AppTheme.mutedLavender,
  );

  /// Default theme (currently just the Witchy Flatlay theme)
  static const QuizTheme defaultTheme = witchyFlatlay;
}
