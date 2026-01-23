import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/tag.dart';
import '../providers/task_provider.dart';
import '../services/date_parsing_service.dart'; // Phase 3.7
import '../utils/debouncer.dart'; // Phase 3.7
import '../utils/date_formatter.dart'; // Phase 3.7
import '../utils/date_suffix_parser.dart'; // Phase 3.7
import 'highlighted_text_editing_controller.dart'; // Phase 3.7
import 'date_options_sheet.dart'; // Phase 3.7
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
  // Phase 3.7: Changed to HighlightedTextEditingController for date highlighting
  late HighlightedTextEditingController _titleController;
  late TextEditingController _notesController;

  // Phase 3.7: Date parsing state
  final DateParsingService _dateParser = DateParsingService();
  final Debouncer _debouncer = Debouncer(milliseconds: 300);
  ParsedDate? _parsedDate;
  bool _userDismissedParsing = false;

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

    // Phase 3.7: Use HighlightedTextEditingController for date highlighting
    _titleController = HighlightedTextEditingController(text: widget.task.title);
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

    // Phase 3.7: Detect existing date suffix and set up highlight
    _detectExistingDateSuffix();
  }

  /// Phase 3.7: Detect date suffix in existing task title and make it interactive
  void _detectExistingDateSuffix() {
    final title = widget.task.title;
    final suffixResult = DateSuffixParser.parse(title);

    if (suffixResult != null) {
      // Calculate the range of the suffix in the title
      final suffixStart = title.length - suffixResult.suffix.length;
      final suffixEnd = title.length;

      // Set up parsed date with the detected suffix
      _parsedDate = ParsedDate(
        matchedText: suffixResult.suffix,
        matchedRange: TextRange(start: suffixStart, end: suffixEnd),
        date: suffixResult.date,
        isAllDay: !suffixResult.hasTime,
      );

      // Set up highlight on the suffix
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _titleController.setHighlight(TextRange(start: suffixStart, end: suffixEnd));
        }
      });
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
    _debouncer.dispose(); // Phase 3.7
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
    // Phase 3.7: Also strip date text from title and clear highlight
    final text = _titleController.text;
    String cleanText = text;

    // Try stripping via parsed date range first
    if (_parsedDate != null) {
      final range = _parsedDate!.matchedRange;
      if (range.start >= 0 && range.end <= text.length) {
        cleanText = (text.substring(0, range.start) +
            text.substring(range.end)).trim();
      }
    }
    // Fallback: strip formatted suffix
    if (cleanText == text) {
      final suffixResult = DateSuffixParser.parse(text.trim());
      if (suffixResult != null) {
        cleanText = suffixResult.prefix.trim();
      }
    }

    setState(() {
      _titleController.clearHighlight();
      _titleController.text = cleanText;
      _parsedDate = null;
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
    // Phase 3.7: Use clean title (with date text stripped if parsed)
    final title = _getCleanTitle();
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

    // Phase 3.7: If there's a due date but no suffix in the title, append one
    String finalTitle = title;
    if (combinedDueDate != null && !DateSuffixParser.hasSuffix(title)) {
      final suffix = DateFormatter.formatTitleSuffix(
        combinedDueDate,
        isAllDay: _isAllDay,
      );
      finalTitle = '$title $suffix';
    }

    Navigator.pop(context, {
      'title': finalTitle,
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

  // ===== PHASE 3.7: DATE PARSING METHODS =====

  void _onTitleChanged(String text) {
    // Reset dismissal flag when user continues typing after dismissal
    // (UX: If they dismissed parsing but keep typing, they likely want parsing back)
    if (_userDismissedParsing) {
      setState(() {
        _userDismissedParsing = false;
      });
    }

    // PRE-FILTER (Codex/Gemini): Skip parsing if no date-like tokens
    // Reduces FFI calls by 80-90% (most tasks don't have dates)
    if (!_dateParser.containsPotentialDate(text)) {
      _debouncer.cancel(); // Stop any pending parse
      _titleController.clearHighlight();
      setState(() => _parsedDate = null);
      return;
    }

    // Debounce parsing (300ms after last keystroke)
    _debouncer.run(() {
      if (!_userDismissedParsing) {
        _parseDateFromTitle(text);
      }
    });
  }

  void _parseDateFromTitle(String text) {
    try {
      final parsed = _dateParser.parse(text);

      setState(() {
        _parsedDate = parsed;

        if (parsed != null) {
          _titleController.setHighlight(parsed.matchedRange);
          // Auto-apply parsed date to _dueDate
          _dueDate = parsed.date;
          _isAllDay = parsed.isAllDay;
          if (!parsed.isAllDay) {
            // Convert UTC datetime to local before extracting time
            _dueTime = TimeOfDay.fromDateTime(parsed.date.toLocal());
          }
        } else {
          _titleController.clearHighlight();
        }
      });
    } catch (e) {
      print('Error parsing date: $e');
      // Silently fail - don't disrupt user
    }
  }

  // Phase 3.7: Handle tap on title TextField - check if cursor is on highlighted date
  // PostFrameCallback ensures cursor position is finalized before we read it.
  void _handleTitleTap() {
    if (_parsedDate == null || _titleController.highlightRange == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_parsedDate == null || _titleController.highlightRange == null) return;
      final cursorPos = _titleController.selection.baseOffset;
      final range = _titleController.highlightRange!;
      if (cursorPos >= range.start && cursorPos <= range.end) {
        _showDateOptions();
      }
    });
  }

  void _showDateOptions() {
    if (_parsedDate == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => DateOptionsSheet(
        parsedDate: _parsedDate!,
        onRemove: () {
          // Strip date text from title
          final text = _titleController.text;
          String cleanText = text;
          if (_parsedDate != null) {
            final range = _parsedDate!.matchedRange;
            if (range.start >= 0 && range.end <= text.length) {
              cleanText = (text.substring(0, range.start) +
                  text.substring(range.end)).trim();
            }
          }
          // Fallback: strip formatted suffix if range didn't work
          if (cleanText == text) {
            final suffixResult = DateSuffixParser.parse(text.trim());
            if (suffixResult != null) {
              cleanText = suffixResult.prefix.trim();
            }
          }

          setState(() {
            _parsedDate = null;
            _titleController.clearHighlight();
            _titleController.text = cleanText;
            // Clear due date fields
            _dueDate = null;
            _dueTime = null;
            _isAllDay = true;
          });
          Navigator.pop(context);
        },
        onSelectDate: (DateTime date, bool isAllDay) {
          // Strip old date text and replace with new formatted suffix
          final text = _titleController.text;
          String cleanText = text;
          final range = _parsedDate!.matchedRange;
          if (range.start >= 0 && range.end <= text.length) {
            cleanText = (text.substring(0, range.start) +
                text.substring(range.end)).trim();
          } else {
            final suffixResult = DateSuffixParser.parse(text.trim());
            if (suffixResult != null) {
              cleanText = suffixResult.prefix.trim();
            }
          }

          // Append new suffix for the selected date
          final newSuffix = DateFormatter.formatTitleSuffix(
            date,
            isAllDay: isAllDay,
          );
          final newTitle = '$cleanText $newSuffix';
          final suffixStart = cleanText.length + 1; // +1 for the space
          final suffixEnd = newTitle.length;

          setState(() {
            _titleController.text = newTitle;
            _parsedDate = ParsedDate(
              matchedText: newSuffix,
              matchedRange: TextRange(start: suffixStart, end: suffixEnd),
              date: date,
              isAllDay: isAllDay,
            );
            _titleController.setHighlight(
              TextRange(start: suffixStart, end: suffixEnd),
            );
            // Update the actual due date fields
            _dueDate = date;
            _isAllDay = isAllDay;
            if (!isAllDay) {
              _dueTime = TimeOfDay.fromDateTime(date);
            } else {
              _dueTime = null;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  String _getCleanTitle() {
    if (_parsedDate == null || _userDismissedParsing) {
      // Even without active parsing, strip any existing suffix
      // (handles case where user clears due date on a task with suffix)
      final text = _titleController.text.trim();
      final suffixResult = DateSuffixParser.parse(text);
      if (suffixResult != null) {
        return suffixResult.prefix.trim();
      }
      return text;
    }

    // Strip the matched date text from title
    final text = _titleController.text;
    final range = _parsedDate!.matchedRange;

    // Safety: if range is out of bounds (user edited title), fall back to suffix parser
    if (range.start < 0 || range.end > text.length || range.start > range.end) {
      final suffixResult = DateSuffixParser.parse(text.trim());
      if (suffixResult != null) {
        return suffixResult.prefix.trim();
      }
      return text.trim();
    }

    final before = text.substring(0, range.start);
    final after = text.substring(range.end);

    // Return only the stripped title - _save() handles suffix appending
    return '${before}${after}'.trim();
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
                      onChanged: _onTitleChanged, // Phase 3.7: Date parsing
                      onTap: _handleTitleTap, // Phase 3.7: Tap highlight to refine date
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g., Call dentist tomorrow', // Phase 3.7
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                    ),

                    // Phase 3.7: Date preview
                    if (_parsedDate != null && !_userDismissedParsing)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          'Due: ${DateFormatter.formatRelativeDate(_parsedDate!.date.toLocal(), isAllDay: _parsedDate!.isAllDay)}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
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
