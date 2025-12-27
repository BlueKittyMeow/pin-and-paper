# Phase 3.3 Implementation: Recently Deleted (Soft Delete)

**Subphase:** 3.3
**Status:** ✅ COMPLETE
**Started:** 2025-12-26
**Completed:** 2025-12-27
**Actual Duration:** 1 day

---

## Quick Links

- **Feature Request:** FEATURE_REQUESTS.md (Lines 1-153)
- **Database Schema:** Current version 4 → Migrate to version 5
- **Bug Tracker:** [phase-03-bugs.md](./phase-03-bugs.md)
- **Test Plan:** [phase-3.3-test-plan.md](./phase-3.3-test-plan.md)

---

## Scope

Phase 3.3 implements a "Recently Deleted" safety net to prevent accidental data loss, similar to iOS/Android trash functionality.

### User Story
> "Can we have a section for recently deleted tasks somewhere? Just in case things get accidentally deleted."

This feature addresses a critical UX need for users with ADHD who may accidentally delete tasks and need an undo mechanism.

---

## Features to Implement

### 1. **Database Migration (v4 → v5)**
- Add `deleted_at` timestamp column to tasks table
- Create index on `deleted_at` for query performance
- Modify existing queries to exclude soft-deleted tasks by default

### 2. **Soft Delete System**
- **TaskService Methods:**
  - `softDeleteTask(taskId)` - Set `deleted_at = NOW()`
  - `restoreTask(taskId)` - Set `deleted_at = NULL`
  - `permanentlyDeleteTask(taskId)` - Hard delete from database
  - `getRecentlyDeletedTasks()` - Fetch tasks where `deleted_at IS NOT NULL`
  - `cleanupOldDeletedTasks()` - Hard delete tasks older than 30 days

- **Cascade Behavior:**
  - Soft-deleting a parent soft-deletes all children (set same `deleted_at` timestamp)
  - Restoring a parent restores all children (set `deleted_at = NULL`)
  - Permanent delete uses CASCADE (already handled by foreign key)

### 3. **Recently Deleted Screen**
- New screen accessible from Settings
- Shows tasks deleted within last 30 days
- Each task displays: "Deleted X days ago" (relative time)
- Task hierarchy preserved (show parent breadcrumb if applicable)
- Actions available:
  - **Restore** - Restore individual task (and children if parent)
  - **Delete Permanently** - Hard delete with confirmation
  - **Empty Trash** - Delete all with confirmation
- Empty state: "No recently deleted tasks"
- Warning: "Tasks are permanently deleted after 30 days"

### 4. **Automatic Cleanup**
- Run cleanup on app launch (async, non-blocking)
- Delete tasks where `deleted_at < (NOW() - 30 days)`
- Log cleanup actions for debugging
- Consider: Future enhancement could add scheduled background job

### 5. **UI Updates**
- **Settings Screen:**
  - Add "Recently Deleted" menu item with badge showing count
  - Position above "Debug" section

- **Delete Confirmations:**
  - Update existing delete dialogs to mention "Move to Recently Deleted"
  - Change "Delete" button text to "Move to Trash"
  - Keep CASCADE warning for parents with children

---

## Implementation Checklist

### Prerequisites ✅
- [x] Database v4 schema in production
- [x] CASCADE delete working correctly
- [x] Hierarchical tasks fully functional
- [x] Test infrastructure established

### Phase 3.3 Tasks

#### Database Layer
- [ ] Create migration v4 → v5 script
- [ ] Add `deleted_at INTEGER DEFAULT NULL` column to tasks table
- [ ] Create index: `idx_tasks_deleted_at`
- [ ] Update `_createDB()` to include deleted_at in fresh installs
- [ ] Test migration on test database
- [ ] Verify index performance

#### TaskService - Soft Delete Methods
- [ ] Implement `softDeleteTask(taskId)` with CASCADE to children (always cascades)
- [ ] Implement `restoreTask(taskId)` with CASCADE to children
- [ ] Implement `permanentlyDeleteTask(taskId)` (hard delete)
- [ ] Implement `getRecentlyDeletedTasks()` (ordered by deleted_at DESC)
- [ ] Implement `countRecentlyDeletedTasks()` for badge
- [ ] Implement `emptyTrash()` (hard delete all soft-deleted tasks)
- [ ] Implement `cleanupOldDeletedTasks(daysThreshold = 30)`
- [ ] Add comprehensive doc comments

#### TaskService - Query Updates
- [ ] Audit all existing queries to add `WHERE deleted_at IS NULL`
- [ ] Update `getTaskHierarchy()` to exclude deleted tasks
- [ ] Update `getAllTasks()` to exclude deleted tasks
- [ ] Update `getTaskWithDescendants()` to exclude deleted tasks
- [ ] Add optional `includeDeleted` parameter for flexibility
- [ ] Update search queries to exclude deleted tasks

#### TaskProvider - State Management
- [ ] Update `deleteTask()` to call `softDeleteTask()` instead of hard delete
- [ ] Add `restoreTask()` method
- [ ] Add `permanentlyDeleteTask()` method
- [ ] Add `emptyTrash()` method
- [ ] Update task counts to exclude soft-deleted tasks
- [ ] Add notification when tasks auto-cleaned

#### Recently Deleted Screen
- [ ] Create `lib/screens/recently_deleted_screen.dart`
- [ ] Implement task list with hierarchical display
- [ ] Add "Deleted X days ago" timestamp formatter
- [ ] Show parent breadcrumb for child tasks
- [ ] Implement Restore button with loading state
- [ ] Implement Delete Permanently button with confirmation
- [ ] Implement Empty Trash button with confirmation
- [ ] Add empty state illustration/message
- [ ] Add 30-day warning banner at top
- [ ] Handle errors gracefully (show snackbar)

#### Settings Screen Updates
- [ ] Add "Recently Deleted" menu item
- [ ] Add badge showing count of deleted tasks
- [ ] Wire up navigation to RecentlyDeletedScreen
- [ ] Position menu item logically (above Debug section)

#### Dialogs & Confirmations
- [ ] Update `DeleteTaskDialog` text: "Move to Recently Deleted?"
- [ ] Update button text: "Move to Trash" instead of "Delete"
- [ ] Create `PermanentDeleteDialog` for hard delete confirmation
- [ ] Create `EmptyTrashDialog` with count display
- [ ] Update context menu to show "Move to Trash"

#### Automatic Cleanup
- [ ] Add cleanup call in `main.dart` on app launch
- [ ] Implement background/async cleanup (non-blocking)
- [ ] Use hardcoded 30-day threshold for cleanup
- [ ] Log cleanup results for debugging
- [ ] Show snackbar notification if tasks were auto-deleted (count > 0)

#### Testing
- [ ] Unit tests: Soft delete with CASCADE
- [ ] Unit tests: Restore with CASCADE
- [ ] Unit tests: Permanent delete
- [ ] Unit tests: Cleanup old deleted tasks (date math)
- [ ] Unit tests: Query exclusions (deleted_at IS NULL)
- [ ] Widget tests: RecentlyDeletedScreen rendering
- [ ] Widget tests: Restore/Delete buttons
- [ ] Widget tests: Empty trash confirmation
- [ ] Integration test: Soft delete → Restore flow
- [ ] Integration test: Soft delete → 30 days → Auto-cleanup
- [ ] Integration test: Hierarchical soft delete (parent + children)
- [ ] Integration test: Settings navigation to Recently Deleted

---

## Technical Decisions

### 1. Soft Delete vs Archive
**Decision:** Use soft delete with `deleted_at` timestamp (not boolean `archived`)
**Rationale:**
- Timestamp allows "Deleted X days ago" display
- Enables automatic cleanup based on age
- Matches iOS/Android "Recently Deleted" UX
- More intuitive naming for users ("Trash" vs "Archive")

### 2. Cascade Behavior on Soft Delete
**Decision:** Soft-deleting parent soft-deletes all children with same timestamp
**Rationale:**
- Maintains hierarchy integrity
- All or nothing restore (no orphaned children)
- Simpler mental model for users
- Matches hard delete CASCADE behavior

### 3. Automatic Cleanup Timing
**Decision:** Run on app launch, not scheduled background job
**Rationale:**
- Simpler implementation (no background job infrastructure)
- Sufficient for use case (app opened frequently)
- Non-blocking async operation
- Can add scheduled job in future if needed
- Low overhead (single DELETE query with WHERE clause)

### 4. Query Modification Strategy
**Decision:** Update all existing queries to add `WHERE deleted_at IS NULL`
**Rationale:**
- Ensures deleted tasks never appear in main app
- Explicit opt-in required to see deleted tasks
- Prevents bugs from forgetting to filter
- Slight performance cost mitigated by index on deleted_at

### 5. Restore Behavior for Children
**Decision:** Restoring parent restores all children automatically
**Rationale:**
- Symmetrical with soft delete (preserve hierarchy)
- Avoids orphaned children scenario
- Simpler user experience (one click restores subtree)
- Matches user expectations

### 6. Badge Count on Settings
**Decision:** Show count of recently deleted tasks as badge
**Rationale:**
- Increases discoverability of feature
- Provides at-a-glance info
- Matches iOS Settings app pattern
- Reminds users to check trash periodically

---

## Database Migration Details

### Migration v4 → v5

```sql
-- Add deleted_at column to tasks table
ALTER TABLE tasks ADD COLUMN deleted_at INTEGER DEFAULT NULL;

-- Create index for query performance
CREATE INDEX idx_tasks_deleted_at ON tasks(deleted_at);

-- Optional: Create compound index for common query pattern
CREATE INDEX idx_tasks_active ON tasks(deleted_at, completed, created_at DESC)
  WHERE deleted_at IS NULL;
```

### Schema After Migration

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  completed INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  completed_at INTEGER,

  -- Phase 3.1: Date fields
  due_date INTEGER,
  is_all_day INTEGER DEFAULT 1,
  start_date INTEGER,

  -- Phase 3.2: Nesting
  parent_id TEXT,
  position INTEGER NOT NULL DEFAULT 0,

  -- Phase 3.1: Template support
  is_template INTEGER DEFAULT 0,

  -- Phase 3.1: Notification support
  notification_type TEXT DEFAULT 'use_global',
  notification_time INTEGER,

  -- Phase 3.3: Soft delete ⭐ NEW
  deleted_at INTEGER DEFAULT NULL,

  FOREIGN KEY (parent_id) REFERENCES tasks(id) ON DELETE CASCADE
);
```

---

## Files to Modify/Create

### New Files
- `lib/screens/recently_deleted_screen.dart` - Main screen for trash
- `lib/widgets/deleted_task_item.dart` - Task card with restore/delete buttons
- `lib/widgets/empty_trash_dialog.dart` - Confirmation dialog for empty trash
- `lib/widgets/permanent_delete_dialog.dart` - Confirmation for hard delete
- `test/screens/recently_deleted_screen_test.dart` - Widget tests
- `test/integration/recently_deleted_flow_test.dart` - Integration tests

### Modified Files
- `lib/services/database_service.dart` - Add migration v4 → v5, update _createDB
- `lib/services/task_service.dart` - Add soft delete methods, update queries
- `lib/providers/task_provider.dart` - Update deleteTask, add restore methods
- `lib/screens/settings_screen.dart` - Add Recently Deleted menu item + badge
- `lib/widgets/delete_task_dialog.dart` - Update text to mention trash
- `lib/utils/constants.dart` - Add database version 5
- `lib/main.dart` - Add cleanup call on app launch

### Test Files
- `test/services/task_service_test.dart` - Add new `group('soft delete', ...)` with comprehensive test cases
- `test/services/database_service_test.dart` - Test migration v4 → v5

---

## Dependencies

### No New Dependencies Required
All functionality uses existing packages:
- `sqflite` - Database operations (already present)
- `path_provider` - App directory (already present)
- `intl` - Date formatting (already present)

---

## User Experience Flow

### Soft Delete Flow
```
User long-presses task → Context menu "Move to Trash"
  ↓
Shows dialog: "Move '[task]' to Recently Deleted?"
  ↓
If task has children: "This will also move X subtasks to trash"
  ↓
User taps "Move to Trash"
  ↓
Task(s) soft deleted (deleted_at = NOW())
  ↓
Snackbar: "Moved to Recently Deleted"
  ↓
Task disappears from main view
```

### Restore Flow
```
Settings → Recently Deleted
  ↓
User sees list of deleted tasks with timestamps
  ↓
User taps "Restore" on a task
  ↓
If task has children: Shows count "This will restore X subtasks"
  ↓
User confirms
  ↓
Task(s) restored (deleted_at = NULL)
  ↓
Snackbar: "Task restored"
  ↓
User navigates back to home, sees task in original location
```

### Permanent Delete Flow
```
Recently Deleted screen → User taps "Delete Permanently"
  ↓
Dialog: "Permanently delete '[task]'? This cannot be undone."
  ↓
If task has children: "This will also permanently delete X subtasks"
  ↓
User taps "Delete Forever" (red/destructive button)
  ↓
Task hard deleted from database (CASCADE to children)
  ↓
Snackbar: "Task permanently deleted"
```

### Empty Trash Flow
```
Recently Deleted screen → User taps "Empty Trash" button
  ↓
Dialog: "Permanently delete all X tasks? This cannot be undone."
  ↓
User taps "Empty Trash" (red button)
  ↓
All soft-deleted tasks hard deleted
  ↓
Screen updates to show empty state
  ↓
Snackbar: "Trash emptied"
```

### Automatic Cleanup Flow
```
User opens app
  ↓
App launch triggers cleanup (async, non-blocking)
  ↓
Query: DELETE FROM tasks WHERE deleted_at < (NOW() - 30 days)
  ↓
Log cleanup results for debugging
  ↓
If count > 0: Show snackbar "Removed X old tasks from trash (>30 days)"
  ↓
User continues using app normally
```

---

## Edge Cases & Considerations

### 1. Hierarchical Tasks
- **Soft deleting parent:** All children get same `deleted_at` timestamp
- **Restoring parent:** All children get `deleted_at = NULL` together
- **Partial restore not allowed:** Must restore entire subtree
- **Display in Recently Deleted:** Show parent with breadcrumb context
- **Restoring child task UX:** When user taps "Restore" on a child task, show dialog:
  - Title: "Restore Task Tree"
  - Message: "This will also restore '[Parent Task Name]' and all of its subtasks. Continue?"
  - Buttons: "Cancel" (default), "Restore" (primary)
  - This makes the CASCADE behavior explicit and prevents surprise

### 2. Task with Due Dates
- **Soft deleted tasks don't trigger notifications**
- **Restored tasks resume normal notification schedule**
- **Query filters must exclude deleted tasks from date views**

### 3. Templates
- **Templates can be soft deleted** (is_template flag preserved)
- **Deleted templates don't appear in template picker**
- **Restoring template makes it available again**

### 4. Performance
- **Index on deleted_at ensures fast filtering**
- **Cleanup query uses indexed WHERE clause**
- **Count badge query optimized with COUNT(*) on indexed column**

### 5. Data Integrity
- **Foreign key CASCADE still works for permanent delete**
- **Soft delete doesn't violate any constraints**
- **Restoring tasks preserves all relationships (parent_id, etc.)**

### 6. Migration Safety
- **New installs get deleted_at column from _createDB**
- **Existing users get column via migration with DEFAULT NULL**
- **All existing tasks unaffected (deleted_at = NULL)**
- **Migration is reversible (can drop column if needed)**

---

## Testing Strategy

### Unit Tests (TaskService)
1. Soft delete single task (verify deleted_at set)
2. Soft delete parent with children (verify CASCADE)
3. Restore single task (verify deleted_at = NULL)
4. Restore parent with children (verify CASCADE)
5. Permanent delete task (verify hard deleted)
6. Empty trash (verify all soft-deleted tasks gone)
7. Cleanup old deleted tasks (date math validation)
8. Get recently deleted tasks (ordered by deleted_at DESC)
9. Count recently deleted tasks (accurate count)

### Integration Tests
1. **Soft Delete → Restore Flow:**
   - Create task → Soft delete → Verify hidden from home
   - Navigate to Recently Deleted → Restore task
   - Navigate to home → Verify task visible again

2. **Hierarchical Soft Delete:**
   - Create Parent → [Child1, Child2]
   - Soft delete Parent
   - Verify all 3 tasks in Recently Deleted
   - Restore Parent
   - Verify all 3 tasks back in home with correct hierarchy

3. **Automatic Cleanup:**
   - Create task → Soft delete
   - Manually set deleted_at to 31 days ago
   - Trigger cleanup
   - Verify task permanently deleted

4. **Empty Trash:**
   - Create 3 tasks → Soft delete all
   - Empty trash
   - Verify all permanently deleted
   - Verify empty state shown

### Widget Tests
1. RecentlyDeletedScreen renders empty state correctly
2. RecentlyDeletedScreen renders task list with timestamps
3. Restore button calls correct method
4. Delete Permanently button shows confirmation
5. Empty Trash button shows confirmation with count

---

## Success Criteria

**Phase 3.3 is considered complete when:**
- ✅ Database migration v4 → v5 successful
- ✅ All existing queries exclude soft-deleted tasks
- ✅ Soft delete with CASCADE working
- ✅ Restore with CASCADE working
- ✅ Recently Deleted screen fully functional
- ✅ Automatic cleanup working
- ✅ All unit tests passing
- ✅ All integration tests passing
- ✅ Manual testing on Android validates UX flows
- ✅ No regressions in existing functionality
- ✅ Documentation updated

---

## Known Risks & Mitigation

### Risk 1: Migration Failure
**Impact:** Users can't open app (database locked)
**Mitigation:**
- Test migration thoroughly on test database first
- Implement rollback mechanism
- Add migration logging for debugging
- Consider: Backup database before migration (future enhancement)

### Risk 2: Query Performance Degradation
**Impact:** App feels slower after adding deleted_at filters
**Mitigation:**
- Create indexes on deleted_at column
- Use partial indexes where appropriate
- Benchmark query performance before/after
- Monitor query execution plans

### Risk 3: Accidental Data Loss
**Impact:** User empties trash or cleanup runs too aggressively
**Mitigation:**
- Clear confirmation dialogs before permanent delete
- 30-day window is generous
- User setting for cleanup threshold (future enhancement)
- Consider: Warning notification before auto-cleanup

### Risk 4: Storage Bloat
**Impact:** Deleted tasks take up space for 30 days
**Mitigation:**
- Automatic cleanup after 30 days
- Empty Trash button for manual cleanup
- Typical usage: small number of deleted tasks
- Monitor: Add storage metrics in Debug screen (future)

---

## Progress Log

### 2025-12-26: Phase 3.3 Planning Started
- ✅ Created phase-3.3-implementation.md
- ⏸️ Ready to begin implementation after user approval

---

## Next Steps

1. Review this implementation plan
2. Create test plan document (phase-3.3-test-plan.md)
3. Begin database migration implementation
4. Implement soft delete methods
5. Build Recently Deleted screen
6. Update existing UI/dialogs
7. Write comprehensive tests
8. Manual testing on Android
9. Document any changes/learnings
10. Merge to main after validation
