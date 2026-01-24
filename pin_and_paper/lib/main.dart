import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/task_provider.dart';
import 'providers/tag_provider.dart'; // Phase 3.5
import 'providers/task_sort_provider.dart'; // Phase 3.9 Refactor
import 'providers/task_filter_provider.dart'; // Phase 3.9 Refactor
import 'providers/task_hierarchy_provider.dart'; // Phase 3.9 Refactor
import 'providers/settings_provider.dart'; // Phase 2
import 'providers/brain_dump_provider.dart'; // Phase 2
import 'providers/quiz_provider.dart'; // Phase 3.9
import 'screens/home_screen.dart';
import 'screens/quiz_screen.dart'; // Phase 3.9
import 'services/quiz_service.dart'; // Phase 3.9
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
    await dateParser.loadSettings(); // Phase 3.9: Load user preferences
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
    // Phase 3.9 Refactor: Added TaskSortProvider, TaskFilterProvider, TaskHierarchyProvider
    // Order matters: Independent providers first, then dependent providers
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TagProvider()), // Phase 3.5
        ChangeNotifierProvider(create: (_) => TaskSortProvider()..loadPreferences()), // Phase 3.9 Refactor
        ChangeNotifierProvider(create: (_) => TaskHierarchyProvider()), // Phase 3.9 Refactor
        ChangeNotifierProxyProvider<TagProvider, TaskFilterProvider>( // Phase 3.9 Refactor
          create: (context) => TaskFilterProvider(
            tagProvider: Provider.of<TagProvider>(context, listen: false),
          ),
          update: (context, tagProvider, previous) =>
              previous ?? TaskFilterProvider(tagProvider: tagProvider),
        ),
        ChangeNotifierProxyProvider4<TagProvider, TaskSortProvider, TaskFilterProvider, TaskHierarchyProvider, TaskProvider>(
          create: (context) => TaskProvider(
            tagProvider: Provider.of<TagProvider>(context, listen: false),
            sortProvider: Provider.of<TaskSortProvider>(context, listen: false),
            filterProvider: Provider.of<TaskFilterProvider>(context, listen: false),
            hierarchyProvider: Provider.of<TaskHierarchyProvider>(context, listen: false),
          )..loadPreferences(),
          update: (context, tagProvider, sortProvider, filterProvider, hierarchyProvider, previous) =>
              previous ?? TaskProvider(
                tagProvider: tagProvider,
                sortProvider: sortProvider,
                filterProvider: filterProvider,
                hierarchyProvider: hierarchyProvider,
              )..loadPreferences(),
        ),
        ChangeNotifierProvider(create: (_) => QuizProvider()), // Phase 3.9
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
        home: const _LaunchRouter(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Routes to QuizScreen on first launch, HomeScreen otherwise.
class _LaunchRouter extends StatefulWidget {
  const _LaunchRouter();

  @override
  State<_LaunchRouter> createState() => _LaunchRouterState();
}

class _LaunchRouterState extends State<_LaunchRouter> {
  bool _isLoading = true;
  bool _quizCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkQuizStatus();
  }

  Future<void> _checkQuizStatus() async {
    try {
      final quizService = QuizService();
      final completed = await quizService.hasCompletedOnboardingQuiz();
      if (mounted) {
        setState(() {
          _quizCompleted = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, skip quiz and go to home
      if (mounted) {
        setState(() {
          _quizCompleted = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.warmBeige,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.deepShadow,
          ),
        ),
      );
    }

    if (_quizCompleted) {
      return const HomeScreen();
    }

    return const QuizScreen();
  }
}
