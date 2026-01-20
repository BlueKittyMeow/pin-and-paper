# Phase 3.6.5 Detailed Implementation Plan - Version 3

**Document Type:** Ultrathink Deep Planning (Final)
**Created:** 2026-01-20
**Revised:** 2026-01-20
**Status:** ✅ Approved for Implementation
**Based On:** phase-3.6.5-plan-v2.md + All Pre-Implementation Reviews (Claude, Gemini, Codex)

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| v1 | 2026-01-20 | Initial detailed implementation plan |
| v2 | 2026-01-20 | Incorporated 13 issues from initial reviews + 3 design clarifications from BlueKitty |
| v3 | 2026-01-20 | Incorporated 5 additional issues from v2 review (Codex #9-11, Gemini focus/architecture) |

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Pre-Implementation Review Summary](#pre-implementation-review-summary)
3. [Codebase Analysis Findings](#codebase-analysis-findings)
4. [Day-by-Day Implementation Plan](#day-by-day-implementation-plan)
5. [Implementation Details by Feature](#implementation-details-by-feature)
6. [Code Patterns & Reusability](#code-patterns--reusability)
7. [Edge Cases & Error Handling](#edge-cases--error-handling)
8. [Testing Strategy](#testing-strategy)
9. [Risk Mitigation](#risk-mitigation)

---

## Executive Summary

### What We're Building

**Three tightly-coupled features:**
1. **Comprehensive Edit Modal** - Expand from title-only to title + due date + notes + **inline tag picker** + parent selector
2. **Completed Task Metadata View** - Read-only modal showing full task details + actions (with position restore on uncomplete)
3. **Completed Parent Visual Indicator** - Dimmed box (NO strikethrough) for completed parents with incomplete **descendants** (any depth)

### Critical Dependencies RESOLVED

✅ **Task.notes field does NOT exist** - Will add in migration v8 (Day 1)
✅ **Task.position_before_completion does NOT exist** - Will add in migration v8 (Day 1) - NEW in v2
✅ **No existing date picker** - Will use Flutter's built-in `showDatePicker`
✅ **Tag picker exists** - `TagPickerDialog` from Phase 3.5 (will adapt to inline dropdown) - CHANGED in v2
✅ **Breadcrumb logic exists** - `TaskService.getParentChain()` from Phase 3.6B (reusable)
✅ **Navigate logic exists** - `TaskProvider.navigateToTask()` from Phase 3.6B (reusable)

### Key Changes in v2

| Area | v1 Approach | v2 Approach | Reason |
|------|-------------|-------------|--------|
| Tag Picker | Nested dialog (TagPickerDialog) | Inline dropdown with fuzzy search | Better UX, avoids dialog-in-dialog |
| Incomplete Children | Check immediate children only | Check ALL descendants recursively | User requirement for depth awareness |
| Depth Indicator | None | `>` immediate, `>>` grandchildren+ | Visual distinction for hierarchy depth |
| Position on Uncomplete | Undefined | Restore original position (shift siblings) | User requirement |
| Migration v8 | notes field only | notes + position_before_completion | Support position restore |
| Parent Selector Cancel | Returns null (= No Parent) | Returns sentinel value | Bug fix from Codex |
| _hasIncompleteChildren | O(N²) per-widget calculation | Cached in TaskProvider | Performance fix from Gemini |
| Edit Modal | Column without scroll | SingleChildScrollView wrapper | UX fix for small screens |
| updateTask | Calls loadTasks() | In-memory update like updateTaskTitle | Preserve tree state (Codex) |
| Fresh Install Schema | Missing notes column | Include notes + position_before_completion | Critical bug fix (Codex) |

### Timeline: 6-8 Days (expanded from 5-7)

| Day | Focus | Files Changed | Risk Level |
|-----|-------|---------------|------------|
| Day 1 | Migration v8 (notes + position_before_completion) | 4 files | LOW |
| Day 2 | Inline tag picker widget | 1-2 files | MEDIUM |
| Day 3 | Edit modal expansion | 1-2 files | MEDIUM |
| Day 4 | Parent selector with validation | 1-2 files | MEDIUM |
| Day 5 | Completed task metadata view | 1-2 files | LOW |
| Day 6 | Completed parent visual indicator (deep, cached) | 2-3 files | MEDIUM |
| Day 7-8 | Testing, edge cases, polish | All | LOW |

---

## Pre-Implementation Review Summary

### Issues Identified and Resolutions

**CRITICAL (2 issues):**

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 1 | Fresh-install schema missing `notes` column in `_createDB` | Codex | Add to CREATE TABLE statement |
| 2 | `firstWhere(..., orElse: () => null)` won't compile | Codex, Claude | Use Map lookup or collection extension |

**HIGH (2 issues):**

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 3 | Parent selector uses filtered list (breaks cycle detection) | Codex | Use full unfiltered task list |
| 4 | `TaskService.updateTask` missing validation & cycle checks | Codex | Add validation before db.update() |

**MEDIUM (9 issues):**

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 5 | Cancel parent selector = "No Parent" (ambiguous) | Codex | Use sentinel wrapper class |
| 6 | O(N²) performance in `_hasIncompleteChildren` | Gemini, Claude | Cache in TaskProvider |
| 7 | Async `setState` without mounted guard | Codex | Add `if (!mounted) return;` |
| 8 | `updateTask` calls `loadTasks()` (loses tree state) | Codex | Follow updateTaskTitle pattern |
| 9 | Completed-parent detection uses filtered list | Codex | Use full task list from provider |
| 10 | Modal height overflow on small screens | Gemini, Claude | Wrap in SingleChildScrollView |
| 11 | Date picker `cancelText: 'Clear'` misleading | Claude | Remove, use separate clear button |
| 12 | Delayed controller disposal | Gemini | Use mounted check pattern |
| 13 | Missing cycle prevention test | Gemini | Add to test strategy |

**Design Clarifications from BlueKitty:**

| # | Topic | Decision |
|---|-------|----------|
| A | Tag picker UX | Inline dropdown with fuzzy search (adds chips when selected) |
| B | Incomplete children depth | Check all descendants; use `>` immediate, `>>` grandchildren+ |
| C | Position on uncomplete | Restore original position, shift siblings; append if not possible |

---

### v3 Additional Issues (from v2 review)

**CRITICAL (1 issue):**

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 14 | `Color(tag.color)` won't compile - tag.color is hex `String?` | Codex | Use `TagColors.hexToColor()` + null default |

**HIGH (1 issue):**

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 15 | `_allTasks` source unspecified - filters could corrupt it | Codex | Clarify architecture: `_allTasks` immutable, `_tasks` is view |

**MEDIUM (1 issue):**

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 16 | Overlay can be inserted multiple times | Codex | Add `if (_overlayEntry != null) return;` guard |

**LOW (2 issues):**

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 17 | `Future.delayed` for focus handling unreliable | Gemini | Use `TapRegion` widget instead |
| 18 | Position restore logic belongs in TaskService | Gemini | Move to `TaskService.restoreTaskToPosition()` |

---

## Codebase Analysis Findings

### 1. Current Task Editing Mechanism

**Location:** `pin_and_paper/lib/widgets/task_item.dart:61-131`

**Current Implementation:** Simple AlertDialog with single TextField for title.

**Key Insights:**
- Uses inline `AlertDialog` (NOT separate widget file)
- 300ms delayed disposal to avoid rebuild crashes
- Updates via `TaskProvider.updateTaskTitle()`
- Shows success/error snackbars

**For Phase 3.6.5 (v2 changes):**
- ✅ Keep inline AlertDialog pattern initially
- ✅ Expand to multiple fields (title, due date, notes, tags, parent)
- ✅ Use `StatefulWidget` for complex state management
- ✅ **Wrap in SingleChildScrollView** (v2 fix)
- ✅ **Use mounted checks instead of delayed disposal** (v2 fix)

---

### 2. Tag Picker Implementation (Adapting for Inline Use)

**Location:** `pin_and_paper/lib/widgets/tag_picker_dialog.dart`

**Current Features:**
- StatefulWidget with search controller
- Multi-select with Set<String> for selected IDs
- Create new tag with color picker
- Returns `List<String>?` (null if cancelled)

**v2 Adaptation for Inline Dropdown:**
- Extract search + filtering logic
- Create lightweight `InlineTagPicker` widget
- Display as dropdown below search field
- Show selected tags as removable chips
- No separate dialog - embedded in edit modal

---

### 3. Date Picker (Does NOT Exist)

**Finding:** No existing date picker implementation.

**Solution:** Use Flutter's built-in `showDatePicker`

**v2 Fix:** Remove misleading `cancelText: 'Clear'` - use separate clear button instead.

```dart
Future<DateTime?> _selectDate(BuildContext context, DateTime? initialDate) async {
  return await showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    helpText: 'Select Due Date',
    // v2: Removed cancelText: 'Clear' - it doesn't clear, just cancels
  );
}
```

---

### 4. Database Migration Patterns

**Location:** `pin_and_paper/lib/services/database_service.dart`

**v2 Migration v8 - EXPANDED SCOPE:**

```dart
/// Phase 3.6.5 Migration: v7 → v8
///
/// Adds:
/// - notes field to tasks table (TEXT, nullable)
/// - position_before_completion field (INTEGER, nullable) - for uncomplete restore
///
/// This enables comprehensive task editing and position restoration on uncomplete.
Future<void> _migrateToV8(Database db) async {
  await db.transaction((txn) async {
    // ===========================================
    // 1. ADD NOTES COLUMN
    // ===========================================
    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN notes TEXT DEFAULT NULL
    ''');

    // ===========================================
    // 2. ADD POSITION_BEFORE_COMPLETION COLUMN
    // ===========================================
    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN position_before_completion INTEGER DEFAULT NULL
    ''');
  });

  debugPrint('✅ Database migrated to v8 successfully');
}
```

**v2 CRITICAL FIX - Update `_createDB` for Fresh Installs:**

```dart
// In _createDB method, update CREATE TABLE tasks statement:
CREATE TABLE ${AppConstants.tasksTable} (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  completed INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  completed_at INTEGER,
  parent_id TEXT,
  position INTEGER DEFAULT 0,
  depth INTEGER DEFAULT 0,
  is_template INTEGER DEFAULT 0,
  due_date INTEGER,
  is_all_day INTEGER DEFAULT 1,
  start_date INTEGER,
  notification_type TEXT DEFAULT 'use_global',
  notification_time INTEGER,
  deleted_at INTEGER DEFAULT NULL,
  notes TEXT DEFAULT NULL,                        -- Phase 3.6.5: NEW
  position_before_completion INTEGER DEFAULT NULL, -- Phase 3.6.5: NEW
  FOREIGN KEY (parent_id) REFERENCES ${AppConstants.tasksTable}(id) ON DELETE CASCADE
)
```

---

### 5. Parent Selector Requirements (v2 Rewrite)

**v2 Critical Fixes:**
1. Use FULL unfiltered task list (not `taskProvider.tasks` which may be filtered)
2. Use Map lookup instead of `firstWhere` with null orElse
3. Return sentinel value on cancel (not null)
4. Add validation in TaskService

**v2 Implementation:**

```dart
/// Sentinel class to distinguish cancel from "No Parent" selection
class ParentSelectorResult {
  final bool cancelled;
  final String? parentId; // null = "No Parent (Root Level)"

  const ParentSelectorResult.cancelled() : cancelled = true, parentId = null;
  const ParentSelectorResult.selected(this.parentId) : cancelled = false;
}

class ParentSelectorDialog extends StatefulWidget {
  final Task currentTask;
  final String? currentParentId;

  static Future<ParentSelectorResult> show({
    required BuildContext context,
    required Task currentTask,
    String? currentParentId,
  }) async {
    final result = await showDialog<ParentSelectorResult>(
      context: context,
      builder: (context) => ParentSelectorDialog(
        currentTask: currentTask,
        currentParentId: currentParentId,
      ),
    );
    // If dialog dismissed without selection, treat as cancelled
    return result ?? const ParentSelectorResult.cancelled();
  }

  @override
  State<ParentSelectorDialog> createState() => _ParentSelectorDialogState();
}

class _ParentSelectorDialogState extends State<ParentSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, Task> _taskMap = {};  // v2: Use Map for O(1) lookup
  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];
  Set<String> _descendantIds = {};  // v2: Pre-computed descendants

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_filterTasks);
  }

  Future<void> _loadTasks() async {
    final taskProvider = context.read<TaskProvider>();

    // v2 FIX: Get ALL tasks, not filtered list
    final allTasks = await taskProvider.getAllTasksUnfiltered();

    // Build map for O(1) lookup
    _taskMap = {for (final t in allTasks) t.id: t};

    // Pre-compute descendants to exclude
    _descendantIds = _computeDescendants(widget.currentTask.id);

    // Filter out: current task, descendants, soft-deleted
    final selectableTasks = allTasks.where((t) =>
      t.id != widget.currentTask.id &&
      !_descendantIds.contains(t.id) &&
      t.deletedAt == null
    ).toList();

    if (mounted) {
      setState(() {
        _allTasks = selectableTasks;
        _filteredTasks = selectableTasks;
      });
    }
  }

  /// v2: Compute all descendants using the task map
  Set<String> _computeDescendants(String taskId) {
    final descendants = <String>{};
    final queue = <String>[taskId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      // Find all children of currentId
      for (final task in _taskMap.values) {
        if (task.parentId == currentId && !descendants.contains(task.id)) {
          descendants.add(task.id);
          queue.add(task.id);
        }
      }
    }

    return descendants;
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
      title: const Text('Select Parent Task'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // Fixed height for scrollable list
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  // "No Parent" option - returns null parentId
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('No Parent (Root Level)'),
                    selected: widget.currentParentId == null,
                    onTap: () => Navigator.pop(
                      context,
                      const ParentSelectorResult.selected(null),
                    ),
                  ),
                  const Divider(),
                  // Filtered tasks
                  ..._filteredTasks.map((task) => ListTile(
                    leading: task.completed
                        ? const Icon(Icons.check_circle, color: Colors.grey)
                        : const Icon(Icons.circle_outlined),
                    title: Text(
                      task.title,
                      style: task.completed
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    selected: task.id == widget.currentParentId,
                    onTap: () => Navigator.pop(
                      context,
                      ParentSelectorResult.selected(task.id),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // v2 FIX: Return cancelled sentinel, not null
          onPressed: () => Navigator.pop(
            context,
            const ParentSelectorResult.cancelled(),
          ),
          child: const Text('Cancel'),
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

### 6. Breadcrumb Logic (Reusable - No Changes)

**Location:** `pin_and_paper/lib/services/task_service.dart:171-196`

No changes needed - existing implementation is solid.

---

### 7. Navigate to Task Logic (Reusable - No Changes)

**Location:** `pin_and_paper/lib/providers/task_provider.dart:1008-1059`

No changes needed - existing implementation is solid.

---

### 8. Completed Task Display Logic (v2 Major Rewrite)

**v2 Changes:**
1. Check ALL descendants, not just immediate children
2. Add depth indicator (`>` vs `>>`)
3. Cache results in TaskProvider for O(1) lookup
4. Use full task list, not filtered

**v2 TaskProvider Additions:**

```dart
/// Phase 3.6.5: Cached incomplete descendant info for completed parents
class IncompleteDescendantInfo {
  final int immediateCount;     // Direct children that are incomplete
  final int totalCount;         // All descendants that are incomplete
  final int maxDepth;           // 1 = immediate only, 2+ = has grandchildren+

  const IncompleteDescendantInfo({
    required this.immediateCount,
    required this.totalCount,
    required this.maxDepth,
  });

  bool get hasIncomplete => totalCount > 0;
  bool get hasDeepIncomplete => maxDepth > 1;

  /// Returns display string: "> 3 incomplete" or ">> 5 incomplete"
  String get displayText {
    final prefix = maxDepth > 1 ? '>>' : '>';
    final noun = totalCount == 1 ? 'incomplete' : 'incomplete';
    return '$prefix $totalCount $noun';
  }
}

// In TaskProvider class:
Map<String, IncompleteDescendantInfo> _incompleteDescendantCache = {};

/// Phase 3.6.5: Get incomplete descendant info for a completed task
/// Uses cached value for O(1) lookup
IncompleteDescendantInfo? getIncompleteDescendantInfo(String taskId) {
  return _incompleteDescendantCache[taskId];
}

/// Phase 3.6.5: Check if task is a completed parent with incomplete descendants
bool isCompletedParentWithIncomplete(String taskId) {
  return _incompleteDescendantCache[taskId]?.hasIncomplete ?? false;
}

/// Phase 3.6.5: Rebuild the incomplete descendant cache
/// Called after loadTasks() and after any task completion changes
void _rebuildIncompleteDescendantCache() {
  _incompleteDescendantCache.clear();

  // Build parent-to-children map for efficient traversal
  final childrenMap = <String, List<Task>>{};
  for (final task in _allTasks) {  // Use full unfiltered list
    if (task.parentId != null && task.deletedAt == null) {
      childrenMap.putIfAbsent(task.parentId!, () => []).add(task);
    }
  }

  // For each completed task, compute its incomplete descendants
  for (final task in _allTasks) {
    if (task.completed && task.deletedAt == null) {
      final info = _computeIncompleteDescendants(task.id, childrenMap, 1);
      if (info.hasIncomplete) {
        _incompleteDescendantCache[task.id] = info;
      }
    }
  }
}

/// Recursive helper to compute incomplete descendants
IncompleteDescendantInfo _computeIncompleteDescendants(
  String taskId,
  Map<String, List<Task>> childrenMap,
  int currentDepth,
) {
  final children = childrenMap[taskId] ?? [];

  int immediateCount = 0;
  int totalCount = 0;
  int maxDepth = 0;

  for (final child in children) {
    if (!child.completed) {
      immediateCount++;
      totalCount++;
      maxDepth = max(maxDepth, 1);
    }

    // Recurse into grandchildren regardless of child completion status
    final childInfo = _computeIncompleteDescendants(
      child.id,
      childrenMap,
      currentDepth + 1,
    );
    totalCount += childInfo.totalCount;
    if (childInfo.maxDepth > 0) {
      maxDepth = max(maxDepth, childInfo.maxDepth + 1);
    }
  }

  return IncompleteDescendantInfo(
    immediateCount: immediateCount,
    totalCount: totalCount,
    maxDepth: maxDepth,
  );
}
```

**v2 TaskItem Widget Changes:**

```dart
// In task_item.dart build method:

// v2: Use cached lookup instead of computing per-widget
final incompleteInfo = context.read<TaskProvider>()
    .getIncompleteDescendantInfo(task.id);
final isCompletedParent = task.completed && incompleteInfo != null;
final isTrulyComplete = task.completed && incompleteInfo == null;

// Title text decoration
title: Text(
  task.title,
  style: TextStyle(
    // v2: Only strikethrough if TRULY complete (no incomplete descendants)
    decoration: isTrulyComplete
        ? TextDecoration.lineThrough
        : TextDecoration.none,
    color: task.completed
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.onSurface,
  ),
),

// v2: Depth indicator badge
if (isCompletedParent)
  Padding(
    padding: const EdgeInsets.only(left: 60, right: 12, bottom: 8),
    child: Text(
      incompleteInfo!.displayText,  // "> 3 incomplete" or ">> 5 incomplete"
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    ),
  ),
```

---

## Day-by-Day Implementation Plan

### Day 1: Migration v8 (Expanded Scope)

**Goal:** Add notes AND position_before_completion fields

**Files to Modify:**
1. `pin_and_paper/lib/utils/constants.dart` - Update version to 8
2. `pin_and_paper/lib/services/database_service.dart` - Add migration + update _createDB
3. `pin_and_paper/lib/models/task.dart` - Add both fields

#### Step 1.1: Update Database Version

**File:** `pin_and_paper/lib/utils/constants.dart`

```dart
// OLD:
static const int databaseVersion = 7;

// NEW:
static const int databaseVersion = 8; // Phase 3.6.5: Edit Task Modal Rework
```

#### Step 1.2: Update _createDB (CRITICAL - v2 fix)

**File:** `pin_and_paper/lib/services/database_service.dart`

Add to CREATE TABLE statement:
```dart
notes TEXT DEFAULT NULL,
position_before_completion INTEGER DEFAULT NULL,
```

#### Step 1.3: Add Migration Method

**File:** `pin_and_paper/lib/services/database_service.dart`

```dart
Future<void> _migrateToV8(Database db) async {
  await db.transaction((txn) async {
    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN notes TEXT DEFAULT NULL
    ''');

    await txn.execute('''
      ALTER TABLE ${AppConstants.tasksTable}
      ADD COLUMN position_before_completion INTEGER DEFAULT NULL
    ''');
  });

  debugPrint('✅ Database migrated to v8 successfully');
}
```

#### Step 1.4: Call Migration in _upgradeDB

Add after v7 check:
```dart
if (oldVersion < 8) {
  await _migrateToV8(db);
}
```

#### Step 1.5: Update Task Model

**File:** `pin_and_paper/lib/models/task.dart`

Add fields:
```dart
final String? notes;
final int? positionBeforeCompletion;
```

Update constructor, toMap(), fromMap(), copyWith() accordingly.

#### Step 1.6: Test Migration

```bash
cd pin_and_paper
flutter clean && flutter pub get
flutter test
flutter run
```

Verify:
- ✅ Migration message in console
- ✅ Existing tasks load correctly
- ✅ Both columns exist in database

---

### Day 2: Inline Tag Picker Widget

**Goal:** Create lightweight inline tag picker with fuzzy search

**Files to Create:**
1. `pin_and_paper/lib/widgets/inline_tag_picker.dart`

#### Step 2.1: Create InlineTagPicker Widget

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';

/// Phase 3.6.5: Lightweight inline tag picker with fuzzy search
///
/// Displays as:
/// - Search TextField
/// - Dropdown with filtered results (multi-select)
/// - Selected tags as removable chips below
class InlineTagPicker extends StatefulWidget {
  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onChanged;

  const InlineTagPicker({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
  });

  @override
  State<InlineTagPicker> createState() => _InlineTagPickerState();
}

class _InlineTagPickerState extends State<InlineTagPicker> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  List<Tag> _allTags = [];
  List<Tag> _filteredTags = [];
  bool _showDropdown = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _searchController.addListener(_onSearchChanged);
    // v3 FIX: Removed _focusNode.addListener - using TapRegion instead (Gemini #17)
  }

  Future<void> _loadTags() async {
    final tagProvider = context.read<TagProvider>();
    await tagProvider.loadTags();

    if (mounted) {
      setState(() {
        _allTags = tagProvider.tags;
        _filteredTags = _allTags;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTags = query.isEmpty
          ? _allTags
          : _allTags.where((t) =>
              t.name.toLowerCase().contains(query)
            ).toList();
    });
    _updateOverlay();
  }

  // v3 FIX: Removed _onFocusChanged with Future.delayed - now using TapRegion
  // Focus changes are handled by TapRegion.onTapOutside in build()

  void _showOverlay() {
    // v3 FIX: Guard against multiple insertions (Codex #11)
    if (_overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showDropdown = true);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _showDropdown = false);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredTags.length,
                itemBuilder: (context, index) {
                  final tag = _filteredTags[index];
                  final isSelected = widget.selectedTagIds.contains(tag.id);

                  // v3 FIX: Use TagColors helper for hex string parsing (Codex #9)
                  final tagColor = tag.color != null
                      ? TagColors.hexToColor(tag.color!)
                      : TagColors.defaultColor;

                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: tagColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(tag.name),
                    trailing: isSelected
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onTap: () => _toggleTag(tag.id),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleTag(String tagId) {
    final newSelection = List<String>.from(widget.selectedTagIds);
    if (newSelection.contains(tagId)) {
      newSelection.remove(tagId);
    } else {
      newSelection.add(tagId);
    }
    widget.onChanged(newSelection);
    _updateOverlay();
  }

  void _removeTag(String tagId) {
    final newSelection = List<String>.from(widget.selectedTagIds);
    newSelection.remove(tagId);
    widget.onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTags = _allTags.where(
      (t) => widget.selectedTagIds.contains(t.id)
    ).toList();

    // v3 FIX: Use TapRegion instead of Future.delayed for focus handling (Gemini #17)
    return TapRegion(
      onTapOutside: (_) => _hideOverlay(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field with dropdown
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onTap: _showOverlay,  // v3: Show on tap instead of focus listener
              decoration: InputDecoration(
                labelText: 'Tags',
                hintText: 'Search tags...',
                prefixIcon: const Icon(Icons.label),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

        // Selected tags as chips
        if (selectedTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selectedTags.map((tag) {
              // v3 FIX: Use TagColors helper for hex string parsing (Codex #9)
              final tagColor = tag.color != null
                  ? TagColors.hexToColor(tag.color!)
                  : TagColors.defaultColor;

              return Chip(
                avatar: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tagColor,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag.id),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
        ],
      ),
    );  // v3: Close TapRegion
  }

  @override
  void dispose() {
    _hideOverlay();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
```

---

### Day 3: Edit Modal Expansion

**Goal:** Create comprehensive edit modal with all fields

**Files to Modify:**
1. `pin_and_paper/lib/widgets/task_item.dart` (expand `_handleEdit`)

#### Step 3.1: Create _EditTaskDialog Widget

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _dueDate = widget.task.dueDate;
    _parentId = widget.task.parentId;

    // Select all title text
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );

    _loadTags();
  }

  Future<void> _loadTags() async {
    final tagProvider = context.read<TagProvider>();
    final taskTags = await tagProvider.getTaskTags(widget.task.id);

    // v2 FIX: Check mounted before setState
    if (!mounted) return;

    setState(() {
      _selectedTagIds = taskTags.map((t) => t.id).toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Due Date',
    );

    if (date != null && mounted) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  void _clearDueDate() {
    setState(() {
      _dueDate = null;
    });
  }

  Future<void> _selectParent() async {
    final result = await ParentSelectorDialog.show(
      context: context,
      currentTask: widget.task,
      currentParentId: _parentId,
    );

    // v2 FIX: Check if cancelled vs actual selection
    if (!result.cancelled && mounted) {
      setState(() {
        _parentId = result.parentId;
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
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              // v2 FIX: Wrap in SingleChildScrollView for small screens
              child: SingleChildScrollView(
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== DUE DATE =====
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDueDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _dueDate == null
                                  ? 'No Due Date'
                                  : 'Due: ${DateFormat('MMM d, yyyy').format(_dueDate!)}',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                        if (_dueDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _clearDueDate,
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear date',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ===== INLINE TAG PICKER =====
                    InlineTagPicker(
                      selectedTagIds: _selectedTagIds,
                      onChanged: (ids) {
                        setState(() {
                          _selectedTagIds = ids;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // ===== NOTES =====
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                        hintText: 'Add notes or description...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
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
    // v2 FIX: Use safe lookup
    final parent = taskProvider.getTaskById(_parentId!);
    return parent?.title ?? '(Parent not found)';
  }
}
```

---

### Day 4: Parent Selector with Validation

**Goal:** Implement parent selector dialog and TaskService validation

Already covered in Section 5 above. Additionally:

#### Step 4.0: Clarify _allTasks Architecture (v3 FIX - Codex #10)

**CRITICAL:** The `TaskProvider` must maintain TWO separate lists:

```dart
// In TaskProvider class:

/// Master list - NEVER filtered, always contains all non-deleted tasks
/// Used for: cycle detection, completed-parent cache, parent selector
List<Task> _allTasks = [];

/// View list - may be filtered by tag, completion status, etc.
/// Used for: UI display in task list
List<Task> _tasks = [];

/// IMPORTANT: loadTasks() populates _allTasks
/// IMPORTANT: setFilter() creates _tasks as a filtered VIEW of _allTasks
/// IMPORTANT: _allTasks is NEVER modified by filter operations
```

**Architecture Rules:**
1. `loadTasks()` loads ALL tasks into `_allTasks`
2. `setFilter()` creates `_tasks` as a filtered subset of `_allTasks`
3. Cycle detection, parent selector, and completed-parent cache ALWAYS use `_allTasks`
4. UI display uses `_tasks` (the filtered view)
5. `_allTasks` is the single source of truth for task existence

#### Step 4.1: Add getAllTasksUnfiltered to TaskProvider

```dart
/// Phase 3.6.5: Get all tasks without filters applied
/// Used by parent selector for cycle detection
/// v3: Returns from _allTasks (the master list, never filtered)
Future<List<Task>> getAllTasksUnfiltered() async {
  return _allTasks.where((t) => t.deletedAt == null).toList();
}

/// Phase 3.6.5: Get task by ID (safe lookup)
Task? getTaskById(String id) {
  try {
    return _allTasks.firstWhere((t) => t.id == id);
  } catch (e) {
    return null;
  }
}
```

#### Step 4.2: Add Validation to TaskService.updateTask

```dart
/// Phase 3.6.5: Comprehensive task update with validation
Future<void> updateTask(
  String taskId, {
  required String title,
  DateTime? dueDate,
  String? notes,
  String? parentId,
}) async {
  final db = await _dbService.database;

  // v2 FIX: Validate parent exists and is not a descendant
  if (parentId != null) {
    // Check parent exists
    final parentResult = await db.query(
      AppConstants.tasksTable,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [parentId],
    );
    if (parentResult.isEmpty) {
      throw ArgumentError('Selected parent does not exist');
    }

    // Check for cycles - walk up from parentId
    String? currentId = parentId;
    final visited = <String>{};

    while (currentId != null) {
      if (currentId == taskId) {
        throw ArgumentError('Cannot create circular parent reference');
      }
      if (visited.contains(currentId)) break;
      visited.add(currentId);

      final result = await db.query(
        AppConstants.tasksTable,
        columns: ['parent_id'],
        where: 'id = ?',
        whereArgs: [currentId],
      );
      if (result.isEmpty) break;
      currentId = result.first['parent_id'] as String?;
    }
  }

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

#### Step 4.3: Update TaskProvider.updateTask (v2 - No Full Reload)

```dart
/// Phase 3.6.5: Comprehensive task update
/// v2 FIX: Uses in-memory update pattern, not loadTasks()
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
    // Get old parent for position handling
    final oldTask = _allTasks.firstWhere((t) => t.id == taskId);
    final oldParentId = oldTask.parentId;
    final parentChanged = oldParentId != parentId;

    // Determine new position if parent changed
    int newPosition = oldTask.position;
    if (parentChanged) {
      // Find max position among new siblings
      final siblings = _allTasks.where((t) =>
        t.parentId == parentId && t.id != taskId && t.deletedAt == null
      );
      newPosition = siblings.isEmpty
          ? 0
          : siblings.map((t) => t.position).reduce(max) + 1;
    }

    // Update task via service
    await _taskService.updateTask(
      taskId,
      title: title.trim(),
      dueDate: dueDate,
      notes: notes,
      parentId: parentId,
    );

    // If parent changed, update position in DB
    if (parentChanged) {
      await _taskService.updateTaskPosition(taskId, newPosition);
    }

    // Update tags
    final currentTags = await _tagProvider.getTaskTags(taskId);
    final currentTagIds = currentTags.map((t) => t.id).toSet();
    final newTagIds = tagIds.toSet();

    for (final tagId in newTagIds.difference(currentTagIds)) {
      await _tagProvider.addTagToTask(taskId, tagId);
    }
    for (final tagId in currentTagIds.difference(newTagIds)) {
      await _tagProvider.removeTagFromTask(taskId, tagId);
    }

    // v2 FIX: Update in-memory instead of full reload
    final updatedTask = oldTask.copyWith(
      title: title.trim(),
      dueDate: dueDate,
      notes: notes,
      parentId: parentId,
      position: newPosition,
      depth: parentId == null ? 0 : _calculateDepth(parentId),
    );

    final index = _allTasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      _allTasks[index] = updatedTask;
    }

    // Re-categorize and rebuild caches
    _categorizeTasks();
    _rebuildIncompleteDescendantCache();

    notifyListeners();
  } catch (e) {
    _errorMessage = 'Failed to update task: $e';
    debugPrint(_errorMessage);
    rethrow;
  }
}

int _calculateDepth(String parentId) {
  int depth = 1;
  String? currentParentId = parentId;
  while (currentParentId != null) {
    final parent = _allTasks.cast<Task?>().firstWhere(
      (t) => t?.id == currentParentId,
      orElse: () => null,
    );
    if (parent == null) break;
    currentParentId = parent.parentId;
    depth++;
  }
  return depth;
}
```

---

### Day 5: Completed Task Metadata View

**Goal:** Add read-only modal for completed tasks with position restore

**Files to Create:**
1. `pin_and_paper/lib/widgets/completed_task_metadata_dialog.dart`

Key changes from v1:
- Use mounted checks
- Implement position restore on uncomplete

#### Step 5.1: Uncomplete with Position Restore

```dart
Future<void> _uncompleteTask() async {
  try {
    final taskProvider = context.read<TaskProvider>();

    // v2: Restore position if available
    await taskProvider.uncompleteTaskWithPositionRestore(widget.task);

    if (mounted) {
      Navigator.pop(context);
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
```

#### Step 5.2: Add restoreTaskToPosition to TaskService (v3 FIX - Gemini #18)

**v3:** Move sibling shifting logic to TaskService for better separation of concerns.

```dart
// In TaskService:

/// Phase 3.6.5: Restore task to original position, shifting siblings as needed
/// v3: Moved from TaskProvider per Gemini recommendation
Future<void> restoreTaskToPosition(String taskId, int targetPosition, String? parentId) async {
  final db = await _dbService.database;

  await db.transaction((txn) async {
    // 1. Shift siblings at >= targetPosition up by 1 to make room
    await txn.execute('''
      UPDATE ${AppConstants.tasksTable}
      SET position = position + 1
      WHERE parent_id ${parentId == null ? 'IS NULL' : '= ?'}
        AND id != ?
        AND position >= ?
        AND deleted_at IS NULL
    ''', parentId == null ? [taskId, targetPosition] : [parentId, taskId, targetPosition]);

    // 2. Set task to target position
    await txn.execute('''
      UPDATE ${AppConstants.tasksTable}
      SET position = ?
      WHERE id = ?
    ''', [targetPosition, taskId]);

    // 3. Clear the stored position
    await txn.execute('''
      UPDATE ${AppConstants.tasksTable}
      SET position_before_completion = NULL
      WHERE id = ?
    ''', [taskId]);
  });
}
```

#### Step 5.2b: Add uncompleteTaskWithPositionRestore to TaskProvider

```dart
/// Phase 3.6.5: Uncomplete task and restore original position
/// v3: Delegates position logic to TaskService
Future<void> uncompleteTaskWithPositionRestore(Task task) async {
  final originalPosition = task.positionBeforeCompletion;

  // Mark as incomplete
  await _taskService.updateTaskCompletion(task.id, false);

  // Restore position if we have it (v3: delegate to service)
  if (originalPosition != null) {
    await _taskService.restoreTaskToPosition(
      task.id,
      originalPosition,
      task.parentId,
    );
  }

  await loadTasks();
}
```

#### Step 5.3: Save Position on Complete

In `toggleTaskCompletion` method, before marking complete:

```dart
// Phase 3.6.5: Save position before completing
if (!task.completed) {
  await _taskService.savePositionBeforeCompletion(task.id, task.position);
}
```

---

### Day 6: Completed Parent Visual Indicator

**Goal:** Implement deep detection with caching and depth indicator

Already covered in Section 8 above. Key implementation points:

1. Add `_incompleteDescendantCache` to TaskProvider
2. Add `_rebuildIncompleteDescendantCache()` method
3. Call rebuild after `loadTasks()` and `toggleTaskCompletion()`
4. Update TaskItem to use cached lookup
5. Display depth indicator (`>` vs `>>`)

---

### Days 7-8: Testing, Edge Cases, Polish

See updated Testing Strategy section below.

---

## Code Patterns & Reusability

### Pattern 1: Sentinel Result Class (NEW in v2)

**Used in:** ParentSelectorDialog

```dart
class ParentSelectorResult {
  final bool cancelled;
  final String? parentId;

  const ParentSelectorResult.cancelled() : cancelled = true, parentId = null;
  const ParentSelectorResult.selected(this.parentId) : cancelled = false;
}
```

**Benefits:**
- Distinguishes cancel from "No Parent" selection
- Type-safe, self-documenting
- Prevents null ambiguity bugs

### Pattern 2: Mounted Guard (v2 Standard)

**Used in:** All async setState operations

```dart
Future<void> _loadData() async {
  final data = await someAsyncOperation();

  // v2: Always check mounted before setState
  if (!mounted) return;

  setState(() {
    _data = data;
  });
}
```

### Pattern 3: Map Lookup Instead of firstWhere (v2 Fix)

**Used in:** ParentSelectorDialog, TaskProvider

```dart
// OLD (won't compile with null):
final item = list.firstWhere((x) => x.id == id, orElse: () => null);

// v2 FIX - Option A: Build map
final map = {for (final x in list) x.id: x};
final item = map[id];

// v2 FIX - Option B: Use where + firstOrNull
final item = list.where((x) => x.id == id).firstOrNull;
```

### Pattern 4: In-Memory Update (v2 Standard)

**Used in:** TaskProvider.updateTask

```dart
// v2: Update local state instead of reloading
final index = _allTasks.indexWhere((t) => t.id == taskId);
if (index >= 0) {
  _allTasks[index] = updatedTask;
}
_categorizeTasks();
notifyListeners();
```

### Pattern 5: Cached Computation (v2 Performance)

**Used in:** Incomplete descendant detection

```dart
// Compute once, lookup O(1)
Map<String, ComputedInfo> _cache = {};

void _rebuildCache() {
  _cache.clear();
  // ... compute all values
}

ComputedInfo? getCachedInfo(String id) => _cache[id];
```

---

## Edge Cases & Error Handling

### Edge Case 1: Position Restore Conflict

**Scenario:** Original position is occupied when uncompleting.

**Handling:** Shift siblings to make room.

```dart
if (originalPosition != null) {
  // Shift siblings at >= originalPosition up by 1
  for (final sibling in siblingsAtOrAfter) {
    await _taskService.updateTaskPosition(sibling.id, sibling.position + 1);
  }
  await _taskService.updateTaskPosition(task.id, originalPosition);
}
```

### Edge Case 2: Deep Nesting Performance

**Scenario:** Task nested 20 levels deep with many siblings.

**Handling:** Cache is rebuilt once after loadTasks, not per-widget.

### Edge Case 3: Parent Selector Cycle Prevention

**Scenario:** User tries to parent task to its own grandchild.

**Handling:** Pre-compute all descendants, exclude from list.

**Test Case (v2 addition from Gemini):**
1. Create: Root → Child → Grandchild
2. Edit Root, open parent selector
3. Verify Child and Grandchild NOT in list

### Edge Case 4: Canceling with Overlay Open

**Scenario:** User closes edit modal while tag dropdown is open.

**Handling:** InlineTagPicker.dispose() removes overlay entry.

---

## Testing Strategy

### Unit Tests

**New Tests (v2):**

1. **Cycle Prevention Test (from Gemini):**
```dart
test('Parent selector excludes descendants', () {
  // Create hierarchy
  // Open selector for root
  // Verify children/grandchildren excluded
});
```

2. **Position Restore Test:**
```dart
test('Uncomplete restores original position', () {
  // Create tasks at positions 0, 1, 2
  // Complete task at position 1
  // Verify position_before_completion = 1
  // Uncomplete
  // Verify task back at position 1
  // Verify siblings shifted correctly
});
```

3. **Deep Incomplete Detection Test:**
```dart
test('Completed parent detects incomplete grandchildren', () {
  // Create: Parent (complete) → Child (complete) → Grandchild (incomplete)
  // Verify parent shows as completed parent with incomplete
  // Verify maxDepth = 2
  // Verify displayText = ">> 1 incomplete"
});
```

### Integration Tests

1. Edit modal saves all fields correctly
2. Parent change updates hierarchy
3. Tag changes persist
4. Uncomplete restores position

### Manual Test Additions (v2)

**Cycle Prevention:**
- [ ] Create 3-level hierarchy
- [ ] Edit root, try to select grandchild as parent
- [ ] Verify grandchild NOT in list

**Deep Detection:**
- [ ] Create: Parent → Child → Grandchild
- [ ] Complete Parent and Child
- [ ] Verify Parent shows ">> 1 incomplete"
- [ ] Complete Grandchild
- [ ] Verify Parent shows strikethrough (fully complete)

**Position Restore:**
- [ ] Create 3 siblings (A=0, B=1, C=2)
- [ ] Complete B
- [ ] Verify B's position_before_completion = 1
- [ ] Uncomplete B
- [ ] Verify order is A, B, C again

---

## Risk Mitigation

### Updated Risk Assessment (v3)

| Risk | Impact | Likelihood | Mitigation | Status |
|------|--------|------------|------------|--------|
| Migration failure | HIGH | LOW | Transaction wrap, test on copy | ✅ Addressed |
| firstWhere compile error | HIGH | HIGH | Use Map lookup pattern | ✅ Fixed in v2 |
| Cancel = No Parent bug | MEDIUM | HIGH | Sentinel result class | ✅ Fixed in v2 |
| O(N²) performance | MEDIUM | MEDIUM | Cache in TaskProvider | ✅ Fixed in v2 |
| Modal overflow | MEDIUM | HIGH | SingleChildScrollView | ✅ Fixed in v2 |
| Tree state lost on update | MEDIUM | HIGH | In-memory update pattern | ✅ Fixed in v2 |
| Cycle creation | HIGH | LOW | Pre-compute + validate | ✅ Addressed |
| Async setState after dispose | LOW | MEDIUM | Mounted guards | ✅ Fixed in v2 |
| Tag color compile error | HIGH | HIGH | TagColors.hexToColor helper | ✅ Fixed in v3 |
| Filtered list corruption | MEDIUM | MEDIUM | _allTasks architecture | ✅ Fixed in v3 |
| Overlay double insert | LOW | MEDIUM | Guard in _showOverlay | ✅ Fixed in v3 |
| Focus handling unreliable | LOW | MEDIUM | TapRegion widget | ✅ Fixed in v3 |

---

## Success Criteria

### Phase 3.6.5 Complete When:

**Database:**
- ✅ Migration v8 adds notes AND position_before_completion
- ✅ Fresh install schema includes both columns
- ✅ All existing data intact

**Edit Modal:**
- ✅ Opens with SingleChildScrollView (no overflow)
- ✅ **Inline tag picker** with fuzzy search and chips
- ✅ Parent selector with sentinel cancel handling
- ✅ All fields save correctly (in-memory update)
- ✅ Mounted guards on all async setState

**Metadata View:**
- ✅ Uncomplete restores original position
- ✅ All mounted guards in place

**Completed Parent Indicator:**
- ✅ Checks ALL descendants (not just immediate)
- ✅ Depth indicator: `>` immediate, `>>` grandchildren+
- ✅ Cached in TaskProvider (O(1) lookup)
- ✅ Uses full task list (not filtered)

**No Regressions:**
- ✅ All Phase 3.6B features work
- ✅ Tree state preserved on task updates
- ✅ Filters work correctly

**Code Quality:**
- ✅ All firstWhere patterns use safe lookup
- ✅ All async setState has mounted guards
- ✅ Cycle prevention tested
- ✅ Tag colors use TagColors.hexToColor helper (v3)
- ✅ _allTasks architecture properly documented (v3)
- ✅ Overlay guards prevent double insertion (v3)
- ✅ TapRegion used instead of Future.delayed (v3)
- ✅ Position restore logic in TaskService (v3)

---

**END OF IMPLEMENTATION PLAN v3**

---

**Changes Summary:**

**v2 (from initial reviews):**
- 13 issues from pre-implementation review addressed
- 3 design clarifications from BlueKitty incorporated
- Timeline extended to 6-8 days
- All code snippets updated with fixes
- New testing requirements added

**v3 (from v2 review):**
- Fixed `Color(tag.color)` compile error → use `TagColors.hexToColor()`
- Clarified `_allTasks` vs `_tasks` architecture
- Added overlay insertion guard
- Replaced `Future.delayed` focus handling with `TapRegion`
- Moved position restore logic to `TaskService.restoreTaskToPosition()`

**Total Issues Addressed:** 18 (13 in v2 + 5 in v3)

**Approved by:** Gemini ✅, Codex ✅ (with v3 fixes)

**Ready for Implementation**
