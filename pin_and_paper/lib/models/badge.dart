/// Represents a personality badge earned from the onboarding quiz.
class Badge {
  final String id;
  final String name;
  final String description;
  final String imagePath; // Path to badge asset (e.g., 'assets/images/badges/night_owl.png')
  final BadgeCategory category;
  final bool isCombo; // True for special combination badges

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.category,
    this.isCombo = false,
  });
}

/// Categories for organizing badges.
enum BadgeCategory {
  circadianRhythm,
  weekStructure,
  dailyRhythm,
  displayPreference,
  taskManagement,
  combo,
}
