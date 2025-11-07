import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../services/task_matching_service.dart';

class QuickCompleteScreen extends StatefulWidget {
  const QuickCompleteScreen({super.key});

  @override
  State<QuickCompleteScreen> createState() => _QuickCompleteScreenState();
}

class _QuickCompleteScreenState extends State<QuickCompleteScreen> {
  final TextEditingController _controller = TextEditingController();
  final TaskMatchingService _matchingService = TaskMatchingService();
  List<TaskMatch> _matches = [];
  bool _hasSearched = false;
  Set<String> _selectedTaskIds = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _searchMatches(String input) {
    if (input.trim().isEmpty) {
      setState(() {
        _matches = [];
        _hasSearched = false;
        _selectedTaskIds.clear();
      });
      return;
    }

    final taskProvider = context.read<TaskProvider>();
    final matches = _matchingService.findMatches(
      input,
      taskProvider.tasks,
    );

    setState(() {
      _matches = matches;
      _hasSearched = true;
      _selectedTaskIds.clear(); // Clear selection when search changes
    });
  }

  // Single task quick complete (only when 1 match)
  Future<void> _completeTaskImmediately(TaskMatch match) async {
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.toggleTaskCompletion(match.task);

    if (!mounted) return;

    // Bug fix: Capture messenger BEFORE popping to prevent snackbar from vanishing
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text('✓ Completed: ${match.task.title}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Batch complete selected tasks
  Future<void> _completeSelected() async {
    final taskProvider = context.read<TaskProvider>();

    for (final taskId in _selectedTaskIds) {
      final match = _matches.firstWhere((m) => m.task.id == taskId);
      await taskProvider.toggleTaskCompletion(match.task);
    }

    if (!mounted) return;

    // Bug fix: Capture messenger BEFORE popping to prevent snackbar from vanishing
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text('✓ Completed ${_selectedTaskIds.length} task(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Complete all matches
  Future<void> _completeAll() async {
    final taskProvider = context.read<TaskProvider>();

    for (final match in _matches) {
      await taskProvider.toggleTaskCompletion(match.task);
    }

    if (!mounted) return;

    // Bug fix: Capture messenger BEFORE popping to prevent snackbar from vanishing
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text('✓ Completed ${_matches.length} task(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getConfidenceLabel(double similarity) {
    if (similarity >= 0.90) return 'Exact match';
    if (similarity >= 0.75) return 'Likely match';
    return 'Possible match';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Complete'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input field
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'What did you finish?',
                hintText: 'e.g., "finished calling dentist"',
                border: OutlineInputBorder(),
              ),
              onChanged: _searchMatches,
            ),
            const SizedBox(height: 8),

            // Debug info
            Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                final incompleteCount = taskProvider.tasks.where((t) => !t.completed).length;
                final cleaned = _controller.text.isEmpty
                    ? ''
                    : _matchingService.extractAction(_controller.text);

                return Text(
                  'Searching ${incompleteCount} incomplete tasks${cleaned.isNotEmpty ? " • Cleaned: \"$cleaned\"" : ""}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
            const SizedBox(height: 8),

            // Matches list
            Expanded(
              child: _matches.isEmpty
                  ? Center(
                      child: Text(
                        _hasSearched
                            ? 'No matching tasks found.\nTry different keywords!'
                            : 'Type to search your tasks...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Match list
                        Expanded(
                          child: ListView.builder(
                            itemCount: _matches.length,
                            itemBuilder: (context, index) {
                              final match = _matches[index];
                              final isHighConfidence = match.similarity >= 0.75;
                              final isSelected = _selectedTaskIds.contains(match.task.id);

                              // If only 1 match, use simple tap to complete
                              if (_matches.length == 1) {
                                return ListTile(
                                  leading: Icon(
                                    Icons.task_alt,
                                    color: isHighConfidence ? Colors.green : Colors.orange,
                                  ),
                                  title: Text(match.task.title),
                                  subtitle: Text(
                                    '${(match.similarity * 100).toStringAsFixed(1)}% - ${_getConfidenceLabel(match.similarity)}',
                                  ),
                                  trailing: const Icon(Icons.check_circle_outline),
                                  onTap: () => _completeTaskImmediately(match),
                                );
                              }

                              // Multiple matches: show checkboxes
                              return CheckboxListTile(
                                secondary: Icon(
                                  Icons.task_alt,
                                  color: isHighConfidence ? Colors.green : Colors.orange,
                                ),
                                title: Text(match.task.title),
                                subtitle: Text(
                                  '${(match.similarity * 100).toStringAsFixed(1)}% - ${_getConfidenceLabel(match.similarity)}',
                                ),
                                value: isSelected,
                                activeColor: Colors.green,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedTaskIds.add(match.task.id);
                                    } else {
                                      _selectedTaskIds.remove(match.task.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),

                        // Batch action buttons (only show when multiple matches)
                        if (_matches.length > 1)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Mark All Complete (smaller button)
                                OutlinedButton(
                                  onPressed: _completeAll,
                                  child: const Text('Mark All Complete'),
                                ),
                                const SizedBox(width: 12),
                                // Mark Selected Complete (main button)
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _selectedTaskIds.isEmpty ? null : _completeSelected,
                                    child: Text(
                                      _selectedTaskIds.isEmpty
                                          ? 'Select tasks to complete'
                                          : 'Mark ${_selectedTaskIds.length} Selected Complete',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
