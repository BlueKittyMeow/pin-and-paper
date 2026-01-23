import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/settings_service.dart';
import '../services/api_usage_service.dart';
import '../services/database_service.dart';
import '../models/user_settings.dart'; // Phase 3.8: For Value<T> in copyWith
import '../services/notification_service.dart'; // Phase 3.8
import '../services/user_settings_service.dart'; // Phase 3.8
import '../services/reminder_service.dart'; // Phase 3.8
import '../utils/constants.dart';
import '../widgets/permission_explanation_dialog.dart'; // Phase 3.8
import 'recently_deleted_screen.dart'; // Phase 3.3

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

  // Bug fix: Cache usage stats future to prevent re-running query on every rebuild
  late Future<UsageStats> _usageStatsFuture;

  // Phase 3.8: Notification settings state
  final UserSettingsService _userSettingsService = UserSettingsService();
  bool _notifyWhenOverdue = true;
  bool _quietHoursEnabled = false;
  int _quietHoursStart = 1320; // 22:00 in minutes
  int _quietHoursEnd = 420; // 07:00 in minutes
  Set<int> _quietHoursDays = {0, 1, 2, 3, 4, 5, 6}; // All days
  Set<String> _defaultReminderTypes = {'at_time'};

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _usageStatsFuture = _apiUsageService.getStats();
    _loadNotificationSettings(); // Phase 3.8
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
                            initialValue: taskProvider.hideThresholdHours,
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

            // Phase 3.8: Notifications Section
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Permission status
                    FutureBuilder<bool>(
                      future: NotificationService().isPermissionGranted(),
                      builder: (context, snapshot) {
                        final granted = snapshot.data ?? false;
                        return ListTile(
                          leading: Icon(
                            granted
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            color: granted ? Colors.green : Colors.red,
                          ),
                          title: Text(granted
                              ? 'Notifications enabled'
                              : 'Notifications disabled'),
                          trailing: granted
                              ? null
                              : TextButton(
                                  onPressed: () async {
                                    await PermissionExplanationDialog.show(
                                        context);
                                    setState(() {}); // Refresh status
                                  },
                                  child: const Text('Enable'),
                                ),
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    ),

                    const Divider(),

                    // Default reminder timing
                    Text('Default reminders',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildDefaultReminderChip('at_time', 'At due time'),
                        _buildDefaultReminderChip('before_1h', '1 hour before'),
                        _buildDefaultReminderChip('before_1d', '1 day before'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Notify when overdue (global)
                    SwitchListTile(
                      title: const Text('Notify when overdue'),
                      subtitle: const Text(
                          'Get reminded when tasks pass their due date'),
                      value: _notifyWhenOverdue,
                      onChanged: (value) {
                        setState(() => _notifyWhenOverdue = value);
                        _updateNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Divider(),

                    // Quiet hours
                    SwitchListTile(
                      title: const Text('Quiet hours'),
                      subtitle: const Text(
                          'Delay notifications during set times'),
                      value: _quietHoursEnabled,
                      onChanged: (value) {
                        setState(() => _quietHoursEnabled = value);
                        _updateNotificationSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (_quietHoursEnabled) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Start'),
                              subtitle: Text(
                                  _formatMinutesFromMidnight(_quietHoursStart)),
                              onTap: () =>
                                  _pickQuietHoursTime(isStart: true),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('End'),
                              subtitle: Text(
                                  _formatMinutesFromMidnight(_quietHoursEnd)),
                              onTap: () =>
                                  _pickQuietHoursTime(isStart: false),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 4,
                        children: List.generate(7, (i) => _buildDayChip(i)),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Test notification button
                    OutlinedButton.icon(
                      onPressed: () async {
                        await NotificationService().showImmediate(
                          id: 0,
                          title: 'Test Notification',
                          body:
                              'Pin and Paper notifications are working!',
                        );
                      },
                      icon: const Icon(Icons.notifications_none, size: 18),
                      label: const Text('Send Test Notification'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Data Management Section (Phase 3.3)
            Text(
              'Data Management',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.restore_from_trash,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Recently Deleted'),
                    subtitle: const Text('View and restore deleted tasks'),
                    trailing: FutureBuilder<int>(
                      future: context.read<TaskProvider>().getRecentlyDeletedCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: const Icon(Icons.chevron_right),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecentlyDeletedScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // API Usage & Costs Section
            Text(
              'API Usage & Costs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            FutureBuilder<UsageStats>(
              future: _usageStatsFuture,
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
            const SizedBox(height: 32),

            // App Info Section
            Text(
              'App Info',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final info = snapshot.data!;
                final dbVersion = AppConstants.databaseVersion;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatRow(
                          'Version:',
                          'v${info.version}',
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow(
                          'Build:',
                          '#${info.buildNumber}',
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow(
                          'Database:',
                          'v$dbVersion',
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _copyDebugInfo(info, dbVersion),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Debug Info'),
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
          // Recompute future to refresh stats UI with cleared data
          _usageStatsFuture = _apiUsageService.getStats();
        });
        _showSnackBar('Usage data reset successfully');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to reset usage data: $e', isError: true);
      }
    }
  }

  Future<void> _copyDebugInfo(PackageInfo info, int dbVersion) async {
    final debugInfo = '''
Pin and Paper Debug Info
========================
App Version: ${info.version}
Build Number: ${info.buildNumber}
Database Version: $dbVersion
Package Name: ${info.packageName}
========================
''';

    await Clipboard.setData(ClipboardData(text: debugInfo));
    if (mounted) {
      _showSnackBar('Debug info copied to clipboard');
    }
  }

  // ========== Phase 3.8: Notification Settings ==========

  Future<void> _loadNotificationSettings() async {
    try {
      final settings = await _userSettingsService.getUserSettings();
      if (!mounted) return;
      setState(() {
        _notifyWhenOverdue = settings.notifyWhenOverdue;
        _quietHoursEnabled = settings.quietHoursEnabled;
        _quietHoursStart = settings.quietHoursStart ?? 1320;
        _quietHoursEnd = settings.quietHoursEnd ?? 420;
        _quietHoursDays = settings.quietHoursDays
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toSet();
        _defaultReminderTypes = settings.defaultReminderTypes
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toSet();
      });
    } catch (e) {
      debugPrint('[SettingsScreen] Failed to load notification settings: $e');
    }
  }

  Future<void> _updateNotificationSettings() async {
    try {
      final settings = await _userSettingsService.getUserSettings();
      final updated = settings.copyWith(
        notifyWhenOverdue: _notifyWhenOverdue,
        quietHoursEnabled: _quietHoursEnabled,
        quietHoursStart: Value(_quietHoursStart),
        quietHoursEnd: Value(_quietHoursEnd),
        quietHoursDays: _quietHoursDays.join(','),
        defaultReminderTypes: _defaultReminderTypes.join(','),
      );
      await _userSettingsService.updateUserSettings(updated);
      // Reschedule all notifications with new settings
      await ReminderService().rescheduleAll();
    } catch (e) {
      debugPrint('[SettingsScreen] Failed to update notification settings: $e');
    }
  }

  Future<void> _pickQuietHoursTime({required bool isStart}) async {
    final currentMinutes = isStart ? _quietHoursStart : _quietHoursEnd;
    final initial = TimeOfDay(
      hour: currentMinutes ~/ 60,
      minute: currentMinutes % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (isStart) {
        _quietHoursStart = minutes;
      } else {
        _quietHoursEnd = minutes;
      }
    });
    _updateNotificationSettings();
  }

  String _formatMinutesFromMidnight(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildDefaultReminderChip(String type, String label) {
    final selected = _defaultReminderTypes.contains(type);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _defaultReminderTypes.add(type);
          } else {
            _defaultReminderTypes.remove(type);
          }
        });
        _updateNotificationSettings();
      },
    );
  }

  Widget _buildDayChip(int dayIndex) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final selected = _quietHoursDays.contains(dayIndex);
    return FilterChip(
      label: Text(dayLabels[dayIndex]),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _quietHoursDays.add(dayIndex);
          } else {
            _quietHoursDays.remove(dayIndex);
          }
        });
        _updateNotificationSettings();
      },
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}
