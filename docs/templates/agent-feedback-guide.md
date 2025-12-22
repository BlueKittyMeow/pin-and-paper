# Agent Feedback & Findings Format Guide

**Purpose:** Standard formats for agent feedback, findings, and reviews
**Updated:** 2025-12-22
**For:** Gemini, Codex, Claude, and other AI agents

---

## Document Types

### 1. Ongoing Bug Findings (codex-findings.md, gemini-findings.md, claude-findings.md)

**When to use:** Continuous bug hunting during implementation
**Format:** Individual issue blocks

```markdown
## Issue: [Brief descriptive title]
**File:** path/to/file.dart:line-number
**Type:** [Bug / Performance / Architecture / Documentation]
**Found:** YYYY-MM-DD

**Description:**
[Clear explanation of what's wrong, including context and why it's a problem]

**Suggested Fix:**
[Specific recommendation with code examples if applicable]

**Impact:** [High / Medium / Low]
```

**Example:**
```markdown
## Issue: BuildContext reused after await in Brain Dump screen
**File:** pin_and_paper/lib/screens/brain_dump_screen.dart:86
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`Navigator.push` is awaited inside the Brain Dump app bar action and the callback continues to use `context` (`setState`, `context.read`, `Navigator.pop`) without guarding the async gap using `if (!context.mounted) return;`. If the widget unmounts while the awaited navigation/dialog is open, resuming the callback triggers `setState`/navigation on a disposed context, which will crash in release.

**Suggested Fix:**
After each `await` that yields (`Navigator.push`, `_showExitConfirmation`, `_saveDraft`), immediately check `if (!context.mounted) return;` (or restructure to capture providers before the `await` and store local references). This satisfies the lint and guarantees the widget is still mounted before touching `context`.

**Impact:** Medium
```

---

### 2. Pre-Implementation Reviews (phase-X.Y-review-vN.md)

**When to use:** Reviewing detailed specs before implementation starts
**Format:** Structured sections with severity levels

```markdown
# Phase X.Y Review - vN

**Reviewer:** [Agent Name]
**Date:** YYYY-MM-DD
**Status:** [Draft / Final]

---

## Phase X.Y: [Feature Name]

### [SEVERITY] - [Category] - [Issue Title]

**Location:** `file.md:line-number` or section reference

**Issue Description:**
[Clear description of the problem or concern]

**Suggested Fix:**
[Specific recommendation or code example]

**Impact:**
[Why this matters - compilation error, logic bug, performance issue, etc.]

---

**Severity Levels:**
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
```

**Example:**
```markdown
### HIGH - Logic - updateTaskParent lacks sibling reindexing

**Location:** `group1.md:1323-1344`, TaskService.updateTaskParent method

**Issue Description:**
`updateTaskParent` only updates the moved task's `parent_id`/`position` but never reindexes siblings in the destination list and does not guard against selecting one of the task's descendants as the new parent. That combination will create duplicated `position` values, undefined ordering, and allows cycles that break the recursive CTE.

**Suggested Fix:**
1. Add cycle detection: Query all descendants before allowing parent change
2. Resequence destination siblings: After insert, update all positions >= new position
3. Add transaction wrapper to ensure atomicity

**Impact:**
Will create data corruption and break hierarchical queries. Blocks Phase 3.2 drag-and-drop feature.
```

---

### 3. Linting/Analysis Reports (phase-X.Y-issues.md)

**When to use:** Reporting `flutter analyze` or linter output
**Format:** Numbered list with lint rule names

```markdown
# Phase X.Y Linting Issues

**Reported by:** [Agent Name]
**Date:** YYYY-MM-DD
**Status:** [Pending Review / In Progress / Resolved]

---

## Summary

**Total Issues:** N

### By Category:
- **Style (N):** `rule_name_1`, `rule_name_2`
- **Deprecated Members (N):** `deprecated_member_use`
- **Async Gaps (N):** `use_build_context_synchronously`

---

## Detailed Issue List

### `path/to/file.dart`
1. **[level]:** Description. (`lint_rule_name`)
   - **Location:** `path/to/file.dart:line`

2. **[level]:** Description. (`lint_rule_name`)
   - **Location:** `path/to/file.dart:line`
```

**Example:**
```markdown
### `lib/screens/settings_screen.dart`
10. **info:** `value` is deprecated and shouldn't be used. Use `initialValue` instead. (`deprecated_member_use`)
    - **Location:** `lib/screens/settings_screen.dart:185:29`
```

---

### 4. Quick Feedback (Inline in planning docs)

**When to use:** During iterative planning/review cycles
**Format:** Bullet points with severity prefix and attribution

```markdown
## Phase X.Y: [Feature Name]

*   **[Severity] Issue:** [Description of the problem]
    - *[Agent Name]*

*   **[Severity] Issue:** [Description of the problem]
    - *[Agent Name]*
```

**Example:**
```markdown
## Phase 3.1: Database Migration (v3 → v4)

*   **Major Issue:** There is a contradiction regarding the `due_date` column in the `tasks` table. The `group1.md` plan states that this column will be added during the v3 to v4 migration. However, the `PROJECT_SPEC.md` indicates that the `due_date` column was already part of the schema in Phase 1.
    - *Gemini*

*   **Medium Issue:** The testing plan for the `DateParserService` correctly identifies the need for mocking the system clock (`DateTime.now()`) but defers the implementation. Testing time-sensitive logic without a reliable way to control the clock will lead to flaky and inaccurate tests.
    - *Gemini*
```

---

## Severity/Priority Guidelines

### Impact Levels

**High:**
- Causes crashes or data loss
- Blocks critical functionality
- Security vulnerabilities
- Compilation errors

**Medium:**
- Degrades user experience
- Causes incorrect behavior in edge cases
- Performance issues
- Missing error handling

**Low:**
- Code style issues
- Documentation gaps
- Minor inefficiencies
- Nice-to-have improvements

---

## Example Prompts for BlueKitty

### For Ongoing Bug Hunting
```
Codex, please review the current Phase 3.2 implementation and add any bugs
or issues you find to docs/phase-03/codex-findings.md using the standard
format (Issue title, File, Type, Found, Description, Suggested Fix, Impact).
```

### For Pre-Implementation Review
```
Gemini, please review docs/phase-03/phase-3.2-implementation.md and provide
feedback in a new file docs/phase-03/phase-3.2-review-v1.md. Use the review
format with SEVERITY levels (CRITICAL/HIGH/MEDIUM/LOW) and categories
(Compilation/Logic/Data/Architecture/Testing/Documentation/Performance).
Focus on: completeness, correctness, clarity, consistency, and testing strategy.
```

### For Linting Analysis
```
Gemini, please run `flutter analyze` on the Phase 3.2 code and report any
issues in docs/phase-03/phase-3.2-linting.md using the numbered list format
with lint rule names, grouped by file.
```

### For Quick Inline Feedback
```
Codex and Gemini, please review the updated group1.md plan (lines 726-844)
and provide quick feedback using bullet points with severity levels
(Major Issue / Medium Issue / Minor Issue). Include your agent name
attribution at the end of each item.
```

---

## Cross-Validation

When reviewing another agent's findings, use this format:

```markdown
---
## [Agent Name]'s thoughts on [Other Agent]'s feedback

*   Regarding [issue summary]: [Agreement/disagreement with reasoning]
    - *[Agent Name]*

*   Regarding [issue summary]: [Additional context or alternative solution]
    - *[Agent Name]*
```

**Example:**
```markdown
## Gemini's thoughts on Codex's feedback

*   Regarding the `updateTaskParent` issues: I concur with Codex's analysis. The lack of sibling re-indexing and cycle detection are critical flaws that will lead to data corruption and application errors. The plan must be updated to include logic for both of these. This is a major issue.
    - *Gemini*
```

---

## Tips for Effective Feedback

1. **Be Specific:** Include exact line numbers, file paths, and code snippets
2. **Explain Impact:** Always describe WHY it matters (crashes, data loss, poor UX)
3. **Provide Solutions:** Don't just identify problems - suggest fixes
4. **Use Examples:** Show concrete code when recommending changes
5. **Consider Context:** Reference related issues or architectural decisions
6. **Prioritize Correctly:** HIGH = blocks work, MEDIUM = should fix, LOW = nice-to-have
7. **Stay Constructive:** Frame feedback as improvement opportunities
8. **Reference Docs:** Link to specs, project decisions, or other findings

---

**Template Version:** 1.0
**Last Updated:** 2025-12-22
**Maintained By:** BlueKitty + Claude
