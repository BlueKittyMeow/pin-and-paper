import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/brain_dump_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';
import 'task_suggestion_preview_screen.dart';

class BrainDumpScreen extends StatefulWidget {
  const BrainDumpScreen({super.key});

  @override
  State<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends State<BrainDumpScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Update provider when text changes
    _textController.addListener(() {
      context.read<BrainDumpProvider>().updateDumpText(_textController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent automatic navigation
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return; // Already popped, do nothing

        // Intercept ALL navigation attempts (button, gesture, etc.)
        if (_textController.text.trim().isNotEmpty) {
          final shouldExit = await _showExitConfirmation();
          if (shouldExit && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          // Empty text, allow navigation
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Brain Dump'),
        ),
        body: Consumer<BrainDumpProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // Error message banner
                if (provider.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade100,
                    child: Text(
                      provider.errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),

                // Large text field
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      minLines: 20,
                      maxLength: AppConstants.maxBrainDumpLength,
                      decoration: const InputDecoration(
                        hintText: 'Pour out your thoughts... everything that\'s on your mind',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      autofocus: true,
                      enabled: !provider.isProcessing,
                    ),
                  ),
                ),

                // Loading indicator
                if (provider.isProcessing)
                  const LinearProgressIndicator(),
              ],
            );
          },
        ),
        bottomNavigationBar: Consumer<BrainDumpProvider>(
          builder: (context, provider, child) {
            return BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: provider.isProcessing ? null : _showClearConfirmation,
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: (_textController.text.isEmpty || provider.isProcessing)
                          ? null
                          : _processBrainDump,
                      icon: provider.isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(provider.isProcessing ? 'Processing...' : 'Claude, Help Me'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _processBrainDump() async {
    // Check for API key first
    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.hasApiKey) {
      final shouldNavigateToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Key Required'),
          content: const Text(
            'You need to configure your Claude API key before using Brain Dump.\n\n'
            'Would you like to set it up now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );

      if (shouldNavigateToSettings == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      }
      return;
    }

    // Estimate cost and show confirmation
    final provider = context.read<BrainDumpProvider>();
    await provider.estimateCost();

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Processing'),
        content: Text(
          'Estimated cost: \$${provider.estimatedCost.toStringAsFixed(3)}\n\n'
          'This will send your text to Claude AI for processing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.processDump();

      // If successful (suggestions available), navigate to preview
      if (mounted && provider.suggestions.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TaskSuggestionPreviewScreen(),
          ),
        );
      }
    }
  }

  void _showClearConfirmation() {
    if (_textController.text.isEmpty) {
      return; // Nothing to clear
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Brain Dump?'),
        content: const Text(
          'Are you sure you want to clear all text? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearText();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _clearText() {
    setState(() {
      _textController.clear();
    });
    context.read<BrainDumpProvider>().clear();
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Brain Dump?'),
        content: const Text(
          'You have unsaved text. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save Draft'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveDraft();
      return true; // Allow exit after saving
    } else if (result == 'discard') {
      return true; // Allow exit
    }
    return false; // Stay on screen (cancel)
  }

  Future<void> _saveDraft() async {
    final provider = context.read<BrainDumpProvider>();
    await provider.saveDraft(_textController.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved')),
      );
    }
  }
}
