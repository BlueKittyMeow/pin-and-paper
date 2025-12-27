import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/task_provider.dart';
import 'providers/settings_provider.dart'; // Phase 2
import 'providers/brain_dump_provider.dart'; // Phase 2
import 'screens/home_screen.dart';
import 'services/task_service.dart'; // Phase 3.3
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

  runApp(const PinAndPaperApp());
}

class PinAndPaperApp extends StatelessWidget {
  const PinAndPaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Phase 2: MultiProvider for multiple state management
    // Order matters: SettingsProvider must be created before BrainDumpProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadPreferences()),
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
