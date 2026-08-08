import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/spatial/task_spatial_entity.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart' show kCardSize;

Task _task({required String id, required int position}) {
  return Task(id: id, title: 'Task $id', createdAt: DateTime(2026, 1, 1), position: position);
}

void main() {
  group('TaskSpatialEntity', () {
    test('id delegates to the wrapped task', () {
      final entity = TaskSpatialEntity(task: _task(id: 't1', position: 0), position: Offset.zero);
      expect(entity.id, 't1');
    });

    test('size matches the card renderer\'s kCardSize (addendum item 4)', () {
      final entity = TaskSpatialEntity(task: _task(id: 't1', position: 0), position: Offset.zero);
      expect(entity.size, kCardSize);
    });

    test('rotation is always 0 (no rotation gesture in this MVP)', () {
      final entity = TaskSpatialEntity(task: _task(id: 't1', position: 0), position: Offset.zero);
      expect(entity.rotation, 0);
    });

    test('position is session-mutable independent of the wrapped task', () {
      final entity = TaskSpatialEntity(task: _task(id: 't1', position: 0), position: const Offset(10, 20));
      expect(entity.position, const Offset(10, 20));

      entity.position = const Offset(99, -5);
      expect(entity.position, const Offset(99, -5));
    });

    group('zIndex = -task.position (M3/M4 addendum item 5)', () {
      test('a task at position -2 (newer) has a higher zIndex than one at 0 (older)', () {
        final newer = TaskSpatialEntity(task: _task(id: 'new', position: -2), position: Offset.zero);
        final older = TaskSpatialEntity(task: _task(id: 'old', position: 0), position: Offset.zero);

        expect(newer.zIndex, greaterThan(older.zIndex));
        expect(newer.zIndex, 2); // zIndex = -task.position = -(-2) = 2
        expect(older.zIndex, 0);
      });

      test('positive task positions still negate correctly', () {
        final entity = TaskSpatialEntity(task: _task(id: 't1', position: 7), position: Offset.zero);
        expect(entity.zIndex, -7);
      });
    });
  });
}
