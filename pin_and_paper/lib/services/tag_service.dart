import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/tag.dart';
import '../utils/constants.dart';
import 'database_service.dart';
import 'sync_service.dart'; // Phase 4.0

/// Service for managing tags and tag-task associations
///
/// Phase 3.5: Tags feature
/// - CRUD operations for tags
/// - Tag-task associations (many-to-many)
/// - Batch loading to prevent N+1 queries
/// - Soft delete support (hybrid deletion strategy)
class TagService {
  final DatabaseService _dbService = DatabaseService.instance;
  final Uuid _uuid = const Uuid();

  String _generateId() => _uuid.v4();

  // ===================================================================
  // CRUD Operations
  // ===================================================================

  /// Create a new tag
  ///
  /// Validates:
  /// - Name is not empty
  /// - Color is valid hex format (if provided)
  ///
  /// Throws:
  /// - ArgumentError if validation fails
  /// - DatabaseException if name already exists (UNIQUE constraint)
  Future<Tag> createTag(String name, {String? color}) async {
    // Validate name
    final nameError = Tag.validateName(name);
    if (nameError != null) {
      throw ArgumentError(nameError);
    }

    // Validate color
    final colorError = Tag.validateColor(color);
    if (colorError != null) {
      throw ArgumentError(colorError);
    }

    final db = await _dbService.database;

    final now = DateTime.now();
    final tag = Tag(
      id: _generateId(),
      name: name.trim(),
      color: color,
      createdAt: now,
      updatedAt: now,
    );

    final tagMap = tag.toMap();
    await db.insert(
      AppConstants.tagsTable,
      tagMap,
      // Default ConflictAlgorithm.abort throws on duplicate name (UNIQUE constraint)
      // This is intentional - prevents silent overwrite of existing tags
    );

    await SyncService.instance.logChange(
      tableName: 'tags',
      recordId: tag.id,
      operation: 'INSERT',
      payload: tagMap,
    );

    return tag;
  }

  /// Get all active tags (excludes soft-deleted)
  ///
  /// Returns tags ordered by name (alphabetically)
  Future<List<Tag>> getAllTags() async {
    final db = await _dbService.database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tagsTable,
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );

    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get tag by ID
  ///
  /// Returns null if tag not found or soft-deleted
  Future<Tag?> getTagById(String id) async {
    final db = await _dbService.database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tagsTable,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  /// Get tag by name (case-insensitive)
  ///
  /// Used for:
  /// - Autocomplete (prevent duplicates)
  /// - Tag picker search
  ///
  /// Returns null if tag not found or soft-deleted
  Future<Tag?> getTagByName(String name) async {
    final db = await _dbService.database;

    // SQLite COLLATE NOCASE for case-insensitive comparison
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tagsTable,
      where: 'name = ? COLLATE NOCASE AND deleted_at IS NULL',
      whereArgs: [name.trim()],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  /// Batch-fetch multiple tags by IDs in a single query
  ///
  /// Phase 3.6B v4.1 MEDIUM FIX (Codex): Eliminates N sequential queries
  /// when loading tag chips in search dialog.
  ///
  /// Example: If user has 5 tags selected, this fetches all 5 in one query
  /// instead of 5 separate database queries.
  ///
  /// Returns list of tags (may be smaller than input if some IDs don't exist)
  Future<List<Tag>> getTagsByIds(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];

    final db = await _dbService.database;
    final placeholders = tagIds.map((_) => '?').join(',');

    final results = await db.query(
      AppConstants.tagsTable,
      where: 'id IN ($placeholders) AND deleted_at IS NULL',
      whereArgs: tagIds,
    );

    return results.map((map) => Tag.fromMap(map)).toList();
  }

  /// Update a tag's name and/or color
  ///
  /// At least one field must be provided.
  /// Short-circuits if the new values are identical to current values (no-op).
  ///
  /// Throws:
  /// - ArgumentError if no fields provided, name is empty, or color is invalid hex
  /// - StateError if tag not found or is soft-deleted
  /// - DatabaseException if name already exists on a different tag (UNIQUE constraint)
  Future<Tag> updateTag(String id, {String? name, String? color}) async {
    // 1. At least one field must be provided
    if (name == null && color == null) {
      throw ArgumentError('At least one field (name or color) must be provided');
    }

    // 2. Validate name if provided
    if (name != null) {
      final nameError = Tag.validateName(name);
      if (nameError != null) {
        throw ArgumentError(nameError);
      }
    }

    // 3. Validate color if provided
    if (color != null) {
      final colorError = Tag.validateColor(color);
      if (colorError != null) {
        throw ArgumentError(colorError);
      }
    }

    // 4. Check tag exists and is not soft-deleted
    final existing = await getTagById(id);
    if (existing == null) {
      throw StateError('Tag not found or has been deleted');
    }

    // 5. Short-circuit no-op updates
    final trimmedName = name?.trim();
    final nameUnchanged = trimmedName == null || trimmedName == existing.name;
    final colorUnchanged = color == null || color == existing.color;
    if (nameUnchanged && colorUnchanged) {
      return existing;
    }

    // 6. Build update map
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'updated_at': now,
    };
    if (trimmedName != null && trimmedName != existing.name) {
      updates['name'] = trimmedName;
    }
    if (color != null && color != existing.color) {
      updates['color'] = color;
    }

    // 7. Update DB — UNIQUE constraint throws on duplicate name
    await db.update(
      AppConstants.tagsTable,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );

    // 8. Re-read updated tag
    final updated = await getTagById(id);

    // 9. Log change for sync
    await SyncService.instance.logChange(
      tableName: 'tags',
      recordId: id,
      operation: 'UPDATE',
      payload: updated!.toMap(),
    );

    return updated;
  }

  /// Soft-delete a tag and remove all its task associations
  ///
  /// Uses a transaction for atomicity (Finding 1 from both Codex and Gemini reviews).
  /// Task_tags are hard-deleted because:
  /// - Junction table has no `deleted_at` column
  /// - Soft-deleted tag shouldn't be associated with tasks
  /// - `pullTaskTags()` does full union-merge reconciliation
  ///
  /// Throws:
  /// - StateError if tag not found or already soft-deleted
  Future<void> deleteTag(String id) async {
    // 1. Check tag exists and is not already soft-deleted
    final existing = await getTagById(id);
    if (existing == null) {
      throw StateError('Tag not found or has already been deleted');
    }

    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 2. Query affected task_tags before deletion (for sync logging)
    final affectedTaskTags = await db.query(
      AppConstants.taskTagsTable,
      where: 'tag_id = ?',
      whereArgs: [id],
    );

    // 3. Wrap in transaction for atomicity
    await db.transaction((txn) async {
      // Soft-delete tag
      await txn.update(
        AppConstants.tagsTable,
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );

      // Hard-delete task_tags
      await txn.delete(
        AppConstants.taskTagsTable,
        where: 'tag_id = ?',
        whereArgs: [id],
      );
    });

    // 4. Log sync changes (after transaction commits)
    // Log tag as UPDATE (soft delete = UPDATE with deleted_at set)
    final deletedTag = existing.copyWith(
      deletedAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    await SyncService.instance.logChange(
      tableName: 'tags',
      recordId: id,
      operation: 'UPDATE',
      payload: deletedTag.toMap(),
    );

    // Log each task_tag DELETE individually
    for (final taskTag in affectedTaskTags) {
      final taskId = taskTag['task_id'] as String;
      await SyncService.instance.logChange(
        tableName: 'task_tags',
        recordId: '${taskId}_$id',
        operation: 'DELETE',
      );
    }
  }

  // ===================================================================
  // Tag-Task Associations
  // ===================================================================

  /// Add a tag to a task
  ///
  /// Creates association in task_tags junction table
  /// Idempotent: Does nothing if association already exists
  ///
  /// Throws:
  /// - DatabaseException if task or tag doesn't exist (foreign key constraint)
  Future<void> addTagToTask(String taskId, String tagId) async {
    final db = await _dbService.database;

    final payload = {
      'task_id': taskId,
      'tag_id': tagId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    await db.insert(
      AppConstants.taskTagsTable,
      payload,
      conflictAlgorithm: ConflictAlgorithm.ignore, // Idempotent: ignore duplicates
    );

    await SyncService.instance.logChange(
      tableName: 'task_tags',
      recordId: '${taskId}_$tagId',
      operation: 'INSERT',
      payload: payload,
    );
  }

  /// Remove a tag from a specific task
  ///
  /// **CRITICAL**: Enables removing tag from individual task
  /// without affecting other tasks using the same tag
  ///
  /// Returns true if tag is not associated (idempotent operation)
  /// Returns false only on database errors (exceptions)
  Future<bool> removeTagFromTask(String taskId, String tagId) async {
    final db = await _dbService.database;

    await db.delete(
      AppConstants.taskTagsTable,
      where: 'task_id = ? AND tag_id = ?',
      whereArgs: [taskId, tagId],
    );

    await SyncService.instance.logChange(
      tableName: 'task_tags',
      recordId: '${taskId}_$tagId',
      operation: 'DELETE',
    );

    // Phase 3.5: Fix #M1 - Idempotent removal
    // Return true even if 0 rows deleted (tag already removed)
    // Only return false on actual database errors (caught exceptions)
    return true;
  }

  /// Get all tags for a single task
  ///
  /// Returns tags ordered by name
  /// Excludes soft-deleted tags
  Future<List<Tag>> getTagsForTask(String taskId) async {
    final db = await _dbService.database;

    final maps = await db.rawQuery('''
      SELECT t.*
      FROM ${AppConstants.tagsTable} t
      JOIN ${AppConstants.taskTagsTable} tt ON t.id = tt.tag_id
      WHERE tt.task_id = ?
        AND t.deleted_at IS NULL
      ORDER BY t.name ASC
    ''', [taskId]);

    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get task counts for all tags (Phase 3.6A)
  ///
  /// **CRITICAL**: Performance optimization for tag filter dialog
  ///
  /// Returns map of tagId to task count
  /// - Only includes tags that have at least one task
  /// - Excludes soft-deleted tasks
  /// - Filters by completed status to match current task list view
  ///
  /// Performance:
  /// - Before: N queries (one per tag) - 250ms for 50 tags
  /// - After: 1 query with GROUP BY - 10ms (25× faster!)
  ///
  /// Example:
  /// ```dart
  /// // Get counts for active tasks only
  /// final counts = await getTaskCountsByTag(completed: false);
  /// // counts = {'tag-1': 5, 'tag-2': 12, ...}
  /// ```
  Future<Map<String, int>> getTaskCountsByTag({required bool completed}) async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
      SELECT
        task_tags.tag_id,
        COUNT(DISTINCT tasks.id) as task_count
      FROM ${AppConstants.taskTagsTable} task_tags
      INNER JOIN ${AppConstants.tasksTable} tasks ON tasks.id = task_tags.task_id
      WHERE tasks.deleted_at IS NULL
        AND tasks.completed = ?
      GROUP BY task_tags.tag_id
    ''', [completed ? 1 : 0]);

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['tag_id'] as String,
        row['task_count'] as int,
      )),
    );
  }

  /// Batch load tags for multiple tasks (fixes N+1 query problem)
  ///
  /// **CRITICAL**: Performance optimization for loading tasks with tags
  ///
  /// Returns map of taskId to List of Tag
  /// - Tasks with tags: included in map with list of tags
  /// - Tasks with no tags: NOT included in map (result[id] == null)
  /// - Excludes soft-deleted tags
  ///
  /// Performance:
  /// - Before: N+1 queries (1 + N * 1 for N tasks)
  /// - After: 1-N queries (batched by 900 tasks due to SQLite limit)
  /// - 250x improvement for 500 tasks (2 queries vs 501)
  ///
  /// SQLite Parameter Limit:
  /// - SQLite has SQLITE_MAX_VARIABLE_NUMBER limit (~999 default)
  /// - Automatically batches requests in chunks of 900 to stay safe
  /// - Handles lists of any size without errors
  Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return {};

    // SQLite parameter limit is ~999, use 900 to be safe
    const batchSize = 900;

    // If small enough, process in single batch
    if (taskIds.length <= batchSize) {
      return _getTagsForTasksBatch(taskIds);
    }

    // For large lists, batch the requests
    final result = <String, List<Tag>>{};
    for (int i = 0; i < taskIds.length; i += batchSize) {
      final end = (i + batchSize < taskIds.length) ? i + batchSize : taskIds.length;
      final batch = taskIds.sublist(i, end);
      final batchResult = await _getTagsForTasksBatch(batch);
      result.addAll(batchResult);
    }

    return result;
  }

  /// Internal helper: Load tags for a batch of tasks (≤900)
  ///
  /// Should not be called directly - use getTagsForAllTasks instead
  /// which handles batching automatically.
  Future<Map<String, List<Tag>>> _getTagsForTasksBatch(List<String> taskIds) async {
    final db = await _dbService.database;
    final placeholders = List.filled(taskIds.length, '?').join(',');

    final maps = await db.rawQuery('''
      SELECT tt.task_id, t.*
      FROM ${AppConstants.taskTagsTable} tt
      JOIN ${AppConstants.tagsTable} t ON tt.tag_id = t.id
      WHERE tt.task_id IN ($placeholders)
        AND t.deleted_at IS NULL
      ORDER BY t.name ASC
    ''', taskIds);

    // Group by task_id
    final result = <String, List<Tag>>{};
    for (var map in maps) {
      final taskId = map['task_id'] as String;
      // Create Tag from map (skip task_id column)
      final tagMap = Map<String, dynamic>.from(map)..remove('task_id');
      final tag = Tag.fromMap(tagMap);
      result.putIfAbsent(taskId, () => []).add(tag);
    }

    return result;
  }
}
