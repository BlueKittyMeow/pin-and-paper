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
**Phase 3.4 Decision:** 🚨 **NEEDS DECISION** 🚨

**Option 1: No Local Parsing (Send Raw Text + User Preferences to Claude)**
```
User types: "Call mom tomorrow morning, dentist Jan 15, workout tonight"
    ↓
Send to Claude API:
  - Raw text (unmodified)
  - UserSettings as JSON context (morningHour: 9, tonightHour: 20, etc.)
    ↓
Claude parses dates using user preferences
    ↓
Returns task suggestions with due_date values
    ↓
User approves → tasks created
```

**Pros:**
- Simpler architecture (one source of truth)
- Claude can be contextually smarter ("mom's birthday" → checks context)
- No risk of double-parsing
- No pre-processing tangles

**Cons:**
- Adds ~50 tokens per request for user preferences
- Claude must respect date parsing rules (need clear prompts)

---

**Option 2: Local Parsing Before Claude (Pre-extract Dates)**
```
User types: "Call mom tomorrow morning, dentist Jan 15"
    ↓
DateParserService.parse(text, userSettings)
    ↓
Extracts dates locally
    ↓
Send to Claude with structured data:
  {
    "rawText": "Call mom tomorrow morning, dentist Jan 15",
    "extractedDates": [
      {"phrase": "tomorrow morning", "date": "2025-10-31T09:00:00"},
      {"phrase": "Jan 15", "date": "2026-01-15"}
    ]
  }
    ↓
Claude uses extracted dates or overwrites if context requires
    ↓
Returns task suggestions
```

**Pros:**
- Consistent with Voice Input approach (see below)
- User sees parsing happen immediately (could show highlights)
- Reduces Claude's cognitive load

**Cons:**
- More complex architecture
- Risk of double-parsing conflicts
- Pre-processed text might confuse Claude
- Need rules for when Claude can override local parsing

---

**🎯 RECOMMENDATION: Option 1 (No Local Parsing)**

**Rationale:**
- Brain Dump is for free-form thought capture, not structured input
- Claude is better at contextual interpretation ("mom's birthday" vs "Jan 15")
- Simpler architecture = fewer bugs
- User preferences still respected (sent as context)
- Avoids pre-processing tangles before Claude sees text

**Implementation:**
- Add `userSettings` to Claude API context (Phase 3.4)
- Update Brain Dump system prompt to respect user preferences
- No local DateParserService calls for typed input

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

1. **Brain Dump Typed Input:** ✅ CONFIRMED - Option 1 (no local parsing, send raw to Claude)
   - Status: Tentative, pending team review with Gemini/Codex

2. **Brain Dump Voice Input:** ✅ CONFIRMED - Always goes to Claude
   - Brain Dump NEVER creates tasks without Claude parsing
   - Input method (typed vs voice) does NOT change this behavior
   - Voice = STT → transcript → send to Claude (same as typed)

3. **Quick Add Field Toggle:** ✅ CONFIRMED - Default to ON
   - `enableQuickAddDateParsing` = true (default)
   - More powerful out-of-box experience
   - Users can disable in settings if they prefer simple mode

4. **Onboarding Quiz:** ✅ CONFIRMED - Yes, ask during setup
   - Added as Question 7 in `docs/future/onboarding-quiz.md`
   - User can choose: "Automatically detect dates" (A) or "Keep it simple" (B)
   - Default remains ON if quiz is skipped

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

### Claude API Context (Brain Dump Typed Input)
```dart
// When sending to Claude, include user preferences
final context = '''
User Preferences:
- Morning starts at: ${userSettings.morningHour}:00
- Afternoon starts at: ${userSettings.afternoonHour}:00
- Tonight/Evening starts at: ${userSettings.tonightHour}:00
- Today cutoff (after midnight): ${userSettings.todayCutoffHour}:${userSettings.todayCutoffMinute}
- Weekend starts: ${userSettings.weekendStartDay}
- Timezone: ${userSettings.timezoneId}

When extracting dates from the user's text, respect these time preferences.
For example, "tomorrow morning" should be ${userSettings.morningHour}:00.
''';
```

---

## Files to Update (Phase 3.4)

### Quick Add Field (TaskInput Widget)
- [ ] Add check for `userSettings.enableQuickAddDateParsing`
- [ ] Integrate DateParserService when enabled
- [ ] Add visual highlight widget for matched phrases
- [ ] Show date picker confirmation UI

### Brain Dump Screen (Typed Input)
- [ ] Add `userSettings` to Claude API context
- [ ] Update system prompt to respect time preferences
- [ ] **NO** DateParserService calls for typed input

### Brain Dump Screen (Voice Input)
- [ ] Integrate speech_to_text plugin (device-native STT)
- [ ] Capture transcript from STT
- [ ] Send transcript + UserSettings to Claude (same as typed input)
- [ ] Display task suggestions for user approval (existing UI)

---

## Status

**Document Created:** 2025-10-30
**Last Updated:** 2025-10-30
**Status:** ✅ Decisions confirmed by BlueKitty

**Next Steps:**
1. Team review with Gemini/Codex on Brain Dump typed input architecture (tentative approval)
2. Update group1.md to reflect these decisions
3. Finalize Phase 3.4 implementation plan with correct data flows
