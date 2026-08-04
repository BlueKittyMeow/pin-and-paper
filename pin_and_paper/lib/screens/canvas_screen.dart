import 'package:flutter/material.dart';
import 'package:pin_and_paper_canvas/spatial_canvas.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart';
import 'package:pin_and_paper_sketchpad/sketchpad.dart' show DrawingPreview;
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../models/task_drawing.dart';
import '../providers/task_provider.dart';
import '../services/task_service.dart';
import '../theme/desk_colors.dart';
import 'drawing_editor_screen.dart';
import '../spatial/amethyst_desk_entity.dart';
import '../spatial/spatial_desk_background.dart';
import '../spatial/task_card_adapter.dart';
import '../spatial/task_spatial_data_source.dart';
import '../spatial/task_spatial_entity.dart';

/// Canvas bounds for the Spatial View — matches the canvas module's own
/// `example/` app (DRAG_DROP_CANVAS_MVP_PLAN.md Milestone 4) so gesture feel
/// carries over 1:1 from the module's manual verification pass.
const Size kCanvasScreenSize = Size(2000, 1500);

/// Key on the grey "this card has hidden ink" pencil glyph (owner L10).
/// Stable for tests.
const Key kHiddenDrawingGlyphKey = Key('canvas_screen.hidden_drawing_glyph');

/// The "Spatial View": real tasks as draggable index cards on a pannable,
/// zoomable desk (DRAG_DROP_CANVAS_MVP_PLAN.md Milestone 4).
///
/// Builds a one-time snapshot of `TaskProvider.tasks` and a
/// [TaskSpatialDataSource] from it in [initState] — reopening this screen
/// refreshes the snapshot, but live task edits elsewhere don't appear while
/// it's open (accepted POC limitation, per the plan).
class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  TaskSpatialDataSource? _dataSource;

  TaskProvider? _watchedProvider;
  VoidCallback? _isLoadingListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _armSnapshot());
  }

  /// Snapshots `TaskProvider.tasks` once loading has settled.
  ///
  /// M3/M4 addendum item 7: guard STRICTLY on `TaskProvider.isLoading`
  /// (true only during the very first load, always resolved false in a
  /// `finally`) — never on `tasks.isEmpty`, which would show the
  /// placeholder forever for a legitimately empty (but fully loaded) task
  /// list instead of a correctly-empty desk. A one-shot listener for the
  /// `isLoading -> false` transition is sufficient; no polling or timeout
  /// needed since that flag always resolves.
  void _armSnapshot() {
    if (!mounted) return;
    final taskProvider = context.read<TaskProvider>();
    if (!taskProvider.isLoading) {
      _snapshot(taskProvider);
      return;
    }

    _watchedProvider = taskProvider;
    void listener() {
      if (taskProvider.isLoading) return;
      taskProvider.removeListener(listener);
      _isLoadingListener = null;
      if (mounted) _snapshot(taskProvider);
    }

    _isLoadingListener = listener;
    taskProvider.addListener(listener);
  }

  void _snapshot(TaskProvider taskProvider) {
    setState(() {
      _dataSource = TaskSpatialDataSource(
        tasks: List<Task>.of(taskProvider.tasks),
        taskService: TaskService(),
        canvasSize: kCanvasScreenSize,
      );
    });
  }

  @override
  void dispose() {
    final listener = _isLoadingListener;
    if (listener != null) {
      _watchedProvider?.removeListener(listener);
    }
    _dataSource?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataSource = _dataSource;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spatial View'),
        actions: [
          if (dataSource != null) ...[
            // Quick-scan face overrides: view-only until "kept". Tapping the
            // active one returns to the manual per-card faces.
            // setState on all of these: the toggles repaint these AppBar
            // icons; the canvas itself already rebuilds via the data
            // source's own listeners.
            _FlipModeButton(
              dataSource: dataSource,
              mode: FlipViewMode.allFronts,
              icon: Icons.flip_to_front,
              tooltip: 'Show all fronts',
              onChanged: () => setState(() {}),
            ),
            _FlipModeButton(
              dataSource: dataSource,
              mode: FlipViewMode.allBacks,
              icon: Icons.flip_to_back,
              tooltip: 'Show all backs',
              onChanged: () => setState(() {}),
            ),
            if (dataSource.flipViewMode != FlipViewMode.manual)
              IconButton(
                tooltip: 'Keep these faces',
                icon: const Icon(Icons.check, color: DeskColors.accentGold),
                onPressed: () => setState(dataSource.commitFlipView),
              ),
            IconButton(
              tooltip: dataSource.trayArranged ? 'Restack the inbox' : 'Spread the inbox out',
              icon: Icon(dataSource.trayArranged ? Icons.layers : Icons.grid_view),
              onPressed: () => setState(() => dataSource.setTrayArranged(!dataSource.trayArranged)),
            ),
          ],
        ],
      ),
      body: dataSource == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              // Beyond the canvas edge is the "void" past the desk — same
              // treatment as the canvas module's own example app.
              color: DeskColors.voidBackground,
              child: SpatialCanvas(
                dataSource: dataSource,
                entityBuilder: (entity, isSelected) => _buildCard(context, dataSource, entity, isSelected),
                canvasSize: kCanvasScreenSize,
                background: SpatialDeskBackground(canvasSize: kCanvasScreenSize),
                // The default drag-lift shadow is a rounded rect — right for
                // cards, wrong under the amethyst, which paints its own
                // grounding pool (same suppression as the canvas example).
                liftDecorationBuilder: (entity) => entity is AmethystDeskEntity ? const BoxDecoration() : null,
              ),
            ),
    );
  }

  // FlippableTaskCard (not bare TaskCard) is what makes double-tap-to-flip
  // work — it reads flip state from the data source, same as isSelected
  // reads selection state from the canvas. Card back rows use the POC
  // default (const TaskCardBackFields()) per M3/M4 addendum item 1; a
  // settings-backed preference is a follow-up, not this milestone.
  Widget _buildCard(BuildContext context, TaskSpatialDataSource dataSource, SpatialEntity entity, bool isSelected) {
    if (entity is AmethystDeskEntity) {
      final chunk = AmethystChunk(
        size: entity.size,
        rotationY: entity.rotationY,
        isSelected: isSelected,
        lightAzimuthDegrees: kDeskLightAzimuth,
      );
      if (!isSelected) return chunk;
      // Selected: resize chips, INSIDE the entity's bounds (anything
      // outside a Positioned entity's box is unhittable). Their inner tap
      // recognizers win the arena over the canvas's per-card detector, so
      // tapping a chip resizes without moving/deselecting.
      return Stack(children: [
        Positioned.fill(child: chunk),
        Positioned(
          top: 2,
          right: 2,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _EntityChip(icon: Icons.add, tooltip: 'Bigger', onTap: () => dataSource.resizeAmethyst(1.15)),
            const SizedBox(height: 4),
            _EntityChip(icon: Icons.remove, tooltip: 'Smaller', onTap: () => dataSource.resizeAmethyst(1 / 1.15)),
          ]),
        ),
      ]);
    }
    final taskEntity = entity as TaskSpatialEntity;
    final taskProvider = context.read<TaskProvider>();
    final id = taskEntity.id;
    final showBack = dataSource.isFlipped(id);
    final data = taskToCardData(taskEntity.task, taskProvider.getTagsForTask(id));

    // Card drawings (M-D5): a face's ink renders as a DrawingPreview
    // overlay when that face has a drawing AND it isn't toggled hidden.
    // The data source hands back a CACHED LayerStack instance per face, so
    // the preview's recorded picture survives rebuilds (pans/drags) instead
    // of re-tessellating per frame.
    Widget? overlayFor(String face) {
      if (!dataSource.isDrawingVisible(id, face: face)) return null;
      final stack = dataSource.drawingStackFor(id, face: face);
      if (stack == null) return null;
      return DrawingPreview(layerStack: stack, size: kCardSize);
    }

    final card = FlippableTaskCard(
      data: data,
      showBack: showBack,
      isSelected: isSelected,
      frontOverlay: overlayFor(TaskDrawing.faceFront),
      backOverlay: overlayFor(TaskDrawing.faceBack),
    );

    final hasHidden = dataSource.hasHiddenDrawing(id);
    if (!isSelected && !hasHidden) return card;

    // Chips act on the face currently showing: draw on (or show/hide) the
    // front normally, the back when the card is flipped (owner L1).
    final face = showBack ? TaskDrawing.faceBack : TaskDrawing.faceFront;
    final hasDrawing = dataSource.drawingJsonFor(id, face: face) != null;
    final drawingVisible = dataSource.isDrawingVisible(id, face: face);
    return Stack(children: [
      Positioned.fill(child: card),
      // Owner L10 tell: hidden ink gets a small grey pencil glyph.
      // Bottom-right corner — the chips live top-right, the due date
      // bottom-left, so nothing collides.
      if (hasHidden)
        const Positioned(
          right: 5,
          bottom: 5,
          child: IgnorePointer(
            child: Icon(
              Icons.edit,
              key: kHiddenDrawingGlyphKey,
              size: 12,
              color: DeskColors.hiddenDrawingGlyph,
            ),
          ),
        ),
      // Selected-card controls, INSIDE the card bounds (same arena rules
      // as the amethyst's chips above): pencil opens the editor for the
      // showing face; the eye — only when that face has a drawing —
      // toggles its visibility.
      if (isSelected)
        Positioned(
          top: 8,
          right: 4,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _EntityChip(
              icon: Icons.edit,
              tooltip: 'Draw on this card',
              onTap: () => _openDrawingEditor(dataSource, id, face, data),
            ),
            if (hasDrawing) ...[
              const SizedBox(height: 4),
              _EntityChip(
                icon: drawingVisible ? Icons.visibility : Icons.visibility_off,
                tooltip: drawingVisible ? 'Hide drawing' : 'Show drawing',
                onTap: () => dataSource.toggleDrawingVisible(id, face: face),
              ),
            ],
          ]),
        ),
    ]);
  }

  /// Pushes the full-screen drawing editor for [face] of task [taskId];
  /// on a saved change, re-reads that task's drawing rows so the card's
  /// overlay (and chips) reflect the fresh ink.
  Future<void> _openDrawingEditor(
    TaskSpatialDataSource dataSource,
    String taskId,
    String face,
    TaskCardData data,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DrawingEditorScreen(
          taskId: taskId,
          cardData: data,
          face: face,
          existingDrawingJson: dataSource.drawingJsonFor(taskId, face: face),
        ),
      ),
    );
    if (changed == true) {
      await dataSource.refreshDrawingFor(taskId); // notifies the canvas
      if (mounted) setState(() {});
    }
  }
}

/// One of the two quick-scan face-override AppBar buttons. Active mode
/// glows accent gold; tapping the active mode returns to manual per-card
/// faces.
class _FlipModeButton extends StatelessWidget {
  const _FlipModeButton({
    required this.dataSource,
    required this.mode,
    required this.icon,
    required this.tooltip,
    required this.onChanged,
  });

  final TaskSpatialDataSource dataSource;
  final FlipViewMode mode;
  final IconData icon;
  final String tooltip;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final active = dataSource.flipViewMode == mode;
    return IconButton(
      tooltip: active ? 'Back to your flips' : tooltip,
      icon: Icon(icon, color: active ? DeskColors.accentGold : null),
      onPressed: () {
        dataSource.setFlipViewMode(active ? FlipViewMode.manual : mode);
        onChanged();
      },
    );
  }
}

/// Small circular control shown on a selected entity (amethyst resize,
/// card draw/eye). Amber on dark, matching the app's accent language;
/// deliberately tiny so it reads as a handle, not a toolbar. Placed INSIDE
/// the entity's bounds; its inner tap recognizer wins the arena over the
/// canvas's per-entity detector. (Ported with the stone from the canvas
/// example app as _ResizeChip; generalized for the M-D5 card chips.)
class _EntityChip extends StatelessWidget {
  const _EntityChip({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: DeskColors.chipBackground,
            shape: BoxShape.circle,
            border: Border.all(color: DeskColors.accentGold, width: 1),
          ),
          child: Icon(icon, size: 14, color: DeskColors.accentGold),
        ),
      ),
    );
  }
}
