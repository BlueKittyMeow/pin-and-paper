import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/filter_state.dart'; // Phase 3.6A
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

  /// Get parent chain for a task (for breadcrumb generation)
  ///
  /// Phase 3.6B: Returns list of parent tasks from immediate parent up to root.
  /// Used for generating breadcrumb navigation in search results.
  ///
  /// Example: If task hierarchy is: Root > Parent > Child > Target
  /// This returns: [Child, Parent, Root] (immediate parent first)
  ///
  /// Returns empty list if task has no parent (is root-level task).
  /// Excludes soft-deleted tasks from the chain.
  Future<List<Task>> getParentChain(String taskId) async {
    final db = await _dbService.database;

    // Use recursive CTE to walk up the parent chain
    final maps = await db.rawQuery('''
      WITH RECURSIVE ancestors AS (
        SELECT id, parent_id, 0 as depth
        FROM ${AppConstants.tasksTable}
        WHERE id = ?

        UNION ALL

        SELECT t.id, t.parent_id, a.depth + 1
        FROM ${AppConstants.tasksTable} t
        INNER JOIN ancestors a ON t.id = a.parent_id
        WHERE t.deleted_at IS NULL
      )
      SELECT t.*
      FROM ${AppConstants.tasksTable} t
      INNER JOIN ancestors a ON t.id = a.id
      WHERE a.depth > 0
      ORDER BY a.depth ASC
    ''', [taskId]);

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Phase 3.6A: Get filtered tasks by tags and presence
  ///
  /// Returns tasks matching the filter criteria:
  /// - selectedTagIds with OR logic: tasks with ANY of the selected tags
  /// - selectedTagIds with AND logic: tasks with ALL of the selected tags
  /// - onlyTagged: tasks with at least one tag
  /// - onlyUntagged: tasks with no tags
  /// - No filter active: returns all tasks for the completed status
  ///
  /// Always filters by:
  /// - `completed` status (active vs completed)
  /// - Excludes soft-deleted tasks (deleted_at IS NULL)
  ///
  /// Returns tasks ordered by position.
  Future<List<Task>> getFilteredTasks(
    FilterState filter, {
    required bool completed,
  }) async {
    final db = await _dbService.database;

    // Base WHERE conditions (always apply)
    final baseConditions = [
      'tasks.deleted_at IS NULL',
      'tasks.completed = ?',
    ];
    final baseArgs = [completed ? 1 : 0];

    // Build query based on filter state
    String query;
    List<dynamic> args;

    if (filter.selectedTagIds.isNotEmpty) {
      // Specific tag filter
      if (filter.logic == FilterLogic.or) {
        // OR logic: tasks with ANY of the selected tags
        query = '''
          SELECT DISTINCT tasks.*
          FROM ${AppConstants.tasksTable} tasks
          INNER JOIN ${AppConstants.taskTagsTable} task_tags ON tasks.id = task_tags.task_id
          WHERE task_tags.tag_id IN (${List.filled(filter.selectedTagIds.length, '?').join(', ')})
            AND ${baseConditions.join(' AND ')}
          ORDER BY tasks.position DESC;
        ''';
        args = [...filter.selectedTagIds, ...baseArgs];
      } else {
        // AND logic: tasks with ALL of the selected tags
        query = '''
          SELECT tasks.*
          FROM ${AppConstants.tasksTable} tasks
          WHERE tasks.id IN (
            SELECT task_id
            FROM ${AppConstants.taskTagsTable}
            WHERE tag_id IN (${List.filled(filter.selectedTagIds.length, '?').join(', ')})
            GROUP BY task_id
            HAVING COUNT(DISTINCT tag_id) = ?
          )
            AND ${baseConditions.join(' AND ')}
          ORDER BY tasks.position DESC;
        ''';
        args = [...filter.selectedTagIds, filter.selectedTagIds.length, ...baseArgs];
      }
    } else if (filter.presenceFilter == TagPresenceFilter.onlyTagged) {
      // Show only tasks with at least one tag
      query = '''
        SELECT DISTINCT tasks.*
        FROM ${AppConstants.tasksTable} tasks
        INNER JOIN ${AppConstants.taskTagsTable} task_tags ON tasks.id = task_tags.task_id
        WHERE ${baseConditions.join(' AND ')}
        ORDER BY tasks.position DESC;
      ''';
      args = baseArgs;
    } else if (filter.presenceFilter == TagPresenceFilter.onlyUntagged) {
      // Show only tasks with no tags
      query = '''
        SELECT tasks.*
        FROM ${AppConstants.tasksTable} tasks
        WHERE tasks.id NOT IN (
          SELECT DISTINCT task_id
          FROM ${AppConstants.taskTagsTable}
        )
          AND ${baseConditions.join(' AND ')}
        ORDER BY tasks.position DESC;
      ''';
      args = baseArgs;
    } else {
      // No filter active - return all tasks for this completed status
      query = '''
        SELECT tasks.*
        FROM ${AppConstants.tasksTable} tasks
        WHERE ${baseConditions.join(' AND ')}
        ORDER BY tasks.position DESC;
      ''';
      args = baseArgs;
    }

    final maps = await db.rawQuery(query, args);
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Phase 3.6A: Count tasks matching filter (for UX preview)
  ///
  /// Similar to getFilteredTasks but returns count instead of full list.
  /// Used in TagFilterDialog to show "X tasks match" preview.
  ///
  /// Performance: Much faster than loading full list, typically <5ms
  Future<int> countFilteredTasks(
    FilterState filter, {
    required bool completed,
  }) async {
    final db = await _dbService.database;

    // Base WHERE conditions (always apply)
    final baseConditions = [
      'tasks.deleted_at IS NULL',
      'tasks.completed = ?',
    ];
    final baseArgs = [completed ? 1 : 0];

    // Build query based on filter state
    String query;
    List<dynamic> args;

    if (filter.selectedTagIds.isNotEmpty) {
      // Specific tag filter
      if (filter.logic == FilterLogic.or) {
        // OR logic: tasks with ANY of the selected tags
        query = '''
          SELECT COUNT(DISTINCT tasks.id) as count
          FROM ${AppConstants.tasksTable} tasks
          INNER JOIN ${AppConstants.taskTagsTable} task_tags ON tasks.id = task_tags.task_id
          WHERE task_tags.tag_id IN (${List.filled(filter.selectedTagIds.length, '?').join(', ')})
            AND ${baseConditions.join(' AND ')}
        ''';
        args = [...filter.selectedTagIds, ...baseArgs];
      } else {
        // AND logic: tasks with ALL of the selected tags
        query = '''
          SELECT COUNT(*) as count
          FROM ${AppConstants.tasksTable} tasks
          WHERE tasks.id IN (
            SELECT task_id
            FROM ${AppConstants.taskTagsTable}
            WHERE tag_id IN (${List.filled(filter.selectedTagIds.length, '?').join(', ')})
            GROUP BY task_id
            HAVING COUNT(DISTINCT tag_id) = ?
          )
            AND ${baseConditions.join(' AND ')}
        ''';
        args = [...filter.selectedTagIds, filter.selectedTagIds.length, ...baseArgs];
      }
    } else if (filter.presenceFilter == TagPresenceFilter.onlyTagged) {
      // Show only tasks with at least one tag
      query = '''
        SELECT COUNT(DISTINCT tasks.id) as count
        FROM ${AppConstants.tasksTable} tasks
        INNER JOIN ${AppConstants.taskTagsTable} task_tags ON tasks.id = task_tags.task_id
        WHERE ${baseConditions.join(' AND ')}
      ''';
      args = baseArgs;
    } else if (filter.presenceFilter == TagPresenceFilter.onlyUntagged) {
      // Show only tasks with no tags
      query = '''
        SELECT COUNT(*) as count
        FROM ${AppConstants.tasksTable} tasks
        WHERE tasks.id NOT IN (
          SELECT DISTINCT task_id
          FROM ${AppConstants.taskTagsTable}
        )
          AND ${baseConditions.join(' AND ')}
      ''';
      args = baseArgs;
    } else {
      // No filter active - return all tasks for this completed status
      query = '''
        SELECT COUNT(*) as count
        FROM ${AppConstants.tasksTable} tasks
        WHERE ${baseConditions.join(' AND ')}
      ''';
      args = baseArgs;
    }

    final result = await db.rawQuery(query, args);
    return result.first['count'] as int;
  }

  // Toggle task completion status
  // Phase 3.6.5: Now saves position before completion for restore capability
  Future<Task> toggleTaskCompletion(Task task) async {
    final db = await _dbService.database;

    if (!task.completed) {
      // Completing: Save current position for potential restore
      final updatedTask = task.copyWith(
        completed: true,
        completedAt: DateTime.now(),
        positionBeforeCompletion: task.position,
      );

      await db.update(
        AppConstants.tasksTable,
        updatedTask.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );

      return updatedTask;
    } else {
      // Uncompleting: Use restoreTaskToPosition for proper handling
      return await uncompleteTask(task.id);
    }
  }

  /// Phase 3.6.5: Uncomplete a task and restore its position
  ///
  /// Gemini #18: Moved position restore logic to TaskService for cleaner architecture
  ///
  /// Steps:
  /// 1. Get task and its saved position
  /// 2. Shift siblings at >= target position up by 1
  /// 3. Restore task to its original position
  /// 4. Clear position_before_completion
  Future<Task> uncompleteTask(String taskId) async {
    final db = await _dbService.database;

    return await db.transaction((txn) async {
      // 1. Get the task
      final taskMaps = await txn.query(
        AppConstants.tasksTable,
        where: 'id = ?',
        whereArgs: [taskId],
      );

      if (taskMaps.isEmpty) {
        throw Exception('Task not found: $taskId');
      }

      final task = Task.fromMap(taskMaps.first);

      // Determine target position
      final targetPosition = task.positionBeforeCompletion ?? task.position;
      final parentId = task.parentId;

      // 2. Shift siblings at >= target position up by 1 to make room
      await txn.rawUpdate('''
        UPDATE ${AppConstants.tasksTable}
        SET position = position + 1
        WHERE ${parentId == null ? 'parent_id IS NULL' : 'parent_id = ?'}
          AND position >= ?
          AND completed = 0
          AND deleted_at IS NULL
          AND id != ?
      ''', parentId == null
          ? [targetPosition, taskId]
          : [parentId, targetPosition, taskId]);

      // 3. Update task: uncomplete and restore position
      await txn.update(
        AppConstants.tasksTable,
        {
          'completed': 0,
          'completed_at': null,
          'position': targetPosition,
          'position_before_completion': null, // Clear saved position
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      // 4. Return updated task
      return task.copyWith(
        completed: false,
        completedAt: null,
        position: targetPosition,
        positionBeforeCompletion: null,
      );
    });
  }

  /// Phase 3.6.5: Comprehensive task update
  ///
  /// Updates multiple task fields at once:
  /// - title (required)
  /// - dueDate (optional)
  /// - notes (optional)
  ///
  /// NOTE: Parent changes are handled separately via updateTaskParent()
  /// to maintain proper hierarchy validation and position handling.
  ///
  /// Returns the updated Task object
  /// Throws [ArgumentError] if title is empty or whitespace-only
  /// Throws [Exception] if task not found
  Future<Task> updateTask(
    String taskId, {
    required String title,
    DateTime? dueDate,
    bool isAllDay = true,
    String? notes,
  }) async {
    final db = await _dbService.database;
    final trimmedTitle = title.trim();

    // Validate title
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Task title cannot be empty');
    }

    // Fetch the original task first to have all its data
    final maps = await db.query(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
    );

    if (maps.isEmpty) {
      throw Exception('Task not found: $taskId');
    }

    final originalTask = Task.fromMap(maps.first);

    // Perform the update
    await db.update(
      AppConstants.tasksTable,
      {
        'title': trimmedTitle,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'is_all_day': isAllDay ? 1 : 0,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // Return updated copy
    return originalTask.copyWith(
      title: trimmedTitle,
      dueDate: dueDate,
      isAllDay: isAllDay,
      notes: notes,
    );
  }

  // Phase 3.4: Update task title
  /// Updates the title of an existing task
  /// Returns the updated Task object
  ///
  /// Throws [ArgumentError] if title is empty or whitespace-only
  /// Throws [Exception] if task not found
  ///
  /// OPTIMIZED: Fetch-first approach to avoid redundant query (Gemini feedback)
  Future<Task> updateTaskTitle(String taskId, String newTitle) async {
    final db = await _dbService.database;
    final trimmedTitle = newTitle.trim();

    // Validate title
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Task title cannot be empty');
    }

    // Fetch the original task first to have all its data
    final maps = await db.query(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
    );

    if (maps.isEmpty) {
      throw Exception('Task not found: $taskId');
    }

    final originalTask = Task.fromMap(maps.first);

    // Perform the update
    await db.update(
      AppConstants.tasksTable,
      {'title': trimmedTitle},
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // Return updated copy (leverages existing copyWith method)
    return originalTask.copyWith(title: trimmedTitle);
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
      // CRITICAL: Get all ANCESTORS (parents up to root) first
      // This ensures the entire path from root to this task is visible
      final ancestors = await txn.rawQuery('''
        WITH RECURSIVE ancestors AS (
          SELECT id, parent_id FROM ${AppConstants.tasksTable}
          WHERE id = ?

          UNION ALL

          SELECT t.id, t.parent_id
          FROM ${AppConstants.tasksTable} t
          INNER JOIN ancestors a ON t.id = a.parent_id
        )
        SELECT id FROM ancestors
      ''', [taskId]);

      // Get all DESCENDANTS (children down)
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

      // Combine ancestors + descendants (using Set to avoid duplicates)
      final ancestorIds = ancestors.map((row) => row['id'] as String).toSet();
      final descendantIds = descendants.map((row) => row['id'] as String).toSet();
      final idsToRestore = {...ancestorIds, ...descendantIds}.toList();

      // Clear deleted_at for entire tree path (ancestors + self + descendants)
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

  /// Count how many deleted ancestors (parents) will also be restored
  /// Used for restore confirmation dialog
  Future<int> countDeletedAncestors(String taskId) async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
      WITH RECURSIVE ancestors AS (
        SELECT id, parent_id FROM ${AppConstants.tasksTable}
        WHERE id = ?

        UNION ALL

        SELECT t.id, t.parent_id
        FROM ${AppConstants.tasksTable} t
        INNER JOIN ancestors a ON t.id = a.parent_id
        WHERE t.deleted_at IS NOT NULL
      )
      SELECT COUNT(*) - 1 as count FROM ancestors
    ''', [taskId]);

    return (result.first['count'] as int?) ?? 0;
  }

  /// Count how many deleted descendants (children) will also be restored
  /// Used for restore confirmation dialog
  Future<int> countDeletedDescendants(String taskId) async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
      WITH RECURSIVE descendants AS (
        SELECT id FROM ${AppConstants.tasksTable}
        WHERE parent_id = ?

        UNION ALL

        SELECT t.id
        FROM ${AppConstants.tasksTable} t
        INNER JOIN descendants d ON t.parent_id = d.id
        WHERE t.deleted_at IS NOT NULL
      )
      SELECT COUNT(*) as count FROM descendants
    ''', [taskId]);

    return (result.first['count'] as int?) ?? 0;
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
