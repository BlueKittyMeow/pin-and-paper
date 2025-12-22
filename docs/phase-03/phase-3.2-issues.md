# Phase 3.2 Issues & Questions

**Phase:** 3.2 - Task Nesting & Hierarchical UI
**Status:** Active
**Created:** 2025-12-22

---

## Purpose

Track specific issues, questions, and blockers encountered during Phase 3.2 implementation.

**Note:** General bugs across all phases are tracked in [phase-03-bugs.md](./phase-03-bugs.md).
This document is for Phase 3.2-specific issues only.

---

## Issue Format

```markdown
## Issue #N: [Brief Title]
**File:** path/to/file.dart:line
**Type:** [Bug / Question / Design Decision / Performance]
**Severity:** [Blocker / High / Medium / Low]
**Found:** [DATE]
**Status:** [Open / In Progress / Resolved]

**Description:**
[What's wrong or what needs clarification]

**Proposed Solution:**
[How to fix or options to consider]

**Resolution:**
[If resolved: what was done]
```

---

## Open Issues

*No open issues - 1 issue found and resolved*

---

## Resolved Issues

### Issue #1: New tasks disappear after app restart (ordering mismatch) ✅
**File:** pin_and_paper/lib/services/task_service.dart:99
**Type:** Bug
**Severity:** High
**Found:** 2025-12-22
**Resolved:** 2025-12-22

**Resolution:**
Changed `getAllTasks()` ordering from `ASC` to `DESC`:
```dart
orderBy: 'position DESC',  // Newest tasks (highest position) appear first
```

This ensures database query results match the in-memory ordering where new tasks are inserted at index 0. Now tasks consistently appear at the top of the list both during the session and after app restarts.

**Testing:** All 23 unit tests pass ✅
**Commit:** Pending

---

## Questions for Team

*None yet*

---

## Design Decisions Made

### 1. TreeController Integration
**Date:** 2025-12-22
**Decision:** Use flutter_fancy_tree_view2's built-in TreeController
**Rationale:** Provides expand/collapse state, efficient traversal, animations
**Impact:** Cleaner code, well-tested library

---

## Notes

- Issues found during implementation will be added here
- Consult group1.md for detailed specifications
- Coordinate with codex-findings.md and gemini-findings.md for general bugs
- Critical blockers should be escalated to BlueKitty immediately
