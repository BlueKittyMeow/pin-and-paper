# Phase 3.3 Ultrathinking: Technical Deep Dive

**Author:** Claude (Sonnet 4.5)
**Date:** 2025-12-26
**Purpose:** Comprehensive technical analysis and decision-making for Recently Deleted feature

---

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Database Layer Analysis](#database-layer-analysis)
3. [Cascade Behavior Deep Dive](#cascade-behavior-deep-dive)
4. [Query Performance Optimization](#query-performance-optimization)
5. [State Management Considerations](#state-management-considerations)
6. [Edge Cases & Corner Cases](#edge-cases--corner-cases)
7. [Migration Strategy](#migration-strategy)
8. [Testing Strategy](#testing-strategy)
9. [Potential Pitfalls](#potential-pitfalls)
10. [Implementation Sequence](#implementation-sequence)

---

## Architecture Overview

### System Layers
```
┌─────────────────────────────────────────┐
│         UI Layer (Widgets)              │
│  - RecentlyDeletedScreen                │
│  - DeletedTaskItem                      │
│  - Updated DeleteTaskDialog             │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│      State Management (Provider)        │
│  - TaskProvider                         │
│    - softDeleteTask()                   │
│    - restoreTask()                      │
│    - permanentlyDeleteTask()            │
│    - emptyTrash()                       │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│     Business Logic (TaskService)        │
│  - softDeleteTask() + CASCADE           │
│  - restoreTask() + CASCADE              │
│  - getRecentlyDeletedTasks()            │
│  - cleanupOldDeletedTasks()             │
│  - Query filtering (deleted_at IS NULL) │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│      Database Layer (SQLite)            │
│  - tasks table + deleted_at column      │
│  - Indexes for performance              │
│  - Foreign key CASCADE (hard delete)    │
└─────────────────────────────────────────┘
```

### Data Flow: Soft Delete
```
User taps "Move to Trash"
  ↓
UI: DeleteTaskDialog confirms
  ↓
Provider: taskProvider.deleteTask(taskId)
  ↓
Service: taskService.softDeleteTask(taskId)
  ↓
Database: UPDATE tasks SET deleted_at = ? WHERE id = ? OR parent_id = ?
  ↓
Service: Returns success
  ↓
Provider: notifyListeners()
  ↓
UI: Task disappears, snackbar shows "Moved to trash"
```

### Data Flow: Restore
```
User taps "Restore" in Recently Deleted
  ↓
Provider: taskProvider.restoreTask(taskId)
  ↓
Service: taskService.restoreTask(taskId)
  ↓
Database: UPDATE tasks SET deleted_at = NULL WHERE id = ? OR parent_id = ?
  ↓
Service: Returns success
  ↓
Provider: Refreshes task lists, notifyListeners()
  ↓
UI: Task reappears in home screen
```

---

## Database Layer Analysis

### Schema Changes (v4 → v5)

**Current Schema (v4):**
```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  completed INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  completed_at INTEGER,
  due_date INTEGER,
  is_all_day INTEGER DEFAULT 1,
  start_date INTEGER,
  parent_id TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  is_template INTEGER DEFAULT 0,
  notification_type TEXT DEFAULT 'use_global',
  notification_time INTEGER,
  FOREIGN KEY (parent_id) REFERENCES tasks(id) ON DELETE CASCADE
);
```

**New Schema (v5):**
```sql
ALTER TABLE tasks ADD COLUMN deleted_at INTEGER DEFAULT NULL;

-- Index for filtering active tasks
CREATE INDEX idx_tasks_deleted_at ON tasks(deleted_at);

-- Compound index for common query pattern
CREATE INDEX idx_tasks_active ON tasks(deleted_at, completed, created_at DESC)
  WHERE deleted_at IS NULL;
```

### Why Timestamp Instead of Boolean?

**Option A: Boolean `is_deleted`**
```sql
ALTER TABLE tasks ADD COLUMN is_deleted INTEGER DEFAULT 0;
```
- ❌ Cannot display "Deleted X days ago"
- ❌ Cannot implement time-based cleanup
- ❌ Less information for debugging

**Option B: Timestamp `deleted_at`** ✅ CHOSEN
```sql
ALTER TABLE tasks ADD COLUMN deleted_at INTEGER DEFAULT NULL;
```
- ✅ Enables "Deleted X days ago" display
- ✅ Enables automatic cleanup (WHERE deleted_at < threshold)
- ✅ Audit trail (when was task deleted?)
- ✅ Nullable (NULL = active, timestamp = deleted)
- ✅ Matches iOS/Android conventions

### Index Strategy

**Why We Need `idx_tasks_deleted_at`:**
- All active task queries add `WHERE deleted_at IS NULL`
- Without index: Full table scan on every query
- With index: Fast lookup using B-tree

**Why We Need Compound Index `idx_tasks_active`:**
```sql
-- Common query pattern:
SELECT * FROM tasks
WHERE deleted_at IS NULL
  AND completed = 0
ORDER BY created_at DESC;
```
- Compound index covers entire query
- Eliminates need for separate sort operation
- Massive performance gain on large datasets

**Partial Index Benefits:**
- `WHERE deleted_at IS NULL` clause makes it partial index
- Only indexes active tasks (smaller index)
- Faster inserts/updates (fewer index entries)
- Lower storage overhead

**Index Size Estimation:**
- Assume 10,000 tasks
- Active tasks: ~9,500 (95%)
- Deleted tasks: ~500 (5%, within 30 days)
- Full index size: ~80 KB
- Partial index size: ~76 KB (saves 4 KB)
- **Takeaway:** Modest size savings, huge query speed gain

---

## Cascade Behavior Deep Dive

### The Challenge: Soft Delete CASCADE

**SQLite's CASCADE only works for hard deletes:**
```sql
FOREIGN KEY (parent_id) REFERENCES tasks(id) ON DELETE CASCADE
```
- This CASCADE triggers on `DELETE FROM tasks WHERE id = ?`
- Does NOT trigger on `UPDATE tasks SET deleted_at = ?`

**Therefore, we must implement soft delete CASCADE manually.**

### Approach 1: Recursive CTE (Complex, Elegant)

```sql
WITH RECURSIVE descendants AS (
  -- Base case: the task we're deleting
  SELECT id FROM tasks WHERE id = ?

  UNION ALL

  -- Recursive case: all children, grandchildren, etc.
  SELECT tasks.id
  FROM tasks
  INNER JOIN descendants ON tasks.parent_id = descendants.id
)
UPDATE tasks
SET deleted_at = ?
WHERE id IN (SELECT id FROM descendants);
```

**Pros:**
- ✅ Single query handles entire hierarchy
- ✅ Automatically handles arbitrary depth
- ✅ Efficient (single pass)

**Cons:**
- ❌ Complex to understand and maintain
- ❌ Harder to debug if issues arise
- ❌ SQLite CTE support varies by version

### Approach 2: Iterative Breadth-First (Simpler, Reliable) ✅ CHOSEN

```dart
Future<void> softDeleteTask(String taskId) async {
  final db = await database;
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  await db.transaction((txn) async {
    // 1. Soft delete the parent
    await txn.update(
      'tasks',
      {'deleted_at': timestamp},
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // 2. Soft delete all descendants iteratively
    List<String> currentLevel = [taskId];

    while (currentLevel.isNotEmpty) {
      // Find children of current level
      final children = await txn.query(
        'tasks',
        columns: ['id'],
        where: 'parent_id IN (${currentLevel.map((_) => '?').join(',')})',
        whereArgs: currentLevel,
      );

      if (children.isEmpty) break;

      // Soft delete this level
      final childIds = children.map((c) => c['id'] as String).toList();
      await txn.update(
        'tasks',
        {'deleted_at': timestamp},
        where: 'id IN (${childIds.map((_) => '?').join(',')})',
        whereArgs: childIds,
      );

      currentLevel = childIds;
    }
  });
}
```

**Pros:**
- ✅ Easy to understand and debug
- ✅ Works on all SQLite versions
- ✅ Transaction ensures atomicity
- ✅ Same timestamp for all tasks (important for restore)

**Cons:**
- ❌ Multiple queries (but within transaction)
- ❌ Slightly less elegant than CTE

**Why Iterative is Better:**
1. **Debugging:** Can log each level for troubleshooting
2. **Testing:** Easier to write unit tests
3. **Compatibility:** No SQLite version concerns
4. **Performance:** Transaction makes it fast enough

### Restore CASCADE: Same Strategy

```dart
Future<void> restoreTask(String taskId) async {
  final db = await database;

  await db.transaction((txn) async {
    // 1. Restore the parent
    await txn.update(
      'tasks',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // 2. Restore all descendants iteratively
    List<String> currentLevel = [taskId];

    while (currentLevel.isNotEmpty) {
      final children = await txn.query(
        'tasks',
        columns: ['id'],
        where: 'parent_id IN (${currentLevel.map((_) => '?').join(',')}) AND deleted_at IS NOT NULL',
        whereArgs: currentLevel,
      );

      if (children.isEmpty) break;

      final childIds = children.map((c) => c['id'] as String).toList();
      await txn.update(
        'tasks',
        {'deleted_at': null},
        where: 'id IN (${childIds.map((_) => '?').join(',')})',
        whereArgs: childIds,
      );

      currentLevel = childIds;
    }
  });
}
```

**Critical Detail: Same Timestamp for All Tasks**
- All tasks in hierarchy get SAME deleted_at timestamp
- Important for: "This was deleted as a group"
- Enables: Restore entire group together
- Prevents: Partial restores that break hierarchy

---

## Query Performance Optimization

### Problem: Every Query Needs Filtering

**Before Phase 3.3:**
```sql
SELECT * FROM tasks;
```

**After Phase 3.3:**
```sql
SELECT * FROM tasks WHERE deleted_at IS NULL;
```

**Impact Analysis:**
- **Without index:** Full table scan every time (O(n))
- **With index:** Index lookup + pointer follow (O(log n))
- **Difference at 10,000 tasks:** 10,000 rows scanned vs. ~14 index lookups

### Index Coverage Test

**Query 1: Get All Active Tasks**
```sql
EXPLAIN QUERY PLAN
SELECT * FROM tasks WHERE deleted_at IS NULL;
```
Expected: `SEARCH TABLE tasks USING INDEX idx_tasks_deleted_at (deleted_at=?)`

**Query 2: Get Active Tasks Sorted**
```sql
EXPLAIN QUERY PLAN
SELECT * FROM tasks
WHERE deleted_at IS NULL
ORDER BY created_at DESC;
```
Expected: `SEARCH TABLE tasks USING INDEX idx_tasks_active`

**Query 3: Get Recently Deleted**
```sql
EXPLAIN QUERY PLAN
SELECT * FROM tasks
WHERE deleted_at IS NOT NULL
ORDER BY deleted_at DESC;
```
Expected: `SEARCH TABLE tasks USING INDEX idx_tasks_deleted_at (deleted_at>?)`

### Partial Index Trade-offs

**Full Index:**
```sql
CREATE INDEX idx_tasks_active ON tasks(deleted_at, completed, created_at DESC);
```
- Indexes ALL tasks (active + deleted)
- Size: ~80 KB for 10,000 tasks
- Useful for both active and deleted queries

**Partial Index:**
```sql
CREATE INDEX idx_tasks_active ON tasks(deleted_at, completed, created_at DESC)
  WHERE deleted_at IS NULL;
```
- Indexes only active tasks
- Size: ~76 KB for 10,000 tasks (assuming 95% active)
- NOT useful for deleted task queries
- Faster inserts (fewer index updates)

**Decision:** Use partial index for active tasks, separate index for deleted_at
- `idx_tasks_deleted_at` - All tasks (for both active and deleted queries)
- `idx_tasks_active` - Partial index for common active task queries

### Query Audit Checklist

All existing queries must be updated to exclude deleted tasks:

- [ ] `getAllTasks()` → `WHERE deleted_at IS NULL`
- [ ] `getTaskHierarchy()` → `WHERE deleted_at IS NULL`
- [ ] `getTaskWithDescendants()` → `WHERE deleted_at IS NULL`
- [ ] `searchTasks()` → `WHERE deleted_at IS NULL`
- [ ] `getTasksByDueDate()` → `WHERE deleted_at IS NULL`
- [ ] `getTasksByStartDate()` → `WHERE deleted_at IS NULL`
- [ ] `getTemplates()` → `WHERE deleted_at IS NULL`
- [ ] Any raw SQL queries in the codebase

**Testing Strategy:**
1. Write unit test that creates task, soft deletes it, queries for active tasks
2. Verify soft-deleted task does NOT appear in results
3. Repeat for all query methods

---

## State Management Considerations

### TaskProvider Changes

**Current deleteTask Method:**
```dart
Future<void> deleteTask(String taskId) async {
  await _taskService.deleteTask(taskId);  // Hard delete
  await loadTasks();
  notifyListeners();
}
```

**New deleteTask Method:**
```dart
Future<void> deleteTask(String taskId) async {
  await _taskService.softDeleteTask(taskId);  // Soft delete
  await loadTasks();  // Reloads active tasks (excludes deleted)
  notifyListeners();
}
```

**Key Changes:**
- Method signature unchanged (backward compatible)
- Underlying behavior changes to soft delete
- UI remains the same (task disappears)
- User can now restore from Recently Deleted

### New Provider Methods

```dart
// Restore a soft-deleted task
Future<void> restoreTask(String taskId) async {
  await _taskService.restoreTask(taskId);
  await loadTasks();  // Refresh active task list
  notifyListeners();
}

// Permanently delete (hard delete)
Future<void> permanentlyDeleteTask(String taskId) async {
  await _taskService.permanentlyDeleteTask(taskId);
  // No need to reload (task already hidden)
  notifyListeners();
}

// Empty trash (hard delete all soft-deleted tasks)
Future<void> emptyTrash() async {
  await _taskService.emptyTrash();
  notifyListeners();
}

// Get recently deleted tasks
Future<List<Task>> getRecentlyDeletedTasks() async {
  return await _taskService.getRecentlyDeletedTasks();
}
```

### Badge Count Reactivity

**Challenge:** Settings screen badge must update when trash count changes

**Solution 1: Polling (Simple, Inefficient)**
```dart
Timer.periodic(Duration(seconds: 5), (_) async {
  final count = await taskService.countRecentlyDeletedTasks();
  if (count != _lastCount) {
    notifyListeners();
  }
});
```
❌ Wasteful, delays, not reactive

**Solution 2: Reactive Count (Efficient)** ✅ CHOSEN
```dart
class TaskProvider extends ChangeNotifier {
  int _deletedTaskCount = 0;

  int get deletedTaskCount => _deletedTaskCount;

  Future<void> updateDeletedTaskCount() async {
    _deletedTaskCount = await _taskService.countRecentlyDeletedTasks();
    notifyListeners();
  }

  // Call after any delete/restore/empty operation
  Future<void> deleteTask(String taskId) async {
    await _taskService.softDeleteTask(taskId);
    await loadTasks();
    await updateDeletedTaskCount();  // Update badge count
    notifyListeners();
  }
}
```

**Settings Screen Badge:**
```dart
ListTile(
  title: Text('Recently Deleted'),
  trailing: Consumer<TaskProvider>(
    builder: (context, provider, child) {
      final count = provider.deletedTaskCount;
      return count > 0
        ? Badge(label: Text('$count'))
        : SizedBox.shrink();
    },
  ),
  onTap: () => Navigator.push(...),
)
```

---

## Edge Cases & Corner Cases

### 1. Orphaned Children After Parent Permanent Delete

**Scenario:**
1. Soft delete Parent → Children (all get deleted_at set)
2. User permanently deletes Parent from trash
3. Foreign key CASCADE hard deletes children too
4. Children are now gone forever, even though they were in trash

**Question:** Is this desired behavior?

**Option A: Allow CASCADE (Current FK Constraint)**
- Parent permanent delete → Children also permanently deleted
- Pro: Matches soft delete CASCADE (symmetrical)
- Pro: Prevents orphans
- Con: User can't restore children separately

**Option B: Prevent Parent Permanent Delete Until Children Restored**
- Check if task has deleted children before permanent delete
- Show error: "Restore or permanently delete children first"
- Pro: Explicit user control
- Con: More complex UX

**Option C: Restore Children When Parent Permanently Deleted**
- Before permanent delete, restore all deleted children
- Children become root tasks
- Pro: Prevents data loss
- Con: Unexpected behavior (children reappear)

**Recommendation: Option A** ✅
- Matches user mental model: deleting parent deletes children
- Simpler implementation (leverage existing CASCADE)
- If user wants children, they restore parent first
- Consistent with soft delete behavior

### 2. Restoring Orphaned Child (Parent Permanently Deleted)

**Scenario:**
1. Soft delete Parent → Children
2. User permanently deletes Parent only
3. Children still soft-deleted, but parent_id points to non-existent task
4. User tries to restore Child

**Solution:**
```dart
Future<void> restoreTask(String taskId) async {
  final db = await database;
  final task = await getTask(taskId);

  if (task.parentId != null) {
    // Check if parent exists
    final parent = await getTask(task.parentId!);
    if (parent == null) {
      // Parent was permanently deleted → make child a root task
      await db.update(
        'tasks',
        {'deleted_at': null, 'parent_id': null},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      return;
    }

    // Check if parent is also deleted
    if (parent.deletedAt != null) {
      throw Exception('Cannot restore child without restoring parent first');
    }
  }

  // Normal restore
  await db.update(
    'tasks',
    {'deleted_at': null},
    where: 'id = ?',
    whereArgs: [taskId],
  );
}
```

**Decision:** Restore orphan as root task ✅
- User can always re-nest it manually
- Prevents data loss
- Better UX than throwing error

### 3. Soft Delete During Drag-and-Drop

**Scenario:**
1. User enters reorder mode
2. User long-presses task (initiates drag)
3. Context menu appears instead of drag
4. User selects "Move to Trash"
5. Task soft deleted while in reorder mode

**Solution:** No special handling needed
- Soft delete removes task from active list
- Reorder mode state unaffected
- User continues reordering remaining tasks
- Test this scenario explicitly

### 4. Restore Task with Due Date in Past

**Scenario:**
1. Task has due_date = 2024-12-20
2. Task soft deleted on 2024-12-25
3. User restores task on 2025-01-15
4. Due date is 26 days in past

**Question:** Should we update due date on restore?

**Option A: Keep Original Due Date** ✅ CHOSEN
- Preserve data integrity
- User can manually update if needed
- Past due dates might be intentional (historical tracking)

**Option B: Prompt User to Update**
- "This task's due date is in the past. Update to today?"
- Pro: Helpful UX
- Con: Extra modal, interrupts flow

**Recommendation: Option A**
- Simpler, respects user data
- Future enhancement: Show warning badge on task

### 5. Cleanup Runs While User in Recently Deleted Screen

**Scenario:**
1. User navigating Recently Deleted screen
2. App launch cleanup runs in background
3. Tasks deleted on 31 days ago disappear mid-session

**Solution: Debounce Cleanup**
```dart
bool _cleanupRunning = false;

Future<void> cleanupOldDeletedTasks() async {
  if (_cleanupRunning) return;
  _cleanupRunning = true;

  try {
    // Run cleanup
    final count = await _taskService.cleanupOldDeletedTasks();
    if (count > 0) {
      // Refresh UI if needed
      notifyListeners();
    }
  } finally {
    _cleanupRunning = false;
  }
}
```

**Also: Run cleanup only on app launch, not on navigation**
```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run cleanup async (non-blocking)
  TaskService.instance.cleanupOldDeletedTasks();

  runApp(MyApp());
}
```

### 6. Very Large Hierarchies (100+ Tasks)

**Scenario:**
1. User has Parent with 100 children
2. User soft deletes Parent
3. Iterative CASCADE must update 101 tasks

**Performance Consideration:**
- Each level requires query + update
- 100 children = 1 query, 1 batch update
- Wrapped in transaction (atomic, fast)

**Optimization: Batch Updates**
```dart
// Instead of updating one by one:
for (final childId in childIds) {
  await txn.update('tasks', {'deleted_at': timestamp},
    where: 'id = ?', whereArgs: [childId]);
}

// Batch update all at once:
await txn.update('tasks', {'deleted_at': timestamp},
  where: 'id IN (${childIds.map((_) => '?').join(',')})',
  whereArgs: childIds);
```

**Result:** 100 individual updates → 1 batch update (100x faster)

---

## Migration Strategy

### Migration Safety Checklist

✅ **Backward Compatible:** New column is nullable (DEFAULT NULL)
✅ **Existing Data Unaffected:** All current tasks have deleted_at = NULL
✅ **Indexes Created After Column:** Prevents index errors
✅ **Transaction Wrapped:** Migration atomic (all or nothing)
✅ **Version Bump:** v4 → v5 (prevents re-run)
✅ **Rollback Plan:** Can drop column if needed (rare)

### Migration Code

```dart
Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  debugPrint('Upgrading database from v$oldVersion to v$newVersion');

  if (oldVersion < 5) {
    await _migrateToV5(db);
  }
}

Future<void> _migrateToV5(Database db) async {
  debugPrint('Migrating to v5: Adding soft delete support');

  await db.transaction((txn) async {
    // 1. Add deleted_at column
    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN deleted_at INTEGER DEFAULT NULL
    ''');

    debugPrint('Added deleted_at column');

    // 2. Create index for performance
    await txn.execute('''
      CREATE INDEX idx_tasks_deleted_at
      ON ${AppConstants.tasksTable}(deleted_at)
    ''');

    debugPrint('Created idx_tasks_deleted_at index');

    // 3. Create compound partial index for active tasks
    await txn.execute('''
      CREATE INDEX idx_tasks_active
      ON ${AppConstants.tasksTable}(deleted_at, completed, created_at DESC)
      WHERE deleted_at IS NULL
    ''');

    debugPrint('Created idx_tasks_active index');
  });

  debugPrint('Migration to v5 complete');
}
```

### Testing Migration

**Unit Test:**
```dart
test('Migration v4 to v5 adds deleted_at column and indexes', () async {
  // 1. Create v4 database
  final db = await createTestDatabaseV4();

  // 2. Insert test data
  await db.insert('tasks', {
    'id': 'task1',
    'title': 'Test Task',
    'completed': 0,
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'position': 0,
  });

  // 3. Close database
  await db.close();

  // 4. Reopen with v5 (triggers migration)
  final db5 = await openDatabase(
    testDbPath,
    version: 5,
    onUpgrade: _upgradeDB,
  );

  // 5. Verify schema
  final columns = await db5.rawQuery('PRAGMA table_info(tasks)');
  expect(columns.any((col) => col['name'] == 'deleted_at'), true);

  // 6. Verify indexes
  final indexes = await db5.rawQuery('PRAGMA index_list(tasks)');
  expect(indexes.any((idx) => idx['name'] == 'idx_tasks_deleted_at'), true);
  expect(indexes.any((idx) => idx['name'] == 'idx_tasks_active'), true);

  // 7. Verify existing data unchanged
  final tasks = await db5.query('tasks');
  expect(tasks.length, 1);
  expect(tasks[0]['deleted_at'], null);
  expect(tasks[0]['title'], 'Test Task');
});
```

---

## Testing Strategy

### Test Pyramid

```
       ┌───────────────┐
       │  Integration  │  ← 10 tests (complex flows)
       │     Tests     │
       ├───────────────┤
       │  Widget Tests │  ← 20 tests (UI components)
       ├───────────────┤
       │  Unit Tests   │  ← 40 tests (business logic)
       └───────────────┘
```

### Critical Test Cases (Must Pass)

1. **Soft Delete CASCADE:**
   - Parent + 3 children → Soft delete parent
   - Verify all 4 have same deleted_at timestamp
   - Verify none appear in getAllTasks()

2. **Restore CASCADE:**
   - Restore parent from test #1
   - Verify all 4 have deleted_at = NULL
   - Verify all appear in getAllTasks() in correct hierarchy

3. **Permanent Delete CASCADE:**
   - Soft delete parent + children
   - Permanently delete parent
   - Verify all hard deleted (FK CASCADE works)

4. **Query Exclusion:**
   - Create 10 tasks, soft delete 3
   - Verify getAllTasks() returns 7
   - Verify getRecentlyDeletedTasks() returns 3

5. **Cleanup Old Tasks:**
   - Create task, set deleted_at to 31 days ago
   - Run cleanup
   - Verify task hard deleted

6. **Migration v4 → v5:**
   - Create v4 database with test data
   - Run migration
   - Verify column added, indexes created, data intact

### Performance Benchmarks

**Target Metrics:**
- Soft delete 100-task hierarchy: < 500ms
- Restore 100-task hierarchy: < 500ms
- Query 10,000 active tasks (with deleted): < 100ms
- Cleanup 1,000 old tasks: < 1s

**How to Test:**
```dart
test('Soft delete performance benchmark', () async {
  // Create 100-task hierarchy
  final parentId = await createTaskHierarchy(depth: 3, childrenPerLevel: 10);
  // Total: 1 + 10 + 100 = 111 tasks

  // Benchmark soft delete
  final stopwatch = Stopwatch()..start();
  await taskService.softDeleteTask(parentId);
  stopwatch.stop();

  expect(stopwatch.elapsedMilliseconds, lessThan(500));
});
```

---

## Potential Pitfalls

### Pitfall 1: Forgetting to Filter Queries

**Risk:** New query added, forgets `WHERE deleted_at IS NULL`
**Impact:** Deleted tasks appear in UI (critical bug)

**Mitigation:**
1. Code review checklist: "Does this query filter deleted tasks?"
2. Integration test: Create deleted task, verify it doesn't appear
3. Linter rule (future): Warn on queries without deleted_at filter
4. Base query method that always filters:

```dart
Future<List<Task>> _queryActiveTasks(String where, List<dynamic> args) async {
  final db = await database;
  final results = await db.query(
    AppConstants.tasksTable,
    where: '($where) AND deleted_at IS NULL',
    whereArgs: args,
  );
  return results.map((r) => Task.fromMap(r)).toList();
}
```

### Pitfall 2: Race Condition: Cleanup During Restore

**Risk:** User restores task while cleanup is running
**Impact:** Task restored then immediately deleted

**Mitigation:** Transaction isolation
```dart
Future<void> restoreTask(String taskId) async {
  await db.transaction((txn) async {
    // Check task still exists and is deleted
    final task = await txn.query('tasks', where: 'id = ?', whereArgs: [taskId]);
    if (task.isEmpty) throw Exception('Task not found');
    if (task.first['deleted_at'] == null) throw Exception('Task not deleted');

    // Restore
    await txn.update('tasks', {'deleted_at': null}, where: 'id = ?', whereArgs: [taskId]);
  });
}
```

### Pitfall 3: Index Not Used (Performance Degradation)

**Risk:** Query doesn't use index, falls back to full scan
**Impact:** App becomes slow with many tasks

**Mitigation: ** Test query plans
```dart
test('Verify index usage', () async {
  final db = await database;
  final plan = await db.rawQuery(
    'EXPLAIN QUERY PLAN SELECT * FROM tasks WHERE deleted_at IS NULL'
  );

  expect(
    plan.any((row) => row['detail'].contains('idx_tasks_deleted_at')),
    true,
    reason: 'Query should use idx_tasks_deleted_at index',
  );
});
```

### Pitfall 4: Migration Fails on Large Database

**Risk:** User has 50,000 tasks, migration takes 10 seconds, app ANR
**Impact:** App hangs on startup

**Mitigation:**
1. Test migration on large dataset (simulate 50k tasks)
2. Add progress indicator during migration (future enhancement)
3. Migration is transaction-wrapped (atomic, can't corrupt data)

```dart
test('Migration performance on large dataset', () async {
  // Create 50,000 tasks in v4 database
  final db = await createLargeTestDatabase(taskCount: 50000);
  await db.close();

  // Time the migration
  final stopwatch = Stopwatch()..start();
  final db5 = await openDatabase(testDbPath, version: 5, onUpgrade: _upgradeDB);
  stopwatch.stop();

  expect(stopwatch.elapsedMilliseconds, lessThan(5000),
    reason: 'Migration should complete in under 5 seconds');
});
```

---

## Implementation Sequence

### Phase 1: Database Foundation (Day 1, Morning)
1. ✅ Update `AppConstants.databaseVersion` to 5
2. ✅ Implement migration `_migrateToV5()`
3. ✅ Update `_createDB()` to include deleted_at for fresh installs
4. ✅ Write migration unit tests
5. ✅ Test on device (backup database first!)

### Phase 2: TaskService Layer (Day 1, Afternoon)
1. ✅ Implement `softDeleteTask()` with iterative CASCADE
2. ✅ Implement `restoreTask()` with iterative CASCADE
3. ✅ Implement `permanentlyDeleteTask()`
4. ✅ Implement `getRecentlyDeletedTasks()`
5. ✅ Implement `countRecentlyDeletedTasks()`
6. ✅ Implement `emptyTrash()`
7. ✅ Implement `cleanupOldDeletedTasks()`
8. ✅ Write comprehensive unit tests

### Phase 3: Query Updates (Day 1, Evening)
1. ✅ Audit all existing query methods
2. ✅ Add `WHERE deleted_at IS NULL` to each
3. ✅ Test query exclusions
4. ✅ Verify no regressions

### Phase 4: TaskProvider Updates (Day 2, Morning)
1. ✅ Update `deleteTask()` to call `softDeleteTask()`
2. ✅ Add `restoreTask()` method
3. ✅ Add `permanentlyDeleteTask()` method
4. ✅ Add `emptyTrash()` method
5. ✅ Add deleted task count tracking
6. ✅ Test provider state management

### Phase 5: UI - Recently Deleted Screen (Day 2, Afternoon)
1. ✅ Create `RecentlyDeletedScreen` widget
2. ✅ Create `DeletedTaskItem` widget
3. ✅ Implement timestamp formatting ("Deleted X days ago")
4. ✅ Implement breadcrumb display
5. ✅ Implement Restore button
6. ✅ Implement Delete Permanently button
7. ✅ Implement Empty Trash button
8. ✅ Implement empty state
9. ✅ Write widget tests

### Phase 6: UI - Dialog Updates (Day 2, Evening)
1. ✅ Update `DeleteTaskDialog` text and button
2. ✅ Create `PermanentDeleteDialog`
3. ✅ Create `EmptyTrashDialog`
4. ✅ Update context menu text
5. ✅ Test dialog flows

### Phase 7: Settings Integration (Day 3, Morning)
1. ✅ Add "Recently Deleted" menu item to Settings
2. ✅ Implement badge with count
3. ✅ Wire up navigation
4. ✅ Test Settings → Recently Deleted flow

### Phase 8: Cleanup Integration (Day 3, Afternoon)
1. ✅ Add cleanup call in `main.dart`
2. ✅ Test cleanup on app launch
3. ✅ Test cleanup with various date thresholds
4. ✅ Verify cleanup doesn't block UI

### Phase 9: Integration Testing (Day 3, Evening)
1. ✅ Write soft delete → restore integration test
2. ✅ Write hierarchical soft delete integration test
3. ✅ Write automatic cleanup integration test
4. ✅ Write empty trash integration test
5. ✅ Manual testing on Android device

### Phase 10: Documentation & Cleanup (Day 4, if needed)
1. ✅ Update code documentation
2. ✅ Update README (if applicable)
3. ✅ Create test results document
4. ✅ Code review and refinement
5. ✅ Merge to main

---

## Summary of Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Soft Delete Column** | `deleted_at` timestamp | Enables "X days ago" display, time-based cleanup |
| **CASCADE Strategy** | Iterative breadth-first | Simpler, more debuggable than recursive CTE |
| **Index Strategy** | Separate + partial indexes | Balances query speed and storage |
| **Orphan Handling** | Restore as root task | Prevents data loss, user can re-nest |
| **Cleanup Timing** | App launch (async) | Simpler than background jobs, sufficient frequency |
| **Migration Safety** | Transaction-wrapped, backward compatible | Ensures data integrity, safe rollback |
| **Permanent Delete** | FK CASCADE works | Consistent with soft delete CASCADE behavior |

---

## Conclusion

Phase 3.3 adds a critical safety net for users while maintaining app performance. The soft delete system is:

- **User-Friendly:** Familiar "Recently Deleted" UX from iOS/Android
- **Safe:** 30-day window to restore accidentally deleted tasks
- **Performant:** Indexed queries, async cleanup, batch updates
- **Maintainable:** Clear code, comprehensive tests, good documentation
- **Extensible:** Can add features like user-configurable thresholds later

**Estimated Complexity:** Medium
**Estimated Duration:** 2-3 days
**Risk Level:** Low (well-tested migration, backward compatible)

Ready to implement! 🚀
