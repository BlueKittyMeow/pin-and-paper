# Feature Requests

**Track user-requested features and enhancements**

---

## 🗑️ Recently Deleted / Trash Feature

**Requested:** 2025-12-22
**Priority:** Medium
**Complexity:** Medium
**Assigned Phase:** 3.3 (Soft Delete with 30-Day Auto-Cleanup)
**Status:** Planned for next phase

### Description
Add a "Recently Deleted" section to prevent accidental data loss, similar to iOS/Android trash functionality.

### User Story
> "Can we have a section for recently deleted tasks somewhere? Just in case things get accidentally deleted."

### Proposed Implementation

#### Database Changes
- Add `deleted_at` timestamp column to tasks table
- Soft delete: Set `deleted_at = NOW()` instead of actual deletion
- Hard delete: Remove tasks where `deleted_at` > 30 days old

#### UI/UX
- **Settings Screen:** Add "Recently Deleted" menu item
- **Recently Deleted Screen:**
  - Show tasks deleted within last 30 days
  - Each task shows "Deleted X days ago"
  - Actions: Restore, Delete Permanently
  - "Empty Trash" button (deletes all)
  - Auto-delete after 30 days warning

#### Task Flow
```
Long-press task → Delete → Confirmation
  ↓
Soft delete (set deleted_at timestamp)
  ↓
Task moves to Recently Deleted
  ↓
User has 30 days to restore or permanently delete
  ↓
After 30 days: Background job hard-deletes
```

#### Database Schema
```sql
-- Add to migration v5
ALTER TABLE tasks ADD COLUMN deleted_at INTEGER DEFAULT NULL;

-- Query for active tasks
WHERE deleted_at IS NULL

-- Query for recently deleted
WHERE deleted_at IS NOT NULL AND deleted_at > (NOW() - 30 days)

-- Restore task
UPDATE tasks SET deleted_at = NULL WHERE id = ?

-- Hard delete old trash
DELETE FROM tasks WHERE deleted_at < (NOW() - 30 days)
```

#### Files to Create/Modify
- `lib/screens/recently_deleted_screen.dart` (new)
- `lib/services/task_service.dart` (add soft delete methods)
- `lib/providers/task_provider.dart` (add restore methods)
- `lib/services/database_service.dart` (migration v5)
- `lib/screens/settings_screen.dart` (add menu item)
- `lib/utils/background_jobs.dart` (new - cleanup task)

### Benefits
- ✅ Prevents accidental data loss
- ✅ Familiar UX (iOS/Android users expect this)
- ✅ Peace of mind for users with ADHD
- ✅ Undo mistakes without complex undo stack

### Considerations
- Storage: Deleted tasks take up space for 30 days
- Performance: Need index on `deleted_at` column
- Background jobs: Need periodic cleanup mechanism
- UX: Clear communication about auto-delete after 30 days

### Alternative Approaches

#### Option 1: Simple Archive (Recommended for MVP)
- Add `archived` boolean instead of `deleted_at`
- Archive screen shows all archived tasks (no auto-delete)
- Simpler, no background jobs needed
- User manually clears archive

#### Option 2: Undo Toast (Lighter Weight)
- Show "Deleted [task]" with "Undo" button for 5 seconds
- Keep deleted task in memory temporarily
- If undo clicked: restore, else hard delete
- Pro: No schema changes
- Con: Only 5 second window to undo

#### Option 3: Full Revision History
- Track all changes to tasks (like Git)
- See full history, restore any version
- Pro: Maximum safety
- Con: Complex, storage-intensive

### Recommendation
Start with **Option 1 (Archive)** in Phase 3.3:
- Simpler than soft delete with auto-cleanup
- Familiar concept (email archive)
- User controls when to permanently delete
- Easy to add auto-delete later if needed

---

## 📝 Other Requested Features

*Future feature requests will be added here*

---

**How to Use This Document:**
1. Add new feature requests as they come up
2. Include user quotes and use cases
3. Estimate complexity and priority
4. Link to related GitHub issues
5. Move to implementation docs when ready
