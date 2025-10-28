import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _hideOldCompletedKey = 'hide_old_completed';
  static const String _hideThresholdKey = 'hide_threshold_hours';

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
}
