# Gemini Review Prompt - Phase 3.6B Plan

**Date:** 2026-01-11
**Task:** Pre-implementation review of Phase 3.6B Universal Search plan
**Document to Review:** `docs/phase-3.6B/phase-3.6B-plan-v2.md`
**Feedback Location:** `docs/phase-3.6B/phase-3.6B-review-v1.md` (Gemini's Feedback section)

---

## Your Mission

Review the Phase 3.6B Universal Search implementation plan for **technical correctness and feasibility** before implementation begins.

This is a **pre-implementation review** - no code has been written yet. Focus on catching issues in the *plan* that would cause problems during implementation.

---

## What You're Reviewing

**Phase 3.6B: Universal Search**
- Comprehensive search across active + completed tasks
- Fuzzy matching with `string_similarity` package
- Match highlighting in results
- Relevance scoring and sorting
- Search dialog with tag selector
- Database indexes (migration v7)
- Search state persistence

**Timeline:** 8-11 days (1.5-2 weeks)
**Complexity:** Medium-High
**New Dependencies:** `string_similarity ^2.0.0`

---

## Review Instructions

### 1. Read the Plan Thoroughly

**Location:** `docs/phase-3.6B/phase-3.6B-plan-v2.md`

**Key sections to review:**
- Technical Approach (sections 1-7)
- Database Schema Changes (migration v7)
- SearchService implementation
- SearchDialog UI design
- Performance optimization strategy
- Testing strategy
- Timeline estimate

**Estimated reading time:** 30-45 minutes (1,181 lines)

---

### 2. Focus Areas for Gemini

#### **A. Database & SQL Correctness**
- Migration v7 syntax correct?
- Index creation statements valid?
- SQL queries syntactically correct?
- JOIN logic appropriate?
- WHERE clause conditions valid?
- Parameter binding correct?

#### **B. Flutter/Dart API Correctness**
- Widget structure valid?
- StatefulWidget lifecycle correct?
- Material Design widgets used properly?
- TextEditingController handling correct?
- Provider access patterns valid?
- Dialog navigation correct?

#### **C. Performance Feasibility**
- Index strategy appropriate for SQLite?
- Query optimization realistic?
- <100ms target achievable for 1000 tasks?
- Fuzzy matching performance concerns?
- Widget rebuild efficiency?

#### **D. Package Integration**
- `string_similarity` package usage correct?
- API calls accurate?
- Version constraint appropriate?
- Any known issues with package?

#### **E. Material Design Compliance**
- Dialog design follows Material guidelines?
- FilterChip usage correct?
- AppBar structure valid?
- Accessibility considerations?

---

### 3. What to Look For

**CRITICAL Issues:**
- SQL syntax errors that won't compile
- Flutter API misuse that will cause runtime errors
- Database schema conflicts
- Impossible performance targets
- Package API errors

**HIGH Priority:**
- Inefficient queries that will miss targets
- Poor widget structure (excessive rebuilds)
- Missing error handling
- Index strategy flaws
- Migration risks

**MEDIUM Priority:**
- Suboptimal approaches
- Missing edge cases
- Test coverage gaps
- UX issues

**LOW Priority:**
- Documentation clarity
- Code style suggestions
- Nice-to-have improvements

---

### 4. Provide Feedback

**Location:** Add your feedback to `docs/phase-3.6B/phase-3.6B-review-v1.md` in the "Gemini's Feedback" section.

**Use this format for each issue:**

```markdown
### [Priority] - [Category] - [Issue Title]

**Location:** [Section name or code example in plan-v2.md]

**Issue Description:**
[What's wrong with the plan?]

**Suggested Fix:**
[How should the plan be corrected?]

**Impact:**
[Why this matters - will it cause bugs, performance issues, etc.?]
```

**Priority Levels:**
- **CRITICAL:** Plan has fatal flaws, must fix before coding
- **HIGH:** Significant issues that should be addressed
- **MEDIUM:** Issues that can be worked around but should fix
- **LOW:** Minor improvements or documentation

**Categories:**
- **Compilation:** Code won't compile as written
- **Logic:** Incorrect algorithm or approach
- **Data:** Database/query issues
- **Architecture:** Design problems
- **Performance:** Won't meet targets
- **Documentation:** Unclear or incomplete

---

### 5. Example Feedback

```markdown
### HIGH - Data - SQL Query Missing DISTINCT

**Location:** Section 2 "SearchService", _getCandidates() method SQL query

**Issue Description:**
The SQL query JOINs task_tags and tags tables but doesn't use DISTINCT. This will return duplicate tasks if a task has multiple matching tags.

**Current Code:**
\`\`\`sql
SELECT tasks.* FROM tasks
LEFT JOIN task_tags ON tasks.id = task_tags.task_id
LEFT JOIN tags ON task_tags.tag_id = tags.id
WHERE [conditions]
\`\`\`

**Suggested Fix:**
Add DISTINCT keyword:
\`\`\`sql
SELECT DISTINCT tasks.* FROM tasks
LEFT JOIN task_tags ON tasks.id = task_tags.task_id
LEFT JOIN tags ON task_tags.tag_id = tags.id
WHERE [conditions]
\`\`\`

**Impact:**
Without DISTINCT, search results will have duplicates, breaking relevance scoring and confusing users. This is a logical error that would manifest as a bug immediately.
```

---

### 6. Areas of Special Focus

**BlueKitty's Feedback Changes:**
The plan was updated based on user feedback. Review these changes carefully:
- Search persistence (session storage, not clearing on dialog close)
- Tag filter integration (optional/explicit, not automatic)
- Default scope = "Current" (not "All tasks")
- "Clear All" button functionality
- Tag selector UI with "Apply active tags" + "Add tags" buttons

**New Complexity:**
- Search state save/restore logic
- TagSelectionDialog integration
- Session storage in TaskProvider
- Tag chip display with FutureBuilder

**Ask yourself:**
- Are these changes implemented correctly in the plan?
- Any additional complexity or edge cases?
- Performance implications of FutureBuilders?

---

### 7. Sign-Off Checklist

Before signing off, verify:
- [ ] Read entire plan-v2.md (all 1,181 lines)
- [ ] Reviewed all code examples for correctness
- [ ] Checked SQL queries for syntax and logic
- [ ] Verified Flutter/Dart API usage
- [ ] Assessed performance targets
- [ ] Reviewed database migration approach
- [ ] Checked package integration
- [ ] Added all feedback to review-v1.md
- [ ] Categorized issues by priority
- [ ] Provided concrete fix suggestions

**Only sign off if you're confident the plan is technically sound or all issues are documented.**

---

### 8. Timeline

**Suggested time budget:**
- Reading plan: 30-45 minutes
- Detailed review: 1-2 hours
- Writing feedback: 30-60 minutes
- **Total:** 2-4 hours

**Don't rush!** Finding issues now prevents bugs during implementation.

---

## Questions to Consider

1. **Will this code actually compile and run?**
2. **Are the SQL queries syntactically correct?**
3. **Will the performance targets be met?**
4. **Are there obvious bugs in the logic?**
5. **Are Flutter widgets used correctly?**
6. **Is the database migration safe?**
7. **Will the `string_similarity` package work as described?**
8. **Are there missing error cases?**
9. **Will this work on Linux AND Android?**
10. **Are there simpler/better approaches?**

---

## Success Criteria

**Your review is complete when:**
- You've thoroughly read the entire plan
- You've checked all code examples
- You've verified SQL syntax
- You've assessed performance feasibility
- You've documented all issues in review-v1.md
- You've provided concrete fix suggestions
- You've signed off (or documented blocking issues)

---

## After Your Review

Once you complete your review:
1. Update `review-v1.md` with all your feedback
2. Fill in the "Summary of Issues Found" table
3. Sign off in the "Sign-Off" section if approved
4. If blocking issues: Mark them CRITICAL and explain what blocks approval

Claude will then address all feedback and create plan-v3 if needed, or proceed to Codex review if minor fixes only.

---

**Thank you for your thorough review!** 🙏

Finding issues now prevents implementation delays and bugs later.

**Start your review:** Open `docs/phase-3.6B/phase-3.6B-plan-v2.md` and begin reading!
