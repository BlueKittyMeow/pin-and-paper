import 'package:clock/clock.dart';
import '../models/user_settings.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Service for managing user settings (single-row table)
///
/// User settings are stored in a single row with id=1.
/// If settings don't exist, defaults are created automatically.
class UserSettingsService {
  final DatabaseService _dbService = DatabaseService.instance;

  /// Get user settings (creates defaults if they don't exist)
  Future<UserSettings> getUserSettings() async {
    final db = await _dbService.database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.userSettingsTable,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (maps.isEmpty) {
      // No settings exist - create defaults
      final defaultSettings = UserSettings.defaults();
      await db.insert(
        AppConstants.userSettingsTable,
        defaultSettings.toMap(),
      );
      return defaultSettings;
    }

    return UserSettings.fromMap(maps.first);
  }

  /// Update user settings
  ///
  /// Updates the existing settings row. The updated_at timestamp
  /// is automatically set by the copyWith method.
  Future<void> updateUserSettings(UserSettings settings) async {
    final db = await _dbService.database;

    // Ensure updated_at is set to now
    final updatedSettings = settings.copyWith(
      updatedAt: clock.now(),
    );

    await db.update(
      AppConstants.userSettingsTable,
      updatedSettings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// Update specific settings using copyWith pattern
  ///
  /// Example:
  /// ```dart
  /// await updateSettings((current) => current.copyWith(
  ///   morningHour: Value(8),
  ///   timezoneId: Value('America/New_York'),
  /// ));
  /// ```
  Future<void> updateSettings(
    UserSettings Function(UserSettings) updateFn,
  ) async {
    final current = await getUserSettings();
    final updated = updateFn(current);
    await updateUserSettings(updated);
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    final db = await _dbService.database;
    final defaults = UserSettings.defaults();

    await db.update(
      AppConstants.userSettingsTable,
      defaults.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
