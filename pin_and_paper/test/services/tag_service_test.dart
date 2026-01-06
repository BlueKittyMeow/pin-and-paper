import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/test_database_helper.dart';

void main() {
  group('TagService', () {
    setUpAll(() {
      TestDatabaseHelper.initialize();
    });

    late TagService tagService;
    late TaskService taskService;
    late Database testDb;

    setUp(() async {
      // Create fresh database for each test
      testDb = await TestDatabaseHelper.createTestDatabase();
      DatabaseService.setTestDatabase(testDb);

      // Clear all data from previous tests
      await TestDatabaseHelper.clearAllData(testDb);
      tagService = TagService();
      taskService = TaskService();
    });

    // tearDownAll removed - TestDatabaseHelper.createTestDatabase() handles cleanup
    // Double-close was causing "database is locked" errors (Gemini Issue #1)

    group('createTag', () {
      test('creates tag with name only', () async {
        final tag = await tagService.createTag('work');

        expect(tag.id, isNotEmpty);
        expect(tag.name, equals('work'));
        expect(tag.color, isNull);
        expect(tag.createdAt, isA<DateTime>());
        expect(tag.deletedAt, isNull);
      });

      test('creates tag with name and color', () async {
        final tag = await tagService.createTag('urgent', color: '#FF5722');

        expect(tag.id, isNotEmpty);
        expect(tag.name, equals('urgent'));
        expect(tag.color, equals('#FF5722'));
      });

      test('trims whitespace from name', () async {
        final tag = await tagService.createTag('  work  ');

        expect(tag.name, equals('work'));
      });

      test('throws on empty name', () async {
        expect(
          () => tagService.createTag(''),
          throwsArgumentError,
        );
      });

      test('throws on whitespace-only name', () async {
        expect(
          () => tagService.createTag('   '),
          throwsArgumentError,
        );
      });

      test('throws on invalid color format', () async {
        expect(
          () => tagService.createTag('work', color: 'invalid'),
          throwsArgumentError,
        );
      });

      test('throws on duplicate name (case-insensitive)', () async {
        await tagService.createTag('work');

        // Attempt to create with same name (different case)
        expect(
          () => tagService.createTag('Work'),
          throwsA(isA<Exception>()), // Database UNIQUE constraint violation
        );
      });
    });

    group('getAllTags', () {
      test('returns empty list when no tags exist', () async {
        final tags = await tagService.getAllTags();

        expect(tags, isEmpty);
      });

      test('returns all active tags', () async {
        await tagService.createTag('work');
        await tagService.createTag('urgent');
        await tagService.createTag('personal');

        final tags = await tagService.getAllTags();

        expect(tags.length, equals(3));
        expect(tags.map((t) => t.name), containsAll(['work', 'urgent', 'personal']));
      });

      test('returns tags ordered by name alphabetically', () async {
        await tagService.createTag('zebra');
        await tagService.createTag('apple');
        await tagService.createTag('monkey');

        final tags = await tagService.getAllTags();

        expect(tags[0].name, equals('apple'));
        expect(tags[1].name, equals('monkey'));
        expect(tags[2].name, equals('zebra'));
      });
    });

    group('getTagById', () {
      test('returns tag when found', () async {
        final created = await tagService.createTag('work', color: '#FF5722');

        final found = await tagService.getTagById(created.id);

        expect(found, isNotNull);
        expect(found!.id, equals(created.id));
        expect(found.name, equals('work'));
        expect(found.color, equals('#FF5722'));
      });

      test('returns null when tag not found', () async {
        final found = await tagService.getTagById('nonexistent-id');

        expect(found, isNull);
      });
    });

    group('getTagByName', () {
      test('returns tag when found (exact match)', () async {
        await tagService.createTag('work', color: '#FF5722');

        final found = await tagService.getTagByName('work');

        expect(found, isNotNull);
        expect(found!.name, equals('work'));
        expect(found.color, equals('#FF5722'));
      });

      test('returns tag with case-insensitive match', () async {
        await tagService.createTag('work');

        final found1 = await tagService.getTagByName('Work');
        final found2 = await tagService.getTagByName('WORK');
        final found3 = await tagService.getTagByName('WoRk');

        expect(found1, isNotNull);
        expect(found2, isNotNull);
        expect(found3, isNotNull);
        expect(found1!.name, equals('work'));
      });

      test('trims whitespace before search', () async {
        await tagService.createTag('work');

        final found = await tagService.getTagByName('  work  ');

        expect(found, isNotNull);
        expect(found!.name, equals('work'));
      });

      test('returns null when tag not found', () async {
        final found = await tagService.getTagByName('nonexistent');

        expect(found, isNull);
      });
    });

    group('addTagToTask', () {
      test('adds tag to task successfully', () async {
        final task = await taskService.createTask('Test task');
        final tag = await tagService.createTag('work');

        await tagService.addTagToTask(task.id, tag.id);

        final tags = await tagService.getTagsForTask(task.id);
        expect(tags.length, equals(1));
        expect(tags.first.id, equals(tag.id));
      });

      test('is idempotent (adding same tag twice does nothing)', () async {
        final task = await taskService.createTask('Test task');
        final tag = await tagService.createTag('work');

        await tagService.addTagToTask(task.id, tag.id);
        await tagService.addTagToTask(task.id, tag.id); // Add again

        final tags = await tagService.getTagsForTask(task.id);
        expect(tags.length, equals(1)); // Still only one
      });

      test('allows multiple tags on same task', () async {
        final task = await taskService.createTask('Test task');
        final tag1 = await tagService.createTag('work');
        final tag2 = await tagService.createTag('urgent');

        await tagService.addTagToTask(task.id, tag1.id);
        await tagService.addTagToTask(task.id, tag2.id);

        final tags = await tagService.getTagsForTask(task.id);
        expect(tags.length, equals(2));
      });
    });

    group('removeTagFromTask', () {
      test('removes tag from task successfully', () async {
        final task = await taskService.createTask('Test task');
        final tag = await tagService.createTag('work');
        await tagService.addTagToTask(task.id, tag.id);

        final removed = await tagService.removeTagFromTask(task.id, tag.id);

        expect(removed, isTrue);
        final tags = await tagService.getTagsForTask(task.id);
        expect(tags, isEmpty);
      });

      test('returns false when association does not exist', () async {
        final task = await taskService.createTask('Test task');
        final tag = await tagService.createTag('work');

        final removed = await tagService.removeTagFromTask(task.id, tag.id);

        expect(removed, isFalse);
      });

      test('removes tag from one task without affecting others', () async {
        final task1 = await taskService.createTask('Task 1');
        final task2 = await taskService.createTask('Task 2');
        final tag = await tagService.createTag('work');

        await tagService.addTagToTask(task1.id, tag.id);
        await tagService.addTagToTask(task2.id, tag.id);

        // Remove from task1 only
        await tagService.removeTagFromTask(task1.id, tag.id);

        final tags1 = await tagService.getTagsForTask(task1.id);
        final tags2 = await tagService.getTagsForTask(task2.id);

        expect(tags1, isEmpty);
        expect(tags2.length, equals(1)); // Still has tag
      });
    });

    group('getTagsForTask', () {
      test('returns empty list when task has no tags', () async {
        final task = await taskService.createTask('Test task');

        final tags = await tagService.getTagsForTask(task.id);

        expect(tags, isEmpty);
      });

      test('returns all tags for task', () async {
        final task = await taskService.createTask('Test task');
        final tag1 = await tagService.createTag('work');
        final tag2 = await tagService.createTag('urgent');
        final tag3 = await tagService.createTag('personal');

        await tagService.addTagToTask(task.id, tag1.id);
        await tagService.addTagToTask(task.id, tag2.id);
        await tagService.addTagToTask(task.id, tag3.id);

        final tags = await tagService.getTagsForTask(task.id);

        expect(tags.length, equals(3));
        expect(tags.map((t) => t.name), containsAll(['work', 'urgent', 'personal']));
      });

      test('returns tags ordered by name alphabetically', () async {
        final task = await taskService.createTask('Test task');
        final tag1 = await tagService.createTag('zebra');
        final tag2 = await tagService.createTag('apple');
        final tag3 = await tagService.createTag('monkey');

        await tagService.addTagToTask(task.id, tag1.id);
        await tagService.addTagToTask(task.id, tag2.id);
        await tagService.addTagToTask(task.id, tag3.id);

        final tags = await tagService.getTagsForTask(task.id);

        expect(tags[0].name, equals('apple'));
        expect(tags[1].name, equals('monkey'));
        expect(tags[2].name, equals('zebra'));
      });
    });

    group('getTagsForAllTasks', () {
      test('returns empty map when taskIds list is empty', () async {
        final result = await tagService.getTagsForAllTasks([]);

        expect(result, isEmpty);
      });

      test('returns empty map when no tasks have tags', () async {
        final task1 = await taskService.createTask('Task 1');
        final task2 = await taskService.createTask('Task 2');

        final result = await tagService.getTagsForAllTasks([task1.id, task2.id]);

        expect(result, isEmpty);
      });

      test('loads tags for multiple tasks in single query', () async {
        final task1 = await taskService.createTask('Task 1');
        final task2 = await taskService.createTask('Task 2');
        final task3 = await taskService.createTask('Task 3');

        final tag1 = await tagService.createTag('work');
        final tag2 = await tagService.createTag('urgent');

        await tagService.addTagToTask(task1.id, tag1.id);
        await tagService.addTagToTask(task2.id, tag1.id);
        await tagService.addTagToTask(task2.id, tag2.id);
        await tagService.addTagToTask(task3.id, tag2.id);

        final result = await tagService.getTagsForAllTasks([
          task1.id,
          task2.id,
          task3.id,
        ]);

        // Task 1: [work]
        expect(result[task1.id]?.length, equals(1));
        expect(result[task1.id]?.first.name, equals('work'));

        // Task 2: [urgent, work] (ordered alphabetically)
        expect(result[task2.id]?.length, equals(2));
        expect(result[task2.id]?[0].name, equals('urgent')); // 'urgent' comes before 'work'
        expect(result[task2.id]?[1].name, equals('work'));

        // Task 3: [urgent]
        expect(result[task3.id]?.length, equals(1));
        expect(result[task3.id]?.first.name, equals('urgent'));
      });

      test('handles tasks with no tags gracefully', () async {
        final task1 = await taskService.createTask('Task with tag');
        final task2 = await taskService.createTask('Task without tag');

        final tag = await tagService.createTag('work');
        await tagService.addTagToTask(task1.id, tag.id);

        final result = await tagService.getTagsForAllTasks([task1.id, task2.id]);

        expect(result[task1.id]?.length, equals(1));
        expect(result[task2.id], isNull); // Task 2 not in map (no tags)
      });

      test('handles large number of tasks efficiently', () async {
        // Test with 100 tasks to ensure performance
        final tasks = <Task>[];
        for (int i = 0; i < 100; i++) {
          tasks.add(await taskService.createTask('Task $i'));
        }

        final tag = await tagService.createTag('test');

        // Add tag to every other task
        for (int i = 0; i < 100; i += 2) {
          await tagService.addTagToTask(tasks[i].id, tag.id);
        }

        final taskIds = tasks.map((t) => t.id).toList();
        final result = await tagService.getTagsForAllTasks(taskIds);

        // Should have 50 tasks with tags
        expect(result.length, equals(50));
      });

      test('handles >900 tasks with automatic batching (SQLite limit)', () async {
        // Test with 1000 tasks to verify batching works
        // SQLite has ~999 parameter limit, batching at 900
        final tasks = <Task>[];
        for (int i = 0; i < 1000; i++) {
          tasks.add(await taskService.createTask('Task $i'));
        }

        final tag1 = await tagService.createTag('batch-test');
        final tag2 = await tagService.createTag('priority');

        // Add tag1 to first 500 tasks
        for (int i = 0; i < 500; i++) {
          await tagService.addTagToTask(tasks[i].id, tag1.id);
        }

        // Add tag2 to last 300 tasks
        for (int i = 700; i < 1000; i++) {
          await tagService.addTagToTask(tasks[i].id, tag2.id);
        }

        // Load all 1000 tasks (should trigger batching: 900 + 100)
        final taskIds = tasks.map((t) => t.id).toList();
        final result = await tagService.getTagsForAllTasks(taskIds);

        // Verify correct results
        expect(result.length, equals(800)); // 500 with tag1 + 300 with tag2
        expect(result[tasks[0].id]?.length, equals(1)); // First task has tag1
        expect(result[tasks[0].id]?.first.name, equals('batch-test'));
        expect(result[tasks[800].id]?.length, equals(1)); // Task 800 has tag2
        expect(result[tasks[800].id]?.first.name, equals('priority'));
        expect(result[tasks[600].id], isNull); // Task 600 has no tags
      });
    });
  });
}
