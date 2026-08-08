/// Card drawings M-D4 (DB v14): a persisted drawing for one face of a task
/// card.
///
/// `drawingJson` is the sketchpad module's LayerStack serialization
/// (format v1). At most one row exists per (taskId, face) in v1 — enforced
/// by DrawingService, not the schema, so the schema stays multi-drawing
/// ready (positionX/positionY are the future placement columns, 0,0 =
/// fills the card face).
class TaskDrawing {
  /// Face values — a card has an independent drawing per face.
  static const String faceFront = 'front';
  static const String faceBack = 'back';

  final String id;
  final String taskId;
  final String face;
  final String drawingJson;
  final bool visible;
  final double positionX;
  final double positionY;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TaskDrawing({
    required this.id,
    required this.taskId,
    this.face = faceFront,
    required this.drawingJson,
    this.visible = true,
    this.positionX = 0,
    this.positionY = 0,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'face': face,
      'drawing_json': drawingJson,
      'visible': visible ? 1 : 0,
      'position_x': positionX,
      'position_y': positionY,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  // Create from Map (database row)
  factory TaskDrawing.fromMap(Map<String, dynamic> map) {
    return TaskDrawing(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      face: map['face'] as String,
      drawingJson: map['drawing_json'] as String,
      visible: (map['visible'] as int) == 1,
      positionX: (map['position_x'] as num).toDouble(),
      positionY: (map['position_y'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }
}
