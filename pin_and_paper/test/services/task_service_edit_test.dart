import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import '../helpers/test_database_helper.dart';

/// Phase 3.4: Unit tests for task title editing
/// Tests the updateTaskTitle() method with various edge cases
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late TaskService taskService;
  late Database testDb;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    taskService = TaskService();
  });

  // tearDown removed - TestDatabaseHelper.createTestDatabase() handles cleanup
  // Double-close was causing "database is locked" errors (Gemini Issue #1)

  group('TaskService - updateTaskTitle()', () {
    test('updates task title successfully', () async {
      // Arrange
      final task = await taskService.createTask('Original Title');

      // Act
      final updated = await taskService.updateTaskTitle(task.id, 'New Title');

      // Assert
      expect(updated.title, 'New Title');
      expect(updated.id, task.id);

      // Verify persistence
      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);
      expect(found.title, 'New Title');
    });

    test('rejects empty title', () async {
      // Arrange
      final task = await taskService.createTask('Original');

      // Act & Assert
      expect(
        () => taskService.updateTaskTitle(task.id, ''),
        throwsA(isA<ArgumentError>()),
      );

      // Verify title unchanged
      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);
      expect(found.title, 'Original');
    });

    test('rejects whitespace-only title', () async {
      // Arrange
      final task = await taskService.createTask('Original');

      // Act & Assert
      expect(
        () => taskService.updateTaskTitle(task.id, '   '),
        throwsA(isA<ArgumentError>()),
      );

      // Verify title unchanged
      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);
      expect(found.title, 'Original');
    });

    test('throws on non-existent task', () async {
      // Act & Assert
      expect(
        () => taskService.updateTaskTitle('non-existent-uuid', 'New Title'),
        throwsA(isA<Exception>()),
      );
    });

    test('trims whitespace from title', () async {
      // Arrange
      final task = await taskService.createTask('Original');

      // Act
      final updated = await taskService.updateTaskTitle(task.id, '  Trimmed  ');

      // Assert
      expect(updated.title, 'Trimmed');

      // Verify persistence
      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);
      expect(found.title, 'Trimmed');
    });

    test('handles special characters', () async {
      // Arrange
      final task = await taskService.createTask('Original');

      // Act
      final updated = await taskService.updateTaskTitle(
        task.id,
        'Task with emoji 🎉 and unicode ✓',
      );

      // Assert
      expect(updated.title, 'Task with emoji 🎉 and unicode ✓');

      // Verify persistence
      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);
      expect(found.title, 'Task with emoji 🎉 and unicode ✓');
    });

    test('handles long titles', () async {
      // Arrange
      final task = await taskService.createTask('Original');
      final longTitle = 'A' * 500; // 500 characters

      // Act
      final updated = await taskService.updateTaskTitle(task.id, longTitle);

      // Assert
      expect(updated.title, longTitle);
      expect(updated.title.length, 500);

      // Verify persistence
      final tasks = await taskService.getAllTasks();
      final found = tasks.firstWhere((t) => t.id == task.id);
      expect(found.title.length, 500);
    });

    test('preserves other task fields (parent, position, completed)', () async {
      // Arrange
      final parent = await taskService.createTask('Parent');
      final child = await taskService.createTask('Child');
      final parentResult = await taskService.updateTaskParent(child.id, parent.id, 0);

      // Verify parent update succeeded (returns null on success)
      expect(parentResult, isNull, reason: 'Parent update should succeed');

      // Fetch the updated child from database (important! toggleTaskCompletion writes all fields)
      final tasks = await taskService.getAllTasks();
      final childAfterParent = tasks.firstWhere((t) => t.id == child.id);

      // Mark child as completed (using the fresh object from database)
      final completedChild = await taskService.toggleTaskCompletion(childAfterParent);
      expect(completedChild.completed, true);
      expect(completedChild.parentId, parent.id);

      // Act
      final updated = await taskService.updateTaskTitle(child.id, 'Updated Child');

      // Assert - verify the returned object has correct fields
      expect(updated.title, 'Updated Child');
      expect(updated.parentId, parent.id, reason: 'Parent ID should be preserved');
      expect(updated.position, 0, reason: 'Position should be preserved');
      expect(updated.completed, true, reason: 'Completed status should be preserved');
    });

    test('returns updated Task object with copyWith()', () async {
      // Arrange
      final task = await taskService.createTask('Original');

      // Act
      final updated = await taskService.updateTaskTitle(task.id, 'New');

      // Assert - verify it's a new object (not mutated original)
      expect(updated.title, 'New');
      expect(updated.id, task.id);
      // Compare milliseconds only (SQLite stores milliseconds, Dart has microseconds)
      expect(updated.createdAt.millisecondsSinceEpoch, task.createdAt.millisecondsSinceEpoch);
      expect(updated.completed, task.completed);

      // Verify updated is a different instance (copyWith creates new object)
      expect(identical(task, updated), false);
    });

    test('does not affect deleted tasks (soft delete isolation)', () async {
      // Arrange
      final activeTask = await taskService.createTask('Active Task');
      final deletedTask = await taskService.createTask('Deleted Task');
      await taskService.softDeleteTask(deletedTask.id);

      // Act - update the active task
      await taskService.updateTaskTitle(activeTask.id, 'Updated Active');

      // Assert - deleted task remains deleted and unchanged
      final recentlyDeleted = await taskService.getRecentlyDeletedTasks();
      final deletedFound = recentlyDeleted.firstWhere((t) => t.id == deletedTask.id);
      expect(deletedFound.title, 'Deleted Task');
      expect(deletedFound.deletedAt, isNotNull);

      // Active task updated correctly
      final activeTasks = await taskService.getAllTasks();
      final activeFound = activeTasks.firstWhere((t) => t.id == activeTask.id);
      expect(activeFound.title, 'Updated Active');
    });
  });
}
