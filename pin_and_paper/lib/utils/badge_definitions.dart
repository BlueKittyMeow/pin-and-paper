// ignore_for_file: constant_identifier_names

import '../models/badge.dart';

/// All badge definitions for the onboarding quiz.
///
/// Badge images are stored at assets/images/badges/{1x,2x,3x}/
/// Use [getBadgeById] to look up a badge by its ID.
class BadgeDefinitions {
  BadgeDefinitions._();

  /// Get the asset path for a badge at a given density.
  static String badgeAssetPath(String badgeId, {int density = 1}) {
    return 'assets/images/badges/${density}x/$badgeId.png';
  }

  // ==========================================
  // Circadian Rhythm Badges (Q1 + Q8)
  // ==========================================

  static const midnight_purist = Badge(
    id: 'midnight_purist',
    name: 'Midnight Purist',
    description: 'You believe the day ends at midnight, with strict calendar boundaries.',
    imagePath: 'assets/images/badges/1x/midnight_purist.png',
    category: BadgeCategory.circadianRhythm,
  );

  static const night_owl = Badge(
    id: 'night_owl',
    name: 'Night Owl',
    description: 'Your day extends past midnight — Friday isn\'t over until you sleep.',
    imagePath: 'assets/images/badges/1x/night_owl.png',
    category: BadgeCategory.circadianRhythm,
  );

  static const early_bird = Badge(
    id: 'early_bird',
    name: 'Early Bird',
    description: 'You\'re a morning person who sleeps before midnight.',
    imagePath: 'assets/images/badges/1x/early_bird.png',
    category: BadgeCategory.circadianRhythm,
  );

  static const nocturnal_scholar = Badge(
    id: 'nocturnal_scholar',
    name: 'Nocturnal Scholar',
    description: 'You\'re regularly awake past 2am — a true creature of the night.',
    imagePath: 'assets/images/badges/1x/nocturnal_scholar.png',
    category: BadgeCategory.circadianRhythm,
  );

  // ==========================================
  // Week Structure Badges (Q2)
  // ==========================================

  static const monday_starter = Badge(
    id: 'monday_starter',
    name: 'Monday Starter',
    description: 'Your week begins on Monday — international work-week style.',
    imagePath: 'assets/images/badges/1x/monday_starter.png',
    category: BadgeCategory.weekStructure,
  );

  static const sunday_traditionalist = Badge(
    id: 'sunday_traditionalist',
    name: 'Sunday Traditionalist',
    description: 'Your week begins on Sunday — classic US calendar style.',
    imagePath: 'assets/images/badges/1x/sunday_traditionalist.png',
    category: BadgeCategory.weekStructure,
  );

  static const calendar_rebel = Badge(
    id: 'calendar_rebel',
    name: 'Calendar Rebel',
    description: 'Your week starts on an unconventional day — you make your own rules.',
    imagePath: 'assets/images/badges/1x/calendar_rebel.png',
    category: BadgeCategory.weekStructure,
  );

  // ==========================================
  // Daily Rhythm Badges (Q3 + Q4)
  // ==========================================

  static const dawn_greeter = Badge(
    id: 'dawn_greeter',
    name: 'Dawn Greeter',
    description: 'Your morning starts early — you greet the sunrise.',
    imagePath: 'assets/images/badges/1x/dawn_greeter.png',
    category: BadgeCategory.dailyRhythm,
  );

  static const classic_scheduler = Badge(
    id: 'classic_scheduler',
    name: 'Classic Scheduler',
    description: 'You follow a standard daily rhythm — 9-to-5 aligned.',
    imagePath: 'assets/images/badges/1x/classic_scheduler.png',
    category: BadgeCategory.dailyRhythm,
  );

  static const late_morning_luxurist = Badge(
    id: 'late_morning_luxurist',
    name: 'Late Morning Luxurist',
    description: 'You take your mornings slow — no rush to start the day.',
    imagePath: 'assets/images/badges/1x/late_morning_luxurist.png',
    category: BadgeCategory.dailyRhythm,
  );

  static const twilight_worker = Badge(
    id: 'twilight_worker',
    name: 'Twilight Worker',
    description: 'You come alive in the late evening hours.',
    imagePath: 'assets/images/badges/1x/twilight_worker.png',
    category: BadgeCategory.dailyRhythm,
  );

  // ==========================================
  // Display Preference Badges (Q5)
  // ==========================================

  static const exacting_enthusiast = Badge(
    id: 'exacting_enthusiast',
    name: 'Exacting Enthusiast',
    description: 'You prefer 24-hour time — precision is your style.',
    imagePath: 'assets/images/badges/1x/exacting_enthusiast.png',
    category: BadgeCategory.displayPreference,
  );

  static const am_pm_classicist = Badge(
    id: 'am_pm_classicist',
    name: 'AM/PM Classicist',
    description: 'You prefer 12-hour time with AM/PM markers.',
    imagePath: 'assets/images/badges/1x/am_pm_classicist.png',
    category: BadgeCategory.displayPreference,
  );

  // ==========================================
  // Task Management Badges (Q7)
  // ==========================================

  static const decisive_completer = Badge(
    id: 'decisive_completer',
    name: 'Decisive Completer',
    description: 'Parent done means all done — you complete decisively.',
    imagePath: 'assets/images/badges/1x/decisive_completer.png',
    category: BadgeCategory.taskManagement,
  );

  static const thoughtful_curator = Badge(
    id: 'thoughtful_curator',
    name: 'Thoughtful Curator',
    description: 'You decide case-by-case whether subtasks should auto-complete.',
    imagePath: 'assets/images/badges/1x/thoughtful_curator.png',
    category: BadgeCategory.taskManagement,
  );

  static const granular_manager = Badge(
    id: 'granular_manager',
    name: 'Granular Manager',
    description: 'You handle each task separately — no auto-completing for you.',
    imagePath: 'assets/images/badges/1x/granular_manager.png',
    category: BadgeCategory.taskManagement,
  );

  // ==========================================
  // Combo Badges (require multiple answers)
  // ==========================================

  static const vampire_scholar = Badge(
    id: 'vampire_scholar',
    name: 'Vampire Scholar',
    description: 'Strict midnight boundaries yet awake all night — a fascinating paradox.',
    imagePath: 'assets/images/badges/1x/vampire_scholar.png',
    category: BadgeCategory.combo,
    isCombo: true,
  );

  static const sunrise_achiever = Badge(
    id: 'sunrise_achiever',
    name: 'Sunrise Achiever',
    description: 'Early bird + dawn greeter + Monday starter — the ultimate morning person.',
    imagePath: 'assets/images/badges/1x/sunrise_achiever.png',
    category: BadgeCategory.combo,
    isCombo: true,
  );

  static const night_ops = Badge(
    id: 'night_ops',
    name: 'Night Ops',
    description: 'Military time + nocturnal schedule — precision in the dark.',
    imagePath: 'assets/images/badges/1x/night_ops.png',
    category: BadgeCategory.combo,
    isCombo: true,
  );

  // Note: time_anarchist badge requires Q2 (Weekday Reference Logic) which
  // was removed from the quiz in Phase 3.9. The asset exists but the badge
  // cannot be earned until Q2 is re-introduced in a future version.

  /// All individual (non-combo) badges that can be earned.
  static const List<Badge> allIndividual = [
    midnight_purist,
    night_owl,
    early_bird,
    nocturnal_scholar,
    monday_starter,
    sunday_traditionalist,
    calendar_rebel,
    dawn_greeter,
    classic_scheduler,
    late_morning_luxurist,
    twilight_worker,
    exacting_enthusiast,
    am_pm_classicist,
    decisive_completer,
    thoughtful_curator,
    granular_manager,
  ];

  /// All combo badges.
  static const List<Badge> allCombo = [
    vampire_scholar,
    sunrise_achiever,
    night_ops,
  ];

  /// All badges (individual + combo).
  static const List<Badge> all = [
    ...allIndividual,
    ...allCombo,
  ];

  /// Look up a badge by its ID. Returns null if not found.
  static Badge? getBadgeById(String id) {
    for (final badge in all) {
      if (badge.id == id) return badge;
    }
    return null;
  }
}
