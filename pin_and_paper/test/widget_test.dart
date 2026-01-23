// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/tag.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/providers/tag_provider.dart';
import 'package:pin_and_paper/providers/task_provider.dart';
import 'package:pin_and_paper/screens/home_screen.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:provider/provider.dart';

class FakeTaskService extends TaskService {
  final List<Task> _storage = [];
  int _idCounter = 0;

  @override
  Future<Task> createTask(
    String title, {
    DateTime? dueDate,
    bool isAllDay = true,
  }) async {
    final task = Task(
      id: (++_idCounter).toString(),
      title: title,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      isAllDay: isAllDay,
    );
    _storage.insert(0, task);
    return task;
  }

  @override
  Future<List<Task>> getAllTasks() async {
    return List.from(_storage);
  }

  // Phase 3.5 fix: TaskProvider uses getTaskHierarchy(), not getAllTasks()
  @override
  Future<List<Task>> getTaskHierarchy() async {
    return List.from(_storage);
  }

  @override
  Future<Task> toggleTaskCompletion(Task task) async {
    final index = _storage.indexWhere((element) => element.id == task.id);
    if (index == -1) {
      throw StateError('Task not found');
    }

    final updatedTask = task.copyWith(
      completed: !task.completed,
      completedAt: !task.completed ? DateTime.now() : null,
    );

    _storage[index] = updatedTask;
    return updatedTask;
  }
}

// Phase 3.5: Fake TagService for widget tests
class FakeTagService extends TagService {
  @override
  Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds) async {
    // Return empty tags for all tasks
    return {};
  }
}

void main() {
  testWidgets('task lifecycle flow: add, list, complete', (tester) async {
    final fakeTaskService = FakeTaskService();
    final fakeTagService = FakeTagService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => TaskProvider(
              taskService: fakeTaskService,
              tagService: fakeTagService,
            ),
          ),
          // Phase 3.6.5: TagProvider now required by TaskItem
          ChangeNotifierProvider(
            create: (_) => TagProvider(tagService: fakeTagService),
          ),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Allow initial loadTasks() call to resolve
    await tester.pumpAndSettle();

    expect(find.text('No tasks yet.\nAdd one above!'), findsOneWidget);

    // Add a task via the input field and button
    await tester.enterText(find.byType(TextField), 'Buy candles');
    await tester.tap(find.text('Add'));
    await tester.pump(); // process button tap
    await tester.pumpAndSettle();

    expect(find.text('Buy candles'), findsOneWidget);
    expect(find.text('No tasks yet.\nAdd one above!'), findsNothing);

    // Toggle completion
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final Text taskText = tester.widget(find.text('Buy candles'));
    expect(taskText.style?.decoration, TextDecoration.lineThrough);
    expect(taskText.style?.color?.a, lessThan(255)); // Use .a instead of deprecated .opacity
  });
}
