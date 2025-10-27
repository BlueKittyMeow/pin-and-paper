# Future Phases Planning

**Version:** 1.0
**Created:** 2025-10-26
**Status:** Planning Notes
**Note:** These are planning notes for Phase 3 and beyond. Do not implement until earlier phases are validated.

---

## Phase 3: Core Features Fast-Follow

### Natural Language Date Parsing (Complex!)

**Goal:** Parse dates like "next Tuesday", "tomorrow", "in 2 weeks" into actual due dates.

#### The Midnight Problem

**Core Issue:** Date parsing around midnight can be off by a full week if we're not careful.

**Scenarios:**

1. **Late Monday Night (11:50 PM Monday)**
   - User types: "tomorrow"
   - User expects: Tuesday
   - System time: Monday 11:50 PM
   - ✅ Correct: Tuesday

2. **Just After Midnight (12:05 AM Tuesday)**
   - User types: "tomorrow"
   - System time: Tuesday 12:05 AM
   - System thinks tomorrow = Wednesday
   - ❌ Problem: Night owl user might still think it's "Monday night"
   - ❌ User might expect: Tuesday (today)
   - ✅ System would give: Wednesday

3. **Week-Based Parsing**
   - Monday 11:50 PM: "next Tuesday" should be Tuesday (2 days)
   - Tuesday 12:05 AM: "next Tuesday" could mean:
     - Option A: Tuesday (today, 0 days) ← if user considers it "still Monday night"
     - Option B: Next Tuesday (7 days) ← if user considers it Tuesday

#### Implementation Challenges

**1. Context is Everything**
We need to send Claude:
- Current date/time (ISO 8601 format)
- User's configured "today window" (if set)
- User's timezone

**2. Ambiguity Resolution**
When parsing "tomorrow" at 12:05 AM:
- Check user's "today window" setting
- If within window (e.g., "today" extends to 3 AM), treat as previous day
- If outside window, use system date

**3. Week Boundary Issues**
"Next Tuesday" vs "This Tuesday":
- Monday: "next Tuesday" = 8 days
- Tuesday: "next Tuesday" = 7 days (or 0 if "this Tuesday")
- Need clear rules in prompt

#### Proposed Solution: "Today Window" Configuration

**User Settings:**
```dart
class TodayWindowSettings {
  // "Today" extends this many hours past midnight
  int todayWindowHours; // Default: 3 (3 AM is still "tonight")

  // Examples:
  // todayWindowHours = 0 → strict midnight boundary
  // todayWindowHours = 3 → 12:00 AM - 2:59 AM counts as previous day
  // todayWindowHours = 6 → 12:00 AM - 5:59 AM counts as previous day
}
```

**UI in Settings:**
```
┌─────────────────────────────────┐
│ Date Parsing                    │
│                                 │
│ "Today" ends at:                │
│ ○ Midnight (12:00 AM)           │
│ ● 3:00 AM (Night owl mode)      │
│ ○ 6:00 AM (Extreme night owl)   │
│ ○ Custom: [__] AM               │
└─────────────────────────────────┘
```

**Algorithm:**
```dart
DateTime getEffectiveToday(DateTime now, int todayWindowHours) {
  if (now.hour < todayWindowHours) {
    // We're in the "still yesterday" window
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}

// Usage in prompt:
final effectiveToday = getEffectiveToday(DateTime.now(), settings.todayWindowHours);
final promptDate = effectiveToday.toIso8601String();
```

#### Claude Prompt Enhancement for Phase 3

**Current Prompt (Phase 2):**
```
You are helping someone with ADHD organize their thoughts...
[no date context]
```

**Enhanced Prompt (Phase 3):**
```
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
```

#### Testing Strategy

**Test Cases for Phase 3:**

1. **Midnight Boundary Tests**
   ```
   Time: Monday 11:50 PM
   Input: "Call dentist tomorrow"
   Expected: due_date = "Tuesday"
   ```

   ```
   Time: Tuesday 12:05 AM (with 3-hour window)
   Input: "Call dentist tomorrow"
   Expected: due_date = "Tuesday" (still considers it Monday)
   ```

   ```
   Time: Tuesday 5:00 AM (with 3-hour window)
   Input: "Call dentist tomorrow"
   Expected: due_date = "Wednesday" (now considers it Tuesday)
   ```

2. **Week Parsing Tests**
   ```
   Time: Monday
   Input: "Meeting next Tuesday"
   Expected: due_date = "Tuesday [next week]" (8 days)
   ```

   ```
   Time: Tuesday
   Input: "Meeting next Tuesday"
   Expected: due_date = "Tuesday [next week]" (7 days)
   ```

   ```
   Time: Tuesday
   Input: "Meeting this Tuesday"
   Expected: due_date = "Tuesday [today]" (0 days)
   ```

3. **Edge Cases**
   ```
   Input: "Meeting in 2 weeks"
   Expected: due_date = [today + 14 days]
   ```

   ```
   Input: "Call mom on the 15th"
   Expected: due_date = "[current month]-15" or "[next month]-15" if past
   ```

   ```
   Input: "Birthday party March 5th"
   Expected: due_date = "2025-03-05" (or 2026 if we're past March)
   ```

#### Error Handling for Date Parsing

**Ambiguous Dates:**
- "next week" without specific day → show warning, don't set due date
- "Monday" when it's unclear which Monday → assume nearest future Monday
- Past dates → assume user means next occurrence (e.g., "January 3" in February → next year)

**Invalid Dates:**
- "February 30" → catch and show error
- "Month 13" → catch and show error
- Timezone issues → always use user's local timezone

#### Database Schema Updates (Phase 3)

```sql
-- Add to tasks table
ALTER TABLE tasks ADD COLUMN due_date INTEGER;  -- Unix timestamp
ALTER TABLE tasks ADD COLUMN notes TEXT;        -- Context from brain dump

-- Index for due date queries
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
```

#### UI Changes for Phase 3

**Task List:**
- Show due date prominently
- Color coding:
  - Red: Overdue
  - Orange: Due today
  - Yellow: Due tomorrow
  - Green: Due this week
  - Gray: No due date

**Task Suggestion Preview:**
- Show parsed due date for each task
- Allow manual date picker if Claude got it wrong
- Highlight uncertain dates for user review

---

## Phase 4+: Workspace View

### Technical Challenges
- CustomPaint performance at scale
- Hit testing for rotated/positioned cards
- Viewport culling optimization
- State management for spatial data

### Deferred Features
- Two-finger rotation gesture
- Drag and drop positioning
- Z-index management
- Connection lines between cards

---

## Phase 5+: Sync & Multi-Device

### Considerations
- Timestamp-based sync (simple)
- Conflict resolution UI
- Export/import functionality
- Cloud storage integration (Google Drive)

---

## Phase 6+: Aesthetic Enhancements

### Dynamic Lighting
- Time-based lighting states
- Shadow calculations
- Performance optimization

### Card Customization
- Textures and patterns
- Effects (aged, stained, etc.)
- User-defined themes

---

## Phase 7+: Journal & History

### Temporal Awareness
- Completed tasks archive
- Productivity metrics
- "On this day" historical view

---

## Phase 8+: Cross-Platform

### iPad Optimizations
- Apple Pencil support
- Larger canvas workspace
- Multi-finger gestures

### Desktop (Linux)
- Keyboard shortcuts
- Mouse wheel zoom
- Menu bar interface

---

## Phase 9+: Advanced Features

### Stretch Goals
- Manila folder animations
- Flippable cards
- Multiple theme options
- Comprehensive undo/redo
- Linking/grouping cards

---

## Implementation Priorities

**Decision Gates:**
1. Phase 2 must validate AI feature → if not helpful, pivot
2. Phase 3 only if Phase 2 is successful
3. Phase 4 (workspace) only if user actually needs spatial organization
4. Later phases are polish and enhancement

**Core Philosophy:**
Build minimum viable features, validate with real usage, then enhance. Don't build beautiful features nobody uses.

---

## Notes for Future Development

### Date Parsing Decision Log

**Decision:** Implement "today window" configuration in Phase 3
**Rationale:**
- Night owl users are common in ADHD community
- Ambiguity around midnight causes real usability issues
- User control is better than trying to guess
- Simple configuration (3 options) covers most cases

**Alternative Considered:**
- Always use strict midnight boundary
- Rejected because: doesn't match user mental model

**Implementation Priority:**
- Phase 3, after core date parsing works
- Can start with strict midnight, add window later
- Document the issue clearly for users

### Future Research Needed

**Date Parsing:**
- Test with real ADHD users
- Gather data on common date references
- Analyze failure cases
- Consider multi-language support

**Workspace:**
- Prototype rotation gesture early
- Test CustomPaint performance limits
- Validate spatial organization benefits

**AI Enhancement:**
- Track Claude API improvements
- Consider alternative models (GPT-4, Gemini)
- Prompt engineering optimization
- Multi-turn conversations for complex dumps

---

## Questions to Answer in Future Phases

1. **Do users actually use workspace view, or do they prefer lists?**
   - If lists win, invest in list features over spatial
   - Validate before building Phase 4

2. **Is date parsing accuracy worth the complexity?**
   - Track parsing errors in Phase 3
   - If >20% error rate, reconsider approach

3. **What's the right balance between automation and control?**
   - Claude does too much → users lose agency
   - Claude does too little → users overwhelmed
   - Find sweet spot through iteration

4. **Is sync a must-have or nice-to-have?**
   - Validate multi-device workflow in user testing
   - Many users might be phone-only

---

**Remember:** These are planning notes. Don't implement until earlier phases prove their value. The goal is to build something users love, not to build everything we can imagine.

*Stay focused. Ship early. Validate often.* 🎯
