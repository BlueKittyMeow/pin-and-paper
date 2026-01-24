import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/brain_dump_provider.dart';
import '../utils/theme.dart';

class DraftsListScreen extends StatefulWidget {
  const DraftsListScreen({super.key});

  @override
  State<DraftsListScreen> createState() => _DraftsListScreenState();
}

class _DraftsListScreenState extends State<DraftsListScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    await context.read<BrainDumpProvider>().loadDrafts();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Drafts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<BrainDumpProvider>(
              builder: (context, provider, child) {
                if (provider.drafts.isEmpty) {
                  return const Center(
                    child: Text('No saved drafts'),
                  );
                }

          return Column(
            children: [
              // Selection summary + load button
              if (provider.selectedCount > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: provider.isOverLimit
                      ? AppTheme.warning.withValues(alpha: 0.2)
                      : AppTheme.info.withValues(alpha: 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.isOverLimit
                            ? '⚠️ Selected: ${provider.selectedCount} drafts (${provider.selectedTotalChars} characters)'
                            : 'Selected: ${provider.selectedCount} drafts (${provider.selectedTotalChars} characters)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: provider.isOverLimit ? AppTheme.warning : AppTheme.info,
                        ),
                      ),
                      if (provider.isOverLimit) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Exceeds 10,000 character limit by ${provider.excessCharacters}',
                          style: const TextStyle(color: AppTheme.warning, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: provider.isOverLimit
                            ? null
                            : () async {
                                // Get combined text from provider
                                final combinedText = provider.getCombinedDraftsText();

                                // Bug fix: If single draft selected, load it (reuse ID for updates)
                                // If multiple drafts, clear ID (create new combined draft)
                                if (provider.selectedCount == 1) {
                                  final selectedId = provider.selectedDraftIds.first;
                                  await provider.loadDraft(selectedId, combinedText);
                                } else {
                                  // Multiple drafts merged - clear ID to create new draft
                                  provider.clear();
                                }

                                // Return text to parent screen for controller
                                if (context.mounted) {
                                  Navigator.pop(context, combinedText);
                                }
                              },
                        child: Text(
                          provider.isOverLimit
                              ? 'Too much text - remove a draft'
                              : 'Load ${provider.selectedCount} Draft${provider.selectedCount > 1 ? "s" : ""}',
                        ),
                      ),
                    ],
                  ),
                ),

              // Draft list
              Expanded(
                child: ListView.builder(
                  itemCount: provider.drafts.length,
                  itemBuilder: (context, index) {
                    final draft = provider.drafts[index];
                    final preview = draft.content.length > 100
                        ? '${draft.content.substring(0, 100)}...'
                        : draft.content;

                    final isSelected = provider.selectedDraftIds.contains(draft.id);

                    return Dismissible(
                      key: Key(draft.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppTheme.danger,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => provider.deleteDraft(draft.id),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => provider.toggleDraftSelection(draft.id),
                        title: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatDate(draft.lastModified)} • ${draft.content.length} chars',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
