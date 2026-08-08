import '../models/desk_object_state.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Desk-objects drawer (DB v15): persistence for knick-knack placement
/// (desk_objects table).
///
/// Lives beside DrawingService for the same reason it does: desk objects
/// are their own table with their own lifecycle and never touch the tasks
/// row. Writes are sync-silent by design — no SyncService.logChange (the
/// push path maps only tasks/tags/task_tags; logging rows now would mark
/// them synced-and-dropped, silently losing them for a future retro-push).
/// Decor placement stays per-device until a remote table ships.
class DeskObjectService {
  final DatabaseService _dbService = DatabaseService.instance;

  /// Every stored desk-object row in ONE query — the Spatial View's load
  /// path, called once at TaskSpatialDataSource construction. Kinds with no
  /// row yet simply aren't in the list (callers apply per-kind defaults).
  Future<List<DeskObjectState>> getAll() async {
    final db = await _dbService.database;
    final rows = await db.query(AppConstants.deskObjectsTable);
    return [for (final row in rows) DeskObjectState.fromMap(row)];
  }

  /// Upserts [id]'s full state. One row per kind: INSERT OR REPLACE keyed
  /// on the fixed id is exactly the semantics wanted.
  Future<void> save({
    required String id,
    required bool placed,
    double? x,
    double? y,
    double? width,
    int variant = 0,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert('''
      INSERT INTO ${AppConstants.deskObjectsTable}
        (id, placed, x, y, width, variant, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?,
        COALESCE((SELECT created_at FROM ${AppConstants.deskObjectsTable} WHERE id = ?), ?),
        ?)
      ON CONFLICT(id) DO UPDATE SET
        placed = excluded.placed,
        x = excluded.x,
        y = excluded.y,
        width = excluded.width,
        variant = excluded.variant,
        updated_at = excluded.updated_at
    ''', [id, placed ? 1 : 0, x, y, width, variant, id, now, now]);
  }
}
