import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/providers/tag_provider.dart';
import 'package:pin_and_paper/providers/task_filter_provider.dart';
import 'package:pin_and_paper/providers/task_hierarchy_provider.dart';
import 'package:pin_and_paper/providers/task_provider.dart';
import 'package:pin_and_paper/providers/task_sort_provider.dart';
import 'package:pin_and_paper/screens/canvas_screen.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper_canvas/spatial_canvas.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database_helper.dart';

/// Phase 4.4-MVP (M3/M4 addendum item 7): CanvasScreen's startup guard must
/// gate strictly on `TaskProvider.isLoading`, never on `tasks.isEmpty` — a
/// legitimately empty (but fully loaded) task list is a correctly-empty
/// desk, not a "still loading" state.
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late Database testDb;
  late TaskService taskService;
  late TaskProvider taskProvider;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);

    taskService = TaskService();
    final tagService = TagService();
    final tagProvider = TagProvider(tagService: tagService);
    final filterProvider = TaskFilterProvider(tagProvider: tagProvider);
    taskProvider = TaskProvider(
      taskService: taskService,
      tagService: tagService,
      tagProvider: tagProvider,
      sortProvider: TaskSortProvider(),
      filterProvider: filterProvider,
      hierarchyProvider: TaskHierarchyProvider(),
    );
  });

  tearDown(() async {
    await taskProvider.waitForPendingOperations();
    taskProvider.dispose();
    if (testDb.isOpen) {
      await testDb.close();
    }
  });

  Widget wrap() {
    return ChangeNotifierProvider<TaskProvider>.value(
      value: taskProvider,
      child: const MaterialApp(home: CanvasScreen()),
    );
  }

  testWidgets('shows a loading placeholder while TaskProvider.isLoading, then the desk once it settles', (
    tester,
  ) async {
    // Deliberately zero tasks in this DB -- if the guard were (wrongly)
    // keyed on `tasks.isEmpty` instead of `isLoading`, this would already
    // look "loaded", defeating the point of the test.
    //
    // loadTasks() does a real sqflite_common_ffi round trip (not a fake
    // clock timer), so it must run inside tester.runAsync() -- otherwise
    // it never completes under AutomatedTestWidgetsFlutterBinding's
    // synthetic test zone and the test hangs forever. runAsync() runs
    // taskProvider.loadTasks() synchronously up to its first real await,
    // so `isLoading` is already true by the time this line returns, same
    // as calling loadTasks() directly.
    final loadFuture = tester.runAsync(() => taskProvider.loadTasks());
    expect(taskProvider.isLoading, isTrue);

    await tester.pumpWidget(wrap());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SpatialCanvas), findsNothing);

    await loadFuture; // TaskService.getTaskHierarchy() settles, isLoading -> false
    await tester.pump(); // let the one-shot listener's setState flow through

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SpatialCanvas), findsOneWidget);
  });

  testWidgets('builds the desk immediately when TaskProvider already finished loading before mount', (tester) async {
    // Real DB work -- see tester.runAsync() note above.
    await tester.runAsync(() async {
      await taskService.createTask('Card one');
      await taskProvider.loadTasks(); // settles before CanvasScreen ever mounts
    });
    expect(taskProvider.isLoading, isFalse);

    await tester.pumpWidget(wrap());
    await tester.pump(); // let initState's postFrameCallback run

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SpatialCanvas), findsOneWidget);
  });

  testWidgets('completed cards never render on the desk, placed or not', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Real DB work -- see tester.runAsync() note above.
    await tester.runAsync(() async {
      final placed = await taskService.createTask('Done placed');
      await taskService.updateTaskCanvasPosition(placed.id, 300.0, 300.0);
      await taskService.toggleTaskCompletion(placed);
      final unplaced = await taskService.createTask('Done unplaced');
      await taskService.toggleTaskCompletion(unplaced);
      await taskProvider.loadTasks();
    });

    await tester.pumpWidget(wrap());
    await tester.pump(); // postFrameCallback -> snapshot

    expect(find.byType(SpatialCanvas), findsOneWidget); // desk itself stays
    expect(find.byType(FlippableTaskCard), findsNothing);
  });

  testWidgets('an empty-but-loaded task list shows the desk, not the placeholder forever', (tester) async {
    // Real DB work -- see tester.runAsync() note above.
    await tester.runAsync(() => taskProvider.loadTasks()); // zero tasks; isLoading still resolves false
    expect(taskProvider.isLoading, isFalse);
    expect(taskProvider.tasks, isEmpty);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SpatialCanvas), findsOneWidget);
  });
}
