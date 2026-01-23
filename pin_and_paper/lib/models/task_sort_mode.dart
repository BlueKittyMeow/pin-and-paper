import 'package:flutter/material.dart';

/// Sort modes for the active task tree
enum TaskSortMode {
  /// Manual position order (default, drag-and-drop)
  manual,

  /// By creation date, newest first
  recentlyCreated,

  /// By due date, soonest first (nulls last)
  dueSoonest,

  /// Overdue tasks first, then by how overdue
  overdue,
}

extension TaskSortModeExtension on TaskSortMode {
  String get displayName {
    switch (this) {
      case TaskSortMode.manual:
        return 'Manual';
      case TaskSortMode.recentlyCreated:
        return 'Recently Created';
      case TaskSortMode.dueSoonest:
        return 'Due Soonest';
      case TaskSortMode.overdue:
        return 'Overdue';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskSortMode.manual:
        return Icons.drag_handle;
      case TaskSortMode.recentlyCreated:
        return Icons.schedule;
      case TaskSortMode.dueSoonest:
        return Icons.event;
      case TaskSortMode.overdue:
        return Icons.warning_amber;
    }
  }
}
