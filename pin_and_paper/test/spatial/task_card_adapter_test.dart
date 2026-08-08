import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/tag.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';
import 'package:pin_and_paper/spatial/task_card_adapter.dart';
import 'package:pin_and_paper/utils/tag_colors.dart';

Task _task({
  String id = 't1',
  String title = 'Title',
  bool completed = false,
  DateTime? dueDate,
  bool isAllDay = true,
  String? notes,
  DateTime? createdAt,
}) {
  return Task(
    id: id,
    title: title,
    completed: completed,
    createdAt: createdAt ?? DateTime(2026, 1, 1, 9, 30),
    dueDate: dueDate,
    isAllDay: isAllDay,
    notes: notes,
  );
}

void main() {
  final effectiveToday = DateParsingService().getCurrentEffectiveToday();

  group('taskToCardData — basic field mapping', () {
    test('maps id, title, completed straight through', () {
      final task = _task(id: 'abc', title: 'Water the plants', completed: true);
      final data = taskToCardData(task, const []);

      expect(data.id, 'abc');
      expect(data.title, 'Water the plants');
      expect(data.isCompleted, isTrue);
    });

    test('maps createdAt (M3/M4 addendum item 2: adapter maps more fields now)', () {
      final createdAt = DateTime(2026, 3, 4, 12, 0);
      final task = _task(createdAt: createdAt);
      final data = taskToCardData(task, const []);
      expect(data.createdAt, createdAt);
    });

    test('maps notes (M3/M4 addendum item 2)', () {
      final task = _task(notes: 'Check the soil moisture first.');
      final data = taskToCardData(task, const []);
      expect(data.notes, 'Check the soil moisture first.');
    });

    test('notes is null when the task has none', () {
      final task = _task();
      final data = taskToCardData(task, const []);
      expect(data.notes, isNull);
    });

    test('maps dueDate straight through', () {
      final due = DateTime(2026, 6, 1);
      final task = _task(dueDate: due);
      final data = taskToCardData(task, const []);
      expect(data.dueDate, due);
    });
  });

  group('taskToCardData — tags', () {
    test('maps a tag with an explicit color to a TagChip via TagColors', () {
      final tag = Tag(id: 'tag1', name: 'urgent', color: '#E91E63', createdAt: DateTime(2026, 1, 1));
      final data = taskToCardData(_task(), [tag]);

      expect(data.tags, hasLength(1));
      expect(data.tags.single.id, 'tag1');
      expect(data.tags.single.name, 'urgent');
      expect(data.tags.single.color, TagColors.hexToColor('#E91E63'));
      expect(data.tags.single.textColor, TagColors.getTextColor('#E91E63'));
    });

    test('falls back to #2196F3/white when a tag has no color', () {
      final tag = Tag(id: 'tag2', name: 'someday', createdAt: DateTime(2026, 1, 1));
      final data = taskToCardData(_task(), [tag]);

      expect(data.tags.single.color, TagColors.hexToColor(kDefaultTagColorHex));
      expect(data.tags.single.color, const Color(0xFF2196F3));
      expect(data.tags.single.textColor, Colors.white);
    });

    test('maps multiple tags in order', () {
      final tags = [
        Tag(id: 'a', name: 'home', color: '#4CAF50', createdAt: DateTime(2026, 1, 1)),
        Tag(id: 'b', name: 'writing', color: '#9C27B0', createdAt: DateTime(2026, 1, 1)),
      ];
      final data = taskToCardData(_task(), tags);
      expect(data.tags.map((t) => t.id).toList(), ['a', 'b']);
    });
  });

  group('taskToCardData — isOverdue uses the shared isTaskOverdue() rule', () {
    test('an incomplete all-day task due yesterday (effective) is overdue', () {
      final due = effectiveToday.subtract(const Duration(days: 1));
      final task = _task(dueDate: due, isAllDay: true);
      final data = taskToCardData(task, const []);

      expect(data.isOverdue, isTaskOverdue(due, isAllDay: true));
      expect(data.isOverdue, isTrue);
    });

    test('boundary agreement: due exactly "today" (effective) is NOT overdue', () {
      final task = _task(dueDate: effectiveToday, isAllDay: true);
      final data = taskToCardData(task, const []);

      expect(data.isOverdue, isTaskOverdue(effectiveToday, isAllDay: true));
      expect(data.isOverdue, isFalse);
    });

    test('a completed task is never overdue, even with a due date in the past', () {
      final due = effectiveToday.subtract(const Duration(days: 30));
      final task = _task(dueDate: due, isAllDay: true, completed: true);
      final data = taskToCardData(task, const []);

      expect(data.isOverdue, isFalse);
    });

    test('a task with no due date is never overdue', () {
      final task = _task();
      final data = taskToCardData(task, const []);
      expect(data.isOverdue, isFalse);
    });

    test('a timed task due an hour ago is overdue, matching isTaskOverdue directly', () {
      final due = DateTime.now().subtract(const Duration(hours: 1));
      final task = _task(dueDate: due, isAllDay: false);
      final data = taskToCardData(task, const []);

      expect(data.isOverdue, isTaskOverdue(due, isAllDay: false));
      expect(data.isOverdue, isTrue);
    });
  });
}
