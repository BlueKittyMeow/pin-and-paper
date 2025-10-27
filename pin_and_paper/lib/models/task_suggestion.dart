import 'task.dart';

class TaskSuggestion {
  final String id;              // Temporary UUID (becomes real on creation)
  final String title;
  final String? notes;          // Context extracted by Claude
  final bool approved;          // User approved this suggestion
  final bool edited;            // User manually edited this

  TaskSuggestion({
    required this.id,
    required this.title,
    this.notes,
    this.approved = true,       // Default to approved
    this.edited = false,
  });

  // Convert to Task for creation
  Task toTask() {
    return Task(
      id: id,                    // Reuse the suggestion ID
      title: title,
      createdAt: DateTime.now(),
    );
  }

  // Parse from Claude JSON response
  factory TaskSuggestion.fromJson(Map<String, dynamic> json, String id) {
    return TaskSuggestion(
      id: id,
      title: json['title'] as String,
      notes: json['notes'] as String?,
    );
  }

  // Copyable for edits
  TaskSuggestion copyWith({
    String? title,
    String? notes,
    bool? approved,
    bool? edited,
  }) {
    return TaskSuggestion(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      approved: approved ?? this.approved,
      edited: edited ?? this.edited,
    );
  }
}
