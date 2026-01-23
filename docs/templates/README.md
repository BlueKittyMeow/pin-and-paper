# Documentation Templates - Quick Reference Guide

**Purpose:** Central guide for all project documentation templates
**Audience:** BlueKitty + Claude + Team Agents (Codex, Gemini)
**Last Updated:** 2026-01-22

---

## 📚 Available Templates

| Template | Purpose | When to Use | Output File |
|----------|---------|-------------|-------------|
| [review-template.md](./review-template.md) | Pre-implementation review | Before coding starts (OPTIONAL) | `phase-XXA-review-v1.md` |
| [validation-template.md](./validation-template.md) | Post-implementation validation | After coding complete | `phase-X.Y-validation-v1.md` |
| [manual-test-plan-template.md](./manual-test-plan-template.md) | Manual testing checklist | During validation | `phase-X.Y-manual-test-plan.md` |
| **[codex-findings-template.md](./codex-findings-template.md)** | **Codex ongoing bug hunting** | **During implementation** | **`codex-findings.md`** |
| **[gemini-findings-template.md](./gemini-findings-template.md)** | **Gemini ongoing bug hunting** | **During implementation** | **`gemini-findings.md`** |
| [codex-validation-template.md](./codex-validation-template.md) | Codex post-implementation validation | During validation phase | `codex-validation.md` |
| [gemini-validation-template.md](./gemini-validation-template.md) | Gemini post-implementation validation | During validation phase | `gemini-validation.md` |
| [phase-start-checklist.md](./phase-start-checklist.md) | Phase initialization | Starting new phase | Follow checklist steps |
| [phase-end-checklist.md](./phase-end-checklist.md) | Phase closeout | Finishing phase | `phase-XX-summary.md` + archive + `FEATURE_REQUESTS.md` update |
| [build-and-release.md](./build-and-release.md) | Build and release guide | Before building release | Version updates + testing |
| [documentation-workflow.md](./documentation-workflow.md) | Master doc update workflow | Completing phases | Updated PROJECT_SPEC + README |
| [WORKFLOW-SUMMARY.md](./WORKFLOW-SUMMARY.md) | Development cycle overview | Reference anytime | N/A (reference only) |
| [agent-prompts-cheatsheet.md](./agent-prompts-cheatsheet.md) | Agent interaction guide | Reference for prompting | N/A (reference only) |
| [agent-feedback-guide.md](./agent-feedback-guide.md) | How to provide feedback | Giving feedback | N/A (guide only) |

---

## ⚠️ CRITICAL: Agent Templates (Findings vs Validation)

**Two types of agent docs, for different phases of the workflow:**

### Findings Templates (During Implementation)
Use these for **ongoing bug hunting** while Claude is implementing:
```bash
cp docs/templates/codex-findings-template.md docs/phase-XX/codex-findings.md
cp docs/templates/gemini-findings-template.md docs/phase-XX/gemini-findings.md
```
- Living documents, updated throughout implementation
- Agents explore codebase and log issues as they find them
- Claude periodically reviews and applies fixes

### Validation Templates (Post-Implementation)
Use these for **focused validation** after implementation is complete:
```bash
cp docs/templates/codex-validation-template.md docs/phase-XX/codex-validation.md
cp docs/templates/gemini-validation-template.md docs/phase-XX/gemini-validation.md
```
- One-time focused review of completed code
- Codex: code correctness, data integrity, security, test coverage
- Gemini: build verification, static analysis, schema, UI/accessibility
- Each produces a verdict (Release Ready: YES/NO/YES WITH FIXES)

### DON'T:
- ❌ Create agent docs from scratch (always use templates)
- ❌ Use review-template.md for agent reviews
- ❌ Have agents add feedback to a shared doc
- ❌ Mix findings (ongoing) with validation (post-implementation)

---

## 🎯 Quick Decision Tree

**"Which template should I use?"**

```
┌─ Starting a new phase?
│  └─> phase-start-checklist.md
│
├─ Have a detailed plan ready for review?
│  └─> review-template.md
│
├─ Currently implementing? (agents hunting bugs in parallel)
│  └─> codex-findings-template.md / gemini-findings-template.md
│
├─ Just finished implementation and need validation?
│  ├─> validation-template.md (Claude's validation doc)
│  ├─> codex-validation-template.md (Codex's focused review)
│  └─> gemini-validation-template.md (Gemini's build/analysis review)
│
├─ Ready to build a release version?
│  └─> build-and-release.md
│
├─ Ready to close out a completed phase?
│  └─> phase-end-checklist.md (also see documentation-workflow.md)
│
├─ Need to understand the overall workflow?
│  └─> WORKFLOW-SUMMARY.md
│
└─ Not sure how to prompt agents or give feedback?
   └─> agent-prompts-cheatsheet.md or agent-feedback-guide.md
```

---

## 📖 Detailed Template Guide

### 1. Review Template (Pre-Implementation)

**File:** [review-template.md](./review-template.md)
**Companion Guide:** [review-template-about.md](./review-template-about.md)

**Use When:**
- ✅ Detailed plan/spec is written and ready for review
- ✅ BEFORE implementation starts
- ✅ Need team feedback on design/architecture
- ✅ Want structured review with sign-off process

**Don't Use When:**
- ❌ Implementation already started/complete (use validation-template instead)
- ❌ Just have high-level scope (refine plan first)
- ❌ Doing ongoing bug hunting (use findings docs)

**Output Example:**
```
docs/phase-03/phase-03A-review-v1.md  (Round 1)
docs/phase-03/phase-03A-review-v2.md  (Round 2, after feedback)
docs/phase-03/phase-03A-review-v3.md  (FINAL, approved)
```

**Key Features:**
- Structured feedback format (Priority + Category + Issue)
- Priority levels (CRITICAL/HIGH/MEDIUM/LOW)
- Category tags (Compilation/Logic/Data/Architecture/etc.)
- Sign-off section for team consensus
- Summary tables for issue tracking

**Process:**
1. Copy template → `phase-XXA-review-v1.md`
2. Fill in context, scope, review instructions
3. Team reviews and adds feedback
4. Address feedback → create v2
5. Repeat until all sign off → mark FINAL

**Example Usage:**
```bash
# Phase 3.5 planning complete, ready for review
cp docs/templates/review-template.md docs/phase-03/phase-3.5-review-v1.md
# Edit file, notify team
# After feedback, create v2 with updates
```

---

### 2. Validation Template (Post-Implementation)

**File:** [validation-template.md](./validation-template.md)
**Companion Guide:** [validation-template-about.md](./validation-template-about.md)

**Use When:**
- ✅ Implementation is COMPLETE (code written, tests passing)
- ✅ Need structured bug finding and fix tracking
- ✅ Want multi-cycle fix → verify → sign-off process
- ✅ Ready for end-of-phase (EOP) validation

**Don't Use When:**
- ❌ Still implementing (use ongoing bug hunting docs)
- ❌ Reviewing plans/designs (use review-template instead)
- ❌ Just need quick feedback (use findings docs)

**Output Example:**
```
docs/phase-03/phase-3.5-validation-v1.md  (Cycle 1: find issues, fix)
docs/phase-03/phase-3.5-validation-v2.md  (Cycle 2: verify fixes)
docs/phase-03/phase-3.5-validation-v3.md  (FINAL: all resolved)
```

**Key Features:**
- Multi-cycle validation workflow
- Issue tracking by severity
- Fix verification process
- Exit criteria checklist
- Final sign-off section

**Process:**
1. Implementation complete → create validation-v1.md
2. **Cycle 1:** Team reviews code → finds issues → Claude fixes
3. **Cycle 2:** Team verifies fixes → new issues if any
4. Repeat until clean → mark FINAL
5. All sign off → implementation validated

**Typical Timeline:**
- Cycle 1: 2-4 hours (review + fix)
- Cycle 2: 1-2 hours (verify)
- Total: Usually 2 cycles, 3-6 hours

**Example Usage:**
```bash
# Phase 3.5 implementation done, ready for validation
cp docs/templates/validation-template.md docs/phase-03/phase-3.5-validation-v1.md
# Edit file, team reviews
# After fixes: cp to phase-3.5-validation-v2.md for verification
```

---

### 3. Phase Start Checklist

**File:** [phase-start-checklist.md](./phase-start-checklist.md)

**Use When:**
- ✅ Starting a brand new phase (e.g., Phase 4)
- ✅ Need to set up phase directory structure
- ✅ Creating initial high-level plan

**Process:**
1. Create `docs/phase-XX/` directory
2. Check archive for context from previous phases
3. Read planning context (`docs/PROJECT_SPEC.md`, etc.)
4. Create `phase-XX-plan-v1.md` with high-level scope
5. Initialize bug hunting docs when implementation starts

**What You Get:**
- ✅ Clean phase directory structure
- ✅ Initial planning document
- ✅ Ready for planning iteration (v1 → v2 → v3)

**What You DON'T Get Yet:**
- ⏳ Detailed subphase plans (wait for grouping decision)
- ⏳ Review docs (wait for detailed specs)
- ⏳ Bug hunting docs (wait for implementation start)

**Example:**
```
Starting Phase 4:
  1. Create docs/phase-04/
  2. Read project_spec.md for Phase 4 scope
  3. Create phase-04-plan-v1.md
  4. Ready for BlueKitty's review
```

---

### 4. Phase End Checklist

**File:** [phase-end-checklist.md](./phase-end-checklist.md)

**Use When:**
- ✅ All subphases in a phase are complete
- ✅ Ready to close out and archive documentation
- ✅ Transitioning to next phase

**Process:**
1. Verify all implementation reports exist
2. Verify all validation docs are closed
3. Create phase summary document
4. **Confirm team is done with findings docs** (important!)
5. Archive everything to `docs/archive/phase-XX/`

**Critical:** Always ask BlueKitty to confirm team is finished before archiving!

**What You Get:**
- ✅ Comprehensive phase summary
- ✅ All work archived and organized
- ✅ Clean phase directory ready for next phase
- ✅ Clear record of accomplishments

**Example:**
```
Closing Phase 3:
  1. Check all 3.1, 3.2, 3.3 reports exist ✅
  2. Check all validations closed ✅
  3. Create phase-03-summary.md ✅
  4. Ask: "Is team done with findings?" → Yes
  5. Archive: mv docs/phase-03/* docs/archive/phase-03/
  6. Result: docs/phase-03/ empty, ready for Phase 4
```

---

### 5. Workflow Summary (Reference)

**File:** [WORKFLOW-SUMMARY.md](./WORKFLOW-SUMMARY.md)

**Use When:**
- Want to understand the complete development cycle
- Need to see how documents relate to each other
- Reference for naming conventions
- Understanding versioning strategy

**Not a Template:** This is a reference guide, not a template to copy.

**Key Topics:**
- Document types (planning, review, validation, reports)
- Versioning workflow
- When to create each document type
- Relationship between documents

---

### 6. Agent Prompts Cheatsheet (Reference)

**File:** [agent-prompts-cheatsheet.md](./agent-prompts-cheatsheet.md)

**Use When:**
- Need to prompt Codex, Gemini, or other agents
- Want examples of effective prompts
- Looking for best practices in agent communication

**Not a Template:** Reference guide for interaction patterns.

---

### 7. Build and Release Guide

**File:** [build-and-release.md](./build-and-release.md)

**Use When:**
- ✅ Ready to build release version for testing
- ✅ End of phase - preparing for production
- ✅ Need to update version numbers
- ✅ Want to understand debug vs release builds

**Don't Use When:**
- ❌ Daily development (use debug builds)
- ❌ Quick testing with hot reload

**Key Features:**
- Pre-build version update checklist
- Build mode comparison (debug/release/profile)
- Release testing checklist
- Version numbering strategy
- Performance verification

**Critical Reminders:**
- Update `pubspec.yaml` version to match phase (e.g., 3.5.0)
- Update `constants.dart` appVersion to match
- Increment build number for every APK
- Test in release mode before marking phase complete

**Example Usage:**
```bash
# Before Phase 3.5 release
1. Update pubspec.yaml: version: 3.5.0+5
2. Update constants.dart: appVersion = '3.5.0'
3. flutter build apk --release
4. Test on device
5. Tag release: git tag -a v3.5.0
```

---

### 8. Documentation Workflow Guide

**File:** [documentation-workflow.md](./documentation-workflow.md)

**Use When:**
- ✅ Completing any phase or subphase
- ✅ Need to update PROJECT_SPEC.md and README.md
- ✅ Want to understand documentation hierarchy

**Don't Use When:**
- ❌ Ongoing development (only update at phase completion)
- ❌ Phase-specific docs (those go in docs/phase-XX/)

**Key Features:**
- Documentation hierarchy (PROJECT_SPEC → README → phase docs)
- When to update master documents
- What to update in each document
- Stable search patterns (not line numbers)
- Integration with phase-end-checklist

**Critical Reminders:**
- PROJECT_SPEC.md is the authoritative source
- Always update PROJECT_SPEC.md and README.md together
- Use "Search for:" patterns, not line numbers
- Commit master docs together with phase docs

**Example Usage:**
```bash
# Phase 3.5 completion
1. Update PROJECT_SPEC.md: version, dates, status
2. Update README.md: Phase 3 section, stats
3. Create phase-3.5-implementation-report.md
4. git add PROJECT_SPEC.md README.md docs/phase-03/
5. git commit -m "docs: Complete Phase 3.5 with master doc updates"
```

---

### 9. Agent Feedback Guide (Reference)

**File:** [agent-feedback-guide.md](./agent-feedback-guide.md)

**Use When:**
- Providing feedback on plans or code
- Want to understand feedback format
- Learning how to structure constructive criticism

**Not a Template:** Guide for giving effective feedback.

---

## 🔄 Complete Phase Workflow (Using All Templates)

### Phase Start → Implementation → Phase End

```
1️⃣ PHASE START
   └─> Use: phase-start-checklist.md
   └─> Create: docs/phase-XX/phase-XX-plan-v1.md
   └─> Refine: v2, v3 until approved

2️⃣ DETAILED PLANNING (for subphase group)
   └─> Create: phase-XXA-plan.md (detailed spec)
   └─> Use: review-template.md
   └─> Create: phase-XXA-review-v1.md
   └─> Team reviews → v2 → FINAL

3️⃣ IMPLEMENTATION
   └─> Claude implements Phase XXA
   └─> Ongoing: Team adds to codex-findings.md, gemini-findings.md
   └─> Claude periodically reviews and fixes

4️⃣ END-OF-SUBPHASE VALIDATION
   └─> Use: validation-template.md
   └─> Create: phase-X.Y-validation-v1.md
   └─> Cycle 1: Find bugs → Fix
   └─> Cycle 2: Verify → Sign off
   └─> Mark FINAL

5️⃣ REPEAT for each subphase in phase
   └─> Implement 3.1 → Validate → Implement 3.2 → Validate → etc.

6️⃣ BUILD AND TEST RELEASE VERSION
   └─> Use: build-and-release.md
   └─> Update: pubspec.yaml version, constants.dart
   └─> Build: flutter build apk --release
   └─> Test: Manual testing in release mode
   └─> Verify: Performance, features, database migration

7️⃣ UPDATE MASTER DOCUMENTATION
   └─> Use: documentation-workflow.md
   └─> Update: PROJECT_SPEC.md (version, dates, status)
   └─> Update: README.md (phase section, stats)
   └─> Commit: All together with phase docs

8️⃣ PHASE END
   └─> Use: phase-end-checklist.md
   └─> Create: phase-XX-summary.md
   └─> Archive: mv docs/phase-XX/* docs/archive/phase-XX/
   └─> Ready for next phase
```

---

## 📋 Template Comparison

### Review vs Validation: Key Differences

| Aspect | Review Template | Validation Template |
|--------|----------------|---------------------|
| **Timing** | BEFORE implementation | AFTER implementation |
| **Focus** | Plans, designs, specs | Code, tests, implementation |
| **Input** | Documentation | Working code |
| **Output** | Approved plan | Validated code |
| **Cycles** | Refine spec until approved | Find bugs → fix → verify |
| **Sign-Off Means** | "Ready to implement" | "Ready for production" |

### When to Use Which?

**Use Review Template When:**
- You have a document to review (plan, spec, design)
- No code written yet
- Need consensus on approach
- Example: "I've written the Phase 3.5 implementation plan, ready for review"

**Use Validation Template When:**
- Code is complete and committed
- Tests are passing
- Need bug finding and verification
- Example: "Phase 3.5 implementation done, ready for team validation"

**Can Use Both:** Review plan before coding → Validate code after coding

---

## 🎨 Template Customization

All templates support customization:

### Adding Custom Priority Levels
```markdown
**Priority Levels:**
- **BLOCKER:** Prevents all work
- **CRITICAL:** Blocks implementation
- **HIGH:** Significant issue
- **MEDIUM:** Should be addressed
- **LOW:** Nice-to-have
- **FUTURE:** Defer to later version
```

### Adding Custom Categories
```markdown
**Categories:**
- Compilation / Logic / Data / Architecture / Testing
- Documentation / Performance / Security / UX
- Accessibility (custom)
- I18n (custom)
- Privacy (custom)
```

### Adding Automated Checks
```markdown
**Automated Checks:**
- [ ] CI/CD pipeline passed
- [ ] Code coverage ≥ 80%
- [ ] flutter analyze clean
- [ ] flutter test passing
```

---

## 💡 Best Practices

### DO:
- ✅ **Use templates consistently** - Helps everyone know where to find things
- ✅ **Fill all placeholders** - No `[brackets]` left in final docs
- ✅ **Version documents** - v1, v2, v3 for iterative feedback
- ✅ **Link related docs** - Cross-reference for context
- ✅ **Update status** - Keep "Status" field current
- ✅ **Get sign-offs** - Don't skip the approval step

### DON'T:
- ❌ **Skip templates** - Ad-hoc docs get messy and inconsistent
- ❌ **Mix purposes** - Don't use review template for validation
- ❌ **Create one-off files** - Stick to naming conventions
- ❌ **Archive too early** - Confirm team is done first
- ❌ **Forget to version** - Always use v1, v2, v3 for reviews/validations
- ❌ **Leave incomplete** - Finish all sections before sharing

---

## 📁 File Naming Conventions

### Phase Planning
```
✅ phase-03-plan-v1.md, v2.md, v3.md
✅ phase-03A-plan.md (Group A: 3.1-3.3)
✅ phase-03B-plan.md (Group B: 3.4-3.5)
```

### Reviews
```
✅ phase-03A-review-v1.md, v2.md, v3.md
✅ Mark final: "Status: ✅ FINAL - Ready for Implementation"
```

### Validations
```
✅ phase-3.1-validation-v1.md, v2.md
✅ phase-3.2-validation-v1.md
✅ Mark final: "Status: ✅ FINAL - Phase 3.1 VALIDATED"
```

### Bug Hunting (Ongoing)
```
✅ codex-findings.md (one per phase, living doc)
✅ gemini-findings.md (one per phase, living doc)
✅ claude-findings.md (one per phase, living doc)
```

### Agent Validation (Post-Implementation)
```
✅ codex-validation.md (one per validation cycle)
✅ gemini-validation.md (one per validation cycle)
```

### Implementation Reports
```
✅ phase-3.1-implementation-report.md
✅ phase-3.2-implementation-report.md
```

### Phase Summary
```
✅ phase-03-summary.md (created at end of phase)
```

---

## 🔍 Finding Templates

**All templates are in:** `docs/templates/`

**Quick Links:**
- Review: [review-template.md](./review-template.md) + [review-template-about.md](./review-template-about.md)
- Validation: [validation-template.md](./validation-template.md) + [validation-template-about.md](./validation-template-about.md)
- Phase Start: [phase-start-checklist.md](./phase-start-checklist.md)
- Phase End: [phase-end-checklist.md](./phase-end-checklist.md)
- Build & Release: [build-and-release.md](./build-and-release.md)
- Documentation: [documentation-workflow.md](./documentation-workflow.md)
- Workflow: [WORKFLOW-SUMMARY.md](./WORKFLOW-SUMMARY.md)

**For Detailed Instructions:**
- Each template has an `-about.md` companion with full usage guide
- Read the "about" file first if you're new to a template

---

## 📞 Quick Help

**"I'm starting Phase 4, what do I do?"**
→ Use [phase-start-checklist.md](./phase-start-checklist.md)

**"I have a plan ready for review"**
→ Use [review-template.md](./review-template.md)

**"Implementation is done, need validation"**
→ Use [validation-template.md](./validation-template.md)

**"Ready to build a release version"**
→ Use [build-and-release.md](./build-and-release.md)

**"Need to update master documents"**
→ Use [documentation-workflow.md](./documentation-workflow.md)

**"Phase is complete, ready to close"**
→ Use [phase-end-checklist.md](./phase-end-checklist.md)

**"I'm confused about the workflow"**
→ Read [WORKFLOW-SUMMARY.md](./WORKFLOW-SUMMARY.md)

**"How do I give feedback?"**
→ Read [agent-feedback-guide.md](./agent-feedback-guide.md)

---

## 🆕 Real-World Examples

### Example 1: Phase 3.5 (What We Actually Did)

**What happened:**
- Created `phase-3.5-implementation-strategy.md` (plan)
- Created `gemini-review-day-2.md` (similar to review-template)
- Created `codex-review-day-2.md` (similar to review-template)
- Got findings: `gemini-findings-day-2.md`, `codex-findings-day-2.md`
- Fixed all issues: `gemini-fixes-summary.md`, `codex-fixes-summary.md`
- Completed: `day-2-complete.md` (similar to validation final status)

**How it maps to templates:**
- Planning → Could have used `review-template.md` for pre-implementation review
- Day 2 reviews → Similar to `review-template.md` structure
- Findings + fixes → Similar to `validation-template.md` cycles
- Completion → Similar to validation final sign-off

**Lessons learned:**
- ✅ Priority levels worked well (CRITICAL/HIGH/MEDIUM/LOW)
- ✅ Separate files for Gemini/Codex was clear
- 📋 Could consolidate into single validation doc per cycle
- 📋 Could use formal sign-off checklist

### Example 2: Future Phase Using Templates

**Ideal workflow for Phase 4.1:**
1. Start: Use `phase-start-checklist.md` → create `phase-04-plan-v1.md`
2. Refine: Iterate to `phase-04-plan-v3.md` (final)
3. Detail: Create `phase-04A-plan.md` for subphases 4.1-4.3
4. Review: Use `review-template.md` → `phase-04A-review-v1.md`
5. Team feedback → `phase-04A-review-v2.md` (FINAL, approved)
6. Implement: Write code, ongoing bug hunting in `codex-findings.md`
7. Validate: Use `validation-template.md` → `phase-4.1-validation-v1.md`
8. Fix cycle → `phase-4.1-validation-v2.md` (FINAL, validated)
9. Document: Create `phase-4.1-implementation-report.md`
10. Repeat for 4.2, 4.3
11. Close: Use `phase-end-checklist.md` → create `phase-04-summary.md` → archive

---

## 📚 Template Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-30 | Initial templates created based on Phase 3.1 learnings |
| 1.1 | 2025-01-05 | Added README.md based on Phase 3.5 experience |
| 1.2 | 2026-01-06 | Added manual-test-plan-template.md with checkbox legend system |
| 1.3 | 2026-01-22 | Added codex-validation-template.md and gemini-validation-template.md for post-implementation validation |

---

## 🤝 Contributing

**Found a template issue or have suggestions?**
- Update the template
- Update the companion `-about.md` file
- Update this README if workflow changes
- Document in template version history

**Maintain consistency:**
- Keep templates simple and focused
- Provide clear examples
- Link related documents
- Update all related docs when making changes

---

---

## 🧪 Manual Test Plan Template (NEW!)

**File:** [manual-test-plan-template.md](./manual-test-plan-template.md)

**Use When:**
- ✅ Need structured manual testing for a feature
- ✅ Validating complex UI/UX behavior
- ✅ Testing features that are hard to automate
- ✅ Device-specific testing (phone, tablet, desktop)

**Don't Use When:**
- ❌ Can be fully covered by unit/widget tests
- ❌ Simple bug fixes (use findings docs)

**Key Features:**
- Legend with checkbox meanings (`[ ]`, `[X]`, `[0]`, `[/]`, `[NA]`)
- Pre-test setup checklist
- Test sections with sub-steps
- Expected vs Actual results sections
- Screenshot placeholders
- Performance testing template
- Regression testing checklist
- Edge case testing
- Final sign-off section

**Legend System:**
```markdown
- [ ] : Pending
- [X] : Completed successfully
- [0] : Failed
- [/] : Neither successful nor failure
- [NA] : Not applicable

** : Notes appended with asterisks
```

**Example Usage:**
```bash
# Create manual test plan for Phase 3.5 tagging
cp docs/templates/manual-test-plan-template.md \
   docs/phase-03/phase-3.5-manual-test-plan.md

# Fill out test cases, give to BlueKitty for testing
# BlueKitty marks checkboxes and adds notes with **
# Review results and address any [0] failures
```

**Real Example:**
- `docs/phase-03/phase-3.5-manual-test-plan.md` - Phase 3.5 tagging system
- `docs/phase-03/phase-3.5-fix-c3-manual-test-plan.md` - Fix #C3 hierarchy testing

**Process:**
1. Copy template to phase directory
2. Customize test scenarios for your feature
3. Tester fills in checkboxes during testing
4. Tester adds notes with `**` for observations
5. Review results and fix any `[0]` failures
6. Re-test until all pass `[X]`

---

**Maintained By:** BlueKitty + Claude
**Questions?** Check the `-about.md` files for detailed usage instructions!
