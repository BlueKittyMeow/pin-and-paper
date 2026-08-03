import 'package:pin_and_paper_card_renderer/card_renderer.dart' show TagChip, TaskCardData;

import '../models/tag.dart';
import '../models/task.dart';
import '../services/date_parsing_service.dart' show isTaskOverdue;
import '../utils/tag_colors.dart';

/// Fallback hex used when a [Tag] has no color of its own ([Tag.color] null
/// means "use default", per the model's doc comment). Matches
/// [TagColors.defaultColor].
const String kDefaultTagColorHex = '#2196F3';

/// Maps a [Task] plus its resolved [tags] into the render-only [TaskCardData]
/// shape the card renderer consumes (DRAG_DROP_CANVAS_MVP_PLAN.md Milestone
/// 4's `task_card_adapter.dart`).
///
/// [isOverdue] uses the shared [isTaskOverdue] helper (M3/M4 addendum item
/// 2) rather than a bespoke `dueDate.isBefore(now)` comparison, so this
/// card's red/muted styling agrees with the list view's own overdue rule
/// (Today-Window-aware for all-day tasks) instead of drifting from it.
/// Completed tasks are never overdue, matching [TaskCardData.isOverdue]'s
/// own doc comment.
TaskCardData taskToCardData(Task task, List<Tag> tags) {
  final dueDate = task.dueDate;
  final isOverdue = dueDate != null && !task.completed && isTaskOverdue(dueDate, isAllDay: task.isAllDay);

  return TaskCardData(
    id: task.id,
    title: task.title,
    tags: [for (final tag in tags) _tagToChip(tag)],
    dueDate: dueDate,
    isCompleted: task.completed,
    isOverdue: isOverdue,
    notes: task.notes,
    createdAt: task.createdAt,
  );
}

TagChip _tagToChip(Tag tag) {
  final hex = tag.color ?? kDefaultTagColorHex;
  return TagChip(id: tag.id, name: tag.name, color: TagColors.hexToColor(hex), textColor: TagColors.getTextColor(hex));
}
