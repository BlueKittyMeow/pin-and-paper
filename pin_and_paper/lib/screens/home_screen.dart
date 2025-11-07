import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_input.dart';
import '../widgets/task_item.dart';
import 'brain_dump_screen.dart'; // Phase 2
import 'settings_screen.dart'; // Phase 2
import 'quick_complete_screen.dart'; // Phase 2 Stretch

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load tasks when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin and Paper'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          // Phase 2: Brain Dump button
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Brain Dump',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrainDumpScreen()),
              );
            },
          ),
          // Phase 2: Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const TaskInput(),
          Expanded(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                if (taskProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (taskProvider.errorMessage != null) {
                  return Center(
                    child: Text(
                      taskProvider.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }

                // Phase 2 Stretch: Check if there are any visible tasks
                final hasActiveTasks = taskProvider.activeTasks.isNotEmpty;
                final hasRecentlyCompleted = taskProvider.recentlyCompletedTasks.isNotEmpty;

                if (!hasActiveTasks && !hasRecentlyCompleted) {
                  return Center(
                    child: Text(
                      'No tasks yet.\nAdd one above!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  );
                }

                // Phase 2 Stretch: Render active tasks + separator + recently completed tasks
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Active tasks (normal opacity, no strikethrough)
                    ...taskProvider.activeTasks.map((task) => TaskItem(task: task)),

                    // Separator and recently completed tasks
                    if (hasRecentlyCompleted) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 16.0,
                        ),
                        child: Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                'Recently Completed',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      // Recently completed tasks (reduced opacity + strikethrough)
                      ...taskProvider.recentlyCompletedTasks.map(
                        (task) => Opacity(
                          opacity: 0.5,
                          child: TaskItem(task: task),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuickCompleteScreen()),
          );
        },
        icon: const Icon(Icons.bolt),
        label: const Text('Quick Complete'),
        tooltip: 'Complete a task naturally',
      ),
    );
  }
}
