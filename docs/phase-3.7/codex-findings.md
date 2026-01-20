# Codex Findings - Phase 3.7 Package Research

**Phase:** 3.7 - Natural Language Date Parsing
**Plan Document:** [phase-3.7-plan-v2.md](./phase-3.7-plan-v2.md)
**Review Date:** 2026-01-20
**Reviewer:** Codex
**Review Type:** Pre-Implementation Research (Package Evaluation)
**Status:** ⏳ Pending Research

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

## Findings

### Package 1: [Name]

**Pub.dev link:** [URL]
**GitHub:** [URL]
**Last updated:** [Date]
**Pub score:** [Score]

**Natural Language Support:**
- [ ] Relative dates (today, tomorrow)
- [ ] Days of week (Monday, next Tuesday)
- [ ] Relative offsets (in 3 days)
- [ ] Absolute dates (Jan 15)
- [ ] Time parsing (3pm, morning)
- [ ] Combined parsing (tomorrow at 3pm)

**Pros:**
- [List benefits]

**Cons:**
- [List limitations]

**Extensibility:**
- [Can we add Today Window logic? How?]

**Recommendation:**
- [Recommend / Don't recommend / Need more research]

---

### Package 2: [Name]

[Repeat format above]

---

## Comparison Matrix

| Package | Natural Lang | Extensible | Quality | Performance | Recommendation |
|---------|-------------|------------|---------|-------------|----------------|
| [Name]  | ⭐⭐⭐      | ⭐⭐       | ⭐⭐⭐  | ⭐⭐⭐      | [Yes/No/Maybe] |

---

## Final Recommendation

**Best option:** [Package name OR "Custom implementation"]

**Rationale:**
- [Explain why this is the best choice]
- [Address how it meets our requirements]
- [Explain how we'll handle Today Window logic]

**Implementation approach:**
- Option 1: Use package as-is
- Option 2: Use package + extend with custom rules
- Option 3: Build custom parser (if no suitable package found)

**Recommended:** [Which option?]

---

## Next Steps

1. [ ] Complete package evaluation
2. [ ] Discuss findings with Gemini and Claude
3. [ ] Make final decision on package vs custom
4. [ ] Update phase-3.7-plan-v2.md with chosen approach
5. [ ] Begin core parser implementation

---

**Notes:**
- Codex's focus: Package quality, API design, extensibility
- Cross-check with Gemini's findings for build/compatibility issues
- Remember: We can always fall back to custom implementation if packages insufficient
