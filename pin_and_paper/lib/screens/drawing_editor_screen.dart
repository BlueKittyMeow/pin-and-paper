import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
/// cancels it, so two-finger gestures never leave ink.
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

  /// The touch pointer currently allowed to ink (finger mode only) — a
  /// second concurrent touch cancels it so two-finger gestures never ink.
  int? _activeTouchPointer;

  bool _closing = false;

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
  }

  // -- Input policy (owner L6) -------------------------------------------
  //
  // The sketchpad module's DrawingCanvas accepts every pointer kind, and
  // this milestone consumes the module read-only — so policy is enforced
  // from outside: a wrapping Listener sees each pointer-down right after
  // the canvas does, and kills disallowed pointers with
  // GestureBinding.cancelPointer. The canvas's own onPointerCancel then
  // discards the in-progress stroke (and ignores the pointer's remaining
  // events), so a rejected touch never commits ink.

  static bool _isTouch(PointerDeviceKind kind) => kind == PointerDeviceKind.touch;

  void _handlePolicyPointerDown(PointerDownEvent event) {
    if (!_isTouch(event.kind)) return; // stylus + mouse always ink
    if (!_allowTouchInking) {
      GestureBinding.instance.cancelPointer(event.pointer);
      return;
    }
    if (_activeTouchPointer != null) {
      // Second finger mid-stroke: this is a gesture, not ink. Cancel both
      // pointers — the canvas discards the wet stroke.
      GestureBinding.instance.cancelPointer(_activeTouchPointer!);
      GestureBinding.instance.cancelPointer(event.pointer);
      _activeTouchPointer = null;
      return;
    }
    _activeTouchPointer = event.pointer;
  }

  void _handlePolicyPointerEnd(int pointer) {
    if (pointer == _activeTouchPointer) _activeTouchPointer = null;
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
          // a card.
          IgnorePointer(
            child: FittedBox(fit: BoxFit.fill, child: _buildBackdropFace()),
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
                      // JSON is display-scale-independent.
                      child: SizedBox(
                        width: display.width,
                        height: display.height,
                        child: FittedBox(fit: BoxFit.fill, child: _buildSurface()),
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
