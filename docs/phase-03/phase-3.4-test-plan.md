# Phase 3.4: Task Editing - Test Plan

**Phase:** 3.4 - Task Editing
**Status:** 🔜 Planning
**Created:** 2025-12-27

---

## Test Strategy

### Testing Pyramid

```
                    /\
                   /  \
                  / E2E \
                 /--------\
                /          \
               / Integration \
              /--------------\
             /                \
            /   Unit Tests     \
           /____________________\
```

**Distribution:**
- **Unit Tests (70%):** Service layer, validation logic
- **Integration Tests (20%):** Provider + Service interaction
- **E2E/Manual Tests (10%):** Full user flows

---

## Unit Tests

### TaskService Tests
**File:** `test/services/task_service_edit_test.dart`

#### Test Group: updateTaskTitle()

**Test 1: Successful update**
```dart
test('updateTaskTitle() updates task title successfully', () async {
  // Arrange
  final task = await taskService.createTask('Original Title');

  // Act
  final updated = await taskService.updateTaskTitle(task.id, 'New Title');

  // Assert
  expect(updated.title, 'New Title');
  expect(updated.id, task.id);

  // Verify persistence
  final tasks = await taskService.getAllTasks();
  final found = tasks.firstWhere((t) => t.id == task.id);
  expect(found.title, 'New Title');
});
```

**Test 2: Empty title rejection**
```dart
test('updateTaskTitle() rejects empty title', () async {
  // Arrange
  final task = await taskService.createTask('Original');

  // Act & Assert
  expect(
    () => taskService.updateTaskTitle(task.id, ''),
    throwsA(isA<ArgumentError>()),
  );
});
```

**Test 3: Whitespace-only title rejection**
```dart
test('updateTaskTitle() rejects whitespace-only title', () async {
  // Arrange
  final task = await taskService.createTask('Original');

  // Act & Assert
  expect(
    () => taskService.updateTaskTitle(task.id, '   '),
    throwsA(isA<ArgumentError>()),
  );
});
```

**Test 4: Non-existent task handling**
```dart
test('updateTaskTitle() throws on non-existent task', () async {
  // Act & Assert
  expect(
    () => taskService.updateTaskTitle(99999, 'New Title'),
    throwsA(isA<Exception>()),
  );
});
```

**Test 5: Whitespace trimming**
```dart
test('updateTaskTitle() trims whitespace from title', () async {
  // Arrange
  final task = await taskService.createTask('Original');

  // Act
  final updated = await taskService.updateTaskTitle(task.id, '  Trimmed  ');

  // Assert
  expect(updated.title, 'Trimmed');
});
```

**Test 6: Special characters**
```dart
test('updateTaskTitle() handles special characters', () async {
  // Arrange
  final task = await taskService.createTask('Original');

  // Act
  final updated = await taskService.updateTaskTitle(
    task.id,
    'Task with emoji 🎉 and unicode ✓'
  );

  // Assert
  expect(updated.title, 'Task with emoji 🎉 and unicode ✓');
});
```

**Test 7: Very long title**
```dart
test('updateTaskTitle() handles long titles', () async {
  // Arrange
  final task = await taskService.createTask('Original');
  final longTitle = 'A' * 500; // 500 characters

  // Act
  final updated = await taskService.updateTaskTitle(task.id, longTitle);

  // Assert
  expect(updated.title, longTitle);
  expect(updated.title.length, 500);
});
```

**Test 8: Preserves other fields**
```dart
test('updateTaskTitle() preserves parent, position, completed status', () async {
  // Arrange
  final parent = await taskService.createTask('Parent');
  final child = await taskService.createTask('Child');
  await taskService.updateTaskParent(child.id, parent.id, 0);
  await taskService.toggleComplete(child.id);

  // Act
  final updated = await taskService.updateTaskTitle(child.id, 'Updated Child');

  // Assert
  expect(updated.title, 'Updated Child');
  expect(updated.parentId, parent.id);
  expect(updated.position, 0);
  expect(updated.isCompleted, true);
});
```

---

## Integration Tests

### TaskProvider + TaskService

**File:** `test/providers/task_provider_edit_test.dart`

**Test 1: Provider notifies listeners**
```dart
test('updateTaskTitle() triggers notifyListeners', () async {
  // Arrange
  final provider = TaskProvider();
  await provider.loadTasks();
  final task = provider.activeTasks.first;

  int callCount = 0;
  provider.addListener(() => callCount++);

  // Act
  await provider.updateTaskTitle(task.id, 'New Title');

  // Assert
  expect(callCount, greaterThan(0));
  expect(
    provider.activeTasks.firstWhere((t) => t.id == task.id).title,
    'New Title',
  );
});
```

**Test 2: Error propagation**
```dart
test('updateTaskTitle() propagates errors from service layer', () async {
  // Arrange
  final provider = TaskProvider();

  // Act & Assert
  expect(
    () => provider.updateTaskTitle(99999, 'Title'),
    throwsA(isA<Exception>()),
  );
});
```

---

## Manual Testing Checklist

### Context Menu Integration

- [ ] **Edit option appears**
  - Long-press task → context menu opens
  - "Edit" option visible above "Delete"
  - Appropriate icon displayed

- [ ] **Edit option works for all task types**
  - Root-level task (depth 0)
  - Subtask (depth 1)
  - Deeply nested subtask (depth 3)
  - Completed task
  - Uncompleted task

### Edit Dialog Behavior

- [ ] **Dialog opens correctly**
  - Tapping "Edit" dismisses context menu
  - Dialog appears with current title
  - Text is pre-selected (ready to replace)
  - Keyboard appears automatically

- [ ] **Saving works**
  - Click "Save" button → dialog dismisses, title updates
  - Press Enter key → same behavior
  - Changed title appears immediately in task list
  - SnackBar shows "Task updated" confirmation

- [ ] **Canceling works**
  - Click "Cancel" button → dialog dismisses, no changes
  - Click outside dialog → same behavior
  - Press back button → same behavior
  - Original title remains unchanged

### Input Validation

- [ ] **Empty title**
  - Clear text, click "Save"
  - Error feedback shown OR save button disabled

- [ ] **Whitespace-only title**
  - Enter "   ", click "Save"
  - Error feedback shown OR save button disabled

- [ ] **No changes**
  - Open edit, click "Save" without changes
  - Dialog dismisses gracefully (no error)

- [ ] **Special cases**
  - Very long title (500+ chars) → saves successfully
  - Emoji in title → displays correctly
  - Unicode characters → displays correctly
  - Leading/trailing spaces → trimmed automatically

### UI State Updates

- [ ] **Immediate reflection**
  - Title changes visible without page reload
  - Scroll position maintained
  - Selection/focus state preserved

- [ ] **Parent/child updates**
  - Edit parent task → parent title updates
  - Edit child task → child title updates
  - Hierarchy display remains correct

### Error Handling

- [ ] **Graceful failures**
  - Database error → error message shown
  - Network loss (if applicable) → retry option
  - Task deleted elsewhere → appropriate error

### Performance

- [ ] **Fast response**
  - Edit completes in <100ms
  - No lag when updating UI
  - No jank/stutter in list view

- [ ] **Rapid edits**
  - Edit task A, immediately edit task B
  - No race conditions
  - Both updates persist correctly

### Platform-Specific

- [ ] **Linux Desktop**
  - Click behavior works
  - Keyboard shortcuts work (Enter, Esc)
  - Dialog positioned correctly

- [ ] **Android (if testable)**
  - Touch behavior works
  - Soft keyboard appears/dismisses correctly
  - Back button behavior correct

---

## Regression Testing

### Existing Features Still Work

- [ ] **Task creation** - Creating new tasks unaffected
- [ ] **Task deletion** - Soft delete still works
- [ ] **Task completion** - Toggle complete still works
- [ ] **Task reordering** - Drag & drop still works
- [ ] **Task nesting** - Parent/child relationships maintained
- [ ] **Recently Deleted** - Soft delete screen still works
- [ ] **Settings** - All settings features work

---

## Edge Cases & Stress Tests

### Concurrency

- [ ] Edit task while creating another task
- [ ] Edit task while deleting another task
- [ ] Edit task while reordering tasks
- [ ] Edit same task twice in rapid succession

### Boundary Conditions

- [ ] Edit only task in list
- [ ] Edit first task in large list (1000+ tasks)
- [ ] Edit last task in large list
- [ ] Edit task at maximum nesting depth

### State Transitions

- [ ] Create task → immediately edit
- [ ] Complete task → edit → verify still completed
- [ ] Delete task → (cannot edit, but verify no crash)
- [ ] Edit task → delete → verify deletion works

---

## Accessibility Testing

- [ ] Screen reader announces "Edit" option
- [ ] Keyboard navigation works (Tab, Enter, Esc)
- [ ] Focus indicators visible
- [ ] Color contrast meets WCAG standards
- [ ] Touch targets large enough (48x48dp minimum)

---

## Test Results Template

### Unit Test Results
```
✅ PASS: updateTaskTitle() updates successfully
✅ PASS: updateTaskTitle() rejects empty title
✅ PASS: updateTaskTitle() rejects whitespace-only
✅ PASS: updateTaskTitle() throws on non-existent task
✅ PASS: updateTaskTitle() trims whitespace
✅ PASS: updateTaskTitle() handles special characters
✅ PASS: updateTaskTitle() handles long titles
✅ PASS: updateTaskTitle() preserves other fields

Total: 8/8 passed (100%)
```

### Manual Test Results
```
✅ Context menu shows Edit option
✅ Edit dialog opens with pre-selected text
✅ Saving updates title immediately
✅ Canceling preserves original title
✅ Empty title validation works
✅ Special characters handled correctly
✅ No regressions in existing features

Total: X/Y passed (XX%)
```

---

## Bug Tracking

### Critical Bugs (Blockers)
*None yet*

### High Priority Bugs
*None yet*

### Medium Priority Bugs
*None yet*

### Low Priority / Nice-to-Fix
*None yet*

---

## Sign-off

- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Manual testing complete
- [ ] No critical/high bugs remaining
- [ ] Performance acceptable
- [ ] Ready for merge

**Tested by:** ⏳ Pending
**Test Date:** ⏳ Pending
**Status:** ⏳ Not started
