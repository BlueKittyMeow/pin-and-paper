import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/tag.dart';
import '../utils/constants.dart';
import 'database_service.dart';

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

    final tag = Tag(
      id: _generateId(),
      name: name.trim(),
      color: color,
      createdAt: DateTime.now(),
    );

    await db.insert(
      AppConstants.tagsTable,
      tag.toMap(),
      // Default ConflictAlgorithm.abort throws on duplicate name (UNIQUE constraint)
      // This is intentional - prevents silent overwrite of existing tags
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

    await db.insert(
      AppConstants.taskTagsTable,
      {
        'task_id': taskId,
        'tag_id': tagId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Idempotent: ignore duplicates
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
