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

## Issue: Position backfill assigns duplicate orders for equal timestamps
**File:** pin_and_paper/lib/services/database_service.dart:415
**Type:** Bug
**Found:** 2025-10-30

**Description:**
The v4 migration seeds `position` with `COUNT(*) WHERE t2.created_at <= current.created_at`. When two siblings share the same `created_at` millisecond (common for bulk inserts), they both get the same count. After subtracting 1, every row with that timestamp ends up with an identical position, breaking the new ordering invariant before Phase 3.2 even runs.

**Suggested Fix:**
Add a deterministic tie-breaker—e.g., compare `created_at <` OR (`created_at =` AND `id <=`)—or rebuild the table with `rowid` ordering so each sibling's position is unique and stable.

**Impact:** High

---

## Issue: Success animation callback fires after screen is disposed
**File:** pin_and_paper/lib/widgets/success_animation.dart:24
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`SuccessAnimation` schedules `Future.delayed(..., widget.onComplete)`, but never cancels it. If the user backs out before the 1.2 s delay finishes, `_BrainDumpScreenState._onSuccessComplete` still runs; it calls `setState` and pushes a route on a disposed context, triggering `setState() called after dispose()` and a Navigator exception.

**Suggested Fix:**
Store the delayed callback (e.g., a `Timer`) and cancel it in `dispose()`, plus guard `_onSuccessComplete` with `if (!mounted) return;` before touching state/navigation.

**Impact:** Medium

---

## Issue: Loading a saved draft creates a duplicate on save
**File:** pin_and_paper/lib/screens/drafts_list_screen.dart:84
**Type:** Bug
**Found:** 2025-10-30

**Description:**
When the user loads a draft, the sheet only returns the combined text back to `BrainDumpScreen`. We never call `BrainDumpProvider.loadDraft`, so `_currentDraftId` stays `null`. The next save path inserts a brand-new row instead of updating the original draft, leaving the old copy behind. You can see the unused `loadDraft` helper in `BrainDumpProvider`—it was meant to keep the ID in sync but is never invoked.

**Suggested Fix:**
Before popping the draft list, detect the single-selection case and call `provider.loadDraft(selectedId, draft.content)` (or return both the content and draft ID). That keeps `_currentDraftId` pointing at the existing row; multi-draft merges can continue to clear the ID so a new combined draft is created.

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

## Issue: Brain Dump cost estimate never updates on errors/empty text
**File:** pin_and_paper/lib/providers/brain_dump_provider.dart:77
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`estimateCost()` adjusts `_estimatedCost`, but only calls `notifyListeners()` on the happy path. When the dump is blank (early return) or Claude throws (fallback sets `0.05`), listeners never rebuild. The confirmation dialog keeps showing the stale value from the previous run instead of resetting to `$0.00` or the fallback estimate.

**Suggested Fix:**
Always notify after updating `_estimatedCost`—either by moving the notification outside the try/catch or adding explicit `notifyListeners()` calls in the early-return and catch branches.

**Impact:** Medium

---

## Issue: Brain Dump clear button never flushes draft storage
**File:** pin_and_paper/lib/screens/brain_dump_screen.dart:292
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`_showClearConfirmation` calls `_clearText()`, which only wipes the controller and provider state. `_currentDraftId` stays set on the provider, so the next autosave overwrites the same draft ID with empty text. Worse, previously saved drafts linger forever because we never call `BrainDumpProvider.deleteDraft` or `clear()` to remove them from SQLite. The user thinks everything is gone, but the drafts screen still shows stale copies.

**Suggested Fix:**
Inside `_clearText`, grab the provider and call both `provider.clear()` (to reset the tracked ID) and `provider.deleteDraft(_currentDraftId)` when one exists, so the database record goes away when the user confirms "Clear."

**Impact:** Medium

---

## Issue: Brain Dump draft update silently fails if row was deleted
**File:** pin_and_paper/lib/providers/brain_dump_provider.dart:197
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`saveDraft` always goes down the `UPDATE` path once `_currentDraftId` is assigned. If the underlying row was removed (e.g., from the drafts list), the update affects 0 rows, we never detect it, and the draft isn't reinserted—so the snackbar says “Draft saved” while the DB stays empty.

**Suggested Fix:**
Check the update result and fall back to the insert branch (new UUID) whenever no rows were touched, ensuring the draft is recreated.

**Impact:** High

---

## Issue: VPN connections are treated as offline in Brain Dump
**File:** pin_and_paper/lib/providers/brain_dump_provider.dart:69
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`checkConnectivity()` only marks `_hasInternet` true for `mobile`, `wifi`, or `ethernet`. With connectivity_plus 6.x the plugin now reports `ConnectivityResult.vpn` (and sometimes `other`) for active VPN links. Users on VPN hit the "No internet connection" error path even though they are online, blocking Brain Dump entirely.

**Suggested Fix:**
Include `ConnectivityResult.vpn` (and probably `other`/`bluetooth` for tethering) in the allowlist when computing `_hasInternet`.

**Impact:** High

---

## Issue: Deleting an active draft leaves _currentDraftId stale
**File:** pin_and_paper/lib/providers/brain_dump_provider.dart:223
**Type:** Bug
**Found:** 2025-10-30

**Description:**
When the currently loaded draft is swiped away in the drafts list, `deleteDraft` removes the row but never clears `_currentDraftId`. Subsequent `saveDraft` calls take the "update existing draft" branch, yet the row no longer exists, so the update affects 0 rows and nothing is saved—appearing to succeed while silently dropping the draft.

**Suggested Fix:**
Inside `deleteDraft`, detect when `id == _currentDraftId` and reset `_currentDraftId` to `null` (or fallback to an insert when the update returns 0) so future saves recreate the draft instead of writing into the void.

**Impact:** High

---

## Issue: Hide-completed preference never loads on app start
**File:** pin_and_paper/lib/providers/task_provider.dart:104
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`TaskProvider.loadPreferences()` pulls the saved hide-completed settings from `SharedPreferences`, but nothing ever calls it. The provider always starts with `_hideOldCompleted = true` and `_hideThresholdHours = 24`, so user tweaks made in Settings are ignored after every app restart until they flip the switches again.

**Suggested Fix:**
Invoke `loadPreferences()` during initialization (e.g., in `main.dart` when constructing `TaskProvider`, or in `HomeScreen.initState`) so the provider hydrates its state from storage before rendering the task list and Settings screen.

**Impact:** Medium

---

## Issue: Usage stats query re-runs on every Settings rebuild
**File:** pin_and_paper/lib/screens/settings_screen.dart:220
**Type:** Performance
**Found:** 2025-10-30

**Description:**
`FutureBuilder` receives `_apiUsageService.getStats()` directly inside `build`. Every state change (typing the API key, toggling switches, showing snackbars) rebuilds the widget tree, creating a brand-new future and pinging SQLite again. The stats card flickers and the query runs far more often than necessary.

**Suggested Fix:**
Cache the future in state (e.g., `_usageStatsFuture`) and only refresh it when the user explicitly resets usage data or when we know stats changed. That keeps rebuilds cheap without losing accuracy.

**Impact:** Low

---

## Issue: Deprecated DropdownButtonFormField `value` still used
**File:** pin_and_paper/lib/screens/settings_screen.dart:185
**Type:** Style
**Found:** 2025-10-30

**Description:**
Flutter 3.24 deprecates the `value` parameter on `DropdownButtonFormField`. The hide-completed threshold dropdown still sets `value: taskProvider.hideThresholdHours`, so analyzer warnings are already firing and the widget will break when the old API disappears.

**Suggested Fix:**
Use `initialValue` (and manage selection changes via `onChanged`) to stay compatible with current Flutter releases.

**Impact:** Low

---

## Issue: Task suggestion screen shows snackbar after popping itself
**File:** pin_and_paper/lib/screens/task_suggestion_preview_screen.dart:252
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`_addApprovedTasks` calls `Navigator.popUntil(context, (route) => route.isFirst);` and immediately uses the same `context` to show a SnackBar. Once `popUntil` unwinds, that context belongs to a disposed route, so the snackbar call can throw (and occasionally does, especially in profile/release) because the element is no longer mounted.

**Suggested Fix:**
Capture a root `Navigator`/`ScaffoldMessenger` context before popping (e.g., `final messenger = ScaffoldMessenger.of(context);`) and only interact with it after confirming the screen is still mounted, or delay the snackbar with `Future.microtask` once the navigator has settled.

**Impact:** Medium

---

## Issue: Quick Complete snackbars vanish after route pop
**File:** pin_and_paper/lib/screens/quick_complete_screen.dart:56
**Type:** Bug
**Found:** 2025-10-30

**Description:**
All three completion flows (`_completeTaskImmediately`, `_completeSelected`, `_completeAll`) show a `SnackBar` and then immediately call `Navigator.pop(context)`. Because the snackbar belongs to the page being popped, it disappears before the user can see it. Home never shows the “✓ Completed…” toast.

**Suggested Fix:**
Capture a root `ScaffoldMessenger` before popping (or pop first and then show the snackbar using a `Future.microtask` with the parent context) so the confirmation stays visible on the home screen.

**Impact:** Medium

---

## Issue: Claude client hardcodes deprecated API version/model
**File:** pin_and_paper/lib/services/claude_service.dart:36
**Type:** Bug
**Found:** 2025-10-30

**Description:**
Every request still sends `'anthropic-version': '2023-06-01'` and targets `'claude-sonnet-4-5'`. Anthropic’s current stable release is 2024-09-24 with Sonnet 3.7; older versions are already warning and will be removed imminently. Once that happens Brain Dump and the settings connectivity test will start returning 4xx errors.

**Suggested Fix:**
Update both `claude_service.dart` and `settings_service.dart` to use the current API version/model (pull from the Anthropic dashboard) and centralize these constants so they stay in sync across services.

**Impact:** High

---

## Issue: API usage logging crashes when tokens metadata missing
**File:** pin_and_paper/lib/services/claude_service.dart:52
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`decoded['usage']['input_tokens']` / `output_tokens` is assumed non-null. On streaming responses, partial failures, or future API changes, `usage` is absent and the cast to `int` throws, taking down Brain Dump even though the Claude call succeeded.

**Suggested Fix:**
Guard the usage fields (default to 0 or skip logging when data is missing) before calling `ApiUsageService.logUsage`.

**Impact:** Medium

---

## Issue: Claude extraction has no network timeout
**File:** pin_and_paper/lib/services/claude_service.dart:31
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`http.post` to the Claude API isn’t wrapped in a timeout. If the request stalls (wifi drop, Anthropic hiccup), the future hangs forever, `_isProcessing` never resets, and the Brain Dump screen stays stuck until the app restarts.

**Suggested Fix:**
Apply a reasonable timeout (matching the settings connectivity test, e.g., 10s) so the UI can surface an error and recover.

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

## Issue: TaskService still orders tasks by created_at after v4
**File:** pin_and_paper/lib/services/task_service.dart:68
**Type:** Bug
**Found:** 2025-10-30

**Description:**
`getAllTasks()` continues to `ORDER BY created_at DESC`. With `position` now determining sibling order (and parent-child relationships), this query will scramble nested tasks once Phase 3.2 consumes the hierarchy, defeating the migration’s whole point.

**Suggested Fix:**
Sort using the new ordering columns (e.g., `ORDER BY parent_id IS NULL DESC, parent_id, position`) so both top-level and nested tasks respect their stored positions.

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

## Issue: Deprecated Color.withOpacity usage across UI
**File:** pin_and_paper/lib/screens/home_screen.dart:96
**Type:** Style
**Found:** 2025-10-30

**Description:**
Flutter 3.24 deprecates `Color.withOpacity`; analyzer now points at every call (home screen, quick complete, task item, etc.). Keeping the deprecated API will start failing once the team enables `treat-deprecation-as-error`, and it clutters analyzer output while we're trying to track real warnings.

**Suggested Fix:**
Replace the `.withOpacity(x)` helpers with the new `.withValues(alpha: x)` (or equivalent) on each color instance. Shadowed themes should keep their semantic colors unchanged.

**Impact:** Low

---
