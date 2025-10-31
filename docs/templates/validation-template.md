# Phase [X.Y] Validation - Version [N]

**Subphase:** [X.Y - Brief Description]
**Implementation Commits:** [Commit range, e.g., 072553b..d1f22a2]
**Validation Version:** [N]
**Created:** [YYYY-MM-DD]
**Status:** [🔄 In Progress / ✅ FINAL - Validated / ⚠️ Issues Found]
**Previous Version:** [link to vN-1 if applicable, or "N/A" for v1]

---

## Validation Overview

**What's Being Validated:**
- [Primary deliverable 1]
- [Primary deliverable 2]
- [Primary deliverable 3]

**Validation Team:**
- **Codex:** Codebase exploration, bug finding, architectural review
- **Gemini:** Static analysis, linting, compilation verification
- **Claude:** Self-review, response synthesis, fix implementation

**Exit Criteria:**
- [ ] All HIGH/CRITICAL issues resolved
- [ ] Build passes (flutter analyze, flutter test, flutter build apk)
- [ ] All team members sign off
- [ ] Documentation updated

---

## This Validation Cycle

**Date:** [YYYY-MM-DD]
**Trigger:** [Implementation complete / Fixes from v[N-1] applied]
**Focus:** [First-pass review / Verify v[N-1] fixes / etc.]

**Issues from Previous Version:**
[If v2+, list issues from v[N-1] to verify]
- [ ] Issue #1 from v[N-1] - [Status: Fixed / Still present / Regression]
- [ ] Issue #2 from v[N-1] - [Status]

[If v1, delete this section]

### Findings

#### Codex Findings
**Date:** [YYYY-MM-DD]
**Status:** [⏳ In Progress / ✅ Complete]

**Methodology:**
[How Codex explored the code - file reads, grep patterns, etc.]

**Issues Found:** [X total]

---

##### Issue #1: [Brief Title]
**File:** `path/to/file.dart:line`
**Type:** [Bug / Performance / Architecture / Documentation]
**Severity:** [CRITICAL / HIGH / MEDIUM / LOW]

**Description:**
[Detailed description of the issue]

**Suggested Fix:**
[Concrete recommendation]

**Impact:**
[Why this matters]

---

##### Issue #2: [Brief Title]
[Same format as above]

---

**Codex Summary:**
- CRITICAL: [count]
- HIGH: [count]
- MEDIUM: [count]
- LOW: [count]
- **Total:** [count]

---

#### Gemini Findings
**Date:** [YYYY-MM-DD]
**Status:** [⏳ In Progress / ✅ Complete]

**Methodology:**
[Commands run - flutter analyze, flutter test, etc.]

**Issues Found:** [X total]

---

##### Issue #1: [Brief Title]
**File:** `path/to/file.dart:line`
**Type:** [Linting / Compilation / Test Failure]
**Severity:** [CRITICAL / HIGH / MEDIUM / LOW]

**Analyzer Output:**
```
[Paste exact output from flutter analyze or compiler]
```

**Description:**
[What the issue is]

**Suggested Fix:**
[How to fix it]

---

**Gemini Summary:**
- CRITICAL: [count]
- HIGH: [count]
- MEDIUM: [count]
- LOW: [count]
- **Total:** [count]

---

### Claude's Response

**Date:** [YYYY-MM-DD]
**Total Issues to Address:** [X]

#### Issue Triage

**CRITICAL Issues (Must Fix Now):**
- [ ] #C1: [Issue title] - [Decision: Fix / Defer / Won't Fix]
- [ ] #C2: [Issue title] - [Decision: Fix / Defer / Won't Fix]

**HIGH Issues (Should Fix Before Next Phase):**
- [ ] #H1: [Issue title] - [Decision: Fix / Defer / Won't Fix]
- [ ] #H2: [Issue title] - [Decision: Fix / Defer / Won't Fix]

**MEDIUM Issues (Can Defer):**
- [ ] #M1: [Issue title] - [Decision: Fix / Defer / Won't Fix]

**LOW Issues (Nice to Have):**
- [ ] #L1: [Issue title] - [Decision: Fix / Defer / Won't Fix]

#### Analysis & Plan

**Issues Scope:**
- [X] issues are Phase [X.Y] bugs (introduced by us)
- [X] issues are pre-existing from Phase [X]
- [X] issues are false positives / won't fix

**Fix Strategy:**
1. [Approach for CRITICAL issues]
2. [Approach for HIGH issues]
3. [Deferral plan for MEDIUM/LOW]

**Questions for BlueKitty:**
- [ ] [Question 1]
- [ ] [Question 2]

---

### Fixes Applied

**Commit:** [hash] - [Commit message]
**Date:** [YYYY-MM-DD]

**Fixed Issues:**
- [x] #C1: [Issue title] - [Brief description of fix]
- [x] #H1: [Issue title] - [Brief description of fix]

**Changes Made:**
- [File 1]: [What changed]
- [File 2]: [What changed]

**Testing:**
- [x] `flutter test` passes ([X]/[X] tests)
- [x] `flutter analyze` clean
- [x] `flutter build apk` succeeds

---

### This Cycle Status

**Date Closed:** [YYYY-MM-DD or "In Progress"]
**Outcome:** [⏳ In Progress / ✅ Validated - FINAL / ⚠️ Issues Found - Need v[N+1]]

**Issues Resolved:** [X]/[X]
**Issues Deferred:** [X]
**New Issues Found:** [X]

---

## Next Steps

### If Issues Remain (Create v[N+1])

**Trigger:** Fixes applied, need verification

**Process:**
1. Claude applies fixes from this version
2. Create new file: `phase-X.Y-validation-v[N+1].md`
3. Reference this version in "Previous Version" field
4. List issues from this version to verify
5. Team reviews and adds new findings

**Example:**
If this is v1 with issues → create v2 after fixes applied

---

### If Validation Complete (Mark FINAL)

**Criteria:**
- [ ] All CRITICAL issues resolved
- [ ] All HIGH issues resolved or deferred
- [ ] Build passes (flutter analyze, test, build)
- [ ] Team signs off

**Action:**
1. Update header: `**Status:** ✅ FINAL - Phase [X.Y] VALIDATED`
2. Complete sign-off section below
3. No v[N+1] needed - validation closed

---

## Sign-Off

[Only complete if this is the FINAL version]

**Date:** [YYYY-MM-DD]

- [ ] **Codex:** No blocking issues found
- [ ] **Gemini:** Build verification passed
- [ ] **Claude:** All critical issues resolved
- [ ] **BlueKitty:** Phase [X.Y] approved

**Outstanding Work:**
- [ ] [Deferred issue 1] - Target: Phase [X.Y]
- [ ] [Deferred issue 2] - Target: Separate cleanup task

---

**Template Version:** 2.0 (versioned validation cycles)
**Document Owner:** BlueKitty
**Last Updated:** 2025-10-30

---

**See Also:**
- Implementation report: `docs/phase-XX/phase-X.Y-implementation-report.md`
- Pre-implementation review: `docs/phase-XX/phase-XXA-review-vN.md`
- Ongoing findings: `codex-findings.md`, `gemini-findings.md`, `claude-findings.md`
- Previous validation: `phase-X.Y-validation-v[N-1].md` (if applicable)
- Next validation: `phase-X.Y-validation-v[N+1].md` (if needed)
