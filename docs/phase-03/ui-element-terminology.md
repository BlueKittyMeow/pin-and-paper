# UI Element Terminology & Date Parsing Architecture

**Date:** 2025-10-30
**Purpose:** Clear naming and data flow to prevent architectural confusion

---

## UI Elements (Existing)

### 1. TaskInput Widget - "Quick Add Field"
**Location:** Top of Home Screen
**File:** `pin_and_paper/lib/widgets/task_input.dart`
**Current Behavior:** Type text → press Enter → creates task with that title

**Phase 3.4 Enhancement:**
- **OPTIONAL** natural language date parsing (toggle in User Settings)
- When enabled: Shows Todoist-style live parsing with visual highlights
- When disabled: Remains simple quick-add (current behavior)
- **Setting:** `UserSettings.enableQuickAddDateParsing` (default: **true**)
- **Onboarding:** Question 7 in onboarding quiz (see `docs/future/onboarding-quiz.md`)

**Data Flow (when enabled):**
```
User types: "Call mom Jan 15"
    ↓
DateParserService.parse(text, userSettings)
    ↓
Extracts: due_date = Jan 15, title = "Call mom Jan 15"
    ↓
Shows UI highlight on "Jan 15"
    ↓
User presses Enter
    ↓
Creates task with due_date set
```

**User Preferences Applied:**
- ✅ `morningHour`, `afternoonHour`, `tonightHour` (for "morning", "tonight", etc.)
- ✅ `todayCutoffHour` (for "today" after midnight)
- ✅ `weekendStartDay` (Saturday vs Friday)
- ✅ `timezone_id` (for absolute dates)

---

### 2. Brain Dump Screen
**Location:** Separate screen (accessed from drawer/button)
**File:** `pin_and_paper/lib/screens/brain_dump_screen.dart`
**Current Behavior:** Large text area → "Claude, Help Me" button → Claude extracts tasks

**Two Input Methods:**

#### A. Brain Dump - Typed Input (Keyboard)
**Current:** User types free-form text → Claude extracts tasks
**Phase 3.4 Decision:** ✅ **APPROVED** (2025-10-30)

**Approved Architecture: Claude Extracts Phrases, Local Parses**

```
User types: "call marie tomorrow, bank next friday, pat cat tomorrow morning"
    ↓
Send to Claude API:
  - Raw text only (NO user settings context)
  - Prompt: "Extract date phrases verbatim, don't parse"
    ↓
Claude extracts (simple extraction, no rule application):
  - Task 1: "call marie" + datePhrase: "tomorrow"
  - Task 2: "go to the bank" + datePhrase: "next friday"
  - Task 3: "pat cat" + datePhrase: "tomorrow morning"
    ↓
Local DateParserService.parse() [BEFORE showing to user]:
  - "tomorrow" → 2025-10-31 (apply todayCutoffHour if needed)
  - "next friday" → 2025-11-07 (apply week logic)
  - "tomorrow morning" → 2025-10-31T09:00:00 (apply morningHour)
    ↓
Display tasks to user with FINAL dates for approval
```

**Why This Approach:**
- ✅ **Single source of truth:** DateParserService is the ONLY place user rules exist
- ✅ **Cost savings:** No UserSettings context (~60 tokens saved per request)
- ✅ **Consistency:** "tomorrow morning" means the SAME thing in Quick Add and Brain Dump
- ✅ **Maintainability:** Change user pref? Update ONE place (DateParserService)
- ✅ **Testability:** Pure Dart code, easily unit tested
- ✅ **Clear debugging:** Date bugs always in DateParserService (clear ownership)
- ✅ **No pre-processing tangle:** Claude gets raw text, parsing happens AFTER

**Implementation:**
- Update Claude response format: add `datePhrase` and `timePhrase` fields
- Update system prompt: extract phrases verbatim, don't parse
- Add post-extraction parsing step: call DateParserService before showing tasks
- Add "later" and "soon" synonyms to DateParserService

**See:** `docs/phase-03/brain-dump-date-parsing-options.md` for full analysis and team votes

---

#### B. Brain Dump - Voice Input (Speech-to-Text)
**Phase 3.4:** Device-native STT → transcript → **ALWAYS goes to Claude**

**Data Flow:**
```
User speaks: "Call mom tomorrow morning, dentist Jan 15"
    ↓
speech_to_text plugin (device-native)
    ↓
Transcript: "Call mom tomorrow morning, dentist Jan 15"
    ↓
Send to Claude API:
  - Transcript (raw text)
  - UserSettings as JSON context (morningHour: 9, tonightHour: 20, etc.)
    ↓
Claude parses dates using user preferences
    ↓
Returns task suggestions with due_date values
    ↓
User approves → tasks created
```

**Why Send to Claude (Not Direct Task Creation)?**
- Brain Dump is ALWAYS for Claude parsing, regardless of input method (typed or voice)
- Voice vs. typing is just an input modality difference
- Claude provides contextual intelligence that local parsing cannot
- Maintains consistent behavior: Brain Dump → Claude → Task Suggestions → Approval

**Implementation Note:**
- Voice input does NOT get local DateParserService pre-processing
- Send raw transcript + user preferences to Claude
- Same approach as typed Brain Dump input (Option 1)

---

## Summary Table

| UI Element | Local DateParserService? | Claude Involvement? | User Settings Toggle? |
|------------|--------------------------|---------------------|----------------------|
| **Quick Add Field (TaskInput)** | ✅ Yes (Phase 3.4) | ❌ No | ✅ Yes - `enableQuickAddDateParsing` (default: ON) |
| **Brain Dump - Typed** | ❌ No (send raw to Claude) | ✅ Yes (Claude parses) | N/A (always uses Claude) |
| **Brain Dump - Voice** | ❌ No (send raw to Claude) | ✅ Yes (Claude parses) | N/A (always uses Claude) |

---

## Architectural Principles

### 1. **One Source of Truth per Input Method**
- Quick Add Field: Local DateParserService is source of truth
- Brain Dump (typed OR voice): Claude is source of truth

### 2. **No Double Parsing**
- Quick Add Field: Local parsing only, never sent to Claude
- Brain Dump: Claude parsing only, no local pre-processing
- Clear separation = no conflicts or architectural tangles

### 3. **User Preferences Always Respected**
- Quick Add Field: Local DateParserService uses UserSettings directly
- Brain Dump: Send UserSettings to Claude as context (Claude respects preferences)

### 4. **Clear Boundaries**
- Quick Add Field = Structured, predictable input (good for local parsing)
- Brain Dump = Free-form, contextual input (good for Claude parsing)
- Input method (typed vs voice) does NOT change behavior within same UI element

---

## Decisions Made (2025-10-30)

1. **Brain Dump Typed Input:** ✅ **APPROVED** - Claude extracts phrases, local parses
   - Status: Approved by BlueKitty, Claude, Gemini consensus
   - Raw text → Claude extracts datePhrase → DateParserService applies rules
   - No UserSettings sent to Claude (cost savings)
   - See `docs/phase-03/brain-dump-date-parsing-options.md` for full analysis

2. **Brain Dump Voice Input:** ✅ **APPROVED** - Always goes to Claude (same as typed)
   - Brain Dump NEVER creates tasks without Claude parsing
   - Input method (typed vs voice) does NOT change this behavior
   - Voice = STT → transcript → send to Claude → extract phrases → local parse

3. **Quick Add Field Toggle:** ✅ **APPROVED** - Default to ON
   - `enableQuickAddDateParsing` = true (default)
   - More powerful out-of-box experience
   - Users can disable in settings if they prefer simple mode

4. **Onboarding Quiz:** ✅ **APPROVED** - Yes, ask during setup
   - Added as Question 7 in `docs/future/onboarding-quiz.md`
   - User can choose: "Automatically detect dates" (A) or "Keep it simple" (B)
   - Default remains ON if quiz is skipped

5. **Date Synonyms:** ✅ **APPROVED** - Add "later" and "soon"
   - "later" → undated task (goes to unsorted section)
   - "soon" → undated for now (future: ask in onboarding quiz)

---

## Implementation Notes

### UserSettings Schema (v4)
```dart
class UserSettings {
  // ... existing fields ...

  // Phase 3.4: Quick Add Field date parsing toggle
  final bool enableQuickAddDateParsing; // Default: true (opt-out)
}
```

### Claude API Response Format (Brain Dump)
```dart
// NEW: Claude extracts date phrases verbatim, doesn't parse
// Updated response format includes datePhrase and timePhrase fields

{
  "tasks": [
    {
      "title": "call marie",
      "datePhrase": "tomorrow",        // ← NEW: Extracted verbatim
      "timePhrase": null,               // ← NEW: For standalone times
      "notes": null
    },
    {
      "title": "pat cat",
      "datePhrase": "tomorrow morning", // Combined date+time phrase
      "timePhrase": null,
      "notes": null
    }
  ]
}
```

### Claude System Prompt Update (Brain Dump)
```
When extracting tasks, include any date or time phrases exactly as the user wrote them:
- "tomorrow" → datePhrase: "tomorrow"
- "next friday" → datePhrase: "next friday"
- "tomorrow morning" → datePhrase: "tomorrow morning"
- "3pm" → timePhrase: "3pm"
- "jan 15" → datePhrase: "jan 15"

DO NOT parse or convert dates. Return the original phrase verbatim.
If no date/time is mentioned, set datePhrase and timePhrase to null.
```

### Post-Extraction Date Parsing (Brain Dump)
```dart
// After Claude returns tasks, parse date phrases locally
final parsedTasks = <Task>[];
for (final taskData in response.tasks) {
  DateTime? dueDate;
  bool isAllDay = true;

  // Parse date phrase if present
  if (taskData.datePhrase != null) {
    final parsed = dateParserService.parse(taskData.datePhrase);
    if (parsed.dateTime != null) {
      dueDate = parsed.dateTime;
      isAllDay = parsed.isAllDay;
    }
  }

  // Parse standalone time if present
  if (taskData.timePhrase != null && dueDate == null) {
    final parsed = dateParserService.parse(taskData.timePhrase);
    if (parsed.dateTime != null) {
      dueDate = parsed.dateTime;
      isAllDay = false;
    }
  }

  parsedTasks.add(Task(
    title: taskData.title,
    dueDate: dueDate,
    isAllDay: isAllDay,
    notes: taskData.notes,
  ));
}
```

---

## Files to Update (Phase 3.4)

### Quick Add Field (TaskInput Widget)
- [ ] Add check for `userSettings.enableQuickAddDateParsing`
- [ ] Integrate DateParserService when enabled
- [ ] Add visual highlight widget for matched phrases
- [ ] Show date picker confirmation UI

### Brain Dump Screen (Both Typed and Voice Input)
- [ ] Update Claude response parsing to handle `datePhrase` and `timePhrase` fields
- [ ] Update system prompt: "Extract date phrases verbatim, don't parse"
- [ ] Add post-extraction date parsing step (call DateParserService before showing tasks)
- [ ] Update TaskData model to include datePhrase and timePhrase fields
- [ ] For voice: Integrate speech_to_text plugin (device-native STT)
- [ ] Display parsed tasks with final dates for user approval

### DateParserService (Phase 3.3)
- [ ] Add "later" synonym (returns null date, isDeferral: true)
- [ ] Add "soon" synonym (returns null date for now, future: onboarding quiz)
- [ ] Add "someday" synonym (returns null date)

---

## Status

**Document Created:** 2025-10-30
**Last Updated:** 2025-10-30
**Status:** ✅ **APPROVED** - All decisions finalized (BlueKitty, Claude, Gemini consensus)

**Architecture Decision:** Brain Dump uses Claude extraction → local parsing (Option 2)
- Full analysis: `docs/phase-03/brain-dump-date-parsing-options.md`
- Votes: BlueKitty ✅, Claude ✅, Gemini ✅, Codex ⏳ (pending)

**Next Steps:**
1. ✅ Team review completed (Gemini approved, Codex pending but proceeding)
2. Update group1.md to reflect final architecture
3. Implement Phase 3.4 with approved data flows
