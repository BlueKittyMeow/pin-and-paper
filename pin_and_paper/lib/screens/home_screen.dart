import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';
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
          // Phase 3.2: Reorder mode toggle
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              return IconButton(
                icon: Icon(
                  taskProvider.isReorderMode ? Icons.check : Icons.reorder,
                ),
                tooltip: taskProvider.isReorderMode ? 'Done' : 'Reorder Tasks',
                onPressed: () {
                  taskProvider.setReorderMode(!taskProvider.isReorderMode);
                },
              );
            },
          ),
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

                // Phase 3.2: Check if there are any root tasks
                if (taskProvider.treeController.roots.isEmpty) {
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

                // Phase 3.2: Hierarchical tree view using AnimatedTreeView
                return AnimatedTreeView<Task>(
                  treeController: taskProvider.treeController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  nodeBuilder: (context, TreeEntry<Task> entry) {
                    return TaskItem(
                      key: ValueKey(entry.node.id),
                      task: entry.node,
                      depth: entry.node.depth,
                      hasChildren: entry.hasChildren,
                      isExpanded: entry.isExpanded,
                      onToggleCollapse: () => taskProvider.toggleCollapse(entry.node),
                      isReorderMode: taskProvider.isReorderMode,
                    );
                  },
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
