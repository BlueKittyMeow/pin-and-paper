import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/badge.dart'; // Phase 3.9
import '../models/user_settings.dart'; // Phase 3.8: For Value<T> in copyWith
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/settings_service.dart';
import '../services/api_usage_service.dart';
import '../services/database_service.dart';
import '../services/date_parsing_service.dart'; // Phase 3.9
import '../services/notification_service.dart'; // Phase 3.8
import '../services/quiz_service.dart'; // Phase 3.9
import '../services/user_settings_service.dart'; // Phase 3.8
import '../services/reminder_service.dart'; // Phase 3.8
import '../utils/badge_definitions.dart'; // Phase 3.9
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../widgets/permission_explanation_dialog.dart'; // Phase 3.8
import '../widgets/settings/settings_explanation_dialog.dart'; // Phase 3.9
import '../widgets/settings/time_keyword_picker.dart'; // Phase 3.9
import 'quiz_screen.dart'; // Phase 3.9
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
  bool _notificationsEnabled = true;
  bool _notifyWhenOverdue = true;
  bool _quietHoursEnabled = false;
  int _quietHoursStart = 1320; // 22:00 in minutes
  int _quietHoursEnd = 420; // 07:00 in minutes
  Set<int> _quietHoursDays = {0, 1, 2, 3, 4, 5, 6}; // All days
  Set<String> _defaultReminderTypes = {'at_time'};

  // Phase 3.9: Time & Schedule settings state
  int _todayCutoffHour = 4;
  int _todayCutoffMinute = 59;
  int _weekStartDay = 1; // 0=Sunday, 1=Monday
  bool _use24HourTime = false;

  // Phase 3.9: Date Parsing settings state
  bool _enableQuickAddDateParsing = true;
  int _earlyMorningHour = 5;
  int _morningHour = 9;
  int _noonHour = 12;
  int _afternoonHour = 15;
  int _tonightHour = 19;
  int _lateNightHour = 22;

  // Phase 3.9: Task Behavior state
  String _autoCompleteChildren = 'prompt';

  // Phase 3.9: Quiz personality state
  List<Badge> _earnedBadges = [];
  bool _quizCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _usageStatsFuture = _apiUsageService.getStats();
    _loadNotificationSettings(); // Phase 3.8
    _loadTimeAndPreferenceSettings(); // Phase 3.9
    _loadQuizStatus(); // Phase 3.9
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
                    color: _connectionValid! ? AppTheme.success : AppTheme.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionMessage ?? (_connectionValid! ? 'Connected' : 'Connection failed'),
                      style: TextStyle(
                        color: _connectionValid! ? AppTheme.success : AppTheme.danger,
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
                    style: TextStyle(color: AppTheme.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Help Text
            const Text(
              'Get your API key from console.anthropic.com',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
            const Text(
              r'💡 Tip: Claude API costs ~$0.01 per brain dump',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
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
                            style: TextStyle(fontSize: 12, color: AppTheme.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Phase 3.9: Your Time Personality Section
            Text(
              'Your Time Personality',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_earnedBadges.isEmpty && !_quizCompleted)
                      ListTile(
                        leading: const Icon(Icons.psychology_outlined,
                            color: AppTheme.mutedLavender),
                        title: const Text('Take the Onboarding Quiz'),
                        subtitle: const Text(
                            'Discover your time personality and configure preferences'),
                        trailing: const Icon(Icons.chevron_right),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _navigateToQuiz(isRetake: false),
                      )
                    else ...[
                      if (_earnedBadges.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _earnedBadges.map((badge) {
                            return Chip(
                              avatar: Icon(
                                _badgeCategoryIcon(badge.category),
                                size: 18,
                                color: _badgeCategoryColor(badge.category),
                              ),
                              label: Text(
                                badge.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              backgroundColor:
                                  AppTheme.kraftPaper.withValues(alpha: 0.4),
                              side: BorderSide.none,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_quizCompleted)
                        ListTile(
                          leading: const Icon(Icons.info_outline,
                              color: AppTheme.info),
                          title: const Text('Explain My Settings'),
                          subtitle: const Text(
                              'See how quiz answers shaped your preferences'),
                          trailing: const Icon(Icons.chevron_right),
                          contentPadding: EdgeInsets.zero,
                          onTap: () => SettingsExplanationDialog.show(context),
                        ),
                      ListTile(
                        leading: const Icon(Icons.refresh_rounded,
                            color: AppTheme.muted),
                        title: const Text('Retake Quiz'),
                        subtitle: const Text(
                            'Update your settings with new answers'),
                        trailing: const Icon(Icons.chevron_right),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _navigateToQuiz(isRetake: true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Phase 3.9: Time & Schedule Section
            Text(
              'Time & Schedule',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day cutoff time
                    ListTile(
                      title: const Text('My day ends at'),
                      subtitle: Text(
                        _formatCutoffTime(),
                        style: const TextStyle(
                          color: AppTheme.deepShadow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.access_time_rounded),
                      contentPadding: EdgeInsets.zero,
                      onTap: _pickCutoffTime,
                    ),
                    const Text(
                      'Tasks created after this time count as "tomorrow"',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                    const Divider(height: 24),

                    // Week start day
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Week starts on',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                        DropdownButton<int>(
                          value: _weekStartDay,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Sunday')),
                            DropdownMenuItem(value: 1, child: Text('Monday')),
                            DropdownMenuItem(value: 6, child: Text('Saturday')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _weekStartDay = value);
                              _updateTimeSettings();
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // 24-hour time toggle
                    SwitchListTile(
                      title: const Text('24-hour time'),
                      subtitle: Text(
                        _use24HourTime ? '14:00' : '2:00 PM',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      value: _use24HourTime,
                      onChanged: (value) {
                        setState(() => _use24HourTime = value);
                        _updateTimeSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Phase 3.9: Date Parsing Section
            Text(
              'Date Parsing',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Quick Add date parsing'),
                      subtitle: const Text(
                          'Parse dates from task titles (e.g., "tomorrow", "Friday")'),
                      value: _enableQuickAddDateParsing,
                      onChanged: (value) {
                        setState(() => _enableQuickAddDateParsing = value);
                        _updateTimeSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 24),

                    // Time keyword header
                    const Text(
                      'Time Keywords',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'What time do these words mean to you?',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 12),

                    TimeKeywordPicker(
                      label: 'Early Morning',
                      description: '"early morning" / "dawn"',
                      currentHour: _earlyMorningHour,
                      onHourChanged: (hour) {
                        setState(() => _earlyMorningHour = hour);
                        _updateTimeSettings();
                      },
                    ),
                    TimeKeywordPicker(
                      label: 'Morning',
                      description: '"morning" / "this morning"',
                      currentHour: _morningHour,
                      onHourChanged: (hour) {
                        setState(() => _morningHour = hour);
                        _updateTimeSettings();
                      },
                    ),
                    TimeKeywordPicker(
                      label: 'Noon',
                      description: '"noon" / "midday" / "lunch"',
                      currentHour: _noonHour,
                      onHourChanged: (hour) {
                        setState(() => _noonHour = hour);
                        _updateTimeSettings();
                      },
                    ),
                    TimeKeywordPicker(
                      label: 'Afternoon',
                      description: '"afternoon" / "this afternoon"',
                      currentHour: _afternoonHour,
                      onHourChanged: (hour) {
                        setState(() => _afternoonHour = hour);
                        _updateTimeSettings();
                      },
                    ),
                    TimeKeywordPicker(
                      label: 'Tonight',
                      description: '"tonight" / "evening"',
                      currentHour: _tonightHour,
                      onHourChanged: (hour) {
                        setState(() => _tonightHour = hour);
                        _updateTimeSettings();
                      },
                    ),
                    TimeKeywordPicker(
                      label: 'Late Night',
                      description: '"late night" / "late"',
                      currentHour: _lateNightHour,
                      onHourChanged: (hour) {
                        setState(() => _lateNightHour = hour);
                        _updateTimeSettings();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Phase 3.9: Task Behavior Section
            Text(
              'Task Behavior',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'When completing a parent task:',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text('Ask me each time'),
                      subtitle: const Text(
                          'Prompt before completing subtasks'),
                      value: 'prompt',
                      groupValue: _autoCompleteChildren,
                      onChanged: (value) {
                        setState(() => _autoCompleteChildren = value!);
                        _updateTimeSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: const Text('Always complete subtasks'),
                      subtitle: const Text(
                          'Automatically mark all children as done'),
                      value: 'always',
                      groupValue: _autoCompleteChildren,
                      onChanged: (value) {
                        setState(() => _autoCompleteChildren = value!);
                        _updateTimeSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: const Text('Never complete subtasks'),
                      subtitle: const Text(
                          'Leave children unchanged'),
                      value: 'never',
                      groupValue: _autoCompleteChildren,
                      onChanged: (value) {
                        setState(() => _autoCompleteChildren = value!);
                        _updateTimeSettings();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
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
                    // Master notifications toggle
                    SwitchListTile(
                      secondary: Icon(
                        _notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: _notificationsEnabled ? AppTheme.success : AppTheme.danger,
                      ),
                      title: Text(_notificationsEnabled
                          ? 'Notifications enabled'
                          : 'Notifications disabled'),
                      value: _notificationsEnabled,
                      onChanged: (value) async {
                        if (value) {
                          // Request permission before enabling
                          final granted =
                              await PermissionExplanationDialog.show(context);
                          if (granted) {
                            setState(() => _notificationsEnabled = true);
                            _updateNotificationSettings();
                          }
                          // If denied, toggle stays off
                        } else {
                          setState(() => _notificationsEnabled = false);
                          _updateNotificationSettings();
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (_notificationsEnabled) ...[
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
                    ], // end if (_notificationsEnabled)
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
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: AppTheme.creamPaper,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right),
                          ],
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
                        style: const TextStyle(color: AppTheme.danger),
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
                                backgroundColor: AppTheme.danger,
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
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
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
        backgroundColor: isError ? AppTheme.danger : null,
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
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
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
        _notificationsEnabled = settings.notificationsEnabled;
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
        notificationsEnabled: _notificationsEnabled,
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

  // ========== Phase 3.9: Time & Preference Settings ==========

  Future<void> _loadTimeAndPreferenceSettings() async {
    try {
      final settings = await _userSettingsService.getUserSettings();
      if (!mounted) return;
      setState(() {
        _todayCutoffHour = settings.todayCutoffHour;
        _todayCutoffMinute = settings.todayCutoffMinute;
        _weekStartDay = settings.weekStartDay;
        _use24HourTime = settings.use24HourTime;
        _enableQuickAddDateParsing = settings.enableQuickAddDateParsing;
        _earlyMorningHour = settings.earlyMorningHour;
        _morningHour = settings.morningHour;
        _noonHour = settings.noonHour;
        _afternoonHour = settings.afternoonHour;
        _tonightHour = settings.tonightHour;
        _lateNightHour = settings.lateNightHour;
        _autoCompleteChildren = settings.autoCompleteChildren;
      });
    } catch (e) {
      debugPrint('[SettingsScreen] Failed to load time settings: $e');
    }
  }

  Future<void> _loadQuizStatus() async {
    try {
      final quizService = QuizService();
      final completed = await quizService.hasCompletedOnboardingQuiz();
      if (!completed || !mounted) {
        if (mounted) setState(() => _quizCompleted = completed);
        return;
      }

      final badgeIds = await quizService.getEarnedBadgeIds();
      if (!mounted) return;

      final badges = <Badge>[];
      if (badgeIds != null) {
        for (final id in badgeIds) {
          final badge = BadgeDefinitions.getBadgeById(id);
          if (badge != null) badges.add(badge);
        }
      }

      setState(() {
        _quizCompleted = true;
        _earnedBadges = badges;
      });
    } catch (e) {
      debugPrint('[SettingsScreen] Failed to load quiz status: $e');
    }
  }

  Future<void> _updateTimeSettings() async {
    try {
      final settings = await _userSettingsService.getUserSettings();
      final updated = settings.copyWith(
        todayCutoffHour: _todayCutoffHour,
        todayCutoffMinute: _todayCutoffMinute,
        weekStartDay: _weekStartDay,
        use24HourTime: _use24HourTime,
        enableQuickAddDateParsing: _enableQuickAddDateParsing,
        earlyMorningHour: _earlyMorningHour,
        morningHour: _morningHour,
        noonHour: _noonHour,
        afternoonHour: _afternoonHour,
        tonightHour: _tonightHour,
        lateNightHour: _lateNightHour,
        autoCompleteChildren: _autoCompleteChildren,
      );
      await _userSettingsService.updateUserSettings(updated);
      // Phase 3.9: Reload DateParsingService settings
      await DateParsingService().loadSettings();
    } catch (e) {
      debugPrint('[SettingsScreen] Failed to update time settings: $e');
    }
  }

  Future<void> _pickCutoffTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _todayCutoffHour, minute: _todayCutoffMinute),
      helpText: 'When does your day end?',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.creamPaper,
              dialHandColor: AppTheme.deepShadow,
              hourMinuteColor: AppTheme.kraftPaper,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _todayCutoffHour = picked.hour;
      _todayCutoffMinute = picked.minute;
    });
    _updateTimeSettings();
  }

  String _formatCutoffTime() {
    if (_use24HourTime) {
      return '${_todayCutoffHour.toString().padLeft(2, '0')}:${_todayCutoffMinute.toString().padLeft(2, '0')}';
    }
    final period = _todayCutoffHour >= 12 ? 'PM' : 'AM';
    final displayHour = _todayCutoffHour == 0
        ? 12
        : (_todayCutoffHour > 12 ? _todayCutoffHour - 12 : _todayCutoffHour);
    return '$displayHour:${_todayCutoffMinute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _navigateToQuiz({required bool isRetake}) async {
    if (isRetake) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.creamPaper,
          title: const Text('Retake Quiz?'),
          content: const Text(
            'This will update your settings based on your new answers. '
            'Your current settings will be overwritten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepShadow,
                foregroundColor: AppTheme.creamPaper,
              ),
              child: const Text('Retake'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(isRetake: isRetake)),
    );

    // Reload settings and quiz status after returning
    if (mounted) {
      _loadTimeAndPreferenceSettings();
      _loadQuizStatus();
    }
  }

  Color _badgeCategoryColor(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.circadianRhythm:
        return AppTheme.info;
      case BadgeCategory.weekStructure:
        return AppTheme.softSage;
      case BadgeCategory.dailyRhythm:
        return AppTheme.warning;
      case BadgeCategory.displayPreference:
        return AppTheme.mutedLavender;
      case BadgeCategory.taskManagement:
        return AppTheme.success;
      case BadgeCategory.combo:
        return AppTheme.mutedLavender;
    }
  }

  IconData _badgeCategoryIcon(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.circadianRhythm:
        return Icons.nightlight_round;
      case BadgeCategory.weekStructure:
        return Icons.calendar_today;
      case BadgeCategory.dailyRhythm:
        return Icons.wb_sunny;
      case BadgeCategory.displayPreference:
        return Icons.schedule;
      case BadgeCategory.taskManagement:
        return Icons.task_alt;
      case BadgeCategory.combo:
        return Icons.stars;
    }
  }
}
