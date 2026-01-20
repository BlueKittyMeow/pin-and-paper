# Codex Review Prompt - Phase 3.6B Plan

**Date:** 2026-01-11
**Task:** Pre-implementation review of Phase 3.6B Universal Search plan
**Document to Review:** `docs/phase-3.6B/phase-3.6B-plan-v2.md`
**Feedback Location:** `docs/phase-3.6B/phase-3.6B-review-v1.md` (Codex's Feedback section)

---

## Your Mission

Review the Phase 3.6B Universal Search implementation plan for **architectural soundness and algorithmic correctness** before implementation begins.

This is a **pre-implementation review** - no code has been written yet. Focus on design flaws, integration issues, and algorithmic problems that would cause issues during or after implementation.

---

## What You're Reviewing

**Phase 3.6B: Universal Search**
- Two-stage search (SQL LIKE + Dart fuzzy matching)
- Weighted relevance scoring (title 60%, notes 30%, tags 10%)
- Match highlighting with position tracking
- Optional tag filtering (explicit, not automatic)
- Search state persistence (session only)
- Performance target: <100ms for 1000 tasks

**Timeline:** 8-11 days
**Complexity:** Medium-High
**Integration Points:** Phase 3.6A tag filtering, TaskProvider, existing search UI

---

## Review Instructions

### 1. Read the Plan Thoroughly

**Location:** `docs/phase-3.6B/phase-3.6B-plan-v2.md`

**Key sections to review:**
- SearchService architecture (section 2)
- Fuzzy matching algorithm (scoring, weighting)
- Integration with Phase 3.6A (section 5)
- SearchDialog state management
- Match highlighting implementation
- Search persistence strategy
- Testing approach

**Estimated reading time:** 30-45 minutes (1,181 lines)

---

### 2. Focus Areas for Codex

#### **A. Algorithm Correctness**
- Fuzzy matching approach sound?
- Relevance scoring algorithm correct?
- Weighted scoring (60/30/10) reasonable?
- Match position finding logic correct?
- Sort stability for equal scores?

#### **B. Architecture & Design**
- SearchService class design clean?
- Two-stage filtering (SQL + Dart) optimal?
- Widget state management appropriate?
- Search persistence architecture sound?
- TagSelectionDialog reuse approach correct?

#### **C. Integration Points**
- Phase 3.6A tag filter integration correct?
- TaskProvider methods used properly?
- FilterState compatibility maintained?
- Navigation to task will work?
- Dialog lifecycle handling correct?

#### **D. Edge Cases & Error Handling**
- Empty search query handling?
- No results state?
- Very long query strings?
- Unicode/emoji in search?
- Special characters (', ", %, etc.)?
- Concurrent searches (debouncing)?
- Database connection errors?

#### **E. Performance & Scalability**
- Two-stage approach efficient?
- Fuzzy matching on 1000 candidates feasible?
- Widget rebuild frequency acceptable?
- FutureBuilder usage appropriate?
- Memory usage with large result sets?

---

### 3. What to Look For

**CRITICAL Issues:**
- Algorithm will produce incorrect results
- Integration breaks existing functionality
- Architecture has fundamental flaws
- Performance targets impossible to meet
- Data loss or corruption risks

**HIGH Priority:**
- Suboptimal architecture (major refactor needed)
- Missing critical edge cases
- Integration conflicts with Phase 3.6A
- Performance bottlenecks
- State management issues

**MEDIUM Priority:**
- Code complexity that could be simplified
- Minor edge cases
- Test coverage gaps
- Maintainability concerns

**LOW Priority:**
- Alternative approaches worth considering
- Code organization suggestions
- Documentation improvements

---

### 4. Provide Feedback

**Location:** Add your feedback to `docs/phase-3.6B/phase-3.6B-review-v1.md` in the "Codex's Feedback" section.

**Use this format for each issue:**

```markdown
### [Priority] - [Category] - [Issue Title]

**Location:** [Section name or code block in plan-v2.md]

**Issue Description:**
[What's the architectural or algorithmic problem?]

**Suggested Fix:**
[How should the design be improved?]

**Impact:**
[What breaks if not fixed? Performance, correctness, maintainability?]
```

**Priority Levels:**
- **CRITICAL:** Fundamental flaw, blocks implementation
- **HIGH:** Significant issue requiring rework
- **MEDIUM:** Should address but can work around
- **LOW:** Nice-to-have improvement

**Categories:**
- **Logic:** Algorithm or business logic errors
- **Architecture:** Design or structure issues
- **Integration:** Compatibility with existing code
- **Testing:** Test strategy gaps
- **Performance:** Scalability concerns
- **Security:** Potential vulnerabilities

---

### 5. Example Feedback

```markdown
### HIGH - Architecture - Search State Management Too Complex

**Location:** Section 3 "SearchDialog", _saveSearchState() and _restoreSearchState() methods

**Issue Description:**
The plan stores search state in TaskProvider, but search is a UI concern, not a business logic concern. Mixing UI state with business state violates separation of concerns and makes TaskProvider more complex.

Additionally, the plan uses FutureBuilder for tag chip display, which will cause unnecessary rebuilds every time the dialog opens.

**Suggested Fix:**
1. Store search state in a dedicated SearchStateProvider or use StatefulWidget state only
2. Preload tag data when tags are selected, avoid FutureBuilder in chip display
3. Use Provider for search state if needed, but keep it separate from TaskProvider

\`\`\`dart
// Alternative approach
class SearchState extends ChangeNotifier {
  String query = '';
  SearchScope scope = SearchScope.current;
  List<String> selectedTagIds = [];
  Map<String, Tag> tagCache = {};  // Avoid FutureBuilder

  void reset() {
    query = '';
    scope = SearchScope.current;
    selectedTagIds.clear();
    notifyListeners();
  }
}
\`\`\`

**Impact:**
Current approach pollutes TaskProvider with UI concerns, makes testing harder, and causes unnecessary rebuilds. A cleaner architecture would improve maintainability and performance.
```

---

### 6. Areas of Special Focus

**BlueKitty's Requirements:**
Review how these user requirements are implemented:
1. **Search persistence:** Only clear on app launch - is this architecture sound?
2. **Optional tag filtering:** NOT automatic - is the integration clean?
3. **Default scope "Current":** Will this work with the algorithm?
4. **Clear All button:** Resets everything - edge cases covered?

**Critical Integration Points:**
- Phase 3.6A `FilterState` - compatibility maintained?
- `TaskProvider` - methods used correctly?
- Tag selector - can reuse existing dialog?
- Navigation - scroll to task will work?

**Algorithm Validation:**
- Fuzzy matching with `string_similarity` - library used correctly?
- Weighted scoring - weights make sense?
- Match position finding - algorithm correct for all cases?
- Relevance sort - stable and efficient?

---

### 7. Code Quality Review

**Check for:**
- **DRY violations:** Code duplication?
- **SOLID principles:** Single responsibility, open/closed?
- **Separation of concerns:** UI vs business logic?
- **Testability:** Can this code be unit tested easily?
- **Readability:** Is the approach clear and maintainable?
- **Error handling:** Missing try-catch or null checks?
- **Resource management:** Proper disposal of controllers?

---

### 8. Sign-Off Checklist

Before signing off, verify:
- [ ] Read entire plan-v2.md
- [ ] Reviewed all architectural decisions
- [ ] Validated algorithms and logic
- [ ] Checked integration with Phase 3.6A
- [ ] Assessed edge case handling
- [ ] Reviewed state management approach
- [ ] Verified test strategy coverage
- [ ] Added all feedback to review-v1.md
- [ ] Provided alternative approaches where appropriate
- [ ] Considered maintainability and scalability

**Only sign off if the architecture is sound or all issues are documented.**

---

### 9. Timeline

**Suggested time budget:**
- Reading plan: 30-45 minutes
- Architecture review: 1-2 hours
- Algorithm validation: 30-60 minutes
- Writing feedback: 30-60 minutes
- **Total:** 2.5-4.5 hours

**Take your time!** Architectural issues are expensive to fix after implementation starts.

---

## Key Questions to Answer

### Architecture
1. Is the two-stage filtering approach (SQL + Dart) the best design?
2. Should search state live in TaskProvider or separate provider?
3. Is the SearchService class well-designed?
4. Does the widget hierarchy make sense?

### Algorithms
5. Will fuzzy matching produce good results?
6. Are the scoring weights (60/30/10) appropriate?
7. Is match position finding robust for all text types?
8. Will sort stability cause issues?

### Integration
9. Does the tag filter integration respect Phase 3.6A design?
10. Will navigation to task work correctly?
11. Can TagSelectionDialog be reused cleanly?
12. Are there conflicts with existing filter state?

### Performance
13. Will fuzzy matching on 1000 candidates be fast enough?
14. Are there unnecessary widget rebuilds?
15. Will FutureBuilders cause performance issues?
16. Is the database query efficient?

### Edge Cases
17. What happens with very long queries (1000+ chars)?
18. How does it handle no results?
19. What about concurrent searches?
20. Are special characters handled correctly?

---

## Common Pitfalls to Watch For

1. **N+1 Query Problems:** Does the algorithm fetch tags individually?
2. **State Synchronization:** Can search state get out of sync with UI?
3. **Memory Leaks:** Are controllers/listeners disposed properly?
4. **Race Conditions:** What if user types very fast?
5. **Null Safety:** Are null cases handled?
6. **Error Propagation:** Do errors bubble up correctly?
7. **Widget Rebuilds:** Excessive rebuilds from poor state management?
8. **FutureBuilder Abuse:** Too many async operations in build?

---

## Success Criteria

**Your review is complete when:**
- You understand the entire architecture
- You've validated all algorithms
- You've checked all integration points
- You've considered all edge cases
- You've documented all concerns
- You've provided actionable suggestions
- You've signed off or documented blocking issues

---

## After Your Review

Once complete:
1. Update `review-v1.md` with all feedback
2. Fill in "Summary of Issues Found" table
3. Sign off if approved, or mark blocking issues as CRITICAL
4. Suggest alternative approaches if current design has issues

Claude will address all feedback, update the plan if needed, and coordinate with Gemini's review.

---

**Thank you for your thorough architectural review!** 🏗️

Good architecture now prevents technical debt later.

**Start your review:** Open `docs/phase-3.6B/phase-3.6B-plan-v2.md` and analyze the design!
