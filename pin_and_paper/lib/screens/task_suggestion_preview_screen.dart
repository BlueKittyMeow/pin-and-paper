import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/brain_dump_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_suggestion_item.dart';

class TaskSuggestionPreviewScreen extends StatelessWidget {
  const TaskSuggestionPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Consumer<BrainDumpProvider>(
        builder: (context, provider, child) {
          final suggestions = provider.suggestions;
          final approvedCount = provider.getApprovedSuggestions().length;

          if (suggestions.isEmpty) {
            return const Center(
              child: Text('No task suggestions available'),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${suggestions.length} task${suggestions.length != 1 ? 's' : ''} suggested',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    return TaskSuggestionItem(
                      suggestion: suggestions[index],
                      onToggle: (id) => provider.toggleSuggestionApproval(id),
                      onEdit: (id, title) => provider.editSuggestion(id, title),
                      onDelete: (id) => provider.removeSuggestion(id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<BrainDumpProvider>(
        builder: (context, provider, child) {
          final approvedCount = provider.getApprovedSuggestions().length;

          return BottomAppBar(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: approvedCount > 0 ? () => _addApprovedTasks(context) : null,
                    child: Text('Add $approvedCount Task${approvedCount != 1 ? 's' : ''}'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addApprovedTasks(BuildContext context) async {
    final brainDumpProvider = context.read<BrainDumpProvider>();
    final taskProvider = context.read<TaskProvider>();

    final approved = brainDumpProvider.getApprovedSuggestions();

    if (approved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tasks selected')),
      );
      return;
    }

    try {
      // Bulk create tasks in a single transaction (MUCH faster!)
      // Uses TaskProvider.createMultipleTasks() which:
      // 1. Creates all tasks in one database transaction
      // 2. Updates UI ONCE instead of N times
      // 3. No stuttering/flashing as tasks appear
      await taskProvider.createMultipleTasks(approved);

      // Clear brain dump
      brainDumpProvider.clear();

      // Navigate back to home
      if (context.mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${approved.length} task${approved.length != 1 ? 's' : ''} added!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add tasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
