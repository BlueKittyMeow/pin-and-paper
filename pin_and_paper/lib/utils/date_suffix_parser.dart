import '../services/date_parsing_service.dart';

/// Result of parsing a date suffix from a task title
class DateSuffixResult {
  /// The title without the date suffix
  final String prefix;

  /// The date suffix string (e.g., "(Wed, Jan 22)")
  final String suffix;

  /// The parsed DateTime from the suffix
  final DateTime date;

  /// Whether the date includes a time component
  final bool hasTime;

  /// Whether the date is in the past (overdue)
  final bool isOverdue;

  DateSuffixResult({
    required this.prefix,
    required this.suffix,
    required this.date,
    required this.hasTime,
    required this.isOverdue,
  });
}

/// Utility to detect and parse date suffixes from task titles
///
/// Phase 3.7: When tasks are created with natural language dates, the date
/// is stripped and a formatted suffix is appended: "Call dentist (Mon, Jan 27)"
///
/// This parser detects those suffixes for:
/// 1. Highlighting in task list (blue = future, red = overdue)
/// 2. Making suffixes clickable in EditTaskDialog
///
/// Supported formats:
/// - "(Wed, Jan 22)" - all-day date
/// - "(Wed, Jan 22, 3:00 PM)" - date with time
class DateSuffixParser {
  // Pattern for all-day date: (Wed, Jan 22)
  // Day: 3-letter weekday
  // Month: 3-letter month
  // Day number: 1-2 digits
  static final RegExp _allDayPattern = RegExp(
    r'\(([A-Z][a-z]{2}), ([A-Z][a-z]{2}) (\d{1,2})\)$',
  );

  // Pattern for date with time: (Wed, Jan 22, 3:00 PM)
  // Same as above + time in h:mm a format
  static final RegExp _withTimePattern = RegExp(
    r'\(([A-Z][a-z]{2}), ([A-Z][a-z]{2}) (\d{1,2}), (\d{1,2}):(\d{2}) ([AP]M)\)$',
  );

  // Map month abbreviations to month numbers
  static const Map<String, int> _monthMap = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
    'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
    'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  /// Check if a title contains a date suffix
  static bool hasSuffix(String title) {
    return _allDayPattern.hasMatch(title) || _withTimePattern.hasMatch(title);
  }

  /// Parse a date suffix from a title
  ///
  /// Returns null if no valid suffix is found
  static DateSuffixResult? parse(String title) {
    // Try time pattern first (more specific)
    final timeMatch = _withTimePattern.firstMatch(title);
    if (timeMatch != null) {
      return _parseWithTime(title, timeMatch);
    }

    // Try all-day pattern
    final allDayMatch = _allDayPattern.firstMatch(title);
    if (allDayMatch != null) {
      return _parseAllDay(title, allDayMatch);
    }

    return null;
  }

  static DateSuffixResult? _parseAllDay(String title, RegExpMatch match) {
    try {
      final monthStr = match.group(2)!;
      final dayNum = int.parse(match.group(3)!);
      final month = _monthMap[monthStr];

      if (month == null) return null;

      // Determine year - assume current year, but if date is > 6 months ago,
      // assume next year (handles Dec → Jan transition)
      final now = DateParsingService().getCurrentEffectiveToday();
      int year = now.year;

      final candidateDate = DateTime(year, month, dayNum);
      if (candidateDate.isBefore(now.subtract(const Duration(days: 180)))) {
        year++;
      }

      final date = DateTime(year, month, dayNum);
      final suffix = match.group(0)!;
      final prefix = title.substring(0, match.start).trim();

      return DateSuffixResult(
        prefix: prefix,
        suffix: suffix,
        date: date,
        hasTime: false,
        isOverdue: _isOverdue(date, isAllDay: true),
      );
    } catch (e) {
      return null;
    }
  }

  static DateSuffixResult? _parseWithTime(String title, RegExpMatch match) {
    try {
      final monthStr = match.group(2)!;
      final dayNum = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final amPm = match.group(6)!;
      final month = _monthMap[monthStr];

      if (month == null) return null;

      // Convert 12-hour to 24-hour
      int hour24 = hour;
      if (amPm == 'PM' && hour != 12) {
        hour24 += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour24 = 0;
      }

      // Determine year
      final now = DateParsingService().getCurrentEffectiveToday();
      int year = now.year;

      final candidateDate = DateTime(year, month, dayNum);
      if (candidateDate.isBefore(now.subtract(const Duration(days: 180)))) {
        year++;
      }

      final date = DateTime(year, month, dayNum, hour24, minute);
      final suffix = match.group(0)!;
      final prefix = title.substring(0, match.start).trim();

      return DateSuffixResult(
        prefix: prefix,
        suffix: suffix,
        date: date,
        hasTime: true,
        isOverdue: _isOverdue(date, isAllDay: false),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if a date is overdue
  static bool _isOverdue(DateTime date, {required bool isAllDay}) {
    final now = DateTime.now();

    if (isAllDay) {
      // For all-day tasks, overdue if date is before today
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);
      return dateOnly.isBefore(today);
    } else {
      // For timed tasks, overdue if datetime is in the past
      return date.isBefore(now);
    }
  }
}
