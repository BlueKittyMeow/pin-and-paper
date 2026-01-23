import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/tag_provider.dart'; // Phase 3.6A
import '../services/tag_service.dart'; // Phase 3.6A
import '../models/task_sort_mode.dart'; // Phase 3.7.5
import '../widgets/task_input.dart';
import '../widgets/task_item.dart';
import '../widgets/live_clock.dart'; // Phase 3.7.5
import '../widgets/drag_and_drop_task_tile.dart'; // Phase 3.2
import '../widgets/active_filter_bar.dart'; // Phase 3.6A
import '../widgets/tag_filter_dialog.dart'; // Phase 3.6A
import '../widgets/search_dialog.dart'; // Phase 3.6B
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
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              final isActive = taskProvider.sortMode != TaskSortMode.manual;
              return PopupMenuButton<TaskSortMode>(
                icon: Icon(
                  Icons.sort,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Sort Tasks',
                onSelected: (mode) {
                  if (mode == taskProvider.sortMode) {
                    taskProvider.toggleSortReversed();
                  } else {
                    taskProvider.setSortMode(mode);
                  }
                },
                itemBuilder: (context) => TaskSortMode.values.map((mode) {
                  final isSelected = mode == taskProvider.sortMode;
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
                            taskProvider.sortReversed
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
          // Phase 3.6A: Active filter bar
          Consumer2<TaskProvider, TagProvider>(
            builder: (context, taskProvider, tagProvider, _) {
              return ActiveFilterBar(
                filterState: taskProvider.filterState,
                allTags: tagProvider.tags,
                onClearAll: () => taskProvider.clearFilters(),
                onRemoveTag: (tagId) => taskProvider.removeTagFilter(tagId),
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

  /// Phase 3.6A: Show tag filter dialog
  Future<void> _showFilterDialog(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();
    final tagProvider = context.read<TagProvider>();

    // Load tags if not already loaded
    if (tagProvider.tags.isEmpty) {
      await tagProvider.loadTags();
    }

    // Show dialog
    final result = await showDialog(
      context: context,
      builder: (context) => TagFilterDialog(
        initialFilter: taskProvider.filterState,
        allTags: tagProvider.tags,
        showCompletedCounts: false, // M3: Show active task counts
        tagService: TagService(), // L5: Inject service
      ),
    );

    // Apply filter if user clicked "Apply" or "Clear All"
    if (result != null && context.mounted) {
      await taskProvider.setFilter(result);
    }
  }
}
