# Phase [X.Y] Validation Cycles

**Subphase:** [X.Y - Brief Description]
**Implementation Commits:** [Commit range, e.g., 072553b..d1f22a2]
**Started:** [YYYY-MM-DD]
**Status:** [🔄 In Progress / ✅ Validated / ⚠️ Issues Found]

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

## Cycle 1: Initial Validation

**Date:** [YYYY-MM-DD]
**Trigger:** Initial implementation complete (commits: [hash])
**Focus:** First-pass review of implementation

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

### Cycle 1 Status

**Date Closed:** [YYYY-MM-DD]
**Outcome:** [✅ Ready for Cycle 2 / ⚠️ Needs More Work]

**Issues Resolved:** [X]/[X]
**Issues Deferred:** [X]
**New Issues Found:** [X]

---

## Cycle 2: Verification

**Date:** [YYYY-MM-DD]
**Trigger:** Cycle 1 fixes applied (commit: [hash])
**Focus:** Verify fixes worked, catch any regressions

### Findings

#### Codex Verification
**Date:** [YYYY-MM-DD]
**Status:** [⏳ In Progress / ✅ Complete]

**Verified Issues:**
- [x] #C1: ✅ Confirmed fixed
- [x] #H1: ✅ Confirmed fixed
- [ ] #H2: ⚠️ Still present / regression

**New Issues Found:** [X]

[If new issues, use same format as Cycle 1]

---

#### Gemini Verification
**Date:** [YYYY-MM-DD]
**Status:** [⏳ In Progress / ✅ Complete]

**Build Verification:**
```bash
flutter analyze
flutter test
flutter build apk
```

**Results:**
- [x] Static analysis: ✅ Clean
- [x] Tests: ✅ [X]/[X] passing
- [x] Build: ✅ [Size]MB APK

**New Issues Found:** [X]

---

### Claude's Response

**Date:** [YYYY-MM-DD]

**Verification Summary:**
- ✅ [X] issues confirmed fixed
- ⚠️ [X] issues still present
- 🆕 [X] new issues found

**Plan:**
[If issues remain, plan for Cycle 3. Otherwise, close validation.]

---

### Cycle 2 Status

**Date Closed:** [YYYY-MM-DD]
**Outcome:** [✅ Validation Complete / ⏳ Need Cycle 3]

---

## [Cycle 3: Additional Round]

[If needed, repeat same structure as Cycle 2]

---

## Final Validation Status

**Date Closed:** [YYYY-MM-DD]
**Status:** ✅ Phase [X.Y] VALIDATED

**Final Metrics:**
- Total cycles: [X]
- Total issues found: [X]
- Issues fixed: [X]
- Issues deferred: [X]
- Issues won't fix: [X]

**Outstanding Work:**
- [ ] [Deferred issue 1] - Target: Phase [X.Y]
- [ ] [Deferred issue 2] - Target: Separate cleanup task

**Sign-Off:**
- [x] **Codex:** No blocking issues found
- [x] **Gemini:** Build verification passed
- [x] **Claude:** All critical issues resolved
- [x] **BlueKitty:** Phase [X.Y] approved for production

---

## Lessons Learned

**What Went Well:**
- [Positive 1]
- [Positive 2]

**What Could Improve:**
- [Improvement 1]
- [Improvement 2]

**Process Changes:**
- [Change 1 for next phase]
- [Change 2 for next phase]

---

**Template Version:** 1.0
**Document Owner:** BlueKitty
**Last Updated:** [YYYY-MM-DD]

---

**See Also:**
- Implementation report: `docs/phase-XX/phase-X.Y-implementation-report.md`
- Pre-implementation review: `docs/phase-XX/groupX-review.md`
- Codex findings archive: `docs/archive/phase-XX/codex-findings.md`
