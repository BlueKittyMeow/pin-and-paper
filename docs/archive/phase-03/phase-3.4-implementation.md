# Phase 3.4: Task Editing - Implementation Plan

**Status:** ✅ REVIEWED & CORRECTED (Ready for Implementation)
**Created:** 2025-12-27
**Last Updated:** 2025-12-27 (Post-Review)
**Branch:** phase-3.4
**Priority:** HIGH (Missing core feature)

> **📋 PRE-IMPLEMENTATION REVIEW COMPLETE**
>
> This plan was reviewed by Gemini and Codex and **7 critical bugs were caught** before any code was written:
> - 1 CRITICAL bug (wrong data type - would not compile)
> - 3 HIGH priority bugs (performance, UX, architecture)
> - 3 MEDIUM priority bugs (optimization, validation, testing)
>
> All issues have been corrected in this document. See `claude-findings.md` for detailed analysis.
> **Review Grade: A+** (saved hours of debugging!)

---

## Overview

**Goal:** Add ability to edit existing tasks via the context menu

**Current State:**
- Long-pressing a task opens context menu with only "Delete" option
- No way to edit task title after creation
- Users must delete and recreate tasks to fix typos/changes

**Target State:**
- Context menu includes "Edit" option
- Tapping "Edit" opens inline edit dialog
- Changes save immediately to database
- UI updates instantly via TaskProvider

---

## Problem Statement

### User Pain Point
From user: "We need to add that we will need to have ability to edit a task lol. Right now long pressing only brings up delete menu"

**Impact:** Users cannot fix typos or update task titles without deleting and recreating the task, which loses:
- Task position in hierarchy
- Completed status
- Creation timestamp
- Any future metadata (tags, due dates, etc.)

### Technical Gap
The `task_context_menu.dart` widget currently only handles:
- Soft delete confirmation
- Delete action execution

No edit functionality exists at any layer.

---

## Requirements

### Functional Requirements

**FR-1: Edit Option in Context Menu**
- Add "Edit" option to context menu alongside "Delete"
- Position "Edit" above "Delete" (safer action first)
- Use appropriate icon (Icons.edit or Icons.edit_outlined)

**FR-2: Edit Dialog/Sheet**
- Modal interface for editing task title
- Pre-populate with current task title
- TextField with autofocus and text selection
- "Cancel" and "Save" buttons
- Keyboard submit triggers save
- Dialog dismisses on save/cancel

**FR-3: Database Persistence**
- Update task title in SQLite via TaskService
- Maintain all other task properties (id, parent_id, position, etc.)
- Update `updated_at` timestamp (if we add this field)

**FR-4: UI State Update**
- TaskProvider notifies listeners after update
- UI reflects new title immediately
- No full page reload required

**FR-5: Validation**
- Empty titles not allowed
- Whitespace-only titles not allowed
- Show error feedback for invalid input
- Max length validation (if we add this constraint)

### Non-Functional Requirements

**NFR-1: Performance**
- Edit operation completes in <100ms
- No perceived lag in UI update

**NFR-2: UX Consistency**
- Follow Material 3 design patterns
- Match existing dialog/sheet styling
- Consistent with brain dump input experience

**NFR-3: Error Handling**
- Handle database errors gracefully
- Show user-friendly error messages
- Log errors for debugging

---

## Technical Design

### Architecture Layers

```
UI Layer (widgets/task_context_menu.dart)
    ↓ User taps "Edit"
    ↓ Shows edit dialog
    ↓ User enters new title
    ↓ Calls TaskProvider.updateTaskTitle()

Provider Layer (providers/task_provider.dart)
    ↓ Validates input
    ↓ Calls TaskService.updateTaskTitle()
    ↓ On success: notifyListeners()

Service Layer (services/task_service.dart)
    ↓ Executes SQL UPDATE
    ↓ Returns updated Task object

Database Layer (SQLite)
    ↓ UPDATE tasks SET title = ? WHERE id = ?
```

### Database Changes

**Option 1: No schema changes** (Recommended for Phase 3.4)
- Use existing `tasks` table structure
- Only update `title` field
- Keep migration simple

**Option 2: Add `updated_at` field** (Future enhancement)
- Track when tasks were last modified
- Requires database migration
- Save for Phase 4+

**Decision:** Start with Option 1 for simplicity

### Code Changes Required

> **⚠️ UPDATED AFTER GEMINI/CODEX REVIEW (2025-12-27)**
>
> The original plan had several critical bugs caught during pre-implementation review:
> - ❌ Used `int taskId` instead of `String taskId` (CRITICAL - would not compile)
> - ❌ Called `loadTasks()` after update (HIGH - performance + tree collapse)
> - ❌ Redundant database query (MEDIUM - wasteful)
> - ❌ Wrong widget pattern (HIGH - doesn't match existing code)
>
> All code below has been corrected based on review feedback.
> See `claude-findings.md` for full analysis.

#### 1. TaskService Layer
**File:** `lib/services/task_service.dart`

Add method:
```dart
/// Updates the title of an existing task
/// Returns the updated Task object
///
/// OPTIMIZED: Fetch-first approach to avoid redundant query (Gemini feedback)
Future<Task> updateTaskTitle(String taskId, String newTitle) async {
  final db = await DatabaseService.instance.database;
  final trimmedTitle = newTitle.trim();

  // Validate title
  if (trimmedTitle.isEmpty) {
    throw ArgumentError('Task title cannot be empty');
  }

  // Fetch the original task first to have all its data
  final maps = await db.query(
    AppConstants.tasksTable,
    where: 'id = ?',
    whereArgs: [taskId],
  );

  if (maps.isEmpty) {
    throw Exception('Task not found: $taskId');
  }

  final originalTask = Task.fromMap(maps.first);

  // Perform the update
  await db.update(
    AppConstants.tasksTable,
    {'title': trimmedTitle},
    where: 'id = ?',
    whereArgs: [taskId],
  );

  // Return updated copy (leverages existing copyWith method)
  return originalTask.copyWith(title: trimmedTitle);
}
```

#### 2. TaskProvider Layer
**File:** `lib/providers/task_provider.dart`

Add method:
```dart
/// Updates a task's title
///
/// OPTIMIZED: In-memory update to avoid:
/// - Full database reload (Gemini feedback - performance)
/// - TreeController collapse (Codex feedback - UX regression)
Future<void> updateTaskTitle(String taskId, String newTitle) async {
  try {
    final updatedTask = await _taskService.updateTaskTitle(taskId, newTitle);

    // Find and update the task in-memory
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    } else {
      // Fallback: reload if task not found (shouldn't happen)
      await loadTasks();
    }
  } catch (e) {
    debugPrint('Error updating task title: $e');
    rethrow; // Let UI handle error display
  }
}
```

#### 3. Context Menu Widget
**File:** `lib/widgets/task_context_menu.dart`

**CORRECTED:** Match existing `showMenu` pattern (Codex feedback - architectural consistency)

Current widget structure (lines 6-56):
```dart
class TaskContextMenu extends StatelessWidget {
  final Task task;
  final VoidCallback? onDelete;

  // ... builds Column with ListTile children
}
```

**Changes needed:**

1. **Add `onEdit` callback parameter:**
```dart
class TaskContextMenu extends StatelessWidget {
  final Task task;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit; // ADD THIS

  const TaskContextMenu({
    super.key,
    required this.task,
    this.onDelete,
    this.onEdit, // ADD THIS
  });
```

2. **Add "Edit" ListTile to Column (BEFORE delete tile):**
```dart
@override
Widget build(BuildContext context) {
  return Material(
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(/* ... */),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // NEW: Edit option (add BEFORE delete)
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              onEdit?.call();
            },
          ),

          // EXISTING: Delete option
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Move to Trash',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onDelete?.call();
            },
          ),
        ],
      ),
    ),
  );
}
```

3. **Update static `show()` method to accept `onEdit` parameter:**
```dart
static Future<void> show({
  required BuildContext context,
  required Task task,
  required Offset position,
  VoidCallback? onDelete,
  VoidCallback? onEdit, // ADD THIS
}) async {
  await showMenu(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: [
      PopupMenuItem(
        padding: EdgeInsets.zero,
        child: TaskContextMenu(
          task: task,
          onDelete: onDelete,
          onEdit: onEdit, // PASS IT THROUGH
        ),
      ),
    ],
  );
}
```

#### 4. Edit Dialog Implementation
**File:** Where task list is rendered (e.g., `lib/screens/home_screen.dart` or tree view)

**Add edit dialog helper function:**
```dart
/// Shows edit dialog for a task
/// SIMPLIFIED: Validation moved to service layer (Gemini feedback)
Future<void> _showEditDialog(BuildContext context, Task task) async {
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

  // Service layer handles validation and trimming
  if (result != null) {
    try {
      await context.read<TaskProvider>().updateTaskTitle(task.id, result);

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

  controller.dispose();
}
```

**Wire up to context menu:**
```dart
// When showing context menu (on long-press)
await TaskContextMenu.show(
  context: context,
  task: task,
  position: position,
  onDelete: () => _handleDelete(task),
  onEdit: () => _showEditDialog(context, task), // ADD THIS
);
```

---

## Implementation Checklist

### Phase 1: Core Functionality
- [ ] Create `phase-3.4` branch
- [ ] Add `updateTaskTitle()` method to TaskService
- [ ] Add corresponding method to TaskProvider
- [ ] Update `task_context_menu.dart` to add "Edit" option
- [ ] Implement edit dialog with TextField
- [ ] Wire up save/cancel actions
- [ ] Test basic edit functionality manually

### Phase 2: Polish & Edge Cases
- [ ] Add input validation (empty, whitespace-only)
- [ ] Add error handling and user feedback
- [ ] Ensure keyboard dismisses properly
- [ ] Test with very long task titles
- [ ] Test with special characters
- [ ] Verify UI updates immediately after edit

### Phase 3: Testing
- [ ] Write unit tests for `updateTaskTitle()`
- [ ] Test validation logic (empty title rejection)
- [ ] Test error handling (non-existent task ID)
- [ ] **NEW:** Write widget tests for UI layer (Codex feedback)
  - [ ] Context menu shows Edit option
  - [ ] Edit dialog pre-populates title
  - [ ] Save button updates task
  - [ ] Cancel button preserves original
  - [ ] SnackBar shows on success/error
- [ ] Manual testing on Linux
- [ ] Manual testing on Android (if available)
- [ ] Test with subtasks (ensure editing parent/child works)

### Phase 4: Documentation & Merge
- [ ] Update post-implementation review
- [ ] Update CHANGELOG
- [ ] Commit with descriptive message
- [ ] Push branch
- [ ] Merge to main
- [ ] Delete feature branch

---

## Testing Strategy

### Unit Tests (Service Layer)
**File:** `test/services/task_service_edit_test.dart`

Test cases:
1. `updateTaskTitle() updates task successfully` (String ID)
2. `updateTaskTitle() rejects empty title`
3. `updateTaskTitle() rejects whitespace-only title`
4. `updateTaskTitle() throws on non-existent task`
5. `updateTaskTitle() trims whitespace from title`
6. `updateTaskTitle() returns updated Task object`
7. `updateTaskTitle() preserves other task fields`
8. `updateTaskTitle() handles special characters`

### Widget Tests (UI Layer) - NEW per Codex Feedback
**File:** `test/widgets/task_edit_widget_test.dart`

**Rationale:** Unit tests only cover service layer. Most bugs in UI features come from widget layer: wrong callbacks, missing mounted checks, improper dialog dismissal. (Codex feedback)

Test cases:
1. **Context menu displays Edit option**
   - Render task list
   - Long-press task
   - Verify context menu shows "Edit" above "Delete"

2. **Edit dialog opens with pre-populated title**
   - Tap Edit option
   - Verify dialog appears
   - Verify TextField contains current task title
   - Verify text is selected

3. **Save button updates task**
   - Open edit dialog
   - Enter new title
   - Tap Save
   - Verify `provider.updateTaskTitle()` called with correct args
   - Verify dialog dismisses
   - Verify SnackBar shows "Task updated"

4. **Cancel preserves original title**
   - Open edit dialog
   - Change title
   - Tap Cancel
   - Verify task title unchanged
   - Verify no provider calls made

5. **Empty title shows error**
   - Open edit dialog
   - Clear text
   - Tap Save
   - Verify error SnackBar shown
   - Verify task unchanged

### Manual Testing Scenarios
1. Edit root-level task
2. Edit subtask (depth > 0)
3. Edit completed task
4. Edit task then immediately edit again
5. Cancel edit (ensure no changes)
6. Edit to same title (no-op)
7. Very long title (100+ chars)
8. Special characters (emoji, unicode)
9. Edit deleted task (should fail gracefully)

### Edge Cases
- User clicks "Edit" but enters empty string → Show validation error
- User clicks "Edit" but clicks "Cancel" → No changes made
- Database error during save → Show error message
- Task deleted by another process during edit → Handle gracefully

---

## Success Criteria

**Must Have:**
- ✅ "Edit" option appears in context menu
- ✅ Edit dialog opens with current title pre-filled
- ✅ Saving updates title in database
- ✅ UI reflects changes immediately
- ✅ Empty titles rejected
- ✅ Basic unit tests pass

**Should Have:**
- ✅ Keyboard auto-shows and auto-dismisses
- ✅ Enter key submits edit
- ✅ Text auto-selected for easy replacement
- ✅ Error feedback for invalid input

**Nice to Have:**
- ⏳ Undo/redo for edits (future)
- ⏳ Edit history (future)
- ⏳ Multi-field edit (add description, tags, etc.) (future)

---

## Risk Assessment

### Low Risk
- Database update logic (simple SQL UPDATE)
- UI state management (existing pattern)

### Medium Risk
- TextField keyboard behavior on different platforms
- Context menu dismissed before edit dialog shows
- Race conditions with rapid edits

### Mitigation Strategies
- Test on both Linux and Android early
- Use `Navigator.pop()` + `await` pattern for proper sequencing
- Disable edit button during save operation
- Add debouncing if needed

---

## Future Enhancements (Post-Phase 3.4)

**Phase 4+ Ideas:**
1. **Inline editing** - Edit task title directly in list view
2. **Multi-field edit** - Edit title, tags, due date in one dialog
3. **Edit history** - Track changes over time
4. **Undo/redo** - Revert recent edits
5. **Batch edit** - Edit multiple tasks at once
6. **Rich text editing** - Markdown, formatting, etc.

---

## Notes

- Keep implementation simple for Phase 3.4
- Focus on reliability over features
- Follow existing code patterns
- Maintain consistency with brain dump input
- Consider accessibility (screen readers, keyboard nav)

---

## Sign-off

**Planning complete:** ⏳ Waiting for implementation
**Implementation complete:** ⏳ Pending
**Testing complete:** ⏳ Pending
**Merged to main:** ⏳ Pending
