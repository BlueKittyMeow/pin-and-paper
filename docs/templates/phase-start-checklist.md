# Start-of-Phase Checklist

**Purpose:** Standardized workflow for initiating a new phase
**Used by:** Claude (with BlueKitty's approval)

---

## Trigger

BlueKitty says: "Let's start Phase X" or "Ready to plan Phase X"

---

## Checklist

### 0. Verify Master Documents Are Current ⚠️

**Before starting a new phase, check that previous phase is properly documented!**

**Quick check:**
```bash
# Check PROJECT_SPEC.md header
head -10 docs/PROJECT_SPEC.md | grep "Version:\|Current Phase:"

# Should show previous phase complete, not 2+ phases behind
```

**If outdated:**
- [ ] Previous phase may not be properly closed
- [ ] Check if phase-end-checklist was followed
- [ ] Update master docs before starting new phase (see [documentation-workflow.md](./documentation-workflow.md))

**Why this matters:**
- Prevents documentation drift
- Ensures accurate project state tracking
- Makes it easier to resume work later

**Confirm:** "✅ Master documents current before starting Phase X"

---

### 1. Create Phase Directory
```bash
mkdir -p docs/phase-XX/
```
**Confirm:** "Created docs/phase-XX/"

---

### 2. Check Archive for Context
**If resuming work or referencing previous phase:**
```bash
ls docs/archive/phase-XX/
```

**Ask BlueKitty:** "Should I pull any reference docs from archive/phase-XX/?"
- If yes: Copy specified docs to new phase directory
- If no: Proceed

**For brand new phase:** Skip this step.

---

### 3. Read Planning Context

**Required reading:**
- `PROJECT_SPEC.md` - What's in Phase X? (authoritative source)
- `README.md` - Current project status
- `docs/archive/phase-0X-1/phase-0X-1-summary.md` - Previous phase context
- [documentation-workflow.md](./documentation-workflow.md) - How docs should be maintained
- Any docs pulled from archive

**Extract:**
- Phase X goals and scope
- Subphases included (X.1, X.2, X.3, etc.)
- Dependencies and constraints
- Known technical decisions

**DO NOT ask BlueKitty for scope - it's in the docs!**

**Reference:** Bookmark documentation-workflow.md - you'll need it when completing phases

---

### 4. Create Initial Phase Plan

**File:** `docs/phase-XX/phase-XX-plan-v1.md`

**Contents:**
```markdown
# Phase X Plan

**Version:** 1
**Created:** [DATE]
**Status:** Draft

---

## Scope

[Extracted from project_spec.md]

**Subphases:**
- X.1: [Feature name]
- X.2: [Feature name]
- X.3: [Feature name]

## Grouping Strategy

[Will be determined later when ready to implement]
[For now, document all subphases]

## Technical Approach

[High-level approach for the phase]

## Dependencies

[External dependencies, prerequisite work]

## Timeline Estimate

[Rough estimate if available]

## Open Questions

[Things to clarify before detailed planning]
```

**Confirm:** "Created phase-XX-plan-v1.md - ready for review?"

---

### 5. Wait for Detailed Planning Phase

**DO NOT immediately create:**
- ❌ phase-XXA-plan.md (too early - wait for grouping decision)
- ❌ review docs (wait for detailed spec)

**At this stage we have:**
- ✅ `docs/phase-XX/phase-XX-plan-v1.md` (high-level scope)

**Next step:** BlueKitty reviews v1, provides feedback → create v2, etc.

---

### 6. When Ready for Detailed Planning

**Trigger:** BlueKitty says "Ready to detail out X.1-X.3" or similar

**Then create:**
- `phase-XXA-plan.md` (detailed spec for specified subphases)
- `phase-XXA-review-v1.md` (team review doc)

**Process:**
1. Read final phase-XX-plan-vN.md
2. Extract subphase grouping (e.g., 3.1-3.3 = Phase 03A)
3. Create detailed plan for that group
4. Create review doc from review-template.md
5. Notify team for feedback

---

### 7. Initialize Bug Hunting Docs

**When implementation starts:**

Create tracking docs:
```bash
touch docs/phase-XX/codex-findings.md
touch docs/phase-XX/gemini-findings.md
touch docs/phase-XX/claude-findings.md
```

**Initial content for each:**
```markdown
# [Agent] Findings - Phase X

**Phase:** X
**Started:** [DATE]
**Status:** Active

---

## Instructions

This document tracks bugs, issues, and improvements found during Phase X implementation.

**Format for each finding:**
```markdown
## Issue: [Brief Title]
**File:** path/to/file.dart:line
**Type:** [Bug / Performance / Architecture / Documentation]
**Found:** [DATE]

**Description:**
[What's wrong]

**Suggested Fix:**
[How to fix]

**Impact:** [High / Medium / Low]
```

Add findings as you discover them. Claude will periodically review and address.

---

[Findings added below as discovered]
```

**Confirm:** "Bug tracking docs initialized for Phase X"

---

## Start-of-Phase Summary

**At the end of this checklist, we should have:**

✅ `docs/phase-XX/` directory created
✅ `docs/phase-XX/phase-XX-plan-v1.md` created (high-level scope)
✅ Optional: Reference docs pulled from archive
✅ Ready for planning iteration (v1 → v2 → v3)

**NOT created yet:**
- ⏳ phase-XXA-plan.md (wait for grouping decision)
- ⏳ review docs (wait for detailed specs)
- ⏳ bug hunting docs (wait for implementation start)
- ⏳ validation docs (wait for subphase completion)

---

## Example: Starting Phase 4

```
YOU: "Let's start Phase 4"

CLAUDE:
"Starting Phase 4 setup...

✅ Created docs/phase-04/

Checking archive... No Phase 4 archive (new phase).

Reading planning context:
- project_spec.md → Phase 4 scope
- phase-03-summary.md → Previous phase learnings

Phase 4 includes subphases:
- 4.1: Feature A
- 4.2: Feature B
- 4.3: Feature C

Creating phase-04-plan-v1.md...

✅ phase-04-plan-v1.md created

Status: Phase 4 planning initiated. Ready for your review of v1."
```

---

**Template Version:** 1.0
**Last Updated:** 2025-10-30
**Maintained By:** BlueKitty + Claude
