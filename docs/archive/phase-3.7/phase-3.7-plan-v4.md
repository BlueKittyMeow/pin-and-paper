# Phase 3.7 Plan - Natural Language Date Parsing

**Version:** 4
**Created:** 2026-01-20
**Status:** Ready for Implementation

---

## Changes from v3

**CRITICAL BLOCKERS RESOLVED:**

**✅ Blocker #1: Date Parsing Package**
- **v3 Problem:** Both `chrono_dart` and `any_date` had build/compatibility issues
- **v4 Solution:** Use `flutter_js` + `chrono.js` (JavaScript library via FFI)
  - Mature library (2.5k+ GitHub stars, 10+ years active)
  - Supports all required date formats
  - Cross-platform (QuickJS on Android/Windows/Linux, JavaScriptCore on iOS/macOS)
  - ~5-6MB APK overhead (acceptable for mature, battle-tested library)
  - Performance: Expected <5ms per parse (well within target)

**✅ Blocker #2: Real-Time Highlighting**
- **v3 Problem:** RichText widget is not editable
- **v4 Solution:** Override `TextEditingController.buildTextSpan()`
  - Keeps TextField fully editable
  - Supports inline highlighting + tap gestures
  - Web platform workaround: Use `kIsWeb` check to disable highlighting on web (minor cosmetic limitation)
  - Full functionality on mobile/desktop platforms

**🐛 Algorithm Bug Fix:**
- **v3 Problem:** `getEffectiveToday()` only checked hour, not minutes
- **v4 Fix:** Added `todayWindowMinutes` parameter for accurate cutoff (4:59am vs 4:00am)

**📉 Timeline Reduction:**
- **v3 Estimate:** 1.5-2 weeks (12-17 days) - included package evaluation and custom parser development
- **v4 Estimate:** 1-1.5 weeks (7-10 days) - mature library eliminates research phase

---

## Scope

Phase 3.7 adds natural language date parsing to Pin and Paper, allowing users to specify due dates using human-friendly phrases with real-time visual feedback.

**From PROJECT_SPEC.md:**
- Parse relative dates ("tomorrow", "next Tuesday", "in 3 days")
- Parse absolute dates ("Jan 15", "March 3rd")
- Time-of-day support ("3pm", "morning", "evening")
- Night owl mode (configurable midnight boundary)
- Integration with Brain Dump and task creation

**Parsing Scope:**
- ✅ Parse dates in task titles (real-time with inline highlighting)
- ✅ Extract date phrases and strip from title on save
- ❌ Do NOT parse dates in notes/descriptions (symbolic only, no linking yet)

**UX Pattern:**
- Real-time parsing as user types (debounced 300ms)
- Inline highlighting of matched date phrases (Todoist-style)
- Click highlighted text → options menu (edit/remove)
- Auto-apply on save (strip phrase, set due date)

---

## Motivation

**Current UX:**
- Users must tap date picker icon → select date → optionally select time
- Requires multiple taps and visual context switching
- Slower than typing, especially for common relative dates

**Improved UX:**
- Users can type naturally: "Fix bug tomorrow at 3pm"
- Parser detects date in real-time, highlights matched text: "Fix bug [tomorrow at 3pm]"
- Click highlight to edit, remove, or see alternatives
- Preview shows: "Tomorrow, 3:00 PM (Tue, Jan 21)"
- On save: title becomes "Fix bug", due date set
- Reduces friction for date entry during task capture

---

## The Midnight Problem (Critical Implementation Detail)

### Problem Statement

**From `docs/future/future.md`:**

Date parsing around midnight can be off by a full week if we're not careful. For night owl users working at 2:30am, saying "tomorrow" should mean "later today" not "in 4 hours."

**Scenarios:**

1. **Late Monday Night (11:50 PM Monday)**
   - User types: "tomorrow"
   - User expects: Tuesday
   - System time: Monday 11:50 PM
   - ✅ Correct: Tuesday (no issue)

2. **Just After Midnight (12:05 AM Tuesday)**
   - User types: "tomorrow"
   - System time: Tuesday 12:05 AM
   - System thinks tomorrow = Wednesday
   - ❌ Problem: Night owl user still thinks it's "Monday night"
   - ❌ User expects: Tuesday (today)
   - ✅ System would give: Wednesday (wrong!)

3. **Week-Based Parsing**
   - Monday 11:50 PM: "next Tuesday" should be Tuesday in 8 days
   - Tuesday 12:05 AM: "next Tuesday" could mean:
     - Option A: Tuesday (today, 0 days) ← if user considers it "still Monday night"
     - Option B: Next Tuesday (7 days) ← if user considers it Tuesday

### Solution: "Today Window" Configuration

**Algorithm (FIXED in v4):**
```dart
DateTime getEffectiveToday(
  DateTime now,
  int todayWindowHours,
  int todayWindowMinutes, // v4: Added minute parameter
) {
  if (now.hour < todayWindowHours ||
      (now.hour == todayWindowHours && now.minute <= todayWindowMinutes)) {
    // We're in the "still yesterday" window
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}
```

**Settings:**
- `today_cutoff_hour`: Default 4 (4am is still "tonight")
- `today_cutoff_minute`: Default 59 (4:59am cutoff)
- User configurable via onboarding quiz (Question 1, Question 9)

**Default if quiz skipped:** 4:59am cutoff (moderate night owl mode)

**UI Options (from onboarding-quiz.md):**
- Midnight (12:00 AM) - Strict calendar boundaries
- 3:00 AM - Moderate night owl mode
- 6:00 AM - Extreme night owl mode
- Custom - User specifies exact time

---

## Integration with Onboarding Quiz

**From `docs/future/onboarding-quiz.md`:**

Date parsing behavior is configured through the onboarding quiz, not manual settings.

**Relevant Questions:**

**Question 1 (Circadian Rhythm Detection):**
> "It's 2:30am on Saturday and you haven't fallen asleep yet. You remark to someone that you'll wash the dishes 'tomorrow.' Do you mean Saturday or Sunday?"
- **A: Saturday** → Sets `today_cutoff_hour = 4` or `5` (night owl mode)
- **B: Sunday** → Sets `today_cutoff_hour = 0` (midnight purist)

**Question 7 (Quick Add Date Parsing):**
> "When you type 'Call dentist Jan 15' in the quick-add field, what should happen?"
- **A: Automatically detect the date** → Sets `enable_quick_add_date_parsing = 1` (default)
- **B: Keep it simple** → Sets `enable_quick_add_date_parsing = 0`

**Question 9 (Sleep Schedule):**
> "On a usual day, what time do you fall asleep?"
- Cross-validates Q1, refines `today_cutoff_hour`
- A: Before midnight → Early sleeper
- B: 12am-2am → Moderate night owl (4am cutoff)
- C: 2am-4am → Strong night owl (5am cutoff)
- D: 4am+ / Varies → Extreme night owl (6am cutoff)

**Implementation Note:**
- Onboarding quiz is Phase 4+ feature
- Phase 3.7: Use hardcoded default (4:59am cutoff) for now
- Phase 4+: Read from user settings configured by quiz
- Users can always skip quiz and use defaults

---

## UX Mockups & Interaction Flows

### Real-Time Parsing with Todoist-Style Highlighting

**Typing Experience:**

```
User types: "Call dentist t"
┌─────────────────────────────────────────┐
│ Title                                   │
│ Call dentist t█                        │ ← No highlight yet
│                                         │
└─────────────────────────────────────────┘

User types: "Call dentist tomorrow"
┌─────────────────────────────────────────┐
│ Title                                   │
│ Call dentist [tomorrow]                │ ← "tomorrow" highlighted
│              └─ Click to edit          │   (blue background, clickable)
│                                         │
│ Due Date: Tomorrow (Tue, Jan 21)       │ ← Auto-preview appears
└─────────────────────────────────────────┘
```

**Highlighting Style:**
- Light blue background (opacity 0.2)
- Blue text color (for contrast)
- Slightly rounded corners
- Subtle, non-intrusive
- Tappable/clickable

---

### Click Highlighted Text → Options Menu

```
User clicks on [tomorrow]:

┌─────────────────────────────────────────┐
│ Title                                   │
│ Call dentist [tomorrow]                │ ← Still highlighted
│                                         │
│ Due Date Options:                       │
│ ┌─────────────────────────────────────┐ │
│ │ ✓ Tomorrow (Tue, Jan 21)           │ │ ← Currently selected
│ │   Today (Mon, Jan 20)              │ │ ← Alternative (if applicable)
│ │   Next Week (Mon, Jan 27)          │ │ ← Alternative
│ │   ───────────────────────────────   │ │
│ │   📅 Pick custom date...           │ │ ← Manual picker
│ │   ✕ Remove due date                │ │ ← Clear entirely
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Menu Behavior:**
- Modal/dropdown overlay
- Checkmark shows current selection
- Click alternative → update preview, close menu
- Click "Pick custom date" → open date picker dialog
- Click "Remove" → un-highlight text, clear preview, close menu

---

### False Positive Example (Scenario 2)

```
User types: "May need to call dentist"

┌─────────────────────────────────────────┐
│ Title                                   │
│ [May] need to call dentist             │ ← "May" highlighted (WRONG!)
│  ^^^                                    │
│                                         │
│ Due Date: May 1, 2026                  │ ← Parser misinterpreted
└─────────────────────────────────────────┘

User notices: "Wait, 'May' is part of my sentence!"

User clicks [May]:
┌─────────────────────────────────────────┐
│ Due Date Options:                       │
│ ┌─────────────────────────────────────┐ │
│ │ ✓ May 1, 2026                      │ │
│ │   May 2026 (month only)            │ │
│ │   ───────────────────────────────   │ │
│ │   📅 Pick custom date...           │ │
│ │   ✕ Remove due date                │ │ ← User clicks this
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

After clicking "Remove":
┌─────────────────────────────────────────┐
│ Title                                   │
│ May need to call dentist               │ ← No highlight
│                                         │
│                                         │ ← No preview
└─────────────────────────────────────────┘

On save:
  → Title unchanged: "May need to call dentist"
  → No due date applied
```

**Key UX principle:** Easy one-click escape from false positives.

---

### Combined Date + Time Example

```
User types: "Fix bug tomorrow at 3pm"

┌─────────────────────────────────────────┐
│ Title                                   │
│ Fix bug [tomorrow at 3pm]              │ ← Full phrase highlighted
│         └─ Click to edit                │
│                                         │
│ Due Date: Tomorrow, 3:00 PM (Tue, Jan 21) │ ← Shows time
└─────────────────────────────────────────┘

On save:
  → Title: "Fix bug"
  → Due date: 2026-01-21 15:00
  → isAllDay: false
```

---

### Current Date/Time in Top Bar

```
┌────────────────────────────────────────────────────┐
│ Pin and Paper       Today: Mon, Jan 20, 2:45 PM   │ ← Top bar
├────────────────────────────────────────────────────┤
│                                                    │
│ [Screen content]                                   │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Purpose:**
- Reference point for ADHD time blindness
- User can verify relative dates
- Updates in real-time (every minute)
- Subtle, non-distracting

**Format:**
- Full format: "Monday, January 20, 2:45 PM"
- Short format (mobile): "Mon, Jan 20, 2:45 PM"
- Updates every minute
- Shows current timezone (implicit from device)

---

### Invalid Date Error (Scenario 1)

```
User types: "Meeting on Feb 30"

┌─────────────────────────────────────────┐
│ Title                                   │
│ Meeting on [Feb 30]                    │ ← Highlighted
│            └─ Click to edit             │
│                                         │
│ ⚠️ Due Date: Feb 30 is invalid         │ ← Error message
│    Did you mean Feb 28 or Mar 2?       │
└─────────────────────────────────────────┘

User clicks [Feb 30]:
┌─────────────────────────────────────────┐
│ Due Date Options:                       │
│ ┌─────────────────────────────────────┐ │
│ │   Feb 28, 2026                     │ │ ← Suggestions
│ │   Mar 2, 2026                      │ │
│ │   ───────────────────────────────   │ │
│ │   📅 Pick custom date...           │ │
│ │   ✕ Remove due date                │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Error Handling:**
- Show error in preview area
- Offer smart corrections (last valid day of month, next valid date)
- Track occurrences (if too noisy, switch to silent rejection)
- Still allow manual date picker as fallback

---

## Technical Approach

### Dual Parsing Strategy: Brain Dump vs Direct Input

**Brain Dump (Claude Parses):**
```
User: "Need to call dentist tomorrow and maybe schedule
       checkup for next week and remind mom about her
       appointment on the 15th"

       ↓ Send to Claude (already paying for API call)

Claude extracts:
  1. "Call dentist" → due: tomorrow
  2. "Schedule checkup" → due: next week
  3. "Remind mom about appointment" → due: 15th

✅ Full context preserved
✅ Multiple tasks + dates matched correctly
✅ No compute concerns (already using API)
```

**Quick Add / Edit Dialog (Local Parses):**
```
User types: "Fix bug tomorrow at 3pm"

       ↓ Local parser (debounced 300ms)

Local parser (flutter_js + chrono.js):
  - Detects "tomorrow at 3pm"
  - Highlights in real-time
  - Calculates date using Today Window
  - Shows preview

✅ Real-time feedback (<5ms parse time)
✅ Free (no API cost)
✅ Offline capable
✅ Single task context (simpler than multi-task Brain Dump)
```

**Separation Rationale:**
- No conflicts (different use cases)
- No duplication (Claude for Brain Dump, local for direct input)
- Optimal compute usage (local when possible, Claude when needed)
- Each tool optimized for its context

**Important:** We need to be careful about Claude model selection and context. Send effective date information so Claude calculates correctly:

```dart
// Context sent to Claude for Brain Dump
final effectiveToday = getEffectiveToday(
  DateTime.now(),
  settings.todayCutoffHour,
  settings.todayCutoffMinute, // v4: Added minute parameter
);

String claudePrompt = """
You are helping someone with ADHD organize their thoughts...

CURRENT CONTEXT:
- Today's date: ${effectiveToday.toLocal().toString().split(' ')[0]}
- Current time: ${DateTime.now().toLocal().toString().split(' ')[1].substring(0, 5)}
- User's timezone: ${DateTime.now().timeZoneName}
- Day of week: ${_getDayName(effectiveToday.weekday)}

DATE PARSING RULES:
- "today" = ${effectiveToday.toLocal().toString().split(' ')[0]}
- "tomorrow" = ${effectiveToday.add(Duration(days: 1)).toLocal().toString().split(' ')[0]}
- "next Tuesday" = the Tuesday of next week (even if today is Tuesday)
- "this Tuesday" = the upcoming Tuesday (could be today if it's Tuesday)
- Relative dates like "in 3 days" should be calculated from today

When you extract a task with a time reference, set "due_date" to YYYY-MM-DD format.
""";
```

---

## Date Parsing Strategy (v4: RESOLVED)

### Solution: flutter_js + chrono.js

**Package:** `flutter_js` (^0.9.1)
- FFI wrapper for JavaScript execution
- QuickJS on Android/Windows/Linux
- JavaScriptCore on iOS/macOS
- Minimal overhead, production-ready

**Library:** `chrono.js` (bundled)
- Mature natural language date parser (2.5k+ GitHub stars)
- 10+ years of active development
- Supports all required patterns:
  - Relative dates: "tomorrow", "next Tuesday", "in 3 days"
  - Absolute dates: "Jan 15", "March 3rd", "2026-01-20"
  - Time parsing: "3pm", "9:30am", "at 3pm"
  - Combined: "tomorrow at 3pm"
  - Context-aware disambiguation

**Performance:**
- Expected: <5ms per parse
- Target: <10ms (acceptable for debounced 300ms UI)
- Cold start: ~10-20ms (one-time initialization)
- Warm subsequent calls: ~1-5ms

**Integration Pattern:**

```dart
import 'package:flutter_js/flutter_js.dart';

class DateParsingService {
  late JavascriptRuntime jsRuntime;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    jsRuntime = getJavascriptRuntime();

    // Load chrono.js bundle (bundled as asset)
    final chronoSource = await rootBundle.loadString('assets/js/chrono.min.js');
    jsRuntime.evaluate(chronoSource);

    _initialized = true;
  }

  ParsedDate? parse(String text, DateTime now) {
    if (!_initialized) {
      throw StateError('DateParsingService not initialized');
    }

    // Calculate effective today for Today Window
    final effectiveToday = getEffectiveToday(
      now,
      _settings.todayCutoffHour,
      _settings.todayCutoffMinute,
    );

    // Pass effective date to chrono as reference
    final result = jsRuntime.evaluate('''
      (function() {
        const referenceDate = new Date("${effectiveToday.toIso8601String()}");
        const parsed = chrono.parse("$text", referenceDate, { forwardDate: true });

        if (parsed.length === 0) return null;

        const match = parsed[0];
        return JSON.stringify({
          text: match.text,
          index: match.index,
          date: match.start.date().toISOString(),
          hasTime: match.start.isCertain('hour')
        });
      })();
    ''');

    if (result.stringResult == 'null') return null;

    final json = jsonDecode(result.stringResult);
    return ParsedDate(
      matchedText: json['text'],
      matchedRange: TextRange(
        start: json['index'],
        end: json['index'] + (json['text'] as String).length,
      ),
      date: DateTime.parse(json['date']),
      isAllDay: !(json['hasTime'] as bool),
    );
  }
}
```

**Assets Setup:**

```yaml
# pubspec.yaml
dependencies:
  flutter_js: ^0.9.1

flutter:
  assets:
    - assets/js/chrono.min.js  # Bundled chrono.js library
```

**APK Size Impact:**
- flutter_js: ~3-4MB (QuickJS engine)
- chrono.min.js: ~2-3MB (bundled library)
- Total: ~5-6MB APK size increase
- **Justification:** Mature, battle-tested library saves weeks of development + maintenance

**Advantages:**
- ✅ Zero development time for parser logic
- ✅ Mature library with 10+ years of testing
- ✅ Built-in context-aware disambiguation
- ✅ Cross-platform (all Flutter targets)
- ✅ Supports all required date formats
- ✅ Works offline (bundled, no API calls)

**Trade-offs:**
- ⚠️ ~5-6MB APK overhead (acceptable for productivity app)
- ⚠️ JavaScript bridge adds ~5ms latency (still within <10ms target)
- ⚠️ Slightly more complex setup (asset bundling, initialization)

---

## Real-Time Parsing Implementation (v4: RESOLVED)

### Solution: TextEditingController.buildTextSpan() Override

**Problem with RichText (v3):**
- RichText widget is NOT editable
- Cannot receive focus or cursor input
- Would require complex custom TextField implementation

**Solution (v4):**
Override `TextEditingController.buildTextSpan()` to inject highlighted TextSpans while keeping TextField fully functional.

**Implementation:**

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HighlightedTextEditingController extends TextEditingController {
  TextRange? highlightRange;
  VoidCallback? onTapHighlight;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Web workaround: disable highlighting on web platform
    // Issue: Flutter web has cursor positioning issues with complex TextSpans
    // Impact: Web users see parsed dates but no visual highlighting (minor cosmetic limitation)
    if (kIsWeb || highlightRange == null) {
      return TextSpan(style: style, text: text);
    }

    // Full highlighting for mobile/desktop (works perfectly)
    final range = highlightRange!;
    final baseStyle = style ?? const TextStyle();

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

  void setHighlight(TextRange? range) {
    highlightRange = range;
    notifyListeners(); // Trigger rebuild
  }

  void clearHighlight() {
    highlightRange = null;
    notifyListeners();
  }
}
```

**Usage in Edit Task Dialog:**

```dart
class _EditTaskDialogState extends State<EditTaskDialog> {
  late HighlightedTextEditingController _titleController;
  final DateParsingService _dateParser = DateParsingService();
  Timer? _debounce;
  ParsedDate? _parsedDate;

  @override
  void initState() {
    super.initState();
    _titleController = HighlightedTextEditingController();
    _titleController.onTapHighlight = _showDateOptions;
    _titleController.text = widget.initialTitle;
    _dateParser.initialize();
  }

  void _onTitleChanged(String text) {
    // Debounce parsing (300ms)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final parsed = _dateParser.parse(text, DateTime.now());

      setState(() {
        _parsedDate = parsed;
        if (parsed != null) {
          _titleController.setHighlight(parsed.matchedRange);
        } else {
          _titleController.clearHighlight();
        }
      });
    });
  }

  void _showDateOptions() {
    // Show modal bottom sheet with alternatives, remove option, etc.
    showModalBottomSheet(
      context: context,
      builder: (context) => DateOptionsSheet(
        currentDate: _parsedDate?.date,
        onRemove: () {
          setState(() {
            _parsedDate = null;
            _titleController.clearHighlight();
          });
          Navigator.pop(context);
        },
        // ... other options
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          onChanged: _onTitleChanged,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'e.g., Call dentist tomorrow',
          ),
        ),

        // Preview
        if (_parsedDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Due Date: ${_formatDate(_parsedDate!.date)}',
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
      ],
    );
  }
}
```

**Web Platform Workaround:**
- Web has cursor positioning issues with complex TextSpans ([Flutter issue #49860](https://github.com/flutter/flutter/issues/49860))
- Workaround: Use `kIsWeb` check to disable highlighting on web
- Impact: Web users still get date parsing, just no visual highlight (minor cosmetic limitation)
- Preview still shows parsed date below field
- Future: Can revisit when Flutter web fixes TextSpan cursor issues

**Performance:**
- buildTextSpan() called on every rebuild
- Must be <1ms for smooth UI
- TextSpan creation is fast (simple string slicing)
- No performance concerns

**Advantages:**
- ✅ TextField remains fully editable
- ✅ Cursor, selection, focus all work normally
- ✅ Tap gestures on highlighted text work
- ✅ Simple implementation (~50 lines)
- ✅ Platform-specific workarounds possible (kIsWeb)

**Trade-offs:**
- ⚠️ Web platform has minor cosmetic limitation (no highlighting)
- ⚠️ Must rebuild on every highlight change (acceptable with notifyListeners)

---

## Parser Features

**Must Support:**
1. **Relative dates**: today, tomorrow, yesterday, tonight
2. **Days of week**: Monday, Tuesday, next Monday, this Friday
3. **Relative offsets**: in 3 days, in 2 weeks, in 1 month
4. **Absolute dates**: Jan 15, March 3rd, 2026-01-20, 1/20/2026
5. **Time of day**: 3pm, 9:30am, 15:00, morning, afternoon, evening, tonight
6. **Combined**: tomorrow at 3pm, next Tuesday morning, Jan 15 at 2pm

**Must Handle:**
1. **Today Window logic**: Use `getEffectiveToday()` for all relative date calculations
2. **Month/year boundaries**: "tomorrow" on Dec 31 → Jan 1 next year
3. **Ambiguity**: Past dates → assume next occurrence (e.g., "Jan 3" in February → next year)
4. **Multiple dates**: Extract first occurrence only
5. **Case insensitive**: "Tomorrow", "TOMORROW", "tomorrow" all work
6. **Context awareness**: Skip false positives (chrono.js handles this)

**Extraction Behavior:**
```dart
// Input: "Fix bug tomorrow at 3pm"
// Output:
//   cleanTitle: "Fix bug"                    (stripped)
//   matchedText: "tomorrow at 3pm"           (what was matched)
//   matchedRange: TextRange(start: 8, end: 25) (position for highlighting)
//   dueDate: DateTime(2026, 1, 21, 15, 0)    (Tomorrow at 3pm)
//   isAllDay: false

// Input: "Call dentist next Tuesday"
// Output:
//   cleanTitle: "Call dentist"
//   matchedText: "next Tuesday"
//   matchedRange: TextRange(start: 14, end: 26)
//   dueDate: DateTime(2026, 1, 28, 0, 0)     (Next Tuesday)
//   isAllDay: true                            (No time specified)
```

---

## Integration Points

**1. DateParsingService (Core Service)**
- Initialize flutter_js runtime
- Load chrono.js bundle
- Method: `ParsedDate? parse(String text, {DateTime? now})`
- Returns: `ParsedDate(cleanTitle, matchedText, matchedRange, dueDate, isAllDay)` or null
- Uses: `getEffectiveToday()` for Today Window logic

**2. Edit Task Dialog**
- Use HighlightedTextEditingController
- Real-time parsing as user types (debounced 300ms)
- Inline highlighting of matched date phrases
- Click highlight → options menu
- Preview below title field: "Tomorrow (Tue, Jan 21)"
- Manual date picker still available as button
- Strip matched text on save (if not dismissed)

**3. Brain Dump (AI Integration)**
- Send effective date context to Claude (from future.md algorithm)
- Claude parses dates AND matches them to extracted tasks
- No local parsing (Claude has full context, already using API)
- Include Today Window effective date in prompt

**4. Quick Add Field (Task List)**
- Real-time date parsing as user types
- Inline highlighting (same as edit dialog)
- Preview chip appears: "Tomorrow, 3pm"
- Hit Enter → create task with parsed date, stripped title
- Respects `enable_quick_add_date_parsing` setting (from Quiz Q7)

**5. Top Bar (Global)**
- Display current date/time: "Mon, Jan 20, 2:45 PM"
- Updates every minute
- Subtle, non-distracting
- Provides reference point for ADHD time blindness

---

## Database & Settings

**No schema changes needed!** Phase 3.4 already added:
- `tasks.due_date` (INTEGER, Unix timestamp)
- `tasks.is_all_day` (INTEGER, 0 or 1)

**Settings to add** (in `user_settings` table or SharedPreferences):
```sql
-- Today Window settings
today_cutoff_hour INTEGER DEFAULT 4,
today_cutoff_minute INTEGER DEFAULT 59,  -- v4: Added

-- Parsing preferences
enable_quick_add_date_parsing INTEGER DEFAULT 1,

-- Time keyword mappings (for "morning", "afternoon", etc.)
morning_hour INTEGER DEFAULT 9,
afternoon_hour INTEGER DEFAULT 15,
evening_hour INTEGER DEFAULT 19,
tonight_hour INTEGER DEFAULT 19,
```

**Phase 3.7 Implementation:**
- Hardcode defaults (4:59am cutoff, parsing enabled)
- Store settings in SharedPreferences for now
- Phase 4+: Migrate to proper settings table, configure via onboarding quiz

---

## Testing Strategy

### Unit Tests (DateParsingService)

**Relative Dates:**
- today, tomorrow, yesterday, tonight
- With Today Window: 2:30am test cases (critical!)
- Month boundaries (Dec 31 → Jan 1)
- Year boundaries (Dec 31 2026 → Jan 1 2027)

**Days of Week:**
- Monday, Tuesday, etc. (next occurrence)
- next Monday, this Friday
- Edge case: "Monday" on Monday (should be next Monday, not today)
- Week boundaries with Today Window

**Absolute Dates:**
- Jan 15, January 15, 1/15, 1/15/2026, 2026-01-15
- March 3rd, Dec 1st (ordinal numbers)
- Past dates → assume next occurrence
- Invalid dates (Feb 30, Month 13) → return null with error

**Time Parsing:**
- 3pm, 9:30am, 15:00, 0930
- morning, afternoon, evening, tonight
- Named times respect settings (morning_hour, etc.)
- 12-hour vs 24-hour format

**Combined:**
- tomorrow at 3pm
- next Tuesday morning
- Jan 15 at 2pm
- in 3 days at 5pm

**Midnight Boundary Tests (CRITICAL!):**
```dart
// Monday 11:50 PM, cutoff 4:59am
// effectiveToday = Monday
// "tomorrow" → Tuesday (correct)
test('tomorrow before midnight', () {
  final now = DateTime(2026, 1, 20, 23, 50); // Mon 11:50 PM
  final parsed = dateParser.parse("tomorrow", now: now);
  expect(parsed!.date.day, 21); // Tuesday
});

// Tuesday 12:05 AM, cutoff 4:59am
// effectiveToday = Monday (still yesterday)
// "tomorrow" → Tuesday (correct!)
test('tomorrow after midnight in today window', () {
  final now = DateTime(2026, 1, 21, 0, 5); // Tue 12:05 AM
  final parsed = dateParser.parse("tomorrow", now: now);
  expect(parsed!.date.day, 21); // Tuesday (not Wednesday!)
});

// Tuesday 5:00 AM, cutoff 4:59am
// effectiveToday = Tuesday (now today)
// "tomorrow" → Wednesday (correct)
test('tomorrow after today window', () {
  final now = DateTime(2026, 1, 21, 5, 0); // Tue 5:00 AM
  final parsed = dateParser.parse("tomorrow", now: now);
  expect(parsed!.date.day, 22); // Wednesday
});
```

**Edge Cases:**
- Empty string → null
- No date found → null
- Multiple dates → extract first only
- Malformed dates (Feb 30) → null with error message
- Ambiguous dates → chrono.js handles

---

### Integration Tests

- DateParsingService initialization and parsing
- Edit dialog real-time parsing and highlighting
- Click highlighted text → options menu flow
- Brain Dump date extraction (Claude context)
- Quick Add field parsing
- Top bar date/time display updates

---

### Manual Testing

**Midnight Workflow (Critical!):**
1. Set device time to 2:30am Tuesday
2. Type "Call dentist tomorrow"
3. Verify due date = Tuesday (not Wednesday!)
4. Verify preview shows "Tomorrow (Tue, Jan 21)"

**False Positive Handling:**
1. Type "May need to call dentist"
2. If "May" highlights (false positive)
3. Click highlighted "May"
4. Select "Remove due date"
5. Verify title unchanged, no date applied

**Real-Time Parsing:**
1. Type "Call dentist t" → no highlight yet
2. Type "Call dentist to" → no highlight yet
3. Type "Call dentist tomorrow" → highlight appears
4. Verify highlighting smooth (no jank)
5. Verify preview appears: "Tomorrow (Tue, Jan 21)"

**Performance Testing:**
- Type rapidly → debouncing works
- Parse complex phrases → <10ms
- UI remains responsive

**Web Platform Testing:**
- Test on Chrome/Firefox/Safari
- Verify parsing works (preview appears)
- Verify no highlighting (expected limitation)
- Verify cursor/selection works normally

---

## Implementation Plan (v4: UPDATED)

**Phase 1: flutter_js + chrono.js Setup (Days 1-2)**
1. Add flutter_js dependency to pubspec.yaml
2. Download and bundle chrono.min.js as asset
3. Create DateParsingService class
4. Implement initialization and basic parse() method
5. Unit tests for basic parsing (today, tomorrow, absolute dates)
6. Verify Today Window integration with getEffectiveToday()

**Phase 2: Real-Time Highlighting (Days 3-4)**
1. Create HighlightedTextEditingController class
2. Implement buildTextSpan() override
3. Add web platform workaround (kIsWeb check)
4. Implement debounced parsing (300ms)
5. Add preview display below title field
6. Test highlighting on mobile, desktop, web

**Phase 3: Options Menu & Interactions (Day 5)**
1. Click highlighted text → modal bottom sheet
2. Show current parsed date + alternatives
3. Remove due date option
4. Manual picker integration
5. Smooth animations and UX polish

**Phase 4: Integration (Days 6-7)**
1. Integrate with edit task dialog
2. Integrate with quick add field
3. Brain Dump: Send Claude effective date context
4. Top bar: Current date/time display
5. Settings storage (SharedPreferences)

**Phase 5: Testing & Refinement (Days 8-9)**
1. Comprehensive unit tests (midnight boundary cases)
2. Integration tests
3. Manual testing (midnight workflow, false positives, locales)
4. Performance testing (<10ms parse, smooth UI)
5. Bug fixes and edge case handling

**Phase 6: Validation & Documentation (Day 10)**
1. End-of-phase validation
2. Implementation report
3. Update PROJECT_SPEC.md and README.md
4. Archive Phase 3.7 docs

**Total:** 10 days (1-1.5 weeks)

---

## Success Criteria

**Must Have (MVP):**
- ✅ Parse common relative dates (today, tomorrow, yesterday, tonight)
- ✅ Parse days of week (Monday, Tuesday, next Monday)
- ✅ Parse absolute dates (Jan 15, March 3rd, 2026-01-20)
- ✅ Time-of-day parsing (3pm, morning, evening)
- ✅ Today Window logic (night owl mode support with minute precision)
- ✅ Real-time parsing with debouncing (300ms)
- ✅ Todoist-style inline highlighting (mobile/desktop)
- ✅ Click highlight → options menu (alternatives + remove)
- ✅ Auto-strip date phrases on save
- ✅ Full absolute date format: "Tomorrow (Tue, Jan 21)"
- ✅ Current date/time in top bar
- ✅ Integration with edit dialog and quick add
- ✅ Comprehensive tests (including midnight boundary tests)
- ✅ Works correctly across month/year boundaries

**Should Have:**
- ✅ Combined date + time ("tomorrow at 3pm")
- ✅ Relative dates with offsets ("in 3 days", "in 2 weeks")
- ✅ Integration with Brain Dump (Claude context)
- ✅ Performance: <10ms parse time, smooth UI
- ✅ Web platform graceful degradation (parsing works, no highlight)

**Nice to Have (Post-MVP):**
- Error messages for invalid dates (Feb 30, etc.)
- Re-trigger parsing if text changes after dismissal
- Locale-aware date parsing (US/European formats)
- More time keyword mappings (dawn, dusk, noon, etc.)

**Out of Scope (Defer to Future):**
- ❌ Recurring dates ("every Monday")
- ❌ Date ranges ("Jan 10-15")
- ❌ Natural language relative times ("in 30 minutes")
- ❌ Date parsing in task notes/descriptions
- ❌ Full onboarding quiz implementation (Phase 4+)
- ❌ User-configurable night owl settings UI (Phase 4+)

---

## Timeline Estimate (v4: UPDATED)

**Estimated Duration:** 1-1.5 weeks (7-10 days)

**Breakdown:**
1. flutter_js + chrono.js setup: 1-2 days
2. Real-time highlighting (buildTextSpan): 1-2 days
3. Options menu + interactions: 1 day
4. Integration with dialogs: 1-2 days
5. Testing & refinement: 2-3 days
6. Validation & documentation: 1 day

**Total:** 7-10 days

**v3 vs v4 Timeline:**
- v3: 12-17 days (package evaluation + custom parser development)
- v4: 7-10 days (mature library eliminates research/development)
- **Savings:** ~5-7 days (40-50% reduction)

**Critical Path:** Setup flutter_js → Implement highlighting → Integration → Testing

---

## Dependencies

### External Packages

**New in v4:**
- `flutter_js: ^0.9.1` - JavaScript runtime for Flutter
- `chrono.js` (bundled as asset) - Natural language date parser

**Already included:**
- `intl` - Date formatting
- `shared_preferences` - Settings storage

### Existing Code

- Phase 3.6.5: Time picker infrastructure (`isAllDay` field)
- Phase 3.4: Due date storage (`due_date` field)
- Phase 2: Brain Dump AI integration (task extraction)
- Phase 3.6B: Quick Add field (task list)

### System Dependencies

- User's locale settings (for date format interpretation)
- System timezone (for "today"/"tomorrow" calculation)
- Device time (for Today Window calculations)

---

## Related Documents

- [PROJECT_SPEC.md](../PROJECT_SPEC.md) - Phase 3.7 official scope
- [docs/future/future.md](../future/future.md) - Midnight Problem research & Today Window algorithm
- [docs/future/onboarding-quiz.md](../future/onboarding-quiz.md) - Quiz integration details
- [archive/phase-3.6.5/phase-3.6.5-implementation-report.md](../../archive/phase-3.6.5/phase-3.6.5-implementation-report.md) - Previous phase context
- [codex-findings.md](./codex-findings.md) - Package evaluation & context-aware parsing research
- [gemini-findings.md](./gemini-findings.md) - Build testing & performance validation
- [claude-findings.md](./claude-findings.md) - Validation of codex/gemini findings, alternative solutions
- [templates/phase-start-checklist.md](../templates/phase-start-checklist.md) - Workflow reference

---

## Notes

- Phase 3.7 is the penultimate phase before Phase 3 completion
- Today Window logic is critical for night owl users (common in ADHD community)
- Real-time parsing with Todoist-style UX is gold standard
- flutter_js + chrono.js eliminates weeks of custom parser development
- buildTextSpan() override keeps TextField editable (critical for UX)
- Web platform limitation (no highlighting) is minor cosmetic issue, full functionality preserved
- Default settings work for most users; onboarding quiz fine-tunes in Phase 4+
- Performance is non-negotiable: must be <10ms parse, smooth UI
- Current date/time in top bar helps with ADHD time blindness

---

**Status:** Ready for implementation.

**Next Steps:**
1. Add flutter_js dependency and bundle chrono.js
2. Implement DateParsingService initialization
3. Create HighlightedTextEditingController
4. Begin integration with edit dialog
5. Comprehensive testing (especially midnight edge cases)
