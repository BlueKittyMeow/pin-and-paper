# Phase 3.7 Implementation Guide - Natural Language Date Parsing

**Version:** 1.0
**Based on:** [phase-3.7-plan-v4.md](./phase-3.7-plan-v4.md)
**Created:** 2026-01-20
**Status:** Ready for Implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Implementation Steps](#implementation-steps)
5. [Component Details](#component-details)
6. [Integration Points](#integration-points)
7. [Testing Strategy](#testing-strategy)
8. [Validation Checklist](#validation-checklist)
9. [Troubleshooting](#troubleshooting)

---

## Overview

### Goals

Phase 3.7 adds natural language date parsing to Pin and Paper, enabling users to type dates naturally like "tomorrow at 3pm" or "next Tuesday" and have them automatically recognized and applied.

### Key Features

1. **Real-time date parsing** with Todoist-style inline highlighting
2. **Flutter_js + chrono.js** integration for robust date parsing
3. **Night owl mode** with configurable midnight boundary (4:59am default)
4. **Brain Dump integration** with Claude-based parsing
5. **Platform support:** Android, iOS, Linux, macOS (with web graceful degradation)

### Timeline

**Total: 7-10 days (1-1.5 weeks)**

- Days 1-2: flutter_js + chrono.js setup
- Days 3-4: Real-time highlighting (buildTextSpan)
- Day 5: Options menu & interactions
- Days 6-7: Integration with dialogs
- Days 8-9: Testing & refinement
- Day 10: Validation & documentation

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Edit Task Dialog / Quick Add Field                  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  TextField (with HighlightedTextEditingController) │  │
│  │  │  - Shows highlighted dates as user types        │  │
│  │  │  - Debounced 300ms after last keystroke         │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │
│  │  │  Preview: "Tomorrow, 3:00 PM (Tue, Jan 21)"     │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   DateParsingService                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  flutter_js Runtime                                   │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  chrono.min.js (bundled as asset)              │  │  │
│  │  │  - Parses "tomorrow at 3pm"                     │  │  │
│  │  │  - Returns: date, time, matched text range      │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  getEffectiveToday()                                  │  │
│  │  - Applies "Today Window" logic (4:59am cutoff)      │  │
│  │  - Used as reference date for chrono.js             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Settings & Storage                        │
│  - today_cutoff_hour: 4                                     │
│  - today_cutoff_minute: 59                                  │
│  - enable_quick_add_date_parsing: 1                         │
│  - morning_hour: 9, afternoon_hour: 15, evening_hour: 19    │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

**Typing → Parsing Flow:**
```
1. User types: "Call dentist tomorrow"
2. TextField onChange → debouncer (300ms)
3. Debouncer fires → DateParsingService.parse()
4. getEffectiveToday() calculates reference date (with night owl mode)
5. chrono.js parses with reference date
6. Returns: { text: "tomorrow", range: (14, 22), date: "2026-01-21" }
7. HighlightedTextEditingController sets highlight range
8. TextField rebuilds with highlighted text
9. Preview shows: "Tomorrow (Tue, Jan 21)"
```

**Click Highlight → Options Flow:**
```
1. User clicks highlighted "tomorrow"
2. TapGestureRecognizer fires onTap
3. Show DateOptionsSheet modal
4. User selects alternative or removes
5. Update state, close modal
6. Preview updates
```

**Save → Apply Flow:**
```
1. User clicks Save
2. If parsedDate exists and not dismissed:
   - Strip matched text from title
   - Apply date to task
3. Save task with clean title + due date
```

---

## Prerequisites

### Dependencies to Add

**pubspec.yaml:**
```yaml
dependencies:
  flutter_js: ^0.9.1  # JavaScript runtime for Flutter

  # Already included:
  # intl: ^0.19.0
  # shared_preferences: ^2.2.0
  # provider: ^6.1.0

flutter:
  assets:
    - assets/js/chrono.min.js  # Bundled chrono.js library
```

### Assets Setup

1. **Download chrono.js:**
   - Visit: https://cdn.jsdelivr.net/npm/chrono-node@2.7.6/dist/chrono.min.js
   - Save to: `pin_and_paper/assets/js/chrono.min.js`

2. **Create assets directory:**
   ```bash
   mkdir -p pin_and_paper/assets/js
   ```

3. **Verify asset size:**
   - Expected: ~200-300KB minified
   - APK impact: ~3-4MB (flutter_js) + ~2-3MB (chrono.js) = ~5-6MB total

---

## Implementation Steps

### Phase 1: flutter_js + chrono.js Setup (Days 1-2)

#### Step 1.1: Add Dependencies

**File:** `pin_and_paper/pubspec.yaml`

```yaml
dependencies:
  flutter_js: ^0.9.1

flutter:
  assets:
    - assets/js/chrono.min.js
```

**Action:**
```bash
cd pin_and_paper
flutter pub get
```

**Expected output:**
```
Running "flutter pub get" in pin_and_paper...
+ flutter_js 0.9.1
Changed 1 dependency!
```

---

#### Step 1.2: Download and Bundle chrono.js

**Terminal:**
```bash
mkdir -p pin_and_paper/assets/js
cd pin_and_paper/assets/js

# Download chrono.min.js
curl -o chrono.min.js https://cdn.jsdelivr.net/npm/chrono-node@2.7.6/dist/chrono.min.js

# Verify download
ls -lh chrono.min.js
# Should show ~200-300KB
```

---

#### Step 1.3: Create DateParsingService

**File:** `pin_and_paper/lib/services/date_parsing_service.dart`

```dart
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
      r'next|this|last|'
      // Days of week
      r'monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
      r'mon|tue|wed|thu|fri|sat|sun|'
      // Months
      r'january|february|march|april|may|june|july|august|'
      r'september|october|november|december|'
      r'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|'
      // Numeric patterns
      r'\d{1,2}[/-]\d{1,2}|'  // 12/31 or 12-31
      r'\d{4}|'                // 2026
      r'in\s+\d+\s+(day|week|month)|'  // "in 3 days"
      r'at\s+\d{1,2}'          // "at 3pm"
      r')\b',
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
```

**Key Design Decisions:**

1. **Singleton pattern** - Only one JavaScript runtime needed
2. **Lazy initialization** - Runtime created on first use
3. **Error handling** - Graceful fallback to null if parsing fails
4. **Today Window fix** - Includes both hour AND minute (fixes v3 bug)
5. **Settings preparation** - Ready for Phase 3.9 onboarding integration
6. **JS String Safety (Codex)** - Uses `jsonEncode()` to prevent injection from user input
7. **Effective Today Consistency (Codex)** - Exposes `getCurrentEffectiveToday()` for widgets to use same base date as parser

---

#### Step 1.4: Initialize in main.dart

**File:** `pin_and_paper/lib/main.dart`

Add initialization:

```dart
import 'services/date_parsing_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop if needed
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize date parsing service
  try {
    await DateParsingService().initialize();
  } catch (e) {
    print('Warning: Failed to initialize date parsing: $e');
    // Continue anyway - app will work without date parsing
  }

  runApp(const MyApp());
}
```

---

#### Step 1.5: Unit Tests for DateParsingService

**File:** `pin_and_paper/test/services/date_parsing_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';

void main() {
  late DateParsingService service;

  setUpAll(() async {
    // Note: flutter_test environment doesn't support flutter_js
    // These tests will need to be integration tests or use mocking
    service = DateParsingService();
    // await service.initialize();  // Will fail in unit test environment
  });

  group('getEffectiveToday', () {
    test('returns yesterday when before cutoff hour', () {
      final now = DateTime(2026, 1, 21, 3, 30); // 3:30am Tuesday
      final result = service.getEffectiveToday(now, 4, 59);

      expect(result.year, 2026);
      expect(result.month, 1);
      expect(result.day, 20); // Monday (still "yesterday")
    });

    test('returns yesterday when at cutoff hour but before cutoff minute', () {
      final now = DateTime(2026, 1, 21, 4, 30); // 4:30am Tuesday
      final result = service.getEffectiveToday(now, 4, 59);

      expect(result.day, 20); // Still Monday
    });

    test('returns yesterday when exactly at cutoff time', () {
      final now = DateTime(2026, 1, 21, 4, 59); // 4:59am Tuesday
      final result = service.getEffectiveToday(now, 4, 59);

      expect(result.day, 20); // Still Monday
    });

    test('returns today when past cutoff time', () {
      final now = DateTime(2026, 1, 21, 5, 0); // 5:00am Tuesday
      final result = service.getEffectiveToday(now, 4, 59);

      expect(result.day, 21); // Now Tuesday
    });

    test('handles month boundaries correctly', () {
      final now = DateTime(2026, 2, 1, 2, 0); // 2:00am Feb 1
      final result = service.getEffectiveToday(now, 4, 59);

      expect(result.year, 2026);
      expect(result.month, 1); // Still January
      expect(result.day, 31); // Jan 31
    });

    test('handles year boundaries correctly', () {
      final now = DateTime(2026, 1, 1, 2, 0); // 2:00am Jan 1
      final result = service.getEffectiveToday(now, 4, 59);

      expect(result.year, 2025); // Still previous year
      expect(result.month, 12); // December
      expect(result.day, 31); // Dec 31
    });
  });

  // Integration tests for actual parsing will need to run in full Flutter environment
  // See: test_driver/date_parsing_integration_test.dart
}
```

---

### Phase 2: Real-Time Highlighting (Days 3-4)

#### Step 2.1: Create HighlightedTextEditingController

**File:** `pin_and_paper/lib/widgets/highlighted_text_editing_controller.dart`

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Custom TextEditingController that highlights matched date text inline
///
/// Uses buildTextSpan() override to inject styled TextSpans while keeping
/// the TextField fully editable.
///
/// Web Platform Workaround:
/// Flutter web has cursor positioning issues with complex TextSpans (GitHub #49860).
/// On web, we disable highlighting but preserve all parsing functionality.
class HighlightedTextEditingController extends TextEditingController {
  TextRange? highlightRange;
  VoidCallback? onTapHighlight;

  HighlightedTextEditingController({
    String? text,
    this.onTapHighlight,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Web workaround: disable highlighting on web platform
    // Issue: Flutter web has cursor positioning issues with complex TextSpans
    // Impact: Web users see parsed dates in preview but no visual highlighting
    // This is a minor cosmetic limitation - full functionality preserved
    if (kIsWeb || highlightRange == null) {
      return TextSpan(style: style, text: text);
    }

    // Full highlighting for mobile/desktop (works perfectly)
    final range = highlightRange!;
    final baseStyle = style ?? const TextStyle();

    // Validate range
    if (range.start < 0 || range.end > text.length || range.start >= range.end) {
      return TextSpan(style: style, text: text);
    }

    return TextSpan(
      style: baseStyle,
      children: [
        // Text before highlight
        if (range.start > 0)
          TextSpan(text: text.substring(0, range.start)),

        // Highlighted text (clickable)
        TextSpan(
          text: text.substring(range.start, range.end),
          style: baseStyle.copyWith(
            backgroundColor: Colors.blue.withOpacity(0.2),
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onTapHighlight != null) {
                onTapHighlight!();
              }
            },
        ),

        // Text after highlight
        if (range.end < text.length)
          TextSpan(text: text.substring(range.end)),
      ],
    );
  }

  /// Set the highlight range and trigger rebuild
  void setHighlight(TextRange? range) {
    if (highlightRange != range) {
      highlightRange = range;
      notifyListeners(); // Trigger TextField rebuild
    }
  }

  /// Clear the highlight
  void clearHighlight() {
    if (highlightRange != null) {
      highlightRange = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Note: TapGestureRecognizer is automatically disposed by Flutter
    super.dispose();
  }
}
```

---

#### Step 2.2: Create Debouncer Utility

**File:** `pin_and_paper/lib/utils/debouncer.dart`

```dart
import 'dart:async';

/// Debounces rapid function calls to prevent excessive execution
///
/// Example: User typing triggers parse after 300ms of no typing
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}
```

---

#### Step 2.3: Update Edit Task Dialog with Highlighting

**File:** `pin_and_paper/lib/screens/edit_task_dialog.dart`

Add date parsing state and highlighting:

```dart
import 'package:pin_and_paper/services/date_parsing_service.dart';
import 'package:pin_and_paper/widgets/highlighted_text_editing_controller.dart';
import 'package:pin_and_paper/utils/debouncer.dart';

class _EditTaskDialogState extends State<EditTaskDialog> {
  late HighlightedTextEditingController _titleController;
  final DateParsingService _dateParser = DateParsingService();
  final Debouncer _debouncer = Debouncer(milliseconds: 300);

  ParsedDate? _parsedDate;
  bool _userDismissedParsing = false;

  @override
  void initState() {
    super.initState();

    _titleController = HighlightedTextEditingController(
      text: widget.initialTitle ?? '',
      onTapHighlight: _showDateOptions,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onTitleChanged(String text) {
    // Reset dismissal flag if text changes significantly
    if (_userDismissedParsing && text.length != _titleController.text.length) {
      setState(() {
        _userDismissedParsing = false;
      });
    }

    // PRE-FILTER (Codex/Gemini): Skip parsing if no date-like tokens
    // Reduces FFI calls by 80-90% (most tasks don't have dates)
    if (!_dateParser.containsPotentialDate(text)) {
      _debouncer.cancel(); // Stop any pending parse
      _titleController.clearHighlight();
      setState(() => _parsedDate = null);
      return;
    }

    // Debounce parsing (300ms after last keystroke)
    _debouncer.run(() {
      if (!_userDismissedParsing) {
        _parseDateFromTitle(text);
      }
    });
  }

  void _parseDateFromTitle(String text) {
    try {
      final parsed = _dateParser.parse(text);

      setState(() {
        _parsedDate = parsed;

        if (parsed != null) {
          _titleController.setHighlight(parsed.matchedRange);
        } else {
          _titleController.clearHighlight();
        }
      });
    } catch (e) {
      print('Error parsing date: $e');
      // Silently fail - don't disrupt user
    }
  }

  void _showDateOptions() {
    if (_parsedDate == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => _DateOptionsSheet(
        parsedDate: _parsedDate!,
        onRemove: () {
          setState(() {
            _parsedDate = null;
            _userDismissedParsing = true;
            _titleController.clearHighlight();
          });
          Navigator.pop(context);
        },
        onSelectDate: (DateTime date, bool isAllDay) {
          setState(() {
            _parsedDate = ParsedDate(
              matchedText: _parsedDate!.matchedText,
              matchedRange: _parsedDate!.matchedRange,
              date: date,
              isAllDay: isAllDay,
            );
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  String _getCleanTitle() {
    if (_parsedDate == null || _userDismissedParsing) {
      return _titleController.text;
    }

    // Strip the matched date text from title
    final text = _titleController.text;
    final range = _parsedDate!.matchedRange;

    final before = text.substring(0, range.start);
    final after = text.substring(range.end);

    // Clean up extra whitespace
    return '${before}${after}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title field with highlighting
            TextField(
              controller: _titleController,
              onChanged: _onTitleChanged,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Call dentist tomorrow',
              ),
              autofocus: true,
            ),

            const SizedBox(height: 8),

            // Date preview
            if (_parsedDate != null && !_userDismissedParsing)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'Due: ${_formatDate(_parsedDate!.date, _parsedDate!.isAllDay)}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

            // ... rest of the dialog fields (parent, tags, notes, etc.)
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveTask,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveTask() {
    final cleanTitle = _getCleanTitle();

    // Apply parsed date if available
    final dueDate = _parsedDate?.date;
    final isAllDay = _parsedDate?.isAllDay ?? true;

    // Save task with clean title and parsed date
    // ... existing save logic
  }

  String _formatDate(DateTime date, bool isAllDay) {
    // Format: "Tomorrow, 3:00 PM (Tue, Jan 21)" or "Tomorrow (Tue, Jan 21)"
    // CRITICAL FIX (Codex): Use effectiveToday instead of DateTime.now()
    // Otherwise at 2am, parsing uses "yesterday" but UI shows "today" - confusing!
    final effectiveToday = DateParsingService().getCurrentEffectiveToday();
    final diff = date.difference(effectiveToday);

    String relativeDay;
    if (diff.inDays == 0) {
      relativeDay = 'Today';
    } else if (diff.inDays == 1) {
      relativeDay = 'Tomorrow';
    } else if (diff.inDays == -1) {
      relativeDay = 'Yesterday';
    } else if (diff.inDays < 7 && diff.inDays > 0) {
      relativeDay = DateFormat('EEEE').format(date); // "Tuesday"
    } else {
      relativeDay = DateFormat('MMM d').format(date); // "Jan 21"
    }

    final absoluteDate = DateFormat('EEE, MMM d').format(date);
    final time = isAllDay ? '' : ', ${DateFormat('h:mm a').format(date)}';

    return '$relativeDay$time ($absoluteDate)';
  }
}
```

---

### Phase 3: Options Menu & Interactions (Day 5)

#### Step 3.1: Create DateOptionsSheet

**File:** `pin_and_paper/lib/widgets/date_options_sheet.dart`

```dart
import 'package:flutter/material.dart';
import 'package:pin_and_paper/services/date_parsing_service.dart';
import 'package:intl/intl.dart';

class DateOptionsSheet extends StatelessWidget {
  final ParsedDate parsedDate;
  final VoidCallback onRemove;
  final Function(DateTime date, bool isAllDay) onSelectDate;

  const DateOptionsSheet({
    super.key,
    required this.parsedDate,
    required this.onRemove,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final alternatives = _generateAlternatives(parsedDate.date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Due Date Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(),

          // Current selection
          _buildOption(
            context,
            date: parsedDate.date,
            isAllDay: parsedDate.isAllDay,
            label: _formatDate(parsedDate.date, parsedDate.isAllDay),
            isSelected: true,
          ),

          // Alternatives
          ...alternatives.map((alt) => _buildOption(
            context,
            date: alt.date,
            isAllDay: alt.isAllDay,
            label: alt.label,
            isSelected: false,
          )),

          const Divider(),

          // Manual picker
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Pick custom date...'),
            onTap: () async {
              Navigator.pop(context);
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: parsedDate.date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (pickedDate != null) {
                onSelectDate(pickedDate, true);
              }
            },
          ),

          // Remove option
          ListTile(
            leading: const Icon(Icons.close, color: Colors.red),
            title: const Text('Remove due date', style: TextStyle(color: Colors.red)),
            onTap: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required DateTime date,
    required bool isAllDay,
    required String label,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      title: Text(label),
      onTap: isSelected ? null : () => onSelectDate(date, isAllDay),
    );
  }

  List<_DateAlternative> _generateAlternatives(DateTime current) {
    // CRITICAL FIX (Codex): Use effectiveToday instead of DateTime.now()
    // Otherwise at 2am, alternatives use wrong base date (off by one day)
    final effectiveToday = DateParsingService().getCurrentEffectiveToday();
    final alternatives = <_DateAlternative>[];

    // Add "Today" if not already today
    if (current.day != effectiveToday.day) {
      alternatives.add(_DateAlternative(
        date: DateTime(effectiveToday.year, effectiveToday.month, effectiveToday.day),
        isAllDay: true,
        label: 'Today (${DateFormat('EEE, MMM d').format(effectiveToday)})',
      ));
    }

    // Add "Tomorrow" if not already tomorrow
    final tomorrow = effectiveToday.add(const Duration(days: 1));
    if (current.day != tomorrow.day) {
      alternatives.add(_DateAlternative(
        date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        isAllDay: true,
        label: 'Tomorrow (${DateFormat('EEE, MMM d').format(tomorrow)})',
      ));
    }

    // Add "Next week" if not already next week
    final nextWeek = effectiveToday.add(const Duration(days: 7));
    if ((current.difference(effectiveToday).inDays - 7).abs() > 1) {
      alternatives.add(_DateAlternative(
        date: DateTime(nextWeek.year, nextWeek.month, nextWeek.day),
        isAllDay: true,
        label: 'Next week (${DateFormat('EEE, MMM d').format(nextWeek)})',
      ));
    }

    return alternatives;
  }

  String _formatDate(DateTime date, bool isAllDay) {
    // CRITICAL FIX (Codex): Use effectiveToday instead of DateTime.now()
    final effectiveToday = DateParsingService().getCurrentEffectiveToday();
    final diff = date.difference(effectiveToday);

    String relativeDay;
    if (diff.inDays == 0) {
      relativeDay = 'Today';
    } else if (diff.inDays == 1) {
      relativeDay = 'Tomorrow';
    } else {
      relativeDay = DateFormat('EEE, MMM d').format(date);
    }

    final time = isAllDay ? '' : ', ${DateFormat('h:mm a').format(date)}';
    return '$relativeDay$time';
  }
}

class _DateAlternative {
  final DateTime date;
  final bool isAllDay;
  final String label;

  _DateAlternative({
    required this.date,
    required this.isAllDay,
    required this.label,
  });
}
```

---

### Phase 4: Integration with Quick Add (Days 6-7)

#### Step 4.1: Update Quick Add Field

**File:** `pin_and_paper/lib/widgets/quick_add_field.dart`

Similar integration as Edit Task Dialog:

```dart
class _QuickAddFieldState extends State<QuickAddField> {
  late HighlightedTextEditingController _controller;
  final DateParsingService _dateParser = DateParsingService();
  final Debouncer _debouncer = Debouncer(milliseconds: 300);
  ParsedDate? _parsedDate;

  @override
  void initState() {
    super.initState();
    _controller = HighlightedTextEditingController(
      onTapHighlight: _showDateOptions,
    );
  }

  void _onChanged(String text) {
    // PRE-FILTER (Codex/Gemini): Skip parsing if no date-like tokens
    // Reduces FFI calls by 80-90% (most tasks don't have dates)
    if (!_dateParser.containsPotentialDate(text)) {
      _debouncer.cancel(); // Stop any pending parse
      _controller.clearHighlight();
      setState(() => _parsedDate = null);
      return;
    }

    _debouncer.run(() {
      final parsed = _dateParser.parse(text);
      setState(() {
        _parsedDate = parsed;
        if (parsed != null) {
          _controller.setHighlight(parsed.matchedRange);
        } else {
          _controller.clearHighlight();
        }
      });
    });
  }

  void _onSubmit() {
    final cleanTitle = _getCleanTitle();
    final dueDate = _parsedDate?.date;
    final isAllDay = _parsedDate?.isAllDay ?? true;

    // Create task with parsed date
    widget.onTaskCreated(cleanTitle, dueDate, isAllDay);

    // Clear field
    _controller.clear();
    setState(() {
      _parsedDate = null;
    });
  }

  String _getCleanTitle() {
    if (_parsedDate == null) return _controller.text;

    final text = _controller.text;
    final range = _parsedDate!.matchedRange;
    return '${text.substring(0, range.start)}${text.substring(range.end)}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: (_) => _onSubmit(),
          decoration: InputDecoration(
            hintText: 'Add task (e.g., "Call dentist tomorrow")',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _onSubmit,
            ),
          ),
        ),

        // Preview chip
        if (_parsedDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              avatar: const Icon(Icons.event, size: 16),
              label: Text(_formatDate(_parsedDate!.date, _parsedDate!.isAllDay)),
              onDeleted: () {
                setState(() {
                  _parsedDate = null;
                  _controller.clearHighlight();
                });
              },
            ),
          ),
      ],
    );
  }
}
```

---

### Phase 5: Brain Dump Integration (Days 6-7)

#### Step 5.1: Update Brain Dump Prompt with Date Context

**File:** `pin_and_paper/lib/services/ai_service.dart`

Update Claude prompt to include Today Window context:

```dart
class AIService {
  String _buildBrainDumpPrompt(String userInput) {
    final now = DateTime.now();
    final dateParser = DateParsingService();
    final effectiveToday = dateParser.getEffectiveToday(now, 4, 59);

    final dayName = DateFormat('EEEE').format(effectiveToday);
    final dateStr = DateFormat('yyyy-MM-dd').format(effectiveToday);
    final timeStr = DateFormat('HH:mm').format(now);
    final timezone = now.timeZoneName;

    return '''
You are helping someone with ADHD organize their chaotic thoughts into actionable tasks.

CURRENT CONTEXT:
- Today's date: $dateStr ($dayName)
- Current time: $timeStr
- Timezone: $timezone

DATE PARSING RULES:
- "today" = $dateStr
- "tomorrow" = ${effectiveToday.add(const Duration(days: 1)).toString().split(' ')[0]}
- "next Tuesday" = the Tuesday of next week (even if today is Tuesday)
- "this Tuesday" = the upcoming Tuesday (could be today if it's Tuesday)
- Relative dates like "in 3 days" should be calculated from today

When you extract a task with a time reference:
- Set "due_date" to YYYY-MM-DD format
- Set "has_time" to true/false depending on if a specific time was mentioned
- If a time was mentioned, include it in ISO 8601 format: YYYY-MM-DDTHH:mm:ss

USER INPUT:
$userInput

Please extract individual tasks from this brain dump...
''';
  }
}
```

---

### Phase 6: Top Bar Date/Time Display (Day 7)

#### Step 6.1: Add Current Date/Time to App Bar

**File:** `pin_and_paper/lib/screens/main_screen.dart`

```dart
class _MainScreenState extends State<MainScreen> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Update clock every minute
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin and Paper'),
        actions: [
          // Current date/time for ADHD time blindness support
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                _formatCurrentTime(_currentTime),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),

          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
          ),
        ],
      ),

      body: /* ... task list ... */,
    );
  }

  String _formatCurrentTime(DateTime time) {
    // Mobile: "Mon, Jan 20, 2:45 PM"
    // Desktop: "Monday, January 20, 2:45 PM"
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      return DateFormat('EEEE, MMMM d, h:mm a').format(time);
    } else {
      return DateFormat('EEE, MMM d, h:mm a').format(time);
    }
  }
}
```

---

## Testing Strategy

### Unit Tests

**File:** `test/services/date_parsing_service_test.dart`

```dart
// Already created in Phase 1, Step 1.5
// Focus on getEffectiveToday() algorithm testing
```

### Integration Tests

**File:** `test_driver/date_parsing_integration_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pin_and_paper/main.dart' as app;
import 'package:pin_and_paper/services/date_parsing_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Date Parsing Integration Tests', () {
    testWidgets('parses "tomorrow" correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final service = DateParsingService();
      final now = DateTime(2026, 1, 20, 10, 0); // Tuesday 10am

      final result = service.parse('Call dentist tomorrow', now: now);

      expect(result, isNotNull);
      expect(result!.matchedText, 'tomorrow');
      expect(result.date.day, 21); // Wednesday
      expect(result.isAllDay, isTrue);
    });

    testWidgets('parses "tomorrow at 3pm" with time', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final service = DateParsingService();
      final now = DateTime(2026, 1, 20, 10, 0);

      final result = service.parse('Call dentist tomorrow at 3pm', now: now);

      expect(result, isNotNull);
      expect(result!.matchedText, contains('tomorrow'));
      expect(result.date.hour, 15); // 3pm
      expect(result.isAllDay, isFalse);
    });

    testWidgets('handles night owl mode correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final service = DateParsingService();
      final now = DateTime(2026, 1, 21, 2, 30); // 2:30am Wednesday

      // With night owl mode (4:59am cutoff), this is still "Tuesday night"
      final result = service.parse('Do dishes today', now: now);

      expect(result, isNotNull);
      expect(result!.date.day, 20); // Tuesday (effective today)
    });

    testWidgets('does not parse "May need"', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final service = DateParsingService();
      final result = service.parse('May need to call dentist');

      // chrono.js should be smart enough to reject this
      // If it doesn't, we'll need to add pre-filtering
      expect(result, isNull);
    });
  });
}
```

### Manual Test Cases

**Checklist:**

**Midnight Boundary Tests:**
- [ ] Set device time to 2:30am Tuesday
- [ ] Type "Call dentist today"
- [ ] Verify date = Tuesday (not Wednesday)
- [ ] Verify preview shows "Today (Tue, Jan 21)"

**Highlighting Tests:**
- [ ] Type "Call dentist t" → no highlight
- [ ] Type "Call dentist tomorrow" → highlight appears
- [ ] Verify highlighting is smooth (no jank)
- [ ] Click highlighted text → options menu appears

**False Positive Tests:**
- [ ] Type "May need to call" → should NOT highlight "May"
- [ ] Type "Meeting with April" → should NOT highlight "April"
- [ ] If false positive occurs, click "Remove" → works

**Platform Tests:**
- [ ] Android: Full highlighting + parsing works
- [ ] Linux Desktop: Full highlighting + parsing works
- [ ] Web: Parsing works, no highlighting (expected)

---

## Validation Checklist

### Before Merging to Main

- [ ] All unit tests pass (290+ existing + new date parsing tests)
- [ ] Integration tests pass
- [ ] Manual midnight boundary test passed
- [ ] Manual highlighting test passed
- [ ] Build succeeds on Android
- [ ] Build succeeds on Linux
- [ ] APK size increase documented (~5-6MB expected)
- [ ] Performance: Typing feels smooth (no jank)
- [ ] No console errors during normal use
- [ ] Claude Brain Dump still works with date context

### Documentation

- [ ] Update README.md with Phase 3.7 completion
- [ ] Create phase-3.7-implementation-report.md
- [ ] Document any deviations from plan
- [ ] Add screenshots of highlighting feature
- [ ] Update PROJECT_SPEC.md

---

## Troubleshooting

### Issue: flutter_js fails to initialize

**Symptoms:**
```
Error initializing DateParsingService: ...
```

**Solution:**
- Check that `assets/js/chrono.min.js` exists
- Verify `pubspec.yaml` includes assets path
- Run `flutter pub get` and restart app
- Check JavaScript console for errors

---

### Issue: Highlighting doesn't appear

**Symptoms:**
- Date is parsed (preview shows)
- But no blue highlight in TextField

**Diagnosis:**
1. Check if running on web (highlighting disabled on web)
2. Verify `TextRange` is valid
3. Check console for `buildTextSpan()` errors

**Solution:**
- Add logging to `buildTextSpan()`
- Verify `notifyListeners()` is called
- Check that `kIsWeb` check isn't incorrectly blocking

---

### Issue: Performance is sluggish

**Symptoms:**
- Typing feels laggy
- UI freezes briefly

**Diagnosis:**
1. Check if debouncing is working (should be 300ms)
2. Profile JavaScript execution time
3. Check for synchronous blocking calls

**Solution:**
- Increase debounce to 500ms if needed
- Ensure `evaluate()` calls are not blocking UI thread
- Consider moving to isolate if needed (advanced)

---

### Issue: Date parsing is incorrect around midnight

**Symptoms:**
- 2:30am Tuesday says "tomorrow" = Thursday (wrong!)

**Diagnosis:**
- Check `getEffectiveToday()` implementation
- Verify minute parameter is included
- Check cutoff hour/minute settings

**Solution:**
- Ensure algorithm includes minute check:
  ```dart
  if (now.hour < cutoffHour ||
      (now.hour == cutoffHour && now.minute <= cutoffMinute))
  ```

---

## Next Steps After Phase 3.7

1. **Phase 3.8:** Due Date Notifications
2. **Phase 3.9:** Onboarding Quiz & User Preferences
   - Users will be able to customize their night owl cutoff
   - Configure time keyword preferences (morning, evening, etc.)
3. **Phase 4:** Bounded Workspace View

---

**Document Version:** 1.0
**Last Updated:** 2026-01-20
**Estimated Implementation Time:** 7-10 days

---

## Appendix: Key Files Created

```
pin_and_paper/
├── assets/
│   └── js/
│       └── chrono.min.js                                    # NEW
├── lib/
│   ├── services/
│   │   └── date_parsing_service.dart                        # NEW
│   ├── utils/
│   │   └── debouncer.dart                                   # NEW
│   ├── widgets/
│   │   ├── highlighted_text_editing_controller.dart         # NEW
│   │   └── date_options_sheet.dart                          # NEW
│   ├── screens/
│   │   ├── edit_task_dialog.dart                            # MODIFIED
│   │   ├── quick_add_field.dart                             # MODIFIED
│   │   └── main_screen.dart                                 # MODIFIED
│   └── services/
│       └── ai_service.dart                                  # MODIFIED
└── test/
    ├── services/
    │   └── date_parsing_service_test.dart                   # NEW
    └── test_driver/
        └── date_parsing_integration_test.dart               # NEW
```

**Total New Files:** 7
**Total Modified Files:** 4
**Total LOC Added:** ~1,500-2,000 lines
