import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/providers/tag_provider.dart';
import 'package:pin_and_paper/screens/drawing_editor_screen.dart';
import 'package:pin_and_paper/services/drawing_service.dart';
import 'package:pin_and_paper/providers/task_filter_provider.dart';
import 'package:pin_and_paper/providers/task_hierarchy_provider.dart';
import 'package:pin_and_paper/providers/task_provider.dart';
import 'package:pin_and_paper/providers/task_sort_provider.dart';
import 'package:pin_and_paper/screens/canvas_screen.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/desk_object_service.dart';
import 'package:pin_and_paper/spatial/amethyst_desk_entity.dart';
import 'package:pin_and_paper/spatial/dachshund_desk_entity.dart';
import 'package:pin_and_paper/spatial/task_spatial_data_source.dart';
import 'package:pin_and_paper/services/tag_service.dart';
import 'package:pin_and_paper/services/task_service.dart';
import 'package:pin_and_paper_canvas/spatial_canvas.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart';
import 'package:pin_and_paper_sketchpad/sketchpad.dart';
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

  /// The data source kicks off real sqflite-ffi restores at construction
  /// (drawings, desk objects). Give them real-async time to land before the
  /// test ends, or their in-flight I/O trips the binding's pending-timer
  /// invariant at teardown.
  Future<void> drainRestores(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
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
    await drainRestores(tester);
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
    await drainRestores(tester);
  });

  testWidgets('completed cards render in the done pile, not at their desk spots', (tester) async {
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

    expect(find.byType(SpatialCanvas), findsOneWidget);
    // Both completed cards render -- but in the pile, not on the desk (the
    // exact pile geometry is covered in the data source suite).
    expect(find.byType(FlippableTaskCard), findsNWidgets(2));
    await drainRestores(tester);
  });

  testWidgets('face toggles: all-backs overrides, keep commits, active toggle returns to manual', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Real DB work -- see tester.runAsync() note above.
    await tester.runAsync(() async {
      await taskService.createTask('Scannable card');
      await taskProvider.loadTasks();
    });

    await tester.pumpWidget(wrap());
    await tester.pump();

    FlippableTaskCard card() => tester.widget<FlippableTaskCard>(find.byType(FlippableTaskCard));
    expect(card().showBack, isFalse);
    expect(find.byTooltip('Keep these faces'), findsNothing);

    await tester.tap(find.byTooltip('Show all backs'));
    await tester.pump();
    expect(card().showBack, isTrue);
    expect(find.byTooltip('Keep these faces'), findsOneWidget);

    await tester.tap(find.byTooltip('Keep these faces'));
    await tester.pump();
    expect(find.byTooltip('Keep these faces'), findsNothing); // back to manual
    expect(card().showBack, isTrue); // ...with the view committed

    // Entering an override and tapping the same (now-active) toggle
    // returns to manual with the committed flips intact.
    await tester.tap(find.byTooltip('Show all fronts'));
    await tester.pump();
    expect(card().showBack, isFalse);
    await tester.tap(find.byTooltip('Back to your flips'));
    await tester.pump();
    expect(card().showBack, isTrue);
    expect(find.byTooltip('Keep these faces'), findsNothing);
    await drainRestores(tester);
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
    await drainRestores(tester);
  });

  group('card drawing chips + overlays (M-D5)', () {
    /// A minimal valid format-v1 drawing (one visible ink stroke).
    String drawingJson() {
      final stack = LayerStack(size: kDrawingEditorCaptureSize);
      stack.addStrokeToActiveLayer(
        const Stroke(
          points: [StrokePoint(100, 100, 0.5), StrokePoint(300, 200, 0.5)],
          color: Color(0xFF2D2D2D),
          options: StrokeOptions.ink,
        ),
      );
      return jsonEncode(stack.toJson());
    }

    /// Pumps the desk, then gives the data source's bulk drawings query
    /// (real sqflite ffi I/O at construction) real-async time to land and
    /// flushes its notifyListeners.
    Future<void> pumpDesk(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(); // postFrameCallback -> snapshot
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(); // drawings-loaded notifyListeners
    }

    /// Selects [target] by tapping it and waiting out the tap/double-tap
    /// disambiguation window in the canvas's gesture arena.
    Future<void> select(WidgetTester tester, Finder target) async {
      await tester.tap(target, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('pencil chip appears only while a task card is selected; no eye without a drawing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        final t = await taskService.createTask('Sketchable card');
        await taskService.updateTaskCanvasPosition(t.id, 150.0, 150.0);
        await taskProvider.loadTasks();
      });
      await pumpDesk(tester);

      expect(find.byTooltip('Draw on this card'), findsNothing); // unselected: no chips

      await select(tester, find.byType(FlippableTaskCard));

      expect(find.byTooltip('Draw on this card'), findsOneWidget);
      // No drawing on this face yet: the eye chip stays away.
      expect(find.byTooltip('Hide drawing'), findsNothing);
      expect(find.byTooltip('Show drawing'), findsNothing);
      expect(find.byKey(kHiddenDrawingGlyphKey), findsNothing);
    });

    testWidgets('the selected amethyst gets resize chips, never the pencil', (tester) async {
      // Park the stone somewhere visible in the test viewport (it defaults
      // to the canvas center, off-screen at zoom 1).
      SharedPreferences.setMockInitialValues({
        'spatial_amethyst_x': 350.0,
        'spatial_amethyst_y': 120.0,
      });
      await tester.runAsync(() => taskProvider.loadTasks()); // zero tasks
      await pumpDesk(tester);
      await tester.pump(); // amethyst prefs restore notifyListeners

      // Scoped to the canvas AND to the amethyst: the drawer hosts gem
      // thumbnails too, and other gems may be placed.
      await select(
        tester,
        find.descendant(
          of: find.byType(SpatialCanvas),
          matching: find.byWidgetPredicate(
            (w) => w is GemFigurine && w.variant == GemVariant.amethyst,
          ),
        ),
      );

      expect(find.byTooltip('Bigger'), findsOneWidget);
      expect(find.byTooltip('Draw on this card'), findsNothing);
      expect(find.byTooltip('Hide drawing'), findsNothing);
    });

    testWidgets('visible drawing renders an overlay; hiding swaps it for the grey glyph', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        final t = await taskService.createTask('Inked card');
        await taskService.updateTaskCanvasPosition(t.id, 150.0, 150.0);
        await DrawingService().saveTaskDrawing(t.id, drawingJson());
        await taskProvider.loadTasks();
      });
      await pumpDesk(tester);

      // Overlay present without any selection; no hidden-ink tell.
      expect(find.byType(DrawingPreview), findsOneWidget);
      expect(find.byKey(kHiddenDrawingGlyphKey), findsNothing);

      await select(tester, find.byType(FlippableTaskCard));
      expect(find.byTooltip('Hide drawing'), findsOneWidget); // eye chip: face HAS a drawing

      // Chip taps sit in the same arena as the card's double-tap
      // recognizer, so they too resolve only after the disambiguation
      // window — pump past it, same as select().
      await tester.tap(find.byTooltip('Hide drawing'));
      await tester.pump(const Duration(milliseconds: 400));

      // Hidden: overlay gone, grey pencil tell on, eye now offers "show".
      expect(find.byType(DrawingPreview), findsNothing);
      expect(find.byKey(kHiddenDrawingGlyphKey), findsOneWidget);
      expect(find.byTooltip('Show drawing'), findsOneWidget);

      await tester.tap(find.byTooltip('Show drawing'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DrawingPreview), findsOneWidget);
      expect(find.byKey(kHiddenDrawingGlyphKey), findsNothing);

      // Let the fire-and-forget visibility writes land before teardown
      // closes the DB.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    });

    testWidgets('the pencil chip opens the drawing editor for the showing face', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        final t = await taskService.createTask('Editable card');
        await taskService.updateTaskCanvasPosition(t.id, 150.0, 150.0);
        await taskProvider.loadTasks();
      });
      await pumpDesk(tester);

      await select(tester, find.byType(FlippableTaskCard));
      // Chip tap resolves after the double-tap disambiguation window (see
      // above); pumpAndSettle alone would return before the timer fires.
      await tester.tap(find.byTooltip('Draw on this card'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(DrawingEditorScreen), findsOneWidget);

      // Close (no ink -> no write) and land back on the desk.
      await tester.tap(find.byKey(kDrawingEditorDoneKey));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.byType(DrawingEditorScreen), findsNothing);
      expect(find.byType(SpatialCanvas), findsOneWidget);
    });
  });

  group('desk-objects drawer', () {
    Finder onDesk(Type type) =>
        find.descendant(of: find.byType(SpatialCanvas), matching: find.byType(type));

    /// Pumps the desk, gives the data source's restore queries (real
    /// sqflite ffi I/O) real-async time to land, and flushes the notify.
    Future<void> pumpDesk(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(); // postFrameCallback -> snapshot
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(); // restore notifyListeners
    }

    // .first: the tile's ghosting Opacity is the outermost — the dachshund
    // thumbnail contains its own Opacity widgets (its 40% shadow layers).
    double tileOpacity(WidgetTester tester, String id) => tester
        .widget<Opacity>(
          find
              .descendant(of: find.byKey(deskDrawerTileKey(id)), matching: find.byType(Opacity))
              .first,
        )
        .opacity;

    testWidgets('tab slides the panel out; tiles show ghosted-if-placed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => taskProvider.loadTasks()); // zero tasks
      await pumpDesk(tester);

      expect(find.byKey(kDeskDrawerTabKey), findsOneWidget);

      await tester.tap(find.byKey(kDeskDrawerTabKey));
      await tester.pumpAndSettle();

      // The stone starts on the desk (ghosted tile); the dachshund starts
      // in the drawer (full opacity), not on the desk.
      expect(tileOpacity(tester, kAmethystDeskId), 0.35);
      expect(tileOpacity(tester, kDachshundDeskId), 1.0);
      expect(onDesk(DachshundFigurine), findsNothing);
    });

    testWidgets('tapping his tile sets the dachshund on the desk; his chip puts him away', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => taskProvider.loadTasks()); // zero tasks
      await pumpDesk(tester);

      await tester.tap(find.byKey(kDeskDrawerTabKey));
      await tester.pumpAndSettle();
      // Six residents now: his tile sits at the bottom of the (scrollable)
      // panel — bring it on screen before tapping.
      await tester.ensureVisible(find.byKey(deskDrawerTileKey(kDachshundDeskId)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(deskDrawerTileKey(kDachshundDeskId)));
      // Placement pans the canvas to him (place-back-at-last-spot + focus);
      // let the animation land so the chips are on screen.
      await tester.pumpAndSettle();

      // On the desk (selected on arrival — the put-away chip is showing),
      // and ghosted in the drawer.
      expect(onDesk(DachshundFigurine), findsOneWidget);
      expect(tileOpacity(tester, kDachshundDeskId), 0.35);
      expect(find.byTooltip('Put away in the drawer'), findsOneWidget);

      // Chip taps resolve after the canvas's double-tap disambiguation
      // window, same as the card chips.
      await tester.tap(find.byTooltip('Put away in the drawer'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(onDesk(DachshundFigurine), findsNothing);
      expect(tileOpacity(tester, kDachshundDeskId), 1.0);

      // Let the fire-and-forget desk_objects writes land before teardown
      // closes the DB.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    });
  });

  group('desk-object selection transfer (owner report 2026-08-05)', () {
    // Scoped past the drawer: it always builds a thumbnail Dachshund/Gem
    // Figurine per catalog entry (clipped to zero width, not gone), so an
    // unscoped find.byType would match those too.
    Finder onDesk(Type type) =>
        find.descendant(of: find.byType(SpatialCanvas), matching: find.byType(type));

    /// Pumps the desk, gives the data source's desk_objects restore (real
    /// sqflite ffi I/O) time to land, then polls until both hit masks this
    /// test depends on have actually finished decoding. A real PNG decode
    /// isn't on the fake test clock, so a fixed delay would be a guess: a
    /// known-transparent corner sample (0.02, 0.02) answers `true` (the
    /// whole-box fallback) before a mask lands and `false` once it's
    /// decoded -- the same trick `DachshundHitMask`'s own "answers
    /// whole-box true before masks load" unit test relies on -- so polling
    /// on that is a reliable loaded signal without a public flag.
    Future<void> pumpDeskAndAwaitMasks(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(); // postFrameCallback -> snapshot
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        final dachshundLoaded = !DachshundHitMask.contains(DachshundStop.threeQLeft, 0.02, 0.02);
        final amethystLoaded = !GemHitMask.contains(GemVariant.amethyst, SpriteStop.threeQLeft, 0.02, 0.02);
        if (dachshundLoaded && amethystLoaded) return;
      }
      fail('hit masks did not finish decoding in time (real PNG decode running long?)');
    }

    testWidgets(
      'tapping a second desk object while the first is selected transfers selection directly',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        // The dachshund ("A") sits at (280, 80). His widened sprite frame's
        // transparent margin is made to overlap the amethyst's ("B")
        // visible body: B is placed so its own silhouette center lands at
        // A's local (39.2, 352.8) -- normalized (0.1, 0.9), confirmed
        // transparent in the source art (outside the "central ~40%" dog)
        // and well clear of the chip cluster in A's top-right corner. Same
        // shape of overlap as the owner's phone report: tap a second
        // knick-knack while the first is selected.
        const dachshundPos = Offset(280, 80);
        final marginLocal = Offset(0.1 * kDachshundDefaultSize.width, 0.9 * kDachshundDefaultSize.height);
        final swallowPoint = dachshundPos + marginLocal;
        final amethystPos =
            swallowPoint - Offset(kAmethystDefaultSize.width / 2, kAmethystDefaultSize.height / 2);

        await tester.runAsync(() async {
          await taskProvider.loadTasks(); // zero tasks -- desk objects only
          await DeskObjectService().save(
            id: kDachshundDeskId,
            placed: true,
            x: dachshundPos.dx,
            y: dachshundPos.dy,
            width: kDachshundDefaultSize.width,
          );
          await DeskObjectService().save(
            id: kAmethystDeskId,
            placed: true,
            x: amethystPos.dx,
            y: amethystPos.dy,
            width: kAmethystDefaultSize.width,
          );
        });

        await pumpDeskAndAwaitMasks(tester);

        // Select the dachshund by tapping his own visible body (box
        // center -- deep inside the opaque "central ~40%" silhouette).
        await tester.tap(onDesk(DachshundFigurine), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<DachshundFigurine>(onDesk(DachshundFigurine)).isSelected, isTrue);
        expect(tester.widget<GemFigurine>(onDesk(GemFigurine)).isSelected, isFalse);

        // Tap the swallow point: on the dachshund's transparent margin
        // (inside his box, outside his silhouette) AND on the amethyst's
        // visible body underneath. Before the fix, the selected
        // dachshund's full box reclaimed this point and the tap never
        // reached the amethyst at all -- selection stayed on him. Fixed:
        // selection transfers to the amethyst in this ONE tap, no
        // deselect-first required.
        final dogTopLeft = tester.getTopLeft(onDesk(DachshundFigurine));
        await tester.tapAt(dogTopLeft + marginLocal);
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.widget<GemFigurine>(onDesk(GemFigurine)).isSelected, isTrue);
        expect(tester.widget<DachshundFigurine>(onDesk(DachshundFigurine)).isSelected, isFalse);

        // Constraint check: his chips must still be reachable while he's
        // selected (this fix narrows his box-back region to exactly their
        // footprint -- confirm it didn't narrow them into unreachability).
        await tester.tap(onDesk(DachshundFigurine), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byTooltip('Put away in the drawer'), findsOneWidget);

        // Let the fire-and-forget desk_objects writes land before teardown
        // closes the DB.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      },
    );
  });

  group('done-pile scrollable tray (owner decision 2026-08-06)', () {
    /// Fills the pile to [kRecentCompletedCount] -- at the app's real
    /// [kCanvasScreenSize], a full pile is exactly the case that overflows
    /// a single on-desk fan column (see task_spatial_data_source_test.dart's
    /// cramped-canvas regression case for the numbers) -- then pumps the
    /// desk and hands back the live data source CanvasScreen actually built,
    /// the same way the "desk-objects drawer" group above reaches into the
    /// widget tree rather than re-deriving app internals.
    Future<TaskSpatialDataSource> pumpDeskWithFullPile(WidgetTester tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < kRecentCompletedCount; i++) {
          final t = await taskService.createTask('Done $i');
          await taskService.toggleTaskCompletion(t);
        }
        await taskProvider.loadTasks();
      });
      await tester.pumpWidget(wrap());
      await tester.pump(); // postFrameCallback -> snapshot
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(); // restores' notifyListeners
      return tester.widget<SpatialCanvas>(find.byType(SpatialCanvas)).dataSource as TaskSpatialDataSource;
    }

    testWidgets('fanning a full pile overflows into the tray instead of an on-desk fan', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dataSource = await pumpDeskWithFullPile(tester);
      expect(find.byKey(kDonePileTrayKey), findsNothing);

      dataSource.toggleDonePileFanned();
      await tester.pump();

      expect(dataSource.donePileOverflowsFan, isTrue);
      expect(find.byKey(kDonePileTrayKey), findsOneWidget);
      for (final entity in dataSource.recentCompletedNewestFirst) {
        expect(find.byKey(donePileTrayCardKey(entity.id)), findsOneWidget);
      }
    });

    testWidgets('tapping a tray card selects it (its chips surface) without closing the tray', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dataSource = await pumpDeskWithFullPile(tester);
      dataSource.toggleDonePileFanned();
      await tester.pump();

      final first = dataSource.recentCompletedNewestFirst.first;
      await tester.tap(find.byKey(donePileTrayCardKey(first.id)));
      // Chip taps/selection resolve after the canvas's double-tap
      // disambiguation window, same as on-desk card chips.
      await tester.pump(const Duration(milliseconds: 400));

      expect(dataSource.donePileFanned, isTrue, reason: 'inspecting a tray card must not dismiss the pile');
      expect(find.byKey(kDonePileTrayKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(donePileTrayCardKey(first.id)),
          matching: find.byTooltip('Draw on this card'),
        ),
        findsOneWidget,
        reason: 'selecting a tray card surfaces its edit chip, same as an on-desk selected card',
      );
    });

    testWidgets("the tray header's close control restacks the pile", (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dataSource = await pumpDeskWithFullPile(tester);
      dataSource.toggleDonePileFanned();
      await tester.pump();
      expect(find.byKey(kDonePileTrayKey), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();

      expect(dataSource.donePileFanned, isFalse);
      expect(dataSource.donePileOverflowsFan, isFalse);
      expect(find.byKey(kDonePileTrayKey), findsNothing);
    });
  });

  group('tag-tap spotlight (owner idea 2026-08-06, tentative)', () {
    /// Two placed cards -- one tagged 'work', one untagged -- far enough
    /// apart that their AnimatedOpacity ancestors are unambiguous by title.
    /// Returns the live data source plus the created tag's real id: tags
    /// are identified by [Tag.id] (a UUID), not [Tag.name] -- see
    /// `TaskSpatialDataSource.spotlitTag`'s doc comment -- so tests that
    /// assert on `spotlitTag` need the id, not the display string 'work'.
    Future<(TaskSpatialDataSource, String tagId)> pumpDeskWithTaggedCards(WidgetTester tester) async {
      late String tagId;
      await tester.runAsync(() async {
        final tagService = TagService();
        final workTag = await tagService.createTag('work');
        tagId = workTag.id;
        final tagged = await taskService.createTask('Work card');
        await taskService.updateTaskCanvasPosition(tagged.id, 150.0, 150.0);
        await tagService.addTagToTask(tagged.id, workTag.id);
        final untagged = await taskService.createTask('Other card');
        await taskService.updateTaskCanvasPosition(untagged.id, 150.0, 400.0);
        await taskProvider.loadTasks();
      });
      await tester.pumpWidget(wrap());
      await tester.pump(); // postFrameCallback -> snapshot
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(); // restores' notifyListeners
      final dataSource = tester.widget<SpatialCanvas>(find.byType(SpatialCanvas)).dataSource as TaskSpatialDataSource;
      return (dataSource, tagId);
    }

    /// The AnimatedOpacity this card's title sits inside -- `_spotlightGhost`
    /// wraps every task card's whole rendered content (drawing chips and
    /// all), so the title is always a descendant of it.
    double cardOpacity(WidgetTester tester, String title) => tester
        .widget<AnimatedOpacity>(find.ancestor(of: find.text(title), matching: find.byType(AnimatedOpacity)).first)
        .opacity;

    /// Taps a tag chip and pumps past the canvas's tap/double-tap
    /// disambiguation window -- chip taps share that arena with the card's
    /// own recognizers, same as the drawing chips above (see `select()`'s
    /// doc comment in the "card drawing chips" group).
    Future<void> tapTag(WidgetTester tester, String tagName) async {
      await tester.tap(find.text(tagName), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('tapping a tag ghosts cards without it, leaves the matching card at full opacity', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpDeskWithTaggedCards(tester);

      expect(cardOpacity(tester, 'Work card'), 1.0);
      expect(cardOpacity(tester, 'Other card'), 1.0);

      await tapTag(tester, 'work');

      expect(cardOpacity(tester, 'Work card'), 1.0, reason: 'the spotlit card itself must stay full opacity');
      expect(cardOpacity(tester, 'Other card'), kSpotlightGhostOpacity);
    });

    testWidgets('tapping the same tag again clears the spotlight', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (dataSource, tagId) = await pumpDeskWithTaggedCards(tester);

      await tapTag(tester, 'work');
      expect(dataSource.spotlitTag, tagId);
      expect(cardOpacity(tester, 'Other card'), kSpotlightGhostOpacity);

      await tapTag(tester, 'work');
      expect(dataSource.spotlitTag, isNull);
      expect(cardOpacity(tester, 'Work card'), 1.0);
      expect(cardOpacity(tester, 'Other card'), 1.0);
    });

    testWidgets('a felt tap clears the spotlight and un-ghosts everything', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (dataSource, _) = await pumpDeskWithTaggedCards(tester);

      await tapTag(tester, 'work');
      expect(cardOpacity(tester, 'Other card'), kSpotlightGhostOpacity);

      // Exercises the same onCanvasTapped path a real felt tap drives
      // (SpatialCanvas forwards background taps to it) -- called directly
      // on the live data source, the same convention the done-pile tray
      // tests above use for data-source-level interactions.
      dataSource.onCanvasTapped(const Offset(900, 900));
      await tester.pump();

      expect(dataSource.spotlitTag, isNull);
      expect(cardOpacity(tester, 'Work card'), 1.0);
      expect(cardOpacity(tester, 'Other card'), 1.0);
    });
  });
}
