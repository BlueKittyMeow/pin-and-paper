import '../models/badge.dart';
import '../models/user_settings.dart';
import '../utils/badge_definitions.dart';

/// Maps quiz answers to UserSettings fields and calculates earned badges.
///
/// Question mapping (after Q2 "Weekday Reference Logic" removal):
///   Q1: Circadian Rhythm → todayCutoffHour/Minute
///   Q2: Week Start → weekStartDay
///   Q3: "Tonight" → tonightHour (supports custom time)
///   Q4: "Morning" → morningHour, earlyMorningHour (supports custom time)
///   Q5: Time Format → use24HourTime
///   Q6: Quick Add → enableQuickAddDateParsing
///   Q7: Auto-Complete → autoCompleteChildren
///   Q8: Sleep Schedule → refines todayCutoffHour from Q1
class QuizInferenceService {
  /// Infer UserSettings from quiz answers.
  ///
  /// Takes the user's current settings as a base and returns a new
  /// UserSettings with quiz-inferred values applied.
  UserSettings inferSettings(
    Map<int, String> answers,
    UserSettings currentSettings,
  ) {
    var inferred = currentSettings;

    // Q1: Circadian Rhythm → todayCutoffHour/Minute
    final q1 = answers[1];
    if (q1 == 'q1_a') {
      // Night owl: day extends past midnight
      inferred = inferred.copyWith(todayCutoffHour: 4, todayCutoffMinute: 59);
    } else if (q1 == 'q1_b') {
      // Midnight purist: strict calendar boundaries
      inferred = inferred.copyWith(todayCutoffHour: 0, todayCutoffMinute: 0);
    }

    // Q2: Week Start → weekStartDay
    final q2 = answers[2];
    if (q2 == 'q2_a') {
      inferred = inferred.copyWith(weekStartDay: 0); // Sunday
    } else if (q2 == 'q2_b') {
      inferred = inferred.copyWith(weekStartDay: 1); // Monday
    } else if (q2 != null && q2.startsWith('q2_c_')) {
      final day = int.tryParse(q2.split('_').last);
      if (day != null) {
        inferred = inferred.copyWith(weekStartDay: day.clamp(0, 6));
      }
    }

    // Q3: "Tonight" → tonightHour
    final q3 = answers[3];
    if (q3 == 'q3_a') {
      inferred = inferred.copyWith(tonightHour: 18);
    } else if (q3 == 'q3_b') {
      inferred = inferred.copyWith(tonightHour: 20);
    } else if (q3 == 'q3_c') {
      inferred = inferred.copyWith(tonightHour: 22);
    } else if (q3 != null && q3.startsWith('q3_custom_')) {
      final hour = int.tryParse(q3.split('_').last);
      if (hour != null) {
        inferred = inferred.copyWith(tonightHour: hour.clamp(0, 23));
      }
    }

    // Q4: "Morning" → morningHour, earlyMorningHour
    final q4 = answers[4];
    if (q4 == 'q4_a') {
      inferred = inferred.copyWith(morningHour: 7, earlyMorningHour: 5);
    } else if (q4 == 'q4_b') {
      inferred = inferred.copyWith(morningHour: 9, earlyMorningHour: 5);
    } else if (q4 == 'q4_c') {
      inferred = inferred.copyWith(
        morningHour: 11,
        earlyMorningHour: 7,
        noonHour: 13,
      );
    } else if (q4 != null && q4.startsWith('q4_custom_')) {
      final hour = int.tryParse(q4.split('_').last);
      if (hour != null) {
        final clampedHour = hour.clamp(0, 23);
        final earlyMorningHour = clampedHour <= 8
            ? (clampedHour - 2).clamp(0, 23)
            : (clampedHour >= 11 ? clampedHour - 4 : 5);
        inferred = inferred.copyWith(
          morningHour: clampedHour,
          earlyMorningHour: earlyMorningHour,
        );
      }
    }

    // Q5: Time Format → use24HourTime
    final q5 = answers[5];
    if (q5 == 'q5_a') {
      inferred = inferred.copyWith(use24HourTime: false);
    } else if (q5 == 'q5_b') {
      inferred = inferred.copyWith(use24HourTime: true);
    }

    // Q6: Quick Add Date Parsing → enableQuickAddDateParsing
    final q6 = answers[6];
    if (q6 == 'q6_a') {
      inferred = inferred.copyWith(enableQuickAddDateParsing: true);
    } else if (q6 == 'q6_b') {
      inferred = inferred.copyWith(enableQuickAddDateParsing: false);
    }

    // Q7: Auto-Complete Children → autoCompleteChildren
    final q7 = answers[7];
    if (q7 == 'q7_a') {
      inferred = inferred.copyWith(autoCompleteChildren: 'prompt');
    } else if (q7 == 'q7_b') {
      inferred = inferred.copyWith(autoCompleteChildren: 'always');
    } else if (q7 == 'q7_c') {
      inferred = inferred.copyWith(autoCompleteChildren: 'never');
    }

    // Q8: Sleep Schedule → refines todayCutoffHour from Q1
    // Q1 sets the general approach; Q8 fine-tunes the cutoff hour.
    // If Q1 = "Night Owl" (q1_a), adjust cutoff based on actual sleep time.
    // If Q1 = "Midnight Purist" (q1_b), Q8 doesn't override (Q1 is explicit).
    final q8 = answers[8];
    if (q1 == 'q1_a') {
      // Night owl mode: refine cutoff based on sleep schedule
      if (q8 == 'q8_a') {
        // Sleeps before midnight: moderate night owl
        inferred = inferred.copyWith(todayCutoffHour: 3, todayCutoffMinute: 59);
      } else if (q8 == 'q8_b') {
        // Sleeps 12-2am: standard night owl
        inferred = inferred.copyWith(todayCutoffHour: 4, todayCutoffMinute: 59);
      } else if (q8 == 'q8_c') {
        // Sleeps 2-4am: strong night owl
        inferred = inferred.copyWith(todayCutoffHour: 5, todayCutoffMinute: 59);
      } else if (q8 != null && q8.startsWith('q8_custom_')) {
        // Custom bedtime: set cutoff to bedtime + 2 hours (clamped)
        final hour = int.tryParse(q8.split('_').last);
        if (hour != null) {
          // Bedtime hour → cutoff hour (add 2, wrap around midnight)
          final cutoff = (hour + 2) % 24;
          inferred = inferred.copyWith(todayCutoffHour: cutoff, todayCutoffMinute: 59);
        }
      }
      // q8_e (no consistent schedule): keep Q1 default cutoff
    }

    return inferred;
  }

  /// Calculate earned badges from quiz answers.
  ///
  /// Badges are determined by answers (not settings values), so they
  /// remain static even if the user manually changes settings later.
  List<Badge> calculateBadges(Map<int, String> answers) {
    final badges = <Badge>[];

    // Q1: Circadian Rhythm badges
    final q1 = answers[1];
    if (q1 == 'q1_a') {
      badges.add(BadgeDefinitions.night_owl);
    } else if (q1 == 'q1_b') {
      badges.add(BadgeDefinitions.midnight_purist);
    }

    // Q2: Week Structure badges
    final q2 = answers[2];
    if (q2 == 'q2_a') {
      badges.add(BadgeDefinitions.sunday_traditionalist);
    } else if (q2 == 'q2_b') {
      badges.add(BadgeDefinitions.monday_starter);
    } else if (q2 != null && q2.startsWith('q2_c_')) {
      badges.add(BadgeDefinitions.calendar_rebel);
    }

    // Q3: "Tonight" contributes to daily rhythm (twilight_worker for late night)
    final q3 = answers[3];
    if (q3 == 'q3_c') {
      badges.add(BadgeDefinitions.twilight_worker);
    } else if (q3 != null && q3.startsWith('q3_custom_')) {
      final hour = int.tryParse(q3.split('_').last);
      if (hour != null && hour >= 23) {
        badges.add(BadgeDefinitions.twilight_worker);
      }
    }

    // Q4: "Morning" badges
    final q4 = answers[4];
    if (q4 == 'q4_a') {
      badges.add(BadgeDefinitions.dawn_greeter);
    } else if (q4 == 'q4_b') {
      badges.add(BadgeDefinitions.classic_scheduler);
    } else if (q4 == 'q4_c') {
      badges.add(BadgeDefinitions.late_morning_luxurist);
    } else if (q4 != null && q4.startsWith('q4_custom_')) {
      final hour = int.tryParse(q4.split('_').last);
      if (hour != null) {
        if (hour <= 8) {
          badges.add(BadgeDefinitions.dawn_greeter);
        } else if (hour >= 11) {
          badges.add(BadgeDefinitions.late_morning_luxurist);
        } else {
          badges.add(BadgeDefinitions.classic_scheduler);
        }
      }
    }

    // Q5: Time Format badges
    final q5 = answers[5];
    if (q5 == 'q5_a') {
      badges.add(BadgeDefinitions.am_pm_classicist);
    } else if (q5 == 'q5_b') {
      badges.add(BadgeDefinitions.exacting_enthusiast);
    }

    // Q6: Quick Add — no badge

    // Q7: Task Management badges
    final q7 = answers[7];
    if (q7 == 'q7_a') {
      badges.add(BadgeDefinitions.thoughtful_curator);
    } else if (q7 == 'q7_b') {
      badges.add(BadgeDefinitions.decisive_completer);
    } else if (q7 == 'q7_c') {
      badges.add(BadgeDefinitions.granular_manager);
    }

    // Q8: Sleep Schedule badges
    final q8 = answers[8];
    if (q8 == 'q8_a') {
      badges.add(BadgeDefinitions.early_bird);
    } else if (q8 == 'q8_c') {
      badges.add(BadgeDefinitions.nocturnal_scholar);
    } else if (q8 != null && q8.startsWith('q8_custom_')) {
      final hour = int.tryParse(q8.split('_').last);
      if (hour != null) {
        // Bedtime interpretation: hours 0-6 = after midnight (nocturnal),
        // hours 20-23 = before midnight (early bird)
        if (hour >= 0 && hour <= 6) {
          badges.add(BadgeDefinitions.nocturnal_scholar);
        } else if (hour >= 20 && hour <= 23) {
          badges.add(BadgeDefinitions.early_bird);
        }
        // 7-19: daytime/ambiguous — no sleep badge
      }
    }
    // q8_e (no consistent schedule): no badge

    // Combo badges (require multiple individual badges)
    _addComboBadges(badges);

    return badges;
  }

  /// Check and add combo badges based on individual badges already earned.
  void _addComboBadges(List<Badge> badges) {
    final badgeIds = badges.map((b) => b.id).toSet();

    // Vampire Scholar: midnight_purist + nocturnal_scholar
    if (badgeIds.contains('midnight_purist') &&
        badgeIds.contains('nocturnal_scholar')) {
      badges.add(BadgeDefinitions.vampire_scholar);
    }

    // Sunrise Achiever: early_bird + dawn_greeter + monday_starter
    if (badgeIds.contains('early_bird') &&
        badgeIds.contains('dawn_greeter') &&
        badgeIds.contains('monday_starter')) {
      badges.add(BadgeDefinitions.sunrise_achiever);
    }

    // Night Ops: exacting_enthusiast + nocturnal_scholar
    if (badgeIds.contains('exacting_enthusiast') &&
        badgeIds.contains('nocturnal_scholar')) {
      badges.add(BadgeDefinitions.night_ops);
    }
  }

  /// Prefill quiz answers from existing UserSettings (for quiz retake).
  ///
  /// Maps current settings values back to the closest quiz answer IDs.
  /// Values are clamped to prevent invalid answer IDs.
  Map<int, String> prefillFromSettings(UserSettings settings) {
    final answers = <int, String>{};

    // Q1: Circadian rhythm (based on todayCutoffHour)
    final cutoffHour = settings.todayCutoffHour.clamp(0, 23);
    if (cutoffHour == 0) {
      answers[1] = 'q1_b'; // Midnight purist
    } else {
      answers[1] = 'q1_a'; // Night owl
    }

    // Q2: Week start
    final weekStart = settings.weekStartDay.clamp(0, 6);
    if (weekStart == 0) {
      answers[2] = 'q2_a'; // Sunday
    } else if (weekStart == 1) {
      answers[2] = 'q2_b'; // Monday
    } else {
      answers[2] = 'q2_c_$weekStart'; // Custom day
    }

    // Q3: "Tonight" (based on tonightHour)
    final tonightHour = settings.tonightHour.clamp(0, 23);
    if (tonightHour >= 17 && tonightHour <= 19) {
      answers[3] = 'q3_a'; // Early evening
    } else if (tonightHour >= 20 && tonightHour <= 21) {
      answers[3] = 'q3_b'; // Classic evening
    } else if (tonightHour >= 22) {
      answers[3] = 'q3_c'; // Late night
    } else {
      answers[3] = 'q3_custom_$tonightHour'; // Custom
    }

    // Q4: "Morning" (based on morningHour)
    final morningHour = settings.morningHour.clamp(0, 23);
    if (morningHour >= 6 && morningHour <= 8) {
      answers[4] = 'q4_a'; // Early morning
    } else if (morningHour >= 9 && morningHour <= 10) {
      answers[4] = 'q4_b'; // Mid-morning
    } else if (morningHour >= 11 && morningHour <= 12) {
      answers[4] = 'q4_c'; // Late morning
    } else {
      answers[4] = 'q4_custom_$morningHour'; // Custom
    }

    // Q5: Time format
    if (settings.use24HourTime) {
      answers[5] = 'q5_b'; // 24-hour
    } else {
      answers[5] = 'q5_a'; // 12-hour
    }

    // Q6: Quick add parsing
    if (settings.enableQuickAddDateParsing) {
      answers[6] = 'q6_a'; // Auto-detect
    } else {
      answers[6] = 'q6_b'; // Keep simple
    }

    // Q7: Auto-complete children
    switch (settings.autoCompleteChildren) {
      case 'always':
        answers[7] = 'q7_b';
        break;
      case 'never':
        answers[7] = 'q7_c';
        break;
      default:
        answers[7] = 'q7_a'; // prompt
    }

    // Q8: Sleep schedule (based on todayCutoffHour)
    if (cutoffHour == 0) {
      answers[8] = 'q8_a'; // Before midnight
    } else if (cutoffHour <= 4) {
      answers[8] = 'q8_b'; // 12-2am
    } else if (cutoffHour <= 5) {
      answers[8] = 'q8_c'; // 2-4am
    } else {
      // Derive bedtime from cutoff (cutoff = bedtime + 2)
      final bedtime = (cutoffHour + 22) % 24;
      answers[8] = 'q8_custom_$bedtime';
    }

    return answers;
  }
}
