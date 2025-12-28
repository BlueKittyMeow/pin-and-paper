/// Tag model for organizing tasks with colored labels
///
/// Phase 3.5: Tags feature
/// - Flexible, overlapping organization (not rigid categories)
/// - Color-coded for visual distinction
/// - Soft delete support (hybrid deletion strategy)
class Tag {
  final String id;
  final String name; // Unique, case-insensitive (handled by DB)
  final String? color; // Hex color code (e.g., "#FF5722"), NULL = default
  final DateTime createdAt;
  final DateTime? deletedAt; // NULL = active, non-NULL = soft-deleted

  Tag({
    required this.id,
    required this.name,
    required this.createdAt,
    this.color,
    this.deletedAt,
  });

  /// Serialize to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  /// Deserialize from database map
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      deletedAt: map['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
          : null,
    );
  }

  /// Copy with method for immutable updates
  Tag copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Validate tag name
  ///
  /// Rules:
  /// - Must not be empty or whitespace-only
  /// - Trimmed name must have at least 1 character
  /// - Maximum 100 characters (allows descriptive tags like AO3)
  /// - Uniqueness enforced by database UNIQUE constraint
  ///
  /// Returns error message if invalid, null if valid
  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Tag name cannot be empty';
    }
    if (trimmed.length > 100) {
      return 'Tag name must be 100 characters or less';
    }
    return null; // Valid
  }

  /// Validate hex color code
  ///
  /// Rules:
  /// - Must start with #
  /// - Must be exactly 7 characters (#RRGGBB)
  /// - Must contain only valid hex digits (0-9, A-F, a-f)
  /// - NULL is valid (uses default color)
  ///
  /// Returns error message if invalid, null if valid
  static String? validateColor(String? color) {
    if (color == null) return null; // NULL is valid (default color)

    final hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
    if (!hexPattern.hasMatch(color)) {
      return 'Color must be a valid hex code (#RRGGBB)';
    }
    return null; // Valid
  }

  @override
  String toString() {
    return 'Tag(id: $id, name: $name, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tag && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
