import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_and_paper/rendering/backdrop_capture.dart';

/// [captureBackdrop] exists to replace a capture path
/// (drawing_editor_screen.dart, pre-2026-08-08) that gated its retry loop
/// on `RenderObject.debugNeedsPaint` — a debug-only getter whose only
/// assignment lives inside an `assert(...)` closure, so it throws
/// `LateInitializationError` on every access once asserts are stripped
/// (release/profile builds). That passed every widget test (which always
/// run with asserts enabled) while silently never capturing anything on
/// the owner's phone. See `captureBackdrop`'s doc comment for the full
/// mechanism.
///
/// These tests can't reproduce the release-mode assert-stripping itself
/// (flutter_test always runs asserts-on), so they instead pin down the
/// contract the helper promises regardless of that: it captures real,
/// correctly-sized content when a boundary is mounted and painted, and it
/// resolves to `null` — never throws, never hangs — when there's nothing
/// to capture.
///
/// [captureBackdrop] self-schedules the frame its `addPostFrameCallback`
/// needs (see its doc comment) rather than assuming one is already in
/// flight, so a plain `pumpAndSettle` — same convention
/// `drawing_editor_screen_test.dart` uses for this exact capture path in
/// the live editor — is enough here too, no `runAsync` needed for
/// `flutter_tester`'s software-rendered `toImage` to resolve.
Future<ui.Image?> captureAndSettle(WidgetTester tester, GlobalKey key) async {
  ui.Image? result;
  captureBackdrop(key).then((image) => result = image);
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('captures a real, correctly-sized image of a painted '
      'RepaintBoundary', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 40,
            height: 20,
            child: RepaintBoundary(
              key: key,
              child: Container(color: const Color(0xFF4080C0)),
            ),
          ),
        ),
      ),
    );

    final image = await captureAndSettle(tester, key);
    expect(image, isNotNull);
    addTearDown(() => image!.dispose());
    expect(image!.width, 40);
    expect(image.height, 20);

    final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba));
    // Fully opaque, uniformly the container's own color -- proves this is
    // the REAL painted content, not a blank/transparent placeholder.
    expect(bytes!.getUint8(3), 255); // alpha
    expect(bytes.getUint8(0), 0x40); // R
    expect(bytes.getUint8(1), 0x80); // G
    expect(bytes.getUint8(2), 0xC0); // B
  });

  testWidgets('resolves to null (never throws) when the key never attaches '
      'to anything', (tester) async {
    // An empty tree still lets SchedulerBinding drive frames/postFrame
    // callbacks -- pumpWidget establishes one so `tester.pump()` inside
    // captureAndSettle has something to draw.
    await tester.pumpWidget(const SizedBox.shrink());
    final key = GlobalKey(); // never used in any pumped widget tree

    final image = await captureAndSettle(tester, key);
    expect(image, isNull);
  });

  testWidgets('resolves to null when the widget is disposed before a '
      'capture completes', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: Container(color: const Color(0xFF4080C0), width: 10, height: 10),
        ),
      ),
    );

    // Tear the boundary out of the tree immediately, before the capture's
    // first postFrameCallback can even run.
    await tester.pumpWidget(const SizedBox.shrink());

    final image = await captureAndSettle(tester, key);
    expect(image, isNull);
  });
}
