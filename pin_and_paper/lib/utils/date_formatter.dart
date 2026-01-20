import 'package:intl/intl.dart';
import '../services/date_parsing_service.dart';

/// Utility functions for formatting dates relative to "today"
///
/// Phase 3.7: Used for displaying parsed dates in a human-readable format
///
/// CRITICAL: Uses DateParsingService.getCurrentEffectiveToday() instead of
/// DateTime.now() to ensure consistency with the Today Window algorithm.
/// This prevents confusion where at 2am, parsing uses "yesterday" but
/// UI shows "today".
class DateFormatter {
  /// Format a date as a relative string (e.g., "Today", "Tomorrow", or "Wed, Jan 22")
  ///
  /// If [includeTime] is true and [isAllDay] is false, includes time like "3:00 PM"
  ///
  /// Examples:
  /// - Today, all-day: "Today (Wed, Jan 22)"
  /// - Tomorrow, 3pm: "Tomorrow, 3:00 PM (Thu, Jan 23)"
  /// - Next week: "Wed, Jan 29"
  static String formatRelativeDate(DateTime date, {bool isAllDay = true}) {
    // CRITICAL FIX (Codex): Use effectiveToday instead of DateTime.now()
    final effectiveToday = DateParsingService().getCurrentEffectiveToday();
    final diff = date.difference(effectiveToday);

    String relativeDay;
    if (diff.inDays == 0) {
      relativeDay = 'Today';
    } else if (diff.inDays == 1) {
      relativeDay = 'Tomorrow';
    } else if (diff.inDays == -1) {
      relativeDay = 'Yesterday';
    } else {
      // Use day of week for dates within a week
      if (diff.inDays.abs() <= 7) {
        relativeDay = DateFormat('EEEE').format(date); // "Monday"
      } else {
        relativeDay = DateFormat('EEE, MMM d').format(date); // "Wed, Jan 22"
      }
    }

    // Add time if not all-day
    final time = isAllDay ? '' : ', ${DateFormat('h:mm a').format(date)}';

    // Add full date in parentheses for clarity
    final fullDate = DateFormat('EEE, MMM d').format(date);

    return '$relativeDay$time ($fullDate)';
  }

  /// Format a date for the DateOptionsSheet alternatives
  ///
  /// Examples:
  /// - "Today (Wed, Jan 22)"
  /// - "Tomorrow (Thu, Jan 23)"
  /// - "Next week (Wed, Jan 29)"
  static String formatAlternativeDate(DateTime date, String label) {
    final fullDate = DateFormat('EEE, MMM d').format(date);
    return '$label ($fullDate)';
  }
}
