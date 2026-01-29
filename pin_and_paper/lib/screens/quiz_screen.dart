import 'package:flutter/material.dart' hide Badge;

import 'package:provider/provider.dart';

import '../models/quiz_question.dart';
import '../providers/quiz_provider.dart';
import '../utils/theme.dart';
import '../widgets/quiz/quiz_answer_option.dart';
import '../widgets/quiz/quiz_progress_indicator.dart';
import 'badge_reveal_screen.dart';

/// Main onboarding quiz screen.
///
/// Displays 8 questions one at a time with answer options.
/// Supports custom time picker for time-based questions.
/// On completion, navigates to [BadgeRevealScreen].
class QuizScreen extends StatefulWidget {
  final bool isRetake;

  const QuizScreen({super.key, this.isRetake = false});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];
  @override
  void initState() {
    super.initState();
    // Load quiz state based on entry mode
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final quizProvider = context.read<QuizProvider>();
      if (widget.isRetake) {
        await quizProvider.loadPrefillFromSettings();
      } else {
        quizProvider.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final quizProvider = context.read<QuizProvider>();
        if (quizProvider.isFirstQuestion) {
          // On first question, confirm exit
          final shouldExit = await _showExitConfirmation();
          if (shouldExit && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          // Navigate back to previous question
          quizProvider.previousQuestion();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.warmBeige,
        appBar: AppBar(
          backgroundColor: AppTheme.warmBeige,
          elevation: 0,
          leading: Consumer<QuizProvider>(
            builder: (context, quiz, _) {
              return IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppTheme.deepShadow,
                onPressed: () {
                  if (quiz.isFirstQuestion) {
                    _showExitConfirmation().then((shouldExit) {
                      if (shouldExit && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    });
                  } else {
                    quiz.previousQuestion();
                  }
                },
              );
            },
          ),
          title: const Text(
            'Your Time Personality',
            style: TextStyle(
              color: AppTheme.deepShadow,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Consumer<QuizProvider>(
          builder: (context, quizProvider, _) {
            final question = quizProvider.currentQuestion;
            final answeredIndices = <int>{};
            for (int i = 0; i < quizProvider.questions.length; i++) {
              if (quizProvider.answers.containsKey(quizProvider.questions[i].id)) {
                answeredIndices.add(i);
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Progress indicator
                    QuizProgressIndicator(
                      currentStep: quizProvider.currentQuestionIndex,
                      totalSteps: quizProvider.questions.length,
                      answeredSteps: answeredIndices,
                    ),
                    const SizedBox(height: 8),

                    // Question counter
                    Text(
                      'Question ${quizProvider.currentQuestionIndex + 1} of ${quizProvider.questions.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Question content (scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question title
                            Text(
                              question.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Question text
                            Text(
                              question.question,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.richBlack,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Answer options
                            ...question.answers.map((answer) {
                              final currentAnswer = quizProvider.answers[question.id];
                              final isSelected = currentAnswer == answer.id ||
                                  ((answer.showTimePicker || answer.showDayPicker) &&
                                      currentAnswer != null &&
                                      currentAnswer.startsWith('${answer.id}_'));

                              // Resolve selected day name for day picker answers
                              String? selectedDayName;
                              if (answer.showDayPicker && isSelected && currentAnswer != null) {
                                final dayIndex = int.tryParse(currentAnswer.split('_').last);
                                if (dayIndex != null) {
                                  selectedDayName = _dayNames[dayIndex];
                                }
                              }

                              return QuizAnswerOption(
                                answer: answer,
                                isSelected: isSelected,
                                selectedTime: quizProvider.customTimes[question.id],
                                selectedDayName: selectedDayName,
                                onTap: () => _handleAnswerTap(
                                  quizProvider,
                                  question.id,
                                  answer,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    // Bottom navigation
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back button (invisible on first question to maintain spacing)
                          Opacity(
                            opacity: quizProvider.isFirstQuestion ? 0 : 1,
                            child: TextButton.icon(
                              onPressed: quizProvider.isFirstQuestion
                                  ? null
                                  : () => quizProvider.previousQuestion(),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('Back'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.deepShadow,
                              ),
                            ),
                          ),

                          // Next / Complete button
                          if (quizProvider.isLastQuestion)
                            ElevatedButton(
                              onPressed: (quizProvider.currentQuestionAnswered &&
                                      !quizProvider.isSubmitting)
                                  ? () => _submitQuiz(quizProvider)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: AppTheme.creamPaper,
                                disabledBackgroundColor: AppTheme.muted.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: quizProvider.isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.creamPaper,
                                      ),
                                    )
                                  : const Text('Complete Quiz'),
                            )
                          else
                            ElevatedButton(
                              onPressed: quizProvider.currentQuestionAnswered
                                  ? () => quizProvider.nextQuestion()
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.deepShadow,
                                foregroundColor: AppTheme.creamPaper,
                                disabledBackgroundColor: AppTheme.muted.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Next'),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAnswerTap(
    QuizProvider quizProvider,
    int questionId,
    QuizAnswer answer,
  ) async {
    if (answer.showTimePicker) {
      // Show time picker for custom time options
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: quizProvider.customTimes[questionId] ?? TimeOfDay.now(),
        helpText: 'Select your preferred time',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: AppTheme.creamPaper,
                dialHandColor: AppTheme.deepShadow,
                hourMinuteColor: AppTheme.kraftPaper,
              ),
            ),
            child: child!,
          );
        },
      );

      if (selectedTime != null && mounted) {
        // Store answer with hour appended to base ID
        final answerId = '${answer.id}_${selectedTime.hour}';
        quizProvider.selectAnswerWithTime(
          questionId,
          answerId,
          customTime: selectedTime,
        );
      }
    } else if (answer.showDayPicker) {
      // Show day-of-week picker dialog
      final selectedDay = await _showDayPickerDialog();
      if (selectedDay != null && mounted) {
        final answerId = '${answer.id}_$selectedDay';
        quizProvider.selectAnswer(questionId, answerId);
      }
    } else {
      quizProvider.selectAnswer(questionId, answer.id);
    }
  }

  Future<int?> _showDayPickerDialog() async {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppTheme.creamPaper,
        title: const Text(
          'Pick your week start day',
          style: TextStyle(
            color: AppTheme.richBlack,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: List.generate(7, (index) {
          // Sunday (0) and Monday (1) have dedicated quiz options
          final isDisabled = index == 0 || index == 1;
          return SimpleDialogOption(
            onPressed: isDisabled ? null : () => Navigator.pop(context, index),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              isDisabled ? '${_dayNames[index]} (select above)' : _dayNames[index],
              style: TextStyle(
                fontSize: 16,
                color: isDisabled ? AppTheme.muted : AppTheme.richBlack,
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _submitQuiz(QuizProvider quizProvider) async {
    // Validate all questions answered
    final allAnswered = quizProvider.questions.every(
      (q) => quizProvider.answers.containsKey(q.id),
    );

    if (!allAnswered) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before completing'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final success = await quizProvider.submitQuiz();

    if (!mounted) return;

    if (success) {
      final badges = quizProvider.earnedBadges ?? [];
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BadgeRevealScreen(badges: badges),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(quizProvider.errorMessage ?? 'Something went wrong'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamPaper,
        title: const Text('Leave Quiz?'),
        content: const Text(
          'Your progress will be lost. You can retake the quiz later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Leave'),
          ),
        ],
      ),
    ) ?? false;
  }
}
