# Development Workflow Summary

**Created:** 2025-10-30
**Purpose:** Quick reference for the complete development cycle

---

## Three Document Types

### 1️⃣ Pre-Implementation Review (`review-template.md`)

**When:** Before implementation starts
**Purpose:** Review plans, designs, architecture
**Template:** `docs/templates/review-template.md`
**Output:** `docs/phase-XX/groupX-review.md`, `groupX-secondary-feedback.md`, etc.

**Process:**
1. Claude drafts implementation plan
2. Create review doc from template
3. Team reviews plan (Gemini, Codex, BlueKitty)
4. Multiple rounds of feedback until approved
5. Sign-off → ready to implement

**Example:** `docs/phase-03/group1-final-feedback.md`

---

### 2️⃣ Ongoing Bug Hunting (ad-hoc docs)

**When:** During implementation (parallel to Claude's work)
**Purpose:** Continuous bug finding while Claude codes
**Files:** `codex-findings.md`, `3.1-issues.md`, etc. (agent-specific)

**Process:**
1. Claude implements subphase
2. Codex + Gemini explore codebase (READ-ONLY)
3. They add findings to their docs continuously
4. Claude periodically reviews and applies fixes
5. Docs stay active throughout implementation

**Example:** `docs/phase-03/codex-findings.md`

**Key:** These are SEPARATE from EOP validation (see below)!

---

### 3️⃣ End-of-Phase Validation (`validation-template.md`)

**When:** After implementation complete
**Purpose:** Structured EOP validation with cycles
**Template:** `docs/templates/validation-template.md`
**Output:** `docs/phase-XX/phase-X.Y-validation.md` (single doc per subphase)

**Process:**
1. Claude finishes implementation
2. Create validation doc from template
3. **Cycle 1:** Team reviews code → finds issues → Claude fixes
4. **Cycle 2:** Team verifies fixes → repeat if needed
5. Final sign-off → subphase validated

**Example:** `docs/phase-03/phase-3.2-validation.md` (future)

---

## Complete Development Cycle

```
┌─────────────────────────────────────────────────────────────┐
│ Phase X.Y Development Lifecycle                              │
└─────────────────────────────────────────────────────────────┘

1. PLANNING
   ├─ Claude drafts implementation plan
   ├─ Create review doc (review-template.md)
   └─ Team reviews → feedback rounds → sign-off
         ↓
2. IMPLEMENTATION
   ├─ Claude codes the feature
   ├─ (Parallel) Codex + Gemini do ongoing bug hunting
   │   └─ Add findings to codex-findings.md, etc.
   │   └─ Claude periodically applies fixes
   ├─ Unit tests written
   └─ Implementation report created
         ↓
3. END-OF-PHASE VALIDATION
   ├─ Create validation doc (validation-template.md)
   ├─ Cycle 1: Team reviews → Claude fixes
   ├─ Cycle 2: Team verifies → repeat if needed
   └─ Final sign-off
         ↓
4. DONE
   └─ Move to next subphase
```

---

## File Naming Conventions

### DO ✅

**Pre-Implementation:**
- `group1-review.md`
- `group1-secondary-feedback.md`
- `group2-final-feedback.md`

**Ongoing Bug Hunting:**
- `codex-findings.md` (Codex's running log)
- `3.1-issues.md` (Gemini's findings)
- `3.1-issues-response.md` (Claude's analysis)

**EOP Validation:**
- `phase-3.1-validation.md`
- `phase-3.2-validation.md`
- `phase-4.1-validation.md`

**Implementation Records:**
- `phase-3.1-implementation-report.md`
- `phase-3.2-implementation-report.md`

### DON'T ❌

- ❌ Multiple validation files per subphase (`validation-cycle-1.md`, `validation-cycle-2.md`)
- ❌ Agent-specific validation files (`codex-validation.md`, `gemini-validation.md`)
- ❌ Vague names (`issues.md`, `bugs.md`, `fixes.md`)
- ❌ Mixing ongoing findings with EOP validation

---

## Quick Decision Tree

**"Should I create a review doc or validation doc?"**

```
Is implementation started yet?
├─ NO → Use review-template.md (pre-implementation)
│        (Reviewing plan before coding)
│
└─ YES → Is implementation complete?
    ├─ NO → Ongoing bug hunting (ad-hoc docs)
    │        (Finding bugs while Claude codes)
    │
    └─ YES → Use validation-template.md (EOP)
             (Structured validation with sign-off)
```

---

## Templates Location

All templates live in: `docs/templates/`

| Template | Purpose | Guide |
|----------|---------|-------|
| `review-template.md` | Pre-implementation review | `review-template-about.md` |
| `validation-template.md` | End-of-phase validation | `validation-template-about.md` |

**No template for ongoing bug hunting** - these are ad-hoc agent-specific docs that evolve naturally.

---

## Key Principles

1. **One document per purpose** - Don't mix review/validation/bug-hunting
2. **Single source of truth** - One validation doc per subphase (not per cycle)
3. **Clear naming** - `phase-X.Y-validation.md` pattern
4. **Chronological flow** - All cycles in one doc (scroll to bottom for current status)
5. **Separation of concerns** - Ongoing ≠ EOP validation

---

## Example: Phase 3.2 Lifecycle

**Pre-Implementation:**
- `docs/phase-03/group1-review.md` ✅ (approved)

**During Implementation:**
- Claude implements Phase 3.2 hierarchical UI
- `docs/phase-03/codex-findings.md` (ongoing bug hunting)
- `docs/phase-03/3.2-issues.md` (Gemini's ongoing findings)
- `docs/phase-03/phase-3.2-implementation-report.md` (created as work progresses)

**After Implementation:**
- `docs/phase-03/phase-3.2-validation.md` (EOP structured validation)
  - Cycle 1: Review → fix
  - Cycle 2: Verify
  - Final sign-off

**Result:**
- Phase 3.2 validated ✅
- Move to Phase 3.3

---

## Benefits of This System

✅ **No fragmentation** - Clear which doc serves which purpose
✅ **Easy to find** - Predictable naming (`phase-X.Y-validation.md`)
✅ **Complete history** - All cycles in one chronological doc
✅ **Clear status** - Scroll to bottom for current state
✅ **Parallel work** - Ongoing bug hunting doesn't block implementation
✅ **Structured closure** - Formal sign-off process

---

**Last Updated:** 2025-10-30
**Maintained By:** BlueKitty + Claude
