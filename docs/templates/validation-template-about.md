# Validation Template - Usage Guide

**For:** BlueKitty & Claude (Template Management)
**Companion File:** `validation-template.md`
**Version:** 1.0
**Created:** 2025-10-30

---

## Overview

This document explains the **end-of-phase (EOP) validation workflow** and how to use the `validation-template.md` template.

**Key Differences:**
- **Review Template** (`review-template.md`): PRE-implementation review of plans/designs
- **Validation Template** (`validation-template.md`): POST-implementation structured EOP validation
- **Ongoing Bug Hunting** (`codex-findings.md`, etc.): CONTINUOUS bug finding during implementation

**IMPORTANT:** This template is for **structured end-of-phase validation**, NOT for ongoing bug hunting!

### Ongoing Bug Hunting vs EOP Validation

**Ongoing Bug Hunting (separate from this template):**
- Happens **during** implementation (parallel to Claude's work)
- Codex + Gemini use their own docs (`codex-findings.md`, `3.1-issues.md`, etc.)
- READ-ONLY exploration (no code changes)
- Continuous additions as bugs are found
- Claude periodically reviews and applies fixes

**EOP Validation (this template):**
- Happens **after** implementation complete
- Structured team validation with cycles
- Multi-round fix → verify → sign-off process
- Single consolidated document per subphase
- Clear exit criteria and sign-off

---

## When to Use Validation Template

Use this template when:
- ✅ A subphase implementation is **complete** (code written, tests passing)
- ✅ You need team validation before moving to next subphase
- ✅ You want structured bug finding and fix tracking
- ✅ Multiple validation cycles are expected (fix → verify → repeat)

**Example triggers:**
- "Phase 3.1 implementation complete, ready for validation"
- "Just committed 3.2 hierarchical UI, need team review"
- "Finished Group 1, let's validate before starting Group 2"

---

## Workflow Overview

### Standard Validation Flow

```
Implementation Complete
         ↓
    Create validation doc (from template)
         ↓
    Cycle 1: Team reviews code
         ↓
    Codex + Gemini add findings to doc
         ↓
    Claude analyzes, triages, plans fixes
         ↓
    Claude implements fixes (new commit)
         ↓
    Cycle 2: Team verifies fixes
         ↓
    [Repeat if issues remain]
         ↓
    Final sign-off → Close validation
```

### Typical Timeline

**Cycle 1 (2-4 hours):**
- 1 hour: Codex explores codebase
- 30 min: Gemini runs analysis/tests
- 1 hour: Claude triages and plans
- 1-2 hours: Claude implements fixes

**Cycle 2 (1-2 hours):**
- 30 min: Codex verifies fixes
- 30 min: Gemini verifies build
- 30 min: Claude responds
- (If clean: close validation)

**Total:** Usually 2 cycles, 3-6 hours total

---

## How to Create a Validation Document

### Step 1: Copy Template

**When:** Immediately after implementation commits are pushed.

```bash
# Copy template to phase directory
cp docs/templates/validation-template.md docs/phase-03/phase-3.1-validation.md

# Or for other subphases
cp docs/templates/validation-template.md docs/phase-03/phase-3.2-validation.md
```

### Step 2: Fill Header

Replace all bracketed placeholders at the top:

```markdown
# Phase 3.1 Validation Cycles

**Subphase:** 3.1 - Database Migration (v3 → v4)
**Implementation Commits:** 072553b..d1f22a2
**Started:** 2025-10-30
**Status:** 🔄 In Progress
```

### Step 3: Set Overview

**What's Being Validated:**
```markdown
- Database migration script (_migrateToV4)
- Task model extensions (9 new fields)
- UserSettings model with Value<T> wrapper
- UserSettingsService CRUD operations
- 22 unit tests for new models
```

**Exit Criteria:**
```markdown
- [ ] All HIGH/CRITICAL issues resolved
- [ ] flutter analyze clean
- [ ] flutter test passes (22+ tests)
- [ ] flutter build apk succeeds
- [ ] All team members sign off
```

### Step 4: Commit Initial Doc

```bash
git add docs/phase-03/phase-3.1-validation.md
git commit -m "docs: Create Phase 3.1 validation tracking document"
```

### Step 5: Notify Team

Announce to team:
> "Phase 3.1 implementation complete! Ready for validation.
> Tracking doc: `docs/phase-03/phase-3.1-validation.md`
> Codex: Please explore codebase and add findings.
> Gemini: Please run static analysis and build verification."

---

## Cycle Workflow

### Cycle 1: Initial Validation

#### Codex's Role

1. **Explore the code:**
   - Read new/modified files
   - Grep for patterns
   - Check for common bugs
   - Review architecture

2. **Add findings to doc:**
   - Fill in "Codex Findings" section
   - Use issue template for each bug
   - Include severity + suggested fix
   - Update summary counts

3. **Update status:**
   ```markdown
   #### Codex Findings
   **Date:** 2025-10-30
   **Status:** ✅ Complete

   **Methodology:**
   - Read database_service.dart, task.dart, user_settings.dart
   - Searched for async gaps, dispose issues, migration bugs
   - Reviewed test coverage

   **Issues Found:** 8 total
   ```

#### Gemini's Role

1. **Run validation commands:**
   ```bash
   flutter analyze
   flutter test
   flutter build apk
   ```

2. **Document results:**
   - Paste analyzer output
   - Note test failures
   - Report build issues

3. **Add findings to doc:**
   - Fill in "Gemini Findings" section
   - Focus on linting, compilation, tests
   - Update summary counts

#### Claude's Role

1. **Review all findings:**
   - Read Codex + Gemini sections
   - Verify issues are valid
   - Categorize by severity

2. **Triage issues:**
   ```markdown
   **CRITICAL Issues (Must Fix Now):**
   - [ ] #C1: Position backfill duplicates - Fix in Cycle 1
   - [ ] #C2: Missing indexes in migration - Fix in Cycle 1

   **HIGH Issues (Should Fix Before Next Phase):**
   - [ ] #H1: New tasks default to position 0 - Fix in Cycle 1

   **MEDIUM Issues (Can Defer):**
   - [ ] #M1: BuildContext async gaps - Defer to cleanup task
   ```

3. **Create fix plan:**
   - Explain which issues to fix now vs defer
   - Outline fix approach
   - Ask clarifying questions if needed

4. **Implement fixes:**
   - Make code changes
   - Test thoroughly
   - Commit with descriptive message
   - Update "Fixes Applied" section

#### Closing Cycle 1

Once fixes are committed:

```markdown
### Cycle 1 Status

**Date Closed:** 2025-10-30
**Outcome:** ✅ Ready for Cycle 2

**Issues Resolved:** 3/8
**Issues Deferred:** 5
**New Issues Found:** 0
```

---

### Cycle 2: Verification

#### Codex's Role

1. **Verify each fix:**
   - Re-read modified files
   - Confirm issue is resolved
   - Check for regressions

2. **Update verification section:**
   ```markdown
   **Verified Issues:**
   - [x] #C1: ✅ Position backfill now uses deterministic tie-breaker
   - [x] #C2: ✅ Indexes added to migration
   - [x] #H1: ✅ New tasks calculate position = max + 1
   ```

#### Gemini's Role

1. **Re-run validation:**
   ```bash
   flutter analyze
   flutter test
   flutter build apk
   ```

2. **Report results:**
   ```markdown
   **Results:**
   - [x] Static analysis: ✅ Clean (0 issues)
   - [x] Tests: ✅ 25/25 passing (+3 new tests)
   - [x] Build: ✅ 143MB APK
   ```

#### Claude's Role

1. **Review verification:**
   - Check all issues confirmed fixed
   - Look for new issues

2. **Decide on closure:**
   - If clean → close validation
   - If issues remain → plan Cycle 3

---

### Closing Validation

When all critical issues are resolved:

```markdown
## Final Validation Status

**Date Closed:** 2025-10-30
**Status:** ✅ Phase 3.1 VALIDATED

**Final Metrics:**
- Total cycles: 2
- Total issues found: 8
- Issues fixed: 3
- Issues deferred: 5 (targeted for cleanup task)
- Issues won't fix: 0

**Sign-Off:**
- [x] **Codex:** No blocking issues found
- [x] **Gemini:** Build verification passed
- [x] **Claude:** All critical issues resolved
- [x] **BlueKitty:** Phase 3.1 approved for production
```

---

## File Naming Convention

### DO:
✅ `phase-3.1-validation.md`
✅ `phase-3.2-validation.md`
✅ `phase-4.1-validation.md`

### DON'T:
❌ `3.1-issues.md` (not descriptive enough)
❌ `codex-findings.md` (fragments into multiple files)
❌ `3.1-issues-response.md` (creates response file separate from findings)
❌ `phase-3.1-validation-cycle-1.md` (creates file per cycle)
❌ `phase-3.1-bugs.md` (vague purpose)

**Rationale:**
- One file per subphase keeps everything together
- Clear naming pattern (`phase-X.Y-validation.md`)
- All cycles in one doc (chronological history)
- Easy to find current status (scroll to bottom)

---

## When to Create Multiple Cycles

**Create Cycle 2 when:**
- Fixes have been applied (new commit)
- Need to verify fixes worked
- Want to catch regressions

**Create Cycle 3+ when:**
- Cycle 2 found new issues or regressions
- Major fixes that need re-verification
- Team wants extra validation round

**Skip Cycle 2 when:**
- Only deferred issues (nothing fixed)
- Issues are trivial (e.g., typo in comment)
- Team agrees to close without verification

---

## Integration with Other Documents

### Validation Doc vs Implementation Report

**Validation Doc** (`phase-3.1-validation.md`):
- Living document during validation
- Focuses on bug finding and fixes
- Updated multiple times per cycle
- Closes when validation complete

**Implementation Report** (`phase-3.1-implementation-report.md`):
- Written once at end of implementation
- Comprehensive summary of work
- Includes validation summary in "Post-Implementation" section
- Permanent record

**Relationship:**
- Validation doc tracks the process
- Implementation report summarizes the results
- Implementation report links to validation doc

### Workflow

1. **During implementation:**
   - Create implementation report
   - Document work, decisions, metrics

2. **After implementation:**
   - Create validation doc (from template)
   - Run validation cycles
   - Track bugs and fixes

3. **After validation:**
   - Update implementation report with validation summary
   - Reference validation doc
   - Commit both as final record

---

## Examples

### Example 1: Clean Validation (1 cycle)

```markdown
# Phase 3.2 Validation Cycles

## Cycle 1: Initial Validation
- Codex: 0 issues found
- Gemini: All tests pass, build clean
- Claude: No action needed

## Final Validation Status
**Status:** ✅ Phase 3.2 VALIDATED (1 cycle, 0 issues)
```

**Total time:** 1 hour

---

### Example 2: Normal Validation (2 cycles)

```markdown
# Phase 3.1 Validation Cycles

## Cycle 1: Initial Validation
- Codex: 8 bugs found (2 CRITICAL, 1 HIGH, 5 MEDIUM)
- Gemini: 1 linting issue
- Claude: Fixed 3 CRITICAL/HIGH, deferred 5 MEDIUM

## Cycle 2: Verification
- Codex: All 3 fixes verified
- Gemini: Build clean
- Claude: Close validation

## Final Validation Status
**Status:** ✅ Phase 3.1 VALIDATED (2 cycles, 3 fixed, 5 deferred)
```

**Total time:** 4 hours

---

### Example 3: Complex Validation (3 cycles)

```markdown
# Phase 4.1 Validation Cycles

## Cycle 1: Initial Validation
- Codex: 12 bugs found
- Gemini: 5 test failures
- Claude: Fixed 10 bugs, deferred 2

## Cycle 2: Verification
- Codex: 2 regressions found
- Gemini: 1 test still failing
- Claude: Fixed regressions + test

## Cycle 3: Final Verification
- Codex: All issues resolved
- Gemini: All tests passing
- Claude: Close validation

## Final Validation Status
**Status:** ✅ Phase 4.1 VALIDATED (3 cycles, 13 fixed, 2 deferred)
```

**Total time:** 8 hours

---

## Migration Plan

### What to Do with Existing Files

For Phase 3.1 (already complete):

**Keep Ongoing Bug Hunting Docs:**
- ✅ `codex-findings.md` - Stays in `docs/phase-03/` (ongoing bug hunting)
- ✅ `3.1-issues.md` - Stays in `docs/phase-03/` (Gemini's ongoing findings)
- ✅ `3.1-issues-response.md` - Stays in `docs/phase-03/` (Claude's analysis)

These docs serve ongoing bug hunting, NOT EOP validation. Keep them active!

**For Future Subphases (3.2+):**
- Continue using `codex-findings.md` for ongoing bug hunting during implementation
- Create `phase-3.2-validation.md` when ready for EOP structured validation
- Two parallel processes: ongoing hunting + structured EOP validation

**Relationship:**
```
During Implementation:
- codex-findings.md (ongoing)
- 3.1-issues.md (ongoing)
└─> Claude reviews periodically and applies fixes

After Implementation Complete:
- phase-3.1-validation.md (EOP structured validation)
└─> Team does formal validation cycles with sign-off
```

**Recommendation:**
- Don't retroactively create `phase-3.1-validation.md` (work already documented in implementation report)
- Start using validation template for Phase 3.2+ EOP validation
- Keep ongoing bug hunting docs separate and active

---

## Template Customization

### Adding Custom Issue Types

If your project has specific bug categories:

```markdown
**Type:** [Bug / Performance / Architecture / Documentation / Security / Accessibility]
```

### Adding Automated Checks

If you have CI/CD:

```markdown
**Automated Checks:**
- [ ] CI/CD pipeline passed
- [ ] Code coverage ≥ 80%
- [ ] No security vulnerabilities (npm audit)
- [ ] Performance benchmarks met
```

### Adding Stakeholder Sign-Off

For external stakeholders:

```markdown
**Sign-Off:**
- [x] **Codex:** No blocking issues
- [x] **Gemini:** Build verified
- [x] **Claude:** All critical issues resolved
- [x] **BlueKitty:** Phase approved
- [ ] **Product Manager:** UX validated
- [ ] **QA Lead:** Manual testing complete
```

---

## Tips & Tricks

### Quick Issue Entry

Use editor snippets for fast issue entry:

```markdown
##### Issue #X: [TITLE]
**File:** `path/to/file.dart:line`
**Type:** [Bug]
**Severity:** [HIGH]

**Description:**
[Description]

**Suggested Fix:**
[Fix]

**Impact:**
[Impact]
```

### Status Emojis

Use emojis for quick visual status:

```markdown
- ✅ Complete / Fixed / Verified
- ⏳ In Progress
- ⚠️ Issues Found / Needs Work
- 🔄 In Progress
- 🆕 New Issue
- ❌ Failed / Won't Fix
```

### Linking Between Docs

Cross-reference related documents:

```markdown
**See Also:**
- Implementation: [phase-3.1-implementation-report.md](./phase-3.1-implementation-report.md)
- Pre-review: [group1-final-feedback.md](./group1-final-feedback.md)
- Bug tracker: [codex-findings.md](./codex-findings.md) (archived)
```

---

## Checklist

Use this for every validation:

- [ ] Template copied to correct location
- [ ] Header filled (subphase, commits, date)
- [ ] Overview section complete (deliverables, exit criteria)
- [ ] Initial doc committed
- [ ] Team notified
- [ ] Codex findings added
- [ ] Gemini findings added
- [ ] Claude response written
- [ ] Fixes implemented and committed
- [ ] Cycle 1 status updated
- [ ] Cycle 2 verification complete
- [ ] Final status written
- [ ] Sign-offs collected
- [ ] Implementation report updated with validation summary
- [ ] Validation doc committed as final

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-30 | Initial template based on Phase 3.1 ad-hoc validation |

---

## Related Documents

- `validation-template.md` - The actual template
- `review-template.md` - Pre-implementation review template (different purpose)
- Real example: Phase 3.1 ad-hoc validation (3.1-issues.md, codex-findings.md, 3.1-issues-response.md)

---

**Maintained By:** BlueKitty + Claude
**Questions?** Update this document as we learn from using the template!
