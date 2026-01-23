import 'package:flutter/material.dart';

/// Sort modes for the active task tree
enum TaskSortMode {
  /// Manual position order (default, drag-and-drop)
  manual,

  /// By creation date, newest first
  recentlyCreated,

  /// By due date, soonest first (nulls last)
  dueSoonest,
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
    }
  }
}
