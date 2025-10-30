# [Feature/Phase Name] Implementation Review

**Date:** [YYYY-MM-DD]
**Status:** Ready for team review (Round [X])
**Previous Round:** [Link to previous feedback file if applicable]

---

## Context

[Brief description of what is being reviewed - implementation plan, architectural decision, design document, etc.]

**Changes Since Last Review (if applicable):**
1. [List major changes or fixes applied]
2. [...]
3. [...]

**New Decisions/Additions:**
- [Any new architectural decisions or scope changes]
- [...]

---

## Review Instructions

Please review [document name/files] with focus on:

1. **Completeness:** Are all implementation details sufficient?
2. **Correctness:** Are the code examples, logic, and technical details sound?
3. **Clarity:** Is the plan easy to follow for implementation?
4. **Consistency:** Does everything align with architectural decisions and existing codebase?
5. **Testing:** Are test strategies comprehensive enough?

**Out of Scope for This Review:**
- [List items explicitly out of scope]
- [...]

---

## Feedback Template

Please use the following format for feedback:

### [Priority Level] - [Category] - [Issue Title]

**Location:** [File:line-number or section reference]

**Issue Description:**
[Clear description of the problem or concern]

**Suggested Fix:**
[Specific recommendation or code example]

**Impact:**
[Why this matters - compilation error, logic bug, performance issue, etc.]

---

**Priority Levels:**
- **CRITICAL:** Blocks implementation, must fix before proceeding
- **HIGH:** Significant issue that should be fixed soon
- **MEDIUM:** Should be addressed but can be worked around
- **LOW:** Nice-to-have improvement or documentation clarification

**Categories:**
- **Compilation:** Code won't compile as written
- **Logic:** Incorrect algorithm or business logic
- **Data:** Database schema or query issues
- **Architecture:** Design or structure concerns
- **Testing:** Test coverage or strategy gaps
- **Documentation:** Clarity or completeness issues
- **Performance:** Efficiency concerns
- **Security:** Security vulnerabilities or concerns
- **UX:** User experience issues

---

## Feedback Collection

### [Reviewer 1]'s Feedback

**Status:** Pending review

*([Reviewer 1]: Please add your feedback here)*

---

### [Reviewer 2]'s Feedback

**Status:** Pending review

*([Reviewer 2]: Please add your feedback here)*

---

### [Reviewer 3]'s Feedback

**Status:** Pending review

*([Reviewer 3]: Please add your feedback here)*

---

### [Additional Notes]

**Status:** [As needed]

*([Add any additional notes or concerns here])*

---

## Summary of Issues Found (Round [X])

**To be filled after reviews:**

| Priority | Category | Count | Examples |
|----------|----------|-------|----------|
| CRITICAL | - | 0 | - |
| HIGH | - | 0 | - |
| MEDIUM | - | 0 | - |
| LOW | - | 0 | - |

**Total Issues:** 0

---

## Action Items

**To be created after reviews:**

- [ ] **[PRIORITY]** - [Issue title] - [Owner]
- [ ] **[PRIORITY]** - [Issue title] - [Owner]

---

## Sign-Off

Once all feedback is addressed, each reviewer will sign off here:

- [ ] **[Reviewer 1]:** [Plan/Feature] approved for implementation
- [ ] **[Reviewer 2]:** [Plan/Feature] approved for implementation
- [ ] **[Reviewer 3]:** [Plan/Feature] approved for implementation
- [ ] **[Project Lead]:** [Plan/Feature] approved for implementation

---

## Next Steps After Sign-Off

1. [Next action item]
2. [Next action item]
3. [...]

---

**Review Deadline:** [Date or TBD]
**Document Owner:** [Name]
**Last Updated:** [YYYY-MM-DD]

---

## Template Usage Notes

**How to Use This Template:**

1. **Copy this file** and rename it for your specific review (e.g., `feature-name-review.md`)
2. **Replace all bracketed placeholders** `[like this]` with actual content
3. **Customize reviewer sections** - add/remove as needed for your team size
4. **Add to feedback template** - Add any project-specific priority levels or categories
5. **Update regularly** - Keep the summary table and action items current as reviews come in

**Template Features:**

- ✅ **Structured feedback format** - Ensures consistent, actionable feedback
- ✅ **Priority levels** - Helps triage issues by urgency
- ✅ **Category tags** - Makes it easy to group and track similar issues
- ✅ **Voting/sign-off section** - Clear consensus tracking
- ✅ **Summary tables** - Quick overview of review status
- ✅ **Action items checklist** - Track fixes and follow-ups

**Best Practices:**

- Keep feedback **specific and actionable** (include line numbers, code examples)
- Use **priority levels consistently** across all reviewers
- **Update the summary table** as feedback comes in (don't wait until the end)
- **Link to relevant docs** when referencing architectural decisions
- **Create follow-up issues** for items that need tracking beyond the review

**Example Feedback Entry:**

```markdown
### HIGH - Logic - Task depth calculation incorrect for nested hierarchies

**Location:** `task_service.dart:245-260`

**Issue Description:**
The current depth calculation only works for one level of nesting. For a task structure like:
- Parent (depth 0)
  - Child (depth 1)
    - Grandchild (should be depth 2, but shows as depth 1)

The recursive query doesn't properly increment depth for grandchildren.

**Suggested Fix:**
Update the recursive CTE to properly track depth:
\`\`\`sql
WITH RECURSIVE task_tree AS (
  SELECT *, 0 as depth FROM tasks WHERE parent_id IS NULL
  UNION ALL
  SELECT t.*, tt.depth + 1 as depth  -- Add +1 here
  FROM tasks t
  JOIN task_tree tt ON t.parent_id = tt.id
)
\`\`\`

**Impact:**
UI will show incorrect indentation for deeply nested tasks, breaking the visual hierarchy.
```

---

**Created By:** BlueKitty + Claude
**Template Version:** 1.0
**Last Updated:** 2025-10-30
