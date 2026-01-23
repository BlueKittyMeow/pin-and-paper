# Phase 3.7 Plan - Natural Language Date Parsing

**Version:** 3
**Created:** 2026-01-20
**Status:** Ready for Implementation

---

## Changes from v2

**Major UX decisions finalized:**
- ✅ Real-time parsing with Todoist-style inline highlighting (during typing, not just on save)
- ✅ Strip date phrases on save (after user confirmation)
- ✅ Click highlighted text → edit/remove options menu
- ✅ Separate parsing strategies: Brain Dump (Claude) vs Quick Add/Edit (local)
- ✅ Show errors for invalid dates (track if noise becomes issue)
- ✅ Full absolute date format in preview: "Tomorrow (Tue, Jan 21)"
- ✅ Current date/time displayed in top bar (ADHD time blindness support)
- ✅ Conservative parser with context-aware disambiguation research

**Added:**
- Detailed UX mockup section with Todoist-style interaction flows
- Performance specifications for real-time parsing
- Research tasks for context-aware parsing best practices

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

**Algorithm (from future.md):**
```dart
DateTime getEffectiveToday(DateTime now, int todayWindowHours) {
  if (now.hour < todayWindowHours) {
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

Local parser:
  - Detects "tomorrow at 3pm"
  - Highlights in real-time
  - Calculates date using Today Window
  - Shows preview

✅ Real-time feedback (<1ms parse time)
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
final effectiveToday = getEffectiveToday(DateTime.now(), settings.todayCutoffHour);

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

### Date Parsing Strategy

**Package Evaluation Required (see codex/gemini findings docs)**

**Three Options:**

**Option 1: Existing Dart Package**
- Packages to evaluate: `any_date`, `jiffy`, `timeago`, others
- Pro: No API cost, works offline, fast, battle-tested
- Con: May have limited natural language support
- **Team decision needed:** Codex, Gemini, and Claude evaluate options

**Option 2: Custom Parser**
- Write regex-based parser for common patterns
- Pro: Full control, optimized for our use cases, no dependencies
- Con: More complex, needs thorough testing, maintenance burden

**Option 3: Hybrid**
- Use package for basic parsing (dates, days of week)
- Add custom rules for our specific patterns and Today Window logic
- Pro: Best of both worlds, leverages existing work
- Con: Slightly more complex architecture

**Recommendation:** Start with team evaluation of Option 1 packages. If insufficient, move to Option 3 (hybrid). Option 2 (full custom) only if both fail.

**Action Item:** Codex and Gemini research packages (see findings docs).

---

### Context-Aware Parsing (Research Required)

**The Challenge:**
- "May need to call dentist" → "May" should NOT be parsed as month
- "Call dentist in May" → "May" SHOULD be parsed as month
- "Meeting with April" → "April" is a name, not month
- "March forward with plans" → "March" is verb, not month

**Conservative Approach:**
- Prefer false negatives over false positives
- Better to miss a date than to break the title
- User can always use manual picker
- Escape hatch (click to remove) catches false positives

**Research Tasks (for Codex/Gemini):**
1. How do Todoist, Things, TickTick handle ambiguous date phrases?
2. What NLP techniques are used for context-aware date parsing?
   - Part-of-speech tagging
   - Surrounding word context (prepositions: "in May", "on Tuesday")
   - Sentence position (start vs middle vs end)
   - Capitalization patterns
3. Existing library approaches:
   - How does `chrono` (JavaScript) handle context?
   - What heuristics do popular parsers use?
4. Word lists and confidence scoring:
   - Common phrases to skip ("May need", "Maybe")
   - Confidence thresholds (only parse if high confidence)
   - Require explicit date indicators?

**Implementation Guidelines:**
```dart
// DON'T match "May" in these contexts:
"May need..."        → Common phrase, skip
"May I..."           → Question, skip
"Maybe..."           → Partial word match, skip
"with May"           → Likely proper name, skip

// DO match "May" in these contexts:
"Due in May"         → Clear date context with preposition
"May 15"             → With day number
"Call mom in May"    → With preposition "in"
"Deadline: May"      → After colon/label
```

**Log Ambiguous Cases:**
- Track when parser rejects ambiguous patterns
- Monitor false positive rate (user dismissals)
- Use data to improve parser over time

---

### Parser Features

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
6. **Context awareness**: Skip false positives (research-based approach)

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

### Real-Time Parsing Implementation

**Performance Requirements:**
- Parse time: <1ms per parse
- Debounce: 300ms after last keystroke
- No janky UI (highlighting appears smoothly)
- Works offline (no API calls)

**State Management:**
```dart
class DateParsingState {
  String? matchedText;        // "tomorrow"
  TextRange? matchedRange;    // Position in title (for highlighting)
  DateTime? parsedDate;       // Calculated date
  bool userDismissed;         // User clicked "Remove"
  List<DateOption> alternatives; // Other interpretations

  void dismiss() {
    userDismissed = true;
    matchedText = null;
    matchedRange = null;
    parsedDate = null;
    // Don't re-trigger unless text changes significantly
  }
}
```

**Debounced Parsing:**
```dart
final debouncer = Debouncer(milliseconds: 300);

void onTitleChanged(String text) {
  // Only parse if user hasn't dismissed for this text
  if (!parsingState.userDismissed || textChangedSignificantly(text)) {
    debouncer.run(() {
      final parsed = dateParser.parse(text, now: DateTime.now());

      if (parsed != null) {
        setState(() {
          parsingState.matchedText = parsed.matchedText;
          parsingState.matchedRange = parsed.matchedRange;
          parsingState.parsedDate = parsed.date;
          parsingState.alternatives = parsed.alternatives;
          parsingState.userDismissed = false;
        });
      } else {
        // No date detected, clear state
        setState(() {
          parsingState = DateParsingState();
        });
      }
    });
  }
}
```

**Highlighting Implementation:**
```dart
// Use RichText with TextSpan for inline highlighting
Widget buildTitleField() {
  if (parsingState.matchedRange == null) {
    // No match, use regular TextField
    return TextField(
      controller: titleController,
      onChanged: onTitleChanged,
    );
  }

  // Has match, use RichText with highlighting
  final range = parsingState.matchedRange!;
  final text = titleController.text;

  return RichText(
    text: TextSpan(
      style: DefaultTextStyle.of(context).style,
      children: [
        if (range.start > 0)
          TextSpan(text: text.substring(0, range.start)),
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(
            backgroundColor: Colors.blue.withOpacity(0.2),
            color: Colors.blue[700],
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = showDateOptions,
        ),
        if (range.end < text.length)
          TextSpan(text: text.substring(range.end)),
      ],
    ),
  );
}
```

**Options Menu:**
```dart
void showDateOptions() {
  showModalBottomSheet(
    context: context,
    builder: (context) => DateOptionsSheet(
      currentDate: parsingState.parsedDate,
      alternatives: parsingState.alternatives,
      onSelect: (date) {
        setState(() {
          parsingState.parsedDate = date;
        });
        Navigator.pop(context);
      },
      onRemove: () {
        setState(() {
          parsingState.dismiss();
        });
        Navigator.pop(context);
      },
      onPickCustom: () {
        Navigator.pop(context);
        showDatePicker(/* ... */);
      },
    ),
  );
}
```

---

### Integration Points

**1. TaskService (Core Service)**
- Add `DateParsingService` class
- Method: `ParsedDate? parseDateFromString(String text, {DateTime? now})`
- Returns: `ParsedDate(cleanTitle, matchedText, matchedRange, dueDate, isAllDay, alternatives)` or null
- Uses: `getEffectiveToday()` for Today Window logic

**2. Edit Task Dialog**
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
today_cutoff_minute INTEGER DEFAULT 59,

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

**Context-Aware (False Positive Prevention):**
- "May need to call dentist" → null (not a date)
- "Call dentist in May" → May (is a date)
- "Meeting with April" → null (proper name)
- "March forward" → null (verb)

**Midnight Boundary Tests (CRITICAL!):**
```dart
// Monday 11:50 PM, cutoff 4:59am
// effectiveToday = Monday
// "tomorrow" → Tuesday (correct)
test('tomorrow before midnight', () {
  final now = DateTime(2026, 1, 20, 23, 50); // Mon 11:50 PM
  final parsed = dateParser.parse("tomorrow", now: now);
  expect(parsed.date.day, 21); // Tuesday
});

// Tuesday 12:05 AM, cutoff 4:59am
// effectiveToday = Monday (still yesterday)
// "tomorrow" → Tuesday (correct!)
test('tomorrow after midnight in today window', () {
  final now = DateTime(2026, 1, 21, 0, 5); // Tue 12:05 AM
  final parsed = dateParser.parse("tomorrow", now: now);
  expect(parsed.date.day, 21); // Tuesday (not Wednesday!)
});

// Tuesday 5:00 AM, cutoff 4:59am
// effectiveToday = Tuesday (now today)
// "tomorrow" → Wednesday (correct)
test('tomorrow after today window', () {
  final now = DateTime(2026, 1, 21, 5, 0); // Tue 5:00 AM
  final parsed = dateParser.parse("tomorrow", now: now);
  expect(parsed.date.day, 22); // Wednesday
});
```

**Week Parsing Tests:**
```dart
// Monday: "next Tuesday" → 8 days away
test('next Tuesday from Monday', () {
  final now = DateTime(2026, 1, 19); // Monday
  final parsed = dateParser.parse("next Tuesday", now: now);
  expect(parsed.date, DateTime(2026, 1, 27)); // 8 days
});

// Tuesday 12:05 AM (still Monday): "next Tuesday" → 8 days
test('next Tuesday from Monday night', () {
  final now = DateTime(2026, 1, 21, 0, 5); // Tue 12:05 AM
  final parsed = dateParser.parse("next Tuesday", now: now);
  expect(parsed.date, DateTime(2026, 1, 27)); // Still 8 days (effectiveToday = Monday)
});

// Tuesday 5:00 AM: "next Tuesday" → 7 days
test('next Tuesday from Tuesday', () {
  final now = DateTime(2026, 1, 21, 5, 0); // Tue 5:00 AM
  final parsed = dateParser.parse("next Tuesday", now: now);
  expect(parsed.date, DateTime(2026, 1, 28)); // 7 days
});
```

**Edge Cases:**
- Empty string → null
- No date found → null
- Multiple dates → extract first only
- Malformed dates (Feb 30) → null with error message
- Ambiguous dates → best guess or null (log for improvement)

---

### Integration Tests

- TaskService.createTask with date parsing
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

**Locale Testing:**
- US date formats (1/15/2026)
- European formats (15/1/2026)
- ISO formats (2026-01-15)

**Timezone Testing:**
- Create task near midnight
- Change timezone
- Verify dates still correct

**Performance Testing:**
- Type rapidly → debouncing works
- Parse complex phrases → <1ms
- UI remains responsive

---

## Subphases

Keep as single phase 3.7 for now. If implementation gets complex, can break into:

**Potential breakdown (if needed):**
- 3.7A: Core date parser + tests + Today Window logic
- 3.7B: Real-time UI integration (highlighting, options menu)
- 3.7C: Brain Dump integration + top bar date display

**Current recommendation:** Keep as unified 3.7 unless we hit major blockers.

---

## Success Criteria

**Must Have (MVP):**
- ✅ Parse common relative dates (today, tomorrow, yesterday, tonight)
- ✅ Parse days of week (Monday, Tuesday, next Monday)
- ✅ Parse absolute dates (Jan 15, March 3rd, 2026-01-20)
- ✅ Time-of-day parsing (3pm, morning, evening)
- ✅ Today Window logic (night owl mode support)
- ✅ Real-time parsing with debouncing (300ms)
- ✅ Todoist-style inline highlighting
- ✅ Click highlight → options menu (alternatives + remove)
- ✅ Auto-strip date phrases on save
- ✅ Full absolute date format: "Tomorrow (Tue, Jan 21)"
- ✅ Current date/time in top bar
- ✅ Error messages for invalid dates
- ✅ Context-aware parsing (research-based approach)
- ✅ Integration with edit dialog and quick add
- ✅ Comprehensive tests (including midnight boundary tests)
- ✅ Works correctly across month/year boundaries

**Should Have:**
- ✅ Combined date + time ("tomorrow at 3pm")
- ✅ Relative dates with offsets ("in 3 days", "in 2 weeks")
- ✅ Integration with Brain Dump (Claude context)
- ✅ Locale-aware date parsing (US/European formats)
- ✅ Re-trigger parsing if text changes after dismissal
- ✅ Performance: <1ms parse time, smooth UI

**Nice to Have (Post-MVP):**
- More sophisticated disambiguation UI
- ML-based learning of user's date patterns
- Voice input compatibility testing
- More time keyword mappings (dawn, dusk, noon, etc.)

**Out of Scope (Defer to Future):**
- ❌ Recurring dates ("every Monday")
- ❌ Date ranges ("Jan 10-15")
- ❌ Natural language relative times ("in 30 minutes")
- ❌ Date parsing in task notes/descriptions
- ❌ Full onboarding quiz implementation (Phase 4+)
- ❌ User-configurable night owl settings UI (Phase 4+)

---

## Timeline Estimate

**Estimated Duration:** 1.5-2 weeks

**Breakdown:**
1. Package evaluation (team effort): 1-2 days
2. Core parser implementation + Today Window logic: 2-3 days
3. Real-time UI (highlighting, debouncing): 2 days
4. Options menu + interaction flows: 1-2 days
5. Integration with TaskService: 1 day
6. Brain Dump integration + top bar date display: 1 day
7. Context-aware parsing refinement: 1 day
8. Comprehensive testing (esp. midnight edge cases): 2 days
9. Bug fixes and refinement: 1-2 days
10. Validation and documentation: 1 day

**Total:** 12-17 days (roughly 1.5-2 weeks)

**Critical Path:** Package evaluation → Core parser → Real-time UI → Testing

---

## Dependencies

### External Packages

**To be evaluated by team (Claude, Codex, Gemini):**
- Date parsing packages (TBD after research)
- May use hybrid approach (package + custom extensions)

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

## Implementation Plan

**Phase 1: Research & Package Evaluation (Days 1-2)**
1. Create/update codex-findings.md and gemini-findings.md ✅
2. Team evaluates date parsing packages
3. Research context-aware parsing best practices
4. Decision: package vs custom vs hybrid
5. Set up DateParsingService class structure

**Phase 2: Core Parser (Days 3-5)**
1. Implement basic relative date parsing (today, tomorrow)
2. Add Today Window logic (`getEffectiveToday()`)
3. Implement days of week parsing
4. Add absolute date parsing
5. Add time parsing (12h/24h, named times)
6. Context-aware false positive prevention
7. Comprehensive unit tests (especially midnight edge cases)

**Phase 3: Real-Time UI (Days 6-8)**
1. Debounced parsing (300ms)
2. Inline highlighting (Todoist-style)
3. TextRange tracking and RichText rendering
4. Preview display with full absolute format
5. State management (dismissed state tracking)

**Phase 4: Options Menu & Interactions (Days 9-10)**
1. Click highlighted text → modal/dropdown
2. Show alternatives (common date interpretations)
3. Remove due date option
4. Manual picker integration
5. Smooth animations and UX polish

**Phase 5: Integration (Days 11-13)**
1. Integrate with TaskService (strip on save)
2. Edit dialog integration
3. Quick Add field integration
4. Brain Dump: Send Claude effective date context
5. Top bar: Current date/time display
6. Settings storage (today_cutoff_hour, etc.)

**Phase 6: Testing & Refinement (Days 14-15)**
1. Integration tests
2. Manual testing (midnight workflow, locales, timezones)
3. Performance testing (<1ms parse, smooth UI)
4. Bug fixes
5. Edge case handling
6. Error logging for improvement

**Phase 7: Validation & Documentation (Days 16-17)**
1. End-of-phase validation
2. Implementation report
3. Update PROJECT_SPEC.md and README.md
4. Archive Phase 3.7 docs

---

## Related Documents

- [PROJECT_SPEC.md](../PROJECT_SPEC.md) - Phase 3.7 official scope
- [docs/future/future.md](../future/future.md) - Midnight Problem research & Today Window algorithm
- [docs/future/onboarding-quiz.md](../future/onboarding-quiz.md) - Quiz integration details
- [archive/phase-3.6.5/phase-3.6.5-implementation-report.md](../../archive/phase-3.6.5/phase-3.6.5-implementation-report.md) - Previous phase context
- [codex-findings.md](./codex-findings.md) - Package evaluation & context-aware parsing research
- [gemini-findings.md](./gemini-findings.md) - Build testing & performance validation
- [templates/phase-start-checklist.md](../templates/phase-start-checklist.md) - Workflow reference

---

## Notes

- Phase 3.7 is the penultimate phase before Phase 3 completion
- Today Window logic is critical for night owl users (common in ADHD community)
- Real-time parsing with Todoist-style UX is gold standard
- Conservative parser + escape hatch better than aggressive parser
- Default settings work for most users; onboarding quiz fine-tunes in Phase 4+
- Parser should be conservative: if uncertain, don't parse (rather miss than break)
- Context-aware parsing research critical for false positive prevention
- Performance is non-negotiable: must be <1ms parse, smooth UI
- Current date/time in top bar helps with ADHD time blindness

---

**Status:** Ready for implementation after package evaluation phase.

**Next Steps:**
1. Codex and Gemini: Complete package research (see findings docs)
2. Team decision on package vs custom vs hybrid approach
3. Begin core parser implementation
4. Iterate on UI based on user testing
