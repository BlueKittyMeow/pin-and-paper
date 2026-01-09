
---

## Bonus UX Refinements (Polishing Suggestions)

These are not blockers, but implementing them will significantly enhance the user experience.

### 1. Functional UX: Scroll Position Reset
**The Issue:** When a filter is applied, the content of the task list changes completely. If the user was scrolled down in the previous view, the scroll position might be maintained, potentially leaving the user looking at empty space or the middle of a short filtered list.
**Suggestion:** Explicitly reset the `ScrollController` position to `0` (top) in `TaskListScreen` whenever the `TaskProvider.filterState` changes. This ensures users always see the top results of their new filter immediately.

### 2. Visual Polish: "Ghost Tag" Handling
**The Issue:** The `ActiveFilterBar` code currently defaults to showing an "Unknown" grey chip if a selected tag ID is not found in `allTags` (e.g., if it was deleted on another device or through a sync error). Showing "Unknown" looks broken.
**Suggestion:** Filter the list of tags to display in `ActiveFilterBar`. Instead of showing a placeholder, simply **hide** chips for tags that cannot be found in `allTags`. This makes the UI self-correcting.
```dart
final validTagIds = filterState.selectedTagIds
    .where((id) => allTags.any((t) => t.id == id));
```

### 3. Micro-interaction: Haptic Feedback
**The Issue:** Filtering is a significant state change. Visual feedback alone can sometimes be missed if the list change is subtle.
**Suggestion:** Add `HapticFeedback.lightImpact()` when toggling checkboxes in the dialog, and `HapticFeedback.mediumImpact()` when tapping "Apply" or "Clear All". This tactile response reinforces the action.
