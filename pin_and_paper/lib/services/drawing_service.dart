import 'package:uuid/uuid.dart';
import '../models/task_drawing.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Card drawings M-D4 (DB v14): persistence for per-task, per-face card
/// drawings (task_drawings table).
///
/// Lives beside TaskService rather than inside it — drawings are their own
/// table with their own lifecycle, and none of these operations touch the
/// tasks row. In particular, drawing writes must NOT bump tasks.updated_at:
/// the separate table exists precisely so task last-write-wins sync is
/// untouched by ink.
class DrawingService {
  final DatabaseService _dbService = DatabaseService.instance;
  final Uuid _uuid = const Uuid();

  /// Returns the drawing for a task face, or null if the task has none.
  Future<TaskDrawing?> getDrawingForTask(
    String taskId, {
    String face = TaskDrawing.faceFront,
  }) async {
    final db = await _dbService.database;

    final rows = await db.query(
      AppConstants.taskDrawingsTable,
      where: 'task_id = ? AND face = ?',
      whereArgs: [taskId, face],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return TaskDrawing.fromMap(rows.first);
  }

  /// Returns every task drawing in the database (all tasks, both faces,
  /// visible flag included) in ONE query.
  ///
  /// This is the Spatial View's load path: TaskSpatialDataSource calls it
  /// once at construction instead of issuing a per-task getDrawingForTask
  /// (N queries against a 300+-task desk is not acceptable on open).
  Future<List<TaskDrawing>> getAllDrawings() async {
    final db = await _dbService.database;

    final rows = await db.query(AppConstants.taskDrawingsTable);
    return [for (final row in rows) TaskDrawing.fromMap(row)];
  }

  /// Upserts the drawing for a task face: at most one row per
  /// (task_id, face). An existing row keeps its id, visibility, position,
  /// and created_at; only drawing_json and updated_at change.
  ///
  /// NOTE: deliberately does NOT call SyncService.logChange. The sync push
  /// path only maps tasks/tags/task_tags (preparePushEntry returns null for
  /// other tables), so logging task_drawings entries now would mark them
  /// synced-and-dropped — silently losing them for a future retro-push.
  /// When Supabase support for drawings lands, ship the remote table first,
  /// then add mappers + logChange (same follow-up path documented for
  /// canvas_x/canvas_y in the POC plan). Drawing writes also must not bump
  /// tasks.updated_at — task LWW stays untouched by design.
  Future<TaskDrawing> saveTaskDrawing(
    String taskId,
    String drawingJson, {
    String face = TaskDrawing.faceFront,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    return await db.transaction((txn) async {
      final existing = await txn.query(
        AppConstants.taskDrawingsTable,
        where: 'task_id = ? AND face = ?',
        whereArgs: [taskId, face],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Replace in place — preserves id, visible, position, created_at.
        final current = TaskDrawing.fromMap(existing.first);
        await txn.update(
          AppConstants.taskDrawingsTable,
          {
            'drawing_json': drawingJson,
            'updated_at': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [current.id],
        );
        return TaskDrawing(
          id: current.id,
          taskId: current.taskId,
          face: current.face,
          drawingJson: drawingJson,
          visible: current.visible,
          positionX: current.positionX,
          positionY: current.positionY,
          createdAt: current.createdAt,
          updatedAt: now,
        );
      }

      final drawing = TaskDrawing(
        id: _uuid.v4(),
        taskId: taskId,
        face: face,
        drawingJson: drawingJson,
        createdAt: now,
        updatedAt: now,
      );
      // FK constraint (task_id REFERENCES tasks ON DELETE CASCADE) rejects
      // drawings for nonexistent tasks.
      await txn.insert(AppConstants.taskDrawingsTable, drawing.toMap());
      return drawing;
    });
  }

  /// Sets the per-card show/hide toggle for a task face's drawing.
  ///
  /// Not synced and no tasks.updated_at bump — see saveTaskDrawing.
  ///
  /// Throws [Exception] if the task face has no drawing.
  Future<void> setTaskDrawingVisible(
    String taskId,
    bool visible, {
    String face = TaskDrawing.faceFront,
  }) async {
    final db = await _dbService.database;

    final count = await db.update(
      AppConstants.taskDrawingsTable,
      {
        'visible': visible ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'task_id = ? AND face = ?',
      whereArgs: [taskId, face],
    );

    if (count == 0) {
      throw Exception('No drawing found for task $taskId (face: $face)');
    }
  }

  /// Deletes the drawing for a task face. No-op if none exists.
  ///
  /// Not synced — see saveTaskDrawing.
  Future<void> deleteTaskDrawing(
    String taskId, {
    String face = TaskDrawing.faceFront,
  }) async {
    final db = await _dbService.database;

    await db.delete(
      AppConstants.taskDrawingsTable,
      where: 'task_id = ? AND face = ?',
      whereArgs: [taskId, face],
    );
  }
}
