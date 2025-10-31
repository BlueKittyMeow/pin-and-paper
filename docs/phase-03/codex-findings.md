## Issue: BuildContext reused after await in Brain Dump screen
**File:** pin_and_paper/lib/screens/brain_dump_screen.dart:86
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`Navigator.push` is awaited inside the Brain Dump app bar action and the callback continues to use `context` (`setState`, `context.read`, `Navigator.pop`) without guarding the async gap using `if (!context.mounted) return;`. The same pattern shows up in the pop interceptor and `_saveDraft` helpers. If the widget unmounts while the awaited navigation/dialog is open, resuming the callback triggers `setState`/navigation on a disposed context, which will crash in release.

**Suggested Fix:**
After each `await` that yields (`Navigator.push`, `_showExitConfirmation`, `_saveDraft`), immediately check `if (!context.mounted) return;` (or restructure to capture providers before the `await` and store local references). This satisfies the lint and guarantees the widget is still mounted before touching `context`.

**Impact:** Medium

---

## Issue: v4 migration misses task ordering indexes
**File:** pin_and_paper/lib/services/database_service.dart:524
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`_createDB` creates the new Phase 3 indexes `idx_tasks_created` and `idx_tasks_completed`, but `_migrateToV4` never adds them during the alter path. Devices upgrading from v3 keep a v4 schema without those indexes, so sorting and hide-completed queries will scan the whole `tasks` table while fresh installs use the indexed plan. That breaks the "fresh install == migrated install" guarantee the plan calls out.

**Suggested Fix:**
Add `CREATE INDEX idx_tasks_created ON tasks(created_at DESC)` and `CREATE INDEX idx_tasks_completed ON tasks(completed, completed_at)` inside `_migrateToV4` alongside the other task indexes (guarded with IF NOT EXISTS for safety).

**Impact:** Medium

---

## Issue: New tasks default to position 0 after v4 schema
**File:** pin_and_paper/lib/services/task_service.dart:19
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`TaskService.createTask` (and the bulk creation path) still rely on the `Task` model defaults, which leave `position` at `0`. In the v4 schema, `position` drives ordering within each parent. Without setting it, every newly created task will share `position = 0`, so once the UI switches to position-based ordering (Phase 3.2) tasks added post-migration will appear in arbitrary order and drag-to-reorder logic will fail.

**Suggested Fix:**
Look up the current max `position` for the target parent (or `NULL` for top-level) and assign `nextPosition = max + 1` when instantiating the new task before insertion. Do the same in the bulk creation transaction.

**Impact:** High

---

## Issue: Bottom sheet cleanup calls setState after dispose
**File:** pin_and_paper/lib/screens/task_suggestion_preview_screen.dart:223
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`_showOriginalBottomSheet` attaches a `.whenComplete(() { setState(...) })` to the modal bottom sheet. If the preview screen is popped while the sheet is open (e.g., user hits the close icon), the state unmounts before the sheet's future completes. The callback still runs, so `setState` executes on a disposed State object, triggering "setState() called after dispose()" and bubbling an exception in release.

**Suggested Fix:**
Wrap the completion handler with an `if (!mounted) return;` guard before calling `setState`, or move the `_showOriginalText` reset into `didChangeDependencies`/`dispose` so it doesn't rely on `setState` after the async gap.

**Impact:** Medium

---
