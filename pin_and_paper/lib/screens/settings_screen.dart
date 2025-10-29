import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/settings_service.dart';
import '../services/api_usage_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final SettingsService _settingsService = SettingsService();
  final ApiUsageService _apiUsageService = ApiUsageService();

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
      body: SingleChildScrollView(
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
            const SizedBox(height: 32),

            // Task Display Section
            Text(
              'Task Display',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: const Text('Hide old completed tasks'),
                          subtitle: const Text('Show only recently completed tasks'),
                          value: taskProvider.hideOldCompleted,
                          onChanged: (value) {
                            taskProvider.setHideOldCompleted(value);
                          },
                        ),
                        if (taskProvider.hideOldCompleted) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Hide tasks marked as completed after:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: taskProvider.hideThresholdHours,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 6, child: Text('6 hours')),
                              DropdownMenuItem(value: 12, child: Text('12 hours')),
                              DropdownMenuItem(value: 24, child: Text('24 hours')),
                              DropdownMenuItem(value: 72, child: Text('3 days')),
                              DropdownMenuItem(value: 168, child: Text('1 week')),
                              DropdownMenuItem(value: 999999, child: Text('Never')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                taskProvider.setHideThresholdHours(value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'You can always view previously completed tasks by turning off this toggle. Coming soon: view these in your journal!',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // API Usage & Costs Section
            Text(
              'API Usage & Costs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            FutureBuilder<UsageStats>(
              future: _apiUsageService.getStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading usage data: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final stats = snapshot.data!;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatRow(
                          'Total Spent (est.):',
                          '\$${stats.totalCost.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow(
                          'This Month:',
                          '\$${stats.monthCost.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow(
                          'Brain Dumps:',
                          '${stats.totalCalls}',
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow(
                          'Avg Cost:',
                          '\$${stats.averageCostPerCall.toStringAsFixed(3)}/dump',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _showComingSoonSnackBar,
                                child: const Text('View Detailed Usage'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _showResetDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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

  void _showComingSoonSnackBar() {
    _showSnackBar('Coming soon');
  }

  Future<void> _showResetDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Usage Data?'),
        content: const Text(
          'This will permanently delete all API usage tracking data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _resetUsageData();
    }
  }

  Future<void> _resetUsageData() async {
    try {
      final db = await DatabaseService.instance.database;
      await db.delete(AppConstants.apiUsageLogTable);

      if (mounted) {
        setState(() {
          // Trigger rebuild to refresh the stats
        });
        _showSnackBar('Usage data reset successfully');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to reset usage data: $e', isError: true);
      }
    }
  }
}
