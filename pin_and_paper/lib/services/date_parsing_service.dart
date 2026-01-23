import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParsedDate {
  final String matchedText;
  final TextRange matchedRange;
  final DateTime date;
  final bool isAllDay;

  ParsedDate({
    required this.matchedText,
    required this.matchedRange,
    required this.date,
    required this.isAllDay,
  });

  String get cleanTitle {
    // This will be used to strip the matched text from the original title
    return matchedText;
  }
}

class DateParsingService {
  static final DateParsingService _instance = DateParsingService._internal();
  factory DateParsingService() => _instance;
  DateParsingService._internal();

  JavascriptRuntime? _jsRuntime;
  bool _initialized = false;

  // Settings (will be loaded from SharedPreferences in Phase 3.9)
  int _todayCutoffHour = 4;
  int _todayCutoffMinute = 59;
  bool _parsingEnabled = true;

  /// Initialize the JavaScript runtime and load chrono.js
  ///
  /// OPTIMIZATION (Codex/Gemini): Includes web platform guard and warmup parse
  Future<void> initialize() async {
    if (_initialized) return;

    // WEB PLATFORM GUARD (Codex): Skip initialization on web
    // flutter_js uses platform-specific FFI and is not available on web
    if (kIsWeb) {
      _initialized = true;
      print('DateParsingService: Skipping flutter_js on web platform');
      return;
    }

    try {
      // Create JavaScript runtime
      _jsRuntime = getJavascriptRuntime();

      // Load chrono.js from assets
      final chronoSource = await rootBundle.loadString('assets/js/chrono.min.js');

      // Evaluate chrono.js in the runtime
      final result = _jsRuntime!.evaluate(chronoSource);

      if (result.isError) {
        throw Exception('Failed to load chrono.js: ${result.stringResult}');
      }

      // WARMUP PARSE (Codex): JIT-compile the parsing code path
      // First parse normally takes ~1200μs (cold JIT), subsequent ~1μs (warm)
      // Running warmup eliminates the cold-start delay for better UX
      _jsRuntime!.evaluate('''
        (function() {
          const ref = new Date();
          chrono.parse("warmup test tomorrow", ref);
        })();
      ''');

      _initialized = true;
      print('DateParsingService initialized successfully (with warmup)');
    } catch (e) {
      print('Error initializing DateParsingService: $e');
      rethrow;
    }
  }

  /// Parse a text string and extract date information
  ///
  /// Returns null if no date found or if parsing is disabled
  /// WEB PLATFORM (Codex): Gracefully returns null on web (flutter_js not available)
  ParsedDate? parse(String text, {DateTime? now}) {
    // WEB PLATFORM GUARD: Silently fail on web or if not initialized
    if (kIsWeb || !_initialized) {
      return null;
    }

    if (!_parsingEnabled || text.trim().isEmpty) {
      return null;
    }

    now ??= DateTime.now();

    // Calculate effective today using Today Window algorithm
    final effectiveToday = getEffectiveToday(
      now,
      _todayCutoffHour,
      _todayCutoffMinute,
    );

    try {
      // Prepare JavaScript code to parse the text
      // SECURITY FIX (Codex): Use jsonEncode() to safely escape user input
      // This prevents JS injection from quotes, backslashes, newlines, etc.
      final jsCode = '''
        (function() {
          const text = ${jsonEncode(text)};
          const referenceDate = new Date("${effectiveToday.toIso8601String()}");
          const parsed = chrono.parse(text, referenceDate, { forwardDate: true });

          if (parsed.length === 0) return null;

          const match = parsed[0];
          return JSON.stringify({
            text: match.text,
            index: match.index,
            date: match.start.date().toISOString(),
            hasTime: match.start.isCertain('hour')
          });
        })();
      ''';

      final result = _jsRuntime!.evaluate(jsCode);

      if (result.isError) {
        print('JavaScript error during parsing: ${result.stringResult}');
        return null;
      }

      final resultString = result.stringResult;

      if (resultString == 'null' || resultString.isEmpty) {
        return null;
      }

      final json = jsonDecode(resultString);

      return ParsedDate(
        matchedText: json['text'] as String,
        matchedRange: TextRange(
          start: json['index'] as int,
          end: (json['index'] as int) + (json['text'] as String).length,
        ),
        date: DateTime.parse(json['date'] as String),
        isAllDay: !(json['hasTime'] as bool),
      );
    } catch (e) {
      print('Error parsing date: $e');
      return null;
    }
  }

  /// Check if text potentially contains a date
  ///
  /// Fast rejection using regex to avoid unnecessary FFI calls.
  /// Reduces chrono.js calls by ~80-90% (most tasks don't have dates).
  ///
  /// OPTIMIZATION (Codex/Gemini): Pre-filter prevents false positives and reduces battery drain
  ///
  /// Examples:
  /// - "Call mom" → false (no date-like tokens)
  /// - "Call dentist tomorrow" → true (contains "tomorrow")
  /// - "May need to buy milk" → false (month alone without day)
  /// - "Meeting May 15" → true (month with day)
  bool containsPotentialDate(String text) {
    // Fast rejection for very short strings
    if (text.length < 3) return false;

    // Check for date-like keywords and patterns
    final datePattern = RegExp(
      r'\b('
      // Relative dates
      r'today|tomorrow|yesterday|tonight|'
      r'next\s+(week|month|year)|this\s+(week|month|year)|last\s+(week|month|year)|'
      // Days of week
      r'monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
      r'mon|tue|wed|thu|fri|sat|sun'
      r')\b|'
      // Months WITH day context required (prevents "May need to..." false positive)
      r'\b(january|february|march|april|may|june|july|august|'
      r'september|october|november|december|'
      r'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}\b|'
      r'\b\d{1,2}\s+(january|february|march|april|may|june|july|august|'
      r'september|october|november|december|'
      r'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b|'
      // Numeric patterns
      r'\d{1,2}[/-]\d{1,2}|'  // 12/31 or 12-31
      r'\d{4}|'                // 2026
      r'\bin\s+\d+\s+(day|week|month)s?\b|'  // "in 3 days"
      r'\bat\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b',  // "at 3pm", "at 3:30pm", "at 10"
      caseSensitive: false,
    );

    return datePattern.hasMatch(text);
  }

  /// Calculate "effective today" based on Today Window algorithm
  ///
  /// FIXED: Now includes minute parameter (was missing in v3)
  ///
  /// For night owl mode: if it's 2:30am Tuesday and cutoff is 4:59am,
  /// we consider it "still Monday night", so effective today = Monday
  DateTime getEffectiveToday(
    DateTime now,
    int todayWindowHours,
    int todayWindowMinutes,
  ) {
    // If we're before the cutoff time, treat it as still "yesterday"
    if (now.hour < todayWindowHours ||
        (now.hour == todayWindowHours && now.minute <= todayWindowMinutes)) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  /// Get effective today for current time (convenience method for widgets)
  ///
  /// CRITICAL (Codex): Widgets must use this for date formatting to match parsing logic
  /// Otherwise at 2am, parsing uses "yesterday" but UI shows "today" - confusing!
  DateTime getCurrentEffectiveToday() {
    return getEffectiveToday(
      DateTime.now(),
      _todayCutoffHour,
      _todayCutoffMinute,
    );
  }

  /// Load settings from SharedPreferences (will be implemented in Phase 3.9)
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _todayCutoffHour = prefs.getInt('today_cutoff_hour') ?? 4;
    _todayCutoffMinute = prefs.getInt('today_cutoff_minute') ?? 59;
    _parsingEnabled = prefs.getBool('enable_quick_add_date_parsing') ?? true;
  }

  /// Dispose resources
  void dispose() {
    _jsRuntime?.dispose();
    _jsRuntime = null;
    _initialized = false;
  }
}
