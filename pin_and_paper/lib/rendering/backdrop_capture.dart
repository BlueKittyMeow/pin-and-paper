import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

/// Maximum `addPostFrameCallback` retries [captureBackdrop] will spend
/// waiting for a [RepaintBoundary] to complete a real paint pass before
/// giving up. ~1 second at 60fps on-device — generous for a first paint
/// delayed by a busy frame, small enough that a genuine failure doesn't
/// retry forever.
const int kBackdropCaptureMaxAttempts = 60;

/// Rasterize the [RepaintBoundary] identified by [key] into a `ui.Image`,
/// at [pixelRatio] (1.0 — the default — means one image pixel per logical
/// pixel of the boundary's own laid-out size, independent of the device's
/// `devicePixelRatio`; that's the coordinate space `paintLayerStack`'s
/// `backdropImage`/`bounds` expect, so callers generally don't need any
/// further scale math).
///
/// Returns `null` (never throws) if the boundary never manages a
/// successful capture within [maxAttempts] frames, or if [key]'s context
/// disappears (widget disposed) before one does. Callers should treat
/// `null` as "no backdrop available" and fall back gracefully — never a
/// crash.
///
/// -- Why this exists instead of the obvious `if (!debugNeedsPaint) ...`
/// check --
///
/// `RenderRepaintBoundary.toImage`'s own doc comment says "the render
/// object must have completed at least one paint (i.e. `debugNeedsPaint`
/// must be false)" — so an earlier version of this capture path
/// (drawing_editor_screen.dart, 2026-08-07) gated its retry loop on
/// exactly that: `if (renderObject.debugNeedsPaint) { retry } else {
/// toImage() }`.
///
/// That looks reasonable and PASSED every widget test, but did not work
/// on the owner's phone at all ("blend still does not blend with card
/// itself, tried a few colors and nada", 2026-08-07). Root cause:
/// `RenderObject.debugNeedsPaint` is a debug-only getter —
/// flutter/packages/flutter/lib/src/rendering/object.dart:
///
/// ```dart
/// bool get debugNeedsPaint {
///   late bool result;
///   assert(() {
///     result = _needsPaint;
///     return true;
///   }());
///   return result;
/// }
/// ```
///
/// The ONLY assignment to `result` happens inside an `assert(...)`
/// closure. Flutter release (and profile) builds strip every `assert`
/// statement entirely — the closure never runs — so `result` is never
/// initialized, and reading `debugNeedsPaint` throws
/// `LateInitializationError: Field 'result' has not been initialized.`
/// on every single call, in every release build, unconditionally.
/// `flutter test` always runs with assertions enabled, so no test could
/// ever see this: the bug is invisible everywhere except a release APK,
/// which is exactly the gap between "tests pass" and "owner's phone
/// build does nothing".
///
/// The fix: never branch on a debug-only getter for production control
/// flow. Just attempt [RenderRepaintBoundary.toImage] directly — it
/// throws on its own (null-checking a not-yet-assigned `layer`) if the
/// boundary hasn't painted yet, which is a perfectly good, release-safe
/// "not ready" signal — and retry on that failure via
/// `addPostFrameCallback`, capped at [maxAttempts].
Future<ui.Image?> captureBackdrop(
  GlobalKey key, {
  double pixelRatio = 1.0,
  int maxAttempts = kBackdropCaptureMaxAttempts,
}) {
  final completer = Completer<ui.Image?>();
  var attempts = 0;

  // `attempt` and `retryOrGiveUp` call each other, so at least one needs a
  // forward reference — a `late` variable (assigned its closure below,
  // before it's ever CALLED) makes that legal, unlike two mutually
  // recursive local function DECLARATIONS.
  late void Function() attempt;

  // `addPostFrameCallback` fires at the end of the NEXT drawn frame —
  // but registering it doesn't by itself cause a frame to be drawn (a
  // frame only gets drawn `if (hasScheduledFrame)`). Every real call
  // site today happens to call [captureBackdrop] from `initState`/
  // `build`, where a frame is already in flight, so this would often
  // work by accident even without the explicit `scheduleFrame()` call
  // below — but "often" isn't good enough for a helper whose whole job
  // is reliability, and it silently doesn't hold for a RETRY (there's no
  // guarantee anything else in the app schedules a further frame before
  // this one would need to fire) or for a caller with no ambient frame
  // at all (exactly the situation in this file's own unit tests, which
  // is how this gap was actually found — see backdrop_capture_test.dart).
  // Calling `scheduleFrame()` here makes the "call this, get an answer"
  // contract true unconditionally, independent of caller context.
  void scheduleAttempt() {
    SchedulerBinding.instance.addPostFrameCallback((_) => attempt());
    SchedulerBinding.instance.scheduleFrame();
  }

  void giveUp() {
    if (!completer.isCompleted) completer.complete(null);
  }

  void retryOrGiveUp() {
    attempts++;
    if (attempts >= maxAttempts) {
      giveUp();
      return;
    }
    scheduleAttempt();
  }

  attempt = () {
    if (completer.isCompleted) return; // Defensive: shouldn't happen.
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      // Context is gone (widget disposed) or never attached — nothing to
      // retry against, matches the pre-fix "bail out silently" behavior.
      giveUp();
      return;
    }
    Future<ui.Image> future;
    try {
      // toImage() itself does `assert(!debugNeedsPaint)` — also stripped
      // in release, but harmlessly so, since it's ONLY a sanity check
      // there; the real gate is `layer! as OffsetLayer` right after it,
      // which throws for real (a normal null-check, not assert-gated) if
      // this boundary hasn't painted. That's the signal we actually rely
      // on below.
      future = renderObject.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      retryOrGiveUp();
      return;
    }
    future.then(
      (image) {
        if (!completer.isCompleted) completer.complete(image);
      },
      onError: (Object _) => retryOrGiveUp(),
    );
  };

  scheduleAttempt();
  return completer.future;
}
