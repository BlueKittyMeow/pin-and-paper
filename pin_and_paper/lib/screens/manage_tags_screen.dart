import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';
import '../services/tag_service.dart';
import '../utils/tag_colors.dart';
import '../utils/theme.dart';
import '../widgets/color_picker_dialog.dart';

/// Screen for managing tags — rename, recolor, delete
///
/// Phase 4.0: Tag management feature
/// Entry point: Settings → Data Management → Manage Tags
class ManageTagsScreen extends StatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  State<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends State<ManageTagsScreen> {
  final TagService _tagService = TagService();
  Map<String, int> _taskCounts = {};

  @override
  void initState() {
    super.initState();
    _loadTaskCounts();
  }

  Future<void> _loadTaskCounts() async {
    try {
      final counts = await _tagService.getTaskCountsByTag(completed: false);
      if (mounted) {
        setState(() {
          _taskCounts = counts;
        });
      }
    } catch (e) {
      // Counts are non-critical; UI will show "0 active tasks" as fallback
    }
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    String? selectedColor;
    String? errorText;

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Tag name',
                  errorText: errorText,
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Color: '),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final color = await ColorPickerDialog.show(
                        context: context,
                        initialColor: selectedColor,
                      );
                      if (color != null) {
                        setDialogState(() => selectedColor = color);
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selectedColor != null
                            ? TagColors.hexToColor(selectedColor!)
                            : TagColors.defaultColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.colorize, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Tag name cannot be empty');
                  return;
                }
                Navigator.pop(context, {'name': name, 'color': selectedColor});
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final tagProvider = context.read<TagProvider>();
      final tag = await tagProvider.createTag(
        result['name']!,
        color: result['color'],
      );
      if (tag != null) {
        await _loadTaskCounts();
      } else if (mounted && tagProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tagProvider.errorMessage!)),
        );
      }
    }
  }

  Future<void> _showEditDialog(Tag tag) async {
    final nameController = TextEditingController(text: tag.name);
    String? selectedColor = tag.color;
    String? errorText;

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Tag name',
                  errorText: errorText,
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Color: '),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final color = await ColorPickerDialog.show(
                        context: context,
                        initialColor: selectedColor,
                      );
                      if (color != null) {
                        setDialogState(() => selectedColor = color);
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selectedColor != null
                            ? TagColors.hexToColor(selectedColor!)
                            : TagColors.defaultColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.colorize, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Tag name cannot be empty');
                  return;
                }
                Navigator.pop(context, {'name': name, 'color': selectedColor});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final newName = result['name']!;
      final newColor = result['color'];

      // Only update fields that changed
      final nameChanged = newName != tag.name;
      final colorChanged = newColor != tag.color;

      if (!nameChanged && !colorChanged) return;

      final tagProvider = context.read<TagProvider>();
      final updated = await tagProvider.updateTag(
        tag.id,
        name: nameChanged ? newName : null,
        color: colorChanged ? newColor : null,
      );
      if (updated != null) {
        await _loadTaskCounts();
      } else if (mounted && tagProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tagProvider.errorMessage!)),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(Tag tag) async {
    final count = _taskCounts[tag.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text(
          count > 0
              ? 'This will remove "${tag.name}" from $count active ${count == 1 ? 'task' : 'tasks'}. This cannot be undone.'
              : 'Delete "${tag.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final tagProvider = context.read<TagProvider>();
      final success = await tagProvider.deleteTag(tag.id);
      if (success) {
        await _loadTaskCounts();
      } else if (mounted && tagProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tagProvider.errorMessage!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create tag',
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: Consumer<TagProvider>(
        builder: (context, tagProvider, _) {
          if (tagProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final tags = tagProvider.tags;

          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tags yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first tag with the + button',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              final color = tag.color != null
                  ? TagColors.hexToColor(tag.color!)
                  : TagColors.defaultColor;
              final count = _taskCounts[tag.id] ?? 0;

              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(tag.name),
                subtitle: Text(
                  '$count active ${count == 1 ? 'task' : 'tasks'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit tag',
                      onPressed: () => _showEditDialog(tag),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                      tooltip: 'Delete tag',
                      onPressed: () => _showDeleteConfirmation(tag),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
