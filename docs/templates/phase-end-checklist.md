# End-of-Phase Checklist

**Purpose:** Standardized workflow for closing out a completed phase
**Used by:** Claude (with BlueKitty's confirmation)

---

## Trigger

BlueKitty says: "Phase X is complete" or "Let's close out Phase X"

---

## Checklist

### 1. Verify All Implementation Reports Exist

**Check for each subphase:**
```bash
ls docs/phase-XX/phase-X.*-implementation-report.md
```

**Expected files:**
- `phase-X.1-implementation-report.md`
- `phase-X.2-implementation-report.md`
- `phase-X.3-implementation-report.md`
- etc.

**If missing:**
- [ ] Create missing implementation report(s)
- [ ] Document what was implemented
- [ ] Include metrics, decisions, lessons learned

**Confirm:** "✅ All X.Y implementation reports exist"

---

### 2. Verify All Validation Docs Are Closed

**Check for each subphase:**
```bash
ls docs/phase-XX/phase-X.*-validation-v*.md
```

**Required:**
- Each subphase has at least one validation doc
- Latest validation version marked as FINAL
- All critical issues resolved or deferred

**Example check:**
```markdown
# phase-3.1-validation-v2.md

**Status:** ✅ FINAL - Phase 3.1 VALIDATED

**Sign-Off:**
- [x] Codex: No blocking issues
- [x] Gemini: Build verified
- [x] Claude: All critical issues resolved
- [x] BlueKitty: Approved
```

**Confirm:** "✅ All X.Y validations closed with sign-off"

---

### 3. Create Phase Summary Document

**File:** `docs/phase-XX/phase-XX-summary.md`

**Template:**
```markdown
# Phase X Summary

**Phase:** X
**Duration:** [Start date] - [End date]
**Status:** ✅ COMPLETE

---

## Overview

**Scope:** [What was Phase X about?]

**Subphases Completed:**
- X.1: [Feature] - [Brief outcome]
- X.2: [Feature] - [Brief outcome]
- X.3: [Feature] - [Brief outcome]

**Grouping Used:**
- Phase XXA (X.1-X.3): [Description]
- Phase XXB (X.4-X.5): [Description]

---

## Key Achievements

1. [Major achievement 1]
2. [Major achievement 2]
3. [Major achievement 3]

---

## Metrics

### Code
- **Files modified:** [X]
- **Files created:** [X]
- **Lines added:** [X]
- **Commits:** [X]

### Testing
- **Tests written:** [X]
- **Test pass rate:** [X]%
- **Coverage:** [X]%

### Quality
- **Critical bugs found:** [X] (all resolved)
- **HIGH bugs found:** [X] ([X] resolved, [X] deferred)
- **Build verification:** ✅ Passing

---

## Technical Decisions

1. **[Decision 1]:** [Brief explanation and rationale]
2. **[Decision 2]:** [Brief explanation and rationale]
3. **[Decision 3]:** [Brief explanation and rationale]

---

## Challenges & Solutions

### Challenge 1: [Title]
**Problem:** [Description]
**Solution:** [How we solved it]
**Outcome:** [Result]

### Challenge 2: [Title]
[Same format]

---

## Lessons Learned

**What Went Well:**
- [Positive 1]
- [Positive 2]
- [Positive 3]

**What Could Improve:**
- [Improvement 1]
- [Improvement 2]

**Process Changes for Next Phase:**
- [Change 1]
- [Change 2]

---

## Deferred Work

**Items deferred to future phases:**
- [ ] [Deferred item 1] - Target: Phase [Y]
- [ ] [Deferred item 2] - Target: Backlog
- [ ] [Deferred item 3] - Target: Phase [Z]

**Total deferred:** [X] items

---

## Team Contributions

**Codex Findings:**
- Total issues found: [X]
- Critical/High: [X]
- Fixed during phase: [X]

**Gemini Findings:**
- Linting issues found: [X]
- Build issues found: [X]
- All resolved: ✅

**Claude Implementation:**
- Subphases implemented: [X]
- Validation cycles: [X]
- Fixes applied: [X]

---

## References

**Planning Documents:**
- [phase-XX-plan-v3.md](./phase-XX-plan-v3.md) (final plan)
- [phase-XXA-plan.md](./phase-XXA-plan.md)
- [phase-XXB-plan.md](./phase-XXB-plan.md)

**Implementation Reports:**
- [phase-X.1-implementation-report.md](./phase-X.1-implementation-report.md)
- [phase-X.2-implementation-report.md](./phase-X.2-implementation-report.md)
- [phase-X.3-implementation-report.md](./phase-X.3-implementation-report.md)

**Validation Documents:**
- [phase-X.1-validation-v2.md](./phase-X.1-validation-v2.md) (final)
- [phase-X.2-validation-v1.md](./phase-X.2-validation-v1.md) (final)
- [phase-X.3-validation-v1.md](./phase-X.3-validation-v1.md) (final)

---

**Prepared By:** Claude
**Reviewed By:** BlueKitty
**Date:** [YYYY-MM-DD]
```

**Action:**
- [ ] Create phase-XX-summary.md using template above
- [ ] Fill in all metrics from implementation reports
- [ ] Consolidate lessons learned
- [ ] Document deferred work

**Confirm:** "✅ Phase X summary created"

---

### 4. Update Master Documents ⚠️ **CRITICAL**

**This step is MANDATORY - phase is not complete without it!**

See [documentation-workflow.md](./documentation-workflow.md) for complete guide.

#### 4.1 Update PROJECT_SPEC.md (Authoritative Source)

**File:** `PROJECT_SPEC.md` (root level)

**Updates required:**
- [ ] **Header** (search for `**Version:**`): Update version number (e.g., 3.4 → 3.5)
- [ ] **Header** (search for `**Last Updated:**`): Update date
- [ ] **Header** (search for `**Current Phase:**`): Update current phase field
- [ ] **Current Status** (search for `### Current Status`): Add completion line with date
- [ ] **Phase Description** (search for `### 🚧 Phase 3:`): Move phase from "Remaining" to "Completed"
  - [ ] Add completion date
  - [ ] Add key metrics (tests, LOC, achievements)
  - [ ] Update "Remaining Subphases" list
- [ ] **Next Steps** (search for `## Next Steps`): Update current phase and completed recently
- [ ] **Document Status** (search for `**Document Status:**`): Update Last Review date

**Example:**
```markdown
**Version:** 3.5 (Phase 3 In Progress)
**Last Updated:** 2026-01-05
**Current Phase:** Phase 3.5 Complete - Working on 3.6

### Current Status
✅ **Phase 3.5:** Comprehensive Tagging System - Complete (Jan 5, 2026)
```

**Confirm:** "✅ PROJECT_SPEC.md updated with Phase X.Y completion"

#### 4.2 Update README.md (Public Facing)

**File:** `README.md` (root level)

**Updates required:**
- [ ] **Phase 3 Section** (search for `### Phase 3:`): Add completed subphase with highlights
- [ ] **Phase 3 Section**: Update "Next Up" list
- [ ] **Tech Stack** (search for `### Data & State`): Update DB version if changed
- [ ] **Tech Stack**: Update test count
- [ ] **Project Status** (search for `## Project Status`): Add phase to completed list
- [ ] **Current Stats** (search for `### Current Stats`): Update LOC, tests, DB version

**Example:**
```markdown
### Phase 3: Core Productivity 🚧 **IN PROGRESS**

**Completed:**
- ✅ **Phase 3.5:** Comprehensive Tagging System (Jan 2026)
  - 78 comprehensive tests (100% passing)
  - WCAG AA compliant colors
  - Tag picker with search/filter/create

### Current Stats
- **~8,000+ lines of production code**
- **154 tests passing** (95%+ pass rate)
- **Database:** v6 (6 migrations complete)
```

**Confirm:** "✅ README.md synced with PROJECT_SPEC.md"

#### 4.3 Commit Master Docs Together

**CRITICAL:** Always commit PROJECT_SPEC.md and README.md together with phase docs.

```bash
git add PROJECT_SPEC.md README.md docs/phase-XX/phase-XX-summary.md
git commit -m "docs: Complete Phase X.Y with master doc updates

- Updated PROJECT_SPEC.md: Version X.Y, completion date, achievements
- Updated README.md: Phase X section, project status, stats
- Added phase-XX-summary.md with complete metrics

Phase X.Y complete with [key achievement summary]"
```

**Why this matters:**
- PROJECT_SPEC.md and README.md are the FIRST thing people see
- They must reflect current reality, not be 2+ phases out of date
- Future-you will thank you for keeping them current
- Commits all related docs together maintains sync

**Confirm:** "✅ Master documents updated and committed together"

---

### 4.5 Harvest Future Features → FEATURE_REQUESTS.md

**Purpose:** Capture any deferred features, future enhancements, or scattered "nice to have" items before archiving phase docs.

**Review these sources:**
- [ ] Phase plan docs (phase-XX-plan-v*.md) - Any "Open Questions", "Future Enhancements", or "Deferred" sections?
- [ ] Implementation reports - Any "Deferred Work" sections?
- [ ] Validation docs - Any issues deferred to future phases?
- [ ] Agent findings docs - Any suggestions tagged as "future enhancement"?
- [ ] PROJECT_SPEC.md - Any new "Deferred" notes added during this phase?

**For each unlogged feature found:**
- [ ] Add to `docs/FEATURE_REQUESTS.md` using the standard format
- [ ] Include: description, source phase, priority, complexity estimate
- [ ] Remove from source doc (or replace with "See `docs/FEATURE_REQUESTS.md`")

**Also check FEATURE_REQUESTS.md for items fulfilled this phase:**
- [ ] Mark completed items with ✅ and completion date

**Confirm:** "✅ Future features harvested to FEATURE_REQUESTS.md"

---

### 5. Confirm Team Finished with Findings Docs

**Important:** Don't archive while team is still working!

**Ask BlueKitty:**
> "Phase X documentation complete. Before archiving:
>
> Please confirm Codex and Gemini are done with their findings docs:
> - codex-findings.md
> - gemini-findings.md
>
> Are they finished and safe to archive?"

**Wait for confirmation:** "Yes, archive everything"

**If not ready:**
- [ ] Wait for team to finish
- [ ] Circle back when ready

---

### 5. Archive Everything

**Only proceed after BlueKitty confirms team is done!**

**Actions:**
```bash
# Create archive directory if needed
mkdir -p docs/archive/phase-XX/

# Move ALL files from phase directory to archive
mv docs/phase-XX/* docs/archive/phase-XX/

# Verify phase directory is empty
ls docs/phase-XX/
# Should output: (empty)
```

**Files being archived:**
- Planning docs (phase-XX-plan-v*.md, phase-XXA-plan.md, etc.)
- Review docs (phase-XXA-review-v*.md)
- Bug hunting docs (codex-findings.md, gemini-findings.md, claude-findings.md)
- Implementation reports (phase-X.Y-implementation-report.md)
- Validation docs (phase-X.Y-validation-v*.md)
- Phase summary (phase-XX-summary.md)

**Confirm:**
```
✅ Archived [X] files to docs/archive/phase-XX/
✅ docs/phase-XX/ is now empty
✅ Phase X closed - ready for Phase [X+1]
```

---

## End-of-Phase Summary

**At the end of this checklist:**

✅ All implementation reports verified/created
✅ All validation docs closed with sign-off
✅ Phase summary document created
✅ Master documents updated (PROJECT_SPEC.md, README.md)
✅ Future features harvested to FEATURE_REQUESTS.md
✅ Team confirmed finished with findings docs
✅ Everything archived to docs/archive/phase-XX/
✅ docs/phase-XX/ empty and ready for next phase

---

## Example: Closing Phase 3

```
YOU: "Phase 3 is complete!"

CLAUDE:
"Starting Phase 3 closeout...

Checking documentation:
✅ phase-3.1-implementation-report.md exists
✅ phase-3.2-implementation-report.md exists
✅ phase-3.3-implementation-report.md exists

Checking validation:
✅ phase-3.1-validation-v2.md (FINAL, signed off)
✅ phase-3.2-validation-v1.md (FINAL, signed off)
✅ phase-3.3-validation-v1.md (FINAL, signed off)

Creating phase summary...

✅ phase-03-summary.md created
   - 3 subphases completed
   - 15 commits total
   - 45 tests passing
   - 8 bugs found and resolved

All documentation complete.

Before archiving, please confirm:
Are Codex and Gemini done with their findings docs?
- codex-findings.md
- gemini-findings.md

Ready to archive when you confirm."

YOU: (checks with team) "Yes, they're done. Archive everything."

CLAUDE:
"Archiving Phase 3...

✅ Created docs/archive/phase-03/
✅ Moved 24 files to archive
✅ docs/phase-03/ is now empty

Phase 3 closeout complete!
Ready to start Phase 4 when you are."
```

---

## Troubleshooting

### Missing Implementation Reports
**If some subphases don't have reports:**
- Create minimal report documenting what was done
- Include metrics if available
- Mark as "Retrospective Report"

### Validation Not Fully Closed
**If validation cycles still have open issues:**
- Check if issues are deferred (document in phase summary)
- Verify critical issues are resolved
- Get final sign-off from team

### Team Still Working on Findings
**If team needs more time:**
- Don't archive yet!
- Wait for confirmation
- Phase can be "functionally complete" but not archived

---

**Template Version:** 1.1
**Last Updated:** 2026-01-22
**Maintained By:** BlueKitty + Claude
