import 'package:flutter/foundation.dart';
import '../models/task_sort_mode.dart';
import '../services/preferences_service.dart';

/// Provider for managing task sorting state
///
/// Phase 3.9 Refactor: Extracted from TaskProvider to reduce file size
/// and improve separation of concerns.
///
/// Responsibilities:
/// - Manage sort mode (manual, recently created, due soonest)
/// - Manage sort direction (normal/reversed)
/// - Persist sort preferences
///
/// TaskProvider listens to this provider and applies sorting to tasks.
class TaskSortProvider extends ChangeNotifier {
  final PreferencesService _preferencesService;

  TaskSortProvider({
    PreferencesService? preferencesService,
  }) : _preferencesService = preferencesService ?? PreferencesService();

  TaskSortMode _sortMode = TaskSortMode.manual;
  bool _sortReversed = false;

  // Getters
  TaskSortMode get sortMode => _sortMode;
  bool get sortReversed => _sortReversed;

  /// Load sort preferences from persistent storage
  ///
  /// Call this during app initialization.
  Future<void> loadPreferences() async {
    final sortModeStr = await _preferencesService.getSortMode();
    _sortMode = TaskSortMode.values.firstWhere(
      (m) => m.name == sortModeStr,
      orElse: () => TaskSortMode.manual,
    );
    _sortReversed = await _preferencesService.getSortReversed();
    notifyListeners();
  }

  /// Change sort mode for root-level tasks
  void setSortMode(TaskSortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _sortReversed = false; // Reset reversed when changing mode
    _preferencesService.setSortMode(mode.name);
    _preferencesService.setSortReversed(false);
    notifyListeners();
  }

  /// Toggle sort direction
  void toggleSortReversed() {
    _sortReversed = !_sortReversed;
    _preferencesService.setSortReversed(_sortReversed);
    notifyListeners();
  }
}
