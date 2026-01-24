import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/task_sort_provider.dart'; // Phase 3.9 Refactor
import '../providers/task_filter_provider.dart'; // Phase 3.9 Refactor
import '../providers/tag_provider.dart'; // Phase 3.6A
import '../services/tag_service.dart'; // Phase 3.6A
import '../services/notification_service.dart'; // Phase 3.8.4
import '../services/reminder_service.dart'; // Phase 3.8.4
import '../models/task_sort_mode.dart'; // Phase 3.7.5
import '../widgets/task_input.dart';
import '../widgets/task_item.dart';
import '../widgets/live_clock.dart'; // Phase 3.7.5
import '../widgets/drag_and_drop_task_tile.dart'; // Phase 3.2
import '../widgets/active_filter_bar.dart'; // Phase 3.6A
import '../widgets/tag_filter_dialog.dart'; // Phase 3.6A
import '../widgets/search_dialog.dart'; // Phase 3.6B
import '../widgets/snooze_options_sheet.dart'; // Phase 3.8.4
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
      _setupNotificationCallbacks();
      _replayLaunchNotification();
    });
  }

  /// Phase 3.8.4: Set up notification action callbacks
  void _setupNotificationCallbacks() {
    final notificationService = NotificationService();

    notificationService.onNotificationTapped = (taskId) {
      if (taskId != null && mounted) {
        // Scroll to and highlight the task
        final taskProvider = context.read<TaskProvider>();
        taskProvider.navigateToTask(taskId);
      }
    };

    notificationService.onSnoozeRequested = (taskId) {
      if (!mounted) return;
      _showSnoozeSheet(taskId);
    };

    notificationService.onCompleteRequested = (taskId) async {
      try {
        final taskProvider = context.read<TaskProvider>();
        final task = taskProvider.getTaskById(taskId);
        if (task != null && !task.completed) {
          await taskProvider.toggleTaskCompletion(task);
        }
      } catch (e) {
        debugPrint('[HomeScreen] Failed to complete task from notification: $e');
      }
    };

    notificationService.onCancelRequested = (taskId) async {
      try {
        await ReminderService().cancelReminders(taskId);
      } catch (e) {
        debugPrint('[HomeScreen] Failed to cancel reminders: $e');
      }
    };
  }

  /// Phase 3.8.4: Replay notification that launched the app (cold start).
  /// Must be called AFTER callbacks are set up so the response is handled.
  Future<void> _replayLaunchNotification() async {
    try {
      final notificationService = NotificationService();
      final launchResponse = await notificationService.getLaunchNotification();
      if (launchResponse != null) {
        notificationService.handleNotificationResponse(launchResponse);
      }
    } catch (e) {
      debugPrint('[HomeScreen] Failed to replay launch notification: $e');
    }
  }

  /// Phase 3.8.4: Show snooze options and schedule snoozed notification
  Future<void> _showSnoozeSheet(String taskId) async {
    final duration = await SnoozeOptionsSheet.show(context, taskId);
    if (duration == null) return;

    if (duration == Duration.zero) {
      // Custom time picker
      if (!mounted) return;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked == null) return;

      // Calculate duration from now to picked time (today or tomorrow if past)
      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      final customDuration = target.difference(now);
      await ReminderService().snooze(taskId, customDuration);
    } else {
      await ReminderService().snooze(taskId, duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LiveClock(),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          // Phase 3.6B: Search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Tasks',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SearchDialog(),
              );
            },
          ),
          // Phase 3.6B: Expand/Collapse all button
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              final allExpanded = taskProvider.areAllExpanded;
              return IconButton(
                icon: Icon(
                  allExpanded ? Icons.unfold_less : Icons.unfold_more,
                ),
                tooltip: allExpanded ? 'Collapse All' : 'Expand All',
                onPressed: () {
                  if (allExpanded) {
                    taskProvider.collapseAll();
                  } else {
                    taskProvider.expandAll();
                  }
                },
              );
            },
          ),
          // Phase 3.6A: Filter button
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              final hasActiveFilters = taskProvider.hasActiveFilters;
              return IconButton(
                icon: Icon(
                  hasActiveFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                ),
                tooltip: 'Filter Tasks',
                onPressed: () => _showFilterDialog(context),
              );
            },
          ),
          // Phase 3.7.5: Sort button
          // Phase 3.9 Refactor: Now uses TaskSortProvider instead of TaskProvider
          Consumer<TaskSortProvider>(
            builder: (context, sortProvider, _) {
              final isActive = sortProvider.sortMode != TaskSortMode.manual;
              return PopupMenuButton<TaskSortMode>(
                icon: Icon(
                  Icons.sort,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Sort Tasks',
                onSelected: (mode) {
                  if (mode == sortProvider.sortMode) {
                    sortProvider.toggleSortReversed();
                  } else {
                    sortProvider.setSortMode(mode);
                  }
                },
                itemBuilder: (context) => TaskSortMode.values.map((mode) {
                  final isSelected = mode == sortProvider.sortMode;
                  return PopupMenuItem<TaskSortMode>(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(
                          mode.icon,
                          size: 20,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mode.displayName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            sortProvider.sortReversed
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
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
          // Phase 3.6A / Phase 3.9 Refactor: Active filter bar now uses TaskFilterProvider
          Consumer2<TaskFilterProvider, TagProvider>(
            builder: (context, filterProvider, tagProvider, _) {
              return ActiveFilterBar(
                filterState: filterProvider.filterState,
                allTags: tagProvider.tags,
                onClearAll: () => filterProvider.clearFilters(),
                onRemoveTag: (tagId) => filterProvider.removeTagFilter(tagId),
              );
            },
          ),
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

                // Phase 3.2: Check if there are any tasks at all
                final hasActiveTasks = taskProvider.treeController.roots.isNotEmpty;
                final completedTasks = taskProvider.visibleCompletedTasks;
                final hasRecentlyCompleted = completedTasks.isNotEmpty;

                // Phase 3.6.5 Fix: Only show "No tasks yet" if tasks list is truly empty
                // This prevents brief flash of empty state during completion transitions
                if (!hasActiveTasks && !hasRecentlyCompleted && taskProvider.tasks.isEmpty) {
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

                // Phase 3.2: Show active tasks and recently completed in separate sections
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Active tasks tree
                    if (hasActiveTasks)
                      AnimatedTreeView<Task>(
                        // Phase 3.6.5: ValueKey forces Flutter to recreate widget when tree changes
                        // This fixes the issue where completed children don't appear until scroll
                        key: ValueKey('tree-${taskProvider.treeVersion}'),
                        treeController: taskProvider.treeController,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        nodeBuilder: (context, TreeEntry<Task> entry) {
                          // Use drag-and-drop tile in reorder mode, normal tile otherwise
                          if (taskProvider.isReorderMode) {
                            return DragAndDropTaskTile(
                              key: taskProvider.getKeyForTask(entry.node.id), // Phase 3.6B: GlobalKey for scroll-to-task
                              entry: entry,
                              onNodeAccepted: taskProvider.onNodeAccepted,
                              onToggleCollapse: () => taskProvider.toggleCollapse(entry.node),
                              longPressDelay: Theme.of(context).platform == TargetPlatform.iOS ||
                                      Theme.of(context).platform == TargetPlatform.android
                                  ? const Duration(milliseconds: 500)
                                  : null,
                              tags: taskProvider.getTagsForTask(entry.node.id), // Phase 3.5
                            );
                          }

                          return TaskItem(
                            key: taskProvider.getKeyForTask(entry.node.id), // Phase 3.6B: GlobalKey for scroll-to-task
                            task: entry.node,
                            depth: entry.level, // Phase 3.6A: Use visible tree depth
                            hasChildren: entry.hasChildren,
                            isExpanded: entry.isExpanded,
                            onToggleCollapse: () => taskProvider.toggleCollapse(entry.node),
                            isReorderMode: false,
                            tags: taskProvider.getTagsForTask(entry.node.id), // Phase 3.5
                          );
                        },
                      ),

                    // Divider between active and completed
                    if (hasRecentlyCompleted) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Divider(),
                      ),

                      // Recently completed tasks (Phase 3.5 Fix #C3: with hierarchy preserved)
                      // Phase 3.6.5: Use ValueKey instead of GlobalKey to avoid duplicate key conflict
                      // When a completed child appears in BOTH tree (under expanded parent) AND here,
                      // using same GlobalKey causes Flutter to "steal" widget when scrolling
                      ...taskProvider.completedTasksWithHierarchy.map((task) {
                        final breadcrumb = taskProvider.getBreadcrumb(task);
                        return TaskItem(
                          key: ValueKey('completed-${task.id}'), // Phase 3.6.5: Unique key for completed section
                          task: task,
                          depth: task.depth, // Phase 3.5 Fix #C3: Use real depth from DB
                          hasChildren: taskProvider.hasCompletedChildren(task.id), // Phase 3.5 Fix #C3: Check actual children
                          isReorderMode: false,
                          breadcrumb: breadcrumb,
                          tags: taskProvider.getTagsForTask(task.id), // Phase 3.5
                        );
                      }),
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

  /// Phase 3.6A / Phase 3.9 Refactor: Show tag filter dialog
  Future<void> _showFilterDialog(BuildContext context) async {
    final filterProvider = context.read<TaskFilterProvider>();
    final tagProvider = context.read<TagProvider>();

    // Load tags if not already loaded
    if (tagProvider.tags.isEmpty) {
      await tagProvider.loadTags();
    }

    // Show dialog
    final result = await showDialog(
      context: context,
      builder: (context) => TagFilterDialog(
        initialFilter: filterProvider.filterState,
        allTags: tagProvider.tags,
        showCompletedCounts: false, // M3: Show active task counts
        tagService: TagService(), // L5: Inject service
      ),
    );

    // Apply filter if user clicked "Apply" or "Clear All"
    if (result != null && context.mounted) {
      filterProvider.setFilter(result);
    }
  }
}
