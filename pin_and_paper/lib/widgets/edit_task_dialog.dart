import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/tag.dart';
import '../providers/task_provider.dart';
import 'inline_tag_picker.dart';
import 'parent_selector_dialog.dart'; // Phase 3.6.5 Day 4

/// Phase 3.6.5: Comprehensive Edit Task Dialog
///
/// Allows editing all task fields:
/// - Title
/// - Parent task (via selector)
/// - Due date
/// - Tags (inline picker)
/// - Notes
///
/// Key Features:
/// - SingleChildScrollView for small screens (v2 fix)
/// - Mounted guards on all async operations (v2 fix)
/// - In-memory update pattern (preserves tree state) (v2 fix)
class EditTaskDialog extends StatefulWidget {
  final Task task;
  final List<Tag> currentTags;

  const EditTaskDialog({
    super.key,
    required this.task,
    required this.currentTags,
  });

  /// Show the edit task dialog
  ///
  /// Returns a map of updated fields or null if cancelled
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required Task task,
    required List<Tag> currentTags,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        currentTags: currentTags,
      ),
    );
  }

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  DateTime? _dueDate;
  TimeOfDay? _dueTime; // Time component (separate for picker)
  bool _isAllDay = true; // All-day vs specific time
  String? _parentId;
  List<String> _selectedTagIds = [];
  final bool _isLoading = false; // Reserved for future async loading
  String? _parentTitle;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _dueDate = widget.task.dueDate;
    _isAllDay = widget.task.isAllDay;
    // Extract time from existing dueDate if not all-day
    if (widget.task.dueDate != null && !widget.task.isAllDay) {
      _dueTime = TimeOfDay.fromDateTime(widget.task.dueDate!);
    }
    _parentId = widget.task.parentId;
    _selectedTagIds = widget.currentTags.map((t) => t.id).toList();

    // Select all title text for easy replacement
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );

    // Load parent title if has parent
    if (_parentId != null) {
      _loadParentTitle();
    }
  }

  Future<void> _loadParentTitle() async {
    final taskProvider = context.read<TaskProvider>();
    final parent = taskProvider.getTaskById(_parentId!);

    if (!mounted) return;

    setState(() {
      _parentTitle = parent?.title;
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
      _dueTime = null;
      _isAllDay = true;
    });
  }

  Future<void> _selectDueTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
      helpText: 'Select Due Time',
    );

    if (time != null && mounted) {
      setState(() {
        _dueTime = time;
      });
    }
  }

  void _toggleAllDay(bool isAllDay) {
    setState(() {
      _isAllDay = isAllDay;
      if (isAllDay) {
        _dueTime = null; // Clear time when switching to all-day
      }
    });
  }

  Future<void> _selectParent() async {
    if (!mounted) return;

    // v3 FIX (Codex #4): Use ParentSelectorResult to distinguish cancel vs selection
    final result = await ParentSelectorDialog.show(
      context: context,
      currentTaskId: widget.task.id,
      currentParentId: _parentId,
    );

    if (!mounted) return;

    // User pressed back or closed dialog without result
    if (result == null) return;

    // User explicitly cancelled
    if (result.wasCancelled) return;

    // User selected a parent (may be null for "No Parent")
    final newParentId = result.selectedParentId;

    // Only update if changed
    if (newParentId != _parentId) {
      setState(() {
        _parentId = newParentId;
        _parentTitle = null; // Will reload
      });

      // Reload parent title if new parent selected
      if (newParentId != null) {
        _loadParentTitle();
      }
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

    // Combine date and time into a single DateTime
    DateTime? combinedDueDate;
    if (_dueDate != null) {
      if (_isAllDay || _dueTime == null) {
        // All-day: keep just the date (midnight)
        combinedDueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
        );
      } else {
        // With time: combine date and time
        combinedDueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _dueTime!.hour,
          _dueTime!.minute,
        );
      }
    }

    Navigator.pop(context, {
      'title': title,
      'dueDate': combinedDueDate,
      'isAllDay': _isAllDay,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'parentId': _parentId,
      'tagIds': _selectedTagIds,
    });
  }

  String _getParentDisplayText() {
    if (_parentId == null) {
      return 'No Parent (Root Level)';
    }
    if (_parentTitle != null) {
      return 'Parent: $_parentTitle';
    }
    return 'Parent: (Loading...)';
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
                        _getParentDisplayText(),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        alignment: Alignment.centerLeft,
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
                              alignment: Alignment.centerLeft,
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

                    // ===== ALL DAY TOGGLE + TIME PICKER =====
                    // Only show when date is set
                    if (_dueDate != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // All Day toggle
                          Expanded(
                            child: SwitchListTile(
                              value: _isAllDay,
                              onChanged: _toggleAllDay,
                              title: const Text('All Day'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          // Time picker (only when NOT all-day)
                          if (!_isAllDay)
                            OutlinedButton.icon(
                              onPressed: _selectDueTime,
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                _dueTime == null
                                    ? 'Set Time'
                                    : _dueTime!.format(context),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                        ],
                      ),
                    ],
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
}
