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
import '../spatial/dachshund_desk_entity.dart';
import '../spatial/desk_object_entity.dart';
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

/// Key on the desk-objects drawer's edge tab. Stable for tests.
const Key kDeskDrawerTabKey = Key('canvas_screen.desk_drawer_tab');

/// Key for a desk-objects drawer tile. Stable for tests.
Key deskDrawerTileKey(String id) => Key('canvas_screen.desk_drawer_tile.$id');

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

  /// Programmatic canvas access for the desk-objects drawer: placing an
  /// object needs the current view center; tapping a ghosted tile pans to
  /// the placed object.
  final SpatialCanvasController _canvasController = SpatialCanvasController();

  bool _drawerOpen = false;

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
    _canvasController.dispose();
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
          : Stack(children: [
              Positioned.fill(
                child: Container(
                  // Beyond the canvas edge is the "void" past the desk — same
                  // treatment as the canvas module's own example app.
                  color: DeskColors.voidBackground,
                  child: SpatialCanvas(
                    dataSource: dataSource,
                    controller: _canvasController,
                    entityBuilder: (entity, isSelected) => _buildCard(context, dataSource, entity, isSelected),
                    canvasSize: kCanvasScreenSize,
                    background: SpatialDeskBackground(canvasSize: kCanvasScreenSize),
                    // The default drag-lift shadow is a rounded rect — right
                    // for cards, wrong under desk objects, which paint their
                    // own grounding shadows (same suppression as the canvas
                    // example).
                    liftDecorationBuilder: (entity) => entity is DeskObjectEntity ? const BoxDecoration() : null,
                  ),
                ),
              ),
              // The desk-objects drawer: screen-space chrome — it sits OVER
              // the desk plane and never inherits its transforms (the
              // world-vs-chrome split from DESK_OBJECTS.md's perspective
              // constraint).
              _DeskObjectDrawer(
                dataSource: dataSource,
                controller: _canvasController,
                open: _drawerOpen,
                onToggle: () => setState(() => _drawerOpen = !_drawerOpen),
              ),
            ]),
    );
  }

  // FlippableTaskCard (not bare TaskCard) is what makes double-tap-to-flip
  // work — it reads flip state from the data source, same as isSelected
  // reads selection state from the canvas. Card back rows use the POC
  // default (const TaskCardBackFields()) per M3/M4 addendum item 1; a
  // settings-backed preference is a follow-up, not this milestone.
  Widget _buildCard(BuildContext context, TaskSpatialDataSource dataSource, SpatialEntity entity, bool isSelected) {
    if (entity is DeskObjectEntity) {
      return _buildDeskObject(dataSource, entity, isSelected);
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

  /// A desk object (knick-knack) on the canvas. Selected: resize + put-away
  /// chips, INSIDE the entity's bounds (anything outside a Positioned
  /// entity's box is unhittable). Their inner tap recognizers win the arena
  /// over the canvas's per-card detector, so tapping a chip acts without
  /// moving/deselecting.
  Widget _buildDeskObject(TaskSpatialDataSource dataSource, DeskObjectEntity entity, bool isSelected) {
    final Widget visual = switch (entity) {
      AmethystDeskEntity() => AmethystChunk(
          size: entity.size,
          rotationY: entity.rotationY,
          isSelected: isSelected,
          lightAzimuthDegrees: kDeskLightAzimuth,
        ),
      DachshundDeskEntity() => DachshundFigurine(
          size: entity.size,
          stop: entity.stop,
          isSelected: isSelected,
        ),
      _ => throw ArgumentError('unknown desk object: ${entity.id}'),
    };
    if (!isSelected) return visual;
    return Stack(children: [
      Positioned.fill(child: visual),
      Positioned(
        top: 2,
        right: 2,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _EntityChip(icon: Icons.add, tooltip: 'Bigger', onTap: () => dataSource.resizeDeskObject(entity.id, 1.15)),
          const SizedBox(height: 4),
          _EntityChip(icon: Icons.remove, tooltip: 'Smaller', onTap: () => dataSource.resizeDeskObject(entity.id, 1 / 1.15)),
          const SizedBox(height: 4),
          _EntityChip(
            icon: Icons.archive_outlined,
            tooltip: 'Put away in the drawer',
            onTap: () {
              _canvasController.clearSelection();
              dataSource.removeDeskObject(entity.id);
            },
          ),
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

/// The desk-objects drawer (owner spec 2026-08-03, form chosen 2026-08-04:
/// side tab panel, right edge): a slim gold-accented tab that slides out a
/// dark panel listing every knick-knack the app owns — ghosted if it's
/// already on the desk, full opacity if it's available to place.
///
/// Screen-space chrome, deliberately OUTSIDE the canvas transform: the
/// perspective hard-constraint (DESK_OBJECTS.md) keeps UI over the desk
/// perfectly flat whatever the desk plane ends up doing.
///
/// Tap an available tile → it lands centered in the current view and gets
/// selected. Tap a ghosted tile → the canvas pans to it (find-my-figurine).
/// Putting an object away happens on the object itself (its put-away chip).
class _DeskObjectDrawer extends StatelessWidget {
  const _DeskObjectDrawer({
    required this.dataSource,
    required this.controller,
    required this.open,
    required this.onToggle,
  });

  final TaskSpatialDataSource dataSource;
  final SpatialCanvasController controller;
  final bool open;
  final VoidCallback onToggle;

  static const double _panelWidth = 128;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _tab(),
          // ClipRect + AnimatedContainer: the panel slides out from the
          // edge without ever painting past its animating width.
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: open ? _panelWidth : 0,
              child: OverflowBox(
                minWidth: _panelWidth,
                maxWidth: _panelWidth,
                alignment: Alignment.centerLeft,
                child: _panel(),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tab() {
    return Tooltip(
      message: open ? 'Close the drawer' : 'Desk objects',
      child: GestureDetector(
        key: kDeskDrawerTabKey,
        onTap: onToggle,
        child: Container(
          width: 26,
          height: 92,
          decoration: const BoxDecoration(
            color: DeskColors.chipBackground,
            border: Border(
              left: BorderSide(color: DeskColors.accentGold),
              top: BorderSide(color: DeskColors.accentGold),
              bottom: BorderSide(color: DeskColors.accentGold),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomLeft: Radius.circular(10),
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              open ? Icons.chevron_right : Icons.chevron_left,
              size: 16,
              color: DeskColors.accentGold,
            ),
            const SizedBox(height: 6),
            const Icon(Icons.inventory_2_outlined, size: 16, color: DeskColors.accentGold),
          ]),
        ),
      ),
    );
  }

  Widget _panel() {
    // ListenableBuilder on the data source: placing/removing re-renders the
    // ghosting immediately, same channel the canvas itself listens on.
    return ListenableBuilder(
      listenable: dataSource,
      builder: (context, _) => Container(
        width: _panelWidth,
        decoration: const BoxDecoration(
          color: DeskColors.chipBackground,
          border: Border(
            left: BorderSide(color: DeskColors.accentGold, width: 0.5),
            top: BorderSide(color: DeskColors.accentGold),
            bottom: BorderSide(color: DeskColors.accentGold),
          ),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final id in TaskSpatialDataSource.deskObjectIds) _tile(id),
        ]),
      ),
    );
  }

  Widget _tile(String id) {
    final placed = dataSource.isDeskObjectPlaced(id);
    final (name, thumb) = switch (id) {
      kAmethystDeskId => (
          'Amethyst',
          // Not const: baseAlignedYaw is a computed static final.
          AmethystChunk(size: const Size(72, 58), rotationY: AmethystChunkMesh.baseAlignedYaw),
        ),
      kDachshundDeskId => (
          'Dachshund',
          const DachshundFigurine(size: Size(72, 72)),
        ),
      _ => throw ArgumentError('unknown desk object: $id'),
    };
    return Tooltip(
      message: placed ? 'On the desk — tap to find it' : 'Set it on the desk',
      child: GestureDetector(
        key: deskDrawerTileKey(id),
        onTap: () {
          if (placed) {
            controller.focusOnEntity(id);
            controller.selectEntity(id);
          } else {
            dataSource.placeDeskObject(id, viewCenter: controller.visibleRect.center);
            controller.selectEntity(id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Opacity(
            // Ghosted-if-placed, full-opacity-if-available (owner spec).
            opacity: placed ? 0.35 : 1.0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              thumb,
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(fontSize: 11, color: DeskColors.drawerLabel),
              ),
            ]),
          ),
        ),
      ),
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
