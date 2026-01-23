# Phase 3.7 Plan - Natural Language Date Parsing

**Version:** 1
**Created:** 2026-01-20
**Status:** Draft

---

## Scope

Phase 3.7 adds natural language date parsing to Pin and Paper, allowing users to specify due dates using human-friendly phrases instead of manual date pickers.

**From PROJECT_SPEC.md:**
- Parse relative dates ("tomorrow", "next Tuesday", "in 3 days")
- Parse absolute dates ("Jan 15", "March 3rd")
- Time-of-day support ("3pm", "morning", "evening")
- Night owl mode (configurable midnight boundary)
- Integration with Brain Dump and task creation

---

## Motivation

**Current UX:**
- Users must tap date picker icon → select date → optionally select time
- Requires multiple taps and visual context switching
- Slower than typing, especially for common relative dates

**Improved UX:**
- Users can type naturally: "Fix bug tomorrow at 3pm"
- Parser extracts date/time, task title becomes "Fix bug"
- Fallback to manual picker for ambiguous or unrecognized dates
- Reduces friction for date entry during task capture

---

## Technical Approach

### Date Parsing Strategy

**Option 1: Local Dart Package**
- Use existing package like `any_date` or `chrono_dart`
- Pro: No API cost, works offline, fast
- Con: May have limited natural language support

**Option 2: Custom Parser**
- Write regex-based parser for common patterns
- Pro: Full control, optimized for our use cases
- Con: More complex, needs thorough testing

**Option 3: Hybrid**
- Use package for basic parsing (dates, days of week)
- Add custom rules for our specific patterns
- Pro: Best of both worlds
- Con: Slightly more complex architecture

**Recommended:** Start with Option 1 (package evaluation), extend with custom rules if needed.

### Integration Points

1. **Task Creation (TaskService)**
   - Add `parseDateFromString(String text)` method
   - Returns `(title, dueDate, isAllDay)` tuple
   - Strips date phrases from task title

2. **Edit Task Dialog**
   - Add smart date input field with autocomplete/preview
   - Show parsed date as user types
   - Manual picker as fallback

3. **Brain Dump (AI Integration)**
   - Parse dates from natural language before or after AI extraction
   - Example: "Call dentist tomorrow" → task "Call dentist", due: tomorrow

4. **Quick Add (Future)**
   - If we add quick-add from home screen, date parsing is essential

### Night Owl Mode

**Problem:** For night owls working at 2am, "tomorrow" should mean "later today" not "in 4 hours"

**Solution:** Configurable "day boundary" (default: 4am)
- Before boundary: "tomorrow" = same calendar day
- After boundary: "tomorrow" = next calendar day
- Stored in settings/preferences

---

## Subphases

This is a focused single-feature phase. No subphase breakdown needed unless implementation reveals complexity.

**Potential breakdown (if needed):**
- 3.7A: Core date parser + tests
- 3.7B: Integration with task creation and edit dialog
- 3.7C: Night owl mode + settings

**Prefer:** Keep as single phase 3.7 unless implementation gets complex.

---

## Dependencies

### External Packages

**Evaluate:**
- `any_date` - Dart package for parsing various date formats
- `chrono_dart` - Natural language date parsing (if available)
- `intl` (already included) - Date formatting

**Add if needed:**
```yaml
# To be determined after research
```

### Existing Code

- Phase 3.6.5: Time picker infrastructure (`isAllDay` field)
- Phase 3.4: Due date storage and display
- Phase 2: Brain Dump AI integration (task extraction)

### System Dependencies

- User's locale settings (for date format interpretation)
- System timezone (for "today"/"tomorrow" calculation)

---

## Open Questions

1. **Package Selection**
   - Which Dart package has best natural language date support?
   - Does it handle relative dates well ("next Tuesday")?
   - Performance characteristics?

2. **Parsing Strategy**
   - Parse dates from task title on input, or on save?
   - Show live preview as user types?
   - How to handle ambiguous dates ("May" = month or verb)?

3. **UI/UX Details**
   - Should date parsing be automatic or opt-in?
   - How to show parsed date preview?
   - How to correct mis-parsed dates?
   - Should we show "tomorrow" vs "Jan 21" in task display?

4. **Night Owl Mode**
   - Default boundary time (4am suggested)?
   - Should this be per-user setting or app-wide?
   - UI location for this setting?

5. **Scope Boundaries**
   - Do we parse dates in notes/descriptions, or only in title?
   - Do we support recurring dates ("every Monday") in this phase?
   - Do we support date ranges ("Jan 10-15")?

---

## Success Criteria

**Must Have:**
- ✅ Parse common relative dates (today, tomorrow, next week)
- ✅ Parse days of week (Monday, Tuesday, etc.)
- ✅ Parse absolute dates (Jan 15, March 3rd, 2026-01-20)
- ✅ Extract and strip date phrases from task titles
- ✅ Integration with task creation and edit dialog
- ✅ Comprehensive tests for parser edge cases
- ✅ Works correctly across month/year boundaries

**Should Have:**
- ✅ Time-of-day parsing (3pm, morning, evening)
- ✅ Combine date + time ("tomorrow at 3pm")
- ✅ Night owl mode setting
- ✅ Smart defaults (relative dates default to all-day)

**Nice to Have:**
- ✅ Relative dates with offsets ("in 3 days", "in 2 weeks")
- ✅ Intelligent ambiguity resolution
- ✅ Locale-aware date parsing (format variations)
- ✅ Visual preview of parsed date in edit dialog

**Out of Scope (Defer to Future):**
- ❌ Recurring dates ("every Monday")
- ❌ Date ranges ("Jan 10-15")
- ❌ Natural language relative times ("in 30 minutes")
- ❌ Date parsing in task notes/descriptions

---

## Testing Strategy

### Unit Tests (DateParser)
- Relative dates (today, tomorrow, yesterday)
- Days of week (next/this Monday, Tuesday)
- Absolute dates (various formats)
- Time parsing (12h/24h, named times)
- Combined date + time
- Month/year boundaries
- Night owl mode boundaries
- Malformed/ambiguous inputs

### Integration Tests
- TaskService integration
- Edit dialog integration
- Brain Dump integration

### Manual Testing
- Various locales (US, UK, etc.)
- Timezone edge cases
- Night owl workflow (2am task creation)

---

## Timeline Estimate

**Estimated Duration:** 1-2 weeks (per PROJECT_SPEC.md)

**Breakdown:**
1. Research and package evaluation: 0.5 days
2. Core parser implementation: 1-2 days
3. Integration with task creation: 1 day
4. UI integration (edit dialog): 1 day
5. Night owl mode + settings: 0.5 days
6. Testing and bug fixes: 1-2 days
7. Validation and documentation: 1 day

**Total:** 6-9 days (roughly 1-2 weeks)

---

## Related Documents

- [PROJECT_SPEC.md](../PROJECT_SPEC.md) - Phase 3.7 official scope
- [archive/phase-3.6.5/phase-3.6.5-implementation-report.md](../../archive/phase-3.6.5/phase-3.6.5-implementation-report.md) - Previous phase context
- [templates/phase-start-checklist.md](../templates/phase-start-checklist.md) - Workflow reference

---

## Notes

- Phase 3.7 is the penultimate phase before Phase 3 completion
- Natural language dates significantly reduce friction for users
- This feature pairs well with Brain Dump (Phase 2) and Quick Add (future)
- Consider voice input compatibility (Phase 3+ goal)

---

**Next Steps:**
1. Review this v1 plan with BlueKitty
2. Refine based on feedback → v2
3. Research date parsing packages
4. When approved, create detailed implementation plan
5. Initialize agent findings docs (codex-findings.md, gemini-findings.md)
