import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/models/task.dart';
import 'package:pin_and_paper/models/task_drawing.dart';
import 'package:pin_and_paper/screens/drawing_editor_screen.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/drawing_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart';
import 'package:pin_and_paper_sketchpad/sketchpad.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database_helper.dart';

/// Card drawings M-D5: DrawingEditorScreen widget tests. Real DB reads and
/// writes go through tester.runAsync() (sqflite_common_ffi is real async
/// I/O, not fake-clock timers) — the established pattern from
/// canvas_screen_test.dart.
void main() {
  setUpAll(() {
    TestDatabaseHelper.initialize();
  });

  late Database testDb;
  late TaskService taskService;
  late DrawingService drawingService;

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseService.setTestDatabase(testDb);
    taskService = TaskService();
    drawingService = DrawingService();
  });

  tearDown(() async {
    if (testDb.isOpen) {
      await testDb.close();
    }
  });

  const cardData = TaskCardData(id: 'card-1', title: 'Doodle target');

  Future<Task> createTask(WidgetTester tester, String title) async =>
      (await tester.runAsync(() => taskService.createTask(title)))!;

  /// Pumps a host app and pushes the editor, capturing the popped
  /// "changed" result via [onResult].
  Future<void> pushEditor(
    WidgetTester tester, {
    required String taskId,
    String face = TaskDrawing.faceFront,
    String? existingDrawingJson,
    required void Function(bool?) onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => DrawingEditorScreen(
                      taskId: taskId,
                      cardData: cardData,
                      face: face,
                      existingDrawingJson: existingDrawingJson,
                    ),
                  ),
                );
                onResult(changed);
              },
              child: const Text('open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
  }

  /// The editor's live LayerStack, read off the mounted DrawingCanvas.
  LayerStack editorStack(WidgetTester tester) =>
      tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).layerStack;

  int strokeCount(WidgetTester tester) =>
      editorStack(tester).layers.fold(0, (n, l) => n + l.strokes.length);

  /// One down-move-up stroke across the canvas center with [kind].
  Future<void> drawStroke(WidgetTester tester, PointerDeviceKind kind) async {
    final center = tester.getCenter(find.byType(DrawingCanvas));
    final gesture = await tester.createGesture(
      kind: kind,
      buttons: kind == PointerDeviceKind.mouse ? kPrimaryButton : 0,
    );
    await gesture.down(center);
    await tester.pump();
    await gesture.moveBy(const Offset(30, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  /// Taps save-and-close, gives the real-async DB write time to land, and
  /// settles the pop transition.
  Future<void> saveAndClose(WidgetTester tester) async {
    await tester.tap(find.byKey(kDrawingEditorDoneKey));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  String existingJsonWithOneInkStroke() {
    final stack = LayerStack(size: kDrawingEditorCaptureSize);
    stack.addStrokeToActiveLayer(
      const Stroke(
        points: [StrokePoint(100, 100, 0.5), StrokePoint(200, 150, 0.5)],
        color: Color(0xFF2D2D2D),
        options: StrokeOptions.ink,
      ),
    );
    return jsonEncode(stack.toJson());
  }

  testWidgets('front editor shows the real TaskCard backdrop, full toolbar, and live canvas', (tester) async {
    final task = await createTask(tester, 'Front card');
    bool? result;
    await pushEditor(tester, taskId: task.id, onResult: (r) => result = r);

    expect(find.byType(TaskCard), findsOneWidget); // owner L2: real face under the ink
    expect(find.byType(TaskCardBack), findsNothing);
    expect(find.byType(DrawingCanvas), findsOneWidget);
    expect(find.byType(DrawingToolbar), findsOneWidget); // owner L3: full three-layer toolbar
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(result, isNull); // still open
  });

  testWidgets('back editor shows the TaskCardBack backdrop', (tester) async {
    final task = await createTask(tester, 'Back card');
    await pushEditor(tester, taskId: task.id, face: TaskDrawing.faceBack, onResult: (_) {});

    expect(find.byType(TaskCardBack), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);
  });

  group('backdrop-aware multiply compositing (owner report 2026-08-06, '
      'fixed 2026-08-07)', () {
    // A "Blend"/Marker layer must multiply against the REAL card face, not
    // an imaginary flat paper tone — see stroke_painter.dart's
    // "Backdrop-aware multiply compositing" note. DrawingCanvas needs a
    // raster snapshot of that same card face to do the real per-pixel
    // blend; this proves the editor actually captures and wires one
    // through, at the exact capture-space resolution strokes are recorded
    // in (so the blend math and stroke coordinates agree 1:1).
    testWidgets('captures a backdrop snapshot of the real TaskCard, sized '
        'to the drawing capture space', (tester) async {
      final task = await createTask(tester, 'Front card');
      await pushEditor(tester, taskId: task.id, onResult: (_) {});

      final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
      final backdrop = canvas.backdropImage;
      expect(backdrop, isNotNull, reason: 'a multiply layer has no real '
          'card to blend against without this');
      expect(backdrop!.width, kDrawingEditorCaptureSize.width.round());
      expect(backdrop.height, kDrawingEditorCaptureSize.height.round());
    });

    testWidgets('captures a backdrop snapshot of the real TaskCardBack too',
        (tester) async {
      final task = await createTask(tester, 'Back card');
      await pushEditor(tester, taskId: task.id, face: TaskDrawing.faceBack, onResult: (_) {});

      final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
      final backdrop = canvas.backdropImage;
      expect(backdrop, isNotNull);
      expect(backdrop!.width, kDrawingEditorCaptureSize.width.round());
      expect(backdrop.height, kDrawingEditorCaptureSize.height.round());
    });
  });

  testWidgets('save writes one row with the right (task_id, face) and round-trippable JSON', (tester) async {
    final task = await createTask(tester, 'Inked card');
    bool? result;
    await pushEditor(tester, taskId: task.id, onResult: (r) => result = r);

    await drawStroke(tester, PointerDeviceKind.stylus);
    expect(strokeCount(tester), 1);

    await saveAndClose(tester);
    expect(result, isTrue);

    await tester.runAsync(() async {
      final saved = await drawingService.getDrawingForTask(task.id);
      expect(saved, isNotNull);
      expect(saved!.taskId, task.id);
      expect(saved.face, TaskDrawing.faceFront);
      expect(saved.visible, isTrue);

      // Round-trippable: the stored JSON parses back through the
      // sketchpad's own format-v1 reader with the stroke intact.
      final restored = LayerStack.fromJson(jsonDecode(saved.drawingJson) as Map<String, dynamic>);
      expect(restored.size, kDrawingEditorCaptureSize);
      expect(restored.layers.fold<int>(0, (n, l) => n + l.strokes.length), 1);

      // Face isolation: nothing landed on the back.
      expect(await drawingService.getDrawingForTask(task.id, face: TaskDrawing.faceBack), isNull);
    });
  });

  testWidgets('a back-face save lands on the back row', (tester) async {
    final task = await createTask(tester, 'Two-sided');
    bool? result;
    await pushEditor(tester, taskId: task.id, face: TaskDrawing.faceBack, onResult: (r) => result = r);

    await drawStroke(tester, PointerDeviceKind.stylus);
    await saveAndClose(tester);
    expect(result, isTrue);

    await tester.runAsync(() async {
      expect(await drawingService.getDrawingForTask(task.id), isNull);
      final back = await drawingService.getDrawingForTask(task.id, face: TaskDrawing.faceBack);
      expect(back, isNotNull);
      expect(back!.face, TaskDrawing.faceBack);
    });
  });

  testWidgets('a brand-new empty drawing writes NOTHING (empty-drawings-stay-NULL)', (tester) async {
    final task = await createTask(tester, 'Never inked');
    bool? result;
    await pushEditor(tester, taskId: task.id, onResult: (r) => result = r);

    // Close immediately — no strokes, no prior row.
    await saveAndClose(tester);
    expect(result, isFalse);

    await tester.runAsync(() async {
      expect(await drawingService.getDrawingForTask(task.id), isNull);
    });
  });

  testWidgets('drawing a stroke and undoing everything still writes nothing for a new drawing', (tester) async {
    final task = await createTask(tester, 'Changed my mind');
    bool? result;
    await pushEditor(tester, taskId: task.id, onResult: (r) => result = r);

    await drawStroke(tester, PointerDeviceKind.stylus);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(strokeCount(tester), 0);

    await saveAndClose(tester);
    expect(result, isFalse);
    await tester.runAsync(() async {
      expect(await drawingService.getDrawingForTask(task.id), isNull);
    });
  });

  testWidgets('an intentionally emptied EXISTING drawing still saves (row keeps its identity)', (tester) async {
    final task = await createTask(tester, 'Erased card');
    await tester.runAsync(() => drawingService.saveTaskDrawing(task.id, existingJsonWithOneInkStroke()));
    final existing =
        (await tester.runAsync(() async => (await drawingService.getDrawingForTask(task.id))!))!;

    bool? result;
    await pushEditor(
      tester,
      taskId: task.id,
      existingDrawingJson: existing.drawingJson,
      onResult: (r) => result = r,
    );
    expect(strokeCount(tester), 1); // restored stroke is on the (active) ink layer

    await tester.tap(find.byTooltip('Clear layer'));
    await tester.pump();
    expect(strokeCount(tester), 0);

    await saveAndClose(tester);
    expect(result, isTrue);

    await tester.runAsync(() async {
      final saved = await drawingService.getDrawingForTask(task.id);
      expect(saved, isNotNull, reason: 'Emptying an existing drawing is a deliberate act — it saves');
      expect(saved!.id, existing.id); // upsert kept the row
      final restored = LayerStack.fromJson(jsonDecode(saved.drawingJson) as Map<String, dynamic>);
      expect(restored.layers.every((l) => l.strokes.isEmpty), isTrue);
    });
  });

  testWidgets('an untouched existing drawing closes without rewriting (changed == false)', (tester) async {
    final task = await createTask(tester, 'Just looking');
    await tester.runAsync(() => drawingService.saveTaskDrawing(task.id, existingJsonWithOneInkStroke()));
    final before =
        (await tester.runAsync(() async => (await drawingService.getDrawingForTask(task.id))!))!;

    bool? result;
    await pushEditor(
      tester,
      taskId: task.id,
      existingDrawingJson: before.drawingJson,
      onResult: (r) => result = r,
    );
    await saveAndClose(tester);
    expect(result, isFalse);

    await tester.runAsync(() async {
      final after = (await drawingService.getDrawingForTask(task.id))!;
      expect(after.updatedAt!.millisecondsSinceEpoch, before.updatedAt!.millisecondsSinceEpoch,
          reason: 'No mutations — no write');
    });
  });

  group('input policy (owner L6)', () {
    testWidgets('the toggle exists, defaults to stylus-only, and flips', (tester) async {
      final task = await createTask(tester, 'Policy card');
      await pushEditor(tester, taskId: task.id, onResult: (_) {});

      final toggle = find.byKey(kDrawingEditorTouchToggleKey);
      expect(toggle, findsOneWidget);
      expect(find.byTooltip('Stylus-only — tap to allow finger drawing'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pump();
      expect(find.byTooltip('Finger drawing on — tap for stylus-only'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pump();
      expect(find.byTooltip('Stylus-only — tap to allow finger drawing'), findsOneWidget);
    });

    testWidgets('stylus-only: touch never inks; stylus and mouse do', (tester) async {
      final task = await createTask(tester, 'Stylus card');
      await pushEditor(tester, taskId: task.id, onResult: (_) {});

      await drawStroke(tester, PointerDeviceKind.touch);
      expect(strokeCount(tester), 0, reason: 'Touch inking is rejected by default');

      await drawStroke(tester, PointerDeviceKind.stylus);
      expect(strokeCount(tester), 1);

      // Mouse always inks — Linux desktop has no stylus.
      await drawStroke(tester, PointerDeviceKind.mouse);
      expect(strokeCount(tester), 2);
    });

    testWidgets('finger mode inks with touch, but a second finger cancels the stroke', (tester) async {
      final task = await createTask(tester, 'Finger card');
      await pushEditor(tester, taskId: task.id, onResult: (_) {});

      await tester.tap(find.byKey(kDrawingEditorTouchToggleKey));
      await tester.pump();

      await drawStroke(tester, PointerDeviceKind.touch);
      expect(strokeCount(tester), 1, reason: 'Finger inking allowed after the toggle');

      // Two fingers = a gesture, never ink.
      final center = tester.getCenter(find.byType(DrawingCanvas));
      final finger1 = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger1.down(center);
      await tester.pump();
      final finger2 = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger2.down(center + const Offset(60, 0));
      await tester.pump();
      await finger1.moveBy(const Offset(30, 30));
      await finger2.moveBy(const Offset(-30, 30));
      await tester.pump();
      await finger1.up();
      await finger2.up();
      await tester.pump();

      expect(strokeCount(tester), 1, reason: 'The two-finger gesture left no ink');
    });
  });

  group('pinch-to-zoom (owner 2026-08-06)', () {
    /// The largest scale factor among every `Transform` under the editor.
    /// `_PinchZoomView`'s Transform is the only one expected to move
    /// meaningfully away from 1.0 in these tests.
    double maxTransformScale(WidgetTester tester) {
      var best = 1.0;
      for (final t in tester.widgetList<Transform>(find.descendant(
        of: find.byType(DrawingEditorScreen),
        matching: find.byType(Transform),
      ))) {
        final s = t.transform.getMaxScaleOnAxis();
        if (s > best) best = s;
      }
      return best;
    }

    testWidgets('a two-finger pinch zooms the drawing surface, even in the '
        'default stylus-only mode', (tester) async {
      final task = await createTask(tester, 'Pinch card');
      await pushEditor(tester, taskId: task.id, onResult: (_) {});

      expect(maxTransformScale(tester), closeTo(1.0, 0.001));

      final center = tester.getCenter(find.byType(DrawingCanvas));
      final finger1 = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger1.down(center - const Offset(20, 0));
      await tester.pump();
      final finger2 = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger2.down(center + const Offset(20, 0));
      await tester.pump();

      // Pinch OUT — fingers spread apart, should zoom in.
      await finger1.moveBy(const Offset(-40, 0));
      await finger2.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(maxTransformScale(tester), greaterThan(1.5));

      await finger1.up();
      await finger2.up();
      await tester.pump();

      // The pinch itself never left ink.
      expect(strokeCount(tester), 0);
    });

    testWidgets('a single finger never zooms, even mid-drag', (tester) async {
      final task = await createTask(tester, 'No zoom card');
      await pushEditor(tester, taskId: task.id, onResult: (_) {});

      final center = tester.getCenter(find.byType(DrawingCanvas));
      final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
      await touch.down(center);
      await touch.moveBy(const Offset(40, 40));
      await tester.pump();

      expect(maxTransformScale(tester), closeTo(1.0, 0.001));

      await touch.up();
      await tester.pump();
    });

    testWidgets('a stylus stroke still inks normally with the pinch-zoom '
        'wrapper in place', (tester) async {
      final task = await createTask(tester, 'Still inks card');
      await pushEditor(tester, taskId: task.id, onResult: (_) {});

      await drawStroke(tester, PointerDeviceKind.stylus);
      expect(strokeCount(tester), 1);
      expect(maxTransformScale(tester), closeTo(1.0, 0.001));
    });
  });
}
