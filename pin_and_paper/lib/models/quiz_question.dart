/// Represents a single answer option in a quiz question.
class QuizAnswer {
  final String id;
  final String text;
  final String? description;
  final bool showTimePicker; // If true, show time picker when selected
  final bool showDayPicker; // If true, show day-of-week picker when selected

  const QuizAnswer({
    required this.id,
    required this.text,
    this.description,
    this.showTimePicker = false,
    this.showDayPicker = false,
  });
}

/// Represents a single quiz question with its answer options.
class QuizQuestion {
  final int id;
  final String title;
  final String question;
  final String? imagePath; // Optional scenario illustration
  final List<QuizAnswer> answers;

  const QuizQuestion({
    required this.id,
    required this.title,
    required this.question,
    this.imagePath,
    required this.answers,
  });
}
