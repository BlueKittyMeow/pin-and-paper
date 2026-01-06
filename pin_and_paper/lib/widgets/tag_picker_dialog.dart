import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';
import 'color_picker_dialog.dart';
import 'tag_chip.dart';

/// Dialog for selecting and managing tags for a task
///
/// Phase 3.5: Tags feature
/// - Select from existing tags
/// - Create new tags with color picker
/// - Search/filter tags
/// - Visual feedback for selected tags
class TagPickerDialog extends StatefulWidget {
  final String taskId;
  final List<Tag> currentTags;

  const TagPickerDialog({
    super.key,
    required this.taskId,
    required this.currentTags,
  });

  /// Show the tag picker dialog
  ///
  /// Returns list of selected tag IDs or null if cancelled
  static Future<List<String>?> show({
    required BuildContext context,
    required String taskId,
    required List<Tag> currentTags,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => TagPickerDialog(
        taskId: taskId,
        currentTags: currentTags,
      ),
    );
  }

  @override
  State<TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<TagPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTagIds = {};
  bool _isCreatingTag = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current tags
    _selectedTagIds.addAll(widget.currentTags.map((t) => t.id));

    // Load all tags
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TagProvider>().loadTags();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTag() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isCreatingTag = true;
    });

    try {
      final tagProvider = context.read<TagProvider>();

      // Check if tag already exists
      final existing = await tagProvider.findTagByName(name);
      if (existing != null && mounted) {
        // Tag exists, just select it
        setState(() {
          _selectedTagIds.add(existing.id);
          _searchController.clear();
        });
        return;
      }

      // Show color picker
      if (!mounted) return;
      final colorHex = await ColorPickerDialog.show(
        context: context,
        initialColor: tagProvider.getNextPresetColor(),
      );

      // Codex review: Guard setState against disposed widget
      if (!mounted) return;
      if (colorHex == null) {
        setState(() {
          _isCreatingTag = false;
        });
        return;
      }

      // Create tag
      final tag = await tagProvider.createTag(name, color: colorHex);

      if (tag != null && mounted) {
        setState(() {
          _selectedTagIds.add(tag.id);
          _searchController.clear();
        });

        // Show feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created tag "${tag.name}"'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (tag == null && mounted) {
        // Codex review: Show tag creation errors to user
        // Phase 3.5: Fix #H3 - Float SnackBar above keyboard for visibility
        final errorMsg = tagProvider.errorMessage ?? 'Failed to create tag';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTag = false;
        });
      }
    }
  }

  void _toggleTag(Tag tag) {
    setState(() {
      if (_selectedTagIds.contains(tag.id)) {
        _selectedTagIds.remove(tag.id);
      } else {
        _selectedTagIds.add(tag.id);
      }
    });
  }

  List<Tag> _getFilteredTags(List<Tag> allTags) {
    final query = _searchController.text.toLowerCase().trim();

    // Filter by search query
    final filtered = query.isEmpty
        ? allTags
        : allTags.where((tag) {
            return tag.name.toLowerCase().contains(query);
          }).toList();

    // Phase 3.5: Fix #H4 - Sort selected tags to top
    return _sortTagsWithSelectedFirst(filtered);
  }

  /// Sort tags with selected ones first, then alphabetically within each group
  List<Tag> _sortTagsWithSelectedFirst(List<Tag> tags) {
    return tags.toList()
      ..sort((a, b) {
        // Selected tags first
        final aSelected = _selectedTagIds.contains(a.id);
        final bSelected = _selectedTagIds.contains(b.id);

        if (aSelected && !bSelected) return -1;
        if (!aSelected && bSelected) return 1;

        // Within each group (selected/unselected), sort alphabetically (case-insensitive)
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Tags'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search/Create field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search or create tag',
                hintText: 'Type tag name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: _isCreatingTag ? null : _handleCreateTag,
                        tooltip: 'Create new tag',
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {}),
              onSubmitted: (_) => _handleCreateTag(),
            ),

            const SizedBox(height: 16),

            // Tag list
            Expanded(
              child: Consumer<TagProvider>(
                builder: (context, tagProvider, child) {
                  if (tagProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final filteredTags = _getFilteredTags(tagProvider.tags);
                  final searchText = _searchController.text.trim();

                  // Gemini review: Show explicit "Create new tag" option for clarity
                  // Check if search text is non-empty and doesn't exactly match any tag
                  final hasExactMatch = searchText.isNotEmpty &&
                      filteredTags.any((tag) => tag.name.toLowerCase() == searchText.toLowerCase());
                  final showCreateOption = searchText.isNotEmpty && !hasExactMatch;

                  if (filteredTags.isEmpty && !showCreateOption) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.label_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No tags yet'
                                : 'No matching tags',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: (showCreateOption ? 1 : 0) + filteredTags.length,
                    itemBuilder: (context, index) {
                      // Show "Create new tag" option as first item
                      if (showCreateOption && index == 0) {
                        return ListTile(
                          leading: Icon(
                            Icons.add_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Create new tag: '),
                                TextSpan(
                                  text: '"$searchText"',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          onTap: _isCreatingTag ? null : _handleCreateTag,
                          tileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        );
                      }

                      // Show existing tags (offset index if create option is shown)
                      final tagIndex = showCreateOption ? index - 1 : index;
                      final tag = filteredTags[tagIndex];
                      final isSelected = _selectedTagIds.contains(tag.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) => _toggleTag(tag),
                        title: Row(
                          children: [
                            TagChip(tag: tag, compact: true),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedTagIds.toList()),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
