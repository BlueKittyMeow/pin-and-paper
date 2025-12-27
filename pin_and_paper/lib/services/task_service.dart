import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/task_suggestion.dart'; // Phase 2
import '../utils/constants.dart';
import 'database_service.dart';

class TaskService {
  final DatabaseService _dbService = DatabaseService.instance;
  final Uuid _uuid = const Uuid();

  // Create a new task
  Future<Task> createTask(String title) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Task title cannot be empty');
    }

    final db = await _dbService.database;

    // Phase 3.1: Calculate next position for top-level tasks
    // Phase 3.3: Only consider active (not deleted) tasks for position calculation
    final result = await db.rawQuery('''
      SELECT COALESCE(MAX(position), -1) as max_position
      FROM ${AppConstants.tasksTable}
      WHERE parent_id IS NULL AND deleted_at IS NULL
    ''');
    final maxPosition = result.first['max_position'] as int;
    final nextPosition = maxPosition + 1;

    final task = Task(
      id: _generateId(),
      title: title.trim(),
      createdAt: DateTime.now(),
      position: nextPosition, // Phase 3.1: Assign calculated position
    );

    await db.insert(
      AppConstants.tasksTable,
      task.toMap(),
      // Removed ConflictAlgorithm.replace to prevent silent data loss
      // Default is ConflictAlgorithm.abort which throws on duplicate IDs
    );

    return task;
  }

  // Phase 2: Create multiple tasks in a single transaction (for bulk imports)
  // This is CRITICAL for performance - prevents UI stuttering when adding 10+ tasks
  Future<List<Task>> createMultipleTasks(List<TaskSuggestion> suggestions) async {
    if (suggestions.isEmpty) return [];

    final db = await _dbService.database;
    final List<Task> createdTasks = [];

    // Phase 3.1: Get starting position for bulk insert
    // Phase 3.3: Only consider active (not deleted) tasks for position calculation
    final result = await db.rawQuery('''
      SELECT COALESCE(MAX(position), -1) as max_position
      FROM ${AppConstants.tasksTable}
      WHERE parent_id IS NULL AND deleted_at IS NULL
    ''');
    int nextPosition = (result.first['max_position'] as int) + 1;

    // Use a transaction for atomicity and performance
    // All tasks are created in one database operation instead of N operations
    await db.transaction((txn) async {
      for (final suggestion in suggestions) {
        // Only create approved tasks
        if (!suggestion.approved) continue;

        final task = Task(
          id: suggestion.id, // Reuse suggestion ID (already UUID from ClaudeService)
          title: suggestion.title,
          createdAt: DateTime.now(),
          position: nextPosition++, // Phase 3.1: Assign and increment position
        );

        await txn.insert(
          AppConstants.tasksTable,
          task.toMap(),
        );

        createdTasks.add(task);
      }
    });

    return createdTasks;
  }

  // Get all tasks (ordered by position)
  // Phase 3.1: Orders by position instead of created_at
  // Phase 3.2: Use getTaskHierarchy() for hierarchical display
  // Phase 3.3: Excludes soft-deleted tasks
  Future<List<Task>> getAllTasks() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tasksTable,
      where: 'deleted_at IS NULL',  // Phase 3.3: Exclude soft-deleted
      // Bug fix: DESC ordering - newest tasks (highest position) appear first
      // This matches TaskProvider.createTask() which inserts at index 0
      orderBy: 'position DESC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // Phase 3.2: Get all tasks with hierarchy information
  // Returns flat list ordered by parent_id and position
  // Uses recursive CTE to compute depth dynamically
  // Phase 3.3: Excludes soft-deleted tasks
  Future<List<Task>> getTaskHierarchy() async {
    final db = await _dbService.database;

    // Recursive CTE to get tasks with depth
    // Orders by: root position, then children under parents
    // Reference: docs/phase-03/group1.md:1508-1578
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      WITH RECURSIVE task_tree AS (
        -- Base case: root-level tasks (parent_id IS NULL, not deleted)
        SELECT
          *,
          0 as depth,
          printf('%05d', position) as sort_key
        FROM ${AppConstants.tasksTable}
        WHERE parent_id IS NULL AND deleted_at IS NULL

        UNION ALL

        -- Recursive case: children of tasks (not deleted)
        SELECT
          t.*,
          tt.depth + 1 as depth,
          tt.sort_key || '.' || printf('%05d', t.position) as sort_key
        FROM ${AppConstants.tasksTable} t
        INNER JOIN task_tree tt ON t.parent_id = tt.id
        WHERE tt.depth < 3 AND t.deleted_at IS NULL  -- Max 4 levels (0-indexed: 0, 1, 2, 3)
      )
      SELECT * FROM task_tree
      ORDER BY sort_key
    ''');

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // Phase 3.2: Get children of a specific task
  // Phase 3.3: Excludes soft-deleted tasks
  Future<List<Task>> getTaskWithChildren(String parentId) async {
    final db = await _dbService.database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tasksTable,
      where: 'parent_id = ? AND deleted_at IS NULL',
      whereArgs: [parentId],
      orderBy: 'position ASC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // Toggle task completion status
  Future<Task> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(
      completed: !task.completed,
      completedAt: !task.completed ? DateTime.now() : null,
    );

    final db = await _dbService.database;
    await db.update(
      AppConstants.tasksTable,
      updatedTask.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    return updatedTask;
  }

  // Get count of incomplete tasks
  // Phase 3.3: Excludes soft-deleted tasks
  Future<int> getIncompleteTaskCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tasksTable} WHERE completed = 0 AND deleted_at IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Get count of completed tasks
  // Phase 3.3: Excludes soft-deleted tasks
  Future<int> getCompletedTaskCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tasksTable} WHERE completed = 1 AND deleted_at IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Phase 3.2: Update task parent (move task in hierarchy)
  // Validates depth and cycles, reindexes siblings
  // Returns null on success, error message on failure
  Future<String?> updateTaskParent(
    String taskId,
    String? newParentId,
    int newPosition,
  ) async {
    final db = await _dbService.database;

    return await db.transaction((txn) async {
      // 1. Get current task
      final taskMaps = await txn.query(
        AppConstants.tasksTable,
        where: 'id = ?',
        whereArgs: [taskId],
      );
      if (taskMaps.isEmpty) return 'Task not found';

      final oldParentId = taskMaps.first['parent_id'] as String?;

      // 2. Check for cycle (if newParentId is not null)
      if (newParentId != null) {
        final wouldCycle = await _wouldCreateCycle(taskId, newParentId, txn);
        if (wouldCycle) {
          return 'Cannot create circular task dependencies';
        }
      }

      // 3. Check depth limit
      final newDepth = await _getTaskDepth(newParentId, txn);
      if (newDepth >= 3) {  // 0-indexed: 0, 1, 2, 3 = 4 levels
        return 'Maximum nesting depth (4 levels) reached';
      }

      // 4. Handle position conflicts when moving tasks
      if (oldParentId == newParentId) {
        // Moving within same parent - avoid position conflicts
        // Step 1: Temporarily remove task from sibling list
        await txn.update(
          AppConstants.tasksTable,
          {'position': -1},
          where: 'id = ?',
          whereArgs: [taskId],
        );

        // Step 2: Reindex remaining siblings to close gap
        await _reindexSiblings(newParentId, txn, excludeTaskId: taskId);

        // Step 3: Shift siblings at >= newPosition up by 1 to make space
        await txn.rawUpdate('''
          UPDATE ${AppConstants.tasksTable}
          SET position = position + 1
          WHERE ${newParentId == null ? 'parent_id IS NULL' : 'parent_id = ?'}
            AND position >= ?
        ''', newParentId == null ? [newPosition] : [newParentId, newPosition]);

        // Step 4: Insert task at desired position
        await txn.update(
          AppConstants.tasksTable,
          {
            'parent_id': newParentId,
            'position': newPosition,
          },
          where: 'id = ?',
          whereArgs: [taskId],
        );
      } else {
        // Moving to different parent
        // Step 1: Move task to new parent with temporary position to avoid conflicts
        await txn.update(
          AppConstants.tasksTable,
          {
            'parent_id': newParentId,
            'position': -1,  // Temporary position (semantically "out of list")
          },
          where: 'id = ?',
          whereArgs: [taskId],
        );

        // Step 2: Reindex siblings in SOURCE list (closes gap left by moved task)
        await _reindexSiblings(oldParentId, txn);

        // Step 3: Shift siblings in DESTINATION list at >= newPosition up by 1
        await txn.rawUpdate('''
          UPDATE ${AppConstants.tasksTable}
          SET position = position + 1
          WHERE ${newParentId == null ? 'parent_id IS NULL' : 'parent_id = ?'}
            AND position >= ?
            AND id != ?
        ''', newParentId == null
            ? [newPosition, taskId]
            : [newParentId, newPosition, taskId]);

        // Step 4: Insert task at desired position
        await txn.update(
          AppConstants.tasksTable,
          {'position': newPosition},
          where: 'id = ?',
          whereArgs: [taskId],
        );
      }

      return null;  // Success
    });
  }

  // Phase 3.2: Count descendants of a task (children only, excluding task itself)
  // Used for CASCADE delete confirmation dialogs
  // Phase 3.3: Only counts active (not deleted) descendants
  Future<int> countDescendants(String taskId) async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
      WITH RECURSIVE descendants AS (
        SELECT id FROM ${AppConstants.tasksTable}
        WHERE parent_id = ? AND deleted_at IS NULL

        UNION ALL

        SELECT t.id
        FROM ${AppConstants.tasksTable} t
        INNER JOIN descendants d ON t.parent_id = d.id
        WHERE t.deleted_at IS NULL
      )
      SELECT COUNT(*) as count FROM descendants
    ''', [taskId]);

    return (result.first['count'] as int?) ?? 0;
  }

  // Phase 3.2: Delete task and all its descendants
  // Returns count of deleted tasks
  Future<int> deleteTaskWithChildren(String taskId) async {
    final db = await _dbService.database;

    return await db.transaction((txn) async {
      // Get all descendant IDs using recursive query
      final descendants = await txn.rawQuery('''
        WITH RECURSIVE descendants AS (
          SELECT id FROM ${AppConstants.tasksTable}
          WHERE id = ?

          UNION ALL

          SELECT t.id
          FROM ${AppConstants.tasksTable} t
          INNER JOIN descendants d ON t.parent_id = d.id
        )
        SELECT id FROM descendants
      ''', [taskId]);

      final idsToDelete = descendants.map((row) => row['id'] as String).toList();

      // Delete all descendants
      if (idsToDelete.isNotEmpty) {
        await txn.delete(
          AppConstants.tasksTable,
          where: 'id IN (${List.filled(idsToDelete.length, '?').join(',')})',
          whereArgs: idsToDelete,
        );
      }

      return idsToDelete.length;
    });
  }

  // ============================================
  // PHASE 3.3: SOFT DELETE METHODS
  // ============================================

  /// Soft delete a task and all its descendants
  ///
  /// Sets deleted_at timestamp on the task and all children (CASCADE).
  /// Returns count of soft-deleted tasks.
  ///
  /// **Note:** Soft delete always cascades to preserve hierarchy integrity.
  /// To restore, use restoreTask() which also cascades.
  Future<int> softDeleteTask(String taskId) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.transaction((txn) async {
      // Get all descendant IDs using recursive query
      // Same query as deleteTaskWithChildren but UPDATE instead of DELETE
      final descendants = await txn.rawQuery('''
        WITH RECURSIVE descendants AS (
          SELECT id FROM ${AppConstants.tasksTable}
          WHERE id = ?

          UNION ALL

          SELECT t.id
          FROM ${AppConstants.tasksTable} t
          INNER JOIN descendants d ON t.parent_id = d.id
        )
        SELECT id FROM descendants
      ''', [taskId]);

      final idsToSoftDelete = descendants.map((row) => row['id'] as String).toList();

      // Set deleted_at timestamp for all descendants
      if (idsToSoftDelete.isNotEmpty) {
        await txn.update(
          AppConstants.tasksTable,
          {'deleted_at': now},
          where: 'id IN (${List.filled(idsToSoftDelete.length, '?').join(',')})',
          whereArgs: idsToSoftDelete,
        );
      }

      return idsToSoftDelete.length;
    });
  }

  /// Restore a soft-deleted task and all its descendants
  ///
  /// Sets deleted_at = NULL on the task and all children (CASCADE).
  /// Returns count of restored tasks.
  ///
  /// **Note:** Restore always cascades to maintain hierarchy integrity.
  Future<int> restoreTask(String taskId) async {
    final db = await _dbService.database;

    return await db.transaction((txn) async {
      // Get all descendant IDs using recursive query
      final descendants = await txn.rawQuery('''
        WITH RECURSIVE descendants AS (
          SELECT id FROM ${AppConstants.tasksTable}
          WHERE id = ?

          UNION ALL

          SELECT t.id
          FROM ${AppConstants.tasksTable} t
          INNER JOIN descendants d ON t.parent_id = d.id
        )
        SELECT id FROM descendants
      ''', [taskId]);

      final idsToRestore = descendants.map((row) => row['id'] as String).toList();

      // Clear deleted_at for all descendants
      if (idsToRestore.isNotEmpty) {
        await txn.update(
          AppConstants.tasksTable,
          {'deleted_at': null},
          where: 'id IN (${List.filled(idsToRestore.length, '?').join(',')})',
          whereArgs: idsToRestore,
        );
      }

      return idsToRestore.length;
    });
  }

  /// Permanently delete a soft-deleted task and all its descendants
  ///
  /// This is a HARD delete - task is removed from database permanently.
  /// Can only be called on already soft-deleted tasks.
  /// Returns count of permanently deleted tasks.
  ///
  /// **Warning:** This action cannot be undone!
  Future<int> permanentlyDeleteTask(String taskId) async {
    // Verify task is soft-deleted before allowing permanent delete
    final db = await _dbService.database;
    final task = await db.query(
      AppConstants.tasksTable,
      where: 'id = ? AND deleted_at IS NOT NULL',
      whereArgs: [taskId],
    );

    if (task.isEmpty) {
      throw StateError('Task is not soft-deleted or does not exist');
    }

    // Reuse existing hard delete logic (CASCADE via foreign key)
    return await deleteTaskWithChildren(taskId);
  }

  /// Get all recently deleted tasks
  ///
  /// Returns tasks where deleted_at IS NOT NULL, ordered by deleted_at DESC.
  /// Includes depth information for hierarchical display.
  Future<List<Task>> getRecentlyDeletedTasks() async {
    final db = await _dbService.database;

    // Get all deleted tasks with hierarchy information
    // Base case: Deleted tasks whose parent is NULL or not deleted (roots in deleted view)
    // Recursive case: Deleted children of deleted tasks
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      WITH RECURSIVE task_tree AS (
        -- Base case: Deleted tasks that are "roots" in the deleted task hierarchy
        -- (Either parent is NULL, or parent is NOT deleted)
        SELECT
          t.*,
          0 as depth,
          printf('%05d', t.position) as sort_key
        FROM ${AppConstants.tasksTable} t
        LEFT JOIN ${AppConstants.tasksTable} p ON t.parent_id = p.id
        WHERE t.deleted_at IS NOT NULL
          AND (t.parent_id IS NULL OR p.deleted_at IS NULL)

        UNION ALL

        -- Recursive case: Deleted children of deleted tasks
        SELECT
          t.*,
          tt.depth + 1 as depth,
          tt.sort_key || '.' || printf('%05d', t.position) as sort_key
        FROM ${AppConstants.tasksTable} t
        INNER JOIN task_tree tt ON t.parent_id = tt.id
        WHERE tt.depth < 3 AND t.deleted_at IS NOT NULL
      )
      SELECT * FROM task_tree
      ORDER BY deleted_at DESC
    ''');

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Count recently deleted tasks
  ///
  /// Returns total number of soft-deleted tasks (for badge display).
  Future<int> countRecentlyDeletedTasks() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tasksTable} WHERE deleted_at IS NOT NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Empty trash - permanently delete all soft-deleted tasks
  ///
  /// Hard deletes all tasks where deleted_at IS NOT NULL.
  /// Returns count of permanently deleted tasks.
  ///
  /// **Warning:** This action cannot be undone!
  Future<int> emptyTrash() async {
    final db = await _dbService.database;

    return await db.transaction((txn) async {
      // Get all soft-deleted task IDs
      final deleted = await txn.query(
        AppConstants.tasksTable,
        columns: ['id'],
        where: 'deleted_at IS NOT NULL',
      );

      final idsToDelete = deleted.map((row) => row['id'] as String).toList();

      if (idsToDelete.isEmpty) return 0;

      // Hard delete all soft-deleted tasks
      // Foreign key CASCADE will handle children automatically
      await txn.delete(
        AppConstants.tasksTable,
        where: 'id IN (${List.filled(idsToDelete.length, '?').join(',')})',
        whereArgs: idsToDelete,
      );

      return idsToDelete.length;
    });
  }

  /// Clean up tasks deleted more than 30 days ago
  ///
  /// Automatically called on app launch (Phase 3.3).
  /// Hard deletes tasks where deleted_at < (now - 30 days).
  /// Returns count of permanently deleted tasks.
  Future<int> cleanupExpiredDeletedTasks() async {
    final db = await _dbService.database;

    // Calculate cutoff timestamp (30 days ago)
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffTimestamp = cutoff.millisecondsSinceEpoch;

    return await db.transaction((txn) async {
      // Get all expired soft-deleted task IDs
      final expired = await txn.query(
        AppConstants.tasksTable,
        columns: ['id'],
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoffTimestamp],
      );

      final idsToDelete = expired.map((row) => row['id'] as String).toList();

      if (idsToDelete.isEmpty) return 0;

      // Hard delete all expired tasks
      // Foreign key CASCADE will handle children automatically
      await txn.delete(
        AppConstants.tasksTable,
        where: 'id IN (${List.filled(idsToDelete.length, '?').join(',')})',
        whereArgs: idsToDelete,
      );

      return idsToDelete.length;
    });
  }

  /// Cleanup old deleted tasks (automatic)
  ///
  /// Permanently deletes tasks that have been soft-deleted longer than [daysThreshold].
  /// Default threshold is 30 days.
  /// Returns count of cleaned up tasks.
  ///
  /// Intended to run on app launch (non-blocking, async).
  Future<int> cleanupOldDeletedTasks({int daysThreshold = 30}) async {
    final db = await _dbService.database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysThreshold))
        .millisecondsSinceEpoch;

    return await db.transaction((txn) async {
      // Get all old deleted task IDs
      final oldDeleted = await txn.query(
        AppConstants.tasksTable,
        columns: ['id'],
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoffTime],
      );

      final idsToDelete = oldDeleted.map((row) => row['id'] as String).toList();

      if (idsToDelete.isEmpty) return 0;

      // Hard delete old soft-deleted tasks
      await txn.delete(
        AppConstants.tasksTable,
        where: 'id IN (${List.filled(idsToDelete.length, '?').join(',')})',
        whereArgs: idsToDelete,
      );

      return idsToDelete.length;
    });
  }

  // Phase 3.2: Check if moving taskId under newParentId would create a cycle
  // Reference: docs/phase-03/group1.md:1665-1691
  Future<bool> _wouldCreateCycle(
    String taskId,
    String newParentId,
    Transaction txn,
  ) async {
    // Walk up from newParentId to root, checking if we hit taskId
    String? current = newParentId;

    while (current != null) {
      if (current == taskId) {
        return true;  // Cycle detected!
      }

      final parent = await txn.query(
        AppConstants.tasksTable,
        columns: ['parent_id'],
        where: 'id = ?',
        whereArgs: [current],
      );

      if (parent.isEmpty) break;
      current = parent.first['parent_id'] as String?;
    }

    return false;  // No cycle
  }

  // Phase 3.2: Reindex siblings under a parent to maintain sequential positions
  // Reference: docs/phase-03/group1.md:1693-1710
  // Phase 3.3: Excludes soft-deleted tasks from reindexing
  Future<void> _reindexSiblings(
    String? parentId,
    Transaction txn, {
    String? excludeTaskId,
  }) async {
    // Build where clause to optionally exclude a task
    // Phase 3.3: Always exclude deleted tasks
    String whereClause = parentId == null ? 'parent_id IS NULL AND deleted_at IS NULL' : 'parent_id = ? AND deleted_at IS NULL';
    List<dynamic>? whereArgs = parentId == null ? null : [parentId];

    if (excludeTaskId != null) {
      whereClause += ' AND id != ?';
      whereArgs = [...?whereArgs, excludeTaskId];
    }

    final siblings = await txn.query(
      AppConstants.tasksTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'position ASC',
    );

    for (int i = 0; i < siblings.length; i++) {
      await txn.update(
        AppConstants.tasksTable,
        {'position': i},
        where: 'id = ?',
        whereArgs: [siblings[i]['id']],
      );
    }
  }

  // Phase 3.2: Get depth of a task in the hierarchy
  // Returns 0 for root tasks, 1 for first-level children, etc.
  Future<int> _getTaskDepth(String? taskId, Transaction txn) async {
    if (taskId == null) return 0;  // Root level

    final result = await txn.rawQuery('''
      WITH RECURSIVE parent_chain AS (
        SELECT id, parent_id, 0 as depth
        FROM ${AppConstants.tasksTable}
        WHERE id = ?

        UNION ALL

        SELECT t.id, t.parent_id, pc.depth + 1
        FROM ${AppConstants.tasksTable} t
        INNER JOIN parent_chain pc ON t.id = pc.parent_id
      )
      SELECT MAX(depth) as max_depth FROM parent_chain
    ''', [taskId]);

    return (result.first['max_depth'] as int?) ?? 0;
  }

  // Helper: Generate unique ID using UUID v4
  // This prevents ID collisions during rapid/bulk task creation
  String _generateId() {
    return _uuid.v4();
  }
}
