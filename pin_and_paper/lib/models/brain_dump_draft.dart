class BrainDumpDraft {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime lastModified;
  final String? failedReason;  // Error message if processing failed

  BrainDumpDraft({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.lastModified,
    this.failedReason,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_modified': lastModified.millisecondsSinceEpoch,
      'failed_reason': failedReason,
    };
  }

  // Create from Map (database row)
  factory BrainDumpDraft.fromMap(Map<String, dynamic> map) {
    return BrainDumpDraft(
      id: map['id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastModified: DateTime.fromMillisecondsSinceEpoch(map['last_modified'] as int),
      failedReason: map['failed_reason'] as String?,
    );
  }
}
