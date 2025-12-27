# Phase 3.2 Test Plan
**Hierarchical Tasks, Drag-and-Drop, and Breadcrumb Navigation**

## Overview
This test plan validates all features implemented in Phase 3.2, including hierarchical task management, drag-and-drop reordering, context menus, breadcrumb navigation, and smart visibility logic.

## Test Categories

### 1. Unit Tests - TaskService (lib/services/task_service.dart)

#### 1.1 Hierarchical Query Methods

**Test: `getTaskHierarchy()` returns tasks with correct depth**
- Setup: Create task hierarchy: Root → Child → Grandchild
- Execute: Call `getTaskHierarchy()`
- Verify:
  - Root task has depth = 0
  - Child task has depth = 1
  - Grandchild task has depth = 2
  - All tasks returned in correct order

**Test: `getTaskHierarchy()` handles orphaned tasks**
- Setup: Create task with invalid parent_id (parent doesn't exist)
- Execute: Call `getTaskHierarchy()`
- Verify:
  - Orphaned task is treated as root (depth = 0)
  - No errors thrown

**Test: `getTaskWithDescendants()` fetches entire subtree**
- Setup: Create hierarchy: Parent → [Child1, Child2] → [Grandchild1, Grandchild2]
- Execute: Call `getTaskWithDescendants(parentId)`
- Verify:
  - Parent included
  - Both children included
  - Both grandchildren included
  - Total: 5 tasks

**Test: `getTaskWithDescendants()` returns only task if no children**
- Setup: Create single task with no children
- Execute: Call `getTaskWithDescendants(taskId)`
- Verify: Only the single task returned

**Test: `countDescendants()` returns accurate count**
- Setup: Create hierarchy: Parent → [Child1, Child2] → Grandchild
- Execute: Call `countDescendants(parentId)`
- Verify: Returns 3 (2 children + 1 grandchild)

**Test: `countDescendants()` returns 0 for childless tasks**
- Setup: Create single task
- Execute: Call `countDescendants(taskId)`
- Verify: Returns 0

#### 1.2 Parent Update Methods

**Test: `updateTaskParent()` successfully nests task**
- Setup: Create two root tasks (TaskA, TaskB)
- Execute: `updateTaskParent(TaskB.id, TaskA.id, position: 0)`
- Verify:
  - TaskB.parentId = TaskA.id
  - TaskB.position = 0
  - TaskB.depth = 1

**Test: `updateTaskParent()` successfully unnests task**
- Setup: Create hierarchy: Parent → Child
- Execute: `updateTaskParent(Child.id, null, position: 0)`
- Verify:
  - Child.parentId = null
  - Child.depth = 0
  - Child is now root task

**Test: `updateTaskParent()` prevents circular reference**
- Setup: Create hierarchy: Parent → Child
- Execute: `updateTaskParent(Parent.id, Child.id, position: 0)`
- Verify: Error returned or prevented (cannot make parent a child of its descendant)

**Test: `updateTaskPosition()` reorders siblings correctly**
- Setup: Create Parent → [Child1, Child2, Child3]
- Execute: `updateTaskPosition(Child3.id, position: 0)`
- Verify:
  - Child3.position = 0
  - Child1.position = 1
  - Child2.position = 2
  - Order updated correctly

#### 1.3 Delete Methods

**Test: `deleteTaskWithChildren()` CASCADE deletes entire subtree**
- Setup: Create Parent → [Child1, Child2] → Grandchild
- Execute: `deleteTaskWithChildren(Parent.id)`
- Verify:
  - Parent deleted
  - Child1 deleted
  - Child2 deleted
  - Grandchild deleted
  - Returns deleted count = 4

**Test: `deleteTaskWithChildren()` deletes single task with no children**
- Setup: Create single task
- Execute: `deleteTaskWithChildren(taskId)`
- Verify:
  - Task deleted
  - Returns deleted count = 1

---

### 2. Unit Tests - TaskProvider (lib/providers/task_provider.dart)

#### 2.1 Visibility Logic

**Test: `_hasIncompleteDescendants()` detects incomplete children**
- Setup: Create completed Parent → [completed Child1, incomplete Child2]
- Execute: `_hasIncompleteDescendants(Parent)`
- Verify: Returns true

**Test: `_hasIncompleteDescendants()` detects incomplete grandchildren**
- Setup: Create completed Parent → completed Child → incomplete Grandchild
- Execute: `_hasIncompleteDescendants(Parent)`
- Verify: Returns true (deep check)

**Test: `_hasIncompleteDescendants()` returns false when all complete**
- Setup: Create completed Parent → [completed Child1, completed Child2]
- Execute: `_hasIncompleteDescendants(Parent)`
- Verify: Returns false

**Test: `visibleCompletedTasks` excludes tasks with incomplete descendants**
- Setup: Create completed Parent → incomplete Child
- Execute: Get `visibleCompletedTasks`
- Verify:
  - Parent NOT in list (has incomplete child)
  - Child NOT in list (not completed)

**Test: `visibleCompletedTasks` includes fully completed subtrees**
- Setup: Create completed Parent → completed Child
- Execute: Get `visibleCompletedTasks`
- Verify:
  - Both Parent and Child in list
  - Both marked as completed

**Test: `_refreshTreeController()` keeps completed parents in active tree**
- Setup: Create completed Parent → incomplete Child
- Execute: `_refreshTreeController()`
- Verify: Parent in treeController.roots (active section)

**Test: `_refreshTreeController()` removes fully completed from active tree**
- Setup: Create completed Parent → completed Child
- Execute: `_refreshTreeController()`
- Verify: Parent NOT in treeController.roots (moved to completed section)

#### 2.2 Breadcrumb Generation

**Test: `getBreadcrumb()` returns null for root tasks**
- Setup: Create root task
- Execute: `getBreadcrumb(rootTask)`
- Verify: Returns null

**Test: `getBreadcrumb()` returns parent name for child**
- Setup: Create Parent → Child
- Execute: `getBreadcrumb(Child)`
- Verify: Returns "Parent"

**Test: `getBreadcrumb()` returns full path for deep nesting**
- Setup: Create Root → Parent → Child → Grandchild
- Execute: `getBreadcrumb(Grandchild)`
- Verify: Returns "Root > Parent > Child"

**Test: `getBreadcrumb()` handles orphaned tasks gracefully**
- Setup: Create task with invalid parent_id
- Execute: `getBreadcrumb(task)`
- Verify: Returns null or empty string (no crash)

#### 2.3 Drag-and-Drop Logic

**Test: `onNodeAccepted()` calculates correct position for drop above**
- Setup: Create Parent → [Child1, Child2, Child3]
- Execute: Drag Child3 above Child1
- Verify: Child3.position = 0 (using actual index, not stale DB value)

**Test: `onNodeAccepted()` calculates correct position for drop below**
- Setup: Create Parent → [Child1, Child2, Child3]
- Execute: Drag Child1 below Child3
- Verify: Child1.position = 3 (after Child3)

**Test: `onNodeAccepted()` nests task when dropped inside**
- Setup: Create two root tasks (TaskA, TaskB)
- Execute: Drag TaskB inside TaskA
- Verify:
  - TaskB.parentId = TaskA.id
  - TaskB.position = 0 (first child)

**Test: `onNodeAccepted()` enforces max depth limit**
- Setup: Create 4-level hierarchy
- Execute: Try to nest another task under level 4
- Verify:
  - Error message shown
  - Task not moved
  - Depth remains at original level

**Test: `onNodeAccepted()` updates sibling positions after reorder**
- Setup: Create Parent → [Child1, Child2, Child3]
- Execute: Move Child3 to position 0
- Verify:
  - Child3.position = 0
  - Child1.position = 1
  - Child2.position = 2

---

### 3. Widget Tests

#### 3.1 TaskItem Widget

**Test: `TaskItem` displays breadcrumb when provided**
- Setup: Create TaskItem with breadcrumb = "Parent > Child"
- Execute: Render widget
- Verify:
  - Breadcrumb text visible above task title
  - Breadcrumb styled with smaller font
  - Breadcrumb has reduced opacity

**Test: `TaskItem` hides breadcrumb when null**
- Setup: Create TaskItem with breadcrumb = null
- Execute: Render widget
- Verify: No breadcrumb text displayed

**Test: `TaskItem` wraps long breadcrumbs**
- Setup: Create TaskItem with very long breadcrumb (50+ characters)
- Execute: Render widget
- Verify:
  - Breadcrumb wraps to multiple lines
  - No horizontal overflow

**Test: `TaskItem` shows expand icon when hasChildren = true**
- Setup: Create TaskItem with hasChildren = true
- Execute: Render widget
- Verify: Arrow icon visible next to checkbox

**Test: `TaskItem` hides expand icon when hasChildren = false**
- Setup: Create TaskItem with hasChildren = false
- Execute: Render widget
- Verify: No arrow icon, just spacer for alignment

**Test: `TaskItem` toggles expand icon on collapse state change**
- Setup: Create TaskItem with isExpanded = false, then true
- Execute: Toggle expansion
- Verify: Icon changes from right arrow to down arrow

**Test: `TaskItem` disables context menu in reorder mode**
- Setup: Create TaskItem with isReorderMode = true
- Execute: Long press on task
- Verify: No context menu appears (drag should happen instead)

**Test: `TaskItem` shows drag handle in reorder mode**
- Setup: Create TaskItem with isReorderMode = true
- Execute: Render widget
- Verify: Drag handle icon visible on right side

#### 3.2 DragAndDropTaskTile Widget

**Test: `DragAndDropTaskTile` shows border on top when hovering above**
- Setup: Drag task over top 30% of another task
- Execute: Hover in drop zone
- Verify: Border appears on top edge

**Test: `DragAndDropTaskTile` shows border around when hovering inside**
- Setup: Drag task over middle 40% of another task
- Execute: Hover in drop zone
- Verify: Border appears around entire task

**Test: `DragAndDropTaskTile` shows border on bottom when hovering below**
- Setup: Drag task over bottom 30% of another task
- Execute: Hover in drop zone
- Verify: Border appears on bottom edge

**Test: `DragAndDropTaskTile` shows opacity when dragging**
- Setup: Start dragging a task
- Execute: Drag in progress
- Verify:
  - Original position shows reduced opacity (0.3)
  - Drag feedback shows full opacity with elevation

**Test: `DragAndDropTaskTile` respects longPressDelay on mobile**
- Setup: Create tile on mobile platform
- Execute: Check longPressDelay
- Verify: Set to 500ms for mobile, null for desktop

#### 3.3 TaskContextMenu Widget

**Test: `TaskContextMenu` shows delete option**
- Setup: Long press on task
- Execute: Context menu appears
- Verify: "Delete" option visible

**Test: `TaskContextMenu` positions menu at touch point**
- Setup: Long press on task at specific coordinates
- Execute: Menu appears
- Verify: Menu positioned near touch coordinates

**Test: `DeleteTaskDialog` shows child count warning**
- Setup: Task has 3 children
- Execute: Show delete dialog
- Verify:
  - Warning message visible
  - "This will also delete 3 subtasks" text shown
  - Warning styled with error color

**Test: `DeleteTaskDialog` hides warning for childless tasks**
- Setup: Task has 0 children
- Execute: Show delete dialog
- Verify: No warning message shown

**Test: `DeleteTaskDialog` has cancel and delete buttons**
- Setup: Show delete dialog
- Execute: Check buttons
- Verify:
  - "Cancel" button present
  - "Delete" button present in error color

---

### 4. Integration Tests

#### 4.1 Complete Task Workflows

**Test: Complete child task shows in completed section with breadcrumb**
- Steps:
  1. Create Parent → Child
  2. Complete Child
  3. Check completed section
- Verify:
  - Child appears in completed section
  - Breadcrumb shows "Parent"
  - Parent remains in active section

**Test: Complete parent with incomplete children keeps parent in active**
- Steps:
  1. Create Parent → [Child1, Child2]
  2. Complete Parent only
  3. Check active section
- Verify:
  - Parent in active section with strikethrough
  - Parent is expandable
  - Child1 and Child2 visible and checkable

**Test: Complete all children moves parent to completed**
- Steps:
  1. Create completed Parent → [incomplete Child1, incomplete Child2]
  2. Complete Child1
  3. Complete Child2
  4. Check completed section
- Verify:
  - Parent moved to completed section
  - Child1 in completed section with breadcrumb
  - Child2 in completed section with breadcrumb

**Test: Deep hierarchy - complete grandchild shows correct breadcrumb**
- Steps:
  1. Create Root → Parent → Child
  2. Complete Child
  3. Check completed section
- Verify:
  - Child in completed section
  - Breadcrumb shows "Root > Parent"

#### 4.2 Drag-and-Drop Workflows

**Test: Drag sibling above another reorders correctly**
- Steps:
  1. Create Parent → [Child1, Child2, Child3]
  2. Enter reorder mode
  3. Long press Child3
  4. Drag above Child1
  5. Drop
  6. Exit reorder mode
- Verify:
  - Order is now: Child3, Child1, Child2
  - Positions updated in database
  - Order persists after app reload

**Test: Drag sibling below another reorders correctly**
- Steps:
  1. Create Parent → [Child1, Child2, Child3]
  2. Enter reorder mode
  3. Drag Child1 below Child3
  4. Drop
- Verify:
  - Order is now: Child2, Child3, Child1
  - Positions correct

**Test: Drag root task inside another creates nesting**
- Steps:
  1. Create two root tasks: TaskA, TaskB
  2. Enter reorder mode
  3. Drag TaskB onto middle of TaskA
  4. Drop
- Verify:
  - TaskB is now child of TaskA
  - TaskA shows expand icon
  - TaskA can be expanded to show TaskB

**Test: Drag child task to root level**
- Steps:
  1. Create Parent → Child
  2. Enter reorder mode
  3. Drag Child above/below Parent (at root level)
  4. Drop
- Verify:
  - Child is now root task
  - Parent no longer has expand icon
  - Both at same indentation level

**Test: Cannot exceed max depth of 4 levels**
- Steps:
  1. Create 4-level hierarchy
  2. Create another task
  3. Try to nest it under level 4
- Verify:
  - Error message shown
  - Task not moved
  - Original structure preserved

**Test: Drag-and-drop persists after reload**
- Steps:
  1. Perform any drag-and-drop operation
  2. Exit app
  3. Reload app
- Verify: New order/hierarchy maintained

#### 4.3 Delete Workflows

**Test: Delete childless task removes only that task**
- Steps:
  1. Create single task
  2. Long press task
  3. Select "Delete"
  4. Confirm dialog
- Verify:
  - Task removed from list
  - No other tasks affected
  - No child count warning shown

**Test: Delete parent shows cascade warning**
- Steps:
  1. Create Parent → [Child1, Child2]
  2. Long press Parent
  3. Select "Delete"
- Verify:
  - Dialog shows "This will also delete 2 subtasks"
  - Warning styled prominently

**Test: Delete parent removes entire subtree**
- Steps:
  1. Create Parent → [Child1, Child2] → Grandchild
  2. Delete Parent
  3. Confirm
- Verify:
  - Parent deleted
  - Child1 deleted
  - Child2 deleted
  - Grandchild deleted
  - Total: 4 tasks removed

**Test: Cancel delete preserves all tasks**
- Steps:
  1. Create Parent → Child
  2. Long press Parent
  3. Select "Delete"
  4. Click "Cancel"
- Verify:
  - No tasks deleted
  - Hierarchy intact

**Test: Delete refreshes UI correctly**
- Steps:
  1. Create and delete a task
  2. Check task list
- Verify:
  - Deleted task not visible
  - No ghost tasks
  - UI updated immediately

#### 4.4 Expand/Collapse Workflows

**Test: Expand parent shows children**
- Steps:
  1. Create Parent → [Child1, Child2]
  2. Click expand icon on Parent
- Verify:
  - Child1 visible and indented
  - Child2 visible and indented
  - Icon changes to down arrow

**Test: Collapse parent hides children**
- Steps:
  1. Create expanded Parent → [Child1, Child2]
  2. Click collapse icon
- Verify:
  - Children hidden
  - Icon changes to right arrow

**Test: Expand state persists in active section**
- Steps:
  1. Expand Parent
  2. Complete a different task
  3. Check Parent
- Verify: Parent still expanded

**Test: Deep hierarchy expansion**
- Steps:
  1. Create Root → Parent → Child → Grandchild
  2. Expand Root
  3. Expand Parent
  4. Expand Child
- Verify:
  - All levels visible
  - Correct indentation (24px per level)
  - All expand icons correct

---

### 5. Edge Cases

#### 5.1 Data Integrity

**Test: Orphaned task handling**
- Setup: Manually delete parent from database
- Execute: Load tasks
- Verify:
  - Child treated as root task
  - No crash
  - Child has depth = 0

**Test: Invalid depth in database**
- Setup: Manually set depth to -1 or 999
- Execute: Load tasks
- Verify:
  - Depth recalculated correctly by CTE
  - Display matches actual hierarchy

**Test: Circular reference prevention**
- Setup: Attempt to create Parent → Child → Parent loop
- Execute: Try to update parent
- Verify: Error or prevention mechanism works

**Test: Position gaps handling**
- Setup: Create siblings with positions [0, 2, 5] (gaps)
- Execute: Reorder tasks
- Verify:
  - Display order correct
  - Reordering works
  - Positions recalculated on update

#### 5.2 UI Edge Cases

**Test: Very long task title with breadcrumb**
- Setup: Create task with 100+ character title and long breadcrumb
- Execute: Display in completed section
- Verify:
  - Both wrap correctly
  - No horizontal overflow
  - Card height adjusts

**Test: Empty states**
- Setup: Delete all tasks
- Execute: View home screen
- Verify:
  - "No tasks yet" message shown
  - No divider shown
  - No completed section shown

**Test: Only completed tasks state**
- Setup: Create only completed tasks
- Execute: View home screen
- Verify:
  - No active section
  - Only divider and completed section visible

**Test: Only active tasks state**
- Setup: Create only active tasks
- Execute: View home screen
- Verify:
  - Active section visible
  - No divider
  - No completed section

**Test: Rapid expand/collapse**
- Setup: Create Parent → Children
- Execute: Click expand icon repeatedly
- Verify:
  - No visual glitches
  - State updates correctly
  - No crashes

**Test: Drag to max depth boundary**
- Setup: Create 3-level hierarchy
- Execute: Drag task to create level 4 (allowed), then try level 5 (not allowed)
- Verify:
  - Level 4 succeeds
  - Level 5 shows error
  - Clear feedback to user

#### 5.3 Performance

**Test: Large hierarchy (100+ tasks)**
- Setup: Create hierarchy with 10 parents, 10 children each
- Execute: Load, expand, collapse, reorder
- Verify:
  - Loads in reasonable time (<2s)
  - UI remains responsive
  - No lag during drag-and-drop

**Test: Deep nesting (max depth)**
- Setup: Create 4-level deep hierarchy
- Execute: Expand all, collapse all
- Verify:
  - Operations smooth
  - Correct indentation
  - No visual glitches

**Test: Breadcrumb generation performance**
- Setup: Create many deeply nested tasks
- Execute: Complete them all
- Verify:
  - Breadcrumbs generate quickly
  - No UI lag
  - Completed section renders smoothly

---

## Test Execution Priority

### P0 - Critical (Must pass before Phase 3.3)
1. TaskService: getTaskHierarchy, deleteTaskWithChildren, updateTaskParent
2. TaskProvider: _hasIncompleteDescendants, visibleCompletedTasks, onNodeAccepted
3. Integration: Complete parent workflow, drag-and-drop sibling reorder, CASCADE delete

### P1 - High (Should pass)
1. TaskService: countDescendants, updateTaskPosition
2. TaskProvider: getBreadcrumb, _refreshTreeController
3. Widget: TaskItem breadcrumb display, expand/collapse
4. Integration: Breadcrumb display, expand/collapse workflows

### P2 - Medium (Nice to have)
1. Edge cases: Orphaned tasks, circular references
2. Performance: Large hierarchies
3. UI: Long titles, empty states

## Test Implementation Notes

- Use Flutter's built-in test framework
- Mock database for unit tests
- Use `pumpWidget` for widget tests
- Integration tests should use real database (or well-mocked)
- Consider using golden tests for UI consistency
- Run tests on both Android and iOS if possible

## Success Criteria

**Phase 3.2 is considered tested and ready when:**
- ✅ All P0 tests pass
- ✅ 90%+ of P1 tests pass
- ✅ No critical bugs found
- ✅ Performance acceptable on test devices
- ✅ Edge cases handled gracefully (no crashes)
