# Codex Validation - Phase [X.Y]

**DO NOT edit this template directly!**
**ALWAYS copy to `docs/phase-XX/codex-validation.md` and customize.**

```bash
# Correct usage:
cp docs/templates/codex-validation-template.md docs/phase-XX/codex-validation.md
# Then edit codex-validation.md to fill in phase details
```

---

**Phase:** [X.Y - Brief Description]
**Implementation Report:** [Link to phase-X.Y-implementation-report.md]
**Validation Doc:** [Link to phase-X.Y-validation-v1.md]
**Review Date:** [YYYY-MM-DD]
**Reviewer:** Codex
**Status:** Pending Review

---

## Purpose

This document is for **Codex** to validate Phase [X.Y] **after implementation is complete**.

Unlike the findings doc (used during implementation for ongoing bug hunting), this is a focused post-implementation review to verify correctness, find bugs, and confirm quality before sign-off.

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

## Review Checklist

### Code Correctness
- [ ] No null safety violations
- [ ] No race conditions or async issues
- [ ] Error handling covers edge cases
- [ ] No memory leaks (dispose patterns correct)
- [ ] No potential crashes (bounds checks, null access)

### Data Integrity
- [ ] Database queries correct (no SQL injection, proper escaping)
- [ ] Data validation at boundaries
- [ ] Foreign key relationships maintained
- [ ] No potential data loss scenarios
- [ ] State management consistent (no stale state)

### Performance
- [ ] No N+1 query patterns
- [ ] No unnecessary widget rebuilds
- [ ] No inefficient loops or algorithms
- [ ] Database indexes used appropriately
- [ ] No blocking operations on UI thread

### Security
- [ ] Input validation on user data
- [ ] No sensitive data logged or exposed
- [ ] Secure storage used where needed

### Test Coverage
- [ ] Key logic paths have tests
- [ ] Edge cases covered
- [ ] Tests actually assert meaningful behavior
- [ ] No flaky tests introduced

---

## Methodology

```bash
# Find relevant files
find pin_and_paper/lib -name "*[keyword]*.dart"

# Search for specific patterns
grep -r "[pattern]" pin_and_paper/lib/

# Check test coverage
grep -r "test.*[feature]" pin_and_paper/test/

# Review recent changes
git log --oneline -20
git diff main..HEAD -- pin_and_paper/lib/
```

**Recommended approach:**
1. Read the implementation report to understand what was built
2. Review each file in the validation scope
3. Check tests for completeness
4. Search for common bug patterns (null access, async gaps, dispose issues)
5. Document findings below

---

## Findings

_Use the format below for each issue found._

### Issue Format

```markdown
### Issue #[N]: [Brief Title]

**File:** `path/to/file.dart:line`
**Type:** [Bug / Performance / Architecture / Security / Test Coverage]
**Severity:** [CRITICAL / HIGH / MEDIUM / LOW]

**Description:**
[What's wrong and why it matters]

**Current Code:**
\`\`\`dart
[Problematic code]
\`\`\`

**Suggested Fix:**
\`\`\`dart
[Fixed code]
\`\`\`

**Impact:**
[What breaks if not fixed]
```

---

## [Your findings go here]

_Start reviewing and add issues above using the format._

---

## Summary

**Total Issues Found:** [X]

**By Severity:**
- CRITICAL: [count]
- HIGH: [count]
- MEDIUM: [count]
- LOW: [count]

**By Type:**
- Bug: [count]
- Performance: [count]
- Architecture: [count]
- Security: [count]
- Test Coverage: [count]

---

## Verdict

**Release Ready:** [YES / NO / YES WITH FIXES]

**Must Fix Before Release:**
- [List CRITICAL and HIGH issues]

**Can Defer:**
- [List MEDIUM and LOW issues]

---

**Review completed by:** Codex
**Date:** [YYYY-MM-DD]
**Confidence level:** [High / Medium / Low]
