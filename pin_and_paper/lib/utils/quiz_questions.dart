import '../models/quiz_question.dart';

/// All quiz question definitions for the onboarding quiz.
///
/// 8 questions total (original Q2 "Weekday Reference Logic" was removed
/// and deferred to a future version — see docs/FEATURE_REQUESTS.md).
class QuizQuestions {
  QuizQuestions._();

  /// All quiz questions in display order.
  static const List<QuizQuestion> all = [
    q1CircadianRhythm,
    q2WeekStart,
    q3Tonight,
    q4Morning,
    q5TimeFormat,
    q6QuickAddParsing,
    q7AutoComplete,
    q8SleepSchedule,
  ];

  // ==========================================
  // Q1: Circadian Rhythm Detection
  // Maps to: todayCutoffHour, todayCutoffMinute
  // ==========================================

  static const q1CircadianRhythm = QuizQuestion(
    id: 1,
    title: 'Your Day Boundary',
    question:
        'It\'s 2:30am on Saturday and you haven\'t fallen asleep yet. '
        'You remark to someone that you\'ll wash the dishes "tomorrow." '
        'Do you mean Saturday or Sunday?',
    imagePath: 'assets/images/quiz/circadian.png',
    answers: [
      QuizAnswer(
        id: 'q1_a',
        text: 'Saturday',
        description: 'I consider this still Friday night — Friday hasn\'t ended yet',
      ),
      QuizAnswer(
        id: 'q1_b',
        text: 'Sunday',
        description: 'Friday is over at midnight — it\'s been Saturday for 2.5 hours',
      ),
    ],
  );

  // ==========================================
  // Q2: Week Start Preference
  // Maps to: weekStartDay
  // ==========================================

  static const q2WeekStart = QuizQuestion(
    id: 2,
    title: 'Week Start Day',
    question:
        'When you think about "this week," what day does the week start on?',
    imagePath: 'assets/images/quiz/week_start.png',
    answers: [
      QuizAnswer(
        id: 'q2_a',
        text: 'Sunday',
        description: 'Traditional US calendar style',
      ),
      QuizAnswer(
        id: 'q2_b',
        text: 'Monday',
        description: 'International / work week style',
      ),
      QuizAnswer(
        id: 'q2_c',
        text: 'Other',
        description: 'Let me pick (show day picker)',
      ),
    ],
  );

  // ==========================================
  // Q3: "Tonight" / "Evening" Time
  // Maps to: tonightHour
  // ==========================================

  static const q3Tonight = QuizQuestion(
    id: 3,
    title: '"Tonight" / "Evening" Time',
    question:
        'You tell someone to meet you "tonight." '
        'What time range do you typically mean?',
    imagePath: 'assets/images/quiz/tonight.png',
    answers: [
      QuizAnswer(
        id: 'q3_a',
        text: 'Early evening (6-8pm)',
        description: 'Dinner time, early plans',
      ),
      QuizAnswer(
        id: 'q3_b',
        text: 'Classic evening (8-10pm)',
        description: 'Standard evening hours',
      ),
      QuizAnswer(
        id: 'q3_c',
        text: 'Late night (10pm or later)',
        description: 'Night owl hours',
      ),
      QuizAnswer(
        id: 'q3_custom',
        text: 'Let me pick the exact time',
        description: 'Choose your preferred "tonight" time',
        showTimePicker: true,
      ),
    ],
  );

  // ==========================================
  // Q4: "Morning" Time Preference
  // Maps to: morningHour, earlyMorningHour
  // ==========================================

  static const q4Morning = QuizQuestion(
    id: 4,
    title: '"Morning" Time Preference',
    question:
        'You\'re planning your day and schedule a task for "morning." '
        'What time do YOU typically mean?',
    imagePath: 'assets/images/quiz/morning.png',
    answers: [
      QuizAnswer(
        id: 'q4_a',
        text: 'Early morning (7-8am)',
        description: 'Early riser, dawn hours',
      ),
      QuizAnswer(
        id: 'q4_b',
        text: 'Mid-morning (9-10am)',
        description: 'Standard morning routine',
      ),
      QuizAnswer(
        id: 'q4_c',
        text: 'Late morning (11am-noon)',
        description: 'Leisurely morning start',
      ),
      QuizAnswer(
        id: 'q4_custom',
        text: 'Let me pick the exact time',
        description: 'Choose your preferred "morning" time',
        showTimePicker: true,
      ),
    ],
  );

  // ==========================================
  // Q5: Display Time Format
  // Maps to: use24HourTime
  // ==========================================

  static const q5TimeFormat = QuizQuestion(
    id: 5,
    title: 'Time Display Format',
    question: 'How do you prefer to see times displayed?',
    answers: [
      QuizAnswer(
        id: 'q5_a',
        text: '3:00 PM',
        description: '12-hour format with AM/PM',
      ),
      QuizAnswer(
        id: 'q5_b',
        text: '15:00',
        description: '24-hour format (military time)',
      ),
    ],
  );

  // ==========================================
  // Q6: Quick Add Date Parsing
  // Maps to: enableQuickAddDateParsing
  // ==========================================

  static const q6QuickAddParsing = QuizQuestion(
    id: 6,
    title: 'Quick Add Behavior',
    question:
        'When you type "Call dentist Jan 15" in the quick-add field, '
        'what should happen?',
    answers: [
      QuizAnswer(
        id: 'q6_a',
        text: 'Automatically detect the date',
        description: 'Highlight "Jan 15" and set it as the due date',
      ),
      QuizAnswer(
        id: 'q6_b',
        text: 'Keep it simple',
        description: 'Just create a task titled "Call dentist Jan 15"',
      ),
    ],
  );

  // ==========================================
  // Q7: Task Completion Behavior
  // Maps to: autoCompleteChildren
  // ==========================================

  static const q7AutoComplete = QuizQuestion(
    id: 7,
    title: 'Subtask Completion',
    question:
        'You complete a parent task that has 3 unfinished subtasks. '
        'What should happen to the subtasks?',
    answers: [
      QuizAnswer(
        id: 'q7_a',
        text: 'Ask me every time',
        description: 'I\'ll decide case-by-case',
      ),
      QuizAnswer(
        id: 'q7_b',
        text: 'Always mark them complete too',
        description: 'Parent done = all done',
      ),
      QuizAnswer(
        id: 'q7_c',
        text: 'Leave them incomplete',
        description: 'I\'ll complete them separately',
      ),
    ],
  );

  // ==========================================
  // Q8: Sleep Schedule (cross-validates Q1)
  // Maps to: refines todayCutoffHour
  // ==========================================

  static const q8SleepSchedule = QuizQuestion(
    id: 8,
    title: 'Sleep Schedule',
    question: 'On a usual day, what time do you fall asleep?',
    answers: [
      QuizAnswer(
        id: 'q8_a',
        text: 'Before midnight (9pm-11:59pm)',
        description: 'Early to bed',
      ),
      QuizAnswer(
        id: 'q8_b',
        text: '12am-2am',
        description: 'Around midnight',
      ),
      QuizAnswer(
        id: 'q8_c',
        text: '2am-4am',
        description: 'Late night',
      ),
      QuizAnswer(
        id: 'q8_d',
        text: '4am or later / Varies wildly',
        description: 'No consistent schedule',
      ),
    ],
  );
}
