# Implementation Review Template - Usage Guide

**For:** BlueKitty & Claude (Template Management)
**Companion File:** `review-template.md`
**Version:** 1.0
**Last Updated:** 2025-10-30

---

## Overview

This document explains how to **create, customize, and manage** implementation review documents using the `review-template.md` template. This is for **us** (BlueKitty and Claude) when setting up reviews - reviewers don't need this information.

**The review template provides:**
- ✅ Structured feedback format (Priority + Category + Issue)
- ✅ Priority levels (CRITICAL/HIGH/MEDIUM/LOW)
- ✅ Category tags (Compilation/Logic/Data/Architecture/Testing/etc.)
- ✅ Voting/sign-off section for team consensus
- ✅ Summary tables for issue tracking
- ✅ Action items checklist

---

## How to Create a Review Document

### Step 1: Copy the Template

```bash
# Copy the template to your target directory
cp docs/templates/review-template.md docs/phase-X/feature-name-review.md

# Or for secondary reviews:
cp docs/templates/review-template.md docs/phase-X/feature-name-secondary-feedback.md
```

### Step 2: Replace All Placeholders

Search for and replace all bracketed placeholders:

| Placeholder | Replace With | Example |
|-------------|--------------|---------|
| `[Feature/Phase Name]` | Actual feature name | Group 1 (Phase 3.1-3.3) |
| `[YYYY-MM-DD]` | Current date | 2025-10-30 |
| `[Round X]` | Review round number | Round 2 |
| `[document name/files]` | Files being reviewed | group1.md |
| `[Reviewer 1]`, `[Reviewer 2]`, etc. | Actual reviewer names | Gemini, Codex, Claude |
| `[Date or TBD]` | Deadline if known | TBD |
| `[Name]` | Document owner | BlueKitty |

**Tip:** Use find-and-replace (`Ctrl+H` in most editors) to quickly replace placeholders.

### Step 3: Customize Sections

**Context Section:**
- Add brief description of what's being reviewed
- List major changes since last review (if applicable)
- Note any new architectural decisions

**Review Instructions:**
- Keep the 5 standard focus areas (Completeness, Correctness, Clarity, Consistency, Testing)
- Add project-specific items if needed
- Be explicit about what's **out of scope**

**Reviewer Sections:**
- Add/remove reviewer sections based on team size
- Standard: Gemini, Codex, Claude, BlueKitty
- Can add "Additional Notes" section for general comments

**Sign-Off Section:**
- Match the number of sign-off items to reviewer sections
- Include project lead (BlueKitty) as final sign-off

### Step 4: Set Context

Add specific context at the top:
- What document(s) are being reviewed?
- Why is this review happening? (new feature, architectural change, bug fix)
- What changed since last review?
- Link to previous feedback round if applicable

### Step 5: Define Scope

Be **very clear** about what's in and out of scope:

**Good Example:**
```markdown
**Out of Scope for This Review:**
- Phase 3.4-3.5 details (Group 2 planning)
- UI/UX design specifics (focus on logic and data flow)
- Performance optimization beyond what's documented
```

**Bad Example:**
```markdown
**Out of Scope for This Review:**
- Other stuff
- Things not related to this
```

---

## Best Practices for Review Management

### Before Sending for Review

1. ✅ **All placeholders replaced** - No `[brackets]` remaining
2. ✅ **Context is clear** - Reviewer knows what they're reviewing and why
3. ✅ **Scope is explicit** - No ambiguity about what's in/out of scope
4. ✅ **Files are ready** - The document being reviewed is complete and committed
5. ✅ **Links work** - All cross-references to other docs are valid

### During Review

1. **Monitor incoming feedback** - Check the document regularly as reviewers add comments
2. **Update summary table** - As feedback comes in, update the issue count table
3. **Create action items** - Convert feedback into actionable tasks with owners
4. **Acknowledge feedback** - Respond to reviewers if clarification is needed

### After Review

1. **Address all feedback** - Create follow-up tasks for each issue
2. **Update the reviewed document** - Apply fixes and improvements
3. **Get sign-offs** - Confirm each reviewer approves the changes
4. **Archive the feedback** - Keep the review document for future reference

---

## Priority Levels Guide

Use these consistently across all reviews:

| Priority | When to Use | Example |
|----------|-------------|---------|
| **CRITICAL** | Code won't compile, blocks all progress, fundamental logic error | "SQL query has syntax error on line 245" |
| **HIGH** | Significant bug, incorrect algorithm, data corruption risk | "Depth calculation incorrect for nested tasks" |
| **MEDIUM** | Should fix but has workaround, performance concern, test gap | "Missing unit tests for edge case X" |
| **LOW** | Documentation improvement, minor optimization, nice-to-have | "Add code comment explaining why we use X" |

---

## Category Tags Guide

| Category | When to Use | Example Issues |
|----------|-------------|----------------|
| **Compilation** | Code won't compile as written | Syntax errors, type mismatches, undefined variables |
| **Logic** | Incorrect algorithm or business logic | Wrong calculations, missing edge cases, incorrect flow |
| **Data** | Database schema or query issues | SQL errors, missing indexes, schema inconsistencies |
| **Architecture** | Design or structure concerns | Separation of concerns, coupling issues, pattern misuse |
| **Testing** | Test coverage or strategy gaps | Missing tests, inadequate test cases, flaky tests |
| **Documentation** | Clarity or completeness issues | Missing docs, unclear explanations, outdated info |
| **Performance** | Efficiency concerns | N+1 queries, memory leaks, slow algorithms |
| **Security** | Security vulnerabilities or concerns | SQL injection, XSS, auth issues, data exposure |
| **UX** | User experience issues | Confusing flows, accessibility, poor error messages |

---

## Example: Complete Review Setup

Here's a complete example of setting up a review:

```bash
# 1. Copy template
cp docs/templates/review-template.md docs/phase-03/group2-review.md

# 2. Edit the file and replace:
# - Title: "Group 2 (Phase 3.4-3.5) Implementation Review"
# - Date: "2025-11-05"
# - Status: "Ready for team review (Round 1)"
# - Reviewers: Gemini, Codex, Claude, BlueKitty
# - Context: "Review of Group 2 implementation plan..."
# - Review instructions: Focus on voice input and notifications

# 3. Commit the review document
git add docs/phase-03/group2-review.md
git commit -m "docs: Create Group 2 implementation review (Round 1)"

# 4. Notify team (via chat/email/etc.)
# "Ready for review: docs/phase-03/group2-review.md"
```

---

## Template Features & Benefits

### Structured Feedback Format

**Problem it solves:** Inconsistent, unclear, or non-actionable feedback

**How it works:**
```markdown
### HIGH - Logic - Task depth calculation incorrect

**Location:** `task_service.dart:245-260`
**Issue Description:** [Clear problem statement]
**Suggested Fix:** [Concrete solution with code]
**Impact:** [Why this matters]
```

**Benefits:**
- Every issue is actionable
- Priority is clear
- Location is specific
- Impact is understood

### Voting/Sign-Off Section

**Problem it solves:** Unclear whether team has consensus

**How it works:**
```markdown
- [x] **Gemini:** Approved
- [x] **Codex:** Approved
- [x] **Claude:** Approved
- [ ] **BlueKitty:** Pending final review
```

**Benefits:**
- Clear consensus tracking
- Easy to see who's blocking/pending
- Forces explicit approval
- Creates accountability

### Summary Tables

**Problem it solves:** Hard to see overview of feedback at a glance

**How it works:**
```markdown
| Priority | Category | Count | Examples |
|----------|----------|-------|----------|
| CRITICAL | Logic    | 2     | Depth calc, cycle detection |
| HIGH     | Testing  | 3     | Missing edge case tests |
```

**Benefits:**
- Quick overview of feedback status
- Easy to prioritize fixes
- Helps track progress
- Great for status updates

---

## Customization Options

### Adding Custom Priority Levels

If your project needs additional priority levels:

```markdown
**Priority Levels:**
- **BLOCKER:** Prevents all work (more severe than CRITICAL)
- **CRITICAL:** Blocks implementation
- **HIGH:** Significant issue
- **MEDIUM:** Should be addressed
- **LOW:** Nice-to-have
- **FUTURE:** Good idea but not for this version
```

### Adding Custom Categories

If your project has specific concerns:

```markdown
**Categories:**
- **Compilation:** Code won't compile
- **Logic:** Incorrect algorithm
- **Data:** Database issues
- **Architecture:** Design concerns
- **Testing:** Test gaps
- **Documentation:** Clarity issues
- **Performance:** Efficiency concerns
- **Security:** Security issues
- **UX:** User experience issues
- **Accessibility:** A11y issues (custom)
- **I18n:** Internationalization concerns (custom)
- **Privacy:** Privacy/GDPR concerns (custom)
```

### Adding Review Stages

For complex reviews with multiple stages:

```markdown
## Review Stages

**Stage 1: Architecture Review** (Week 1)
- Focus: High-level design, data flow, technology choices
- Reviewers: Gemini, Claude

**Stage 2: Implementation Detail Review** (Week 2)
- Focus: Code examples, SQL queries, algorithms
- Reviewers: Codex, Claude

**Stage 3: Testing Strategy Review** (Week 3)
- Focus: Test coverage, test cases, edge cases
- Reviewers: All team
```

---

## Tips & Tricks

### Quick Issue Entry

Create a snippet in your editor for fast issue entry:

```markdown
### [PRIORITY] - [CATEGORY] - [TITLE]

**Location:** `file.dart:[LINE]`

**Issue Description:**
[DESCRIPTION]

**Suggested Fix:**
[FIX]

**Impact:**
[IMPACT]
```

### Tracking Progress

Use GitHub issues or project boards to track action items from reviews:

```bash
# Create GitHub issues from review feedback
gh issue create --title "HIGH - Fix task depth calculation" \
  --body "From group1-review.md: task_service.dart:245-260..." \
  --label "bug,high-priority"
```

### Review Checklist

Keep this checklist for every review:

- [ ] Context section filled out
- [ ] All placeholders replaced
- [ ] Reviewer sections customized
- [ ] Scope clearly defined
- [ ] Document being reviewed is ready
- [ ] Team notified review is ready
- [ ] Summary table updated as feedback comes in
- [ ] Action items created from feedback
- [ ] All feedback addressed
- [ ] Sign-offs collected
- [ ] Review document archived

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-30 | Initial template based on group1-secondary-feedback.md success |

---

## Related Documents

- `review-template.md` - The actual template (what reviewers see)
- Example: `docs/phase-03/group1-secondary-feedback.md` - Real usage example
- Architectural decisions: `docs/brain-dump-date-parsing-options.md` - Shows voting pattern

---

**Maintained By:** BlueKitty + Claude
**Questions?** Update this document with new learnings as we use the template!
