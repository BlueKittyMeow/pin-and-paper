# Development Workflow Summary

**Created:** 2025-10-30
**Updated:** 2026-01-22 (v3 - added agent validation templates)
**Purpose:** Quick reference for the complete development cycle

---

## Document Types

### 1️⃣ Phase Planning (versioned, archived on update)

**When:** Start of phase and during planning refinement
**Purpose:** Define scope, group subphases, detail implementation approach
**Files:**
- `phase-XX-plan-v1.md`, `v2.md`, `v3.md` (overall phase scope)
- `phase-XXA-plan.md` (detailed spec for subphase group A, e.g., 3.1-3.3)
- `phase-XXB-plan.md` (detailed spec for subphase group B, e.g., 3.4-3.5)

**Versioning workflow:**
- Create v1 → refine → create v2 → **immediately archive v1**
- Continue until final version
- Keep only latest version in active directory

**Example:** `docs/phase-04/phase-04-plan-v3.md`

---

### 2️⃣ Pre-Implementation Review (versioned)

**When:** After detailed plan created, before implementation
**Purpose:** Team review of detailed specs
**Template:** `docs/templates/review-template.md`
**Output:** `phase-XXA-review-v1.md`, `v2.md`, etc.

**Process:**
1. Claude creates detailed plan (phase-XXA-plan.md)
2. Create review doc from template (phase-XXA-review-v1.md)
3. Team reviews (Gemini, Codex, BlueKitty)
4. Multiple rounds (v2, v3) until approved
5. Mark final version in header → ready to implement

**Example:** `docs/phase-04/phase-04A-review-v2.md` (FINAL)

---

### 3️⃣ Ongoing Bug Hunting (agent-specific, living docs)

**When:** During implementation (parallel to Claude's work)
**Purpose:** Continuous bug finding while Claude codes
**Files:**
- `codex-findings.md` (Codex's running log)
- `gemini-findings.md` (Gemini's running log)
- `claude-findings.md` (Claude's self-review notes)

**Process:**
1. Claude implements subphase
2. All agents explore codebase (READ-ONLY)
3. Each agent adds findings to their doc continuously
4. Claude periodically reviews and applies fixes
5. Docs stay active throughout entire phase

**Key:** These are SEPARATE from EOP validation!

---

### 4️⃣ End-of-Subphase Validation (versioned per cycle)

**When:** After each subphase implementation complete
**Purpose:** Structured validation with fix/verify cycles
**Template:** `docs/templates/validation-template.md`
**Output:** `phase-X.Y-validation-v1.md`, `v2.md`, etc.

**Process:**
1. Claude finishes subphase implementation
2. Create validation-v1.md from template
3. **Cycle 1 (v1):** Team reviews → finds issues → Claude fixes
4. **Cycle 2 (v2):** Team verifies fixes → new issues if any
5. Repeat until clean → mark final version in header
6. Final sign-off → subphase validated

**Why versioned:** Keeps files <500 lines for Gem/Codex readability

**Example:** `phase-3.1-validation-v2.md` (FINAL - all issues resolved)

---

### 5️⃣ Implementation Reports (one per subphase)

**When:** During/after subphase implementation
**Purpose:** Document implementation details, decisions, metrics
**Output:** `phase-X.Y-implementation-report.md`

**Contents:**
- What was implemented
- Technical decisions made
- Metrics (code changes, tests, commits)
- Lessons learned
- Known issues

**Example:** `phase-3.1-implementation-report.md`

---

### 6️⃣ Phase Summary (one per phase)

**When:** End of phase, before archiving
**Purpose:** Retrospective summary of entire phase
**Output:** `phase-XX-summary.md`

**Contents:**
- All subphases completed
- Key achievements
- Consolidated metrics
- Deferred work
- Process improvements

**Example:** `phase-03-summary.md`

---

## Complete Phase Lifecycle

```
┌────────────────────────────────────────────────────┐
│ PHASE LIFECYCLE                                     │
└────────────────────────────────────────────────────┘

START PHASE (see phase-start-checklist.md)
├─ 1. Create docs/phase-XX/ directory
├─ 2. Read docs/PROJECT_SPEC.md for Phase XX scope
├─ 3. Create phase-XX-plan-v1.md (high-level)
├─ 4. Iterate: v1 → v2 → v3 (archive old versions)
└─ 5. Ready for grouping/implementation
      ↓
DETAILED PLANNING (per group)
├─ Create phase-XXA-plan.md (detailed spec for X.1-X.3)
├─ Create phase-XXA-review-v1.md (team review)
├─ Review cycles: v1 → v2 → mark FINAL
├─ Sign-off → approved for implementation
└─ Repeat for phase-XXB-plan.md if needed
      ↓
IMPLEMENTATION (per subphase)
├─ Initialize bug hunting docs (first subphase only):
│   ├─ codex-findings.md
│   ├─ gemini-findings.md
│   └─ claude-findings.md
├─ Claude implements subphase X.Y
├─ Team adds findings to their docs (ongoing)
├─ Claude periodically applies fixes
├─ Create phase-X.Y-implementation-report.md
└─ Create phase-X.Y-validation-v1.md
      ↓
VALIDATION (per subphase)
├─ Create agent validation docs:
│   ├─ codex-validation.md (from codex-validation-template.md)
│   └─ gemini-validation.md (from gemini-validation-template.md)
├─ Cycle 1 (validation-v1.md): Review → fix
├─ Cycle 2 (validation-v2.md): Verify → repeat if needed
├─ Mark final version: "FINAL - Phase X.Y VALIDATED"
└─ Subphase validated ✅
      ↓
[Repeat IMPLEMENTATION + VALIDATION for all subphases]
      ↓
END PHASE (see phase-end-checklist.md)
├─ 1. Verify all implementation reports exist
├─ 2. Create phase-XX-summary.md
├─ 3. Confirm team done with findings docs
├─ 4. Archive EVERYTHING to docs/archive/phase-XX/
└─ 5. docs/phase-XX/ now empty → ready for next phase
```

---

## File Naming Conventions

### ✅ Standard Naming (Phase 4+)

**Phase Planning:**
- `phase-04-plan-v1.md`, `v2.md`, `v3.md` (archive old versions)
- `phase-04A-plan.md` (subphases 4.1-4.3)
- `phase-04B-plan.md` (subphases 4.4-4.5)

**Pre-Implementation Review:**
- `phase-04A-review-v1.md`, `v2.md` (mark FINAL in header)
- `phase-04B-review-v1.md`, `v2.md`

**Bug Hunting (ongoing during implementation):**
- `codex-findings.md` (Codex's log)
- `gemini-findings.md` (Gemini's log)
- `claude-findings.md` (Claude's log)

**Agent Validation (post-implementation):**
- `codex-validation.md` (Codex's focused validation review)
- `gemini-validation.md` (Gemini's build/analysis review)

**Validation:**
- `phase-4.1-validation-v1.md`, `v2.md` (mark FINAL in header)
- `phase-4.2-validation-v1.md`
- `phase-4.3-validation-v1.md`

**Documentation:**
- `phase-4.1-implementation-report.md`
- `phase-4.2-implementation-report.md`
- `phase-04-summary.md`

---

### ⚠️ Legacy Naming (Phase 3)

**Phase 3 uses old naming conventions (grandfathered in):**
- `group1-final-feedback.md` (instead of phase-03A-review-vN.md)
- `codex-findings.md` ✅ (consistent)
- `3.1-issues.md` (instead of gemini-findings.md)
- `3.1-issues-response.md` (instead of claude-findings.md)

**Do NOT update Phase 3 retroactively** - live with legacy names.

**Apply new naming starting Phase 4.**

---

### ❌ DON'T

- ❌ Multiple files per validation cycle (`validation-cycle-1.md`, `cycle-2.md`)
- ❌ Vague names (`issues.md`, `bugs.md`, `fixes.md`)
- ❌ Mixing ongoing findings with EOP validation
- ❌ Using "group" terminology (use letter suffixes: A, B, C)
- ❌ Keeping old plan versions in active directory (archive immediately)

---

## Quick Decision Tree

### "Which document should I create?"

```
Are you starting a new phase?
├─ YES → phase-start-checklist.md
│        └─ Create phase-XX-plan-v1.md
│
└─ NO → Are you refining the plan?
    ├─ YES → Create phase-XX-plan-v2.md
    │        └─ Archive v1 immediately!
    │
    └─ NO → Ready to implement a group?
        ├─ YES → Create phase-XXA-plan.md
        │        └─ Create phase-XXA-review-v1.md
        │
        └─ NO → Currently implementing?
            ├─ YES → Add findings to:
            │        ├─ codex-findings.md
            │        ├─ gemini-findings.md
            │        └─ claude-findings.md
            │
            └─ NO → Subphase done?
                ├─ YES → Create phase-X.Y-validation-v1.md
                │
                └─ NO → Phase complete?
                    └─ YES → phase-end-checklist.md
```

---

## Templates & Checklists

All templates and checklists in: `docs/templates/`

| Document | Purpose | Type |
|----------|---------|------|
| `review-template.md` | Pre-implementation review | Template |
| `review-template-about.md` | How to use review template | Guide |
| `validation-template.md` | End-of-subphase validation | Template |
| `validation-template-about.md` | How to use validation template | Guide |
| `codex-findings-template.md` | Codex ongoing bug hunting | Template |
| `gemini-findings-template.md` | Gemini ongoing bug hunting | Template |
| `codex-validation-template.md` | Codex post-implementation validation | Template |
| `gemini-validation-template.md` | Gemini post-implementation validation | Template |
| `phase-start-checklist.md` | Start new phase workflow | Checklist |
| `phase-end-checklist.md` | Close out phase workflow | Checklist |
| `build-and-release.md` | Build/release and version updates | Guide |
| `documentation-workflow.md` | Master doc update workflow | Guide |
| `WORKFLOW-SUMMARY.md` | This document! | Reference |

---

## Key Principles

1. **Version everything** - Plans, reviews, validations all versioned
2. **Archive immediately** - Don't keep multiple versions in active dir
3. **Consistent naming** - phase-XX pattern, letter suffixes (A, B, C)
4. **Separation of concerns** - Ongoing ≠ EOP validation
5. **One source of truth** - Latest version only in active directory
6. **Under 500 lines** - Validation versioned to keep files readable

---

## Example: Phase 4 Lifecycle

### Start Phase 4
```
docs/phase-04/
└─ phase-04-plan-v1.md (created from project_spec.md)

(Refinement)
├─ phase-04-plan-v2.md (v1 → archive)
└─ phase-04-plan-v3.md (v2 → archive, this is FINAL)
```

### Plan Group A (4.1-4.3)
```
docs/phase-04/
├─ phase-04-plan-v3.md (reference)
├─ phase-04A-plan.md (detailed spec)
└─ phase-04A-review-v1.md (team review)

(Review rounds)
├─ phase-04A-review-v2.md (FINAL - approved)
```

### Implement Subphase 4.1
```
docs/phase-04/
├─ codex-findings.md (initialized, ongoing)
├─ gemini-findings.md (initialized, ongoing)
├─ claude-findings.md (initialized, ongoing)
├─ phase-4.1-implementation-report.md (during implementation)
└─ phase-4.1-validation-v1.md (after implementation)

(Validation cycles)
├─ phase-4.1-validation-v2.md (FINAL - validated ✅)
```

### Repeat for 4.2, 4.3...

### End Phase 4

**Before archiving, complete these steps:**

1. **Build and test release version** (see `build-and-release.md`)
   - Update `pubspec.yaml` version to match phase (e.g., 4.0.0)
   - Update `constants.dart` appVersion
   - Build release APK: `flutter build apk --release`
   - Test on device in release mode
   - Verify performance, features, database migration

2. **Update master documentation** (see `documentation-workflow.md`)
   - Update PROJECT_SPEC.md (version, dates, current phase, status)
   - Update README.md (phase section, stats)
   - Commit together with phase docs

3. **Create phase summary** (see `phase-end-checklist.md`)
   - Create `phase-04-summary.md` with metrics, lessons learned
   - Confirm team finished with findings docs
   - Archive everything

```
Before archiving:
docs/phase-04/
├─ phase-04-plan-v3.md
├─ phase-04A-plan.md
├─ phase-04A-review-v2.md
├─ phase-04B-plan.md
├─ phase-04B-review-v1.md
├─ codex-findings.md
├─ gemini-findings.md
├─ claude-findings.md
├─ phase-4.1-implementation-report.md
├─ phase-4.1-validation-v2.md
├─ phase-4.2-implementation-report.md
├─ phase-4.2-validation-v1.md
├─ phase-4.3-implementation-report.md
├─ phase-4.3-validation-v1.md
└─ phase-04-summary.md (created at end)

After archiving:
docs/phase-04/ (empty)
docs/archive/phase-04/ (all files moved)

Root-level master docs updated:
PROJECT_SPEC.md (version 4.0, Phase 4 complete)
README.md (Phase 4 section updated, stats current)
```

---

## Benefits of This System

✅ **No fragmentation** - Clear which doc serves which purpose
✅ **Easy to find** - Predictable naming with version numbers
✅ **File size control** - Versioning keeps docs under 500 lines
✅ **Clean workspace** - Old versions archived immediately
✅ **Clear progression** - v1 → v2 → v3 → FINAL
✅ **Parallel work** - Ongoing bug hunting doesn't block implementation
✅ **Structured closure** - Formal sign-off and archiving process
✅ **Tied to phase** - Letter suffixes (A, B) clearly tied to phase number

---

**Last Updated:** 2026-01-22 (v3 - added agent validation templates)
**Maintained By:** BlueKitty + Claude
