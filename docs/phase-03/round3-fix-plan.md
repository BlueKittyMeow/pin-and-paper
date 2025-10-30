# Round 3 Tactical Fix Plan

**Date:** 2025-10-30
**Analyst:** Claude
**Status:** Ready for execution

---

## Executive Summary

This document provides **step-by-step instructions** for applying all Round 3 fixes. Each fix includes:
- Exact file locations and line numbers
- Complete code to add/remove
- Verification steps
- Dependencies on other fixes

**Execution Order:** Follow phases 1-5 in sequence.

---

## Team Feedback Incorporated (Round 3.5)

**Date:** 2025-10-30
**Reviewers:** Gemini, Codex

### Critical Updates from Team Review

**1. CRITICAL - Task.copyWith Completeness (Codex)**
- **Issue:** Phase 2 optimistic update in `onNodeAccepted` created new Task() with only subset of fields
- **Impact:** Would silently strip startDate, isTemplate, notificationType, notificationTime, etc. on every drag
- **Fix Applied:** Changed to `movedTask.copyWith(parentId:..., position:..., depth:...)` (lines 429-433)
- **Status:** ✅ FIXED in Phase 2 Step 2.5

**2. HIGH - TreeController Expansion State (Codex)**
- **Issue:** Plan kept `_collapsedTaskIds` Set and old `toggleCollapse` logic after moving to TreeController
- **Impact:** TreeController owns expansion state - toggling Set wouldn't affect UI, nodes would never collapse
- **Fix Applied:**
  - Phase 2 Step 2.6: Added `toggleCollapse(Task task)` that calls `treeController.toggleExpansion()`
  - Phase 4 Steps 4.1-4.2: Removed `_collapsedTaskIds` Set and old `toggleCollapse(String taskId)` method
  - Phase 4 Steps 4.4-4.5: Updated both HomeScreen modes to pass `entry.isExpanded`
  - Phase 5: Renamed `isCollapsed` to `isExpanded` in TaskItem signature, updated icon logic
- **Status:** ✅ FIXED across Phases 2, 4, and 5

**3. UX Enhancement - Depth Limit Feedback (Gemini)**
- **Issue:** `_showDepthLimitError()` only sets error message in provider state
- **Recommendation:** Trigger SnackBar/Toast for immediate visual feedback
- **Fix Applied:** Added TODO comment for UX refinement (line 447)
- **Status:** ✅ NOTED for future enhancement

**4. Task.copyWith Reminder (Gemini)**
- **Issue:** Optimistic update comment said `// ... other fields` without expansion
- **Fix Applied:** Now uses `.copyWith()` which automatically preserves all fields
- **Status:** ✅ FIXED (covered by fix #1)

### Review Praise Points
- ✅ Complete replacement of _createDB mirroring _migrateToV4 (Phase 1)
- ✅ Decisive removal of legacy code (Phase 3)
- ✅ Single source of truth for visibility (Phase 4)
- ✅ Detailed verification checklists (all phases)
- ✅ Root cause analysis identifying "Incomplete Replacement Pattern"

---

## Phase 1: Fix _createDB Schema (CRITICAL)

**File:** `docs/phase-03/group1.md`
**Location:** Lines 790-969
**Estimated Time:** 45 minutes
**Risk:** HIGH - Must be exact

### Step 1.1: Replace Entire _createDB Function

**Action:** Delete lines 790-969 and replace with corrected version

**New Implementation:**
```dart
/// Create database from scratch (fresh installs)
///
/// CRITICAL: This creates the COMPLETE Phase 3 (v4) schema.
/// Must match the end state of _migrateToV4 EXACTLY to ensure parity.
Future<void> _createDB(Database db, int version) async {
  // ===========================================
  // 1. CREATE TASKS TABLE (with ALL Phase 3 columns)
  // ===========================================

  await db.execute('''
    CREATE TABLE ${AppConstants.tasksTable} (
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

      FOREIGN KEY (parent_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
    )
  ''');

  // ===========================================
  // 2. CREATE USER SETTINGS TABLE
  // ===========================================

  await db.execute('''
    CREATE TABLE ${AppConstants.userSettingsTable} (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      early_morning_hour INTEGER DEFAULT 5,
      morning_hour INTEGER DEFAULT 9,
      noon_hour INTEGER DEFAULT 12,
      afternoon_hour INTEGER DEFAULT 15,
      tonight_hour INTEGER DEFAULT 19,
      late_night_hour INTEGER DEFAULT 22,
      today_cutoff_hour INTEGER DEFAULT 4,
      today_cutoff_minute INTEGER DEFAULT 59,
      week_start_day INTEGER DEFAULT 1,
      timezone_id TEXT,
      use_24hour_time INTEGER DEFAULT 0,
      auto_complete_children TEXT DEFAULT 'prompt',
      default_notification_hour INTEGER DEFAULT 9,
      default_notification_minute INTEGER DEFAULT 0,
      voice_smart_punctuation INTEGER DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  // ===========================================
  // 3. CREATE AUXILIARY TABLES
  // ===========================================

  // Brain dump drafts (from Phase 2)
  await db.execute('''
    CREATE TABLE ${AppConstants.brainDumpDraftsTable} (
      id TEXT PRIMARY KEY,
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      last_modified INTEGER NOT NULL
    )
  ''');

  // API usage log (from Phase 2)
  await db.execute('''
    CREATE TABLE ${AppConstants.apiUsageLogTable} (
      id TEXT PRIMARY KEY,
      timestamp INTEGER NOT NULL,
      operation_type TEXT NOT NULL,
      input_tokens INTEGER NOT NULL,
      output_tokens INTEGER NOT NULL,
      estimated_cost_usd REAL NOT NULL,
      model_name TEXT NOT NULL
    )
  ''');

  // Task images (Phase 6 - future-proofing)
  await db.execute('''
    CREATE TABLE ${AppConstants.taskImagesTable} (
      id TEXT PRIMARY KEY,
      task_id TEXT NOT NULL,
      file_path TEXT NOT NULL,
      source_url TEXT,
      is_hero INTEGER DEFAULT 0,
      position INTEGER DEFAULT 0,
      caption TEXT,
      mime_type TEXT NOT NULL,
      file_size INTEGER,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
    )
  ''');

  // Entities for @mentions (Phase 5 - future-proofing)
  await db.execute('''
    CREATE TABLE ${AppConstants.entitiesTable} (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      display_name TEXT,
      type TEXT DEFAULT 'person',
      notes TEXT,
      created_at INTEGER NOT NULL
    )
  ''');

  // Tags for #tags (Phase 5 - future-proofing)
  await db.execute('''
    CREATE TABLE ${AppConstants.tagsTable} (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      color TEXT,
      created_at INTEGER NOT NULL
    )
  ''');

  // Junction table: tasks ↔ entities
  await db.execute('''
    CREATE TABLE ${AppConstants.taskEntitiesTable} (
      task_id TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (task_id, entity_id),
      FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE,
      FOREIGN KEY (entity_id) REFERENCES ${AppConstants.entitiesTable}(id) ON DELETE CASCADE
    )
  ''');

  // Junction table: tasks ↔ tags
  await db.execute('''
    CREATE TABLE ${AppConstants.taskTagsTable} (
      task_id TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (task_id, tag_id),
      FOREIGN KEY (task_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES ${AppConstants.tagsTable}(id) ON DELETE CASCADE
    )
  ''');

  // ===========================================
  // 4. CREATE INDEXES (12 total, matching _migrateToV4)
  // ===========================================

  // Task indexes (with partial indexes for performance)
  await db.execute('''
    CREATE INDEX idx_tasks_parent ON ${AppConstants.tasksTable}(parent_id, position)
  ''');

  await db.execute('''
    CREATE INDEX idx_tasks_due_date ON ${AppConstants.tasksTable}(due_date) WHERE due_date IS NOT NULL
  ''');

  await db.execute('''
    CREATE INDEX idx_tasks_start_date ON ${AppConstants.tasksTable}(start_date) WHERE start_date IS NOT NULL
  ''');

  await db.execute('''
    CREATE INDEX idx_tasks_template ON ${AppConstants.tasksTable}(is_template) WHERE is_template = 1
  ''');

  // Task images indexes
  await db.execute('''
    CREATE INDEX idx_task_images_task ON ${AppConstants.taskImagesTable}(task_id, position)
  ''');

  await db.execute('''
    CREATE INDEX idx_task_images_hero ON ${AppConstants.taskImagesTable}(task_id) WHERE is_hero = 1
  ''');

  // Entity and tag indexes
  await db.execute('''
    CREATE INDEX idx_entities_name ON ${AppConstants.entitiesTable}(name)
  ''');

  await db.execute('''
    CREATE INDEX idx_tags_name ON ${AppConstants.tagsTable}(name)
  ''');

  // Junction table indexes (bidirectional lookups)
  await db.execute('''
    CREATE INDEX idx_task_entities_entity ON ${AppConstants.taskEntitiesTable}(entity_id)
  ''');

  await db.execute('''
    CREATE INDEX idx_task_entities_task ON ${AppConstants.taskEntitiesTable}(task_id)
  ''');

  await db.execute('''
    CREATE INDEX idx_task_tags_tag ON ${AppConstants.taskTagsTable}(tag_id)
  ''');

  await db.execute('''
    CREATE INDEX idx_task_tags_task ON ${AppConstants.taskTagsTable}(task_id)
  ''');

  // ===========================================
  // 5. SEED USER SETTINGS
  // ===========================================

  final now = DateTime.now().millisecondsSinceEpoch;

  await db.insert(AppConstants.userSettingsTable, {
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
    'timezone_id': null, // Populated when user sets up notifications
    'use_24hour_time': 0,
    'auto_complete_children': 'prompt',
    'default_notification_hour': 9,
    'default_notification_minute': 0,
    'voice_smart_punctuation': 1,
    'created_at': now,
    'updated_at': now,
  });

  print('✅ Database created with v4 schema');
}
```

### Verification 1.1:
- [ ] task_images has 10 columns (id, task_id, file_path, source_url, is_hero, position, caption, mime_type, file_size, created_at)
- [ ] entities has 5 columns with correct names (name, display_name, type, notes, created_at)
- [ ] tags has color column
- [ ] Both junction tables have created_at
- [ ] user_settings has CHECK (id = 1) constraint
- [ ] 12 indexes total (not 12+ or 12-)
- [ ] Partial indexes have WHERE clauses

---

## Phase 2: Add Complete TreeController to TaskProvider (CRITICAL)

**File:** `docs/phase-03/group1.md`
**Location:** Lines 1747-1866 (TaskProvider class)
**Estimated Time:** 30 minutes
**Risk:** MEDIUM

### Step 2.1: Add Import at Top of TaskProvider Section

**Location:** Before line 1747 (before `class TaskProvider`)
**Action:** Add import statement

**Add:**
```dart
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
```

### Step 2.2: Add TreeController Field

**Location:** After line 1757 (after `bool _isReorderMode = false;`)
**Action:** Add TreeController field declaration

**Add:**
```dart
  // Tree view controller for hierarchical drag-and-drop
  late TreeController<Task> treeController;
```

### Step 2.3: Add Constructor with TreeController Initialization

**Location:** After field declarations, before `loadTasks` method
**Action:** Add constructor

**Add:**
```dart
  /// Initialize provider with TreeController
  TaskProvider() {
    treeController = TreeController<Task>(
      roots: [],  // Start empty, populated in loadTasks
      childrenProvider: (Task task) => _tasks.where((t) => t.parentId == task.id),
      parentProvider: (Task task) => _findParent(task.parentId),
    );
  }

  /// Helper to find parent task by ID
  Task? _findParent(String? parentId) {
    if (parentId == null) return null;
    try {
      return _tasks.firstWhere((t) => t.id == parentId);
    } catch (e) {
      return null;
    }
  }
```

### Step 2.4: Update loadTasks to Refresh TreeController

**Location:** Lines 1767-1780 (existing loadTasks method)
**Action:** Replace entire method

**Replace with:**
```dart
  /// Load tasks with hierarchy
  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _taskService.getAllTasksHierarchical();

      // ✅ CRITICAL: Refresh TreeController roots after loading
      treeController.roots = _tasks.where((t) => t.parentId == null);
      treeController.rebuild();

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load tasks: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
```

### Step 2.5: Add onNodeAccepted Handler

**Location:** After `setReorderMode` method, BEFORE `reorderTasks` method
**Action:** Add complete onNodeAccepted handler

**Add:**
```dart
  /// Handle tree drag-and-drop reordering
  Future<void> onNodeAccepted(TreeDragAndDropDetails<Task> details) async {
    String? newParentId;
    int newPosition;
    int newDepth;

    // Determine drop location based on hover zone
    details.mapDropPosition(
      whenAbove: () {
        // Insert as previous sibling of target
        newParentId = details.targetNode.parentId;
        newPosition = details.targetNode.position;
        newDepth = details.targetNode.depth;
      },
      whenInside: () {
        // Insert as last child of target
        newParentId = details.targetNode.id;
        final siblings = _tasks.where((t) => t.parentId == newParentId).toList();
        newPosition = siblings.length;
        newDepth = details.targetNode.depth + 1;

        // Auto-expand target to show new child
        treeController.setExpansionState(details.targetNode, true);
      },
      whenBelow: () {
        // Insert as next sibling of target
        newParentId = details.targetNode.parentId;
        newPosition = details.targetNode.position + 1;
        newDepth = details.targetNode.depth;
      },
    );

    // Validate depth limit (max 4 levels)
    if (newDepth >= 4) {
      _showDepthLimitError();
      return;
    }

    // Use existing changeTaskParent (has cycle detection + sibling reindexing)
    await changeTaskParent(
      taskId: details.draggedNode.id,
      newParentId: newParentId,
      newPosition: newPosition,
    );

    // Optimistic update: Update in-memory state (no DB round-trip)
    final movedTaskIndex = _tasks.indexWhere((t) => t.id == details.draggedNode.id);
    if (movedTaskIndex != -1) {
      final movedTask = _tasks[movedTaskIndex];

      // Create updated task with new parent/position/depth
      // CRITICAL: Use copyWith to preserve ALL fields (startDate, isTemplate, notificationTime, etc.)
      final updatedTask = movedTask.copyWith(
        parentId: newParentId,
        position: newPosition,
        depth: newDepth,
      );

      _tasks[movedTaskIndex] = updatedTask;
    }

    // Refresh TreeController with updated state
    treeController.roots = _tasks.where((t) => t.parentId == null);
    treeController.rebuild();

    notifyListeners();
  }

  /// Show error when depth limit exceeded
  void _showDepthLimitError() {
    // TODO (UX Enhancement): Trigger SnackBar/Toast for immediate visual feedback
    // Current implementation: Sets error message in provider state
    _errorMessage = 'Maximum nesting depth (4 levels) reached';
    notifyListeners();
  }
```

### Step 2.6: Add toggleCollapse Method Using TreeController

**Location:** After `_showDepthLimitError` method
**Action:** Add toggleCollapse that delegates to TreeController

**Add:**
```dart
  /// Toggle collapse/expand for a task node
  /// Uses TreeController for expansion state (not _collapsedTaskIds)
  void toggleCollapse(Task task) {
    treeController.toggleExpansion(task);
  }
```

**Important:** This replaces the old `toggleCollapse(String taskId)` that mutated `_collapsedTaskIds`.
TreeController owns expansion state, so we delegate to `toggleExpansion()`.

### Verification 2:
- [ ] Import statement present
- [ ] TreeController field declared
- [ ] Constructor initializes TreeController
- [ ] _findParent helper present
- [ ] loadTasks refreshes treeController.roots
- [ ] onNodeAccepted handler complete
- [ ] _showDepthLimitError method present (with UX TODO note)
- [ ] toggleCollapse delegates to treeController.toggleExpansion

---

## Phase 3: Remove All Flat-List Reordering Code (HIGH)

**File:** `docs/phase-03/group1.md`
**Estimated Time:** 10 minutes
**Risk:** LOW

### Step 3.1: Delete TaskProvider.reorderTasks

**Location:** Lines 1826-1842
**Action:** Delete entire method

**Delete these lines:**
```dart
  /// Reorder tasks (drag and drop)
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    final visible = visibleTasks;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final task = visible.removeAt(oldIndex);
    visible.insert(newIndex, task);

    // Update positions in database
    await _taskService.reorderTasks(visible);

    // Reload to refresh from database
    await loadTasks();
  }
```

### Step 3.2: Delete TaskService.reorderTasks

**Location:** Lines 1718-1734
**Action:** Delete entire method

**Delete these lines:**
```dart
  /// Reorder tasks in bulk (after drag-and-drop)
  Future<void> reorderTasks(List<Task> tasks) async {
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      for (int i = 0; i < tasks.length; i++) {
        await txn.update(
          AppConstants.tasksTable,
          {
            'parent_id': tasks[i].parentId,
            'position': i,
          },
          where: 'id = ?',
          whereArgs: [tasks[i].id],
        );
      }
    });
  }
```

### Verification 3:
- [ ] TaskProvider.reorderTasks completely removed
- [ ] TaskService.reorderTasks completely removed
- [ ] No other references to these methods in document
- [ ] Only onNodeAccepted mentioned for reordering

---

## Phase 4: Consolidate Visibility with TreeController (HIGH)

**File:** `docs/phase-03/group1.md`
**Estimated Time:** 20 minutes
**Risk:** MEDIUM

**Key Change:** TreeController owns expansion state. Remove `_collapsedTaskIds` Set and `isCollapsed` plumbing.

### Step 4.1: Remove _collapsedTaskIds and collapsedTaskIds Getter

**Location:** Lines 1756 and 1763 (TaskProvider fields/getters)
**Action:** Delete these lines

**Delete:**
```dart
Set<String> _collapsedTaskIds = {}; // IDs of collapsed parent tasks
```

**Delete:**
```dart
Set<String> get collapsedTaskIds => _collapsedTaskIds;
```

**Reason:** TreeController manages expansion state via `toggleExpansion()` and `setExpansionState()`.
The `_collapsedTaskIds` Set is no longer used.

### Step 4.2: Remove Old toggleCollapse Method

**Location:** Lines 1806-1812 (old toggleCollapse implementation)
**Action:** Delete entire method (already replaced in Phase 2 Step 2.6)

**Delete:**
```dart
  void toggleCollapse(String taskId) {
    if (_collapsedTaskIds.contains(taskId)) {
      _collapsedTaskIds.remove(taskId);
    } else {
      _collapsedTaskIds.add(taskId);
    }
    notifyListeners();
  }
```

**Note:** Phase 2 Step 2.6 already added the new `toggleCollapse(Task task)` that uses TreeController.

### Step 4.3: Add Note to visibleTasks Getter

**Location:** Lines 1782-1803 (existing visibleTasks getter)
**Action:** Add deprecation comment above method

**Add above the method:**
```dart
  /// ⚠️ DEPRECATED: This getter is superseded by TreeController for tree view.
  ///
  /// TreeController manages visibility through its own expansion state.
  /// This getter is kept for backwards compatibility but should not be used
  /// with AnimatedTreeView. Use TreeController.roots instead.
  ///
  /// TODO: Remove this once all code uses TreeController.
```

### Step 4.4: Update HomeScreen Normal Mode to Use TreeView

**Location:** Lines 1964-1979 (HomeScreen ListView.builder for normal mode)
**Action:** Replace with AnimatedTreeView

**Replace:**
```dart
          // Normal mode: Regular ListView
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visibleTasks.length,
            itemBuilder: (context, index) {
              final task = visibleTasks[index];
              return TaskItem(
                key: ValueKey(task.id),
                task: task,
                isReorderMode: false,
                hasChildren: taskProvider.hasChildren(task.id),
                isCollapsed: taskProvider.collapsedTaskIds.contains(task.id),
                onToggleCollapse: () => taskProvider.toggleCollapse(task.id),
              );
            },
          );
```

**With:**
```dart
          // Normal mode: TreeView (no drag-and-drop)
          return AnimatedTreeView<Task>(
            treeController: taskProvider.treeController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            nodeBuilder: (context, TreeEntry<Task> entry) {
              return TaskItem(
                key: ValueKey(entry.node.id),
                task: entry.node,
                depth: entry.node.depth,
                isReorderMode: false,
                hasChildren: taskProvider.hasChildren(entry.node.id),
                isExpanded: entry.isExpanded,  // ✅ Use TreeEntry.isExpanded
                onToggleCollapse: () => taskProvider.toggleCollapse(entry.node),
              );
            },
          );
```

### Step 4.5: Update Reorder Mode DragAndDropTaskTile

**Location:** Lines 1944-1960 (HomeScreen reorder mode AnimatedTreeView)
**Action:** Update DragAndDropTaskTile to remove isCollapsed and pass entry

**Replace:**
```dart
          if (taskProvider.isReorderMode) {
            return AnimatedTreeView<Task>(
              treeController: taskProvider.treeController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              nodeBuilder: (context, TreeEntry<Task> entry) {
                return DragAndDropTaskTile(
                  entry: entry,
                  onNodeAccepted: taskProvider.onNodeAccepted,
                  isReorderMode: true,
                  isCollapsed: taskProvider.collapsedTaskIds.contains(entry.node.id),
                  onToggleCollapse: () => taskProvider.toggleCollapse(entry.node.id),
                  taskProvider: taskProvider, // For hasChildren check
                );
              },
            );
          }
```

**With:**
```dart
          if (taskProvider.isReorderMode) {
            return AnimatedTreeView<Task>(
              treeController: taskProvider.treeController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              nodeBuilder: (context, TreeEntry<Task> entry) {
                return DragAndDropTaskTile(
                  entry: entry,
                  onNodeAccepted: taskProvider.onNodeAccepted,
                  taskProvider: taskProvider,
                );
              },
            );
          }
```

**Note:** DragAndDropTaskTile will be updated to extract info from `entry` (including `entry.isExpanded`).
The wrapper should handle passing the full TreeEntry to TaskItem. See tree-drag-drop-integration-plan.md.

### Verification 4:
- [ ] _collapsedTaskIds Set removed
- [ ] collapsedTaskIds getter removed
- [ ] Old toggleCollapse(String taskId) removed
- [ ] visibleTasks has deprecation warning
- [ ] Both normal and reorder modes use AnimatedTreeView
- [ ] TreeController is single source of visibility truth
- [ ] No more ListView.builder in HomeScreen
- [ ] isCollapsed parameter removed from TaskItem builders
- [ ] onToggleCollapse passes Task object (not String ID)

---

## Phase 5: Fix TaskItem Signature (MEDIUM)

**File:** `docs/phase-03/group1.md`
**Location:** Lines 2014-2028
**Estimated Time:** 10 minutes
**Risk:** LOW

### Step 5.1: Add depth and decoration Parameters, Rename isCollapsed to isExpanded

**Location:** Lines 2015-2028 (TaskItem constructor)
**Action:** Update class fields and constructor

**Replace:**
```dart
class TaskItem extends StatelessWidget {
  final Task task;
  final bool isReorderMode;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const TaskItem({
    Key? key,
    required this.task,
    required this.isReorderMode,
    required this.hasChildren,
    required this.isCollapsed,
    required this.onToggleCollapse,
  }) : super(key: key);

  /// Get depth from Task model (populated by hierarchical query)
  int get depth {
    return task.depth;
  }
```

**With:**
```dart
class TaskItem extends StatelessWidget {
  final Task task;
  final int depth;  // ✅ Explicit parameter
  final bool isReorderMode;
  final bool hasChildren;
  final bool isExpanded;  // ✅ RENAMED from isCollapsed (aligns with TreeController API)
  final VoidCallback onToggleCollapse;
  final Decoration? decoration;  // ✅ Optional for drag feedback

  const TaskItem({
    Key? key,
    required this.task,
    required this.depth,  // ✅ Required
    required this.isReorderMode,
    required this.hasChildren,
    required this.isExpanded,  // ✅ RENAMED from isCollapsed
    required this.onToggleCollapse,
    this.decoration,  // ✅ Optional
  }) : super(key: key);
```

### Step 5.2: Update build() to Use decoration Parameter

**Location:** Lines 2042-2061 (Container with decoration)
**Action:** Replace hardcoded decoration with conditional

**Replace:**
```dart
      child: Container(
        margin: EdgeInsets.only(
          left: 16 + indentation,
          right: 16,
          top: 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
```

**With:**
```dart
      child: Container(
        margin: EdgeInsets.only(
          left: 16 + indentation,
          right: 16,
          top: 4,
          bottom: 4,
        ),
        decoration: decoration ?? BoxDecoration(  // ✅ Use provided or default
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
```

### Step 5.3: Update Icon Logic to Use isExpanded

**Location:** Lines 2103-2110 (_buildLeadingIcon method)
**Action:** Update icon to use `isExpanded` instead of `isCollapsed`

**Replace:**
```dart
      // Parent task: Show expand/collapse button
      return IconButton(
        icon: Icon(
          isCollapsed ? Icons.chevron_right : Icons.expand_more,
        ),
        iconSize: 20,
        padding: EdgeInsets.zero,
        onPressed: onToggleCollapse,
      );
```

**With:**
```dart
      // Parent task: Show expand/collapse button
      return IconButton(
        icon: Icon(
          isExpanded ? Icons.expand_more : Icons.chevron_right,  // ✅ Inverted logic
        ),
        iconSize: 20,
        padding: EdgeInsets.zero,
        onPressed: onToggleCollapse,
      );
```

### Verification 5:
- [ ] TaskItem has depth parameter
- [ ] TaskItem has decoration parameter
- [ ] TaskItem isCollapsed renamed to isExpanded
- [ ] Icon logic updated (isExpanded ? expand_more : chevron_right)
- [ ] build() uses decoration if provided
- [ ] All TaskItem instantiations updated (in Phase 4)

---

## Final Verification Checklist

### Compilation
- [ ] No "undefined treeController" errors
- [ ] No "undefined onNodeAccepted" errors
- [ ] No "reorderTasks isn't defined" errors
- [ ] TaskItem signature matches all usages
- [ ] All imports present

### Schema Parity
- [ ] _createDB matches _migrateToV4 exactly
- [ ] All 10 columns in task_images
- [ ] All 5 columns in entities (correct names)
- [ ] All 3 columns in tags
- [ ] All junction tables have created_at
- [ ] 12 indexes total with WHERE clauses
- [ ] user_settings has CHECK constraint

### Logical Consistency
- [ ] Only one reordering system (onNodeAccepted)
- [ ] Only one visibility system (TreeController)
- [ ] No flat-list reorderTasks methods
- [ ] Both modes use AnimatedTreeView
- [ ] No conflicting documentation

### All 7 Round 3 Issues Addressed
- [x] CRITICAL #1: _createDB schema matches migration
- [x] CRITICAL #2: TreeController fully integrated
- [x] HIGH #3: Legacy reorderTasks removed
- [x] HIGH #4: Visibility consolidated to TreeController
- [x] MEDIUM #5: TaskItem has depth parameter
- [x] MEDIUM #6: TaskItem has decoration parameter
- [x] LOW #7: TaskService.reorderTasks removed

---

## Execution Timeline

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| 1. _createDB | 45 min | 00:00 | 00:45 |
| 2. TreeController | 30 min | 00:45 | 01:15 |
| 3. Remove flat-list | 10 min | 01:15 | 01:25 |
| 4. Consolidate visibility | 20 min | 01:25 | 01:45 |
| 5. TaskItem signature | 10 min | 01:45 | 01:55 |
| **Verification** | 15 min | 01:55 | 02:10 |
| **TOTAL** | **~2h 10min** | | |

---

## Commit Message Template

```
docs: Fix all 7 Round 3 critical issues in Group 1 plan

Addressed comprehensive team feedback on implementation plan:

CRITICAL FIXES (2):
- Rewrite _createDB to exactly match _migrateToV4 end state
  * Add 6 missing columns to task_images (source_url, is_hero, position, caption, mime_type, file_size)
  * Fix entities table (use 'type' not 'entity_type', add display_name/notes)
  * Add color to tags, created_at to junction tables
  * Use correct 12 indexes with WHERE clauses (not 17 mismatched indexes)
  * Add CHECK (id = 1) to user_settings

- Integrate TreeController fully into TaskProvider
  * Add TreeController field, constructor initialization
  * Add onNodeAccepted handler for hierarchical drag-and-drop
  * Add _findParent helper, refresh roots in loadTasks
  * Add flutter_fancy_tree_view2 import

HIGH PRIORITY FIXES (2):
- Remove legacy reorderTasks methods (REGRESSION FIX)
  * Delete TaskProvider.reorderTasks (lines 1826-1842) - flat-list corruption
  * Delete TaskService.reorderTasks (lines 1718-1734) - assigns wrong positions
  * Prevents reintroduction of hierarchy corruption bug

- Consolidate visibility to TreeController only
  * Deprecate visibleTasks getter (superseded by TreeController)
  * Use AnimatedTreeView in both normal and reorder modes
  * Single source of truth for task visibility and expansion state

MEDIUM PRIORITY FIXES (2):
- Add explicit depth parameter to TaskItem
  * TaskItem now requires depth as constructor parameter
  * Matches DragAndDropTaskTile usage expectations
  * Remove internal depth getter, use field directly

- Add decoration parameter to TaskItem for drag feedback
  * TaskItem accepts optional decoration for hover borders
  * Falls back to default decoration if not provided
  * Enables visual feedback during tree drag-and-drop

All fixes verified against team feedback. No regressions introduced.
Schema now has exact parity between fresh installs and migrations.
Ready for final team sign-off.

Fixes: #1 #2 #3 #4 #5 #6 #7 (Round 3 issues)
```

---

**Status:** Ready for execution
**Next Step:** Begin Phase 1 (_createDB fix)
