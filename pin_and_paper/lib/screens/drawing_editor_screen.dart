import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart';
import 'package:pin_and_paper_sketchpad/sketchpad.dart';

import '../models/task_drawing.dart';
import '../services/drawing_service.dart';
import '../theme/desk_colors.dart';

/// Default capture-space size for a brand-new card drawing: the 220x140
/// card face at 4x — comfortable inking room on tablet/desktop
/// (CARD_DRAWINGS_PLAN.md §3: 220x140 is uselessly small to ink directly).
const Size kDrawingEditorCaptureSize = Size(880, 560);

/// Key for the stylus-only / finger-inking policy toggle in the AppBar
/// (owner L6). Stable for tests.
const Key kDrawingEditorTouchToggleKey = Key('drawing_editor.touch_toggle');

/// Key for the save-and-close button (also reachable via system back).
const Key kDrawingEditorDoneKey = Key('drawing_editor.done');

/// Full-screen modal drawing editor for one face of one task card
/// (CARD_DRAWINGS_PLAN.md M-D5).
///
/// The real card face — `TaskCard` for 'front', `TaskCardBack` for 'back'
/// (owner L2) — renders as a non-interactive backdrop under the sketchpad's
/// live [DrawingCanvas], scaled so ink lands relative to real content. The
/// full three-layer [DrawingToolbar] (owner L3) sits below, with
/// cross-layer chronological undo/redo via [LayerStack.undo]/[LayerStack
/// .redo].
///
/// Input policy (owner L6): stylus-only by default — touch inking is
/// rejected (a resting palm or stray finger never inks), while stylus and
/// mouse (Linux desktop has no stylus) always ink. A visible AppBar toggle
/// allows finger inking; even then a second finger landing mid-stroke
/// cancels it, so two-finger gestures never leave ink — instead, 2+
/// simultaneous touches drive pinch-to-zoom/pan on the drawing surface
/// (owner 2026-08-06, see [_PinchZoomView]), in either touch-ink mode.
///
/// Closing (AppBar done or system back) saves and pops with a bool
/// "changed" result: true only when a row was actually written. A drawing
/// with no strokes and no pre-existing row writes NOTHING (agy-endorsed
/// empty-drawings-stay-NULL rule); an intentionally emptied existing
/// drawing still saves.
class DrawingEditorScreen extends StatefulWidget {
  const DrawingEditorScreen({
    super.key,
    required this.taskId,
    required this.cardData,
    this.face = TaskDrawing.faceFront,
    this.existingDrawingJson,
    this.backFields = const TaskCardBackFields(),
    DrawingService? drawingService,
  }) : _drawingService = drawingService;

  /// Task whose card face is being drawn on.
  final String taskId;

  /// Render data for the backdrop card face.
  final TaskCardData cardData;

  /// Which face is being drawn on: [TaskDrawing.faceFront] or
  /// [TaskDrawing.faceBack].
  final String face;

  /// The face's stored drawing JSON (format v1), or null when the face has
  /// none yet.
  final String? existingDrawingJson;

  /// Back-face row config for the backdrop when [face] is 'back'.
  final TaskCardBackFields backFields;

  final DrawingService? _drawingService;

  @override
  State<DrawingEditorScreen> createState() => _DrawingEditorScreenState();
}

class _DrawingEditorScreenState extends State<DrawingEditorScreen> {
  late final DrawingService _drawingService;
  late final LayerStack _stack;

  /// Capture-space size all strokes are recorded in. From the existing
  /// drawing's stored size when editing (so old strokes and new strokes
  /// share one coordinate space), else [kDrawingEditorCaptureSize].
  late final Size _captureSize;

  /// Whether a row already existed for this (task, face) when the editor
  /// opened — drives the empty-drawings-stay-NULL save rule.
  late final bool _hadExistingRow;

  Color _currentColor = const Color(0xFF2D2D2D); // toolbar's near-black ink
  StrokeOptions _currentOptions = StrokeOptions.ink;
  bool _eraserActive = false;

  /// Owner L6 input policy: false = stylus-only (touch inking rejected).
  bool _allowTouchInking = false;

  /// Touch pointers currently down, any count. Distinguishes a lone
  /// accidental touch (rejected per stylus-only policy, or inked in
  /// finger mode) from a 2+-finger pinch/pan gesture (owner 2026-08-06:
  /// always a zoom gesture, never inking, regardless of the touch-ink
  /// toggle) — see [_handlePolicyPointerDown].
  final Set<int> _activeTouchPointers = {};

  /// Lets [_handlePolicyPointerDown] discard a wet stroke when a second
  /// finger turns a would-be ink gesture into a pinch, without calling
  /// `GestureBinding.cancelPointer` — a binding-level cancel would also
  /// stop the [InteractiveViewer] zoom gesture from tracking that same
  /// pointer (see [DrawingCanvasController]'s doc comment).
  final DrawingCanvasController _canvasController = DrawingCanvasController();

  bool _closing = false;

  /// Wraps the widget-rendered backdrop face (see [_buildBackdropFace])
  /// so [_captureBackdrop] can rasterize it — see that method's doc
  /// comment for why a snapshot is needed in addition to the live widget.
  final GlobalKey _backdropCaptureKey = GlobalKey();

  /// Raster snapshot of [_buildBackdropFace], at [_captureSize]
  /// resolution, handed to [DrawingCanvas] as its multiply-blend backdrop
  /// (owner report 2026-08-06, fixed 2026-08-07: a "Blend"/Marker layer
  /// must show the real card through it, like a highlighter, not a fixed
  /// flat paper tone). Null until the first frame's post-frame callback
  /// captures it; a multiply layer painted before then falls back to the
  /// sketchpad's flat-paper precompute (see stroke_painter.dart), same as
  /// pre-fix behavior — never a crash or a blank stroke.
  ui.Image? _backdropImage;

  @override
  void initState() {
    super.initState();
    _drawingService = widget._drawingService ?? DrawingService();
    final json = widget.existingDrawingJson;
    _hadExistingRow = json != null;
    LayerStack? restored;
    if (json != null) {
      try {
        restored = LayerStack.fromJson(jsonDecode(json) as Map<String, dynamic>);
      } catch (e) {
        // A corrupt row shouldn't brick the editor; start fresh. The old
        // row is only overwritten if the user actually draws and saves.
        debugPrint('DrawingEditorScreen: unreadable existing drawing, starting fresh: $e');
      }
    }
    // Explicit size (never left for DrawingCanvas to stamp): the surface
    // below is laid out at exactly this logical size, so strokes, backdrop,
    // and serialization all agree on one capture space.
    _stack = restored ?? LayerStack(size: kDrawingEditorCaptureSize);
    _captureSize = _stack.size ?? kDrawingEditorCaptureSize;
    _stack.size ??= _captureSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureBackdrop());
  }

  /// Bails [_captureBackdrop]'s "wait for a clean paint" retry rather than
  /// rescheduling forever if something keeps the boundary dirty every
  /// frame — a missed backdrop just means multiply layers keep using the
  /// flat-paper fallback, never a crash or a stuck frame-callback loop.
  static const int _maxBackdropCaptureAttempts = 60;
  int _backdropCaptureAttempts = 0;

  /// Rasterize [_buildBackdropFace] (the real card face, already laid out
  /// at [_captureSize] under [_backdropCaptureKey]'s RepaintBoundary — see
  /// `_buildSurface`) into a `ui.Image` so the sketchpad can multiply-blend
  /// a "Blend"/Marker layer against the REAL card instead of a flat paper
  /// swatch. `pixelRatio: 1.0` makes the image exactly [_captureSize] in
  /// pixels — the same coordinate space strokes are recorded in — so
  /// `DrawingCanvas`/`paintLayerStack` can draw it 1:1 under the ink with
  /// no further scale math.
  ///
  /// [RenderRepaintBoundary.toImage] requires `!debugNeedsPaint` — a
  /// postFrameCallback normally guarantees that, but doesn't always land
  /// on a fully clean boundary the very first time (observed here: the
  /// widget test harness's `pumpAndSettle` needed a couple of extra
  /// frames). Reschedule to the next frame instead of giving up on one
  /// dirty check, capped at [_maxBackdropCaptureAttempts] frames.
  ///
  /// The card face is static for the life of this screen (built once from
  /// `widget.cardData`/`widget.backFields`, never mutated here), so one
  /// successful capture is enough — no need to re-capture on every
  /// rebuild.
  Future<void> _captureBackdrop() async {
    final renderObject = _backdropCaptureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;
    if (renderObject.debugNeedsPaint) {
      if (!mounted || _backdropCaptureAttempts >= _maxBackdropCaptureAttempts) {
        return;
      }
      _backdropCaptureAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _captureBackdrop());
      return;
    }
    final ui.Image image;
    try {
      image = await renderObject.toImage(pixelRatio: 1.0);
    } catch (e) {
      // Best-effort only: a failed capture just means multiply layers
      // keep using the flat-paper precompute fallback, never a crash.
      debugPrint('DrawingEditorScreen: backdrop capture failed: $e');
      return;
    }
    if (!mounted) {
      image.dispose();
      return;
    }
    final old = _backdropImage;
    setState(() => _backdropImage = image);
    old?.dispose();
  }

  @override
  void dispose() {
    _canvasController.dispose();
    _backdropImage?.dispose();
    super.dispose();
  }

  // -- Input policy (owner L6) -------------------------------------------
  //
  // The sketchpad module's DrawingCanvas accepts every pointer kind, and
  // this milestone consumes the module read-only — so policy is enforced
  // from outside: a wrapping Listener sees each pointer-down right after
  // the canvas does, and rejects disallowed touches by discarding any wet
  // stroke via [_canvasController.cancelActiveStroke] — see that
  // controller's doc comment for exactly what that does inside the
  // canvas.
  //
  // Pinch-to-zoom rewrite (owner 2026-08-06): this USED to reject a touch
  // with `GestureBinding.instance.cancelPointer`, which kills the pointer
  // at the Flutter binding level — fine when touch could only ever mean
  // "ink or not", but wrong now that a lone rejected finger might become
  // the FIRST finger of a two-finger pinch a moment later: cancelling it
  // immediately (before the second finger even arrives) permanently drops
  // it from _PinchZoomView's scale-gesture tracking, so the pinch could
  // never register any scale at all — caught by this screen's own pinch
  // test failing outright (scale stuck at 1.0) after the naive port of
  // the old single-finger-only cancelPointer logic. Rejecting through
  // _canvasController instead only touches the sketchpad's own
  // in-progress-stroke state; the raw pointer is never cancelled, so it
  // stays available if a second finger turns the gesture into a pinch.

  static bool _isTouch(PointerDeviceKind kind) => kind == PointerDeviceKind.touch;

  void _handlePolicyPointerDown(PointerDownEvent event) {
    if (!_isTouch(event.kind)) return; // stylus + mouse always ink
    _activeTouchPointers.add(event.pointer);

    final isMultiFinger = _activeTouchPointers.length >= 2;
    // Reject ink when: 2+ fingers are down (always a pinch/pan gesture,
    // never ink, in EITHER touch-ink mode), OR it's a lone finger and
    // stylus-only mode is active. A lone finger in finger-mode is left
    // alone — it inks normally.
    if (isMultiFinger || !_allowTouchInking) {
      _canvasController.cancelActiveStroke();
    }
  }

  void _handlePolicyPointerEnd(int pointer) {
    _activeTouchPointers.remove(pointer);
  }

  // -- Save-on-close ------------------------------------------------------

  Future<void> _saveAndClose() async {
    if (_closing) return;
    _closing = true;
    final changed = await _persistIfNeeded();
    if (!mounted) return;
    Navigator.of(context).pop(changed);
  }

  /// Writes the drawing if (and only if) it should be written; returns
  /// whether a row was written (the caller's "changed" flag).
  Future<bool> _persistIfNeeded() async {
    // Untouched session: LayerStack.revision counts every content
    // mutation (strokes, undo/redo, clears, layer visibility/blend), so 0
    // means nothing to persist — even for an existing drawing.
    if (_stack.revision == 0) return false;
    final hasStrokes = _stack.layers.any((l) => l.strokes.isNotEmpty);
    if (!hasStrokes && !_hadExistingRow) {
      // Empty drawings stay NULL: never materialize a row for a doodle
      // that was started and fully undone/never made.
      return false;
    }
    // An emptied EXISTING drawing still saves — the user deliberately
    // erased it, and the row keeps its visibility/position metadata.
    try {
      await _drawingService.saveTaskDrawing(
        widget.taskId,
        jsonEncode(_stack.toJson()),
        face: widget.face,
      );
      return true;
    } catch (e) {
      debugPrint('DrawingEditorScreen: failed to save drawing for ${widget.taskId}/${widget.face}: $e');
      return false;
    }
  }

  // -- Layout -------------------------------------------------------------

  /// Display scale for the drawing surface: the largest card-relative
  /// scale that fits [avail] with letterboxing, floored to half steps when
  /// there's room ("integer-ish" — crisp 3.5x/4x on desktop/tablet) and
  /// exact-fit below 1x card scale (tiny phones still get the whole card).
  double _displayCardScale(Size avail) {
    final raw = math.min(avail.width / kCardSize.width, avail.height / kCardSize.height);
    if (raw <= 1.0) return raw;
    final stepped = (raw * 2).floorToDouble() / 2;
    return math.max(stepped, 1.0);
  }

  Widget _buildBackdropFace() {
    return widget.face == TaskDrawing.faceBack
        ? TaskCardBack(data: widget.cardData, fields: widget.backFields)
        : TaskCard(data: widget.cardData);
  }

  Widget _buildSurface() {
    return SizedBox(
      width: _captureSize.width,
      height: _captureSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Owner L2: the REAL card face under the ink, scaled up from its
          // 220x140 footprint to the capture space, so strokes land
          // relative to real content. IgnorePointer: it's a backdrop, not
          // a card. RepaintBoundary + key: also lets _captureBackdrop
          // rasterize this SAME widget for DrawingCanvas's multiply-blend
          // backdrop (owner report 2026-08-06, fixed 2026-08-07) — the
          // visible widget and the blend-math snapshot are one render,
          // not two, so they can never drift out of sync.
          IgnorePointer(
            child: RepaintBoundary(
              key: _backdropCaptureKey,
              child: FittedBox(fit: BoxFit.fill, child: _buildBackdropFace()),
            ),
          ),
          Listener(
            onPointerDown: _handlePolicyPointerDown,
            onPointerUp: (e) => _handlePolicyPointerEnd(e.pointer),
            onPointerCancel: (e) => _handlePolicyPointerEnd(e.pointer),
            child: DrawingCanvas(
              layerStack: _stack,
              currentColor: _currentColor,
              strokeOptions: _currentOptions,
              isEraserActive: _eraserActive,
              onStrokeComplete: () => setState(() {}),
              controller: _canvasController,
              backdropImage: _backdropImage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faceLabel = widget.face == TaskDrawing.faceBack ? 'back' : 'front';
    return PopScope(
      // System back must run the same save path as the done button.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: DeskColors.voidBackground,
        appBar: AppBar(
          leading: IconButton(
            key: kDrawingEditorDoneKey,
            tooltip: 'Save and close',
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveAndClose,
          ),
          title: Text('Draw — $faceLabel of card'),
          actions: [
            IconButton(
              key: kDrawingEditorTouchToggleKey,
              tooltip: _allowTouchInking
                  ? 'Finger drawing on — tap for stylus-only'
                  : 'Stylus-only — tap to allow finger drawing',
              icon: Icon(
                _allowTouchInking ? Icons.touch_app : Icons.touch_app_outlined,
                color: _allowTouchInking ? DeskColors.accentGold : null,
              ),
              onPressed: () => setState(() => _allowTouchInking = !_allowTouchInking),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = _displayCardScale(constraints.biggest);
                    final display = Size(kCardSize.width * scale, kCardSize.height * scale);
                    return Center(
                      // FittedBox maps the fixed capture space onto the
                      // letterboxed display box; pointer positions arrive
                      // in capture coordinates automatically, so stroke
                      // JSON is display-scale-independent. _PinchZoomView
                      // wraps that mapped box for pinch-to-zoom (owner
                      // 2026-08-06): it doesn't change the child's layout
                      // constraints, only its paint-time transform, so the
                      // capture space and stroke coordinates above are
                      // completely unaffected by the current zoom level —
                      // canvas-style zoom, not a data transform. It's
                      // gated to 2+ finger gestures only, so single-finger
                      // drags stay free for drawing/the touch-ink policy,
                      // and the focal point (hence pan) follows the
                      // fingers naturally while pinching — see
                      // _PinchZoomView's doc comment for why this is a
                      // small hand-rolled widget instead of Flutter's
                      // InteractiveViewer.
                      child: SizedBox(
                        width: display.width,
                        height: display.height,
                        child: _PinchZoomView(
                          minScale: 1.0,
                          maxScale: 5.0,
                          child: FittedBox(fit: BoxFit.fill, child: _buildSurface()),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            DrawingToolbar(
              layerStack: _stack,
              currentColor: _currentColor,
              currentOptions: _currentOptions,
              useBlend: _stack.activeLayer.blendMode == BlendMode.multiply,
              onColorChanged: (color) => setState(() => _currentColor = color),
              onOptionsChanged: (options) => setState(() {
                _currentOptions = options;
                _eraserActive = false;
              }),
              isEraserActive: _eraserActive,
              onEraserToggled: (active) => setState(() => _eraserActive = active),
              onLayerSelected: (index) => setState(() {
                _stack.setActiveLayer(index);
                _currentOptions = _stack.activeLayer.defaultOptions;
                _eraserActive = false;
              }),
              onVisibilityToggled: (index) => setState(() => _stack.toggleLayerVisibility(index)),
              onBlendChanged: (blend) => setState(() {
                // toggleBlendMode (not a raw field write) so the change
                // bumps LayerStack.revision — blend is serialized state.
                if ((_stack.activeLayer.blendMode == BlendMode.multiply) != blend) {
                  _stack.toggleBlendMode(_stack.activeLayerIndex);
                }
              }),
              onUndo: () => setState(_stack.undo),
              canUndo: _stack.canUndo,
              onRedo: () => setState(_stack.redo),
              canRedo: _stack.canRedo,
              onClear: () => setState(_stack.clearActiveLayer),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal two-finger pinch-to-zoom/pan wrapper (owner request, 2026-08-06:
/// "pinch-to-zoom inside the drawing widget while editing... pan should
/// come along naturally if the gesture system allows").
///
/// Deliberately NOT Flutter's built-in [InteractiveViewer]. That widget
/// needs `panEnabled: false` here (a single finger must stay free for
/// drawing/ink — see [_DrawingEditorScreenState._handlePolicyPointerDown]),
/// and with `panEnabled: false` it has a reproducible framework bug: the
/// very first update of a two-finger gesture can throw `Failed assertion:
/// 'scale != 0.0'` inside `_InteractiveViewerState._matrixScale`
/// (flutter/packages/flutter/lib/src/widgets/interactive_viewer.dart,
/// stable 3.35.7) — not a theoretical edge case, this screen's own
/// existing two-finger test ("finger mode inks with touch, but a second
/// finger cancels the stroke") hits it every run once InteractiveViewer is
/// introduced. Rather than ship a widget that crashes on the exact gesture
/// this feature exists for, this reimplements just the slice needed here:
/// a uniform scale + translation, driven by [GestureDetector]'s scale
/// gesture but gated strictly to `details.pointerCount >= 2`, so a lone
/// finger is never touched by it and single-finger drawing/ink is
/// completely unaffected.
class _PinchZoomView extends StatefulWidget {
  const _PinchZoomView({
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 5.0,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  State<_PinchZoomView> createState() => _PinchZoomViewState();
}

class _PinchZoomViewState extends State<_PinchZoomView> {
  double _scale = 1.0;
  Offset _translation = Offset.zero;

  /// Captured at gesture start: the view scale to multiply
  /// `details.scale` against (scale gestures report cumulative change
  /// from gesture start, not frame-to-frame).
  double _gestureStartScale = 1.0;

  /// The content-space point under the fingers when the gesture started.
  /// Recomputing the translation to keep this point under the current
  /// focal point every update is what makes the zoom center on the
  /// fingers and pan "come along naturally" as they drag.
  Offset _gestureContentFocalPoint = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureContentFocalPoint =
        (details.localFocalPoint - _translation) / _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewport) {
    // A lone finger never zooms/pans here — reserved for drawing/ink,
    // the equivalent of InteractiveViewer's panEnabled: false.
    if (details.pointerCount < 2) return;
    // Guards the exact degenerate span InteractiveViewer's assertion
    // crashes on (see class doc comment) — skip rather than apply a
    // zero/negative scale for this one frame.
    if (details.scale <= 0) return;

    final newScale = (_gestureStartScale * details.scale)
        .clamp(widget.minScale, widget.maxScale);
    final rawTranslation =
        details.localFocalPoint - _gestureContentFocalPoint * newScale;

    setState(() {
      _scale = newScale;
      _translation = _clampTranslation(rawTranslation, newScale, viewport);
    });
  }

  /// Keeps the content from being pinch-panned entirely out of view.
  /// [minScale] >= 1.0 is assumed (content is always >= viewport size),
  /// so there's always a valid (non-inverted) clamp range.
  Offset _clampTranslation(Offset t, double scale, Size viewport) {
    const margin = 64.0;
    final minDx = viewport.width - viewport.width * scale - margin;
    final minDy = viewport.height - viewport.height * scale - margin;
    return Offset(t.dx.clamp(minDx, margin), t.dy.clamp(minDy, margin));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final viewport = constraints.biggest;
      return GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: (details) => _onScaleUpdate(details, viewport),
        child: ClipRect(
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(_translation.dx, _translation.dy, 0, 1)
              ..scaleByDouble(_scale, _scale, _scale, 1),
            child: widget.child,
          ),
        ),
      );
    });
  }
}
