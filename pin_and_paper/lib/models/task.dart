class Task {
  // Existing fields
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Phase 3.1: Nesting support
  final String? parentId; // NULL = top-level task
  final int position; // Order within parent (or root level)
  final int depth; // Hierarchy depth (0-3, populated by queries)

  // Phase 3.1: Template support
  final bool isTemplate; // true = task is a template

  // Phase 3.1: Date support
  final DateTime? dueDate; // NULL = no due date
  final bool isAllDay; // true = all-day task (no specific time)
  final DateTime? startDate; // For multi-day tasks ("weekend")

  // Phase 3.1: Notification support
  final String notificationType; // 'use_global', 'custom', 'none'
  final DateTime? notificationTime; // Custom notification time

  // Phase 3.3: Soft delete support
  final DateTime? deletedAt; // NULL = active, non-NULL = soft-deleted

  // Phase 3.6.5: Edit Task Modal Rework
  final String? notes; // Task description/notes
  final int? positionBeforeCompletion; // For restoring position on uncomplete

  Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.completed = false,
    this.completedAt,
    // New fields with defaults
    this.parentId,
    this.position = 0,
    this.depth = 0,
    this.isTemplate = false,
    this.dueDate,
    this.isAllDay = true,
    this.startDate,
    this.notificationType = 'use_global',
    this.notificationTime,
    this.deletedAt,
    this.notes,
    this.positionBeforeCompletion,
  });

  /// Serialize to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      // New fields
      'parent_id': parentId,
      'position': position,
      // NOTE: 'depth' is NOT persisted - computed field from queries
      'is_template': isTemplate ? 1 : 0,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'is_all_day': isAllDay ? 1 : 0,
      'start_date': startDate?.millisecondsSinceEpoch,
      'notification_type': notificationType,
      'notification_time': notificationTime?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'notes': notes,
      'position_before_completion': positionBeforeCompletion,
    };
  }

  /// Deserialize from database map
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      completed: (map['completed'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['completed_at'] as int,
            )
          : null,
      // New fields (handle NULL for backward compatibility)
      parentId: map['parent_id'] as String?,
      position: (map['position'] as int?) ?? 0,
      depth: (map['depth'] as int?) ?? 0,
      isTemplate: (map['is_template'] as int?) == 1,
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
          : null,
      isAllDay: (map['is_all_day'] as int?) == null
          ? true
          : map['is_all_day'] != 0,
      startDate: map['start_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int)
          : null,
      notificationType: (map['notification_type'] as String?) ?? 'use_global',
      notificationTime: map['notification_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['notification_time'] as int)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
          : null,
      notes: map['notes'] as String?,
      positionBeforeCompletion: map['position_before_completion'] as int?,
    );
  }

  /// Copy with method for immutable updates
  Task copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
    DateTime? completedAt,
    String? parentId,
    int? position,
    int? depth,
    bool? isTemplate,
    DateTime? dueDate,
    bool? isAllDay,
    DateTime? startDate,
    String? notificationType,
    DateTime? notificationTime,
    DateTime? deletedAt,
    String? notes,
    int? positionBeforeCompletion,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      parentId: parentId ?? this.parentId,
      position: position ?? this.position,
      depth: depth ?? this.depth,
      isTemplate: isTemplate ?? this.isTemplate,
      dueDate: dueDate ?? this.dueDate,
      isAllDay: isAllDay ?? this.isAllDay,
      startDate: startDate ?? this.startDate,
      notificationType: notificationType ?? this.notificationType,
      notificationTime: notificationTime ?? this.notificationTime,
      deletedAt: deletedAt ?? this.deletedAt,
      notes: notes ?? this.notes,
      positionBeforeCompletion: positionBeforeCompletion ?? this.positionBeforeCompletion,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, completed: $completed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
