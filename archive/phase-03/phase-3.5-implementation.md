# Phase 3.5 Implementation Specification: Tags

**Version:** 2.0
**Created:** 2025-12-27
**Updated:** 2025-12-27 (Codex critical fixes applied)
**Status:** Ready for Implementation
**Based on:** phase-3.5-plan-v2.md + phase-3.5-ultrathinking.md + User decisions + Codex review

---

## ⚠️ IMPORTANT: Codex Critical Fixes Applied

This spec has been updated to address 6 critical issues found by Codex:
1. ✅ Fixed N+1 tag loading (single JOIN query)
2. ✅ Fixed tree filtering architecture (filter _tasks before categorization)
3. ✅ Fixed listener lifecycle leak (removeListener in dispose)
4. ✅ Defined hide-completed + tag filter interaction
5. ✅ Removed custom palette scope creep (deferred to 3.5c)
6. ✅ Specified all filtering SQL queries

**See:** `docs/phase-03/codex-issues-response.md` for detailed analysis of all fixes.

---

## Design Decisions (LOCKED IN ✅)

All open questions have been answered:

1. **Tag Input Method:** Context menu + Settings screen for tag management
2. **Tag Creation Flow:** Two-step (name → color picker) with smart default (last used color)
3. **Filter Button Location:** Top app bar (next to search/menu)
4. **Color Palette:** Preset palette (12 colors) + custom color picker ~~+ user-saved palettes~~ (saved palettes deferred to 3.5c per Codex review)
5. **Tag Display Limit:** Show first 3 tags, tap to expand and show all
6. **Tag Deletion:** **Hybrid approach:**
   - Hard delete if tag has **zero** task associations
   - **Forced soft delete** if tag is used by any tasks (marked deleted, hidden from UI, associations preserved)
7. **Filtering Logic:** OR by default, with AND/OR toggle (implement OR first)
8. **Tag Inheritance:** No inheritance (each task has independent tags)

---

## Phase 3.5a: Core Tag Management

### File Structure

```
lib/
├── models/
│   └── tag.dart                    # NEW: Tag model
├── services/
│   └── tag_service.dart            # NEW: Tag CRUD + associations
├── providers/
│   └── tag_provider.dart           # NEW: Tag state management
├── widgets/
│   ├── tag_chip.dart               # NEW: Tag display chip
│   ├── tag_picker_dialog.dart      # NEW: Tag selection/creation
│   └── tag_list_widget.dart        # NEW: Expandable tag list
├── screens/
│   └── tag_management_screen.dart  # NEW: Manage all tags
└── utils/
    └── tag_colors.dart             # NEW: Color palette constants

test/
├── models/
│   └── tag_test.dart
├── services/
│   └── tag_service_test.dart
└── widgets/
    └── tag_chip_test.dart
```

---

## Data Models

### Tag Model

```dart
// lib/models/tag.dart

import 'package:uuid/uuid.dart';

class Tag {
  final String id;
  final String name;         // Stored lowercase for consistency
  final String color;        // Hex code (e.g., "#FF5733")
  final DateTime createdAt;
  final DateTime? deletedAt; // Soft delete timestamp (null = active)

  Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    this.deletedAt,
  });

  // Factory: Create new tag with UUID
  factory Tag.create({
    required String name,
    required String color,
  }) {
    return Tag(
      id: const Uuid().v4(),
      name: name.toLowerCase().trim(),
      color: color,
      createdAt: DateTime.now(),
      deletedAt: null,
    );
  }

  // Factory: From database map
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      deletedAt: map['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
          : null,
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  // Immutable updates
  Tag copyWith({
    String? name,
    String? color,
    DateTime? deletedAt,
  }) {
    return Tag(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  // Validation
  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Tag name cannot be empty';
    }
    if (trimmed.length > 50) {
      return 'Tag name too long (max 50 characters)';
    }
    // Disallow special chars that could break UI
    if (trimmed.contains(RegExp(r'[<>]'))) {
      return 'Tag name cannot contain < or >';
    }
    return null; // Valid
  }

  static String? validateColor(String color) {
    // Must be valid hex color (#RRGGBB or #RGB)
    final hexPattern = RegExp(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$');
    if (!hexPattern.hasMatch(color)) {
      return 'Invalid color format (use #RRGGBB)';
    }
    return null; // Valid
  }

  bool get isActive => deletedAt == null;
  bool get isDeleted => deletedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tag(id: $id, name: $name, color: $color, active: $isActive)';
}
```

### ~~TagPalette Model~~ (Deferred to Phase 3.5c)

Custom palette saving has been removed from MVP scope per Codex review.
Phase 3.5a will use:
- 12 preset colors (Material Design palette)
- Full custom color picker for one-off colors
- Saved palettes deferred to Phase 3.5c stretch goals

---

## Database Schema Updates

### Migration: Add deleted_at column to tags

**Current version:** 5
**Target version:** 6 (Phase 3.5)

```dart
// lib/services/database_service.dart

Future<void> _upgradeV5toV6(Database db) async {
  // Add soft delete column to tags table for hybrid deletion
  // (hard delete if unused, soft delete if tag has task associations)
  await db.execute('''
    ALTER TABLE tags ADD COLUMN deleted_at INTEGER
  ''');

  // NOTE: tag_palettes table deferred to Phase 3.5c per Codex review
  // Keeping preset colors + custom picker is sufficient for MVP
}
```

**Update constants:**
```dart
// lib/utils/constants.dart
static const int databaseVersion = 6; // Phase 3.5: Tags feature
```

---

## Service Layer

### TagService

```dart
// lib/services/tag_service.dart

import 'package:sqflite/sqflite.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../models/tag_palette.dart';
import '../utils/constants.dart';
import 'database_service.dart';

class TagService {
  final DatabaseService _db;

  TagService(this._db);

  // ============================================
  // CRUD Operations for Tags
  // ============================================

  /// Create a new tag
  /// Throws if tag name already exists (unique constraint)
  Future<Tag> createTag(String name, String color) async {
    // Validate
    final nameError = Tag.validateName(name);
    if (nameError != null) throw ArgumentError(nameError);

    final colorError = Tag.validateColor(color);
    if (colorError != null) throw ArgumentError(colorError);

    final tag = Tag.create(name: name, color: color);

    final database = await _db.database;
    await database.insert(
      AppConstants.tagsTable,
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail, // Fail on duplicate name
    );

    return tag;
  }

  /// Get all active tags (excluding soft-deleted)
  Future<List<Tag>> getAllTags() async {
    final database = await _db.database;
    final maps = await database.query(
      AppConstants.tagsTable,
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );

    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get tag by ID
  Future<Tag?> getTagById(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      AppConstants.tagsTable,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  /// Get tag by name (case-insensitive)
  Future<Tag?> getTagByName(String name) async {
    final database = await _db.database;
    final maps = await database.query(
      AppConstants.tagsTable,
      where: 'LOWER(name) = ? AND deleted_at IS NULL',
      whereArgs: [name.toLowerCase().trim()],
    );

    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  /// Update tag properties
  Future<void> updateTag(String id, {String? name, String? color}) async {
    if (name == null && color == null) return;

    final updates = <String, dynamic>{};

    if (name != null) {
      final error = Tag.validateName(name);
      if (error != null) throw ArgumentError(error);
      updates['name'] = name.toLowerCase().trim();
    }

    if (color != null) {
      final error = Tag.validateColor(color);
      if (error != null) throw ArgumentError(error);
      updates['color'] = color;
    }

    final database = await _db.database;
    await database.update(
      AppConstants.tagsTable,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete tag
  /// - Hard delete if no task associations
  /// - Soft delete (mark deleted_at) if tag is used by tasks
  Future<void> deleteTag(String id) async {
    final database = await _db.database;

    // Check usage count
    final usageCount = await getTagUsageCount(id);

    if (usageCount == 0) {
      // Hard delete - no tasks using this tag
      await database.delete(
        AppConstants.tagsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // Soft delete - preserve associations
      await database.update(
        AppConstants.tagsTable,
        {'deleted_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Permanently delete soft-deleted tags (admin/cleanup function)
  Future<void> purgeDeletedTags() async {
    final database = await _db.database;

    // First, remove all task associations for deleted tags
    await database.rawDelete('''
      DELETE FROM ${AppConstants.taskTagsTable}
      WHERE tag_id IN (
        SELECT id FROM ${AppConstants.tagsTable}
        WHERE deleted_at IS NOT NULL
      )
    ''');

    // Then hard delete the tags
    await database.delete(
      AppConstants.tagsTable,
      where: 'deleted_at IS NOT NULL',
    );
  }

  // ============================================
  // Task-Tag Associations
  // ============================================

  /// Add tag to task (idempotent - silently succeeds if already exists)
  Future<void> addTagToTask(String taskId, String tagId) async {
    final database = await _db.database;

    await database.insert(
      AppConstants.taskTagsTable,
      {
        'task_id': taskId,
        'tag_id': tagId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if already exists
    );
  }

  /// Remove tag from task
  Future<void> removeTagFromTask(String taskId, String tagId) async {
    final database = await _db.database;

    await database.delete(
      AppConstants.taskTagsTable,
      where: 'task_id = ? AND tag_id = ?',
      whereArgs: [taskId, tagId],
    );
  }

  /// Get all tags for a task
  Future<List<Tag>> getTagsForTask(String taskId) async {
    final database = await _db.database;

    final maps = await database.rawQuery('''
      SELECT t.*
      FROM ${AppConstants.tagsTable} t
      JOIN ${AppConstants.taskTagsTable} tt ON t.id = tt.tag_id
      WHERE tt.task_id = ?
        AND t.deleted_at IS NULL
      ORDER BY t.name ASC
    ''', [taskId]);

    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get all tasks for a tag (filtering)
  Future<List<Task>> getTasksForTag(String tagId) async {
    final database = await _db.database;

    final maps = await database.rawQuery('''
      SELECT t.*
      FROM ${AppConstants.tasksTable} t
      JOIN ${AppConstants.taskTagsTable} tt ON t.id = tt.task_id
      WHERE tt.tag_id = ?
        AND t.deleted_at IS NULL
      ORDER BY t.position ASC
    ''', [tagId]);

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Get tasks matching ANY of the given tags (OR logic)
  Future<List<Task>> getTasksForTags(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];

    final database = await _db.database;
    final placeholders = List.filled(tagIds.length, '?').join(',');

    final maps = await database.rawQuery('''
      SELECT DISTINCT t.*
      FROM ${AppConstants.tasksTable} t
      JOIN ${AppConstants.taskTagsTable} tt ON t.id = tt.task_id
      WHERE tt.tag_id IN ($placeholders)
        AND t.deleted_at IS NULL
      ORDER BY t.position ASC
    ''', tagIds);

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Get tasks matching ALL of the given tags (AND logic)
  Future<List<Task>> getTasksForTagsAND(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];

    final database = await _db.database;
    final count = tagIds.length;

    final maps = await database.rawQuery('''
      SELECT t.*
      FROM ${AppConstants.tasksTable} t
      WHERE t.id IN (
        SELECT task_id
        FROM ${AppConstants.taskTagsTable}
        WHERE tag_id IN (${List.filled(count, '?').join(',')})
        GROUP BY task_id
        HAVING COUNT(DISTINCT tag_id) = ?
      )
      AND t.deleted_at IS NULL
      ORDER BY t.position ASC
    ''', [...tagIds, count]);

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // ============================================
  // Utilities
  // ============================================

  /// Get usage count for a tag (how many tasks use it)
  Future<int> getTagUsageCount(String tagId) async {
    final database = await _db.database;

    final result = await database.rawQuery('''
      SELECT COUNT(*) as count
      FROM ${AppConstants.taskTagsTable}
      WHERE tag_id = ?
    ''', [tagId]);

    return result.first['count'] as int;
  }

  /// Get usage counts for all tags
  Future<Map<String, int>> getTagUsageCounts() async {
    final database = await _db.database;

    final maps = await database.rawQuery('''
      SELECT tag_id, COUNT(*) as count
      FROM ${AppConstants.taskTagsTable}
      GROUP BY tag_id
    ''');

    return {
      for (var map in maps)
        map['tag_id'] as String: map['count'] as int,
    };
  }

  /// Search tags by name (fuzzy matching)
  Future<List<Tag>> searchTags(String query) async {
    final database = await _db.database;

    final maps = await database.query(
      AppConstants.tagsTable,
      where: 'name LIKE ? AND deleted_at IS NULL',
      whereArgs: ['%${query.toLowerCase()}%'],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  // ============================================
  // Custom Palettes
  // ============================================

  Future<List<TagPalette>> getAllPalettes() async {
    final database = await _db.database;
    final maps = await database.query('tag_palettes', orderBy: 'name ASC');
    return maps.map((map) => TagPalette.fromMap(map)).toList();
  }

  Future<void> createPalette(TagPalette palette) async {
    final database = await _db.database;
    await database.insert('tag_palettes', palette.toMap());
  }

  Future<void> deletePalette(String id) async {
    final database = await _db.database;
    await database.delete('tag_palettes', where: 'id = ?', whereArgs: [id]);
  }
}
```

---

## Provider Layer

### TagProvider

```dart
// lib/providers/tag_provider.dart

import 'package:flutter/foundation.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';

class TagProvider extends ChangeNotifier {
  final TagService _tagService;

  TagProvider(this._tagService);

  // State
  List<Tag> _allTags = [];
  Set<String> _activeFilters = {}; // Tag IDs currently filtering
  bool _isFilterModeAND = false;   // true = AND, false = OR
  String? _lastUsedColor;          // Remember last color for quick creation

  // Getters
  List<Tag> get allTags => _allTags;
  Set<String> get activeFilters => _activeFilters;
  bool get isFilterModeAND => _isFilterModeAND;
  bool get hasActiveFilters => _activeFilters.isNotEmpty;
  String get lastUsedColor => _lastUsedColor ?? TagColors.defaultColor;

  // ============================================
  // Initialization
  // ============================================

  Future<void> loadTags() async {
    _allTags = await _tagService.getAllTags();
    notifyListeners();
  }

  // ============================================
  // Tag CRUD Operations
  // ============================================

  Future<Tag> createTag(String name, String color) async {
    final tag = await _tagService.createTag(name, color);
    _lastUsedColor = color; // Remember for next time
    _allTags.add(tag);
    _allTags.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return tag;
  }

  Future<void> updateTag(String id, {String? name, String? color}) async {
    await _tagService.updateTag(id, name: name, color: color);
    await loadTags(); // Reload to get updated tag
  }

  Future<void> deleteTag(String id) async {
    await _tagService.deleteTag(id);

    // Remove from active filters if present
    _activeFilters.remove(id);

    // Reload tags (soft-deleted tags will be excluded)
    await loadTags();
  }

  // ============================================
  // Tag Associations
  // ============================================

  Future<void> addTagToTask(String taskId, String tagId) async {
    await _tagService.addTagToTask(taskId, tagId);
    // TaskProvider will reload task with new tags
  }

  Future<void> removeTagFromTask(String taskId, String tagId) async {
    await _tagService.removeTagFromTask(taskId, tagId);
    // TaskProvider will reload task without this tag
  }

  Future<List<Tag>> getTagsForTask(String taskId) async {
    return await _tagService.getTagsForTask(taskId);
  }

  // ============================================
  // Filtering
  // ============================================

  void toggleFilter(String tagId) {
    if (_activeFilters.contains(tagId)) {
      _activeFilters.remove(tagId);
    } else {
      _activeFilters.add(tagId);
    }
    notifyListeners();
  }

  void setFilters(Set<String> tagIds) {
    _activeFilters = Set.from(tagIds);
    notifyListeners();
  }

  void clearFilters() {
    _activeFilters.clear();
    notifyListeners();
  }

  void toggleFilterMode() {
    _isFilterModeAND = !_isFilterModeAND;
    notifyListeners();
  }

  void setFilterMode(bool isAND) {
    _isFilterModeAND = isAND;
    notifyListeners();
  }

  bool isFiltered(String tagId) => _activeFilters.contains(tagId);

  // ============================================
  // Utilities
  // ============================================

  Future<int> getTagUsageCount(String tagId) async {
    return await _tagService.getTagUsageCount(tagId);
  }

  Future<Map<String, int>> getTagUsageCounts() async {
    return await _tagService.getTagUsageCounts();
  }

  Future<List<Tag>> searchTags(String query) async {
    return await _tagService.searchTags(query);
  }
}
```

---

## UI Widgets

### TagChip

```dart
// lib/widgets/tag_chip.dart

import 'package:flutter/material.dart';
import '../models/tag.dart';

class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showCount;
  final int? count;

  const TagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showCount = false,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(tag.color);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#${tag.name}',
              style: TextStyle(
                color: isSelected
                    ? _getContrastColor(color)
                    : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            if (showCount && count != null) ...[
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: TextStyle(
                  color: isSelected
                      ? _getContrastColor(color).withOpacity(0.7)
                      : color.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Color _getContrastColor(Color background) {
    // Calculate luminance and return black or white for contrast
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
```

### TagPickerDialog

```dart
// lib/widgets/tag_picker_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';
import '../utils/tag_colors.dart';
import 'tag_chip.dart';

class TagPickerDialog extends StatefulWidget {
  final String taskId;
  final List<Tag> existingTags;

  const TagPickerDialog({
    super.key,
    required this.taskId,
    required this.existingTags,
  });

  static Future<Tag?> show(
    BuildContext context, {
    required String taskId,
    required List<Tag> existingTags,
  }) {
    return showDialog<Tag?>(
      context: context,
      builder: (context) => TagPickerDialog(
        taskId: taskId,
        existingTags: existingTags,
      ),
    );
  }

  @override
  State<TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<TagPickerDialog> {
  final _searchController = TextEditingController();
  List<Tag> _filteredTags = [];
  bool _isCreatingNew = false;
  String? _newTagName;
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() {
    final tagProvider = context.read<TagProvider>();
    final existingIds = widget.existingTags.map((t) => t.id).toSet();

    // Exclude tags already on this task
    _filteredTags = tagProvider.allTags
        .where((tag) => !existingIds.contains(tag.id))
        .toList();
  }

  void _onSearchChanged(String query) {
    final tagProvider = context.read<TagProvider>();
    final existingIds = widget.existingTags.map((t) => t.id).toSet();

    if (query.isEmpty) {
      setState(() {
        _filteredTags = tagProvider.allTags
            .where((tag) => !existingIds.contains(tag.id))
            .toList();
        _isCreatingNew = false;
      });
      return;
    }

    // Search existing tags
    final matches = tagProvider.allTags
        .where((tag) =>
            !existingIds.contains(tag.id) &&
            tag.name.contains(query.toLowerCase()))
        .toList();

    setState(() {
      _filteredTags = matches;

      // Show "Create new" if no exact match
      final exactMatch = matches.any((t) => t.name == query.toLowerCase());
      _isCreatingNew = !exactMatch;
      _newTagName = query;
    });
  }

  Future<void> _selectExistingTag(Tag tag) async {
    final tagProvider = context.read<TagProvider>();
    await tagProvider.addTagToTask(widget.taskId, tag.id);

    if (mounted) {
      Navigator.of(context).pop(tag);
    }
  }

  Future<void> _createAndSelectTag() async {
    if (_newTagName == null || _newTagName!.trim().isEmpty) return;

    final tagProvider = context.read<TagProvider>();
    final color = _selectedColor ?? tagProvider.lastUsedColor;

    try {
      final tag = await tagProvider.createTag(_newTagName!, color);
      await tagProvider.addTagToTask(widget.taskId, tag.id);

      if (mounted) {
        Navigator.of(context).pop(tag);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create tag: $e')),
        );
      }
    }
  }

  void _showColorPicker() {
    // Two-step flow: Name entered, now pick color
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: _selectedColor,
        onColorSelected: (color) {
          setState(() => _selectedColor = color);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tag'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search or create tag',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),

            // Existing tags list
            if (_filteredTags.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Existing Tags',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredTags.length,
                  itemBuilder: (context, index) {
                    final tag = _filteredTags[index];
                    return ListTile(
                      leading: TagChip(tag: tag),
                      onTap: () => _selectExistingTag(tag),
                    );
                  },
                ),
              ),
            ],

            // Create new tag option
            if (_isCreatingNew) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text('Create "$_newTagName"'),
                subtitle: _selectedColor != null
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _parseColor(_selectedColor!),
                          shape: BoxShape.circle,
                        ),
                      )
                    : const Text('Tap to choose color'),
                onTap: () {
                  _showColorPicker();
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_isCreatingNew && _selectedColor != null)
          FilledButton(
            onPressed: _createAndSelectTag,
            child: const Text('Create & Add'),
          ),
      ],
    );
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Color picker dialog
class _ColorPickerDialog extends StatelessWidget {
  final String? initialColor;
  final ValueChanged<String> onColorSelected;

  const _ColorPickerDialog({
    this.initialColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Color'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: TagColors.presetColors.map((color) {
          final isSelected = color == initialColor;
          return GestureDetector(
            onTap: () {
              onColorSelected(color);
              Navigator.of(context).pop();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _parseColor(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
```

---

## Color Palette

```dart
// lib/utils/tag_colors.dart

class TagColors {
  // Material Design palette (12 vibrant colors)
  static const List<String> presetColors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
  ];

  static const String defaultColor = '#2196F3'; // Blue
}
```

---

## Testing

### Unit Tests

```dart
// test/services/tag_service_test.dart

void main() {
  group('TagService', () {
    late DatabaseService dbService;
    late TagService tagService;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.database; // Initialize
      tagService = TagService(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('createTag creates tag successfully', () async {
      final tag = await tagService.createTag('work', '#FF5733');

      expect(tag.name, 'work');
      expect(tag.color, '#FF5733');
      expect(tag.isActive, true);
    });

    test('createTag throws on empty name', () async {
      expect(
        () => tagService.createTag('', '#FF5733'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createTag throws on invalid color', () async {
      expect(
        () => tagService.createTag('work', 'not-a-color'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteTag hard deletes when unused', () async {
      final tag = await tagService.createTag('unused', '#FF5733');

      await tagService.deleteTag(tag.id);

      final retrieved = await tagService.getTagById(tag.id);
      expect(retrieved, null); // Hard deleted
    });

    test('deleteTag soft deletes when used', () async {
      final tag = await tagService.createTag('used', '#FF5733');
      final task = Task.create(title: 'Test Task');

      // Add task to database
      // ... (use TaskService to create task)

      await tagService.addTagToTask(task.id, tag.id);
      await tagService.deleteTag(tag.id);

      final retrieved = await tagService.getTagById(tag.id);
      expect(retrieved, null); // Soft deleted (excluded from getTagById)

      final usageCount = await tagService.getTagUsageCount(tag.id);
      expect(usageCount, 1); // Association still exists
    });

    test('getTasksForTags returns OR results', () async {
      final tag1 = await tagService.createTag('work', '#FF5733');
      final tag2 = await tagService.createTag('urgent', '#33FF57');

      // Create tasks and associate tags
      // ... (use TaskService + tagService.addTagToTask)

      final results = await tagService.getTasksForTags([tag1.id, tag2.id]);

      // Should return tasks with EITHER tag
      expect(results.length, greaterThan(0));
    });
  });
}
```

---

## Integration with TaskProvider

### Updated Task Model

```dart
// lib/models/task.dart (add field)

class Task {
  // ... existing fields ...
  final List<Tag>? tags; // Lazy-loaded tags

  Task({
    // ... existing parameters ...
    this.tags,
  });

  // Update copyWith to include tags
  Task copyWith({
    // ... existing parameters ...
    List<Tag>? tags,
  }) {
    return Task(
      // ... existing assignments ...
      tags: tags ?? this.tags,
    );
  }
}
```

### TaskProvider Updates

```dart
// lib/providers/task_provider.dart (add filtering logic)

class TaskProvider extends ChangeNotifier {
  // ... existing code ...

  TagProvider? _tagProvider; // Injected

  void setTagProvider(TagProvider tagProvider) {
    _tagProvider = tagProvider;
    tagProvider.addListener(_onTagFiltersChanged);
  }

  void _onTagFiltersChanged() {
    // Reload filtered tasks when tag filters change
    _applyTagFilters();
    notifyListeners();
  }

  Future<void> _applyTagFilters() async {
    if (_tagProvider == null || !_tagProvider!.hasActiveFilters) {
      // No filters - show all tasks
      return;
    }

    final tagIds = _tagProvider!.activeFilters.toList();
    final isAND = _tagProvider!.isFilterModeAND;

    final filteredTasks = isAND
        ? await _tagService.getTasksForTagsAND(tagIds)
        : await _tagService.getTasksForTags(tagIds);

    // Update _activeTasks and _recentlyCompletedTasks with filtered results
    _activeTasks = filteredTasks.where((t) => !t.completed).toList();
    _recentlyCompletedTasks = filteredTasks.where((t) => t.completed).toList();
  }

  // Load tags eagerly when loading tasks
  Future<void> loadTasks() async {
    _tasks = await _taskService.getAllTasksWithHierarchy();

    // Load tags for each task
    for (var task in _tasks) {
      final tags = await _tagService.getTagsForTask(task.id);
      task = task.copyWith(tags: tags);
    }

    _categorizeTasks();
    _refreshTreeController();
    notifyListeners();
  }
}
```

---

## Next Steps for Implementation

1. **Database Migration** (v5 → v6)
   - Add `deleted_at` column to tags
   - Create `tag_palettes` table
   - Update constants.dart

2. **Implement Core Models**
   - Tag model with validation
   - TagPalette model

3. **Implement TagService**
   - All CRUD operations
   - Soft delete logic
   - Association management

4. **Implement TagProvider**
   - State management
   - Filter logic

5. **Implement UI Widgets**
   - TagChip
   - TagPickerDialog
   - TagListWidget (expandable)

6. **Integrate with TaskProvider**
   - Add tags field to Task model
   - Load tags eagerly
   - Apply filters

7. **Add Context Menu Option**
   - "Add Tag" in task context menu

8. **Create Tag Management Screen**
   - List all tags
   - Edit/delete actions
   - Usage counts

9. **Testing**
   - Unit tests for TagService
   - Widget tests for TagChip
   - Integration tests

10. **Documentation & Ship** 🚀

---

**Implementation Status:** Ready to begin!
**Estimated Timeline:** 4-5 days
**Next Document:** Test plan (phase-3.5-test-plan.md)
