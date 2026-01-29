import 'package:flutter/material.dart' hide Badge;

import '../../models/badge.dart';
import '../../models/user_settings.dart';
import '../../services/quiz_inference_service.dart';
import '../../services/quiz_service.dart';
import '../../services/user_settings_service.dart';
import '../../utils/badge_definitions.dart';
import '../../utils/quiz_questions.dart';
import '../../utils/theme.dart';

/// Shows how quiz answers mapped to current settings.
///
/// Displays each setting with its quiz source and indicates
/// when a setting has been manually overridden since the quiz.
class SettingsExplanationDialog extends StatefulWidget {
  const SettingsExplanationDialog({super.key});

  /// Show the dialog as a full-screen modal route.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.warmBeige,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SettingsExplanationDialog(),
    );
  }

  @override
  State<SettingsExplanationDialog> createState() =>
      _SettingsExplanationDialogState();
}

class _SettingsExplanationDialogState extends State<SettingsExplanationDialog> {
  bool _isLoading = true;
  String? _error;

  Map<int, String>? _quizAnswers;
  UserSettings? _currentSettings;
  UserSettings? _quizInferredSettings;
  List<Badge> _earnedBadges = [];
  DateTime? _completedAt;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final quizService = QuizService();
      final settingsService = UserSettingsService();
      final inferenceService = QuizInferenceService();

      final answers = await quizService.getSavedAnswers();
      if (answers == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No quiz data found. Take the quiz first!';
          _isLoading = false;
        });
        return;
      }

      final currentSettings = await settingsService.getUserSettings();
      final inferredSettings =
          inferenceService.inferSettings(answers, UserSettings.defaults());
      final completedAt = await quizService.getQuizCompletedAt();

      final badgeIds = await quizService.getEarnedBadgeIds();
      final badges = <Badge>[];
      if (badgeIds != null) {
        for (final id in badgeIds) {
          final badge = BadgeDefinitions.getBadgeById(id);
          if (badge != null) badges.add(badge);
        }
      }

      if (!mounted) return;
      setState(() {
        _quizAnswers = answers;
        _currentSettings = currentSettings;
        _quizInferredSettings = inferredSettings;
        _earnedBadges = badges;
        _completedAt = completedAt;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load quiz data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Explain My Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.richBlack,
                ),
              ),
            ),
            const SizedBox(height: 4),

            if (_completedAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Quiz taken ${_formatDate(_completedAt!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.deepShadow))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppTheme.muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _buildExplanationList(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExplanationList(ScrollController controller) {
    final explanations = _buildExplanations();

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: explanations.length + (_earnedBadges.isNotEmpty ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0 && _earnedBadges.isNotEmpty) {
          return _buildBadgeSummary();
        }
        final expIndex = _earnedBadges.isNotEmpty ? index - 1 : index;
        return explanations[expIndex];
      },
    );
  }

  Widget _buildBadgeSummary() {
    final individual = _earnedBadges.where((b) => !b.isCombo).toList();
    final combo = _earnedBadges.where((b) => b.isCombo).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.creamPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.kraftPaper),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Badges',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.richBlack,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...individual.map((b) => _badgeChip(b, isCombo: false)),
              ...combo.map((b) => _badgeChip(b, isCombo: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(Badge badge, {required bool isCombo}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCombo
            ? AppTheme.mutedLavender.withValues(alpha: 0.12)
            : AppTheme.kraftPaper.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: isCombo
            ? Border.all(
                color: AppTheme.mutedLavender.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        badge.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isCombo ? AppTheme.mutedLavender : AppTheme.deepShadow,
        ),
      ),
    );
  }

  List<Widget> _buildExplanations() {
    final answers = _quizAnswers!;
    final current = _currentSettings!;
    final inferred = _quizInferredSettings!;
    final widgets = <Widget>[];

    // Q1 + Q8: Day cutoff
    final q1Answer = answers[1];
    final q8Answer = answers[8];
    final cutoffOverridden = current.todayCutoffHour != inferred.todayCutoffHour ||
        current.todayCutoffMinute != inferred.todayCutoffMinute;
    widgets.add(_buildExplanationCard(
      setting: 'My day ends at',
      currentValue: _formatTime(current.todayCutoffHour, current.todayCutoffMinute),
      quizAnswer: _describeAnswer(1, q1Answer),
      quizDetail: q8Answer != null
          ? 'Sleep schedule: ${_describeAnswer(8, q8Answer)}'
          : null,
      isOverridden: cutoffOverridden,
      quizValue: cutoffOverridden
          ? _formatTime(inferred.todayCutoffHour, inferred.todayCutoffMinute)
          : null,
    ));

    // Q2: Week start
    final q2Answer = answers[2];
    final weekOverridden = current.weekStartDay != inferred.weekStartDay;
    widgets.add(_buildExplanationCard(
      setting: 'Week starts on',
      currentValue: _dayName(current.weekStartDay),
      quizAnswer: _describeAnswer(2, q2Answer),
      isOverridden: weekOverridden,
      quizValue: weekOverridden ? _dayName(inferred.weekStartDay) : null,
    ));

    // Q3: Tonight
    final q3Answer = answers[3];
    final tonightOverridden = current.tonightHour != inferred.tonightHour;
    widgets.add(_buildExplanationCard(
      setting: '"Tonight" means',
      currentValue: _formatHour(current.tonightHour),
      quizAnswer: _describeAnswer(3, q3Answer),
      isOverridden: tonightOverridden,
      quizValue: tonightOverridden ? _formatHour(inferred.tonightHour) : null,
    ));

    // Q4: Morning
    final q4Answer = answers[4];
    final morningOverridden = current.morningHour != inferred.morningHour;
    widgets.add(_buildExplanationCard(
      setting: '"Morning" means',
      currentValue: _formatHour(current.morningHour),
      quizAnswer: _describeAnswer(4, q4Answer),
      isOverridden: morningOverridden,
      quizValue: morningOverridden ? _formatHour(inferred.morningHour) : null,
    ));

    // Q5: Time format
    final q5Answer = answers[5];
    final timeFormatOverridden = current.use24HourTime != inferred.use24HourTime;
    widgets.add(_buildExplanationCard(
      setting: 'Time format',
      currentValue: current.use24HourTime ? '24-hour' : '12-hour (AM/PM)',
      quizAnswer: _describeAnswer(5, q5Answer),
      isOverridden: timeFormatOverridden,
      quizValue: timeFormatOverridden
          ? (inferred.use24HourTime ? '24-hour' : '12-hour (AM/PM)')
          : null,
    ));

    // Q6: Quick add
    final q6Answer = answers[6];
    final quickAddOverridden =
        current.enableQuickAddDateParsing != inferred.enableQuickAddDateParsing;
    widgets.add(_buildExplanationCard(
      setting: 'Quick Add parsing',
      currentValue:
          current.enableQuickAddDateParsing ? 'Enabled' : 'Disabled',
      quizAnswer: _describeAnswer(6, q6Answer),
      isOverridden: quickAddOverridden,
      quizValue: quickAddOverridden
          ? (inferred.enableQuickAddDateParsing ? 'Enabled' : 'Disabled')
          : null,
    ));

    // Q7: Auto-complete
    final q7Answer = answers[7];
    final autoCompleteOverridden =
        current.autoCompleteChildren != inferred.autoCompleteChildren;
    widgets.add(_buildExplanationCard(
      setting: 'Subtask completion',
      currentValue: _autoCompleteLabel(current.autoCompleteChildren),
      quizAnswer: _describeAnswer(7, q7Answer),
      isOverridden: autoCompleteOverridden,
      quizValue: autoCompleteOverridden
          ? _autoCompleteLabel(inferred.autoCompleteChildren)
          : null,
    ));

    // Bottom padding
    widgets.add(const SizedBox(height: 20));

    return widgets;
  }

  Widget _buildExplanationCard({
    required String setting,
    required String currentValue,
    required String quizAnswer,
    String? quizDetail,
    required bool isOverridden,
    String? quizValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.creamPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverridden
              ? AppTheme.warning.withValues(alpha: 0.5)
              : AppTheme.kraftPaper,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Setting name + current value
          Row(
            children: [
              Expanded(
                child: Text(
                  setting,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.richBlack,
                  ),
                ),
              ),
              Text(
                currentValue,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.deepShadow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quiz answer source
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 14,
                color: AppTheme.muted.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quizAnswer,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ],
          ),

          if (quizDetail != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                quizDetail,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Override indicator
          if (isOverridden && quizValue != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, size: 12, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Manually changed (quiz set: $quizValue)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== Helpers ==========

  String _describeAnswer(int questionId, String? answerId) {
    if (answerId == null) return 'Not answered';

    // Find the question
    final questions = QuizQuestions.all;
    final question = questions.firstWhere(
      (q) => q.id == questionId,
      orElse: () => questions.first,
    );

    // Handle custom time answers (e.g., q3_custom_20)
    if (answerId.contains('custom_')) {
      final hour = int.tryParse(answerId.split('_').last);
      if (hour != null) {
        return '${question.title}: Custom (${_formatHour(hour)})';
      }
    }

    // Handle day picker answers (e.g., q2_c_3 → Wednesday)
    if (answerId.startsWith('q2_c_')) {
      final day = int.tryParse(answerId.split('_').last);
      if (day != null) {
        return '"Other" (${_dayName(day)})';
      }
    }

    // Find the answer text
    for (final answer in question.answers) {
      if (answerId == answer.id || answerId.startsWith('${answer.id}_')) {
        return '"${answer.text}"';
      }
    }

    return answerId;
  }

  String _formatTime(int hour, int minute) {
    if (_currentSettings?.use24HourTime == true) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatHour(int hour) {
    if (_currentSettings?.use24HourTime == true) {
      return '${hour.toString().padLeft(2, '0')}:00';
    }
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  String _dayName(int day) {
    const days = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday',
    ];
    return days[day.clamp(0, 6)];
  }

  String _autoCompleteLabel(String value) {
    switch (value) {
      case 'always':
        return 'Always complete';
      case 'never':
        return 'Never complete';
      default:
        return 'Ask each time';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
