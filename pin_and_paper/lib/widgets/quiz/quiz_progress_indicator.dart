import 'package:flutter/material.dart';

import '../../utils/theme.dart';

/// Displays quiz progress as a row of dots with an animated position indicator.
///
/// Shows [totalSteps] dots, highlighting [currentStep] as the active one.
/// Answered questions are shown with a filled dot.
class QuizProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Set<int> answeredSteps;

  const QuizProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.answeredSteps = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isCurrent = index == currentStep;
        final isAnswered = answeredSteps.contains(index);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isCurrent
                ? AppTheme.deepShadow
                : isAnswered
                    ? AppTheme.deepShadow.withValues(alpha: 0.5)
                    : AppTheme.kraftPaper,
          ),
        );
      }),
    );
  }
}
