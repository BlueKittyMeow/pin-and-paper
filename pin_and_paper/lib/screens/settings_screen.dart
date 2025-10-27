import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final SettingsService _settingsService = SettingsService();

  bool _obscureKey = true;
  bool _isTesting = false;
  bool? _connectionValid; // null=unknown, true=valid, false=invalid
  String? _connectionMessage;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _settingsService.getApiKey();
    if (apiKey != null && mounted) {
      setState(() {
        _apiKeyController.text = apiKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claude AI',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // API Key Input
            TextField(
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-ant-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              obscureText: _obscureKey,
              controller: _apiKeyController,
              onChanged: (_) {
                // Reset connection status when key changes
                setState(() {
                  _connectionValid = null;
                  _connectionMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Connection Status Indicator
            if (_connectionValid != null)
              Row(
                children: [
                  Icon(
                    _connectionValid! ? Icons.check_circle : Icons.error,
                    color: _connectionValid! ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionMessage ?? (_connectionValid! ? 'Connected' : 'Connection failed'),
                      style: TextStyle(
                        color: _connectionValid! ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _saveApiKey,
                  child: const Text('Save API Key'),
                ),
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                ),
                TextButton(
                  onPressed: _deleteApiKey,
                  child: const Text(
                    'Delete API Key',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Help Text
            const Text(
              'Get your API key from console.anthropic.com',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              r'💡 Tip: Claude API costs ~$0.01 per brain dump',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _connectionValid = false;
        _connectionMessage = 'Please enter an API key first';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _connectionValid = null;
    });

    try {
      final (success, errorMessage) = await _settingsService.testApiKey(apiKey);

      if (mounted) {
        setState(() {
          _connectionValid = success;
          _connectionMessage = errorMessage ?? 'Connected successfully!';
          _isTesting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionValid = false;
          _connectionMessage = 'Test failed: $e';
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      _showSnackBar('Please enter an API key', isError: true);
      return;
    }

    try {
      final provider = context.read<SettingsProvider>();
      await provider.saveApiKey(apiKey);

      if (mounted) {
        _showSnackBar('API key saved successfully!');
        // Optionally run a test after saving
        await _testConnection();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save: $e', isError: true);
      }
    }
  }

  Future<void> _deleteApiKey() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key?'),
        content: const Text('Are you sure you want to delete your Claude API key?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = context.read<SettingsProvider>();
        await provider.deleteApiKey();

        if (mounted) {
          setState(() {
            _apiKeyController.clear();
            _connectionValid = null;
            _connectionMessage = null;
          });
          _showSnackBar('API key deleted');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Failed to delete: $e', isError: true);
        }
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
