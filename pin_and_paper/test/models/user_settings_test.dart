import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';
import 'package:pin_and_paper/models/user_settings.dart';

void main() {
  group('UserSettings Model', () {
    final now = DateTime(2025, 10, 30, 10, 30);

    test('defaults() creates settings with all default values', () {
      withClock(Clock.fixed(now), () {
        final settings = UserSettings.defaults();

        expect(settings.id, 1);
        expect(settings.earlyMorningHour, 5);
        expect(settings.morningHour, 9);
        expect(settings.noonHour, 12);
        expect(settings.afternoonHour, 15);
        expect(settings.tonightHour, 19);
        expect(settings.lateNightHour, 22);
        expect(settings.todayCutoffHour, 4);
        expect(settings.todayCutoffMinute, 59);
        expect(settings.weekStartDay, 1); // Monday
        expect(settings.timezoneId, null);
        expect(settings.use24HourTime, false);
        expect(settings.autoCompleteChildren, 'prompt');
        expect(settings.defaultNotificationHour, 9);
        expect(settings.defaultNotificationMinute, 0);
        expect(settings.voiceSmartPunctuation, true);
        expect(settings.createdAt, now);
        expect(settings.updatedAt, now);
      });
    });

    test('toMap serializes all fields correctly', () {
      final settings = UserSettings(
        id: 1,
        earlyMorningHour: 6,
        morningHour: 8,
        noonHour: 12,
        afternoonHour: 14,
        tonightHour: 20,
        lateNightHour: 23,
        todayCutoffHour: 3,
        todayCutoffMinute: 30,
        weekStartDay: 0, // Sunday
        timezoneId: 'America/New_York',
        use24HourTime: true,
        autoCompleteChildren: 'always',
        defaultNotificationHour: 8,
        defaultNotificationMinute: 30,
        voiceSmartPunctuation: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = settings.toMap();

      expect(map['id'], 1);
      expect(map['early_morning_hour'], 6);
      expect(map['morning_hour'], 8);
      expect(map['noon_hour'], 12);
      expect(map['afternoon_hour'], 14);
      expect(map['tonight_hour'], 20);
      expect(map['late_night_hour'], 23);
      expect(map['today_cutoff_hour'], 3);
      expect(map['today_cutoff_minute'], 30);
      expect(map['week_start_day'], 0);
      expect(map['timezone_id'], 'America/New_York');
      expect(map['use_24hour_time'], 1);
      expect(map['auto_complete_children'], 'always');
      expect(map['default_notification_hour'], 8);
      expect(map['default_notification_minute'], 30);
      expect(map['voice_smart_punctuation'], 0);
      expect(map['created_at'], now.millisecondsSinceEpoch);
      expect(map['updated_at'], now.millisecondsSinceEpoch);
    });

    test('fromMap deserializes all fields correctly', () {
      final map = {
        'id': 1,
        'early_morning_hour': 6,
        'morning_hour': 8,
        'noon_hour': 12,
        'afternoon_hour': 14,
        'tonight_hour': 20,
        'late_night_hour': 23,
        'today_cutoff_hour': 3,
        'today_cutoff_minute': 30,
        'week_start_day': 0,
        'timezone_id': 'America/Detroit',
        'use_24hour_time': 1,
        'auto_complete_children': 'never',
        'default_notification_hour': 7,
        'default_notification_minute': 45,
        'voice_smart_punctuation': 0,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      };

      final settings = UserSettings.fromMap(map);

      expect(settings.id, 1);
      expect(settings.earlyMorningHour, 6);
      expect(settings.morningHour, 8);
      expect(settings.noonHour, 12);
      expect(settings.afternoonHour, 14);
      expect(settings.tonightHour, 20);
      expect(settings.lateNightHour, 23);
      expect(settings.todayCutoffHour, 3);
      expect(settings.todayCutoffMinute, 30);
      expect(settings.weekStartDay, 0);
      expect(settings.timezoneId, 'America/Detroit');
      expect(settings.use24HourTime, true);
      expect(settings.autoCompleteChildren, 'never');
      expect(settings.defaultNotificationHour, 7);
      expect(settings.defaultNotificationMinute, 45);
      expect(settings.voiceSmartPunctuation, false);
      expect(settings.createdAt, now);
      expect(settings.updatedAt, now);
    });

    test('copyWith updates specified fields only', () {
      final original = UserSettings(
        earlyMorningHour: 5,
        morningHour: 9,
        timezoneId: 'America/New_York',
        use24HourTime: false,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        morningHour: 8,
        use24HourTime: true,
      );

      // Changed fields
      expect(updated.morningHour, 8);
      expect(updated.use24HourTime, true);

      // Unchanged fields
      expect(updated.earlyMorningHour, 5);
      expect(updated.timezoneId, 'America/New_York');
      expect(updated.createdAt, now); // createdAt never changes
    });

    test('copyWith automatically updates updatedAt timestamp', () {
      final createdTime = DateTime(2025, 10, 29, 10, 0);
      final updateTime = DateTime(2025, 10, 30, 15, 30);

      final original = UserSettings(
        morningHour: 9,
        createdAt: createdTime,
        updatedAt: createdTime,
      );

      withClock(Clock.fixed(updateTime), () {
        final updated = original.copyWith(morningHour: 8);

        expect(updated.createdAt, createdTime); // Never changes
        expect(updated.updatedAt, updateTime); // Auto-updated to now
      });
    });

    test('copyWith with Value wrapper sets timezoneId to new value', () {
      final settings = UserSettings(
        timezoneId: null,
        createdAt: now,
        updatedAt: now,
      );

      final updated = settings.copyWith(
        timezoneId: Value('America/Chicago'),
      );

      expect(updated.timezoneId, 'America/Chicago');
    });

    test('copyWith with Value(null) clears timezoneId', () {
      final settings = UserSettings(
        timezoneId: 'America/New_York',
        createdAt: now,
        updatedAt: now,
      );

      final updated = settings.copyWith(
        timezoneId: Value(null), // Explicitly clear
      );

      expect(updated.timezoneId, null);
    });

    test('copyWith without timezoneId parameter preserves existing value', () {
      final settings = UserSettings(
        timezoneId: 'America/Los_Angeles',
        morningHour: 9,
        createdAt: now,
        updatedAt: now,
      );

      // Update morningHour but don't touch timezoneId
      final updated = settings.copyWith(
        morningHour: 8,
      );

      expect(updated.timezoneId, 'America/Los_Angeles');
    });

    test('Value wrapper distinguishes between not-provided and null', () {
      final settings = UserSettings(
        timezoneId: 'America/Denver',
        createdAt: now,
        updatedAt: now,
      );

      // Case 1: Parameter not provided - preserves existing value
      final notProvided = settings.copyWith(morningHour: 8);
      expect(notProvided.timezoneId, 'America/Denver');

      // Case 2: Explicitly set to null - clears value
      final explicitlyNull = settings.copyWith(timezoneId: Value(null));
      expect(explicitlyNull.timezoneId, null);

      // Case 3: Set to new value
      final newValue = settings.copyWith(timezoneId: Value('America/Phoenix'));
      expect(newValue.timezoneId, 'America/Phoenix');
    });

    test('Round-trip serialization preserves all data', () {
      final original = UserSettings(
        id: 1,
        earlyMorningHour: 6,
        morningHour: 8,
        noonHour: 13,
        afternoonHour: 16,
        tonightHour: 21,
        lateNightHour: 0,
        todayCutoffHour: 5,
        todayCutoffMinute: 0,
        weekStartDay: 0,
        timezoneId: 'Europe/London',
        use24HourTime: true,
        autoCompleteChildren: 'always',
        defaultNotificationHour: 10,
        defaultNotificationMinute: 15,
        voiceSmartPunctuation: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = original.toMap();
      final deserialized = UserSettings.fromMap(map);

      expect(deserialized.id, original.id);
      expect(deserialized.earlyMorningHour, original.earlyMorningHour);
      expect(deserialized.morningHour, original.morningHour);
      expect(deserialized.noonHour, original.noonHour);
      expect(deserialized.afternoonHour, original.afternoonHour);
      expect(deserialized.tonightHour, original.tonightHour);
      expect(deserialized.lateNightHour, original.lateNightHour);
      expect(deserialized.todayCutoffHour, original.todayCutoffHour);
      expect(deserialized.todayCutoffMinute, original.todayCutoffMinute);
      expect(deserialized.weekStartDay, original.weekStartDay);
      expect(deserialized.timezoneId, original.timezoneId);
      expect(deserialized.use24HourTime, original.use24HourTime);
      expect(deserialized.autoCompleteChildren, original.autoCompleteChildren);
      expect(
          deserialized.defaultNotificationHour, original.defaultNotificationHour);
      expect(deserialized.defaultNotificationMinute,
          original.defaultNotificationMinute);
      expect(deserialized.voiceSmartPunctuation, original.voiceSmartPunctuation);
      expect(deserialized.createdAt, original.createdAt);
      expect(deserialized.updatedAt, original.updatedAt);
    });

    test('id is always 1 (single-row table)', () {
      final settings = UserSettings.defaults();
      expect(settings.id, 1);

      final updated = settings.copyWith(morningHour: 8);
      expect(updated.id, 1); // ID never changes
    });
  });
}
