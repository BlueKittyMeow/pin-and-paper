import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart';

void main() {
  group('Task Model - Phase 3 Fields', () {
    final now = DateTime(2025, 10, 30, 10, 30);
    final dueDate = DateTime(2025, 10, 31, 15, 0);
    final startDate = DateTime(2025, 10, 29, 9, 0);
    final notificationTime = DateTime(2025, 10, 31, 14, 0);

    test('toMap includes all Phase 3 fields', () {
      final task = Task(
        id: 'task-1',
        title: 'Test task with all fields',
        createdAt: now,
        completed: false,
        parentId: 'parent-1',
        position: 5,
        depth: 2,
        isTemplate: true,
        dueDate: dueDate,
        isAllDay: false,
        startDate: startDate,
        notificationType: 'custom',
        notificationTime: notificationTime,
      );

      final map = task.toMap();

      expect(map['id'], 'task-1');
      expect(map['title'], 'Test task with all fields');
      expect(map['completed'], 0);
      expect(map['created_at'], now.millisecondsSinceEpoch);
      expect(map['parent_id'], 'parent-1');
      expect(map['position'], 5);
      // depth should NOT be in the map (computed field)
      expect(map.containsKey('depth'), false);
      expect(map['is_template'], 1);
      expect(map['due_date'], dueDate.millisecondsSinceEpoch);
      expect(map['is_all_day'], 0);
      expect(map['start_date'], startDate.millisecondsSinceEpoch);
      expect(map['notification_type'], 'custom');
      expect(map['notification_time'], notificationTime.millisecondsSinceEpoch);
    });

    test('toMap excludes depth field (computed field)', () {
      final task = Task(
        id: 'task-1',
        title: 'Task with depth',
        createdAt: now,
        depth: 3, // This should NOT be persisted
      );

      final map = task.toMap();

      expect(map.containsKey('depth'), false,
          reason: 'depth is a computed field and should not be persisted');
    });

    test('fromMap deserializes all Phase 3 fields correctly', () {
      final map = {
        'id': 'task-2',
        'title': 'Test task from map',
        'completed': 1,
        'created_at': now.millisecondsSinceEpoch,
        'completed_at': now.millisecondsSinceEpoch,
        'parent_id': 'parent-2',
        'position': 3,
        'depth': 1,
        'is_template': 1,
        'due_date': dueDate.millisecondsSinceEpoch,
        'is_all_day': 0,
        'start_date': startDate.millisecondsSinceEpoch,
        'notification_type': 'custom',
        'notification_time': notificationTime.millisecondsSinceEpoch,
      };

      final task = Task.fromMap(map);

      expect(task.id, 'task-2');
      expect(task.title, 'Test task from map');
      expect(task.completed, true);
      expect(task.createdAt, now);
      expect(task.completedAt, now);
      expect(task.parentId, 'parent-2');
      expect(task.position, 3);
      expect(task.depth, 1);
      expect(task.isTemplate, true);
      expect(task.dueDate, dueDate);
      expect(task.isAllDay, false);
      expect(task.startDate, startDate);
      expect(task.notificationType, 'custom');
      expect(task.notificationTime, notificationTime);
    });

    test('fromMap handles NULL values (backward compatibility)', () {
      // Simulate a task from the Phase 2 database (no Phase 3 fields)
      final map = {
        'id': 'old-task',
        'title': 'Old task without Phase 3 fields',
        'completed': 0,
        'created_at': now.millisecondsSinceEpoch,
        'completed_at': null,
        // All Phase 3 fields are missing
      };

      final task = Task.fromMap(map);

      // Should use defaults
      expect(task.parentId, null);
      expect(task.position, 0);
      expect(task.depth, 0);
      expect(task.isTemplate, false);
      expect(task.dueDate, null);
      expect(task.isAllDay, true); // Default to all-day
      expect(task.startDate, null);
      expect(task.notificationType, 'use_global');
      expect(task.notificationTime, null);
    });

    test('fromMap handles is_all_day NULL as true', () {
      final map = {
        'id': 'task-3',
        'title': 'Task with NULL is_all_day',
        'completed': 0,
        'created_at': now.millisecondsSinceEpoch,
        'is_all_day': null, // NULL should default to true
      };

      final task = Task.fromMap(map);

      expect(task.isAllDay, true);
    });

    test('fromMap handles is_all_day = 0 as false', () {
      final map = {
        'id': 'task-4',
        'title': 'Task with is_all_day = 0',
        'completed': 0,
        'created_at': now.millisecondsSinceEpoch,
        'is_all_day': 0,
      };

      final task = Task.fromMap(map);

      expect(task.isAllDay, false);
    });

    test('copyWith updates Phase 3 fields correctly', () {
      final original = Task(
        id: 'task-5',
        title: 'Original task',
        createdAt: now,
        parentId: 'parent-1',
        position: 0,
        depth: 0,
        isTemplate: false,
        dueDate: null,
        isAllDay: true,
        notificationType: 'use_global',
      );

      final updated = original.copyWith(
        parentId: 'parent-2',
        position: 5,
        depth: 1,
        isTemplate: true,
        dueDate: dueDate,
        isAllDay: false,
        startDate: startDate,
        notificationType: 'custom',
        notificationTime: notificationTime,
      );

      // Original should be unchanged
      expect(original.parentId, 'parent-1');
      expect(original.position, 0);

      // Updated should have new values
      expect(updated.id, 'task-5'); // Unchanged
      expect(updated.title, 'Original task'); // Unchanged
      expect(updated.parentId, 'parent-2');
      expect(updated.position, 5);
      expect(updated.depth, 1);
      expect(updated.isTemplate, true);
      expect(updated.dueDate, dueDate);
      expect(updated.isAllDay, false);
      expect(updated.startDate, startDate);
      expect(updated.notificationType, 'custom');
      expect(updated.notificationTime, notificationTime);
    });

    test('copyWith preserves fields when not specified', () {
      final original = Task(
        id: 'task-6',
        title: 'Task with all fields',
        createdAt: now,
        parentId: 'parent-1',
        position: 3,
        depth: 2,
        isTemplate: true,
        dueDate: dueDate,
        isAllDay: false,
        startDate: startDate,
        notificationType: 'custom',
        notificationTime: notificationTime,
      );

      // Only update position
      final updated = original.copyWith(position: 10);

      // All other fields should be preserved
      expect(updated.id, 'task-6');
      expect(updated.title, 'Task with all fields');
      expect(updated.parentId, 'parent-1');
      expect(updated.position, 10); // Changed
      expect(updated.depth, 2);
      expect(updated.isTemplate, true);
      expect(updated.dueDate, dueDate);
      expect(updated.isAllDay, false);
      expect(updated.startDate, startDate);
      expect(updated.notificationType, 'custom');
      expect(updated.notificationTime, notificationTime);
    });

    test('Round-trip serialization preserves all data', () {
      final original = Task(
        id: 'task-7',
        title: 'Round-trip test',
        createdAt: now,
        completed: true,
        completedAt: now,
        parentId: 'parent-3',
        position: 7,
        depth: 3,
        isTemplate: true,
        dueDate: dueDate,
        isAllDay: false,
        startDate: startDate,
        notificationType: 'none',
        notificationTime: notificationTime,
      );

      final map = original.toMap();
      final deserialized = Task.fromMap(map);

      expect(deserialized.id, original.id);
      expect(deserialized.title, original.title);
      expect(deserialized.completed, original.completed);
      expect(deserialized.createdAt, original.createdAt);
      expect(deserialized.completedAt, original.completedAt);
      expect(deserialized.parentId, original.parentId);
      expect(deserialized.position, original.position);
      // NOTE: depth is NOT serialized, so it won't match
      expect(deserialized.depth, 0); // Default value
      expect(deserialized.isTemplate, original.isTemplate);
      expect(deserialized.dueDate, original.dueDate);
      expect(deserialized.isAllDay, original.isAllDay);
      expect(deserialized.startDate, original.startDate);
      expect(deserialized.notificationType, original.notificationType);
      expect(deserialized.notificationTime, original.notificationTime);
    });

    test('Top-level task has NULL parentId', () {
      final task = Task(
        id: 'top-level',
        title: 'Top-level task',
        createdAt: now,
        parentId: null,
        position: 0,
      );

      final map = task.toMap();
      expect(map['parent_id'], null);

      final deserialized = Task.fromMap(map);
      expect(deserialized.parentId, null);
    });

    test('Nested task has non-NULL parentId', () {
      final task = Task(
        id: 'child-task',
        title: 'Child task',
        createdAt: now,
        parentId: 'parent-task',
        position: 2,
        depth: 1,
      );

      final map = task.toMap();
      expect(map['parent_id'], 'parent-task');

      final deserialized = Task.fromMap(map);
      expect(deserialized.parentId, 'parent-task');
    });
  });
}
