import 'package:flutter/material.dart';
import '../models/task_suggestion.dart';

class TaskSuggestionItem extends StatefulWidget {
  final TaskSuggestion suggestion;
  final Function(String) onToggle;
  final Function(String, String) onEdit;
  final Function(String) onDelete;

  const TaskSuggestionItem({
    super.key,
    required this.suggestion,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TaskSuggestionItem> createState() => _TaskSuggestionItemState();
}

class _TaskSuggestionItemState extends State<TaskSuggestionItem> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestion.title);
  }

  @override
  void didUpdateWidget(TaskSuggestionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if suggestion changed
    if (oldWidget.suggestion.title != widget.suggestion.title) {
      _controller.text = widget.suggestion.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: widget.suggestion.approved ? 2 : 1,
      color: widget.suggestion.approved ? null : Colors.grey.shade200,
      child: ListTile(
        leading: Checkbox(
          value: widget.suggestion.approved,
          onChanged: (_) => widget.onToggle(widget.suggestion.id),
        ),
        title: TextField(
          controller: _controller,
          onChanged: (value) => widget.onEdit(widget.suggestion.id, value),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
          style: TextStyle(
            decoration: widget.suggestion.approved ? null : TextDecoration.lineThrough,
            color: widget.suggestion.approved ? null : Colors.grey,
          ),
          enabled: widget.suggestion.approved,
        ),
        subtitle: widget.suggestion.notes != null && widget.suggestion.notes!.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.suggestion.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.suggestion.approved ? Colors.grey.shade700 : Colors.grey,
                  ),
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => widget.onDelete(widget.suggestion.id),
        ),
      ),
    );
  }
}
