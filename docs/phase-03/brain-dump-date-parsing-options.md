# Brain Dump Date Parsing: Architectural Options

**Date:** 2025-10-30
**Purpose:** Compare two approaches for handling date parsing in Brain Dump (typed + voice)
**Status:** Pending team review (Gemini, Codex, Claude)

---

## Context

Brain Dump allows users to capture tasks via typed text or voice input. The text is sent to Claude for task extraction. The question is: **Who should apply user time preference rules?**

**User Preferences Include:**
- `todayCutoffHour`: "today" at 2am might mean "yesterday" (night owl mode)
- `morningHour`, `afternoonHour`, `tonightHour`: What time does "morning" mean?
- `weekStartDay`: Does the week start Sunday or Monday?
- `weekendStartDay`: Does weekend start Friday or Saturday?
- Plus timezone, 24hr format, etc.

---

## Option 1: Claude Applies User Preferences

### Flow
```
User: "call marie tomorrow, bank next friday, pat cat tomorrow morning"
    ↓
Send to Claude API:
  - Raw text: "call marie tomorrow, bank next friday, pat cat tomorrow morning"
  - UserSettings context: {morningHour: 9, todayCutoffHour: 4, ...}
  - System prompt: "Respect these user preferences when parsing dates"
    ↓
Claude parses with rules:
  - Task 1: "call marie" + due_date: 2025-10-31T00:00:00
  - Task 2: "go to the bank" + due_date: 2025-11-07T00:00:00
  - Task 3: "pat cat" + due_date: 2025-10-31T09:00:00 (user's morningHour)
    ↓
Display tasks to user for approval
```

### Pros
- ✅ Single-stage processing (Claude does everything)
- ✅ Claude can use context for ambiguous cases
- ✅ Simple flow (one API call returns final dates)

### Cons
- ❌ **Token cost:** +50-70 tokens per request for UserSettings context
- ❌ **Inference cost:** Claude must reason about user rules (more thinking)
- ❌ **Reliability:** Must trust Claude implements midnight purist logic correctly
- ❌ **Two sources of truth:** DateParserService (for Quick Add) AND Claude (for Brain Dump)
- ❌ **Maintenance:** If user pref behavior changes, must update BOTH:
  - `DateParserService` code (for Quick Add Field)
  - Claude system prompt (for Brain Dump)
- ❌ **Testing difficulty:** Can't easily test if Claude respects rules without live API calls
- ❌ **Debugging:** If "tomorrow morning" is wrong, is it Claude's fault or our prompt?

### Cost Estimate
- UserSettings context: ~60 tokens per request
- Additional thinking: ~10-20 tokens (reasoning about rules)
- **Total overhead:** ~70-80 tokens per Brain Dump
- **Annual cost** (1000 Brain Dumps/year): ~$0.60/year at current rates

---

## Option 2: Claude Extracts, Local Parses (RECOMMENDED)

### Flow
```
User: "call marie tomorrow, bank next friday, pat cat tomorrow morning"
    ↓
Send to Claude API:
  - Raw text only (no user settings)
  - System prompt: "Extract tasks and date PHRASES verbatim"
    ↓
Claude extracts (no rule application):
  - Task 1: "call marie" + datePhrase: "tomorrow"
  - Task 2: "go to the bank" + datePhrase: "next friday"
  - Task 3: "pat cat" + datePhrase: "tomorrow morning"
    ↓
Local DateParserService.parse() [BEFORE showing to user]:
  - "tomorrow" → 2025-10-31 (apply todayCutoffHour if needed)
  - "next friday" → 2025-11-07 (apply week logic)
  - "tomorrow morning" → 2025-10-31T09:00:00 (apply morningHour)
    ↓
Display tasks to user with FINAL dates
```

### Pros
- ✅ **Cost reduction:** No UserSettings context (~60 tokens saved per request)
- ✅ **Simpler Claude task:** Just extract, don't reason about rules
- ✅ **Single source of truth:** DateParserService is the ONLY place user rules exist
- ✅ **Consistency:** "tomorrow morning" means the SAME thing in Quick Add and Brain Dump
- ✅ **Maintainability:** Change user pref? Update ONE place (DateParserService)
- ✅ **Testability:** DateParserService is pure Dart code (easily unit tested)
- ✅ **Debugging:** Date parsing bugs are always in DateParserService (clear ownership)
- ✅ **Separation of concerns:**
  - Claude: "What is a task? What looks like a date phrase?"
  - Local: "What does 'tomorrow' mean for THIS user at 2am?"
- ✅ **No pre-processing tangle:** Claude gets raw text, never touches preferences

### Cons
- ⚠️ **Two-stage processing:** Extract → parse (slightly more complex flow)
  - **Counter:** This is actually a PRO for debugging and testing
- ⚠️ **Unrecognized phrases:** If Claude returns "soon" or "asap", DateParserService won't parse it
  - **Counter:** Acceptable failure mode - user manually sets date
  - **Mitigation:** Add common synonyms to DateParserService over time
- ⚠️ **Requires structured response:** Claude must return `datePhrase` field
  - **Counter:** We already parse JSON responses, no big deal

### Cost Savings
- UserSettings context saved: ~60 tokens per request
- Simpler reasoning: ~10-20 tokens saved
- **Total savings:** ~70-80 tokens per Brain Dump
- **Annual savings** (1000 Brain Dumps/year): ~$0.60/year at current rates
- **Bonus:** Faster responses (less inference time)

---

## Comparison Table

| Aspect | Option 1 (Claude Applies Rules) | Option 2 (Local Applies Rules) |
|--------|--------------------------------|-------------------------------|
| **Token Cost** | +60 tokens/request | Base cost only |
| **Inference Cost** | Higher (more reasoning) | Lower (simple extraction) |
| **Source of Truth** | 2 places (DateParserService + Claude) | 1 place (DateParserService only) |
| **Consistency** | Quick Add ≠ Brain Dump (different engines) | Quick Add = Brain Dump (same engine) |
| **Maintainability** | Update 2 places per rule change | Update 1 place per rule change |
| **Testability** | Hard (requires API calls) | Easy (pure Dart unit tests) |
| **Debugging** | Unclear (Claude or prompt issue?) | Clear (DateParserService owns it) |
| **Reliability** | Trust Claude's implementation | Trust our own code |
| **Failure Mode** | Wrong date applied | No date applied (user sets manually) |
| **Architecture** | Simple flow, complex responsibility | Two stages, clear separation |

---

## Recommendation: Option 2

**Rationale:**

1. **Architectural Purity** - Each component does what it's best at:
   - Claude: Natural language understanding, task extraction
   - DateParserService: Date parsing, user rule application

2. **Cost Efficiency** - Saves ~$0.60/year per 1000 Brain Dumps (small but real)

3. **Single Source of Truth** - DateParserService is the ONLY date parsing logic
   - Easier to maintain
   - Easier to test
   - Easier to debug
   - Guaranteed consistency

4. **Better Long-Term Maintainability** - As user preferences grow:
   - Add new preference → update DateParserService → done
   - No need to update Claude prompts or worry about LLM implementing rules correctly

5. **No Pre-Processing Tangle** - Claude gets raw text, local parsing happens AFTER
   - Clean separation
   - No risk of mangled input

---

## Implementation Details (Option 2)

### Claude Response Format

**Current Format:**
```json
{
  "tasks": [
    {
      "title": "Call Marie",
      "notes": null
    }
  ]
}
```

**New Format (Option 2):**
```json
{
  "tasks": [
    {
      "title": "call marie",
      "datePhrase": "tomorrow",       // ← NEW FIELD (optional)
      "timePhrase": null,              // ← NEW FIELD (optional, for standalone times)
      "notes": null
    },
    {
      "title": "go to the bank",
      "datePhrase": "next friday",
      "timePhrase": null,
      "notes": null
    },
    {
      "title": "pat cat",
      "datePhrase": "tomorrow morning",  // Combined date+time phrase
      "timePhrase": null,
      "notes": null
    }
  ]
}
```

**Field Rules:**
- `datePhrase`: Extract verbatim, don't parse or convert
- `timePhrase`: For standalone times like "3pm" (no date context)
- If no date/time detected: both fields are `null`

### Claude System Prompt Update

**Add to Brain Dump prompt:**
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

### Brain Dump Processing Flow

```dart
// 1. Send to Claude (existing code, just update response parsing)
final response = await claudeAPI.extractTasks(userText);

// 2. NEW: Parse date phrases locally BEFORE showing to user
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

  // Parse standalone time if present (apply to "today")
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
    // ... other fields
  ));
}

// 3. Show tasks to user for approval (existing UI)
await showTaskSuggestionPreview(parsedTasks);
```

---

## Handling Edge Cases

### Case 1: Unrecognized Date Phrases

**Example:** User says "call dentist asap"
- Claude returns: `datePhrase: "asap"`
- DateParserService doesn't recognize "asap"
- Result: Task created with `due_date = NULL`
- **Acceptable:** User can manually set date

### Case 2: Ambiguous Phrases - "soon" and "later"

**🆕 NEW SYNONYMS TO ADD:**

**"later":**
- **Meaning:** Undated task (goes to "unsorted" section)
- **Implementation:** DateParserService recognizes "later" but returns `null` date
- **Rationale:** User explicitly defers scheduling

**"soon":**
- **Meaning:** TBD (options below)
- **Option A:** Treat as undated (like "later")
- **Option B:** Ask user's definition in onboarding quiz
  - "What does 'soon' mean to you?"
  - A: Today (urgent)
  - B: This week
  - C: I'll decide later (undated)
- **Provisional Decision:** Treat as undated for now
- **Future Enhancement:** Add onboarding question

**Add to DateParserService:**
```dart
ParsedDate? _parseDeferralKeywords(String text) {
  if (text.contains('later') || text.contains('soon') || text.contains('someday')) {
    // User explicitly defers scheduling
    return ParsedDate(
      dateTime: null,
      isAllDay: true,
      matchedPhrase: text,
      isDeferral: true,  // NEW FLAG: signals "user wants this undated"
    );
  }
  return null;
}
```

### Case 3: Multiple Date Phrases

**Example:** "call mom tomorrow or friday"
- Claude returns: `datePhrase: "tomorrow or friday"`
- DateParserService tries to parse, likely fails
- Result: Task with no date
- **Acceptable:** Ambiguous input → user clarifies manually

### Case 4: Claude Misses Date Phrase

**Example:** "dentist 3pm" → Claude returns no datePhrase
- Result: Task with no date
- **Acceptable:** User sets date manually
- **Mitigation:** Over time, retrain/improve Claude's extraction

---

## Testing Strategy (Option 2)

### Unit Tests (Easy!)
```dart
test('DateParserService respects midnight purist setting', () {
  // Mock time to 2:00am
  withClock(Clock.fixed(DateTime(2025, 10, 31, 2, 0)), () {
    final settings = UserSettings(todayCutoffHour: 0);  // Midnight purist
    final parser = DateParserService(settings);

    final result = parser.parse('tomorrow');

    // At 2am with midnight cutoff, "tomorrow" = Oct 31 (current calendar day)
    expect(result.dateTime!.day, 31);
  });
});

test('DateParserService respects night owl setting', () {
  withClock(Clock.fixed(DateTime(2025, 10, 31, 2, 0)), () {
    final settings = UserSettings(todayCutoffHour: 5);  // Night owl
    final parser = DateParserService(settings);

    final result = parser.parse('tomorrow');

    // At 2am with 5am cutoff, "tomorrow" = Nov 1
    expect(result.dateTime!.day, 1);
    expect(result.dateTime!.month, 11);
  });
});

test('DateParserService handles "later" as undated', () {
  final parser = DateParserService(UserSettings.defaults());

  final result = parser.parse('review report later');

  expect(result.dateTime, isNull);
  expect(result.isDeferral, true);
});
```

### Integration Tests
```dart
testWidgets('Brain Dump applies user preferences to extracted dates', (tester) async {
  // Set user to night owl (5am cutoff)
  await setUserSettings(UserSettings(todayCutoffHour: 5));

  // Input text at 2am
  withClock(Clock.fixed(DateTime(2025, 10, 31, 2, 0)), () async {
    await tester.pumpWidget(BrainDumpScreen());
    await tester.enterText(find.byType(TextField), 'call mom tomorrow');
    await tester.tap(find.text('Claude, Help Me'));
    await tester.pumpAndSettle();

    // Claude extracts: datePhrase: "tomorrow"
    // Local parser applies: 2am + 5am cutoff → Nov 1
    final task = find.text('call mom');
    expect(task, findsOneWidget);

    final dateText = find.text('Nov 1');  // Not Oct 31!
    expect(dateText, findsOneWidget);
  });
});
```

---

## Migration Path

### Phase 3.3 (Current - Group 1)
- ✅ Build DateParserService with all user preference logic
- ✅ Integrate with Quick Add Field (if toggle enabled)
- ✅ Comprehensive unit tests

### Phase 3.4 (Group 2)
- 🔄 Update Claude system prompt (extract date phrases verbatim)
- 🔄 Update Brain Dump response parsing (add `datePhrase` field)
- 🔄 Add post-extraction date parsing step (call DateParserService)
- 🔄 Test integration with user preferences
- 🔄 Add "later" and "soon" to DateParserService

### Future Enhancements
- Add onboarding quiz question: "What does 'soon' mean to you?"
- Expand synonym list based on user feedback ("asap", "urgent", "whenever", etc.)
- Add ML feedback loop: Track which phrases Claude extracts that we can't parse

---

## Questions for Team Discussion

### For Gemini:
1. Does Option 2's two-stage processing introduce unacceptable complexity?
2. Are there edge cases where Claude needs user context to extract correctly?
3. Any concerns about reliability of Claude extracting phrases verbatim?

### For Codex:
1. Implementation complexity: Is the post-extraction parsing step clean in the codebase?
2. Any Dart-specific concerns with this architecture?
3. Performance implications of two-stage processing?

### For Claude (me):
1. Can you reliably extract date phrases verbatim without parsing them?
2. Are there cases where you need user context to understand intent?
3. Would simpler extraction (Option 2) reduce your error rate?

### For BlueKitty:
1. Does the cost savings matter ($0.60/year per 1000 uses)?
2. Is "single source of truth" worth the two-stage processing?
3. Are you comfortable with the failure mode (unrecognized phrases → no date)?

---

## Voting

**Please indicate your preference and reasoning:**

- [ ] **Option 1** (Claude applies user preferences) - Why?
- [ ] **Option 2** (Local applies user preferences) - Why?
- [ ] **Need more information** - What questions?

---

## Decision Log

**Pending:** Team review in progress

**BlueKitty's Initial Take:** ✅ Option 2 (proposed this approach)
**Claude's Initial Take:** ✅ Option 2 (cleaner architecture, lower cost, single source of truth)

**Final Decision:** TBD after team discussion

---

**Created By:** BlueKitty + Claude
**Last Updated:** 2025-10-30
**Status:** 📋 Ready for team review
