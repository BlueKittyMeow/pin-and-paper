# Phase 3.2 Implementation – Review v1

## Findings

- **HIGH · Data** – The checklist for `TaskService` (lines 73‑79 of `phase-3.2-implementation.md`) never mentions reindexing siblings after a move or reorder. Group 1’s spec explicitly requires `_reindexSiblings` to run for both the old and new parents to keep `position` values gapless and sortable (`docs/phase-03/group1.md:1693-1720`). Without planning that work, repeated drags will leave duplicate or out-of-order `position` values, making the recursive sort order non-deterministic.

- **HIGH · Logic** – There is no call-out for cycle detection when moving a task to a new parent. The spec dedicates an entire helper (`_wouldCreateCycle`, `docs/phase-03/group1.md:1624-1688`) to prevent users from nesting a task under its own descendant. The implementation doc only says “Change nesting level (with validation)” (line 77) but never states what validation is required or how it should be surfaced in the UI. This omission leaves a critical logic safeguard undefined.

- **MEDIUM · Documentation** – The auto-complete children workflow (lines 51‑55) states “Store preference in user_settings” but never enumerates the allowed values (`prompt`/`always`/`never` from `docs/phase-03/group1.md:338-458`) or how the dialog writes them back. Without that detail the team can’t ensure the dialog, TaskService, and `UserSettings` model agree on semantics, which undermines clarity and consistency.

- **MEDIUM · Testing** – The testing checklist (lines 111‑121) covers hierarchy, position, depth, and a few flows, but it omits any tests for (1) cycle detection failures, (2) sibling reindexing after cross-parent moves, and (3) ensuring the “remember my choice” preference actually persists and changes downstream behavior. Those edge cases are explicitly called out in the spec as high risk yet have no planned coverage, leaving a substantial testing gap.

## Suggestions

1. Update the TaskService section to explicitly include sibling reindex steps (old parent + new parent) so the work mirrors `group1.md` and the DB ordering remains stable.
2. Document the exact validation steps required when dragging or using “convert/promote,” including the user-facing error when a cycle or depth violation is detected.
3. Flesh out the auto-complete dialog section with the enum of allowed values and the provider/service methods responsible for persisting and honoring them.
4. Extend the test plan with explicit cases for cycle prevention, reindex correctness, and auto-complete preference persistence so those failure modes are covered before coding starts.
