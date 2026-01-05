# Documentation Workflow Guide

**Purpose:** Ensure master documents stay current as phases complete
**Audience:** BlueKitty + Claude
**Last Updated:** 2026-01-05

---

## The Documentation Hierarchy

```
PROJECT_SPEC.md (ROOT - Master "Source of Truth")
    ↓ derives from
README.md (ROOT - Public-facing summary)
    ↓ references
docs/phase-XX/ (Implementation details, planning, test results)
```

### The Master Documents

**1. PROJECT_SPEC.md** (Root level) - **AUTHORITATIVE SOURCE**
- **Location:** `/PROJECT_SPEC.md`
- **Purpose:** Single source of truth for project state
- **Contains:**
  - Version number (e.g., "3.5")
  - Last Updated date
  - Current Phase
  - Complete phase history with completion dates
  - Detailed phase descriptions
  - Database evolution
  - Tech stack
  - Next steps

**2. README.md** (Root level) - **PUBLIC FACING**
- **Location:** `/README.md`
- **Purpose:** GitHub front page, first impression
- **Contains:**
  - Project vision and philosophy
  - Screenshots
  - Key Features (by phase)
  - Project Status (derives from PROJECT_SPEC.md)
  - Quick stats (LOC, tests, DB version)
  - Setup instructions

**3. docs/phase-XX/** - **IMPLEMENTATION DETAILS**
- **Purpose:** Granular planning, test results, completion reports
- **Examples:**
  - `phase-3.5-implementation-strategy.md` - Planning
  - `phase-3.5-test-results.md` - Test outcomes
  - `day-2-complete.md` - Completion status
  - `gemini-review-day-2.md` - Code review

---

## When to Update Documentation

### ✅ Always Update These Together

When completing ANY phase or subphase:

1. **Update PROJECT_SPEC.md** FIRST (authoritative source)
   - Version number
   - Last Updated date
   - Current Phase field
   - Current Status section (add completion line)
   - Phase description (move from "Planned" to "Completed")
   - Next Steps section

2. **Update README.md** SECOND (sync with PROJECT_SPEC)
   - Phase 3 section (or relevant phase)
   - Project Status section
   - Current Stats (LOC, tests, DB version)

3. **Create phase completion docs** in `docs/phase-XX/`
   - Implementation report
   - Test results
   - Any phase-specific summaries

4. **Commit all three together**
   ```bash
   git add PROJECT_SPEC.md README.md docs/phase-XX/
   git commit -m "docs: Complete Phase X.Y with master doc updates"
   ```

---

## What to Update in Each Document

### PROJECT_SPEC.md Updates

**Header Section (top of file):**
Search for: `**Version:**` and `**Current Phase:**`
```markdown
**Version:** 3.5 (Phase 3 In Progress)  ← Update version
**Last Updated:** 2026-01-05             ← Update date
**Current Phase:** Phase 3.5 Complete - Working on 3.6  ← Update phase
```

**Current Status Section:**
Search for: `### Current Status`
```markdown
✅ **Phase 3.5:** Comprehensive Tagging System - Complete (Jan 5, 2026)
🔜 **Phase 3.6:** Tag Search & Filtering - In Planning
```

**Phase 3 Description Section:**
Search for: `### 🚧 Phase 3: Core Productivity Features`
- Move completed subphase from "Remaining Subphases" to "Completed Subphases"
- Add completion date
- Add key metrics (tests, LOC, review results)
- Update "Remaining Subphases" list

**Next Steps Section:**
Search for: `## Next Steps`
```markdown
**Current Phase:** Phase 3.6 - Tag Search & Filtering (In Planning)

**Completed Recently:**
- ✅ Phase 3.5: Comprehensive Tagging System (Jan 5, 2026)
```

**Document Status (bottom of file):**
Search for: `**Document Status:**`
```markdown
**Last Review:** January 5, 2026
**Next Review:** After Phase 3.6-3.8 completion
```

---

### README.md Updates

**Phase 3 Section:**
Search for: `### Phase 3: Core Productivity`
```markdown
### Phase 3: Core Productivity 🚧 **IN PROGRESS**

**Completed:**
- ✅ **Phase 3.5:** Comprehensive Tagging System (Jan 2026)
  - 78 comprehensive tests (100% passing)
  - Tag picker with search/filter/create
  - [brief feature list]

**Next Up:**
- 🔜 **Phase 3.6:** Tag Search & Filtering (2-3 weeks)
```

**Tech Stack Section:**
Search for: `### Data & State`
```markdown
- **SQLite v6** (via sqflite) - Local-first, offline-capable
  - 6 schema migrations (v1 → v6)
- **154 comprehensive tests** - Models, services, utilities (95%+ pass rate)
```

**Project Status Section:**
Search for: `## Project Status`
```markdown
🚧 **Phase 3 In Progress** - Core productivity features!

### Completed Phases
- [x] **Phase 3.5:** Comprehensive Tagging System (Jan 2026)
  - [achievement highlights]

### Current Stats
- **~8,000+ lines of production code**
- **154 tests passing** (95%+ pass rate)
- **Database:** v6 (6 migrations complete)
```

---

## Checklist: Completing a Phase

Use this checklist when marking a phase/subphase complete:

### Before Merging to Main

- [ ] All tests passing for the phase
- [ ] Code review findings addressed (if applicable)
- [ ] Phase completion doc created in `docs/phase-XX/`

### Update Master Documents

- [ ] **PROJECT_SPEC.md:**
  - [ ] Update Version number (e.g., 3.4 → 3.5)
  - [ ] Update Last Updated date
  - [ ] Update Current Phase field
  - [ ] Add completion line in Current Status section
  - [ ] Move phase from "Planned" to "Completed" with date
  - [ ] Update Next Steps section
  - [ ] Update Document Status (Last Review date)

- [ ] **README.md:**
  - [ ] Update Phase 3 section (or relevant phase)
  - [ ] Add completed subphase with date and highlights
  - [ ] Update "Next Up" list
  - [ ] Update Project Status section
  - [ ] Update Current Stats (LOC, tests, DB version)
  - [ ] Update Tech Stack if DB version changed

- [ ] **docs/phase-XX/:**
  - [ ] Create `phase-X.Y-complete.md` or similar
  - [ ] Include test results
  - [ ] Include key achievements
  - [ ] Link to implementation docs

### Commit and Push

- [ ] Stage all three document types
- [ ] Commit with clear message: "docs: Complete Phase X.Y with master doc updates"
- [ ] Push to main
- [ ] Verify changes on GitHub

---

## Common Mistakes to Avoid

### ❌ DON'T:
- ❌ Update only phase-specific docs without updating master docs
- ❌ Update README.md but forget PROJECT_SPEC.md
- ❌ Leave version numbers or dates unchanged
- ❌ Use vague completion language ("mostly done", "in progress")
- ❌ Forget to update "Next Steps" section
- ❌ Commit documents separately (breaks sync)

### ✅ DO:
- ✅ Update PROJECT_SPEC.md FIRST (it's authoritative)
- ✅ Update README.md to match PROJECT_SPEC.md
- ✅ Use clear completion dates
- ✅ Include key metrics (tests, LOC, achievements)
- ✅ Update all three document types together
- ✅ Commit with descriptive message

---

## Example: Completing Phase 3.5

### 1. Update PROJECT_SPEC.md

```markdown
**Version:** 3.4 → 3.5 (Phase 3 In Progress)
**Last Updated:** 2025-12-27 → 2026-01-05
**Current Phase:** Phase 3.4 Complete → Phase 3.5 Complete - Working on 3.6

### Current Status
✅ **Phase 3.4:** Task Editing - Complete (Dec 2025)
✅ **Phase 3.5:** Comprehensive Tagging System - Complete (Jan 5, 2026)
🔜 **Phase 3.6:** Tag Search & Filtering - In Planning

### Phase 3: Core Productivity Features (In Progress)
**Phase 3.5: Comprehensive Tagging System** ✅ (Jan 5, 2026)
- Tag model with validation (name, color, timestamps)
- 78 comprehensive tests (100% passing)
- [complete feature list]
```

### 2. Update README.md

```markdown
### Phase 3: Core Productivity 🚧 **IN PROGRESS**

**Completed:**
- ✅ **Phase 3.5:** Comprehensive Tagging System (Jan 2026)
  - 78 tests (100% passing)
  - WCAG AA compliant colors
  - Tag picker with search/filter/create

### Project Status
🚧 **Phase 3 In Progress**

- [x] **Phase 3.5:** Comprehensive Tagging System (Jan 2026)
  - 78 comprehensive tests
  - Database v6
  - Dual AI code review

### Current Stats
- **154 tests passing**
- **Database:** v6
```

### 3. Create Phase Docs

```
docs/phase-03/phase-3.5-test-results.md
docs/phase-03/day-2-complete.md
docs/phase-03/gemini-fixes-summary.md
docs/phase-03/codex-fixes-summary.md
```

### 4. Commit Together

```bash
git add PROJECT_SPEC.md README.md docs/phase-03/
git commit -m "docs: Complete Phase 3.5 with master doc updates

- Updated PROJECT_SPEC.md: Version 3.5, completion date, achievements
- Updated README.md: Phase 3 section, project status, stats
- Added phase-3.5-test-results.md and completion docs

Phase 3.5 complete with 78/78 tests passing, WCAG AA compliance,
and all AI review findings addressed."
```

---

## Automation Ideas (Future)

### Phase Completion Script
```bash
#!/bin/bash
# scripts/complete-phase.sh

PHASE=$1
DATE=$2
VERSION=$3

# Update PROJECT_SPEC.md version
sed -i "s/Version: .*/Version: $VERSION/" PROJECT_SPEC.md

# Update PROJECT_SPEC.md date
sed -i "s/Last Updated: .*/Last Updated: $DATE/" PROJECT_SPEC.md

# Prompt for manual review before commit
echo "Please review PROJECT_SPEC.md and README.md, then commit"
```

### Pre-commit Hook
```bash
# .git/hooks/pre-commit
# Warn if PROJECT_SPEC.md or README.md modified but not both

if git diff --cached --name-only | grep -q "PROJECT_SPEC.md"; then
  if ! git diff --cached --name-only | grep -q "README.md"; then
    echo "⚠️  WARNING: PROJECT_SPEC.md modified without README.md"
    echo "Consider updating both master documents together"
    # Don't block, just warn
  fi
fi
```

---

## FAQ

**Q: Why do we have both PROJECT_SPEC.md and README.md?**
A: PROJECT_SPEC.md is the detailed authoritative source (1000+ lines). README.md is the public-facing summary for GitHub. They serve different audiences but must stay in sync.

**Q: Which document should I update first?**
A: Always update PROJECT_SPEC.md first (it's the source of truth), then sync README.md to match.

**Q: What if I forget to update the master docs?**
A: They'll get out of date (as happened with Phase 3.4 and 3.5). Review this workflow before completing each phase to build the habit.

**Q: Do I update docs for every commit?**
A: No - only when COMPLETING a phase/subphase. Ongoing work doesn't require master doc updates.

**Q: What about docs/phase-XX/ files?**
A: These are implementation details. Create them as needed during development, but they don't need to be updated every time - only master docs need that discipline.

---

## Integration with Phase Checklists

This workflow is now integrated into:
- `phase-start-checklist.md` - Reminds you to check current docs
- `phase-end-checklist.md` - **Enforces updating master docs**

Always refer to phase-end-checklist.md when completing a phase to ensure you don't forget documentation updates.

---

**Remember:** Documentation is part of the deliverable. A phase isn't "complete" until PROJECT_SPEC.md and README.md reflect its completion!

---

*Keeping docs current makes future-you (and contributors) very happy.* 📝✨
