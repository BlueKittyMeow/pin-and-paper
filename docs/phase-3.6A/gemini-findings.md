
## Additional Findings (General Review)

### UX/Logic Ambiguity: "Has Tags" / "No Tags" Interaction
**Type:** UX / Logic
**Description:** The plan mentions a potential ambiguity when combining "Show only tasks with tags" or "Show only tasks without tags" with specific tag selections (e.g., "Work").
- If "No tags" is selected, selecting any specific tag (like "Work") creates a logical contradiction (a task cannot have no tags AND have the "Work" tag).
- If "Has tags" is selected, selecting specific tags is redundant but harmless.

**Recommendation:**
- **Mutually Exclusive UI:** The UI should enforce logic. If "No tags" is checked, disable/uncheck all specific tag selectors. If a specific tag is checked, uncheck "No tags".
- **Clear Visuals:** Use radio button-like behavior or clear visual grouping to show these are distinct modes.

### Architecture: Filter Persistence
**Type:** Architecture / Product Decision
**Description:** The decision to **not** persist filter state across app restarts is sound for an MVP but might annoy power users who always want to see "Work" tasks.
**Recommendation:**
- **Accept for MVP:** This is a good scope decision for 3.6A.
- **Future Hook:** Ensure `FilterState` has a `toJson` / `fromJson` method *now* even if not used for persistence yet. This makes adding persistence later (Phase 6) trivial without refactoring the model.

### UI: Active Filter Bar Overflow
**Type:** UI / Usability
**Description:** If a user selects 10+ tags, the `ActiveFilterBar` could become unwieldy even if scrollable.
**Recommendation:**
- **"Clear All" Visibility:** Ensure the "Clear All" button is always visible (pinned to the right) and doesn't scroll off-screen with the tags. This ensures users can always easily reset.

### Testing: Dialog Search + Selection
**Type:** Testing Gap
**Description:** The test plan covers filtering logic well but misses a specific UI interaction flow in the `TagFilterDialog`.
**Scenario:**
1. User searches for "Work".
2. Checks "Work".
3. Clears search.
4. "Work" should still be checked in the full list.
5. Applies filter.
**Recommendation:** Add a specific widget test for `TagFilterDialog` that verifies selection state is preserved across search query changes.
