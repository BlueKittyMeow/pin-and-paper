# Codex Findings - Phase 3.7 Package Research

**Phase:** 3.7 - Natural Language Date Parsing
**Plan Document:** [phase-3.7-plan-v3.md](./phase-3.7-plan-v3.md)
**Review Date:** 2026-01-20
**Reviewer:** Codex
**Review Type:** Pre-Implementation Research (Package Evaluation)
**Status:** ✅ Research Complete

---

## Instructions

This document is for **Codex** to research and evaluate date parsing packages for Phase 3.7.

**🚫 NEVER SIMULATE OTHER AGENTS' RESPONSES 🚫**
**DO NOT write feedback on behalf of Gemini, Claude, or anyone else!**
**ONLY document YOUR OWN findings in this document.**

---

## Research Focus Areas

### 1. Package Evaluation

**Goal:** Find the best Dart package for natural language date parsing.

**Packages to evaluate:**
- `any_date` - Dart package for parsing various date formats
- `chrono_dart` - Natural language date parsing (if available for Dart)
- `jiffy` - Date manipulation library (check if it has parsing)
- `timeago` - Relative date parsing (check capabilities)
- Any others you find on pub.dev

**Evaluation criteria:**
1. **Natural language support:**
   - Can it parse "tomorrow", "next Tuesday", "in 3 days"?
   - Does it handle days of week?
   - Does it support time parsing ("3pm", "morning")?

2. **Extensibility:**
   - Can we add custom rules (Today Window logic)?
   - Can we extend with our own patterns?
   - Is the API flexible?

3. **Quality:**
   - Pub.dev score and popularity
   - Maintenance status (last updated)
   - Issue tracker activity
   - Documentation quality
   - Test coverage

4. **Performance:**
   - Parse speed for common patterns
   - Memory usage
   - Dependencies (lightweight or heavy?)

5. **Compatibility:**
   - Flutter compatibility
   - Dart version requirements
   - Platform support (Android, iOS, web)

---

## Methodology

**How to research:**

```bash
# Search pub.dev for date parsing packages
# Visit: https://pub.dev/packages?q=date+parsing

# For each promising package:
# 1. Check pub.dev page
# 2. Read documentation
# 3. Check GitHub repo (issues, last commit)
# 4. Review API and examples
# 5. Check test coverage
```

**What to look for in package source:**
```bash
# If evaluating a specific package, check:
# - Example code
# - Test files (how well tested is natural language parsing?)
# - API surface (is it intuitive?)
# - Dependencies (does it pull in a lot of other packages?)
```

---

## Required Features (from phase-3.7-plan-v2.md)

**Must parse:**
1. Relative dates: today, tomorrow, yesterday, tonight
2. Days of week: Monday, Tuesday, next Monday, this Friday
3. Relative offsets: in 3 days, in 2 weeks, in 1 month
4. Absolute dates: Jan 15, March 3rd, 2026-01-20, 1/20/2026
5. Time of day: 3pm, 9:30am, morning, afternoon, evening, tonight
6. Combined: tomorrow at 3pm, next Tuesday morning, Jan 15 at 2pm

**Must handle:**
- Case insensitive parsing
- Month/year boundaries
- Ambiguous dates (past → assume next occurrence)
- Multiple date formats (US, European, ISO)

**Critical requirement:**
- We need to integrate "Today Window" logic (see plan v2 for details)
- Package must allow us to customize "today" calculation for night owl mode

---

## Plan Review: phase-3.7-plan-v3.md

**Instructions:** Review the complete Phase 3.7 plan and provide feedback on:
- Architecture and design decisions
- Potential bugs or edge cases
- Performance concerns
- Complexity issues
- Suggested improvements or alternatives
- Missing requirements or considerations

### Overall Assessment

**Plan Quality:** 4/5

**Strengths:**
- Clear scope, UX flows, and success criteria; strong test coverage plan (midnight boundary, locale, invalid dates).
- Good separation of local parsing vs Claude parsing with explicit context injection.
- Conservative parsing posture + explicit escape hatch aligns with risk profile.

**Concerns:**
- Inline highlighting approach uses `RichText` in place of an editable field; this is not directly compatible with user editing and tap targets in `EditableText`.
- `getEffectiveToday()` ignores the cutoff minute despite `today_cutoff_minute` being specified; risk of off-by-minute behavior at the boundary.
- Ambiguity definitions for "this/next <weekday>" vs bare weekday are scattered and potentially inconsistent (tests vs prompt guidance).
- Performance budget (<1ms) may be optimistic if a heavier parser or POS heuristics are adopted.

**Recommendations:**
- Implement inline highlighting by overriding `TextEditingController.buildTextSpan` or by using a custom `EditableText` to keep editing intact; treat clickable spans as optional UX polish.
- Update `getEffectiveToday()` to honor both hour and minute, and add tests for 4:59 vs 5:00.
- Codify weekday semantics in a single spec and share it across local parser + Claude prompt.
- Plan for a small, fast heuristic parser (regex + scoring) and avoid heavy NLP until proven needed.

---

### Specific Feedback by Section

#### The Midnight Problem & Today Window Logic

**Review:** Solid intent, but the algorithm needs minute-level cutoff and explicit weekday semantics.

**Issues:**
- `today_cutoff_minute` is defined but not used in `getEffectiveToday()`; 4:59 vs 5:00 behavior will be wrong if only hour is checked.
- Weekday semantics differ between plan sections (e.g., "Monday" on Monday should be next Monday vs "this Tuesday" can be today). This needs one authoritative rule.
- "tonight" at 1:30am (within today window) is ambiguous; currently unspecified.

**Suggestions:**
- Implement cutoff logic with both hour and minute, e.g. `now.hour < cutoffHour || (now.hour == cutoffHour && now.minute <= cutoffMinute)`.
- Add tests for exact boundary minutes, DST transitions, and "tonight" within the today window.
- Define a single rule set for `this/next/<weekday>` and "bare weekday", then reuse in both local parsing and Claude prompt.

---

#### Real-Time Parsing with Todoist-Style UX

**Review:** UX is strong, but the technical approach to inline highlighting needs adjustment to remain editable and tappable.

**Issues:**
- `RichText` is not an editable input; swapping out `TextField` for `RichText` will break editing/selection.
- Tap recognizers in `EditableText` spans can conflict with cursor placement and selection.
- If parsing state mutates the controller text, you can trigger re-entrant parsing loops unless guarded.

**Suggestions:**
- Implement highlighting by overriding `TextEditingController.buildTextSpan` (keeps TextField editable); keep taps optional or provide a separate “Edit date” chip.
- Use debounced parsing that only updates state (not the controller text) until save to avoid feedback loops.
- Memoize `TapGestureRecognizer` and dispose to prevent leaks if you do use clickable spans.

---

#### Context-Aware Parsing Strategy

**Review:** Conservative parsing is correct, but needs explicit confidence scoring and rule ordering.

**Issues:**
- Month names like "May" and "March" can be modal/verb/proper name; without scoring, false positives are likely.
- Numeric-only dates (1/2/2026) are locale-ambiguous; needs deterministic rule (device locale or explicit preference).

**Suggestions:**
- Use a weighted scoring system: strong indicators (prepositions like "on/in/by", numeric day, "at <time>") add points; known false-positive contexts subtract points.
- Only parse if score >= threshold; if ambiguous, don't highlight but allow manual picker.
- Prefer matches near end of string or after separators (":", "-", "due") to reduce mid-sentence false positives.

---

#### Dual Parsing Strategy (Brain Dump vs Quick Add)

**Review:** Separation makes sense, but consistency rules must be shared.

**Issues:**
- Claude and local parser can diverge on "this/next weekday" and today-window semantics unless the same rule sheet is enforced.
- Time keyword defaults ("morning", "tonight") must match between local and Claude parsing or users will see inconsistent results.

**Suggestions:**
- Define a shared "date semantics contract" (today window, weekday rules, time keywords) and include it in both local parser and Claude prompt.
- Add cross-check tests where the same input is run through both parsers with the same `effectiveToday`.

---

#### Database & Settings

**Review:** No schema changes required, but settings usage should match the algorithm.

**Issues:**
- `today_cutoff_minute` is stored but not used in the proposed algorithm.
- Ambiguous numeric dates (MDY vs DMY) need a deterministic rule.

**Suggestions:**
- Ensure cutoff minute is honored in `getEffectiveToday()`.
- Add a simple preference or locale-derived rule for numeric date parsing and document it.

---

#### Testing Strategy

**Review:** Strong overall, but a few key edge cases are missing.

**Issues:**
- No explicit tests for minute-level cutoff boundary (4:59 vs 5:00).
- No DST boundary tests (spring forward/fall back) for today window correctness.
- No tests for “in 1 month” from Jan 31 / Mar 31 (end-of-month rollover).

**Suggestions:**
- Add tests for minute boundary, DST shift, and end-of-month rollovers.
- Add tests for "tonight" in today-window hours and at 6pm to lock semantics.

---

#### Implementation Timeline

**Review:** 1.5-2 weeks is achievable if a lightweight parser is chosen; inline editing UX is the main risk.

**Issues:**
- Inline highlighting + editable text is a known complexity in Flutter; this could add unexpected time.
- If a third-party parser is used and needs adaptation, integration time could expand.

**Suggestions:**
- De-risk by prototyping the editable-highlight approach early.
- If the package route looks weak, choose hybrid/custom quickly to avoid churn.

---

### Critical Bugs or Blockers

**Bugs Found in Plan:**
1. `getEffectiveToday()` ignores `today_cutoff_minute`, which will mis-handle 4:59 vs 5:00 boundary cases - Severity: MEDIUM.

**Blockers:**
1. Inline highlighting approach uses `RichText` in place of an editable field; this is not directly compatible with user editing and needs a different implementation strategy - Impact: High UX risk.

---

### Architectural Improvements

**Suggested Changes:**
1. Use `TextEditingController.buildTextSpan` (or a custom `EditableText`) to keep text editable while applying inline styles - Rationale: preserves editing + highlighting - Impact: avoids UX blocker.
2. Define a shared "date semantics contract" for local + Claude (today window, weekday rules, time keywords) - Rationale: consistency - Impact: reduces user confusion.

---

### Missing Considerations

**Not Addressed in Plan:**
- DST transitions and timezone changes while app is running (today window boundaries can shift).
- Locale handling for ambiguous numeric dates (MM/DD vs DD/MM).
- Clear semantic definition for "tonight" when invoked after midnight within today window.

---

## Plan Review Status

- [x] Overall plan reviewed
- [x] Midnight Problem algorithm reviewed
- [x] Real-time parsing UX reviewed
- [x] Context-aware parsing reviewed
- [x] Dual parsing strategy reviewed
- [x] Database & settings reviewed
- [x] Testing strategy reviewed
- [x] Timeline reviewed
- [x] Feedback documented above

**Sign-off:** 2026-01-20 - Approved with concerns

---

## Research Task 1: Context-Aware Parsing Best Practices

**Goal:** Understand how to prevent false positives like "May need" being parsed as "May (month)"

**Note:** Network access is restricted in this environment. Findings below are based on general NLP best practices and observed app behavior, not live web research.

### Findings

**1) How other apps likely mitigate false positives (anecdotal):**
- Todoist/Things/TickTick bias toward parsing when a date token is near a clear indicator (prepositions like "on/in/by", a numeric day, or a time).
- Date tokens placed near the end of the input are more likely to parse; mid-sentence lone month names are often ignored.
- All three apps lean on visible highlighting + easy removal as the escape hatch for false positives.

**2) NLP techniques and heuristics that work well without heavy NLP:**
- **Rule ordering**: parse high-confidence patterns first (relative words, weekday + time, month + day number).
- **Context indicators**: require nearby tokens such as "on", "in", "by", "due", "at", ":".
- **Negative context**: skip modal-verb patterns ("may need", "may I"), verb usage ("march forward"), or "maybe".
- **Position bias**: prefer date matches at end of string or after separators (" - ", ": ", "due ").
- **Confidence scoring**: only parse if score >= threshold; keep low-confidence matches unparsed.

**3) Existing library behavior (general):**
- `chrono` (JS) and `dateparser` (Python) tend to use a mix of regex patterns plus context heuristics and preference for explicit indicators.
- They typically allow "month + number" and "weekday + time" with high confidence, and are conservative with bare month names.

### Research Deliverables

**1. Context Rules Document:**
```markdown
# Context-Aware Parsing Rules

## Strong Date Indicators (DO parse)
- "in [month]" → "in May" → Preposition indicates time context
- "on [weekday]" → "on Tuesday" → Explicit date marker
- "[month] [number]" → "May 15" → Day number confirms date
- "[weekday] at [time]" → "Tuesday at 3pm" → Time anchors date intent
- "[relative] at [time]" → "tomorrow at 5" → Relative + time is unambiguous

## False Positive Patterns (DON'T parse)
- "[month] need" → "May need" → Common modal phrase
- "[month] I" → "May I" → Question construction
- "maybe" → "Maybe call dentist" → Partial word match
- "[month] [verb]" → "March forward" → Verb usage
- "with [month]" → "Meeting with April" → Likely proper name

## Confidence Scoring
- High confidence (always parse): relative words, explicit prepositions, numeric day, or time attached.
- Medium confidence: bare month at end of string or after punctuation ("Due: May").
- Low confidence (skip): modal verb contexts, mid-sentence month names without indicators.
```

**2. Recommended Implementation:**
- Use regex + token scoring; avoid heavy POS/NLP in Dart unless needed.
- Apply negative-context rules before parsing (e.g., `may` modal phrases, "march forward").
- Parse from the rightmost token or last plausible date span (users often append dates).
- Require indicators for month-only matches unless a day number is present.

**3. Test Cases:**
```dart
// False positives we MUST avoid:
"May need to call dentist" → null
"May I suggest..." → null
"Meeting with April" → null
"March forward with plans" → null

// True positives we MUST catch:
"Call dentist in May" → May
"Meeting May 15" → May 15
"Due by April" → April
"March deadline" → March
```

---

## Research Task 2: Package Evaluation

**Note:** Network access is restricted, so package metadata is not verified here. Evaluation is based on typical usage/known capabilities.

### Package 1: any_date

**Pub.dev link:** Not verified
**GitHub:** Not verified
**Last updated:** Not verified
**Pub score:** Not verified

**Natural Language Support:**
- [ ] Relative dates (today, tomorrow)
- [ ] Days of week (Monday, next Tuesday)
- [ ] Relative offsets (in 3 days)
- [x] Absolute dates (Jan 15 / ISO / numeric formats)
- [ ] Time parsing (3pm, morning)
- [ ] Combined parsing (tomorrow at 3pm)

**Context Awareness:**
- [ ] Handles "May need" correctly (doesn't parse as May)?
- [ ] Requires date indicators (in, on, at)?
- [ ] Has confidence scoring?
- [ ] Documented approach to false positives?

**Pros:**
- Likely solid for strict absolute date formats.

**Cons:**
- Not a natural language parser in typical usage.

**Extensibility:**
- Today Window logic must be layered on top (custom pre/post-processing).
- Context rules require custom filtering.

**Recommendation:**
- Maybe (use only for absolute formats as a helper).

---

### Package 2: jiffy

**Pub.dev link:** Not verified
**GitHub:** Not verified
**Last updated:** Not verified
**Pub score:** Not verified

**Natural Language Support:**
- [ ] Relative dates (today, tomorrow)
- [ ] Days of week (Monday, next Tuesday)
- [ ] Relative offsets (in 3 days)
- [x] Absolute dates (format-based)
- [ ] Time parsing (3pm, morning)
- [ ] Combined parsing (tomorrow at 3pm)

**Context Awareness:**
- [ ] Handles "May need" correctly (doesn't parse as May)?
- [ ] Requires date indicators (in, on, at)?
- [ ] Has confidence scoring?
- [ ] Documented approach to false positives?

**Pros:**
- Strong date manipulation utilities.
- Useful once a date is parsed.

**Cons:**
- Not a natural language parser.

**Extensibility:**
- Useful for date math; not for parsing logic.

**Recommendation:**
- Don't recommend as NL parser; keep for date math if needed.

---

### Package 3: timeago

**Pub.dev link:** Not verified
**GitHub:** Not verified
**Last updated:** Not verified
**Pub score:** Not verified

**Natural Language Support:**
- [ ] Relative dates (today, tomorrow)
- [ ] Days of week (Monday, next Tuesday)
- [ ] Relative offsets (in 3 days)
- [ ] Absolute dates (Jan 15)
- [ ] Time parsing (3pm, morning)
- [ ] Combined parsing (tomorrow at 3pm)

**Context Awareness:**
- [ ] Handles "May need" correctly (doesn't parse as May)?
- [ ] Requires date indicators (in, on, at)?
- [ ] Has confidence scoring?
- [ ] Documented approach to false positives?

**Pros:**
- Good for formatting relative times ("2 hours ago").

**Cons:**
- Not a parser.

**Extensibility:**
- Not applicable for parsing.

**Recommendation:**
- Not suitable for NL parsing.

---

### Package 4: chrono_dart (if available)

**Pub.dev link:** Not verified
**GitHub:** Not verified
**Last updated:** Not verified
**Pub score:** Not verified

**Natural Language Support:**
- [ ] Relative dates (today, tomorrow)
- [ ] Days of week (Monday, next Tuesday)
- [ ] Relative offsets (in 3 days)
- [ ] Absolute dates (Jan 15)
- [ ] Time parsing (3pm, morning)
- [ ] Combined parsing (tomorrow at 3pm)

**Context Awareness:**
- [ ] Handles "May need" correctly (doesn't parse as May)?
- [ ] Requires date indicators (in, on, at)?
- [ ] Has confidence scoring?
- [ ] Documented approach to false positives?

**Pros:**
- If it mirrors JS chrono, it may include useful heuristics.

**Cons:**
- Existence/maintenance/quality unknown without verification.

**Extensibility:**
- Unknown; would need verification.

**Recommendation:**
- Need more research/verification.

---

## Comparison Matrix

| Package | Natural Lang | Context Aware | Extensible | Quality | Recommendation |
|---------|-------------|---------------|------------|---------|----------------|
| any_date | ⭐ | ⭐ | ⭐⭐ | ⭐⭐ | Maybe (absolute formats only) |
| jiffy | ⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐⭐ | No (date math only) |
| timeago | ⭐ | ⭐ | ⭐ | ⭐⭐⭐ | No |
| chrono_dart | ? | ? | ? | ? | Verify first |

---

## Final Recommendation

**Best option:** Custom implementation (with optional helper for absolute formats).

**Rationale:**
- No clearly suitable Dart NL parsing package is evident without deeper verification, and common packages are formatting/manipulation-only.
- A lightweight custom parser can be tailored to Today Window logic and conservative context rules.
- We can optionally use a helper package (or `intl`/`DateFormat`) for strict absolute formats.

**Implementation approach:**
- Option 2: Hybrid (custom parser for NL + helper for absolute formats).

**Recommended:** Hybrid (custom + helper). If chrono_dart is verified and maintained, revisit.

---

## Next Steps

1. [x] Complete package evaluation (offline assessment)
2. [ ] Discuss findings with Gemini and Claude
3. [ ] Make final decision on package vs custom
4. [ ] Update phase-3.7-plan-v3.md with chosen approach
5. [ ] Begin core parser implementation

---

**Notes:**
- Codex's focus: Package quality, API design, extensibility
- Cross-check with Gemini's findings for build/compatibility issues
- Remember: We can always fall back to custom implementation if packages insufficient
