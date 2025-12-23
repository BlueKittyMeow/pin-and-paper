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
    // Query max position where parent_id IS NULL
    final result = await db.rawQuery('''
      SELECT COALESCE(MAX(position), -1) as max_position
      FROM ${AppConstants.tasksTable}
      WHERE parent_id IS NULL
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
    final result = await db.rawQuery('''
      SELECT COALESCE(MAX(position), -1) as max_position
      FROM ${AppConstants.tasksTable}
      WHERE parent_id IS NULL
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
  Future<List<Task>> getAllTasks() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tasksTable,
      // Bug fix: DESC ordering - newest tasks (highest position) appear first
      // This matches TaskProvider.createTask() which inserts at index 0
      orderBy: 'position DESC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // Phase 3.2: Get all tasks with hierarchy information
  // Returns flat list ordered by parent_id and position
  // Uses recursive CTE to compute depth dynamically
  Future<List<Task>> getTaskHierarchy() async {
    final db = await _dbService.database;

    // Recursive CTE to get tasks with depth
    // Orders by: root position, then children under parents
    // Reference: docs/phase-03/group1.md:1508-1578
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      WITH RECURSIVE task_tree AS (
        -- Base case: root-level tasks (parent_id IS NULL)
        SELECT
          *,
          0 as depth,
          printf('%05d', position) as sort_key
        FROM ${AppConstants.tasksTable}
        WHERE parent_id IS NULL

        UNION ALL

        -- Recursive case: children of tasks
        SELECT
          t.*,
          tt.depth + 1 as depth,
          tt.sort_key || '.' || printf('%05d', t.position) as sort_key
        FROM ${AppConstants.tasksTable} t
        INNER JOIN task_tree tt ON t.parent_id = tt.id
        WHERE tt.depth < 3  -- Max 4 levels (0-indexed: 0, 1, 2, 3)
      )
      SELECT * FROM task_tree
      ORDER BY sort_key
    ''');

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // Phase 3.2: Get children of a specific task
  Future<List<Task>> getTaskWithChildren(String parentId) async {
    final db = await _dbService.database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tasksTable,
      where: 'parent_id = ?',
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
  Future<int> getIncompleteTaskCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tasksTable} WHERE completed = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Get count of completed tasks
  Future<int> getCompletedTaskCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tasksTable} WHERE completed = 1',
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

      // 4. Move task to new parent with new position
      await txn.update(
        AppConstants.tasksTable,
        {
          'parent_id': newParentId,
          'position': newPosition,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      // 5. Reindex siblings in SOURCE list (old parent)
      await _reindexSiblings(oldParentId, txn);

      // 6. Reindex siblings in DESTINATION list (new parent)
      await _reindexSiblings(newParentId, txn);

      return null;  // Success
    });
  }

  // Phase 3.2: Count descendants of a task (children only, excluding task itself)
  // Used for CASCADE delete confirmation dialogs
  Future<int> countDescendants(String taskId) async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
      WITH RECURSIVE descendants AS (
        SELECT id FROM ${AppConstants.tasksTable}
        WHERE parent_id = ?

        UNION ALL

        SELECT t.id
        FROM ${AppConstants.tasksTable} t
        INNER JOIN descendants d ON t.parent_id = d.id
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
  Future<void> _reindexSiblings(String? parentId, Transaction txn) async {
    final siblings = await txn.query(
      AppConstants.tasksTable,
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
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
