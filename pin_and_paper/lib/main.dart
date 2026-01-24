import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/task_provider.dart';
import 'providers/tag_provider.dart'; // Phase 3.5
import 'providers/task_sort_provider.dart'; // Phase 3.9 Refactor
import 'providers/settings_provider.dart'; // Phase 2
import 'providers/brain_dump_provider.dart'; // Phase 2
import 'screens/home_screen.dart';
import 'services/task_service.dart'; // Phase 3.3
import 'services/date_parsing_service.dart'; // Phase 3.7
import 'services/notification_service.dart'; // Phase 3.8
import 'services/reminder_service.dart'; // Phase 3.8.4
import 'utils/theme.dart';

void main() async {
  // Initialize sqflite_ffi for desktop platforms (Linux, Windows, macOS)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Phase 3.3: Ensure Flutter binding is initialized for async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 3.3: Clean up tasks deleted more than 30 days ago (automatic maintenance)
  try {
    final taskService = TaskService();
    final deletedCount = await taskService.cleanupExpiredDeletedTasks();
    if (deletedCount > 0) {
      print('[Maintenance] Permanently deleted $deletedCount expired task(s)');
    }
  } catch (e) {
    print('[Maintenance] Failed to cleanup expired tasks: $e');
    // Don't block app startup on cleanup failure
  }

  // Phase 3.7: Initialize date parsing service
  try {
    final dateParser = DateParsingService();
    await dateParser.initialize();
  } catch (e) {
    print('[Phase 3.7] Failed to initialize DateParsingService: $e');
    // Don't block app startup on date parsing initialization failure
  }

  // Phase 3.8: Initialize notification service (timezone + plugin)
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Phase 3.8.4: Check for missed notifications on app start
    try {
      await ReminderService().checkMissed();
    } catch (e) {
      print('[Phase 3.8] Failed to check missed notifications: $e');
    }
  } catch (e) {
    print('[Phase 3.8] Failed to initialize NotificationService: $e');
    // Don't block app startup on notification initialization failure
  }

  runApp(const PinAndPaperApp());
}

class PinAndPaperApp extends StatelessWidget {
  const PinAndPaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Phase 2: MultiProvider for multiple state management
    // Phase 3.5: Added TagProvider for tag management
    // Phase 3.6A: TaskProvider now depends on TagProvider (for filter validation)
    // Phase 3.9 Refactor: Added TaskSortProvider, TaskProvider depends on both
    // Order matters: TagProvider and TaskSortProvider must be created before TaskProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TagProvider()), // Phase 3.5
        ChangeNotifierProvider(create: (_) => TaskSortProvider()..loadPreferences()), // Phase 3.9 Refactor
        ChangeNotifierProxyProvider2<TagProvider, TaskSortProvider, TaskProvider>(
          create: (context) => TaskProvider(
            tagProvider: Provider.of<TagProvider>(context, listen: false),
            sortProvider: Provider.of<TaskSortProvider>(context, listen: false),
          )..loadPreferences(),
          update: (context, tagProvider, sortProvider, previous) =>
              previous ?? TaskProvider(
                tagProvider: tagProvider,
                sortProvider: sortProvider,
              )..loadPreferences(),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProxyProvider<SettingsProvider, BrainDumpProvider>(
          create: (context) => BrainDumpProvider(
            Provider.of<SettingsProvider>(context, listen: false),
          ),
          update: (context, settings, previous) =>
              previous ?? BrainDumpProvider(settings),
        ),
      ],
      child: MaterialApp(
        title: 'Pin and Paper',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
