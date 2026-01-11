# Phase 3.6B Universal Search - Implementation Review

**Date:** 2026-01-11
**Status:** Ready for team review (Round 1)
**Previous Round:** N/A (Initial review)

---

## For Reviewers: How to Provide Feedback

1. **Read** the review instructions and scope below
2. **Review** `phase-3.6B-plan-v2.md` (1,181 lines - comprehensive technical plan)
3. **Add your feedback** in your designated section using the feedback template format
4. **Use priority levels** (CRITICAL/HIGH/MEDIUM/LOW) and categories consistently
5. **Be specific** - include section references, code examples, and concrete suggestions
6. **Sign off** when all your concerns are addressed

See the **Feedback Template** section below for the exact format to use.

---

## Context

**What is being reviewed:** Phase 3.6B Universal Search implementation plan (v2)

**Scope:** Comprehensive universal search feature to complement Phase 3.6A tag filtering system.

**Document to Review:** `docs/phase-3.6B/phase-3.6B-plan-v2.md`

**Key Features:**
- Search dialog UI with magnifying glass icon
- Fuzzy matching with `string_similarity` package
- Match highlighting in results
- Relevance scoring and sorting
- Grouped results (Active/Completed sections)
- Hierarchy breadcrumb display
- Database indexes for performance (<100ms for 1000 tasks)
- Filter checkboxes (All/Current/Recently completed/Completed)
- Integration with Phase 3.6A tag filters

**Changes Since Last Review:**
- N/A (Initial review - v1 was too simple, v2 is comprehensive rewrite)

**New Decisions/Additions:**
- Database migration v7 for search indexes (`idx_tasks_title`, `idx_tasks_notes`)
- Two-stage filtering approach (SQL LIKE + Dart fuzzy matching)
- Weighted relevance scoring (title 60%, notes 30%, tags 10%)
- `SearchService` class for search logic
- `SearchDialog` full-screen Material Design dialog
- `SearchResultTile` with RichText highlighting
- Integration with existing `FilterState` from Phase 3.6A

**Timeline:** 7-10 days (1-2 weeks)
**Complexity:** Medium-High (database indexes, fuzzy matching, highlighting)

---

## Review Instructions

Please review **`phase-3.6B-plan-v2.md`** with focus on:

### 1. **Database & Performance**
- Migration v7 strategy (adding indexes)
- SQL query correctness and efficiency
- Index effectiveness for search performance
- Performance target feasibility (<100ms for 1000 tasks)
- Two-stage filtering approach (SQL + Dart)

### 2. **Search Algorithm**
- Fuzzy matching implementation with `string_similarity`
- Relevance scoring algorithm (weighted 60/30/10)
- Match position finding for highlighting
- Handling of edge cases (unicode, emojis, special chars)

### 3. **UI/UX Design**
- SearchDialog component structure
- Filter chip selection UX
- Results grouping (Active/Completed)
- Navigation and highlighting behavior
- Integration with HomeScreen app bar

### 4. **Integration Points**
- Phase 3.6A tag filter integration
- FilterState compatibility
- TaskProvider navigation methods
- Existing task hierarchy display

### 5. **Code Architecture**
- SearchService class design
- SearchResult, SearchScope models
- Widget structure (Dialog, Tile, Highlighting)
- Separation of concerns

### 6. **Testing Strategy**
- Unit test coverage (search, scoring, matching)
- Widget test coverage (dialog, tiles)
- Integration test scenarios
- Performance test approach
- Manual test plan completeness

### 7. **Technical Details**
- Dart/Flutter API usage correctness
- SQLite query syntax
- Material Design pattern adherence
- Error handling approach

**Out of Scope for This Review:**
- Phase 3.6.5 Edit Task Modal Rework (separate phase)
- Advanced search syntax (deferred to future)
- Search history/suggestions (deferred to future)
- Voice search (deferred to future)

---

## Feedback Template

Please use the following format for feedback:

### [Priority Level] - [Category] - [Issue Title]

**Location:** [Section name or line reference in plan-v2.md]

**Issue Description:**
[Clear description of the problem or concern]

**Suggested Fix:**
[Specific recommendation or alternative approach]

**Impact:**
[Why this matters - performance issue, architectural concern, etc.]

---

**Priority Levels:**
- **CRITICAL:** Blocks implementation, must fix before proceeding
- **HIGH:** Significant issue that should be fixed before coding
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

### Gemini's Feedback

**Status:** Pending review

**Instructions for Gemini:**
- Review `phase-3.6B-plan-v2.md` thoroughly
- Focus on: Database queries, Flutter/Dart API correctness, performance concerns
- Check: SQL syntax, widget structure, Material Design patterns
- Verify: Migration strategy, index effectiveness, query optimization
- Look for: Edge cases, potential bugs, missing error handling

*(Gemini: Please add your feedback below using the template format)*

---

### Codex's Feedback

**Status:** Pending review

**Instructions for Codex:**
- Review `phase-3.6B-plan-v2.md` thoroughly
- Focus on: Code architecture, algorithm correctness, integration points
- Check: SearchService design, fuzzy matching logic, highlighting implementation
- Verify: Phase 3.6A integration, FilterState compatibility, navigation approach
- Look for: Architectural issues, missing edge cases, test gaps

*(Codex: Please add your feedback below using the template format)*

---

### BlueKitty's Feedback

**Status:** Pending review

**Instructions for BlueKitty:**
- Review `phase-3.6B-plan-v2.md` for overall direction and UX
- Check: Scope alignment with PROJECT_SPEC.md requirements
- Verify: Feature completeness, timeline reasonableness
- Review: Open questions (need answers before implementation)
- Confirm: This matches your vision for universal search

*(BlueKitty: Please add your feedback below using the template format)*

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

## Key Sections to Review in plan-v2.md

**Must Review:**
1. **Technical Approach** (Section 1-7) - Core architecture decisions
2. **Database Schema Changes** - Migration v7 indexes
3. **Search Service Layer** - SearchService class implementation
4. **Search Dialog UI** - SearchDialog widget structure
5. **Search Result Tile with Highlighting** - Highlighting logic
6. **Integration with Phase 3.6A Tag Filters** - FilterState compatibility
7. **Performance Optimization** - Index strategy, query optimization
8. **Testing Strategy** - All test types and coverage
9. **Timeline Estimate** - Day-by-day breakdown (7-10 days)
10. **Success Criteria** - 18 completion checkpoints

**Important Details:**
- **Dependencies:** `string_similarity ^2.0.0` (new package)
- **Performance Target:** <100ms for 1000 tasks (PROJECT_SPEC requirement)
- **Integration:** Combines with Phase 3.6A tag filters seamlessly
- **Database:** Migration v7 adds 2 indexes (title, notes)

**Open Questions (need answers):**
- Search query persistence (clear on close vs preserve)
- Recently completed timeframe (30 days?)
- Search scope default (All vs Current)
- Minimum query length (search immediately vs require 2-3 chars)
- Tag filter visibility in dialog
- Match highlighting color (yellow?)
- Navigation behavior (close dialog on tap?)

---

## Sign-Off

Once all feedback is addressed, each reviewer will sign off here:

- [ ] **Gemini:** Phase 3.6B plan approved for implementation
- [ ] **Codex:** Phase 3.6B plan approved for implementation
- [ ] **BlueKitty:** Phase 3.6B plan approved for implementation

**All sign-offs required before implementation begins.**

---

## Next Steps After Sign-Off

1. Address all feedback from Round 1
2. Create plan-v3.md if significant changes needed, OR
3. Update plan-v2.md with minor fixes and clarifications
4. If new round needed: Create review-v2.md for re-review
5. Once all sign off: Initialize bug hunting docs (codex-findings.md, gemini-findings.md, claude-findings.md)
6. Begin implementation (Day 1: Database migration + SearchService)

---

## Review Timeline

**Review Deadline:** TBD (suggest: 2-3 days for thorough review)
**Document Owner:** Claude
**Last Updated:** 2026-01-11

---

**Comparison to Phase 3.6A:**
- **Phase 3.6A:** Tag filtering (simpler, no new dependencies, <1 week)
- **Phase 3.6B:** Universal search (complex, fuzzy matching, 1-2 weeks)
- **Why review matters:** Higher complexity = higher risk of architectural issues

**Template Version:** 1.0
**See also:** `docs/templates/review-template-about.md` for detailed instructions
