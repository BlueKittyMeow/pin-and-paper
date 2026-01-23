import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/task_provider.dart';
import '../services/date_parsing_service.dart'; // Phase 3.7
import '../utils/debouncer.dart'; // Phase 3.7
import '../utils/date_formatter.dart'; // Phase 3.7
import 'highlighted_text_editing_controller.dart'; // Phase 3.7
import 'date_options_sheet.dart'; // Phase 3.7

class TaskInput extends StatefulWidget {
  const TaskInput({super.key});

  @override
  State<TaskInput> createState() => _TaskInputState();
}

class _TaskInputState extends State<TaskInput> {
  late HighlightedTextEditingController _controller; // Phase 3.7: Changed type
  final FocusNode _focusNode = FocusNode();
  static const String _hasLaunchedKey = 'has_launched_before';

  // Phase 3.7: Date parsing state
  final DateParsingService _dateParser = DateParsingService();
  final Debouncer _debouncer = Debouncer(milliseconds: 300);
  ParsedDate? _parsedDate;

  @override
  void initState() {
    super.initState();

    // Phase 3.7: Initialize HighlightedTextEditingController
    _controller = HighlightedTextEditingController(text: '');

    // Only auto-focus on first app launch
    _checkAndFocusOnFirstLaunch();
  }

  Future<void> _checkAndFocusOnFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunched = prefs.getBool(_hasLaunchedKey) ?? false;

    if (!hasLaunched && mounted) {
      // First launch - focus the input
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
      await prefs.setBool(_hasLaunchedKey, true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debouncer.dispose(); // Phase 3.7: Cleanup
    super.dispose();
  }

  // Phase 3.7: Handle title changes for date parsing
  void _onTitleChanged(String text) {
    // PRE-FILTER: Skip parsing if no date-like tokens
    // Reduces FFI calls by 80-90% (most tasks don't have dates)
    if (!_dateParser.containsPotentialDate(text)) {
      _debouncer.cancel(); // Stop any pending parse
      _controller.clearHighlight();
      setState(() => _parsedDate = null);
      return;
    }

    // Debounce parsing (300ms after last keystroke)
    _debouncer.run(() {
      _parseDateFromTitle(text);
    });
  }

  // Phase 3.7: Parse date from title
  void _parseDateFromTitle(String text) {
    try {
      final parsed = _dateParser.parse(text);

      setState(() {
        _parsedDate = parsed;

        if (parsed != null) {
          _controller.setHighlight(parsed.matchedRange);
        } else {
          _controller.clearHighlight();
        }
      });
    } catch (e) {
      print('Error parsing date: $e');
      // Silently fail - don't disrupt user
    }
  }

  // Phase 3.7: Handle tap on TextField - check if cursor is on highlighted date
  // Note: TapGestureRecognizer on TextSpan doesn't work in editable TextFields
  // (Flutter's EditableText gesture handler wins the gesture arena).
  // Instead, we detect taps via onTap + cursor position check.
  // PostFrameCallback ensures cursor position is finalized before we read it.
  void _handleTextFieldTap() {
    if (_parsedDate == null || _controller.highlightRange == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_parsedDate == null || _controller.highlightRange == null) return;
      final cursorPos = _controller.selection.baseOffset;
      final range = _controller.highlightRange!;
      if (cursorPos >= range.start && cursorPos <= range.end) {
        _showDateOptions();
      }
    });
  }

  // Phase 3.7: Show date options sheet when tapping highlighted date
  void _showDateOptions() {
    if (_parsedDate == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => DateOptionsSheet(
        parsedDate: _parsedDate!,
        onRemove: () {
          setState(() {
            _parsedDate = null;
            _controller.clearHighlight();
          });
          Navigator.pop(context);
        },
        onSelectDate: (DateTime date, bool isAllDay) {
          setState(() {
            _parsedDate = ParsedDate(
              matchedText: _parsedDate!.matchedText,
              matchedRange: _parsedDate!.matchedRange,
              date: date,
              isAllDay: isAllDay,
            );
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // Phase 3.7: Get clean title with formatted date suffix appended
  String _getCleanTitle() {
    if (_parsedDate == null) {
      return _controller.text.trim();
    }

    final text = _controller.text;
    final range = _parsedDate!.matchedRange;

    final before = text.substring(0, range.start);
    final after = text.substring(range.end);

    // Clean up extra whitespace from stripped text
    final strippedTitle = '${before}${after}'.trim();

    // Append formatted date suffix for clarity
    // e.g., "Call office" + " (Mon, Jan 26)" or "Meeting" + " (Today, 3:00 PM)"
    final dateSuffix = DateFormatter.formatTitleSuffix(
      _parsedDate!.date.toLocal(),
      isAllDay: _parsedDate!.isAllDay,
    );

    return '$strippedTitle $dateSuffix';
  }

  void _addTask() {
    // Phase 3.7: Use clean title (with formatted date suffix)
    final title = _getCleanTitle();
    if (title.isEmpty) return;

    // Phase 3.7: Extract parsed date information
    DateTime? dueDate;
    bool isAllDay = true;

    if (_parsedDate != null) {
      dueDate = _parsedDate!.date;
      isAllDay = _parsedDate!.isAllDay;
    }

    // Call updated API with date parameters
    context.read<TaskProvider>().createTask(
      title,
      dueDate: dueDate,
      isAllDay: isAllDay,
    );

    _controller.clear();
    setState(() => _parsedDate = null); // Reset parsing state
    // Don't auto-refocus - let user manually tap if they want to add more
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: 'Add a task...',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onTap: _handleTextFieldTap, // Phase 3.7: Tap highlight to refine date
              onSubmitted: (_) => _addTask(),
              onChanged: _onTitleChanged, // Phase 3.7: Add date parsing handler
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _addTask,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
