# Agent Prompts Cheat Sheet

Quick copy-paste prompts for requesting agent feedback with proper formatting.

---

## 🐛 Bug Hunting (Ongoing Implementation)

**For Codex:**
```
Codex, please review the Phase 3.2 implementation and add any bugs or issues
you find to docs/phase-03/codex-findings.md. Use this format:

## Issue: [Brief title]
**File:** path/to/file.dart:line
**Type:** Bug / Performance / Architecture
**Found:** 2025-12-22

**Description:**
[What's wrong and why it's a problem]

**Suggested Fix:**
[Specific recommendation]

**Impact:** High / Medium / Low
```

**For Gemini:**
```
Gemini, please review the Phase 3.2 implementation and add any bugs or issues
you find to docs/phase-03/gemini-findings.md. Use the same format as Codex's
findings: Issue title, File, Type, Found, Description, Suggested Fix, Impact.
```

---

## 📋 Pre-Implementation Review

**For detailed spec review:**
```
[Agent Name], please review docs/phase-03/phase-3.2-implementation.md and
provide feedback in docs/phase-03/phase-3.2-review-v1.md.

Use this format:

### [SEVERITY] - [Category] - [Issue Title]
**Location:** file.md:line or section
**Issue Description:** [Clear problem description]
**Suggested Fix:** [Specific recommendation]
**Impact:** [Why it matters]

Severity: CRITICAL / HIGH / MEDIUM / LOW
Category: Compilation / Logic / Data / Architecture / Testing / Documentation / Performance

Focus on: completeness, correctness, clarity, consistency, testing strategy.
```

---

## 🔍 Linting Analysis

**For flutter analyze reports:**
```
Gemini, please run `flutter analyze` and report issues in
docs/phase-03/phase-3.2-linting.md.

Format:
# Phase 3.2 Linting Issues
**Total Issues:** N
**By Category:** Style (N), Deprecated (N), Async (N)

## Detailed List
### `path/to/file.dart`
1. **info:** Description. (`lint_rule_name`)
   - **Location:** file.dart:line
```

---

## 💬 Quick Inline Feedback

**For planning doc comments:**
```
[Agent Name], please review [doc name] (lines X-Y) and provide quick feedback
using bullet points:

*   **Major Issue:** [Description]
    - *[Your Name]*

*   **Medium Issue:** [Description]
    - *[Your Name]*

Include severity (Major/Medium/Minor) and sign with your agent name.
```

---

## 🔄 Cross-Validation

**For reviewing another agent's findings:**
```
Gemini, please review Codex's findings in docs/phase-03/codex-findings.md
and add your thoughts to the bottom using:

---
## Gemini's thoughts on Codex's feedback

*   Regarding [issue name]: [Agreement/disagreement + reasoning]
    - *Gemini*
```

---

## 📝 Implementation Report

**For documenting completed work:**
```
Claude, please create a Phase 3.2 implementation report in
docs/phase-03/phase-3.2-implementation-report.md covering:

- What was implemented
- Technical decisions made
- Files modified/created
- Metrics (LOC, tests, commits)
- Known issues
- Lessons learned

Use the Phase 3.1 implementation report as a template.
```

---

## 🧪 Test Coverage Review

**For test analysis:**
```
[Agent Name], please review test coverage for Phase 3.2 and report in
docs/phase-03/phase-3.2-test-coverage.md:

- List all test files
- Coverage by component (Services, Providers, Widgets)
- Missing test scenarios
- Suggested additional tests (prioritized)
```

---

## 📊 Full Phase Review

**For comprehensive review before merging:**
```
Team (Gemini, Codex), Phase 3.2 is complete. Please perform a comprehensive
review and provide feedback in your respective findings docs:

1. Code quality and architecture
2. Test coverage
3. Documentation completeness
4. Performance considerations
5. Edge cases and error handling
6. Future maintenance concerns

Use standard finding format. Prioritize HIGH/CRITICAL issues.
```

---

## Quick Copy-Paste Examples

### Standard Bug Finding
```
## Issue: [Title]
**File:** path/file.dart:123
**Type:** Bug
**Found:** 2025-12-22

**Description:**


**Suggested Fix:**


**Impact:** High
```

### Standard Review Item
```
### HIGH - Logic - [Title]
**Location:** file.md:100-120

**Issue Description:**


**Suggested Fix:**


**Impact:**

```

### Standard Inline Feedback
```
*   **Major Issue:** [Description]
    - *Gemini*
```

---

**Updated:** 2025-12-22
**Reference:** See agent-feedback-guide.md for detailed format documentation
