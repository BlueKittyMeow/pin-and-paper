# Phase 3.3 (Recently Deleted) Implementation Plan Review

**Date:** 2025-12-27
**Status:** Ready for team review (Round 1)
**Previous Round:** N/A (First review of Phase 3.3 planning)

---

## For Reviewers: How to Provide Feedback

1. **Read** the review instructions and scope below
2. **Add your feedback** in your designated section using the feedback template format
3. **Use priority levels** (CRITICAL/HIGH/MEDIUM/LOW) and categories consistently
4. **Be specific** - include line numbers, code examples, and concrete suggestions
5. **Sign off** when all your concerns are addressed

See the **Feedback Template** section below for the exact format to use.

---

## Context

This review covers the **Phase 3.3 implementation planning documents** for the "Recently Deleted" (soft delete) feature. Phase 3.3 adds a safety net to prevent accidental data loss by implementing soft delete with 30-day auto-cleanup, similar to iOS/Android trash functionality.

**Documents Under Review:**
1. `docs/phase-03/phase-3.3-implementation.md` (600 lines) - Main implementation plan
2. `docs/phase-03/phase-3.3-test-plan.md` (500 lines) - Comprehensive test plan
3. `docs/phase-03/phase-3.3-ultrathinking.md` (900 lines) - Technical deep dive

**What Phase 3.3 Implements:**
- Database migration v4 → v5 (add `deleted_at` column)
- Soft delete with CASCADE (manual implementation, not FK-based)
- Restore functionality with CASCADE
- Recently Deleted screen in Settings
- Automatic cleanup of tasks older than 30 days
- Badge count on Settings menu item

**Key Technical Decisions:**
- Timestamp `deleted_at` instead of boolean (enables "deleted X days ago" display)
- Iterative breadth-first CASCADE (simpler than recursive CTE)
- Dual index strategy (general + partial for active tasks)
- Query filtering: all existing queries updated with `WHERE deleted_at IS NULL`
- Cleanup runs on app launch (async, non-blocking)

---

## Review Instructions

Please review the Phase 3.3 planning documents with focus on:

1. **Completeness:** Are all implementation details sufficient for implementation?
2. **Correctness:** Are the database schema changes, SQL queries, and logic sound?
3. **Clarity:** Can this plan be followed to build the feature?
4. **Consistency:** Does it align with Phase 3.2 architecture and existing patterns?
5. **Testing:** Is the test strategy comprehensive enough?
6. **Edge Cases:** Are potential issues identified and mitigated?

**Specific Areas to Scrutinize:**
- Database migration v4 → v5 safety and rollback plan
- Soft delete CASCADE implementation (iterative approach in ultrathinking.md)
- Query performance impact with `deleted_at IS NULL` filters
- Index strategy (partial vs. full indexes)
- Edge cases: orphaned children, restore conflicts, circular references
- Automatic cleanup timing and safety
- Memory management with TreeController (Phase 3.2 integration)

**Out of Scope for This Review:**
- Phase 3.2 code review (already completed)
- UI/UX design mockups (implementation will follow patterns)
- Phase 3.4+ planning
- Detailed widget implementation (covered in implementation phase)

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

### Codex's Feedback

**Status:** Pending review

**Review Focus:**
- Database migration safety and correctness
- SQL query syntax and performance
- Soft delete CASCADE logic implementation
- Index strategy effectiveness
- Edge case handling (orphans, circular refs)

*(Codex: Please add your feedback below using the template format)*

---

### Gemini's Feedback

**Status:** Pending review

**Review Focus:**
- Code compilation viability (can the SQL/Dart be implemented as-is?)
- Migration script correctness
- Query filtering completeness (did we catch all query methods?)
- Test coverage gaps
- Documentation clarity

*(Gemini: Please add your feedback below using the template format)*

---

### Claude's Self-Review

**Status:** Pending (will complete after team feedback)

**Review Focus:**
- Response to Codex/Gemini concerns
- Triage of issues (which to fix immediately vs. defer)
- Implementation sequence validation
- Risk assessment

*(Claude: To be completed after Codex and Gemini provide feedback)*

---

### Additional Notes

**Status:** As needed

*(Add any additional notes, questions for BlueKitty, or cross-cutting concerns here)*

---

## Summary of Issues Found (Round 1)

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

- [ ] **[PRIORITY]** - [Issue title] - [Owner: Claude]
- [ ] **[PRIORITY]** - [Issue title] - [Owner: Claude]

---

## Sign-Off

Once all feedback is addressed, each reviewer will sign off here:

- [ ] **Codex:** Phase 3.3 plan approved for implementation
- [ ] **Gemini:** Phase 3.3 plan approved for implementation
- [ ] **Claude:** Phase 3.3 plan approved for implementation
- [ ] **BlueKitty:** Phase 3.3 plan approved for implementation

---

## Next Steps After Sign-Off

1. Address all CRITICAL and HIGH priority feedback
2. Update planning documents with fixes
3. Begin Phase 3.3 implementation following the 10-phase sequence (ultrathinking.md)
4. Create Phase 3.3 test infrastructure (test database setup)
5. Implement database migration v4 → v5
6. Create pull request after initial implementation

---

## Reference Documents

**Planning Documents (Under Review):**
- `docs/phase-03/phase-3.3-implementation.md` - Main plan, database schema, file manifest
- `docs/phase-03/phase-3.3-test-plan.md` - 70+ test cases across all layers
- `docs/phase-03/phase-3.3-ultrathinking.md` - Deep dive, CASCADE strategy, edge cases

**Related Phase 3.2 Documents (For Context):**
- `archive/phase-03/phase-3.2-implementation.md` - Phase 3.2 summary (what we just built)
- `pin_and_paper/lib/services/task_service.dart` - Existing hierarchical methods
- `pin_and_paper/lib/services/database_service.dart` - Current schema (v4)

**Feature Request Origin:**
- User request: "Can we have a section for recently deleted tasks somewhere?"
- Tracked in: FEATURE_REQUESTS.md (commit 7640467)

---

**Review Deadline:** TBD (target: before implementation start)
**Document Owner:** Claude (planning), BlueKitty (approval)
**Last Updated:** 2025-12-27

---

**Template Version:** 1.0
**See also:** `docs/templates/review-template-about.md` for template management instructions
