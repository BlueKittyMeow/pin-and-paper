# Database Migration Checklist: v3 → v4

**Migration Scope:** Adding 6 new tables + multiple columns to existing `tasks` table
**Risk Level:** High (large schema change with position backfill logic)
**Rollback:** Not supported (one-way upgrade)

---

## Pre-Migration

### 1. Backup Current Database
- [ ] **Export Phase 2 database snapshot** (v3)
  - Location: `/home/bluekitty/Documents/Git/pin-and-paper/backups/phase-2-v3-snapshot.db`
  - Include timestamp in filename: `pin-and-paper-v3-YYYY-MM-DD-HHMMSS.db`
  - Verify backup file is readable and non-zero size

- [ ] **Document current data state**
  - Count of total tasks: `SELECT COUNT(*) FROM tasks;`
  - Count of drafts: `SELECT COUNT(*) FROM brain_dump_drafts;`
  - Count of API usage logs: `SELECT COUNT(*) FROM api_usage_log;`
  - Save counts to `pre-migration-stats.txt`

### 2. Create Migration Test Environment
- [ ] **Copy database to test location**
  - Test DB: `pin-and-paper-v3-test.db`
  - Keep production DB untouched during testing

- [ ] **Prepare rollback plan**
  - Document steps to restore from backup
  - Test restore procedure with dummy backup
  - Ensure app can revert to Phase 2 code + v3 database if needed

---

## Migration Script Development

### 3. Write Migration SQL
- [ ] **Create `database_helper_v4.dart` migration logic**
  - Version check: `if (oldVersion == 3 && newVersion == 4)`
  - Include all schema changes from `prelim-plan.md`

- [ ] **Task table alterations (in order):**
  ```dart
  // 1. Add nesting columns
  await db.execute('ALTER TABLE tasks ADD COLUMN parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE');
  await db.execute('ALTER TABLE tasks ADD COLUMN position INTEGER DEFAULT 0');

  // 2. Add template support
  await db.execute('ALTER TABLE tasks ADD COLUMN is_template INTEGER DEFAULT 0');

  // 3. Add due date columns
  await db.execute('ALTER TABLE tasks ADD COLUMN due_date INTEGER');
  await db.execute('ALTER TABLE tasks ADD COLUMN is_all_day INTEGER DEFAULT 1');
  await db.execute('ALTER TABLE tasks ADD COLUMN start_date INTEGER');

  // 4. Add notification columns
  await db.execute("ALTER TABLE tasks ADD COLUMN notification_type TEXT DEFAULT 'use_global'");
  await db.execute('ALTER TABLE tasks ADD COLUMN notification_time INTEGER');
  ```

- [ ] **CRITICAL: Position backfill logic**
  ```dart
  // Backfill positions based on created_at to maintain current order
  // IMPORTANT: Handles NULL parent_id correctly for top-level tasks
  await db.execute('''
    UPDATE tasks
    SET position = (
      SELECT COUNT(*)
      FROM tasks AS t2
      WHERE (
        (t2.parent_id IS NULL AND tasks.parent_id IS NULL)
        OR (t2.parent_id = tasks.parent_id)
      )
        AND t2.created_at <= tasks.created_at
    ) - 1
  ''');
  ```

- [ ] **Create new tables (6 total):**
  - [ ] task_images
  - [ ] entities
  - [ ] tags
  - [ ] task_entities
  - [ ] task_tags
  - [ ] user_settings (with default row seeding)

- [ ] **Create indexes (13 total):**
  - [ ] idx_tasks_parent
  - [ ] idx_tasks_due_date
  - [ ] idx_tasks_start_date
  - [ ] idx_tasks_template
  - [ ] idx_task_images_task
  - [ ] idx_task_images_hero
  - [ ] idx_entities_name
  - [ ] idx_tags_name
  - [ ] idx_task_entities_entity
  - [ ] idx_task_entities_task
  - [ ] idx_task_tags_tag
  - [ ] idx_task_tags_task

- [ ] **Seed user_settings table**
  ```dart
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert('user_settings', {
    'id': 1,
    'early_morning_hour': 5,
    'morning_hour': 9,
    'noon_hour': 12,
    'afternoon_hour': 15,
    'tonight_hour': 19,
    'late_night_hour': 22,
    'today_cutoff_hour': 4,
    'today_cutoff_minute': 59,
    'week_start_day': 1,
    'use_24hour_time': 0,
    'auto_complete_children': 'prompt',
    'default_notification_hour': 9,
    'default_notification_minute': 0,
    'voice_smart_punctuation': 1,
    'created_at': now,
    'updated_at': now,
  });
  ```

### 4. Add Migration Transaction Wrapper
- [ ] **CRITICAL: Enable foreign keys BEFORE migration**
  ```dart
  // SQLite disables foreign keys by default - MUST enable them!
  await db.execute('PRAGMA foreign_keys = ON');
  ```
  - Without this, the CASCADE constraint on parent_id won't work
  - Verify with testing: `PRAGMA foreign_keys;` should return 1

- [ ] **Wrap entire migration in transaction**
  ```dart
  await db.transaction((txn) async {
    // All ALTER TABLE statements
    // All CREATE TABLE statements
    // Position backfill
    // user_settings seeding
  });
  ```
  - Ensures all-or-nothing migration (rollback on any error)

---

## Dry Run Testing

### 5. Test Migration on Phase 2 Snapshot
- [ ] **Run migration on test database**
  - Use actual Phase 2 data (not empty database)
  - Monitor console for SQL errors
  - Check migration completes without exceptions

- [ ] **Verify schema changes applied**
  ```sql
  -- Check tasks table columns
  PRAGMA table_info(tasks);

  -- Expected columns: id, title, completed, created_at (v1)
  --                   + parent_id, position, is_template, due_date, is_all_day, start_date,
  --                     notification_type, notification_time (v4)
  ```

- [ ] **Verify new tables exist**
  ```sql
  SELECT name FROM sqlite_master WHERE type='table';
  ```
  - Expected: tasks, brain_dump_drafts, api_usage_log (v3)
  - Plus: task_images, entities, tags, task_entities, task_tags, user_settings (v4)

- [ ] **Verify indexes created**
  ```sql
  SELECT name FROM sqlite_master WHERE type='index';
  ```

### 6. Verify Default Values
- [ ] **Check tasks table defaults**
  ```sql
  SELECT
    parent_id,  -- Should be NULL for all existing tasks
    position,   -- Should be 0, 1, 2... (sequential, see position verification)
    is_template,  -- Should be 0
    is_all_day,   -- Should be 1
    notification_type  -- Should be 'use_global'
  FROM tasks LIMIT 10;
  ```

- [ ] **CRITICAL: Verify position backfill**
  ```sql
  -- Check that positions are sequential within parent scope
  SELECT
    id,
    title,
    parent_id,
    position,
    created_at
  FROM tasks
  WHERE parent_id IS NULL
  ORDER BY position;
  ```
  - Positions should be 0, 1, 2, 3... (no gaps, no duplicates)
  - Order should match created_at ascending
  - If positions are all 0, backfill FAILED (critical bug!)

- [ ] **Verify user_settings seeded**
  ```sql
  SELECT * FROM user_settings WHERE id = 1;
  ```
  - Should return exactly 1 row with all defaults
  - created_at and updated_at should be non-zero timestamps

### 7. Verify Data Integrity
- [ ] **Count tasks before vs after migration**
  - Pre-migration count (from step 1) should match post-migration
  - No tasks should be lost

- [ ] **Verify task content unchanged**
  ```sql
  SELECT id, title, completed, created_at FROM tasks ORDER BY created_at LIMIT 5;
  ```
  - Compare with pre-migration snapshot (same IDs, titles, states)

- [ ] **Check foreign key constraints**
  ```sql
  PRAGMA foreign_key_check;
  ```
  - Should return empty result (no FK violations)

- [ ] **Verify CASCADE delete setup**
  ```sql
  -- Check tasks table foreign key
  PRAGMA foreign_key_list(tasks);

  -- Check junction tables
  PRAGMA foreign_key_list(task_entities);
  PRAGMA foreign_key_list(task_tags);
  PRAGMA foreign_key_list(task_images);
  ```
  - All should show ON DELETE CASCADE

---

## Model & Provider Updates

### 8. Update Dart Models
- [ ] **Update `lib/models/task.dart`**
  - [ ] Add parent_id field (String?)
  - [ ] Add position field (int)
  - [ ] Add is_template field (bool)
  - [ ] Add due_date field (DateTime?)
  - [ ] Add is_all_day field (bool)
  - [ ] Add notification_type field (String)
  - [ ] Add notification_time field (DateTime?)
  - [ ] Update fromMap() constructor
  - [ ] Update toMap() method
  - [ ] Update copyWith() method (if exists)

- [ ] **Create `lib/models/user_settings.dart`**
  - All time keyword fields
  - All preference fields
  - fromMap() and toMap()

- [ ] **Create future models (minimal, for schema only)**
  - `lib/models/task_image.dart` (basic structure, no implementation)
  - `lib/models/entity.dart` (basic structure, no implementation)
  - `lib/models/tag.dart` (basic structure, no implementation)

### 9. Update Providers
- [ ] **Update `lib/providers/task_provider.dart`**
  - Handle new Task model fields
  - Update categorization logic (active/recent) for hierarchical views
  - Add methods for future: getTaskHierarchy(), getSubtasks(), etc.

- [ ] **Create `lib/providers/user_settings_provider.dart`**
  - Load user_settings from database
  - Provide time keyword preferences
  - Provide auto_complete_children preference
  - Provide notification defaults
  - Provide voice_smart_punctuation setting

### 10. Update Database Helper Queries
- [ ] **Update all SELECT queries to include new columns**
  - Or use SELECT * (safer for schema changes)
  - Ensure fromMap() handles null values for new columns

- [ ] **Update INSERT queries with new fields**
  - Set appropriate defaults for new columns
  - parent_id = null (root level)
  - position = next available position
  - is_template = false (unless saving as template)
  - notification_type = 'use_global'

- [ ] **Add user_settings query methods**
  - getUserSettings()
  - updateUserSettings()

---

## Production Migration

### 11. Pre-Production Checks
- [ ] **All dry-run tests passed**
- [ ] **Backup verified and readable**
- [ ] **Migration code reviewed**
- [ ] **No uncommitted changes in git**

### 12. Execute Production Migration
- [ ] **Close app completely**
- [ ] **Run app with updated code (database_helper v4)**
- [ ] **Monitor first launch carefully**
  - Watch console for SQL errors
  - Check app doesn't crash on launch
  - Verify onUpgrade() callback executes

- [ ] **Verify migration completed**
  - Check database version: `PRAGMA user_version;` should return 4
  - Spot-check task data still intact

### 13. Post-Migration Verification
- [ ] **App functionality check**
  - [ ] View task list (renders without errors)
  - [ ] Create new task (saves successfully)
  - [ ] Complete a task (updates in database)
  - [ ] Open Brain Dump screen (no crashes)
  - [ ] Check Settings screen (if implemented)

- [ ] **Data consistency check**
  - [ ] Task count matches pre-migration
  - [ ] All tasks display correctly
  - [ ] Task order preserved (positions working)

- [ ] **Run integration tests** (if available)
  - Verify no regressions in Phase 1/2 features

### 14. Commit Migration
- [ ] **Git commit with migration**
  ```bash
  git add lib/database/database_helper.dart
  git add lib/models/task.dart
  git add lib/models/user_settings.dart
  git add lib/providers/task_provider.dart
  git add lib/providers/user_settings_provider.dart
  git commit -m "feat(db): Migrate database v3 → v4

  - Add task nesting columns (parent_id, position)
  - Add template support (is_template)
  - Add due dates (due_date, is_all_day, start_date for multi-day tasks)
  - Add notification columns (notification_type, notification_time)
  - Create task_images table (Phase 6 future-proofing)
  - Create entities/tags tables (Phase 5 future-proofing)
  - Create user_settings table with defaults
  - Backfill task positions based on created_at
  - Add 13 performance indexes

  BREAKING CHANGE: Database v3 → v4 (no rollback)"
  ```

---

## Rollback Procedure (If Migration Fails)

### 15. Emergency Rollback
**Only if migration fails catastrophically**

- [ ] **Stop app immediately**
- [ ] **Restore database from backup**
  ```bash
  cp backups/pin-and-paper-v3-YYYY-MM-DD-HHMMSS.db \
     /data/data/com.example.pin_and_paper/databases/pin_and_paper.db
  ```

- [ ] **Revert code to Phase 2 commit**
  ```bash
  git checkout <phase-2-commit-hash>
  ```

- [ ] **Restart app**
- [ ] **Verify Phase 2 functionality restored**

- [ ] **Document failure**
  - What error occurred?
  - At what step did migration fail?
  - What was the database state?

- [ ] **Fix migration script**
- [ ] **Repeat dry-run testing before attempting production migration again**

---

## Success Criteria

- [x] Migration completes without errors
- [x] Database version = 4
- [x] All 6 new tables created
- [x] All 13 indexes created
- [x] Task count unchanged
- [x] Task positions backfilled correctly (0, 1, 2... sequential)
- [x] user_settings table has default row (id=1)
- [x] No foreign key violations
- [x] App launches successfully
- [x] All Phase 1/2 features still work
- [x] No data loss

---

## Notes

- **Migration is irreversible** - Cannot downgrade v4 → v3 without losing new columns
- **Single-user context** - Acceptable to surface failures early, can manually recover
- **Future-proofing rationale** - Adding entities/tags/images tables now avoids another complex migration later
- **Position backfill is critical** - Without it, task order becomes non-deterministic on first reorder
- **Testing is paramount** - The larger the migration, the more thorough the dry-run must be

**Estimated Time:** 4-6 hours (including dry-run testing)

**Risk Mitigation:** Transaction wrapper + extensive testing + backup = acceptable risk

---

*Checklist created by Claude based on Codex feedback in prelim-feedback.md*
*Last updated: Phase 3 Planning*
