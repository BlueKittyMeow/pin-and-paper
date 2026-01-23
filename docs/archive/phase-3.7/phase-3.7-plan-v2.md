# Phase 3.7 Plan - Natural Language Date Parsing

**Version:** 2
**Created:** 2026-01-20
**Status:** Draft

---

## Changes from v1

**Incorporated from research docs and feedback:**
- Added "Today Window" configuration details from `docs/future/future.md`
- Clarified automatic parsing with onboarding quiz integration from `docs/future/onboarding-quiz.md`
- Specified date parsing scope (titles only, not notes)
- Added detailed implementation approach for midnight boundary handling
- Package evaluation will be team effort (Claude, Codex, Gemini)
- Clarified preview format expectations
- Expanded test strategy with midnight boundary edge cases

---

## Scope

Phase 3.7 adds natural language date parsing to Pin and Paper, allowing users to specify due dates using human-friendly phrases instead of manual date pickers.

**From PROJECT_SPEC.md:**
- Parse relative dates ("tomorrow", "next Tuesday", "in 3 days")
- Parse absolute dates ("Jan 15", "March 3rd")
- Time-of-day support ("3pm", "morning", "evening")
- Night owl mode (configurable midnight boundary)
- Integration with Brain Dump and task creation

**Parsing Scope:**
- ✅ Parse dates in task titles
- ✅ Extract date phrases and strip from title
- ❌ Do NOT parse dates in notes/descriptions (symbolic only, no linking yet)

---

## Motivation

**Current UX:**
- Users must tap date picker icon → select date → optionally select time
- Requires multiple taps and visual context switching
- Slower than typing, especially for common relative dates

**Improved UX:**
- Users can type naturally: "Fix bug tomorrow at 3pm"
- Parser extracts date/time, task title becomes "Fix bug"
- Show live preview: "Tomorrow, 9:38pm" as user types
- Fallback to manual picker for ambiguous or unrecognized dates
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

## Technical Approach

### Date Parsing Strategy

**Three Options to Evaluate:**

**Option 1: Existing Dart Package**
- Packages to evaluate: `any_date`, `chrono_dart`, others
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

**Action Item:** Create codex-findings.md and gemini-findings.md early for package evaluation research.

### Parser Features

**Must Support:**
1. **Relative dates**: today, tomorrow, yesterday, tonight
2. **Days of week**: Monday, Tuesday, next Monday, this Friday
3. **Relative offsets**: in 3 days, in 2 weeks, in 1 month
4. **Absolute dates**: Jan 15, March 3rd, 2026-01-20, 1/20/2026
5. **Time of day**: 3pm, 9:30am, morning, afternoon, evening, tonight
6. **Combined**: tomorrow at 3pm, next Tuesday morning, Jan 15 at 2pm

**Must Handle:**
1. **Today Window logic**: Use `getEffectiveToday()` for all relative date calculations
2. **Month/year boundaries**: "tomorrow" on Dec 31 → Jan 1 next year
3. **Ambiguity**: Past dates → assume next occurrence (e.g., "Jan 3" in February → next year)
4. **Multiple dates**: Extract first occurrence only
5. **Case insensitive**: "Tomorrow", "TOMORROW", "tomorrow" all work

**Extraction Behavior:**
```dart
// Input: "Fix bug tomorrow at 3pm"
// Output:
//   title: "Fix bug"
//   dueDate: DateTime(2026, 1, 21, 15, 0)  // Tomorrow at 3pm
//   isAllDay: false

// Input: "Call dentist next Tuesday"
// Output:
//   title: "Call dentist"
//   dueDate: DateTime(2026, 1, 28, 0, 0)  // Next Tuesday
//   isAllDay: true  // No time specified
```

### Integration Points

**1. TaskService (Core Service)**
- Add `DateParsingService` class
- Method: `ParsedDate? parseDateFromString(String text, {DateTime? now})`
- Returns: `(cleanTitle, dueDate, isAllDay)` or null if no date found
- Uses: `getEffectiveToday()` for Today Window logic

**2. Edit Task Dialog**
- Add date preview field below title input
- Show parsed date as user types: "Tomorrow, 9:38pm"
- Preview updates in real-time with debounce (300ms)
- Manual date picker still available for corrections
- "Clear" button to remove parsed date

**3. Brain Dump (AI Integration)**
- Parse dates BEFORE sending to Claude (local-first)
- Include effective date context in Claude prompt (from future.md):
  ```
  CURRENT CONTEXT:
  - Today's date: 2026-01-20
  - Current time: 14:35
  - User's timezone: PST
  - Day of week: Monday

  DATE PARSING RULES:
  - "today" = 2026-01-20
  - "tomorrow" = 2026-01-21
  - "next Tuesday" = the Tuesday of next week (even if today is Tuesday)
  ```
- Claude can also suggest dates, but local parsing takes precedence

**4. Quick Add Field (Task List)**
- Real-time date parsing as user types
- Inline preview chip: "Tomorrow, 3pm"
- Hit Enter → create task with parsed date
- Respects `enable_quick_add_date_parsing` setting (from Quiz Q7)

### Preview Format

**Format:** `"[Date], [Time]"` or `"[Date]"` if all-day

**Examples:**
- "Tomorrow" → All-day
- "Tomorrow, 9:38pm" → Specific time
- "Next Tuesday, morning" → Next Tuesday at 9am (morning_hour setting)
- "Jan 15" → All-day
- "Jan 15, 2pm" → Specific time
- "Today, 3pm" → Today at 3pm

**Color Coding (future enhancement):**
- Green: Successfully parsed
- Yellow: Ambiguous (show suggestion)
- Gray: No date detected

---

## Database & Schema

**No changes needed!** Phase 3.4 already added:
- `tasks.due_date` (INTEGER, Unix timestamp)
- `tasks.is_all_day` (INTEGER, 0 or 1)

**Settings to add** (in `user_settings` table or SharedPreferences):
- `today_cutoff_hour` (INTEGER, default 4)
- `today_cutoff_minute` (INTEGER, default 59)
- `enable_quick_add_date_parsing` (INTEGER, default 1)
- `morning_hour` (INTEGER, default 9)
- `afternoon_hour` (INTEGER, default 15)
- `evening_hour` (INTEGER, default 19)
- `tonight_hour` (INTEGER, default 19)

---

## Testing Strategy

### Unit Tests (DateParsingService)

**Relative Dates:**
- today, tomorrow, yesterday, tonight
- With Today Window: 2:30am test cases
- Month boundaries (Dec 31 → Jan 1)
- Year boundaries (Dec 31 2026 → Jan 1 2027)

**Days of Week:**
- Monday, Tuesday, etc. (next occurrence)
- next Monday, this Friday
- Edge case: "Monday" on Monday (should be next Monday, not today)

**Absolute Dates:**
- Jan 15, January 15, 1/15, 1/15/2026, 2026-01-15
- March 3rd, Dec 1st (ordinal numbers)
- Past dates → assume next occurrence

**Time Parsing:**
- 3pm, 9:30am, 15:00, 0930
- morning, afternoon, evening, tonight
- Named times respect settings (morning_hour, etc.)

**Combined:**
- tomorrow at 3pm
- next Tuesday morning
- Jan 15 at 2pm
- in 3 days at 5pm

**Midnight Boundary Tests (Critical!):**
```dart
// Monday 11:50 PM, cutoff 4:59am
// "tomorrow" → Tuesday (correct)

// Tuesday 12:05 AM, cutoff 4:59am
// effectiveToday = Monday (still yesterday)
// "tomorrow" → Tuesday (correct!)

// Tuesday 5:00 AM, cutoff 4:59am
// effectiveToday = Tuesday (now today)
// "tomorrow" → Wednesday (correct)
```

**Week Parsing Tests:**
```dart
// Monday: "next Tuesday" → 8 days away
// Tuesday 12:05 AM (still Monday): "next Tuesday" → 8 days
// Tuesday 5:00 AM: "next Tuesday" → 7 days
```

**Edge Cases:**
- Empty string → null
- No date found → null
- Multiple dates → extract first only
- Malformed dates (Feb 30) → null
- Ambiguous dates → best guess or null

### Integration Tests

- TaskService.createTask with date parsing
- Edit dialog date preview
- Brain Dump date extraction
- Quick Add field parsing

### Manual Testing

**Midnight Workflow:**
1. Set device time to 2:30am Tuesday
2. Type "Call dentist tomorrow"
3. Verify due date = Tuesday (not Wednesday!)

**Locale Testing:**
- US date formats (1/15/2026)
- European formats (15/1/2026)
- ISO formats (2026-01-15)

**Timezone Testing:**
- Create task near midnight
- Change timezone
- Verify dates still correct

---

## Subphases

Keep as single phase 3.7 for now. If implementation gets complex, can break into:

**Potential breakdown (if needed):**
- 3.7A: Core date parser + tests + Today Window logic
- 3.7B: Integration with TaskService and edit dialog
- 3.7C: Brain Dump and Quick Add integration

**Current recommendation:** Keep as unified 3.7 unless we hit major blockers.

---

## Open Questions (Updated)

1. **Package Selection (Team Evaluation Needed)**
   - Which Dart package has best natural language date support?
   - Does it handle relative dates well ("next Tuesday")?
   - Can we extend it with Today Window logic?
   - Performance characteristics?
   - **Action:** Early codex/gemini/claude research phase

2. **Preview Format (Resolved)**
   - ✅ Format: "Tomorrow, 9:38pm" or "Tomorrow" (all-day)
   - ✅ Show in real-time as user types (debounced)
   - ✅ Color coding for confidence (future enhancement)

3. **Night Owl Mode Settings (Resolved from research docs)**
   - ✅ Default: 4:59am cutoff (moderate night owl)
   - ✅ Configured via onboarding quiz (Phase 4+)
   - ✅ Hardcode default in Phase 3.7, make configurable in Phase 4

4. **Parsing Scope (Resolved)**
   - ✅ Parse dates in task titles only
   - ❌ Do NOT parse in notes/descriptions
   - ✅ Extract and strip date phrases from title
   - **Rationale:** Dates in notes are symbolic until proper linking exists

5. **UI/UX Details**
   - Should we show confidence level in preview? (e.g., "Tomorrow (high confidence)")
   - How to handle ambiguous dates? Show warning? Auto-pick best guess?
   - Should we support "undo date parsing" button?
   - What if user types "May" (month vs verb)?

6. **Claude Integration Details**
   - Should Claude parse dates before or after task extraction?
   - Local parsing first, then Claude? Or vice versa?
   - How to handle conflicts between local parser and Claude?

7. **Error Handling**
   - How to handle invalid dates (Feb 30)?
   - What if parser is wildly wrong? Manual correction flow?
   - Should we log parsing errors for improvement?

---

## Success Criteria

**Must Have:**
- ✅ Parse common relative dates (today, tomorrow, yesterday, tonight)
- ✅ Parse days of week (Monday, Tuesday, next Monday)
- ✅ Parse absolute dates (Jan 15, March 3rd, 2026-01-20)
- ✅ Time-of-day parsing (3pm, morning, evening)
- ✅ Today Window logic (night owl mode support)
- ✅ Extract and strip date phrases from task titles
- ✅ Integration with task creation and edit dialog
- ✅ Real-time preview in edit dialog
- ✅ Comprehensive tests (including midnight boundary tests)
- ✅ Works correctly across month/year boundaries

**Should Have:**
- ✅ Combined date + time ("tomorrow at 3pm")
- ✅ Relative dates with offsets ("in 3 days", "in 2 weeks")
- ✅ Integration with Brain Dump (Claude context)
- ✅ Quick Add field real-time parsing
- ✅ Locale-aware date parsing (US/European formats)

**Nice to Have:**
- ✅ Confidence indicators in preview
- ✅ Smart ambiguity resolution
- ✅ Undo date parsing button
- ✅ Parsing error logging for improvement

**Out of Scope (Defer to Future):**
- ❌ Recurring dates ("every Monday")
- ❌ Date ranges ("Jan 10-15")
- ❌ Natural language relative times ("in 30 minutes")
- ❌ Date parsing in task notes/descriptions
- ❌ Full onboarding quiz implementation (Phase 4+)
- ❌ User-configurable night owl settings UI (Phase 4+)

---

## Timeline Estimate

**Estimated Duration:** 1-2 weeks (per PROJECT_SPEC.md)

**Breakdown:**
1. Package evaluation (team effort): 1-2 days
2. Core parser implementation + Today Window logic: 2-3 days
3. Integration with TaskService: 1 day
4. UI integration (edit dialog, preview): 1-2 days
5. Brain Dump + Quick Add integration: 1 day
6. Comprehensive testing (esp. midnight edge cases): 2 days
7. Bug fixes and refinement: 1-2 days
8. Validation and documentation: 1 day

**Total:** 10-14 days (roughly 2 weeks)

**Critical Path:** Package evaluation → Core parser → Integration → Testing

---

## Dependencies

### External Packages

**To be evaluated by team (Claude, Codex, Gemini):**
- `any_date` - Dart package for parsing various date formats
- `chrono_dart` - Natural language date parsing (if available)
- Others suggested by research

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

**Phase 1: Research & Setup (Days 1-2)**
1. Create codex-findings.md and gemini-findings.md
2. Team evaluates date parsing packages
3. Decision: package vs custom vs hybrid
4. Set up DateParsingService class structure

**Phase 2: Core Parser (Days 3-5)**
1. Implement basic relative date parsing (today, tomorrow)
2. Add Today Window logic (`getEffectiveToday()`)
3. Implement days of week parsing
4. Add absolute date parsing
5. Add time parsing (12h/24h, named times)
6. Comprehensive unit tests (especially midnight edge cases)

**Phase 3: Integration (Days 6-8)**
1. Integrate with TaskService
2. Add real-time preview in edit dialog
3. Integrate with Brain Dump (enhance Claude prompt)
4. Add Quick Add field parsing
5. Settings storage (today_cutoff_hour, etc.)

**Phase 4: Testing & Refinement (Days 9-11)**
1. Integration tests
2. Manual testing (midnight workflow, locales, timezones)
3. Bug fixes
4. Edge case handling
5. Error logging

**Phase 5: Validation & Documentation (Days 12-14)**
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
- [templates/phase-start-checklist.md](../templates/phase-start-checklist.md) - Workflow reference

---

## Notes

- Phase 3.7 is the penultimate phase before Phase 3 completion
- Today Window logic is critical for night owl users (common in ADHD community)
- Default settings work for most users; onboarding quiz fine-tunes in Phase 4+
- Parser should be conservative: if uncertain, return null and let user pick manually
- Consider voice input compatibility (Phase 3+ goal)
- Future enhancement: ML-based learning of user's date patterns

---

**Next Steps:**
1. Review this v2 plan with BlueKitty
2. Create codex-findings.md and gemini-findings.md for package research
3. Team (Claude, Codex, Gemini) evaluates date parsing packages
4. Make package selection decision
5. Begin implementation with core parser
