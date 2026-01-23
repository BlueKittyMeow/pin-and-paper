# Phase 3.6.5 Detailed Implementation Plan

**Document Type:** Ultrathink Deep Planning
**Created:** 2026-01-20
**Status:** Ready for Review → Implementation
**Based On:** phase-3.6.5-plan-v2.md + comprehensive codebase analysis

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Codebase Analysis Findings](#codebase-analysis-findings)
3. [Day-by-Day Implementation Plan](#day-by-day-implementation-plan)
4. [Implementation Details by Feature](#implementation-details-by-feature)
5. [Code Patterns & Reusability](#code-patterns--reusability)
6. [Edge Cases & Error Handling](#edge-cases--error-handling)
7. [Testing Strategy](#testing-strategy)
8. [Risk Mitigation](#risk-mitigation)

---

## Executive Summary

### What We're Building

**Three tightly-coupled features:**
1. **Comprehensive Edit Modal** - Expand from title-only to title + due date + notes + tags + parent selector
2. **Completed Task Metadata View** - Read-only modal showing full task details + actions
3. **Completed Parent Visual Indicator** - Dimmed box (NO strikethrough) for completed parents with incomplete children

### Critical Dependencies RESOLVED

✅ **Task.notes field does NOT exist** - Will add in migration v8 (Day 1)
✅ **No existing date picker** - Will use Flutter's built-in `showDatePicker`
✅ **Tag picker exists** - `TagPickerDialog` from Phase 3.5 (reusable)
✅ **Breadcrumb logic exists** - `TaskService.getParentChain()` from Phase 3.6B (reusable)
✅ **Navigate logic exists** - `TaskProvider.navigateToTask()` from Phase 3.6B (reusable)

### Timeline: 5-7 Days

| Day | Focus | Files Changed | Risk Level |
|-----|-------|---------------|------------|
| Day 1 | Add Task.notes field (migration v8) | 3 files | LOW |
| Day 2-3 | Expand edit modal | 1-2 files | MEDIUM |
| Day 4 | Completed task metadata view | 1-2 files | LOW |
| Day 5 | Completed parent visual indicator | 1 file | LOW |
| Day 6-7 | Testing, edge cases, polish | All | LOW |

---

## Codebase Analysis Findings

### 1. Current Task Editing Mechanism

**Location:** `pin_and_paper/lib/widgets/task_item.dart:61-131`

**Current Implementation:**
```dart
Future<void> _handleEdit(BuildContext context) async {
  final controller = TextEditingController(text: task.title);

  // Select all text for easy replacement
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Task'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Task title',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  // Update logic at lines 96-130
  if (result != null && context.mounted) {
    try {
      await context.read<TaskProvider>().updateTaskTitle(task.id, result);
      // Success snackbar
    } catch (e) {
      // Error snackbar
    }
  }

  // CRITICAL: Delayed disposal (300ms) to avoid crashes
  Future.delayed(const Duration(milliseconds: 300), () {
    controller.dispose();
  });
}
```

**Key Insights:**
- Uses inline `AlertDialog` (NOT separate widget file)
- Simple TextField with controller
- 300ms delayed disposal to avoid rebuild crashes
- Updates via `TaskProvider.updateTaskTitle()`
- Shows success/error snackbars

**For Phase 3.6.5:**
- ✅ Keep inline AlertDialog pattern (no separate file needed initially)
- ✅ Expand to multiple fields (title, due date, notes, tags, parent)
- ✅ May need `StatefulWidget` for complex state management
- ⚠️ May need ScrollView if content exceeds screen height (try without first)

---

### 2. Tag Picker Implementation

**Location:** `pin_and_paper/lib/widgets/tag_picker_dialog.dart`

**Key Features:**
- StatefulWidget with search controller
- Loads all tags via `TagProvider.loadTags()`
- Multi-select with Set<String> for selected IDs
- Create new tag with color picker
- Returns `List<String>?` (null if cancelled)

**Static Show Method Pattern:**
```dart
static Future<List<String>?> show({
  required BuildContext context,
  required String taskId,
  required List<Tag> currentTags,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => TagPickerDialog(
      taskId: taskId,
      currentTags: currentTags,
    ),
  );
}
```

**Reusability for Phase 3.6.5:**
- ✅ Can embed in edit modal
- ✅ Already handles multi-select
- ✅ Returns selected tag IDs
- ⚠️ Need to integrate into edit modal (not separate dialog)

**Integration Approach:**
```dart
// In edit modal:
ElevatedButton(
  child: Text('Manage Tags'),
  onPressed: () async {
    final selectedIds = await TagPickerDialog.show(
      context: context,
      taskId: task.id,
      currentTags: _currentTags,
    );
    if (selectedIds != null) {
      setState(() {
        _selectedTagIds = selectedIds;
      });
    }
  },
)
```

---

### 3. Date Picker (Does NOT Exist)

**Finding:** No existing date picker implementation in codebase.

**Solution:** Use Flutter's built-in `showDatePicker`:

```dart
Future<DateTime?> _selectDate(BuildContext context, DateTime? initialDate) async {
  return await showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    helpText: 'Select Due Date',
    cancelText: 'Clear',
    confirmText: 'Set',
  );
}
```

**Integration in Edit Modal:**
```dart
Row(
  children: [
    Text('Due Date: '),
    Expanded(
      child: _dueDate == null
          ? Text('Not set', style: TextStyle(color: Colors.grey))
          : Text(DateFormat('MMM d, yyyy').format(_dueDate!)),
    ),
    IconButton(
      icon: Icon(Icons.calendar_today),
      onPressed: () async {
        final date = await _selectDate(context, _dueDate);
        if (date != null) {
          setState(() {
            _dueDate = date;
          });
        }
      },
    ),
    if (_dueDate != null)
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          setState(() {
            _dueDate = null;
          });
        },
      ),
  ],
)
```

---

### 4. Database Migration Patterns

**Location:** `pin_and_paper/lib/services/database_service.dart`

**Pattern from Migration v5 (lines 679-713):**
```dart
Future<void> _migrateToV5(Database db) async {
  // Wrap entire migration in a transaction for atomicity
  await db.transaction((txn) async {
    // ===========================================
    // 1. ADD COLUMN
    // ===========================================
    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN deleted_at INTEGER DEFAULT NULL
    ''');

    // ===========================================
    // 2. CREATE INDEXES (if needed)
    // ===========================================
    await txn.execute('''
      CREATE INDEX idx_tasks_deleted_at
      ON ${AppConstants.tasksTable}(deleted_at)
    ''');
  });

  debugPrint('✅ Database migrated to v5 successfully');
}
```

**Migration v8 Implementation (Day 1):**
```dart
/// Phase 3.6.5 Migration: v7 → v8
///
/// Adds:
/// - notes field to tasks table (TEXT, nullable)
///
/// This enables comprehensive task editing with descriptions/notes.
/// All existing tasks have notes = NULL by default.
Future<void> _migrateToV8(Database db) async {
  await db.transaction((txn) async {
    // ===========================================
    // 1. ADD NOTES COLUMN
    // ===========================================

    // Add notes column to tasks table
    // DEFAULT NULL means all existing tasks have no notes
    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN notes TEXT DEFAULT NULL
    ''');

    // No indexes needed for notes field (not frequently queried)
  });

  debugPrint('✅ Database migrated to v8 successfully');
}
```

**Files to Modify:**
1. `pin_and_paper/lib/utils/constants.dart` - Update version to 8
2. `pin_and_paper/lib/services/database_service.dart` - Add migration method
3. `pin_and_paper/lib/models/task.dart` - Add notes field

---

### 5. Parent Selector Requirements

**Existing Hierarchy Code:**
- `TaskProvider._findParent(String? parentId)` - Find parent task
- `TaskProvider._expandAncestors(Task task)` - Expand up to root
- `TaskService.getParentChain(String taskId)` - Get breadcrumb

**Parent Selector Design (Simplified Search):**

```dart
class ParentSelectorDialog extends StatefulWidget {
  final Task currentTask; // To exclude from list
  final String? currentParentId;

  static Future<String?> show({
    required BuildContext context,
    required Task currentTask,
    String? currentParentId,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (context) => ParentSelectorDialog(
        currentTask: currentTask,
        currentParentId: currentParentId,
      ),
    );
  }

  @override
  State<ParentSelectorDialog> createState() => _ParentSelectorDialogState();
}

class _ParentSelectorDialogState extends State<ParentSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_filterTasks);
  }

  Future<void> _loadTasks() async {
    final taskProvider = context.read<TaskProvider>();

    // Get all tasks, excluding:
    // 1. Current task (can't parent to self)
    // 2. Descendants of current task (can't create cycle)
    final allTasks = taskProvider.tasks
        .where((t) => !t.completed && !_isDescendant(t))
        .toList();

    setState(() {
      _allTasks = allTasks;
      _filteredTasks = allTasks;
    });
  }

  bool _isDescendant(Task task) {
    // Walk up from task to see if we hit currentTask
    String? currentId = task.parentId;
    while (currentId != null) {
      if (currentId == widget.currentTask.id) return true;
      final parent = _allTasks.firstWhere(
        (t) => t.id == currentId,
        orElse: () => null,
      );
      if (parent == null) break;
      currentId = parent.parentId;
    }
    return false;
  }

  void _filterTasks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = query.isEmpty
          ? _allTasks
          : _allTasks.where((t) =>
              t.title.toLowerCase().contains(query)
            ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Parent Task'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // "No Parent" option
                  ListTile(
                    leading: Icon(Icons.home),
                    title: Text('No Parent (Root Level)'),
                    selected: widget.currentParentId == null,
                    onTap: () => Navigator.pop(context, null),
                  ),
                  Divider(),
                  // Filtered tasks
                  ..._filteredTasks.map((task) => ListTile(
                    leading: task.completed
                        ? Icon(Icons.check_circle, color: Colors.grey)
                        : Icon(Icons.circle_outlined),
                    title: Text(
                      task.title,
                      style: task.completed
                          ? TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    selected: task.id == widget.currentParentId,
                    onTap: () => Navigator.pop(context, task.id),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
```

---

### 6. Breadcrumb Logic (Reusable)

**Location:** `pin_and_paper/lib/services/task_service.dart:171-196`

**Implementation:**
```dart
/// Get parent chain for a task (for breadcrumb generation)
///
/// Phase 3.6B: Returns list of parent tasks from immediate parent up to root.
/// Used for generating breadcrumb navigation in search results.
///
/// Example: If task hierarchy is: Root > Parent > Child > Target
/// This returns: [Child, Parent, Root] (immediate parent first)
///
/// Returns empty list if task has no parent (is root-level task).
/// Excludes soft-deleted tasks from the chain.
Future<List<Task>> getParentChain(String taskId) async {
  final db = await _dbService.database;

  // Use recursive CTE to walk up the parent chain
  final maps = await db.rawQuery('''
    WITH RECURSIVE ancestors AS (
      SELECT id, parent_id, 0 as depth
      FROM ${AppConstants.tasksTable}
      WHERE id = ?

      UNION ALL

      SELECT t.id, t.parent_id, a.depth + 1
      FROM ${AppConstants.tasksTable} t
      INNER JOIN ancestors a ON t.id = a.parent_id
      WHERE t.deleted_at IS NULL
    )
    SELECT t.*
    FROM ${AppConstants.tasksTable} t
    INNER JOIN ancestors a ON t.id = a.id
    WHERE a.depth > 0
    ORDER BY a.depth ASC
  ''', [taskId]);

  return maps.map((map) => Task.fromMap(map)).toList();
}
```

**Usage in Metadata View:**
```dart
Future<String> _buildBreadcrumb(Task task) async {
  if (task.parentId == null) return 'Root Level';

  final taskService = TaskService();
  final parents = await taskService.getParentChain(task.id);

  if (parents.isEmpty) return 'Root Level';

  return parents.map((t) => t.title).join(' > ');
}
```

---

### 7. Navigate to Task Logic (Reusable)

**Location:** `pin_and_paper/lib/providers/task_provider.dart:1008-1059`

**Key Features:**
- Clears filters if task not in current view
- Expands all ancestors to make task visible
- Highlights task for 2 seconds
- Scrolls to task with smooth animation

**Usage in Metadata View:**
```dart
void _viewInContext(BuildContext context, Task task) {
  Navigator.pop(context); // Close metadata modal
  context.read<TaskProvider>().navigateToTask(task.id);
}
```

---

### 8. Completed Task Display Logic

**Location:** `pin_and_paper/lib/widgets/task_item.dart:322-331`

**Current Implementation:**
```dart
title: Text(
  task.title,
  style: TextStyle(
    decoration: task.completed
        ? TextDecoration.lineThrough
        : TextDecoration.none,
    color: task.completed
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.onSurface,
  ),
),
```

**Phase 3.6.5 Modification:**
```dart
// NEW: Determine if task is "truly complete" vs "completed parent"
final isTrulyComplete = task.completed && !_hasIncompleteChildren(task);
final isCompletedParent = task.completed && _hasIncompleteChildren(task);

// Wrapper container for completed parents
Widget taskWidget = ListTile(...);
if (isCompletedParent) {
  taskWidget = Container(
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.3), // Dimmed box
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        taskWidget,
        // Badge showing incomplete children count
        Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            '(${_getIncompleteChildrenCount(task)} incomplete children)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    ),
  );
}

// Title text decoration
title: Text(
  task.title,
  style: TextStyle(
    // Only strikethrough if TRULY complete (not completed parent)
    decoration: isTrulyComplete
        ? TextDecoration.lineThrough
        : TextDecoration.none,
    color: task.completed
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.onSurface,
  ),
),
```

**Helper Methods Needed:**
```dart
bool _hasIncompleteChildren(Task task) {
  // Check if any children are incomplete
  final taskProvider = context.read<TaskProvider>();
  final children = taskProvider.tasks.where((t) => t.parentId == task.id);
  return children.any((c) => !c.completed && c.deletedAt == null);
}

int _getIncompleteChildrenCount(Task task) {
  final taskProvider = context.read<TaskProvider>();
  final children = taskProvider.tasks.where((t) => t.parentId == task.id);
  return children.where((c) => !c.completed && c.deletedAt == null).length;
}
```

---

## Day-by-Day Implementation Plan

### Day 1: Add Task.notes Field (Migration v8)

**Goal:** Add notes field to database and Task model

**Files to Modify:**
1. `pin_and_paper/lib/utils/constants.dart`
2. `pin_and_paper/lib/services/database_service.dart`
3. `pin_and_paper/lib/models/task.dart`

**Step-by-Step:**

#### Step 1.1: Update Database Version

**File:** `pin_and_paper/lib/utils/constants.dart:4`

**Change:**
```dart
// OLD:
static const int databaseVersion = 7; // Phase 3.6B: Universal Search (no schema changes, FTS5 reserved)

// NEW:
static const int databaseVersion = 8; // Phase 3.6.5: Edit Task Modal Rework (notes field)
```

#### Step 1.2: Add Migration Method

**File:** `pin_and_paper/lib/services/database_service.dart`

**Location:** After `_migrateToV7` method (around line 919)

**Add:**
```dart
/// Phase 3.6.5 Migration: v7 → v8
///
/// Adds:
/// - notes field to tasks table (TEXT, nullable)
///
/// This enables comprehensive task editing with descriptions/notes.
/// All existing tasks have notes = NULL by default.
Future<void> _migrateToV8(Database db) async {
  await db.transaction((txn) async {
    // ===========================================
    // 1. ADD NOTES COLUMN
    // ===========================================

    // Add notes column to tasks table
    // DEFAULT NULL means all existing tasks have no notes
    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN notes TEXT DEFAULT NULL
    ''');

    // No indexes needed for notes field (not frequently queried)
  });

  debugPrint('✅ Database migrated to v8 successfully');
}
```

#### Step 1.3: Call Migration in _upgradeDB

**File:** `pin_and_paper/lib/services/database_service.dart`

**Location:** In `_upgradeDB` method (around line 392)

**Add after v7 check:**
```dart
// Migrate from version 7 to 8: Phase 3.6.5 - Edit Task Modal Rework (notes field)
if (oldVersion < 8) {
  await _migrateToV8(db);
}
```

#### Step 1.4: Update Task Model - Add Field

**File:** `pin_and_paper/lib/models/task.dart:1-46`

**Add after line 27 (after deletedAt):**
```dart
// Phase 3.6.5: Notes/description support
final String? notes; // NULL = no notes
```

**Update constructor (line 29-45):**
```dart
Task({
  required this.id,
  required this.title,
  required this.createdAt,
  this.completed = false,
  this.completedAt,
  // New fields with defaults
  this.parentId,
  this.position = 0,
  this.depth = 0,
  this.isTemplate = false,
  this.dueDate,
  this.isAllDay = true,
  this.startDate,
  this.notificationType = 'use_global',
  this.notificationTime,
  this.deletedAt,
  this.notes, // NEW
});
```

#### Step 1.5: Update Task Model - toMap()

**File:** `pin_and_paper/lib/models/task.dart:49-68`

**Add after line 66 (after deleted_at):**
```dart
'notes': notes, // NEW
```

#### Step 1.6: Update Task Model - fromMap()

**File:** `pin_and_paper/lib/models/task.dart:71-105`

**Add after line 102 (after deletedAt):**
```dart
notes: map['notes'] as String?, // NEW
```

#### Step 1.7: Update Task Model - copyWith()

**File:** `pin_and_paper/lib/models/task.dart:109-143`

**Add parameter after line 123 (after deletedAt):**
```dart
String? notes, // NEW
```

**Add assignment after line 140 (after deletedAt):**
```dart
notes: notes ?? this.notes, // NEW
```

#### Step 1.8: Test Migration

**Commands:**
```bash
cd pin_and_paper
flutter clean
flutter pub get
flutter test
flutter build linux --release
```

**Manual Test:**
1. Run app
2. Check console for migration message: "✅ Database migrated to v8 successfully"
3. Verify existing tasks still load correctly
4. Check database file to confirm notes column exists

**Success Criteria:**
- ✅ App builds without errors
- ✅ Migration runs successfully
- ✅ Existing tasks load normally
- ✅ notes column exists in database

---

### Days 2-3: Expand Edit Modal

**Goal:** Transform simple title edit into comprehensive edit modal with all fields

**Files to Modify:**
1. `pin_and_paper/lib/widgets/task_item.dart` (expand `_handleEdit` method)
2. Possibly create `pin_and_paper/lib/widgets/edit_task_dialog.dart` if modal becomes complex

**Decision Point:** Start inline, extract to separate file if >200 lines

#### Step 2.1: Expand _handleEdit to StatefulWidget Dialog

**File:** `pin_and_paper/lib/widgets/task_item.dart:61-131`

**Strategy:** Replace simple AlertDialog with comprehensive edit modal

**New Implementation:**

```dart
// Phase 3.6.5: Comprehensive task edit
Future<void> _handleEdit(BuildContext context) async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _EditTaskDialog(task: task),
  );

  if (result == null || !context.mounted) return;

  try {
    final taskProvider = context.read<TaskProvider>();

    // Update task with all fields
    await taskProvider.updateTask(
      task.id,
      title: result['title'] as String,
      dueDate: result['dueDate'] as DateTime?,
      notes: result['notes'] as String?,
      parentId: result['parentId'] as String?,
      tagIds: result['tagIds'] as List<String>,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update task: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
```

#### Step 2.2: Create _EditTaskDialog Widget

**Location:** Same file or new file (decision based on complexity)

**Implementation:**

```dart
class _EditTaskDialog extends StatefulWidget {
  final Task task;

  const _EditTaskDialog({required this.task});

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  DateTime? _dueDate;
  String? _parentId;
  List<String> _selectedTagIds = [];
  List<Tag> _currentTags = [];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _dueDate = widget.task.dueDate;
    _parentId = widget.task.parentId;

    // Load current tags
    _loadTags();

    // Select all title text
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );
  }

  Future<void> _loadTags() async {
    final tagProvider = context.read<TagProvider>();
    final taskTags = await tagProvider.getTaskTags(widget.task.id);
    setState(() {
      _currentTags = taskTags;
      _selectedTagIds = taskTags.map((t) => t.id).toList();
    });
  }

  @override
  void dispose() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _titleController.dispose();
      _notesController.dispose();
    });
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Due Date',
      cancelText: 'Clear',
      confirmText: 'Set',
    );

    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _selectParent() async {
    final parentId = await ParentSelectorDialog.show(
      context: context,
      currentTask: widget.task,
      currentParentId: _parentId,
    );

    // null means "No Parent" was selected (valid choice)
    // No change if dialog was cancelled (parentId would be the same)
    if (parentId != _parentId) {
      setState(() {
        _parentId = parentId;
      });
    }
  }

  Future<void> _manageTags() async {
    final selectedIds = await TagPickerDialog.show(
      context: context,
      taskId: widget.task.id,
      currentTags: _currentTags,
    );

    if (selectedIds != null) {
      setState(() {
        _selectedTagIds = selectedIds;
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title cannot be empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'title': title,
      'dueDate': _dueDate,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'parentId': _parentId,
      'tagIds': _selectedTagIds,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Task'),
      content: SizedBox(
        width: double.maxFinite,
        // Try without scrollview first (per v2 decision)
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== TITLE =====
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // ===== PARENT SELECTOR =====
            OutlinedButton.icon(
              onPressed: _selectParent,
              icon: const Icon(Icons.account_tree),
              label: Text(
                _parentId == null
                    ? 'No Parent (Root Level)'
                    : 'Parent: ${_getParentTitle()}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),

            // ===== DUE DATE =====
            OutlinedButton.icon(
              onPressed: _selectDueDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _dueDate == null
                    ? 'No Due Date'
                    : 'Due: ${DateFormat('MMM d, yyyy').format(_dueDate!)}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            if (_dueDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _dueDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Date'),
                ),
              ),
            const SizedBox(height: 16),

            // ===== TAGS =====
            OutlinedButton.icon(
              onPressed: _manageTags,
              icon: const Icon(Icons.label),
              label: Text(
                _selectedTagIds.isEmpty
                    ? 'No Tags'
                    : '${_selectedTagIds.length} tag(s) selected',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),

            // ===== NOTES =====
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Add notes or description...',
              ),
              maxLines: 4,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _getParentTitle() {
    if (_parentId == null) return 'Root Level';

    final taskProvider = context.read<TaskProvider>();
    final parent = taskProvider.tasks.firstWhere(
      (t) => t.id == _parentId,
      orElse: () => null,
    );

    return parent?.title ?? '(Parent not found)';
  }
}
```

#### Step 2.3: Add updateTask Method to TaskProvider

**File:** `pin_and_paper/lib/providers/task_provider.dart`

**Add after `updateTaskTitle` method:**

```dart
/// Phase 3.6.5: Comprehensive task update
Future<void> updateTask(
  String taskId, {
  required String title,
  DateTime? dueDate,
  String? notes,
  String? parentId,
  required List<String> tagIds,
}) async {
  if (title.trim().isEmpty) {
    throw ArgumentError('Task title cannot be empty');
  }

  _errorMessage = null;

  try {
    // Update task via service
    await _taskService.updateTask(
      taskId,
      title: title.trim(),
      dueDate: dueDate,
      notes: notes,
      parentId: parentId,
    );

    // Update tags if changed
    final currentTags = await _tagProvider.getTaskTags(taskId);
    final currentTagIds = currentTags.map((t) => t.id).toSet();
    final newTagIds = tagIds.toSet();

    // Add new tags
    for (final tagId in newTagIds.difference(currentTagIds)) {
      await _tagProvider.addTagToTask(taskId, tagId);
    }

    // Remove removed tags
    for (final tagId in currentTagIds.difference(newTagIds)) {
      await _tagProvider.removeTagFromTask(taskId, tagId);
    }

    // Reload tasks to reflect changes
    await loadTasks();
  } catch (e) {
    _errorMessage = 'Failed to update task: $e';
    debugPrint(_errorMessage);
    rethrow;
  }
}
```

#### Step 2.4: Add updateTask Method to TaskService

**File:** `pin_and_paper/lib/services/task_service.dart`

**Add after existing update methods:**

```dart
/// Phase 3.6.5: Comprehensive task update
Future<void> updateTask(
  String taskId, {
  required String title,
  DateTime? dueDate,
  String? notes,
  String? parentId,
}) async {
  final db = await _dbService.database;

  await db.update(
    AppConstants.tasksTable,
    {
      'title': title,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'notes': notes,
      'parent_id': parentId,
    },
    where: 'id = ?',
    whereArgs: [taskId],
  );
}
```

#### Step 2.5: Test Edit Modal

**Manual Tests:**
1. Long-press task → Edit
2. Verify all fields load correctly
3. Change title → Save → Verify update
4. Set due date → Save → Verify update
5. Add notes → Save → Verify update
6. Change parent → Save → Verify hierarchy changes
7. Add/remove tags → Save → Verify tags update
8. Cancel → Verify no changes
9. Empty title → Verify validation error

**Success Criteria:**
- ✅ Modal opens with current values
- ✅ All fields editable
- ✅ Save updates task correctly
- ✅ Cancel discards changes
- ✅ Validation prevents empty title
- ✅ No crashes or errors

---

### Day 4: Completed Task Metadata View

**Goal:** Add read-only modal for completed tasks showing full details + actions

**Files to Create/Modify:**
1. Create `pin_and_paper/lib/widgets/completed_task_metadata_dialog.dart`
2. Modify `pin_and_paper/lib/widgets/task_item.dart` (add tap handler for completed tasks)

#### Step 4.1: Create Metadata Dialog Widget

**File:** `pin_and_paper/lib/widgets/completed_task_metadata_dialog.dart` (NEW)

**Implementation:**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/tag.dart';
import '../providers/task_provider.dart';
import '../providers/tag_provider.dart';
import '../services/task_service.dart';
import 'tag_chip.dart';

/// Read-only metadata view for completed tasks
///
/// Phase 3.6.5: Temporal proof of existence feature
/// Shows: timestamps, duration, tags, notes, hierarchy
/// Actions: View in Context, Uncomplete, Delete Permanently
class CompletedTaskMetadataDialog extends StatefulWidget {
  final Task task;

  const CompletedTaskMetadataDialog({
    super.key,
    required this.task,
  });

  /// Show the metadata dialog
  static Future<void> show({
    required BuildContext context,
    required Task task,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => CompletedTaskMetadataDialog(task: task),
    );
  }

  @override
  State<CompletedTaskMetadataDialog> createState() =>
      _CompletedTaskMetadataDialogState();
}

class _CompletedTaskMetadataDialogState
    extends State<CompletedTaskMetadataDialog> {
  String _breadcrumb = 'Loading...';
  List<Tag> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      // Load breadcrumb
      final taskService = TaskService();
      final parents = await taskService.getParentChain(widget.task.id);
      final breadcrumb = parents.isEmpty
          ? 'Root Level'
          : parents.map((t) => t.title).join(' > ');

      // Load tags
      final tagProvider = context.read<TagProvider>();
      final tags = await tagProvider.getTaskTags(widget.task.id);

      if (mounted) {
        setState(() {
          _breadcrumb = breadcrumb;
          _tags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _breadcrumb = 'Error loading hierarchy';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration() {
    if (widget.task.completedAt == null) return 'Unknown';

    final duration = widget.task.completedAt!.difference(widget.task.createdAt);

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '$days day${days != 1 ? 's' : ''} $hours hour${hours != 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hour${hours != 1 ? 's' : ''} $minutes min';
    } else {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    }
  }

  Future<void> _viewInContext() async {
    Navigator.pop(context); // Close modal
    await context.read<TaskProvider>().navigateToTask(widget.task.id);
  }

  Future<void> _uncompleteTask() async {
    try {
      await context.read<TaskProvider>().toggleTaskCompletion(widget.task);

      if (mounted) {
        Navigator.pop(context); // Close modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task marked as incomplete'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to uncomplete task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text(
          'This will soft-delete the task. '
          'It will be permanently deleted after 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<TaskProvider>().deleteTask(widget.task.id);

      if (mounted) {
        Navigator.pop(context); // Close modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Task Details'),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== TITLE =====
                    Text(
                      widget.task.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // ===== STATUS =====
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Completed',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // ===== HIERARCHY =====
                    _buildInfoRow(
                      icon: Icons.account_tree,
                      label: 'Hierarchy',
                      value: _breadcrumb,
                    ),

                    // ===== TIMESTAMPS =====
                    _buildInfoRow(
                      icon: Icons.schedule,
                      label: 'Created',
                      value: DateFormat('MMM d, yyyy h:mm a')
                          .format(widget.task.createdAt),
                    ),
                    if (widget.task.completedAt != null)
                      _buildInfoRow(
                        icon: Icons.check_circle_outline,
                        label: 'Completed',
                        value: DateFormat('MMM d, yyyy h:mm a')
                            .format(widget.task.completedAt!),
                      ),
                    _buildInfoRow(
                      icon: Icons.timer,
                      label: 'Duration',
                      value: _formatDuration(),
                    ),

                    // ===== DUE DATE =====
                    if (widget.task.dueDate != null)
                      _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Due Date',
                        value: DateFormat('MMM d, yyyy')
                            .format(widget.task.dueDate!),
                      ),

                    const Divider(height: 24),

                    // ===== TAGS =====
                    if (_tags.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.label,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tags',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _tags
                            .map((tag) => CompactTagChip(tag: tag))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ===== NOTES =====
                    if (widget.task.notes != null &&
                        widget.task.notes!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.notes,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Notes',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.task.notes!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        // ===== VIEW IN CONTEXT =====
        TextButton.icon(
          onPressed: _viewInContext,
          icon: const Icon(Icons.visibility),
          label: const Text('View in Context'),
        ),
        // ===== UNCOMPLETE =====
        TextButton.icon(
          onPressed: _uncompleteTask,
          icon: const Icon(Icons.undo),
          label: const Text('Uncomplete'),
        ),
        // ===== DELETE =====
        TextButton.icon(
          onPressed: _deleteTask,
          icon: const Icon(Icons.delete),
          label: const Text('Delete'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Step 4.2: Add Tap Handler for Completed Tasks

**File:** `pin_and_paper/lib/widgets/task_item.dart`

**Location:** In GestureDetector (around line 389)

**Add after onSecondaryTapDown (around line 407):**

```dart
// Phase 3.6.5: Tap completed task to show metadata
onTap: task.completed
    ? () {
        CompletedTaskMetadataDialog.show(
          context: context,
          task: task,
        );
      }
    : null,
```

#### Step 4.3: Test Metadata View

**Manual Tests:**
1. Complete a task
2. Tap completed task
3. Verify metadata modal opens
4. Check all fields display correctly:
   - Title (strikethrough)
   - Status icon
   - Hierarchy breadcrumb
   - Created timestamp
   - Completed timestamp
   - Duration calculation
   - Due date (if set)
   - Tags (if any)
   - Notes (if any)
5. Test "View in Context" → Verify navigation works
6. Test "Uncomplete" → Verify task moves back to active
7. Test "Delete" → Verify confirmation + soft delete

**Success Criteria:**
- ✅ Metadata modal displays all task information
- ✅ Breadcrumb shows correct hierarchy
- ✅ Duration calculated correctly
- ✅ All actions work as expected
- ✅ No crashes or errors

---

### Day 5: Completed Parent Visual Indicator

**Goal:** Show completed parents with incomplete children in dimmed box (NO strikethrough)

**Files to Modify:**
1. `pin_and_paper/lib/widgets/task_item.dart`

#### Step 5.1: Add Helper Methods

**File:** `pin_and_paper/lib/widgets/task_item.dart`

**Add after build method:**

```dart
/// Phase 3.6.5: Check if task has incomplete children
bool _hasIncompleteChildren(BuildContext context) {
  final taskProvider = context.read<TaskProvider>();
  final children = taskProvider.tasks.where((t) => t.parentId == task.id);
  return children.any((c) => !c.completed && c.deletedAt == null);
}

/// Phase 3.6.5: Count incomplete children
int _getIncompleteChildrenCount(BuildContext context) {
  final taskProvider = context.read<TaskProvider>();
  final children = taskProvider.tasks.where((t) => t.parentId == task.id);
  return children.where((c) => !c.completed && c.deletedAt == null).length;
}
```

#### Step 5.2: Modify Task Rendering Logic

**File:** `pin_and_paper/lib/widgets/task_item.dart`

**Location:** Around lines 322-331 (title Text widget)

**Replace with:**

```dart
// Phase 3.6.5: Determine strikethrough based on completion status
final isCompletedParent = task.completed && _hasIncompleteChildren(context);
final isTrulyComplete = task.completed && !isCompletedParent;

title: Text(
  task.title,
  style: TextStyle(
    // NEW: Only strikethrough if TRULY complete
    decoration: isTrulyComplete
        ? TextDecoration.lineThrough
        : TextDecoration.none,
    color: task.completed
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.onSurface,
  ),
),
```

#### Step 5.3: Add Dimmed Box Container

**File:** `pin_and_paper/lib/widgets/task_item.dart`

**Location:** Around line 223 (AnimatedContainer)

**Modify the AnimatedContainer decoration:**

```dart
// Phase 3.6.5: Determine if task is completed parent with incomplete children
return Consumer<TaskProvider>(
  builder: (context, taskProvider, child) {
    final isHighlighted = taskProvider.isTaskHighlighted(task.id);
    final isCompletedParent = task.completed && _hasIncompleteChildren(context);

    final taskContainer = AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(
        left: leftMargin,
        right: 16,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        // Phase 3.6.5: Dimmed box for completed parents
        color: isHighlighted
            ? Colors.amber.shade100
            : isCompletedParent
                ? Colors.grey.withOpacity(0.3) // Dimmed box
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted
            ? Border.all(
                color: Colors.amber.shade700,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing breadcrumb, ListTile, tags...

          // NEW: Badge for incomplete children count
          if (isCompletedParent)
            Padding(
              padding: const EdgeInsets.only(
                left: 60, // Align with title
                right: 12,
                bottom: 8,
              ),
              child: Text(
                '(${_getIncompleteChildrenCount(context)} incomplete children)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );

    // Rest of existing code...
```

#### Step 5.4: Add Tap Handler for Completed Parents

**File:** `pin_and_paper/lib/widgets/task_item.dart`

**Location:** Modify the onTap added in Step 4.2

**Update to:**

```dart
// Phase 3.6.5: Tap completed task to show metadata OR navigate to children
onTap: task.completed
    ? () {
        // If completed parent with incomplete children, navigate to active list
        if (_hasIncompleteChildren(context)) {
          context.read<TaskProvider>().navigateToTask(task.id);
        } else {
          // Otherwise show metadata view
          CompletedTaskMetadataDialog.show(
            context: context,
            task: task,
          );
        }
      }
    : null,
```

#### Step 5.5: Test Completed Parent Indicator

**Manual Tests:**
1. Create parent task with children
2. Complete parent task (children still incomplete)
3. Verify:
   - Dimmed background box appears
   - NO strikethrough on parent title
   - Badge shows "(X incomplete children)"
4. Tap completed parent
5. Verify navigation to active tasks showing children
6. Complete all children
7. Verify:
   - Dimmed box disappears
   - Strikethrough appears
8. Tap now-fully-complete parent
9. Verify metadata modal opens

**Success Criteria:**
- ✅ Completed parents with incomplete children show dimmed box
- ✅ NO strikethrough on completed parents
- ✅ Strikethrough only on fully complete tasks
- ✅ Badge shows correct count
- ✅ Tap navigates to children
- ✅ Fully complete tasks show metadata on tap

---

### Days 6-7: Testing, Edge Cases, and Polish

**Goal:** Comprehensive testing and edge case handling

#### Testing Checklist

**Edit Modal Tests:**
- [ ] Edit title → Save → Verify
- [ ] Set/clear due date → Save → Verify
- [ ] Add/edit/clear notes → Save → Verify
- [ ] Change parent (root → parent → different parent → root) → Verify
- [ ] Add/remove tags → Save → Verify
- [ ] Cancel with changes → Verify no updates
- [ ] Empty title → Verify validation error
- [ ] Very long title (500+ chars) → Verify handling
- [ ] Very long notes (5000+ chars) → Verify handling
- [ ] Modal fits on screen (no overflow)
- [ ] Keyboard navigation works
- [ ] Save/Cancel buttons responsive

**Metadata View Tests:**
- [ ] Tap completed task → Modal opens
- [ ] All fields display correctly
- [ ] Breadcrumb shows full hierarchy
- [ ] Duration calculation accurate
- [ ] Tags display correctly
- [ ] Notes display correctly (with line breaks)
- [ ] "View in Context" navigates correctly
- [ ] "Uncomplete" restores task
- [ ] "Delete" soft-deletes with confirmation
- [ ] Modal fits on screen
- [ ] Actions work from any screen

**Completed Parent Tests:**
- [ ] Parent with 1 incomplete child → Dimmed box
- [ ] Parent with 5 incomplete children → Badge shows "5"
- [ ] Parent with NO incomplete children → Strikethrough, no box
- [ ] Tap completed parent → Navigates to children
- [ ] Complete all children → Box disappears, strikethrough appears
- [ ] Uncomplete child → Box reappears
- [ ] Nested parents (3+ levels) → All display correctly
- [ ] Parent with mix of completed/incomplete/deleted children → Count correct

**Migration Tests:**
- [ ] Fresh install → Schema v8 created
- [ ] Upgrade from v7 → Migration runs
- [ ] Existing tasks load correctly
- [ ] notes column nullable
- [ ] No data loss
- [ ] Migration idempotent (safe to run multiple times)

**Edge Cases:**
- [ ] Task with no parent → "Root Level" displays
- [ ] Task with deleted parent → Orphan handling
- [ ] Task with very deep nesting (10+ levels) → Breadcrumb handling
- [ ] Task with 20+ tags → Display handling
- [ ] Task with no due date → "Not set" displays
- [ ] Task with due date in past → Red indicator?
- [ ] Simultaneous edits from multiple devices (if applicable)
- [ ] Very large notes field → Performance
- [ ] Unicode characters in title/notes → Display correctly
- [ ] Emoji in title/notes → Display correctly

**Performance Tests:**
- [ ] Edit modal opens quickly (<100ms)
- [ ] Metadata modal loads quickly (<200ms)
- [ ] Breadcrumb calculation fast (<100ms)
- [ ] Large task list (500+ tasks) → No lag
- [ ] Completed parents calculation fast

**Regression Tests:**
- [ ] Existing task editing still works
- [ ] Tag management unaffected
- [ ] Task completion/uncompletion works
- [ ] Hierarchyexpand/collapse works
- [ ] Search still works
- [ ] Filters still work
- [ ] Phase 3.6B navigation still works
- [ ] All existing features functional

---

## Code Patterns & Reusability

### Pattern 1: Dialog with Static Show Method

**Used in:** TagPickerDialog, ParentSelectorDialog, CompletedTaskMetadataDialog

**Pattern:**
```dart
class MyDialog extends StatefulWidget {
  final MyData data;

  const MyDialog({super.key, required this.data});

  static Future<MyResult?> show({
    required BuildContext context,
    required MyData data,
  }) {
    return showDialog<MyResult>(
      context: context,
      builder: (context) => MyDialog(data: data),
    );
  }

  @override
  State<MyDialog> createState() => _MyDialogState();
}
```

**Benefits:**
- Clean API: `MyDialog.show(context: context, data: data)`
- Type-safe return values
- Consistent pattern across codebase

### Pattern 2: Delayed Controller Disposal

**Used in:** task_item.dart `_handleEdit`

**Pattern:**
```dart
Future.delayed(const Duration(milliseconds: 300), () {
  controller.dispose();
});
```

**Reason:** Prevents crashes when dialog animation + rebuilds overlap with controller disposal.

**When to use:** Any dialog with TextEditingController that triggers UI rebuilds on save.

### Pattern 3: Transaction-Wrapped Migrations

**Used in:** All database migrations (v4-v7)

**Pattern:**
```dart
Future<void> _migrateToVX(Database db) async {
  await db.transaction((txn) async {
    // All schema changes here
    await txn.execute('ALTER TABLE ...');
    await txn.execute('CREATE INDEX ...');
  });

  debugPrint('✅ Database migrated to vX successfully');
}
```

**Benefits:**
- Atomic migrations (all-or-nothing)
- Automatic rollback on error
- Clear success logging

### Pattern 4: Consumer for Dynamic UI

**Used in:** task_item.dart for highlight detection

**Pattern:**
```dart
return Consumer<TaskProvider>(
  builder: (context, taskProvider, child) {
    final dynamicValue = taskProvider.computeSomething(task);

    return Widget(
      // Use dynamicValue
    );
  },
);
```

**When to use:** Widget needs to rebuild when provider state changes.

### Pattern 5: Recursive CTE for Hierarchy

**Used in:** TaskService.getParentChain

**Pattern:**
```sql
WITH RECURSIVE ancestors AS (
  SELECT id, parent_id, 0 as depth
  FROM tasks
  WHERE id = ?

  UNION ALL

  SELECT t.id, t.parent_id, a.depth + 1
  FROM tasks t
  INNER JOIN ancestors a ON t.id = a.parent_id
  WHERE t.deleted_at IS NULL
)
SELECT t.*
FROM tasks t
INNER JOIN ancestors a ON t.id = a.id
WHERE a.depth > 0
ORDER BY a.depth ASC
```

**Benefits:**
- Single query for entire hierarchy
- Handles arbitrary depth
- Excludes soft-deleted items

---

## Edge Cases & Error Handling

### Edge Case 1: Task Edited While Dialog Open

**Scenario:** User opens edit modal, another user/device edits same task, first user saves.

**Current Handling:** Last write wins (no conflict detection).

**For Phase 3.6.5:** Accept this limitation (single-user app assumption).

**Future Enhancement:** Add version field for optimistic locking.

### Edge Case 2: Parent Deleted While Editing

**Scenario:** User selects parent in edit modal, parent gets deleted before save.

**Handling:**
```dart
// In TaskService.updateTask
Future<void> updateTask(...) async {
  // Validate parent exists
  if (parentId != null) {
    final parent = await getTask(parentId);
    if (parent == null || parent.deletedAt != null) {
      throw ArgumentError('Selected parent no longer exists');
    }
  }

  // Proceed with update
  await db.update(...);
}
```

### Edge Case 3: Circular Parent Reference

**Scenario:** User tries to set parent to descendant (creates cycle).

**Prevention:** ParentSelectorDialog filters out descendants with `_isDescendant()` check.

**Additional Safety:**
```dart
// In TaskService.updateTask
Future<void> updateTask(...) async {
  if (parentId != null) {
    // Walk up from parentId to ensure we don't hit taskId
    String? currentId = parentId;
    final visited = <String>{};

    while (currentId != null) {
      if (currentId == taskId) {
        throw ArgumentError('Cannot create circular parent reference');
      }
      if (visited.contains(currentId)) break; // Cycle detection
      visited.add(currentId);

      final parent = await getTask(currentId);
      currentId = parent?.parentId;
    }
  }

  await db.update(...);
}
```

### Edge Case 4: Very Long Breadcrumb

**Scenario:** Task nested 15 levels deep → breadcrumb = "A > B > C > D > E > F > G > H > I > J > K > L > M > N > O"

**Handling:**
```dart
// In metadata view:
Text(
  _breadcrumb,
  overflow: TextOverflow.ellipsis,
  maxLines: 2,
)

// Alternative: Truncate in middle
String _truncateBreadcrumb(String breadcrumb, int maxLength) {
  if (breadcrumb.length <= maxLength) return breadcrumb;

  final parts = breadcrumb.split(' > ');
  if (parts.length <= 3) return breadcrumb; // Too short to truncate

  // Show first, "...", last
  return '${parts.first} > ... > ${parts.last}';
}
```

### Edge Case 5: Notes with 10,000 Characters

**Scenario:** User pastes very long text into notes field.

**Handling:**
```dart
// In edit modal:
TextField(
  controller: _notesController,
  maxLength: 10000, // Enforce limit
  maxLengthEnforcement: MaxLengthEnforcement.enforced,
  decoration: InputDecoration(
    labelText: 'Notes',
    helperText: '${_notesController.text.length}/10000 characters',
  ),
)
```

### Edge Case 6: Completed Parent with 100 Children

**Scenario:** Badge says "(100 incomplete children)" → UI cluttered.

**Handling:**
```dart
// In task_item.dart:
child: Text(
  _getIncompleteChildrenCount(context) > 10
      ? '(10+ incomplete children)'
      : '(${_getIncompleteChildrenCount(context)} incomplete children)',
  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
)
```

---

## Testing Strategy

### Unit Tests

**Test Files to Create:**
1. `test/models/task_test.dart` - Test notes field serialization
2. `test/services/task_service_test.dart` - Test updateTask method
3. `test/providers/task_provider_test.dart` - Test comprehensive update

**Example Test:**
```dart
test('Task.toMap includes notes field', () {
  final task = Task(
    id: '1',
    title: 'Test',
    createdAt: DateTime.now(),
    notes: 'Test notes',
  );

  final map = task.toMap();

  expect(map['notes'], equals('Test notes'));
});

test('Task.fromMap handles null notes', () {
  final map = {
    'id': '1',
    'title': 'Test',
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'completed': 0,
    'notes': null,
  };

  final task = Task.fromMap(map);

  expect(task.notes, isNull);
});
```

### Integration Tests

**Test Scenarios:**
1. Create task → Edit (add notes) → Save → Verify DB
2. Complete parent → Verify dimmed box → Complete children → Verify strikethrough
3. Tap completed task → Metadata opens → Uncomplete → Verify state

### Manual Test Script

**Phase 3.6.5 Acceptance Test:**

```
SETUP:
- Fresh app install OR upgrade from v7
- Create 5 tasks with hierarchy
- Add tags to some tasks
- Complete 2 tasks

TEST 1: Migration
[ ] App starts successfully
[ ] Console shows "✅ Database migrated to v8 successfully"
[ ] All existing tasks load correctly

TEST 2: Edit Modal - Title
[ ] Long-press task → Edit
[ ] Modal opens with current title
[ ] Change title to "Updated Title"
[ ] Click Save
[ ] Verify title updated in list

TEST 3: Edit Modal - Due Date
[ ] Edit task
[ ] Click "No Due Date" button
[ ] Date picker opens
[ ] Select tomorrow
[ ] Verify "Due: [tomorrow]" displays
[ ] Click calendar icon
[ ] Change to next week
[ ] Verify date updated
[ ] Click Clear Date button
[ ] Verify "No Due Date" displays
[ ] Click Save

TEST 4: Edit Modal - Notes
[ ] Edit task
[ ] Type "This is a test note" in Notes field
[ ] Click Save
[ ] Edit task again
[ ] Verify notes appear in field
[ ] Clear notes
[ ] Click Save

TEST 5: Edit Modal - Parent
[ ] Edit task
[ ] Click "No Parent" button
[ ] Search dialog opens
[ ] Type task name
[ ] Verify filtering works
[ ] Select parent
[ ] Verify "Parent: [name]" displays
[ ] Click Save
[ ] Verify task moved under parent

TEST 6: Edit Modal - Tags
[ ] Edit task
[ ] Click "No Tags" button
[ ] Tag picker opens
[ ] Select 2 tags
[ ] Click Apply
[ ] Verify "2 tag(s) selected" displays
[ ] Click Save
[ ] Verify tags appear on task

TEST 7: Edit Modal - Cancel
[ ] Edit task
[ ] Change all fields
[ ] Click Cancel
[ ] Verify NO changes applied

TEST 8: Edit Modal - Validation
[ ] Edit task
[ ] Clear title
[ ] Click Save
[ ] Verify error: "Title cannot be empty"

TEST 9: Completed Task Metadata
[ ] Complete a task with tags and notes
[ ] Tap completed task
[ ] Metadata modal opens
[ ] Verify all fields display:
  - Title (strikethrough)
  - Status "Completed"
  - Hierarchy breadcrumb
  - Created timestamp
  - Completed timestamp
  - Duration
  - Tags
  - Notes

TEST 10: Metadata - View in Context
[ ] In metadata modal
[ ] Click "View in Context"
[ ] Verify modal closes
[ ] Verify task highlighted in main list
[ ] Verify parents expanded

TEST 11: Metadata - Uncomplete
[ ] Open metadata for completed task
[ ] Click "Uncomplete"
[ ] Verify task moves to active list
[ ] Verify no strikethrough

TEST 12: Metadata - Delete
[ ] Open metadata for completed task
[ ] Click "Delete"
[ ] Verify confirmation dialog
[ ] Click Cancel → Verify no deletion
[ ] Click "Delete" again
[ ] Click Delete in confirmation
[ ] Verify task disappears
[ ] Check Recently Deleted → Verify task there

TEST 13: Completed Parent - Visual
[ ] Create parent with 3 children
[ ] Complete parent (children incomplete)
[ ] Verify:
  - Dimmed background box
  - NO strikethrough
  - Badge: "(3 incomplete children)"

TEST 14: Completed Parent - Navigation
[ ] Tap completed parent
[ ] Verify navigation to active tasks
[ ] Verify parent expanded
[ ] Verify children visible

TEST 15: Completed Parent - Fully Complete
[ ] Complete all 3 children
[ ] Verify:
  - Dimmed box disappears
  - Strikethrough appears
  - Badge disappears

TEST 16: Edge Cases
[ ] Edit task with 50+ character title → Verify no overflow
[ ] Edit task with 1000+ character notes → Verify saves
[ ] Create 10-level deep hierarchy → Verify breadcrumb displays
[ ] Complete parent with 20 children → Verify performance

RESULT: [ PASS / FAIL ]
Issues Found: _______________
```

---

## Risk Mitigation

### Risk 1: Migration Failure

**Impact:** HIGH - App won't start, data loss
**Likelihood:** LOW - Simple ALTER TABLE

**Mitigation:**
- Test migration on copy of production database
- Wrap in transaction (atomic)
- Add rollback logic if needed
- Test on devices with different SQLite versions

### Risk 2: Edit Modal Too Complex

**Impact:** MEDIUM - Poor UX, complaints
**Likelihood:** MEDIUM - Many fields to fit

**Mitigation:**
- Try without ScrollView first (per v2 decision)
- Add ScrollView only if overflow occurs
- Test on small screens (phone in landscape)
- Consider splitting into tabs if needed

### Risk 3: Performance Degradation

**Impact:** MEDIUM - Slow UI, user frustration
**Likelihood:** LOW - Simple queries

**Mitigation:**
- Profile breadcrumb generation (should be <100ms)
- Profile completed parent detection (should be <50ms)
- Cache results if needed
- Test with large datasets (1000+ tasks)

### Risk 4: State Management Issues

**Impact:** MEDIUM - UI not updating, data stale
**Likelihood:** LOW - Using proven Provider pattern

**Mitigation:**
- Follow existing patterns (Consumer, notifyListeners)
- Test concurrent edits
- Verify UI rebuilds on all state changes

### Risk 5: Circular Parent Reference

**Impact:** HIGH - App crash, data corruption
**Likelihood:** LOW - Filtered in UI

**Mitigation:**
- UI prevents selection (ParentSelectorDialog filters)
- Add server-side validation in TaskService
- Add database constraint (future enhancement)

---

## Success Criteria

### Phase 3.6.5 Complete When:

**Database:**
- ✅ Migration v8 runs successfully
- ✅ notes column exists and nullable
- ✅ All existing data intact

**Edit Modal:**
- ✅ Opens for any task
- ✅ Shows all current values
- ✅ Allows editing: title, due date, notes, parent, tags
- ✅ Validates title not empty
- ✅ Saves all changes atomically
- ✅ Cancel discards changes
- ✅ No crashes or errors

**Metadata View:**
- ✅ Opens when tapping completed task
- ✅ Shows all task details
- ✅ Breadcrumb displays correctly
- ✅ Duration calculates correctly
- ✅ "View in Context" navigates correctly
- ✅ "Uncomplete" restores task
- ✅ "Delete" soft-deletes with confirmation

**Completed Parent Indicator:**
- ✅ Dimmed box for completed parents with incomplete children
- ✅ NO strikethrough on completed parents
- ✅ Strikethrough ONLY on fully complete tasks
- ✅ Badge shows correct count
- ✅ Tap navigates to children
- ✅ Visual updates when children complete

**No Regressions:**
- ✅ All Phase 3.6B features work
- ✅ Search still functions
- ✅ Filters still work
- ✅ Tag management unchanged
- ✅ Hierarchy operations normal

**Code Quality:**
- ✅ Follows existing patterns
- ✅ No compiler warnings
- ✅ No linter errors
- ✅ Consistent code style
- ✅ Proper error handling

**Phase 3.7 Unblocked:**
- ✅ Due date picker available in edit modal
- ✅ Natural language parsing can integrate

---

**END OF IMPLEMENTATION PLAN**

---

**Next Steps:**
1. Review this plan with Codex and Gemini
2. Address any feedback or concerns
3. Begin Day 1 implementation (migration v8)
4. Follow plan systematically
5. Test thoroughly at each step
6. Document any deviations or discoveries

**Questions for Review:**
- Any patterns we should change?
- Any edge cases we missed?
- Any risks we didn't consider?
- Is the timeline realistic?
- Should we split any features?

