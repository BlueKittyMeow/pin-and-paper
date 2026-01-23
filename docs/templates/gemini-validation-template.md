# Gemini Validation - Phase [X.Y]

**DO NOT edit this template directly!**
**ALWAYS copy to `docs/phase-XX/gemini-validation.md` and customize.**

```bash
# Correct usage:
cp docs/templates/gemini-validation-template.md docs/phase-XX/gemini-validation.md
# Then edit gemini-validation.md to fill in phase details
```

---

**Phase:** [X.Y - Brief Description]
**Implementation Report:** [Link to phase-X.Y-implementation-report.md]
**Validation Doc:** [Link to phase-X.Y-validation-v1.md]
**Review Date:** [YYYY-MM-DD]
**Reviewer:** Gemini
**Status:** Pending Review

---

## Purpose

This document is for **Gemini** to validate Phase [X.Y] **after implementation is complete**.

Unlike the findings doc (used during implementation for ongoing bug hunting), this is a focused post-implementation review covering build verification, static analysis, schema review, and UI/accessibility checks.

**NEVER SIMULATE OTHER AGENTS' RESPONSES.**
Only document YOUR OWN findings here.

---

## Validation Scope

**Files to review:**
- [ ] `lib/[primary file 1].dart`
- [ ] `lib/[primary file 2].dart`
- [ ] `lib/[primary file 3].dart`
- [ ] `test/[test file 1].dart`
- [ ] `test/[test file 2].dart`

**Features to validate:**
1. [Feature 1 from implementation report]
2. [Feature 2 from implementation report]
3. [Feature 3 from implementation report]

---

## Build Verification

```bash
cd pin_and_paper

# Clean build
flutter clean && flutter pub get

# Static analysis
flutter analyze

# Run tests
flutter test

# Build verification
flutter build linux --debug
# OR: flutter build apk --debug
```

### Build Results

**flutter analyze:**
```
[Paste output or "No issues found"]
```

**flutter test:**
```
Tests: [X] passing, [X] failing, [X] skipped
```

**flutter build:**
```
[Paste summary or "Build successful"]
```

**Compilation Warnings/Errors:**
- [List any issues, or "None"]

---

## Review Checklist

### Static Analysis
- [ ] No analyzer errors
- [ ] No analyzer warnings
- [ ] No deprecated API usage
- [ ] No unused imports
- [ ] Code formatting consistent

### Database Schema
- [ ] Tables correctly defined
- [ ] Indexes appropriate
- [ ] Constraints correct (UNIQUE, NOT NULL, FK)
- [ ] Migration code handles upgrade path
- [ ] No data loss on migration

### UI/Layout
- [ ] No layout constraint violations
- [ ] Text overflow handled
- [ ] Material Design compliance
- [ ] Touch targets adequate (48x48dp)
- [ ] Color contrast WCAG AA (4.5:1)

### Test Quality
- [ ] All phase tests pass
- [ ] No flaky tests
- [ ] Adequate coverage of new features
- [ ] Edge cases tested

### Performance
- [ ] No obvious performance regressions
- [ ] Widget rebuilds reasonable
- [ ] Database queries efficient
- [ ] No blocking UI operations

---

## Methodology

```bash
# Check for TODOs and FIXMEs
grep -r "TODO\|FIXME" pin_and_paper/lib/

# Check for deprecated APIs
grep -r "@deprecated" pin_and_paper/

# Check test files
find pin_and_paper/test -name "*.dart" | grep [keyword]

# Review recent changes
git diff main..HEAD -- pin_and_paper/lib/
```

---

## Findings

_Use the format below for each issue found._

### Issue Format

```markdown
### Issue #[N]: [Brief Title]

**File:** `path/to/file.dart:line`
**Type:** [Lint / Build / Schema / UI / Accessibility / Performance / Test]
**Severity:** [CRITICAL / HIGH / MEDIUM / LOW]
**Analyzer Message:** [If from flutter analyze]

**Description:**
[What's wrong]

**Suggested Fix:**
[How to fix it]

**Impact:**
[Why it matters]
```

---

## [Your findings go here]

_Run the build verification commands above, then review code and add issues._

---

## Summary

**Total Issues Found:** [X]

**By Severity:**
- CRITICAL: [count]
- HIGH: [count]
- MEDIUM: [count]
- LOW: [count]

**By Type:**
- Build: [count]
- Lint: [count]
- Schema: [count]
- UI/Layout: [count]
- Accessibility: [count]
- Performance: [count]
- Test: [count]

**Build Status:** [Clean / Warnings / Errors]
**Test Status:** [All passing / Some failures / Major failures]

---

## Verdict

**Release Ready:** [YES / NO / YES WITH FIXES]

**Must Fix Before Release:**
- [List blocking issues]

**Can Defer:**
- [List non-blocking issues]

---

**Review completed by:** Gemini
**Date:** [YYYY-MM-DD]
**Build version tested:** [Flutter version, Dart version]
**Platform tested:** [Linux / Android / iOS]
