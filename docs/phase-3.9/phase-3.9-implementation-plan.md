# Phase 3.9 Implementation Plan: Onboarding Quiz & User Preferences

**Version:** 1.0
**Created:** 2026-01-23
**Status:** Ready for Implementation
**Estimated Duration:** 10 days

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites & Dependencies](#prerequisites--dependencies)
3. [Architecture Overview](#architecture-overview)
4. [Database Schema Design](#database-schema-design)
5. [Data Models](#data-models)
6. [Services Layer](#services-layer)
7. [State Management](#state-management)
8. [UI Components](#ui-components)
9. [Badge System](#badge-system)
10. [Animation Implementation](#animation-implementation)
11. [Integration Points](#integration-points)
12. [Testing Strategy](#testing-strategy)
13. [Implementation Sequence](#implementation-sequence)
14. [Edge Cases & Error Handling](#edge-cases--error-handling)
15. [Performance Considerations](#performance-considerations)
16. [Accessibility](#accessibility)
17. [File Checklist](#file-checklist)

---

## Overview

Phase 3.9 implements a scenario-based onboarding quiz that infers user time perception preferences through 9 intuitive questions, awards personality badges, and exposes comprehensive settings UI for all user-configurable preferences.

**Key Features:**
- 9-question onboarding quiz with progress indicator
- Scenario-based questions (no technical jargon)
- Badge reveal ceremony with staggered animations
- 23+ individual badges + 4 special combo badges
- Comprehensive settings UI expansion
- "Retake Quiz" and "Explain My Settings" features
- First-launch detection with graceful skip option

**Phase 3.9.0 Status:** ✅ **COMPLETE**
- Theme centralization with semantic colors
- QuizTheme class created
- 6 screens migrated (38 color instances)
- All 23 badges organized (69 PNG files @1x/@2x/@3x)
- All 7 quiz/onboarding images created and integrated

**Ready to implement:** 3.9.1 (Quiz Framework) → 3.9.2 (Questions & Badges) → 3.9.3 (Settings UI) → 3.9.4 (Explain/Retake)

---

## Prerequisites & Dependencies

### Completed Phases
- ✅ Phase 3.7: DateParsingService with `todayCutoff` logic
- ✅ Phase 3.8: Notification preferences in Settings
- ✅ Phase 3.9.0: Theme cleanup & centralization

### Existing Infrastructure
- ✅ UserSettings model (28 fields, all quiz-mappable fields exist)
- ✅ UserSettingsService (CRUD operations)
- ✅ QuizTheme class (`lib/utils/quiz_theme.dart`)
- ✅ AppTheme semantic colors (success, danger, warning, info, muted)
- ✅ Badge assets: 23 badges × 3 densities = 69 PNG files
- ✅ Quiz illustrations: 4 scenario images
- ✅ Onboarding images: welcome, celebration, sash_background

### No New Dependencies Required
All features use built-in Flutter packages:
- `provider` (already in use)
- `shared_preferences` (already in use)
- Built-in animations (AnimationController, Tween, curves)
- No Lottie or external animation packages needed

---

## Architecture Overview

### File Structure

```
lib/
├── screens/
│   ├── quiz_screen.dart                  # NEW - Main quiz container with PageView
│   ├── badge_reveal_screen.dart          # NEW - Badge ceremony after quiz
│   └── settings_screen.dart              # MODIFY - Add quiz/preference sections
│
├── widgets/
│   ├── quiz_question_card.dart           # NEW - Single question layout
│   ├── quiz_answer_option.dart           # NEW - Tappable answer card
│   ├── quiz_progress_dots.dart           # NEW - Progress indicator (9 dots)
│   ├── badge_card.dart                   # NEW - Individual badge display
│   ├── settings_explanation_dialog.dart  # NEW - "Explain My Settings" modal
│   ├── time_keyword_picker.dart          # NEW - Hour picker for time keywords
│   ├── week_start_day_picker.dart        # NEW - Day-of-week dropdown
│   └── timezone_picker.dart              # NEW - Timezone selector
│
├── providers/
│   └── quiz_provider.dart                # NEW - Quiz state management
│
├── services/
│   ├── quiz_service.dart                 # NEW - First-launch detection
│   └── quiz_inference_service.dart       # NEW - Answer → Settings mapping
│
├── models/
│   ├── quiz_question.dart                # NEW - Question data structure
│   ├── quiz_answer.dart                  # NEW - Answer option structure
│   └── badge.dart                        # NEW - Badge metadata
│
└── utils/
    ├── badge_definitions.dart            # NEW - All 27 badge definitions
    └── quiz_questions.dart               # NEW - All 9 question definitions
```

### Component Relationships

```
main.dart
  ├─ FutureBuilder<bool> (quiz completed?)
  │   ├─ QuizScreen (if not completed)
  │   └─ HomeScreen (if completed)
  │
QuizScreen
  ├─ QuizProvider (state management)
  ├─ PageView (9 questions)
  │   └─ QuizQuestionCard × 9
  │       └─ QuizAnswerOption × 2-4 per question
  └─ QuizProgressDots
  │
  └─ (on completion) → QuizInferenceService.inferSettings()
      └─ UserSettingsService.updateUserSettings()
          └─ QuizService.markQuizCompleted()
              └─ BadgeRevealScreen
                  └─ HomeScreen
```

---

## Database Schema Design

### Option 1: SharedPreferences (Recommended)

**Rationale:**
- No schema migration needed
- Simpler implementation
- Quiz metadata is lightweight (boolean + timestamp)
- Single-user app doesn't need DB persistence for this

**Implementation:**
```dart
// lib/services/quiz_service.dart
class QuizService {
  static const String _quizCompletedKey = 'quiz_completed';
  static const String _quizCompletedAtKey = 'quiz_completed_at';
  static const String _quizVersionKey = 'quiz_version'; // For future quiz updates

  Future<bool> hasCompletedOnboardingQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_quizCompletedKey) ?? false;
  }

  Future<DateTime?> getQuizCompletedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final isoString = prefs.getString(_quizCompletedAtKey);
    return isoString != null ? DateTime.parse(isoString) : null;
  }

  Future<void> markQuizCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quizCompletedKey, true);
    await prefs.setString(
      _quizCompletedAtKey,
      DateTime.now().toIso8601String(),
    );
    await prefs.setInt(_quizVersionKey, 1); // Track quiz version
  }

  Future<void> resetQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_quizCompletedKey);
    await prefs.remove(_quizCompletedAtKey);
  }
}
```

### Option 2: Database Table (Alternative)

**Use if:** You want quiz metadata queryable alongside user_settings or plan to store individual answers for analytics.

**Schema:**
```sql
CREATE TABLE quiz_responses (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  quiz_version INTEGER DEFAULT 1,
  completed INTEGER DEFAULT 0,
  completed_at INTEGER,
  answers TEXT, -- JSON: {"q1": "A", "q2": "B", ...}
  badges_earned TEXT, -- JSON: ["night_owl", "monday_starter", ...]
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
```

**Migration (database_service.dart):**
```dart
// In _onUpgrade, add version 11:
if (oldVersion < 11) {
  await db.execute('''
    CREATE TABLE quiz_responses (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      quiz_version INTEGER DEFAULT 1,
      completed INTEGER DEFAULT 0,
      completed_at INTEGER,
      answers TEXT,
      badges_earned TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
}
```

### New UserSettings Field

**Required for Question 7 (Quick Add Date Parsing):**

Add to `user_settings` table:
```sql
ALTER TABLE user_settings ADD COLUMN enable_quick_add_date_parsing INTEGER DEFAULT 1;
```

**Migration (database_service.dart, version 11):**
```dart
if (oldVersion < 11) {
  await db.execute('''
    ALTER TABLE user_settings
    ADD COLUMN enable_quick_add_date_parsing INTEGER DEFAULT 1
  ''');
}
```

**Update UserSettings Model:**
```dart
// lib/models/user_settings.dart

class UserSettings {
  // ... existing fields ...

  final bool enableQuickAddDateParsing; // NEW FIELD

  const UserSettings({
    // ... existing params ...
    this.enableQuickAddDateParsing = true, // Default: ON
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      // ... existing mappings ...
      enableQuickAddDateParsing: (map['enable_quick_add_date_parsing'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // ... existing mappings ...
      'enable_quick_add_date_parsing': enableQuickAddDateParsing ? 1 : 0,
    };
  }

  UserSettings copyWith({
    // ... existing params ...
    bool? enableQuickAddDateParsing,
  }) {
    return UserSettings(
      // ... existing assignments ...
      enableQuickAddDateParsing: enableQuickAddDateParsing ?? this.enableQuickAddDateParsing,
    );
  }
}
```

---

## Data Models

### QuizQuestion Model

```dart
// lib/models/quiz_question.dart

class QuizQuestion {
  final int id; // 1-9
  final String question;
  final String? description; // Optional context/scenario
  final String? imagePath; // Optional illustration
  final List<QuizAnswer> answers;

  const QuizQuestion({
    required this.id,
    required this.question,
    this.description,
    this.imagePath,
    required this.answers,
  });
}
```

### QuizAnswer Model

```dart
// lib/models/quiz_answer.dart

class QuizAnswer {
  final String id; // e.g., "q1_a", "q1_b"
  final String label; // User-facing text
  final String? description; // Additional explanation

  const QuizAnswer({
    required this.id,
    required this.label,
    this.description,
  });
}
```

### Badge Model

```dart
// lib/models/badge.dart

enum BadgeCategory {
  circadianRhythm,
  weekStructure,
  timePerception,
  dailyRhythm,
  displayPreference,
  taskStyle,
  combo, // Special combination badges
}

class Badge {
  final String id; // e.g., "night_owl"
  final String emoji; // 🦉
  final String title; // "Night Owl"
  final String description; // "Your Friday extends past midnight..."
  final String imagePath; // assets/images/badges/1x/night_owl.png
  final BadgeCategory category;
  final bool isRare; // True for combo badges

  const Badge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.category,
    this.isRare = false,
  });

  // Helper to get density-specific path
  String getImagePath(int density) {
    final dir = density == 1 ? '1x' : density == 2 ? '2x' : '3x';
    return imagePath.replaceFirst('1x', dir);
  }
}
```

---

## Services Layer

### QuizService

```dart
// lib/services/quiz_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class QuizService {
  static const String _quizCompletedKey = 'quiz_completed';
  static const String _quizCompletedAtKey = 'quiz_completed_at';
  static const String _quizVersionKey = 'quiz_version';

  /// Check if user has completed the onboarding quiz
  Future<bool> hasCompletedOnboardingQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_quizCompletedKey) ?? false;
  }

  /// Get the timestamp when quiz was completed
  Future<DateTime?> getQuizCompletedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final isoString = prefs.getString(_quizCompletedAtKey);
    return isoString != null ? DateTime.parse(isoString) : null;
  }

  /// Mark quiz as completed (called after settings applied)
  Future<void> markQuizCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quizCompletedKey, true);
    await prefs.setString(
      _quizCompletedAtKey,
      DateTime.now().toIso8601String(),
    );
    await prefs.setInt(_quizVersionKey, 1);
  }

  /// Reset quiz state (for testing or "Retake Quiz")
  /// Note: Does NOT reset UserSettings - only quiz completion status
  Future<void> resetQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_quizCompletedKey);
    await prefs.remove(_quizCompletedAtKey);
    // Keep version to track if user has retaken
  }

  /// Get current quiz version (for future quiz updates)
  Future<int> getQuizVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_quizVersionKey) ?? 0;
  }
}
```

### QuizInferenceService

```dart
// lib/services/quiz_inference_service.dart

import '../models/user_settings.dart';
import '../models/badge.dart';
import '../utils/badge_definitions.dart';

class QuizInferenceService {
  /// Map quiz answers to UserSettings
  ///
  /// Answers format: {"q1": "q1_a", "q2": "q2_b", ...}
  Future<UserSettings> inferSettings(
    Map<int, String> answers,
    UserSettings currentSettings,
  ) async {
    // Start with current settings (preserves notification prefs from Phase 3.8)
    UserSettings inferred = currentSettings;

    // Question 1: Circadian Rhythm Detection
    final q1Answer = answers[1];
    if (q1Answer == 'q1_a') {
      // "Saturday" - Night owl, day extends past midnight
      inferred = inferred.copyWith(
        todayCutoffHour: 4,
        todayCutoffMinute: 59,
      );
    } else if (q1Answer == 'q1_b') {
      // "Sunday" - Midnight purist, strict calendar boundaries
      inferred = inferred.copyWith(
        todayCutoffHour: 0,
        todayCutoffMinute: 0,
      );
    }

    // Question 2: Weekday Reference Logic
    // (Not directly mapped to a setting - affects DateParsingService behavior)
    // Store in a future field if needed, or document as design choice

    // Question 3: Week Start Preference
    final q3Answer = answers[3];
    if (q3Answer == 'q3_a') {
      inferred = inferred.copyWith(weekStartDay: 0); // Sunday
    } else if (q3Answer == 'q3_b') {
      inferred = inferred.copyWith(weekStartDay: 1); // Monday
    } else if (q3Answer?.startsWith('q3_c_') == true) {
      // Custom day: q3_c_0 through q3_c_6
      final day = int.parse(q3Answer!.split('_').last);
      inferred = inferred.copyWith(weekStartDay: day);
    }

    // Question 4: "Tonight" Keyword
    final q4Answer = answers[4];
    if (q4Answer == 'q4_a') {
      inferred = inferred.copyWith(tonightHour: 18); // 6-8pm
    } else if (q4Answer == 'q4_b') {
      inferred = inferred.copyWith(tonightHour: 20); // 8-10pm
    } else if (q4Answer == 'q4_c') {
      inferred = inferred.copyWith(tonightHour: 22); // 10pm+
    }

    // Question 5: "Morning" Keyword (User-Driven)
    final q5Answer = answers[5];
    if (q5Answer == 'q5_a') {
      // Early morning preference
      inferred = inferred.copyWith(
        morningHour: 7,
        earlyMorningHour: 5,
      );
    } else if (q5Answer == 'q5_b') {
      // Mid-morning (defaults)
      inferred = inferred.copyWith(
        morningHour: 9,
        earlyMorningHour: 5,
      );
    } else if (q5Answer == 'q5_c') {
      // Late morning
      inferred = inferred.copyWith(
        morningHour: 11,
        earlyMorningHour: 7,
        noonHour: 13, // Shift noon later too
      );
    }

    // Question 6: Display Time Format
    final q6Answer = answers[6];
    if (q6Answer == 'q6_a') {
      inferred = inferred.copyWith(use24HourTime: false); // 12-hour
    } else if (q6Answer == 'q6_b') {
      inferred = inferred.copyWith(use24HourTime: true); // 24-hour
    }

    // Question 7: Quick Add Date Parsing Preference
    final q7Answer = answers[7];
    if (q7Answer == 'q7_a') {
      inferred = inferred.copyWith(enableQuickAddDateParsing: true);
    } else if (q7Answer == 'q7_b') {
      inferred = inferred.copyWith(enableQuickAddDateParsing: false);
    }

    // Question 8: Task Completion Behavior
    final q8Answer = answers[8];
    if (q8Answer == 'q8_a') {
      inferred = inferred.copyWith(autoCompleteChildren: 'prompt');
    } else if (q8Answer == 'q8_b') {
      inferred = inferred.copyWith(autoCompleteChildren: 'always');
    } else if (q8Answer == 'q8_c') {
      inferred = inferred.copyWith(autoCompleteChildren: 'never');
    }

    // Question 9: Sleep Schedule (Cross-validates Q1)
    final q9Answer = answers[9];
    final q1CutoffHour = inferred.todayCutoffHour;

    if (q9Answer == 'q9_a') {
      // Before midnight - reinforce early cutoff (if not midnight purist)
      if (q1CutoffHour != 0) {
        inferred = inferred.copyWith(
          todayCutoffHour: 3,
          todayCutoffMinute: 59,
        );
      }
    } else if (q9Answer == 'q9_b') {
      // 12am-2am - standard night owl
      inferred = inferred.copyWith(
        todayCutoffHour: 4,
        todayCutoffMinute: 59,
      );
    } else if (q9Answer == 'q9_c') {
      // 2am-4am - strong night owl
      inferred = inferred.copyWith(
        todayCutoffHour: 5,
        todayCutoffMinute: 59,
      );
    } else if (q9Answer == 'q9_d') {
      // 4am+ or varies - extreme night owl
      inferred = inferred.copyWith(
        todayCutoffHour: 6,
        todayCutoffMinute: 59,
      );
    }

    return inferred;
  }

  /// Calculate earned badges from quiz answers
  List<Badge> calculateBadges(Map<int, String> answers, UserSettings settings) {
    final badges = <Badge>[];

    // Question 1: Circadian Rhythm Badges
    final q1 = answers[1];
    if (q1 == 'q1_a') {
      badges.add(BadgeDefinitions.nightOwl);
    } else if (q1 == 'q1_b') {
      badges.add(BadgeDefinitions.midnightPurist);
    }

    // Question 3: Week Structure Badges
    final q3 = answers[3];
    if (q3 == 'q3_a') {
      badges.add(BadgeDefinitions.sundayTraditionalist);
    } else if (q3 == 'q3_b') {
      badges.add(BadgeDefinitions.mondayStarter);
    } else if (q3?.startsWith('q3_c_') == true) {
      final day = int.parse(q3!.split('_').last);
      if (day != 0 && day != 1) {
        badges.add(BadgeDefinitions.calendarRebel);
      }
    }

    // Question 2: Time Perception Badges
    final q2 = answers[2];
    if (q2 == 'q2_a') {
      badges.add(BadgeDefinitions.forwardThinker);
    } else if (q2 == 'q2_b') {
      badges.add(BadgeDefinitions.calendarContextual);
    } else if (q2 == 'q2_c') {
      badges.add(BadgeDefinitions.flexibleInterpreter);
    }

    // Question 5: Daily Rhythm Badges
    final q5 = answers[5];
    final q4 = answers[4];

    if (q5 == 'q5_a' && q4 == 'q4_a') {
      badges.add(BadgeDefinitions.dawnGreeter);
    } else if (q5 == 'q5_b' && q4 == 'q4_b') {
      badges.add(BadgeDefinitions.classicScheduler);
    } else if (q5 == 'q5_c') {
      badges.add(BadgeDefinitions.lateMorningLuxurist);
    }

    // Question 6: Display Preference Badges
    final q6 = answers[6];
    if (q6 == 'q6_a') {
      badges.add(BadgeDefinitions.amPmClassicist);
    } else if (q6 == 'q6_b') {
      badges.add(BadgeDefinitions.exactingEnthusiast); // Renamed from military
    }

    // Question 8: Task Management Style Badges
    final q8 = answers[8];
    if (q8 == 'q8_a') {
      badges.add(BadgeDefinitions.thoughtfulCurator);
    } else if (q8 == 'q8_b') {
      badges.add(BadgeDefinitions.decisiveCompleter);
    } else if (q8 == 'q8_c') {
      badges.add(BadgeDefinitions.granularManager);
    }

    // Question 9: Sleep-based badges
    final q9 = answers[9];
    if (q9 == 'q9_a') {
      badges.add(BadgeDefinitions.earlyBird);
    } else if (q9 == 'q9_c' || q9 == 'q9_d') {
      badges.add(BadgeDefinitions.nocturnalScholar);
    }

    // Check for special combo badges
    final badgeIds = badges.map((b) => b.id).toSet();

    if (badgeIds.contains('midnight_purist') && badgeIds.contains('nocturnal_scholar')) {
      badges.add(BadgeDefinitions.vampireScholar);
    }

    if (badgeIds.contains('early_bird') && badgeIds.contains('dawn_greeter') && badgeIds.contains('monday_starter')) {
      badges.add(BadgeDefinitions.sunriseAchiever);
    }

    if (badgeIds.contains('calendar_rebel') && badgeIds.contains('flexible_interpreter')) {
      badges.add(BadgeDefinitions.timeAnarchist);
    }

    if (badgeIds.contains('exacting_enthusiast') && badgeIds.contains('nocturnal_scholar')) {
      badges.add(BadgeDefinitions.nightOps);
    }

    return badges;
  }

  /// Reverse-infer quiz answers from current UserSettings (for "Retake Quiz" prefill)
  Map<int, String> prefillFromSettings(UserSettings settings) {
    final answers = <int, String>{};

    // Q1: Circadian rhythm
    if (settings.todayCutoffHour == 0) {
      answers[1] = 'q1_b'; // Midnight purist
    } else {
      answers[1] = 'q1_a'; // Night owl
    }

    // Q3: Week start
    if (settings.weekStartDay == 0) {
      answers[3] = 'q3_a'; // Sunday
    } else if (settings.weekStartDay == 1) {
      answers[3] = 'q3_b'; // Monday
    } else {
      answers[3] = 'q3_c_${settings.weekStartDay}'; // Custom
    }

    // Q4: Tonight
    if (settings.tonightHour <= 18) {
      answers[4] = 'q4_a';
    } else if (settings.tonightHour <= 20) {
      answers[4] = 'q4_b';
    } else {
      answers[4] = 'q4_c';
    }

    // Q5: Morning
    if (settings.morningHour <= 7) {
      answers[5] = 'q5_a';
    } else if (settings.morningHour <= 9) {
      answers[5] = 'q5_b';
    } else {
      answers[5] = 'q5_c';
    }

    // Q6: Time format
    answers[6] = settings.use24HourTime ? 'q6_b' : 'q6_a';

    // Q7: Quick add parsing
    answers[7] = settings.enableQuickAddDateParsing ? 'q7_a' : 'q7_b';

    // Q8: Auto-complete children
    if (settings.autoCompleteChildren == 'prompt') {
      answers[8] = 'q8_a';
    } else if (settings.autoCompleteChildren == 'always') {
      answers[8] = 'q8_b';
    } else {
      answers[8] = 'q8_c';
    }

    // Q9: Sleep schedule (infer from cutoff hour)
    if (settings.todayCutoffHour <= 3) {
      answers[9] = 'q9_a';
    } else if (settings.todayCutoffHour == 4) {
      answers[9] = 'q9_b';
    } else if (settings.todayCutoffHour == 5) {
      answers[9] = 'q9_c';
    } else {
      answers[9] = 'q9_d';
    }

    return answers;
  }
}
```

---

## State Management

### QuizProvider

```dart
// lib/providers/quiz_provider.dart

import 'package:flutter/foundation.dart';
import '../models/quiz_question.dart';
import '../models/badge.dart';
import '../models/user_settings.dart';
import '../services/quiz_inference_service.dart';
import '../services/user_settings_service.dart';
import '../utils/quiz_questions.dart';

class QuizProvider extends ChangeNotifier {
  final QuizInferenceService _inferenceService = QuizInferenceService();
  final UserSettingsService _settingsService = UserSettingsService();

  // Quiz state
  int _currentQuestionIndex = 0;
  Map<int, String> _answers = {}; // Question ID → Answer ID
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Badge>? _earnedBadges;

  // Getters
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<int, String> get answers => _answers;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<Badge>? get earnedBadges => _earnedBadges;

  List<QuizQuestion> get questions => QuizQuestions.all;
  QuizQuestion get currentQuestion => questions[_currentQuestionIndex];
  bool get isLastQuestion => _currentQuestionIndex == questions.length - 1;
  bool get canGoBack => _currentQuestionIndex > 0;
  bool get canGoForward => _currentQuestionIndex < questions.length - 1;

  // Check if current question has been answered
  bool get currentQuestionAnswered => _answers.containsKey(currentQuestion.id);

  // Get answer for specific question
  String? getAnswer(int questionId) => _answers[questionId];

  /// Select an answer for the current question
  void selectAnswer(String answerId) {
    _answers[currentQuestion.id] = answerId;
    _errorMessage = null;
    notifyListeners();
  }

  /// Navigate to next question
  void nextQuestion() {
    if (canGoForward) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  /// Navigate to previous question
  void previousQuestion() {
    if (canGoBack) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Jump to specific question (for progress dots)
  void goToQuestion(int index) {
    if (index >= 0 && index < questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  /// Submit quiz and infer settings
  Future<bool> submitQuiz() async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get current settings (preserves notification prefs from Phase 3.8)
      final currentSettings = await _settingsService.getUserSettings();

      // Infer new settings from answers
      final inferredSettings = await _inferenceService.inferSettings(
        _answers,
        currentSettings,
      );

      // Calculate earned badges
      _earnedBadges = _inferenceService.calculateBadges(_answers, inferredSettings);

      // Save settings to database
      await _settingsService.updateUserSettings(inferredSettings);

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save settings: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Apply default settings (skip quiz)
  Future<bool> applyDefaults() async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get current settings
      final currentSettings = await _settingsService.getUserSettings();

      // Apply smart defaults for unset fields (most already have defaults)
      // No changes needed - defaults are already sensible

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to apply defaults: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Prefill answers from current UserSettings (for "Retake Quiz")
  Future<void> prefillFromSettings() async {
    final settings = await _settingsService.getUserSettings();
    _answers = _inferenceService.prefillFromSettings(settings);
    notifyListeners();
  }

  /// Reset quiz state
  void reset() {
    _currentQuestionIndex = 0;
    _answers = {};
    _isSubmitting = false;
    _errorMessage = null;
    _earnedBadges = null;
    notifyListeners();
  }
}
```

---

## UI Components

### QuizScreen

```dart
// lib/screens/quiz_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../services/quiz_service.dart';
import '../utils/theme.dart';
import '../utils/quiz_theme.dart';
import '../widgets/quiz_progress_dots.dart';
import '../widgets/quiz_question_card.dart';
import 'badge_reveal_screen.dart';
import 'home_screen.dart';

class QuizScreen extends StatefulWidget {
  final bool isRetake; // True if accessed from Settings → "Retake Quiz"

  const QuizScreen({super.key, this.isRetake = false});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // If retaking, prefill from current settings
    if (widget.isRetake) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<QuizProvider>().prefillFromSettings();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = QuizTheme.witchyFlatlay;

    return PopScope(
      canPop: false, // Custom back button handling
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        final shouldExit = await _showExitConfirmation();
        if (shouldExit && mounted) {
          if (widget.isRetake) {
            Navigator.of(context).pop(); // Back to Settings
          } else {
            _skipQuiz(); // Apply defaults and go to home
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.creamPaper,
        appBar: AppBar(
          title: Text(widget.isRetake ? 'Retake Quiz' : 'Welcome to Pin and Paper!'),
          backgroundColor: AppTheme.creamPaper,
          elevation: 0,
          actions: [
            if (!widget.isRetake)
              TextButton(
                onPressed: _skipQuiz,
                child: Text(
                  'Skip',
                  style: TextStyle(color: AppTheme.deepShadow),
                ),
              ),
          ],
        ),
        body: Consumer<QuizProvider>(
          builder: (context, quizProvider, _) {
            if (quizProvider.isSubmitting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing your time personality...'),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Progress dots
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: QuizProgressDots(
                    totalQuestions: quizProvider.questions.length,
                    currentQuestion: quizProvider.currentQuestionIndex,
                    answeredQuestions: quizProvider.answers.keys.toSet(),
                    onDotTapped: (index) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),

                // PageView for questions
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      quizProvider.goToQuestion(index);
                    },
                    physics: const NeverScrollableScrollPhysics(), // Control with buttons only
                    itemCount: quizProvider.questions.length,
                    itemBuilder: (context, index) {
                      final question = quizProvider.questions[index];
                      return QuizQuestionCard(
                        question: question,
                        selectedAnswer: quizProvider.getAnswer(question.id),
                        onAnswerSelected: (answerId) {
                          quizProvider.selectAnswer(answerId);
                        },
                      );
                    },
                  ),
                ),

                // Bottom navigation
                _buildBottomNavigation(quizProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(QuizProvider quizProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warmBeige,
        boxShadow: [
          BoxShadow(
            color: AppTheme.richBlack.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            if (quizProvider.canGoBack)
              OutlinedButton(
                onPressed: _goToPreviousQuestion,
                child: const Text('Back'),
              )
            else
              const SizedBox.shrink(),

            const Spacer(),

            // Next/Complete button
            if (quizProvider.isLastQuestion)
              ElevatedButton(
                onPressed: quizProvider.currentQuestionAnswered
                    ? _submitQuiz
                    : null, // Disabled if not answered
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Complete Quiz'),
              )
            else
              ElevatedButton(
                onPressed: _goToNextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepShadow,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Next'),
              ),
          ],
        ),
      ),
    );
  }

  void _goToNextQuestion() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToPreviousQuestion() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitQuiz() async {
    final quizProvider = context.read<QuizProvider>();

    final success = await quizProvider.submitQuiz();
    if (!success || !mounted) return;

    // Mark quiz as completed in SharedPreferences
    if (!widget.isRetake) {
      await QuizService().markQuizCompleted();
    }

    // Navigate to badge reveal screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BadgeRevealScreen(
          badges: quizProvider.earnedBadges!,
          isRetake: widget.isRetake,
        ),
      ),
    );
  }

  Future<void> _skipQuiz() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Quiz?'),
        content: const Text(
          'You\'ll be set to default preferences. You can always retake this quiz in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Quiz'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final quizProvider = context.read<QuizProvider>();
    await quizProvider.applyDefaults();
    await QuizService().markQuizCompleted(); // Still mark as "seen" to not show again

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false, // Remove all previous routes
      );
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    ) ?? false;
  }
}
```

### QuizQuestionCard Widget

```dart
// lib/widgets/quiz_question_card.dart

import 'package:flutter/material.dart';
import '../models/quiz_question.dart';
import '../utils/theme.dart';
import '../utils/quiz_theme.dart';
import 'quiz_answer_option.dart';

class QuizQuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerSelected;

  const QuizQuestionCard({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = QuizTheme.witchyFlatlay;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration (if provided)
          if (question.imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                question.imagePath!,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Question text
          Text(
            question.question,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepShadow,
            ),
            textAlign: TextAlign.center,
          ),

          // Description/scenario (if provided)
          if (question.description != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.questionCardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.kraftPaper,
                  width: 1,
                ),
              ),
              child: Text(
                question.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.deepShadow.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Answer options
          ...question.answers.map((answer) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: QuizAnswerOption(
                answer: answer,
                isSelected: selectedAnswer == answer.id,
                onTap: () => onAnswerSelected(answer.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}
```

### QuizAnswerOption Widget

```dart
// lib/widgets/quiz_answer_option.dart

import 'package:flutter/material.dart';
import '../models/quiz_answer.dart';
import '../utils/theme.dart';
import '../utils/quiz_theme.dart';

class QuizAnswerOption extends StatelessWidget {
  final QuizAnswer answer;
  final bool isSelected;
  final VoidCallback onTap;

  const QuizAnswerOption({
    super.key,
    required this.answer,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = QuizTheme.witchyFlatlay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.answerCardSelected
                : theme.answerCardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.deepShadow : AppTheme.kraftPaper,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.deepShadow.withValues(alpha: 0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.deepShadow : AppTheme.muted,
                    width: 2,
                  ),
                  color: isSelected ? AppTheme.deepShadow : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),

              const SizedBox(width: 16),

              // Answer text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      answer.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: AppTheme.deepShadow,
                      ),
                    ),
                    if (answer.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        answer.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.deepShadow.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### QuizProgressDots Widget

```dart
// lib/widgets/quiz_progress_dots.dart

import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/quiz_theme.dart';

class QuizProgressDots extends StatelessWidget {
  final int totalQuestions;
  final int currentQuestion;
  final Set<int> answeredQuestions; // Question IDs (1-9)
  final ValueChanged<int>? onDotTapped;

  const QuizProgressDots({
    super.key,
    required this.totalQuestions,
    required this.currentQuestion,
    required this.answeredQuestions,
    this.onDotTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = QuizTheme.witchyFlatlay;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalQuestions,
        (index) {
          final questionId = index + 1; // IDs are 1-indexed
          final isActive = index == currentQuestion;
          final isAnswered = answeredQuestions.contains(questionId);

          return GestureDetector(
            onTap: onDotTapped != null ? () => onDotTapped!(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 12 : 8,
              height: isActive ? 12 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? theme.progressDotActive
                    : isAnswered
                        ? theme.progressDotActive.withValues(alpha: 0.5)
                        : theme.progressDotInactive,
                border: Border.all(
                  color: isActive ? theme.progressDotActive : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

---

## Badge System

### Badge Definitions

```dart
// lib/utils/badge_definitions.dart

import '../models/badge.dart';

class BadgeDefinitions {
  // Circadian Rhythm Badges
  static const nightOwl = Badge(
    id: 'night_owl',
    emoji: '🦉',
    title: 'Night Owl',
    description: 'Your Friday extends past midnight. You embrace the late night hours.',
    imagePath: 'assets/images/badges/1x/night_owl.png',
    category: BadgeCategory.circadianRhythm,
  );

  static const midnightPurist = Badge(
    id: 'midnight_purist',
    emoji: '🌙',
    title: 'Midnight Purist',
    description: 'Friday is over at midnight. You follow strict calendar boundaries.',
    imagePath: 'assets/images/badges/1x/midnight_purist.png',
    category: BadgeCategory.circadianRhythm,
  );

  static const earlyBird = Badge(
    id: 'early_bird',
    emoji: '🌅',
    title: 'Early Bird',
    description: 'You embrace the morning hours and sleep before midnight.',
    imagePath: 'assets/images/badges/1x/early_bird.png',
    category: BadgeCategory.circadianRhythm,
  );

  static const nocturnalScholar = Badge(
    id: 'nocturnal_scholar',
    emoji: '🌌',
    title: 'Nocturnal Scholar',
    description: 'Awake past 2am regularly. The night is your canvas.',
    imagePath: 'assets/images/badges/1x/nocturnal_scholar.png',
    category: BadgeCategory.circadianRhythm,
  );

  // Week Structure Badges
  static const mondayStarter = Badge(
    id: 'monday_starter',
    emoji: '📅',
    title: 'Monday Starter',
    description: 'Your week begins on Monday. International calendar style.',
    imagePath: 'assets/images/badges/1x/monday_starter.png',
    category: BadgeCategory.weekStructure,
  );

  static const sundayTraditionalist = Badge(
    id: 'sunday_traditionalist',
    emoji: '🇺🇸',
    title: 'Sunday Traditionalist',
    description: 'Your week starts on Sunday. Classic American calendar.',
    imagePath: 'assets/images/badges/1x/sunday_traditionalist.png',
    category: BadgeCategory.weekStructure,
  );

  static const calendarRebel = Badge(
    id: 'calendar_rebel',
    emoji: '🌍',
    title: 'Calendar Rebel',
    description: 'You start your week on an unconventional day. Break the mold!',
    imagePath: 'assets/images/badges/1x/calendar_rebel.png',
    category: BadgeCategory.weekStructure,
  );

  // Time Perception Badges
  static const forwardThinker = Badge(
    id: 'forward_thinker',
    emoji: '⏰',
    title: 'Forward Thinker',
    description: '"This Friday" always means the next occurrence for you.',
    imagePath: 'assets/images/badges/1x/forward_thinker.png',
    category: BadgeCategory.timePerception,
  );

  static const calendarContextual = Badge(
    id: 'calendar_contextual',
    emoji: '📆',
    title: 'Calendar Contextual',
    description: 'Week boundaries matter in how you reference days.',
    imagePath: 'assets/images/badges/1x/calendar_contextual.png',
    category: BadgeCategory.timePerception,
  );

  static const flexibleInterpreter = Badge(
    id: 'flexible_interpreter',
    emoji: '🤷',
    title: 'Flexible Interpreter',
    description: 'Context-dependent time understanding. You see the nuance.',
    imagePath: 'assets/images/badges/1x/flexible_interpreter.png',
    category: BadgeCategory.timePerception,
  );

  // Daily Rhythm Badges
  static const dawnGreeter = Badge(
    id: 'dawn_greeter',
    emoji: '☀️',
    title: 'Dawn Greeter',
    description: 'Early morning is your power hour. You greet the sun.',
    imagePath: 'assets/images/badges/1x/dawn_greeter.png',
    category: BadgeCategory.dailyRhythm,
  );

  static const classicScheduler = Badge(
    id: 'classic_scheduler',
    emoji: '🕐',
    title: 'Classic Scheduler',
    description: 'Standard 9-5 aligned rhythm. You keep traditional hours.',
    imagePath: 'assets/images/badges/1x/classic_scheduler.png',
    category: BadgeCategory.dailyRhythm,
  );

  static const lateMorningLuxurist = Badge(
    id: 'late_morning_luxurist',
    emoji: '🌙',
    title: 'Late Morning Luxurist',
    description: 'Slow morning starts. You savor the late morning hours.',
    imagePath: 'assets/images/badges/1x/late_morning_luxurist.png',
    category: BadgeCategory.dailyRhythm,
  );

  // Display Preference Badges
  static const exactingEnthusiast = Badge(
    id: 'exacting_enthusiast',
    emoji: '🎖️',
    title: 'Exacting Enthusiast',
    description: '24-hour clock preference. Precision in timekeeping.',
    imagePath: 'assets/images/badges/1x/exacting_enthusiast.png',
    category: BadgeCategory.displayPreference,
  );

  static const amPmClassicist = Badge(
    id: 'am_pm_classicist',
    emoji: '🕰️',
    title: 'AM/PM Classicist',
    description: '12-hour clock with AM/PM. Traditional time display.',
    imagePath: 'assets/images/badges/1x/am_pm_classicist.png',
    category: BadgeCategory.displayPreference,
  );

  // Task Management Style Badges
  static const decisiveCompleter = Badge(
    id: 'decisive_completer',
    emoji: '🎯',
    title: 'Decisive Completer',
    description: 'Always auto-complete children. Parent done = all done.',
    imagePath: 'assets/images/badges/1x/decisive_completer.png',
    category: BadgeCategory.taskStyle,
  );

  static const thoughtfulCurator = Badge(
    id: 'thoughtful_curator',
    emoji: '🤔',
    title: 'Thoughtful Curator',
    description: 'Prompts for subtask completion. You decide case-by-case.',
    imagePath: 'assets/images/badges/1x/thoughtful_curator.png',
    category: BadgeCategory.taskStyle,
  );

  static const granularManager = Badge(
    id: 'granular_manager',
    emoji: '🗂️',
    title: 'Granular Manager',
    description: 'Never auto-complete. Each task gets individual attention.',
    imagePath: 'assets/images/badges/1x/granular_manager.png',
    category: BadgeCategory.taskStyle,
  );

  // Special Combo Badges (Rare)
  static const vampireScholar = Badge(
    id: 'vampire_scholar',
    emoji: '🧛',
    title: 'Vampire Scholar',
    description: 'Midnight Purist + Nocturnal Scholar. Strict boundaries, awake all night.',
    imagePath: 'assets/images/badges/1x/vampire_scholar.png',
    category: BadgeCategory.combo,
    isRare: true,
  );

  static const sunriseAchiever = Badge(
    id: 'sunrise_achiever',
    emoji: '🌄',
    title: 'Sunrise Achiever',
    description: 'Early Bird + Dawn Greeter + Monday Starter. The ultimate morning person.',
    imagePath: 'assets/images/badges/1x/sunrise_achiever.png',
    category: BadgeCategory.combo,
    isRare: true,
  );

  static const timeAnarchist = Badge(
    id: 'time_anarchist',
    emoji: '🎭',
    title: 'Time Anarchist',
    description: 'Calendar Rebel + Flexible Interpreter. Non-traditional everything.',
    imagePath: 'assets/images/badges/1x/time_anarchist.png',
    category: BadgeCategory.combo,
    isRare: true,
  );

  static const nightOps = Badge(
    id: 'night_ops',
    emoji: '🌃',
    title: 'Night Ops',
    description: 'Exacting Enthusiast + Nocturnal Scholar. Late night precision.',
    imagePath: 'assets/images/badges/1x/night_ops.png',
    category: BadgeCategory.combo,
    isRare: true,
  );

  // Utility: Get all badges
  static List<Badge> get all => [
    nightOwl,
    midnightPurist,
    earlyBird,
    nocturnalScholar,
    mondayStarter,
    sundayTraditionalist,
    calendarRebel,
    forwardThinker,
    calendarContextual,
    flexibleInterpreter,
    dawnGreeter,
    classicScheduler,
    lateMorningLuxurist,
    exactingEnthusiast,
    amPmClassicist,
    decisiveCompleter,
    thoughtfulCurator,
    granularManager,
    vampireScholar,
    sunriseAchiever,
    timeAnarchist,
    nightOps,
  ];

  // Utility: Get badge by ID
  static Badge? getById(String id) {
    try {
      return all.firstWhere((badge) => badge.id == id);
    } catch (_) {
      return null;
    }
  }
}
```

### BadgeCard Widget

```dart
// lib/widgets/badge_card.dart

import 'package:flutter/material.dart';
import '../models/badge.dart';
import '../utils/theme.dart';
import '../utils/quiz_theme.dart';

class BadgeCard extends StatelessWidget {
  final Badge badge;
  final bool showDescription;
  final VoidCallback? onTap;

  const BadgeCard({
    super.key,
    required this.badge,
    this.showDescription = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = QuizTheme.witchyFlatlay;
    final density = MediaQuery.of(context).devicePixelRatio.ceil();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.badgeBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.badgeBorder,
              width: 2,
            ),
            boxShadow: badge.isRare
                ? [
                    BoxShadow(
                      color: AppTheme.mutedLavender.withValues(alpha: 0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge image
              Image.asset(
                badge.getImagePath(density),
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 12),

              // Title with emoji
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    badge.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      badge.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepShadow,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              // Description
              if (showDescription) ...[
                const SizedBox(height: 8),
                Text(
                  badge.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.deepShadow.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Rare badge indicator
              if (badge.isRare) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.mutedLavender.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.mutedLavender,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '✨ Rare Combination',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.mutedLavender,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Animation Implementation

### BadgeRevealScreen

```dart
// lib/screens/badge_reveal_screen.dart

import 'package:flutter/material.dart';
import '../models/badge.dart';
import '../utils/theme.dart';
import '../utils/quiz_theme.dart';
import '../widgets/badge_card.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class BadgeRevealScreen extends StatefulWidget {
  final List<Badge> badges;
  final bool isRetake;

  const BadgeRevealScreen({
    super.key,
    required this.badges,
    this.isRetake = false,
  });

  @override
  State<BadgeRevealScreen> createState() => _BadgeRevealScreenState();
}

class _BadgeRevealScreenState extends State<BadgeRevealScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _fadeAnimations;
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startRevealSequence();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.badges.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeIn),
      );
    }).toList();
  }

  Future<void> _startRevealSequence() async {
    // Wait 500ms before starting (build suspense)
    await Future.delayed(const Duration(milliseconds: 500));

    // Stagger badge reveals by 200ms each
    for (int i = 0; i < _controllers.length; i++) {
      if (!mounted) return;
      _controllers[i].forward();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Wait for last animation to complete
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() => _animationComplete = true);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = QuizTheme.witchyFlatlay;

    return Scaffold(
      backgroundColor: AppTheme.creamPaper,
      body: SafeArea(
        child: Stack(
          children: [
            // Sash background
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/images/onboarding/sash_background.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Badge reveal content
            Column(
              children: [
                const SizedBox(height: 40),

                // Title
                Text(
                  widget.isRetake ? 'Your Updated Badges!' : 'You\'ve Earned:',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepShadow,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Badges grid with animations
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: widget.badges.length,
                    itemBuilder: (context, index) {
                      return FadeTransition(
                        opacity: _fadeAnimations[index],
                        child: ScaleTransition(
                          scale: _scaleAnimations[index],
                          child: BadgeCard(
                            badge: widget.badges[index],
                            showDescription: false, // Compact for grid
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom action buttons
                if (_animationComplete)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: _continueTo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: Text(
                            widget.isRetake ? 'Back to Settings' : 'Start Using Pin and Paper!',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextButton(
                          onPressed: _showBadgeDetails,
                          child: const Text('View Badge Descriptions'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _continueTo() {
    if (widget.isRetake) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _showBadgeDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.creamPaper,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.muted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your Badge Collection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepShadow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.badges.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: BadgeCard(
                            badge: widget.badges[index],
                            showDescription: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
```

---

## Integration Points

### 1. main.dart - First Launch Detection

```dart
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/quiz_service.dart';
import 'screens/quiz_screen.dart';
import 'screens/home_screen.dart';
// ... other imports

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing initialization ...

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ... existing providers ...
        ChangeNotifierProvider(create: (_) => QuizProvider()), // NEW
      ],
      child: MaterialApp(
        title: 'Pin and Paper',
        theme: AppTheme.lightTheme,
        home: FutureBuilder<bool>(
          future: QuizService().hasCompletedOnboardingQuiz(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Show quiz on first launch, HomeScreen otherwise
            final hasCompletedQuiz = snapshot.data ?? false;
            return hasCompletedQuiz
                ? const HomeScreen()
                : const QuizScreen();
          },
        ),
      ),
    );
  }
}
```

### 2. SettingsScreen - "Retake Quiz" Button

```dart
// lib/screens/settings_screen.dart

// Add new section: "Your Time Personality"
ListTile(
  title: const Text('Your Time Personality'),
  subtitle: const Text('View or retake the onboarding quiz'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    final shouldRetake = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retake Quiz?'),
        content: const Text(
          'This will update your current settings based on your new answers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retake'),
          ),
        ],
      ),
    );

    if (shouldRetake == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const QuizScreen(isRetake: true),
        ),
      );
    }
  },
),
```

---

## Testing Strategy

### Unit Tests

```dart
// test/services/quiz_inference_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/services/quiz_inference_service.dart';
import 'package:pin_and_paper/models/user_settings.dart';

void main() {
  group('QuizInferenceService', () {
    late QuizInferenceService service;
    late UserSettings baseSettings;

    setUp(() {
      service = QuizInferenceService();
      baseSettings = UserSettings.defaults();
    });

    test('Q1-A (Night Owl) sets todayCutoff to 4:59 AM', () async {
      final answers = {1: 'q1_a'};
      final result = await service.inferSettings(answers, baseSettings);

      expect(result.todayCutoffHour, 4);
      expect(result.todayCutoffMinute, 59);
    });

    test('Q1-B (Midnight Purist) sets todayCutoff to 0:00', () async {
      final answers = {1: 'q1_b'};
      final result = await service.inferSettings(answers, baseSettings);

      expect(result.todayCutoffHour, 0);
      expect(result.todayCutoffMinute, 0);
    });

    test('Q3-A sets week start to Sunday', () async {
      final answers = {3: 'q3_a'};
      final result = await service.inferSettings(answers, baseSettings);

      expect(result.weekStartDay, 0);
    });

    test('Q6-B sets 24-hour time', () async {
      final answers = {6: 'q6_b'};
      final result = await service.inferSettings(answers, baseSettings);

      expect(result.use24HourTime, true);
    });

    test('calculateBadges awards Night Owl for Q1-A', () {
      final answers = {1: 'q1_a'};
      final settings = baseSettings.copyWith(todayCutoffHour: 4);

      final badges = service.calculateBadges(answers, settings);

      expect(badges.any((b) => b.id == 'night_owl'), true);
    });

    test('calculateBadges awards Vampire Scholar combo', () {
      final answers = {
        1: 'q1_b', // Midnight Purist
        9: 'q9_c', // Nocturnal Scholar
      };
      final settings = baseSettings.copyWith(todayCutoffHour: 0);

      final badges = service.calculateBadges(answers, settings);

      expect(badges.any((b) => b.id == 'midnight_purist'), true);
      expect(badges.any((b) => b.id == 'nocturnal_scholar'), true);
      expect(badges.any((b) => b.id == 'vampire_scholar'), true);
    });

    test('prefillFromSettings reverse-infers correctly', () {
      final settings = baseSettings.copyWith(
        todayCutoffHour: 0,
        weekStartDay: 1,
        use24HourTime: true,
      );

      final answers = service.prefillFromSettings(settings);

      expect(answers[1], 'q1_b'); // Midnight purist
      expect(answers[3], 'q3_b'); // Monday start
      expect(answers[6], 'q6_b'); // 24-hour
    });
  });
}
```

### Widget Tests

```dart
// test/widgets/quiz_progress_dots_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/widgets/quiz_progress_dots.dart';

void main() {
  testWidgets('QuizProgressDots renders correct number of dots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizProgressDots(
            totalQuestions: 9,
            currentQuestion: 0,
            answeredQuestions: {1},
          ),
        ),
      ),
    );

    // Should render 9 dots
    expect(find.byType(AnimatedContainer), findsNWidgets(9));
  });

  testWidgets('QuizProgressDots calls onDotTapped', (tester) async {
    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizProgressDots(
            totalQuestions: 9,
            currentQuestion: 0,
            answeredQuestions: {},
            onDotTapped: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    // Tap the 3rd dot
    await tester.tap(find.byType(GestureDetector).at(2));
    await tester.pump();

    expect(tappedIndex, 2);
  });
}
```

### Integration Tests

```dart
// integration_test/quiz_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pin_and_paper/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete quiz flow end-to-end', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Should show QuizScreen on first launch
    expect(find.text('Welcome to Pin and Paper!'), findsOneWidget);

    // Answer all 9 questions
    for (int i = 0; i < 9; i++) {
      // Tap first answer option
      await tester.tap(find.byType(QuizAnswerOption).first);
      await tester.pumpAndSettle();

      // Tap Next (or Complete on last question)
      final buttonText = i == 8 ? 'Complete Quiz' : 'Next';
      await tester.tap(find.text(buttonText));
      await tester.pumpAndSettle();
    }

    // Should show BadgeRevealScreen
    expect(find.text('You\'ve Earned:'), findsOneWidget);

    // Wait for animations
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Tap "Start Using Pin and Paper!"
    await tester.tap(find.text('Start Using Pin and Paper!'));
    await tester.pumpAndSettle();

    // Should navigate to HomeScreen
    expect(find.text('Pin and Paper'), findsOneWidget);
  });

  testWidgets('Skip quiz applies defaults', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Tap Skip
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Confirm in dialog
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Should navigate to HomeScreen
    expect(find.text('Pin and Paper'), findsOneWidget);
  });
}
```

---

## Implementation Sequence

### Phase 3.9.1: Quiz Framework (Days 1-2)

**Day 1:**
1. ✅ Create data models (QuizQuestion, QuizAnswer, Badge)
2. ✅ Create QuizProvider with state management
3. ✅ Create QuizService for first-launch detection
4. ✅ Add database migration for `enable_quick_add_date_parsing` field
5. ✅ Update UserSettings model with new field
6. ✅ Create quiz questions data (QuizQuestions.all)

**Day 2:**
1. ✅ Create QuizScreen with PageView
2. ✅ Create QuizProgressDots widget
3. ✅ Create QuizQuestionCard widget
4. ✅ Create QuizAnswerOption widget
5. ✅ Integrate first-launch detection in main.dart
6. ✅ Test quiz navigation flow

### Phase 3.9.2: Questions, Inference, Badges (Days 3-5)

**Day 3:**
1. ✅ Create QuizInferenceService with answer → settings mapping
2. ✅ Implement all 9 question mappings
3. ✅ Write unit tests for inference logic
4. ✅ Test edge cases (conflicting answers, missing answers)

**Day 4:**
1. ✅ Create BadgeDefinitions with all 23+ badges
2. ✅ Implement badge calculation logic in QuizInferenceService
3. ✅ Create BadgeCard widget
4. ✅ Test badge awarding (individual + combos)

**Day 5:**
1. ✅ Create BadgeRevealScreen with sash background
2. ✅ Implement staggered fade+scale animations
3. ✅ Add badge details modal bottom sheet
4. ✅ Test animation timing and transitions

### Phase 3.9.3: Settings UI Expansion (Days 6-7)

**Day 6:**
1. ✅ Create TimeKeywordPicker widget
2. ✅ Create WeekStartDayPicker widget
3. ✅ Create TimezonePicker widget
4. ✅ Add "Time & Schedule" section to SettingsScreen

**Day 7:**
1. ✅ Add "Date Parsing" section with keyword pickers
2. ✅ Add "Task Behavior" section
3. ✅ Add "Your Time Personality" section with badges display
4. ✅ Wire up all settings to UserSettings model

### Phase 3.9.4: Explain/Retake Features (Day 8)

1. ✅ Create SettingsExplanationDialog widget
2. ✅ Implement "Explain My Settings" button logic
3. ✅ Implement "Retake Quiz" flow with prefill
4. ✅ Add confirmation dialogs for destructive actions

### Testing & Polish (Days 9-10)

**Day 9:**
1. ✅ Write comprehensive unit tests
2. ✅ Write widget tests for all new components
3. ✅ Write integration tests for quiz flow
4. ✅ Manual testing on Android + Linux

**Day 10:**
1. ✅ Visual polish (spacing, colors, typography)
2. ✅ Accessibility improvements (screen readers, focus)
3. ✅ Performance testing (animation smoothness)
4. ✅ Documentation and code comments
5. ✅ Final commit and merge to main

---

## Edge Cases & Error Handling

### 1. Partial Quiz Completion
**Scenario:** User closes app mid-quiz
**Handling:** Quiz state is NOT persisted. On next app open, quiz starts fresh from Q1.
**Rationale:** Short quiz (9 questions), not worth complex state persistence.

### 2. Network Issues During Quiz
**Scenario:** No network during quiz submission
**Handling:** N/A - Quiz is 100% offline. No network calls involved.

### 3. Settings Write Failure
**Scenario:** Database error when saving UserSettings
**Handling:**
- Show error snackbar: "Failed to save settings. Please try again."
- Keep user on quiz screen with retry button
- Log error for debugging

```dart
try {
  await userSettingsService.updateUserSettings(settings);
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Failed to save settings. Please try again.'),
        backgroundColor: AppTheme.danger,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => submitQuiz(),
        ),
      ),
    );
  }
}
```

### 4. Missing Badge Assets
**Scenario:** Badge PNG file not found
**Handling:**
- Use `errorBuilder` in Image.asset to show placeholder
- Log warning for missing asset
- Continue with other badges

```dart
Image.asset(
  badge.getImagePath(density),
  width: 120,
  height: 120,
  fit: BoxFit.contain,
  errorBuilder: (context, error, stackTrace) {
    return Container(
      width: 120,
      height: 120,
      color: AppTheme.kraftPaper,
      child: Icon(
        Icons.emoji_events,
        size: 60,
        color: AppTheme.deepShadow.withValues(alpha: 0.3),
      ),
    );
  },
)
```

### 5. Retake Quiz with Invalid Current Settings
**Scenario:** UserSettings in DB have impossible values (e.g., cutoffHour = 25)
**Handling:**
- QuizInferenceService.prefillFromSettings() has fallback logic
- Invalid values map to closest valid answer
- Logs warning for debugging

### 6. System Back Button During Quiz
**Scenario:** User presses Android back button
**Handling:**
- PopScope intercepts navigation
- Show "Exit Quiz?" confirmation dialog
- If confirmed, apply defaults and navigate to home

### 7. Animation Controller Disposal
**Scenario:** User navigates away during badge reveal animation
**Handling:**
- Always check `mounted` before setState()
- Dispose all AnimationControllers in dispose()
- Cancel pending Future.delayed with mounted checks

### 8. Empty Badge List
**Scenario:** No badges earned (shouldn't happen, but defensively code for it)
**Handling:**
- Skip badge reveal screen entirely
- Navigate directly to home/settings
- Log warning (indicates inference logic bug)

---

## Performance Considerations

### 1. Asset Loading
- **Lazy load** quiz illustrations (only load when question visible)
- **Preload** badge assets during quiz submission (while "Analyzing..." shows)
- Use `precacheImage()` for smoother badge reveal

```dart
Future<void> _preloadBadgeAssets(List<Badge> badges) async {
  for (final badge in badges) {
    await precacheImage(
      AssetImage(badge.getImagePath(2)),
      context,
    );
  }
}
```

### 2. Animation Performance
- Use `RepaintBoundary` around each badge during reveal
- Limit to 2-3 concurrent animations (stagger prevents all running simultaneously)
- Dispose AnimationControllers immediately after use

### 3. Database Operations
- UserSettings read/write are already fast (single-row table)
- No additional indexes needed
- SharedPreferences is instant (in-memory cache)

### 4. Provider Rebuilds
- QuizProvider only notifies on state changes (answer selection, navigation)
- Use `Consumer` widgets instead of `context.watch()` for scoped rebuilds
- Badge calculation happens once (on submit), not on every rebuild

---

## Accessibility

### 1. Screen Reader Support
- All images have semantic labels:
  ```dart
  Semantics(
    label: 'Clock showing 2:30 AM',
    child: Image.asset('assets/images/quiz/clock_230am.png'),
  )
  ```
- Progress dots announce current question:
  ```dart
  Semantics(
    label: 'Question ${index + 1} of $totalQuestions',
    child: Container(...),
  )
  ```

### 2. Keyboard Navigation
- PageView navigation via arrow keys (built-in)
- Focus management for answer cards:
  ```dart
  Focus(
    autofocus: index == 0,
    onKey: (node, event) { /* handle enter key */ },
    child: QuizAnswerOption(...),
  )
  ```

### 3. Color Contrast
- All text meets WCAG AA standards (4.5:1 ratio minimum)
- Selected answer cards use 2px border + color change (not just color)
- Progress dots use size change + color (not just color)

### 4. Text Scaling
- All text respects user's system font size settings
- No hardcoded `fontSize` without scale factor
- Test with `textScaleFactor: 2.0` in widget tests

---

## File Checklist

### New Files (27 total)

**Models:**
- ✅ `lib/models/quiz_question.dart`
- ✅ `lib/models/quiz_answer.dart`
- ✅ `lib/models/badge.dart`

**Providers:**
- ✅ `lib/providers/quiz_provider.dart`

**Services:**
- ✅ `lib/services/quiz_service.dart`
- ✅ `lib/services/quiz_inference_service.dart`

**Screens:**
- ✅ `lib/screens/quiz_screen.dart`
- ✅ `lib/screens/badge_reveal_screen.dart`

**Widgets:**
- ✅ `lib/widgets/quiz_question_card.dart`
- ✅ `lib/widgets/quiz_answer_option.dart`
- ✅ `lib/widgets/quiz_progress_dots.dart`
- ✅ `lib/widgets/badge_card.dart`
- ✅ `lib/widgets/settings_explanation_dialog.dart`
- ✅ `lib/widgets/time_keyword_picker.dart`
- ✅ `lib/widgets/week_start_day_picker.dart`
- ✅ `lib/widgets/timezone_picker.dart`

**Utils:**
- ✅ `lib/utils/badge_definitions.dart`
- ✅ `lib/utils/quiz_questions.dart`

**Tests:**
- ✅ `test/services/quiz_inference_service_test.dart`
- ✅ `test/services/quiz_service_test.dart`
- ✅ `test/providers/quiz_provider_test.dart`
- ✅ `test/widgets/quiz_progress_dots_test.dart`
- ✅ `test/widgets/quiz_question_card_test.dart`
- ✅ `test/widgets/badge_card_test.dart`
- ✅ `integration_test/quiz_flow_test.dart`

**Documentation:**
- ✅ `docs/phase-3.9/phase-3.9-implementation-plan.md` (this file)

### Modified Files (4 total)

**Core:**
- ✅ `lib/main.dart` (add first-launch detection)
- ✅ `lib/screens/settings_screen.dart` (add quiz/preference sections)

**Models:**
- ✅ `lib/models/user_settings.dart` (add `enableQuickAddDateParsing` field)

**Services:**
- ✅ `lib/services/database_service.dart` (add migration for new field)

---

## Next Steps After Implementation

### Phase 3.9.5 (Future Polish):
1. **Analytics:** Track quiz completion rate, skipped questions
2. **A/B Testing:** Test question phrasings, see what resonates
3. **Shift Worker Detection:** Add screener question for non-traditional schedules
4. **Badge Sharing:** Export badge collection as image for social media
5. **Gamification:** Additional badges for app usage milestones
6. **Cultural Presets:** "I live in [region]" → infer likely preferences
7. **Machine Learning:** Learn actual behavior over time, suggest adjustments

---

**Status:** ✅ Ready for Implementation
**Last Updated:** 2026-01-23
**Created By:** Claude (with research from Explore agents a05055d, a8b8821, ab8deb7)
