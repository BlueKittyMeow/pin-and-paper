import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _hideOldCompletedKey = 'hide_old_completed';
  static const String _hideThresholdKey = 'hide_threshold_hours';
  static const String _sortModeKey = 'task_sort_mode';
  static const String _sortReversedKey = 'task_sort_reversed';

  Future<bool> getHideOldCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideOldCompletedKey) ?? true;  // Default: ON
  }

  Future<void> setHideOldCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideOldCompletedKey, value);
  }

  Future<int> getHideThresholdHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hideThresholdKey) ?? 24;  // Default: 24 hours
  }

  Future<void> setHideThresholdHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hideThresholdKey, hours);
  }

  // Phase 3.7.5: Sort mode persistence
  Future<String> getSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortModeKey) ?? 'manual';
  }

  Future<void> setSortMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortModeKey, mode);
  }

  Future<bool> getSortReversed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sortReversedKey) ?? false;
  }

  Future<void> setSortReversed(bool reversed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sortReversedKey, reversed);
  }
}
