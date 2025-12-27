# Phase 3.3 Test Plan
**Recently Deleted / Soft Delete Feature**

## Overview
This test plan validates all features implemented in Phase 3.3, including soft delete with CASCADE, Recently Deleted screen, restore functionality, permanent delete, empty trash, and automatic cleanup.

## Test Categories

### 1. Unit Tests - DatabaseService (lib/services/database_service.dart)

#### 1.1 Migration Tests

**Test: Migration v4 → v5 succeeds**
- Setup: Create database at version 4
- Execute: Run migration to version 5
- Verify:
  - `deleted_at` column exists in tasks table
  - `idx_tasks_deleted_at` index created
  - All existing tasks have `deleted_at = NULL`
  - No data loss during migration

**Test: Fresh install creates v5 schema**
- Setup: Clean database (no existing data)
- Execute: Call `_createDB()` with version 5
- Verify:
  - Tasks table includes `deleted_at INTEGER DEFAULT NULL`
  - Index `idx_tasks_deleted_at` exists
  - Schema matches migrated v4 databases exactly

**Test: Migration is idempotent**
- Setup: Run migration v4 → v5 once
- Execute: Attempt migration again
- Verify: No errors, schema unchanged

---

### 2. Unit Tests - TaskService (lib/services/task_service.dart)

#### 2.1 Soft Delete Methods

**Test: `softDeleteTask()` sets deleted_at timestamp**
- Setup: Create task
- Execute: `softDeleteTask(taskId)`
- Verify:
  - Task's `deleted_at` is set to current timestamp (within 1 second)
  - Task still exists in database
  - Task not returned by `getAllTasks()`

**Test: `softDeleteTask()` CASCADE to children**
- Setup: Create Parent → [Child1, Child2]
- Execute: `softDeleteTask(Parent.id)`
- Verify:
  - Parent.deleted_at set
  - Child1.deleted_at set to same timestamp
  - Child2.deleted_at set to same timestamp
  - None returned by `getAllTasks()`

**Test: `softDeleteTask()` CASCADE to deep hierarchy**
- Setup: Create Root → Parent → Child → Grandchild
- Execute: `softDeleteTask(Root.id)`
- Verify:
  - All 4 tasks have same deleted_at timestamp
  - None appear in active task queries

**Test: `softDeleteTask()` handles childless task**
- Setup: Create single task with no children
- Execute: `softDeleteTask(taskId)`
- Verify:
  - Task.deleted_at set
  - No errors
  - Task hidden from main queries

#### 2.2 Restore Methods

**Test: `restoreTask()` clears deleted_at**
- Setup: Create task → Soft delete it
- Execute: `restoreTask(taskId)`
- Verify:
  - Task.deleted_at = NULL
  - Task appears in `getAllTasks()`
  - Task appears in original position

**Test: `restoreTask()` CASCADE to children**
- Setup: Create Parent → [Child1, Child2] → Soft delete all
- Execute: `restoreTask(Parent.id)`
- Verify:
  - Parent.deleted_at = NULL
  - Child1.deleted_at = NULL
  - Child2.deleted_at = NULL
  - All 3 tasks appear in `getAllTasks()`
  - Hierarchy preserved

**Test: `restoreTask()` deep hierarchy CASCADE**
- Setup: Create 4-level hierarchy → Soft delete all
- Execute: `restoreTask(rootId)`
- Verify:
  - All 4 tasks restored (deleted_at = NULL)
  - Hierarchy intact
  - Positions preserved

**Test: `restoreTask()` on already-active task (no-op)**
- Setup: Create active task (deleted_at = NULL)
- Execute: `restoreTask(taskId)`
- Verify:
  - No error thrown
  - Task remains active
  - No side effects

#### 2.3 Permanent Delete Methods

**Test: `permanentlyDeleteTask()` hard deletes task**
- Setup: Create task → Soft delete it
- Execute: `permanentlyDeleteTask(taskId)`
- Verify:
  - Task no longer exists in database
  - Not returned by `getRecentlyDeletedTasks()`
  - Cannot be restored

**Test: `permanentlyDeleteTask()` CASCADE to children**
- Setup: Create Parent → Children → Soft delete all
- Execute: `permanentlyDeleteTask(Parent.id)`
- Verify:
  - All tasks hard deleted (foreign key CASCADE)
  - Database count = 0 for those task IDs

**Test: `emptyTrash()` deletes all soft-deleted tasks**
- Setup: Create 5 tasks → Soft delete 3 of them
- Execute: `emptyTrash()`
- Verify:
  - 3 soft-deleted tasks hard deleted
  - 2 active tasks remain unchanged
  - `getRecentlyDeletedTasks()` returns empty list

**Test: `emptyTrash()` with no deleted tasks (no-op)**
- Setup: All tasks active (none soft deleted)
- Execute: `emptyTrash()`
- Verify:
  - No errors
  - All tasks remain active
  - Returns count = 0

#### 2.4 Query Methods

**Test: `getRecentlyDeletedTasks()` returns only soft-deleted tasks**
- Setup: Create 5 tasks → Soft delete 2
- Execute: `getRecentlyDeletedTasks()`
- Verify:
  - Returns exactly 2 tasks
  - Both have deleted_at IS NOT NULL
  - Ordered by deleted_at DESC (most recent first)

**Test: `getRecentlyDeletedTasks()` excludes active tasks**
- Setup: Create mix of active and deleted tasks
- Execute: `getRecentlyDeletedTasks()`
- Verify:
  - No active tasks returned
  - Only tasks with deleted_at timestamp

**Test: `getRecentlyDeletedTasks()` includes hierarchical info**
- Setup: Soft delete Parent → Children
- Execute: `getRecentlyDeletedTasks()`
- Verify:
  - All tasks returned
  - Parent ID preserved
  - Can reconstruct hierarchy for display

**Test: `countRecentlyDeletedTasks()` accurate count**
- Setup: Soft delete 7 tasks
- Execute: `countRecentlyDeletedTasks()`
- Verify: Returns 7

**Test: `cleanupOldDeletedTasks(days = 30)` deletes old trash**
- Setup: Create 3 tasks → Soft delete with different timestamps:
  - Task A: deleted 31 days ago
  - Task B: deleted 15 days ago
  - Task C: deleted 29 days ago
- Execute: `cleanupOldDeletedTasks(30)`
- Verify:
  - Task A hard deleted (older than 30 days)
  - Task B remains (within 30 days)
  - Task C remains (within 30 days)
  - Returns count = 1

**Test: `cleanupOldDeletedTasks()` with custom threshold**
- Setup: Tasks deleted 10 days ago
- Execute: `cleanupOldDeletedTasks(days = 7)`
- Verify:
  - Tasks hard deleted (older than 7 days)
  - Custom threshold respected

#### 2.5 Query Exclusions

**Test: `getAllTasks()` excludes soft-deleted tasks**
- Setup: Create 5 tasks → Soft delete 2
- Execute: `getAllTasks()`
- Verify: Returns exactly 3 tasks (active only)

**Test: `getTaskHierarchy()` excludes soft-deleted tasks**
- Setup: Create Parent → [Child1, Child2] → Soft delete Child2
- Execute: `getTaskHierarchy()`
- Verify:
  - Parent returned
  - Child1 returned
  - Child2 NOT returned

**Test: `getTaskWithDescendants()` excludes deleted descendants**
- Setup: Create Parent → [Child1, Child2] → Soft delete Child1
- Execute: `getTaskWithDescendants(Parent.id)`
- Verify:
  - Parent returned
  - Child2 returned
  - Child1 NOT returned

**Test: `searchTasks()` excludes soft-deleted tasks**
- Setup: Create task "Important" → Soft delete it
- Execute: `searchTasks("Important")`
- Verify: No results (deleted task not searchable)

---

### 3. Unit Tests - TaskProvider (lib/providers/task_provider.dart)

#### 3.1 Delete Operations

**Test: `deleteTask()` calls softDeleteTask (not hard delete)**
- Setup: Create task
- Execute: `provider.deleteTask(taskId)`
- Verify:
  - Task soft deleted (deleted_at set)
  - Task not hard deleted
  - Task appears in Recently Deleted

**Test: `deleteTask()` updates UI state**
- Setup: Create task → Display in UI
- Execute: `provider.deleteTask(taskId)`
- Verify:
  - Task removed from active list
  - notifyListeners called
  - UI updates immediately

#### 3.2 Restore Operations

**Test: `restoreTask()` restores soft-deleted task**
- Setup: Soft delete task
- Execute: `provider.restoreTask(taskId)`
- Verify:
  - Task appears in active list
  - deleted_at = NULL
  - notifyListeners called

**Test: `restoreTask()` with parent restores children**
- Setup: Soft delete Parent → Children
- Execute: `provider.restoreTask(Parent.id)`
- Verify:
  - All tasks restored
  - Hierarchy preserved
  - All appear in active tree

#### 3.3 Permanent Delete

**Test: `permanentlyDeleteTask()` hard deletes**
- Setup: Soft delete task
- Execute: `provider.permanentlyDeleteTask(taskId)`
- Verify:
  - Task hard deleted from database
  - Removed from Recently Deleted list
  - Cannot be restored

**Test: `emptyTrash()` clears all deleted tasks**
- Setup: Soft delete 3 tasks
- Execute: `provider.emptyTrash()`
- Verify:
  - All 3 tasks hard deleted
  - Recently Deleted list empty
  - Active tasks unaffected

---

### 4. Widget Tests - RecentlyDeletedScreen

#### 4.1 Rendering

**Test: Empty state displays correctly**
- Setup: No soft-deleted tasks
- Execute: Render RecentlyDeletedScreen
- Verify:
  - "No recently deleted tasks" message shown
  - Empty trash button hidden
  - 30-day warning visible

**Test: Task list renders with timestamps**
- Setup: 3 soft-deleted tasks
- Execute: Render RecentlyDeletedScreen
- Verify:
  - All 3 tasks visible
  - Each shows "Deleted X days ago"
  - Timestamps accurate

**Test: Hierarchical tasks show breadcrumb**
- Setup: Soft delete Parent → Child
- Execute: Render RecentlyDeletedScreen
- Verify:
  - Child shows breadcrumb with Parent name
  - Parent shows no breadcrumb (root)

**Test: 30-day warning banner visible**
- Execute: Render RecentlyDeletedScreen
- Verify:
  - Warning message present
  - Mentions "30 days" explicitly
  - Styled as warning/info banner

#### 4.2 Interactions

**Test: Restore button restores task**
- Setup: Soft delete task → Navigate to screen
- Execute: Tap "Restore" button
- Verify:
  - Task restored (deleted_at = NULL)
  - Task removed from list
  - Snackbar shown: "Task restored"

**Test: Restore button with children shows count**
- Setup: Soft delete Parent → [Child1, Child2]
- Execute: Tap "Restore" on Parent
- Verify:
  - Shows "This will restore 2 subtasks" (or similar)
  - All 3 tasks restored on confirm

**Test: Delete Permanently button shows confirmation**
- Execute: Tap "Delete Permanently"
- Verify:
  - Confirmation dialog appears
  - Dialog text warns "cannot be undone"
  - Dialog has Cancel and Delete Forever buttons

**Test: Delete Permanently removes task**
- Setup: Soft delete task
- Execute: Tap "Delete Permanently" → Confirm
- Verify:
  - Task hard deleted
  - Task removed from list
  - Snackbar shown: "Task permanently deleted"

**Test: Empty Trash button shows confirmation with count**
- Setup: Soft delete 5 tasks
- Execute: Tap "Empty Trash"
- Verify:
  - Dialog shows count: "Permanently delete all 5 tasks?"
  - Dialog warns "cannot be undone"

**Test: Empty Trash clears all tasks**
- Setup: Soft delete 3 tasks
- Execute: Tap "Empty Trash" → Confirm
- Verify:
  - All 3 tasks hard deleted
  - Screen shows empty state
  - Snackbar shown: "Trash emptied"

#### 4.3 Error Handling

**Test: Restore error shows snackbar**
- Setup: Mock restore failure
- Execute: Tap "Restore"
- Verify:
  - Error snackbar shown
  - Task remains in list
  - User can retry

**Test: Delete error shows snackbar**
- Setup: Mock delete failure
- Execute: Tap "Delete Permanently" → Confirm
- Verify:
  - Error snackbar shown
  - Task remains in list

---

### 5. Widget Tests - Settings Screen

**Test: Recently Deleted menu item visible**
- Execute: Render SettingsScreen
- Verify:
  - "Recently Deleted" menu item present
  - Positioned above Debug section
  - Tappable

**Test: Badge shows count of deleted tasks**
- Setup: Soft delete 3 tasks
- Execute: Render SettingsScreen
- Verify:
  - Badge shows "3"
  - Badge visible and styled

**Test: Badge hidden when count = 0**
- Setup: No soft-deleted tasks
- Execute: Render SettingsScreen
- Verify: No badge shown (or shows "0" depending on design)

**Test: Tapping menu item navigates to Recently Deleted**
- Execute: Tap "Recently Deleted" item
- Verify: Navigates to RecentlyDeletedScreen

---

### 6. Widget Tests - Delete Dialogs

**Test: DeleteTaskDialog mentions "Recently Deleted"**
- Execute: Show delete dialog for task
- Verify:
  - Dialog text: "Move to Recently Deleted?" (or similar)
  - Not "Delete permanently"

**Test: DeleteTaskDialog button says "Move to Trash"**
- Execute: Show delete dialog
- Verify:
  - Button text: "Move to Trash" (not "Delete")

**Test: DeleteTaskDialog shows CASCADE warning for parents**
- Setup: Task with 3 children
- Execute: Show delete dialog
- Verify:
  - Warning: "This will also move 3 subtasks to trash"
  - Warning styled prominently

**Test: PermanentDeleteDialog warns "cannot be undone"**
- Execute: Show permanent delete dialog
- Verify:
  - Clear warning about permanence
  - Button text: "Delete Forever" (destructive style)

---

### 7. Integration Tests

#### 7.1 Soft Delete → Restore Flow

**Test: Complete soft delete and restore cycle**
- Steps:
  1. Create task "Test Task"
  2. Long-press task → Select "Move to Trash"
  3. Confirm dialog
  4. Verify task disappears from home
  5. Navigate to Settings → Recently Deleted
  6. Verify task appears with timestamp
  7. Tap "Restore"
  8. Navigate back to home
  9. Verify task reappears in original position
- Verify:
  - Task fully functional after restore
  - No data loss
  - Timestamps preserved

#### 7.2 Hierarchical Soft Delete

**Test: Soft delete parent CASCADE deletes children**
- Steps:
  1. Create Parent → [Child1, Child2, Grandchild]
  2. Long-press Parent → "Move to Trash"
  3. Confirm dialog (should show "4 subtasks")
  4. Verify all 4 tasks disappear from home
  5. Navigate to Recently Deleted
  6. Verify all 4 tasks present
  7. Verify Child1 shows breadcrumb "Parent"
  8. Verify Grandchild shows breadcrumb "Parent > Child2"
- Verify:
  - Hierarchy preserved in deleted state
  - All timestamps identical

**Test: Restore parent CASCADE restores children**
- Steps:
  1. Soft delete Parent → Children (from previous test)
  2. In Recently Deleted, tap "Restore" on Parent
  3. Confirm dialog (should show "3 subtasks")
  4. Navigate to home
  5. Verify Parent and all children restored
  6. Verify hierarchy intact
  7. Expand Parent → Verify children present
- Verify:
  - Complete subtree restored
  - No orphaned children
  - Positions preserved

#### 7.3 Permanent Delete Flow

**Test: Permanently delete task from Recently Deleted**
- Steps:
  1. Create task → Soft delete
  2. Navigate to Recently Deleted
  3. Tap "Delete Permanently"
  4. Confirm dialog
  5. Verify task removed from list
  6. Navigate to home → Verify task not there
  7. Reload app → Verify task still gone
- Verify:
  - Hard deleted from database
  - Cannot be restored
  - No database remnants

#### 7.4 Empty Trash Flow

**Test: Empty trash removes all deleted tasks**
- Steps:
  1. Create 5 tasks → Soft delete all
  2. Navigate to Recently Deleted
  3. Verify 5 tasks shown
  4. Tap "Empty Trash"
  5. Confirm dialog (shows "5 tasks")
  6. Verify screen shows empty state
  7. Reload app → Verify trash still empty
- Verify:
  - All tasks hard deleted
  - No tasks recoverable
  - Badge on Settings shows 0

#### 7.5 Automatic Cleanup Flow

**Test: Auto-cleanup deletes old trash on app launch**
- Steps:
  1. Create task → Soft delete
  2. Manually set deleted_at to 31 days ago (direct DB update)
  3. Close app
  4. Reopen app (triggers cleanup)
  5. Navigate to Recently Deleted
  6. Verify task NOT present (auto-deleted)
- Verify:
  - Cleanup runs on launch
  - Tasks older than 30 days removed
  - No user interaction required

**Test: Auto-cleanup preserves recent trash**
- Steps:
  1. Create 2 tasks → Soft delete both
  2. Manually set Task A deleted_at to 31 days ago
  3. Leave Task B deleted_at as recent
  4. Reopen app (triggers cleanup)
  5. Navigate to Recently Deleted
  6. Verify Task A gone, Task B present
- Verify:
  - Cleanup selective (only old tasks)
  - Recent trash preserved

#### 7.6 Mixed Scenarios

**Test: Soft delete, restore, soft delete again**
- Steps:
  1. Create task → Soft delete
  2. Restore task
  3. Soft delete again
  4. Verify task in Recently Deleted with new timestamp
- Verify:
  - Multiple delete cycles work
  - Timestamp updates each time

**Test: Restore task preserves due date and notifications**
- Steps:
  1. Create task with due date and notification
  2. Soft delete
  3. Restore
  4. Verify due date intact
  5. Verify notification settings preserved
- Verify: All task metadata preserved

**Test: Delete during reorder mode**
- Steps:
  1. Create tasks → Enter reorder mode
  2. Exit reorder mode → Long-press task
  3. Select "Move to Trash"
  4. Verify task deleted correctly
- Verify: No UI conflicts between modes

---

### 8. Edge Cases

#### 8.1 Data Integrity

**Test: Orphaned children after parent permanent delete (edge case)**
- Setup: Soft delete Parent → Permanently delete Parent only
- Verify:
  - Children also hard deleted (CASCADE)
  - No orphaned children in database

**Test: Restore orphaned child (invalid parent deleted)**
- Setup: Soft delete Parent → Permanent delete Parent → Restore Child
- Verify:
  - Child restored as root task (parent_id = NULL)
  - OR: Error shown (cannot restore orphan)

**Test: Circular reference prevention in deleted tasks**
- Setup: Create circular reference → Soft delete
- Verify:
  - No database corruption
  - Restore handles gracefully

#### 8.2 Performance

**Test: Large trash (100+ deleted tasks) renders smoothly**
- Setup: Soft delete 100 tasks
- Execute: Navigate to Recently Deleted
- Verify:
  - Screen loads within 2 seconds
  - List scrolls smoothly
  - No UI lag

**Test: Cleanup with large trash is non-blocking**
- Setup: 100 old deleted tasks
- Execute: Launch app (triggers cleanup)
- Verify:
  - App usable immediately
  - Cleanup runs in background
  - No UI freeze

#### 8.3 UI Edge Cases

**Test: Very long task title in Recently Deleted**
- Setup: Task with 200-character title → Soft delete
- Execute: Render in Recently Deleted screen
- Verify:
  - Title wraps correctly
  - No horizontal overflow

**Test: Task deleted 0 days ago (just now)**
- Setup: Soft delete task immediately
- Execute: View in Recently Deleted
- Verify: Shows "Deleted just now" or "Deleted today"

**Test: Task deleted exactly 30 days ago (boundary case)**
- Setup: Task deleted exactly 30 days ago
- Execute: Trigger cleanup
- Verify:
  - Cleanup logic handles boundary correctly
  - Consistent with "older than 30 days" definition

---

## Test Execution Priority

### P0 - Critical (Must pass before release)
1. Database migration v4 → v5
2. Soft delete with CASCADE
3. Restore with CASCADE
4. Permanent delete
5. Query exclusions (deleted_at IS NULL)
6. Recently Deleted screen rendering
7. Automatic cleanup

### P1 - High (Should pass)
1. Empty trash functionality
2. Settings badge count
3. Delete dialog text updates
4. Hierarchical restore
5. Timestamp display accuracy

### P2 - Medium (Nice to have)
1. Edge cases (orphaned children)
2. Performance with large trash
3. UI edge cases (long titles)
4. Error handling

## Test Implementation Notes

- Use existing test infrastructure (TestDatabaseHelper)
- Mock time for date-based cleanup tests
- Use integration tests for full user flows
- Test migration on copy of production database structure
- Consider snapshot testing for UI consistency

## Success Criteria

**Phase 3.3 is considered tested and ready when:**
- ✅ All P0 tests pass (100%)
- ✅ 95%+ of P1 tests pass
- ✅ No critical bugs found
- ✅ Manual testing validates UX flows
- ✅ Performance acceptable on target devices
- ✅ Migration tested on realistic data volume
- ✅ Edge cases handled gracefully (no crashes)
