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

/// Canvas bounds for the Spatial View: the desk's inner cut-in panel
/// (owner decision 2026-08-05 — "bind usable desktop within those
/// corners"). The desk asset keeps its true proportions; the CANVAS
/// adapts to the desk, not the other way around. These are the modeled
/// desk's panel dimensions from the bundle v1 camera contract
/// (marker-verified sub-pixel in the renders) — see
/// `SpatialDeskBackground` for how the image anchors to it. Full-panel
/// desk-mat art designs to exactly this box at 2× = 3646×2646 (canvas
/// origin = the panel's top-left corner); the bundled mats are
/// full-frame layers instead and just stack over the desk.
const Size kCanvasScreenSize = Size(1823, 1323);

/// Key on the grey "this card has hidden ink" pencil glyph (owner L10).
/// Stable for tests.
const Key kHiddenDrawingGlyphKey = Key('canvas_screen.hidden_drawing_glyph');

/// Key on the desk-objects drawer's edge tab. Stable for tests.
const Key kDeskDrawerTabKey = Key('canvas_screen.desk_drawer_tab');

/// Key for a desk-objects drawer tile. Stable for tests.
Key deskDrawerTileKey(String id) => Key('canvas_screen.desk_drawer_tile.$id');

/// Opacity a desk card fades to when a tag is spotlit and it doesn't carry
/// that tag (owner idea 2026-08-06, tentative "tag-tap spotlight" first
/// pass for device feel-testing). 0.3 sits in the owner's requested
/// "clearly dimmed but still readable/locatable" ~0.25-0.35 band: dim
/// enough that the spotlit cards visually pop against the rest of the desk,
/// but a ghosted card's title/tags/position stay legible at a glance --
/// this is a spotlight, not a filter, so nothing should become hard to find
/// or identify, just visually de-emphasized.
const double kSpotlightGhostOpacity = 0.3;

/// How long a card takes to fade in/out of ghost. Long enough to read as an
/// intentional sweep of the desk rather than a flicker, short enough to
/// feel responsive to the tap that caused it (owner idea 2026-08-06,
/// tentative first pass).
const Duration kSpotlightFadeDuration = Duration(milliseconds: 200);

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

  /// Which done-pile tray card (if any) is selected -- own lightweight
  /// state (owner decision 2026-08-06) rather than the canvas's shared
  /// [SpatialCanvasController] selection: the tray is chrome outside the
  /// canvas, its cards' compact on-desk twins don't need to visually react,
  /// and driving the tray's own rebuild off the SAME controller a tray
  /// card's tap would notify caused knock-on timing trouble for unrelated
  /// canvas animations (desk-object focus/select pans) sharing that
  /// controller -- plain [setState] avoids coupling the two entirely.
  String? _selectedTrayCardId;

  TaskProvider? _watchedProvider;
  VoidCallback? _isLoadingListener;

  @override
  void initState() {
    super.initState();
    // Async-decodes the figurine's silhouette masks; until they land his
    // hit target is the whole box (never untappable).
    DachshundHitMask.ensureLoading();
    GemHitMask.ensureLoading();
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
        // Lets the data source resolve tag membership itself for the
        // spotlight-raise, inside getVisibleEntities (which the canvas
        // re-runs on every spotlight change) rather than us pushing it from
        // build() — which doesn't re-run on a tag tap, so the raise never
        // fired on device (owner report 2026-08-07). Ghost dimming was
        // unaffected because it's computed in _buildCard, inside the canvas.
        tagIdsForTask: (id) =>
            taskProvider.getTagsForTask(id).map((t) => t.id).toSet(),
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
    // NOTE: the spotlight-raise match-feeding that used to live here was
    // removed 2026-08-07 — build() doesn't re-run on a tag tap (only the
    // inner SpatialCanvas listens to the data source), so it never fired on
    // device. The data source now resolves matches itself via the
    // tagIdsForTask closure passed in _snapshot.
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
                  // Beyond the canvas edge is the "void" past the desk. A
                  // soft-focus candlelit-study backdrop (owner-sourced
                  // 2026-08-05, testing the DESK_VIEWPORT_RESEARCH void
                  // treatment) replaces flat black: screen-space (doesn't
                  // pan with the desk), cover-cropped to any window shape.
                  // The dark base color stays underneath as the fallback.
                  decoration: const BoxDecoration(
                    color: DeskColors.voidBackground,
                    image: DecorationImage(
                      image: AssetImage('assets/images/spatial/desk_void_backdrop.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: SpatialCanvas(
                    dataSource: dataSource,
                    controller: _canvasController,
                    entityBuilder: (entity, isSelected) => _buildCard(context, dataSource, entity, isSelected),
                    canvasSize: kCanvasScreenSize,
                    background: SpatialDeskBackground(canvasSize: kCanvasScreenSize),
                    // Zoom-out headroom (owner 2026-08-06, phone): the
                    // canvas rect is only the desk's inner panel (1823×1323),
                    // but the desk art extends far below it — true-height
                    // drawer band to ~2992px plus the floor shadow and the
                    // room backdrop beyond. The module's default 0.5 floor
                    // couldn't shrink the panel enough to bring the drawers
                    // (let alone the room) into a phone viewport, so drop the
                    // floor well below 1:1. maxZoom left at the 2.0 default.
                    minZoom: 0.18,
                    // The default drag-lift shadow is a rounded rect — right
                    // for cards, wrong under desk objects, which paint their
                    // own grounding shadows (same suppression as the canvas
                    // example).
                    liftDecorationBuilder: (entity) => entity is DeskObjectEntity ? const BoxDecoration() : null,
                    // Desk objects hit-test against their actual silhouette,
                    // not their (mostly transparent) bounding box — a tap
                    // just below the dog's nose reaches the card beneath
                    // (owner report 2026-08-04). Selected objects get the
                    // CHIP CLUSTER corner of their box back (only that
                    // corner, not the whole box): the resize/put-away chips
                    // live in the transparent margin, so they need their
                    // spot back to stay tappable. Handing back the ENTIRE
                    // box while selected (the original fix) went too far —
                    // because a selected entity also paints/hit-tests ABOVE
                    // every other entity (see SpatialCanvas's `_layerTier`),
                    // that full box silently ate any tap landing in its
                    // margin, including taps meant for whatever sat
                    // underneath: another desk object, or a card (owner
                    // report 2026-08-05 — tapping a second knick-knack while
                    // the first was selected didn't transfer selection,
                    // single tap required first deselecting). Narrowing the
                    // box-back region to just the chips fixes the tap-theft
                    // while keeping them reachable.
                    entityHitTest: (entity, local, isSelected) {
                      if (entity is! DeskObjectEntity) return true;
                      if (isSelected && _isInDeskObjectChipCluster(entity.size, local)) {
                        return true;
                      }
                      if (entity is DachshundDeskEntity) {
                        return DachshundHitMask.contains(
                          entity.stop,
                          local.dx / entity.size.width,
                          local.dy / entity.size.height,
                        );
                      }
                      if (entity is GemDeskEntity) {
                        return GemHitMask.contains(
                          entity.variant,
                          entity.stop,
                          local.dx / entity.size.width,
                          local.dy / entity.size.height,
                        );
                      }
                      return true;
                    },
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
              _DonePileTray(
                dataSource: dataSource,
                selectedCardId: _selectedTrayCardId,
                onCardTap: (id) {
                  setState(() => _selectedTrayCardId = id);
                  dataSource.onEntityTapped(id);
                },
                cardBuilder: (entity, isSelected) => _buildCard(context, dataSource, entity, isSelected),
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
      // Tag-tap spotlight (owner idea 2026-08-06, tentative): any tag chip
      // on any card can drive the spotlight, including done-pile cards --
      // spotlighting is a global desk state, not something scoped to
      // where the tap happened.
      onTagTap: dataSource.spotlightTag,
    );

    final hasHidden = dataSource.hasHiddenDrawing(id);
    final Widget content;
    if (!isSelected && !hasHidden) {
      content = card;
    } else {
      // Chips act on the face currently showing: draw on (or show/hide) the
      // front normally, the back when the card is flipped (owner L1).
      final face = showBack ? TaskDrawing.faceBack : TaskDrawing.faceFront;
      final hasDrawing = dataSource.drawingJsonFor(id, face: face) != null;
      final drawingVisible = dataSource.isDrawingVisible(id, face: face);
      content = Stack(children: [
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
              // Complete-from-card (owner request 2026-08-06 -- the
              // highest-value slice of in-place editing: finishing a task
              // shouldn't require leaving the desk for the main list).
              // Guarded on task.completed rather than isSelected alone: a
              // selected done-pile card renders through this SAME
              // `_buildCard` path (via `_DonePileTray`'s cardBuilder), and
              // it must never re-offer "complete" on an already-finished
              // card.
              if (!taskEntity.task.completed) ...[
                const SizedBox(height: 4),
                _EntityChip(
                  icon: Icons.check,
                  tooltip: 'Complete task',
                  onTap: () {
                    // The card is about to leave the desk for the done
                    // pile -- clear the canvas's own selection so it
                    // doesn't dangle on an entity that no longer lives in
                    // `_placed`/`_tray` (mirrors the put-away chip's
                    // clearSelection() below for the same reason).
                    _canvasController.clearSelection();
                    dataSource.completeTask(id);
                  },
                ),
              ],
            ]),
          ),
      ]);
    }

    return _spotlightGhost(dataSource, taskEntity, data, content);
  }

  /// Dims [content] to [kSpotlightGhostOpacity] when a tag is spotlit and
  /// this card doesn't carry it (owner idea 2026-08-06, tentative "tag-tap
  /// spotlight" first pass for device feel-testing). A visual dim only --
  /// [AnimatedOpacity] never affects hit testing, so a ghosted card still
  /// drags/taps/flips exactly like a spotlit one (owner spec: "nothing
  /// becomes non-interactive").
  ///
  /// The done pile ([Task.completed]) is exempt regardless of tags: the
  /// spotlight is about finding live desk work, not the finished pile
  /// (owner spec) -- this covers both the on-desk fan and the overflow
  /// tray, since both render through this same `_buildCard` path.
  Widget _spotlightGhost(
    TaskSpatialDataSource dataSource,
    TaskSpatialEntity taskEntity,
    TaskCardData data,
    Widget content,
  ) {
    final spotlit = dataSource.spotlitTag;
    final isGhosted =
        spotlit != null && !taskEntity.task.completed && !data.tags.any((tag) => tag.id == spotlit);
    return AnimatedOpacity(
      opacity: isGhosted ? kSpotlightGhostOpacity : 1.0,
      duration: kSpotlightFadeDuration,
      child: content,
    );
  }

  /// A desk object (knick-knack) on the canvas. Selected: resize + put-away
  /// chips, INSIDE the entity's bounds (anything outside a Positioned
  /// entity's box is unhittable). Their inner tap recognizers win the arena
  /// over the canvas's per-card detector, so tapping a chip acts without
  /// moving/deselecting.
  Widget _buildDeskObject(TaskSpatialDataSource dataSource, DeskObjectEntity entity, bool isSelected) {
    final Widget visual = switch (entity) {
      GemDeskEntity() => GemFigurine(
          variant: entity.variant,
          size: entity.size,
          stop: entity.stop,
          isSelected: isSelected,
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

/// Selection chip cluster geometry for a desk object, mirroring
/// [_CanvasScreenState._buildDeskObject]'s chip `Column` by hand: inset 2
/// from the top-right corner, three stacked 22×22 `_EntityChip`s with 4px
/// gaps between them. If that layout ever changes, update this too.
const double _kDeskObjectChipInset = 2;
const double _kDeskObjectChipSize = 22;
const double _kDeskObjectChipSpacing = 4;
const int _kDeskObjectChipCount = 3;

/// A little extra room around the chip cluster's own footprint, same
/// "forgiving halo" idea as the hit masks' texel halo — a selected chip
/// shouldn't be a hairline target.
const double _kDeskObjectChipHitPad = 6;

/// Whether [local] (a raw-pixel offset within a desk object's own
/// `Offset.zero`..[entitySize] box, per `SpatialCanvas.entityHitTest`'s
/// local-coordinate contract) falls within that object's selection chip
/// cluster — the ONLY part of a selected desk object's transparent margin
/// that should hit-test as "the object" rather than fall through to
/// whatever's underneath. See the `entityHitTest` closure in
/// `CanvasScreen.build` for why this matters.
bool _isInDeskObjectChipCluster(Size entitySize, Offset local) {
  const clusterHeight =
      _kDeskObjectChipCount * _kDeskObjectChipSize + (_kDeskObjectChipCount - 1) * _kDeskObjectChipSpacing;
  final cluster = Rect.fromLTWH(
    entitySize.width - _kDeskObjectChipInset - _kDeskObjectChipSize,
    _kDeskObjectChipInset,
    _kDeskObjectChipSize,
    clusterHeight,
  ).inflate(_kDeskObjectChipHitPad);
  return cluster.contains(local);
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
/// Tap an available tile → it returns to wherever it last sat on the desk
/// (its default spot if never placed; owner call 2026-08-04), gets
/// selected, and the canvas pans to it. Tap a ghosted tile → the canvas
/// pans to it (find-my-figurine). Putting an object away happens on the
/// object itself (its put-away chip).
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
      // Near the top, not centered (owner call 2026-08-04) — hangs like a
      // drawer pull just under the AppBar.
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                alignment: Alignment.topLeft,
                child: _panel(),
              ),
            ),
          ),
        ]),
        ),
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
        // Scrollable: five-and-growing tiles can outgrow a landscape-phone
        // viewport height.
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final id in TaskSpatialDataSource.deskObjectIds) _tile(id),
          ]),
        ),
      ),
    );
  }

  Widget _tile(String id) {
    final placed = dataSource.isDeskObjectPlaced(id);
    final (String name, Widget thumb) = switch (id) {
      kDachshundDeskId => (
          'Dachshund',
          // The widened sprite frame is mostly shadow margin — center-crop
          // the thumbnail (1.75× overscan) so the tile shows dog, not air.
          const ClipRect(
            child: SizedBox(
              width: 72,
              height: 72,
              child: OverflowBox(
                minWidth: 126,
                maxWidth: 126,
                minHeight: 126,
                maxHeight: 126,
                child: DachshundFigurine(size: Size(126, 126)),
              ),
            ),
          ),
        ),
      _ => (
          // Modeled habit gems fill most of their frame (padding 1.25) —
          // no overscan crop needed, unlike the dachshund.
          (kGemVariantsById[id] ?? (throw ArgumentError('unknown desk object: $id'))).label,
          GemFigurine(variant: kGemVariantsById[id]!, size: const Size(72, 72)),
        ),
    };
    return Tooltip(
      message: placed ? 'On the desk — tap to find it' : 'Set it on the desk',
      child: GestureDetector(
        key: deskDrawerTileKey(id),
        onTap: () {
          if (!placed) {
            // Back to wherever it last sat (or its default spot) — the
            // focus pan below carries the eye to it.
            dataSource.placeDeskObject(id);
          }
          controller.focusOnEntity(id);
          controller.selectEntity(id);
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

/// Key on the done-pile tray's outer panel. Stable for tests.
const Key kDonePileTrayKey = Key('canvas_screen.done_pile_tray');

/// Key for a done-pile tray card tile.
Key donePileTrayCardKey(String id) => Key('canvas_screen.done_pile_tray_card.$id');

/// The done pile's scrollable browsing tray (owner decision 2026-08-06,
/// replacing an earlier second-fan-column attempt): screen-space chrome
/// modeled directly on [_DeskObjectDrawer] just above — it sits OVER the
/// desk plane and never inherits its transforms, the same world-vs-chrome
/// split from DESK_OBJECTS.md's perspective constraint.
///
/// Shown only while the pile is fanned AND [TaskSpatialDataSource
/// .donePileOverflowsFan] — a full pile that doesn't fit one on-desk fan
/// column without shingling over card titles. The desk itself stays at its
/// neat compact stack in that state ([TaskSpatialDataSource
/// ._positionCompletedStack]); this tray is the only way to browse the
/// rest, newest first, by scrolling instead of fanning.
///
/// Tapping a card here does exactly what tapping a fanned on-desk card
/// does today: selects it (surfacing its own edit/eye chips, same as an
/// on-desk selected card) and calls [TaskSpatialDataSource.onEntityTapped]
/// (a no-op while the pile's cards are the selection target — it only
/// collapses the pile for taps on something ELSE, so this keeps the tray
/// open: inspecting, not dismissing). Selection is this widget's OWN
/// lightweight state ([CanvasScreen._selectedTrayCardId]), not the canvas's
/// shared [SpatialCanvasController] selection — see that field's doc
/// comment for why. The header's close control (or any felt tap on the
/// desk underneath) collapses the pile back to its stack, same as
/// collapsing an on-desk fan.
class _DonePileTray extends StatelessWidget {
  const _DonePileTray({
    required this.dataSource,
    required this.selectedCardId,
    required this.onCardTap,
    required this.cardBuilder,
  });

  final TaskSpatialDataSource dataSource;

  /// The currently-selected tray card, if any -- owned by `CanvasScreen`.
  final String? selectedCardId;

  /// Fired when a tray card is tapped; `CanvasScreen` updates
  /// [selectedCardId] and forwards to [TaskSpatialDataSource.onEntityTapped].
  final void Function(String id) onCardTap;

  /// Builds one card's widget -- forwarded from `CanvasScreen._buildCard`
  /// so tray cards render identically to on-desk ones (flip state, drawing
  /// overlays, hidden-drawing tell, selected chips).
  final Widget Function(SpatialEntity entity, bool isSelected) cardBuilder;

  static const double _panelWidth = 252;

  @override
  Widget build(BuildContext context) {
    // Fan/overflow state lives on the data source; selection is plain
    // widget state passed down from CanvasScreen (see selectedCardId's doc
    // comment), so only the data source needs listening here.
    return ListenableBuilder(
      listenable: dataSource,
      builder: (context, _) {
        if (!dataSource.donePileFanned || !dataSource.donePileOverflowsFan) {
          // Must still be a Positioned, not a bare SizedBox: this widget is
          // a direct child of CanvasScreen's outer Stack, alongside
          // _DeskObjectDrawer and the canvas's own Positioned.fill — every
          // sibling there is Positioned today. RenderStack sizes itself
          // from its NON-positioned children whenever any exist (falling
          // back to Size(constraints.minWidth, constraints.minHeight)
          // instead of filling available space) — a bare SizedBox.shrink()
          // here would be the Stack's first-ever non-positioned child,
          // collapsing the whole Stack to near-zero and scrambling every
          // other Positioned sibling's coordinates (caught by two
          // completely unrelated, pre-existing desk-object drawer tests
          // failing once this widget was added — the drawer tab rendered
          // at a negative, zero-height Rect).
          return const Positioned(top: 0, right: 0, child: SizedBox.shrink());
        }
        final cards = dataSource.recentCompletedNewestFirst;
        return Positioned(
          // Starts below the desk-objects drawer's tab (16 top padding +
          // 92 tall) so the two pieces of screen-space chrome never
          // overlap.
          top: 116,
          right: 0,
          bottom: 16,
          child: Container(
            key: kDonePileTrayKey,
            width: _panelWidth,
            decoration: const BoxDecoration(
              color: DeskColors.chipBackground,
              border: Border(
                left: BorderSide(color: DeskColors.accentGold, width: 0.5),
                top: BorderSide(color: DeskColors.accentGold),
                bottom: BorderSide(color: DeskColors.accentGold),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recently completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: DeskColors.drawerLabel,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Close',
                        child: GestureDetector(
                          onTap: dataSource.toggleDonePileFanned,
                          child: const Icon(Icons.close, size: 16, color: DeskColors.accentGold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      children: [
                        for (final entity in cards)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            // RepaintBoundary, matching SpatialCanvas's own
                            // per-entity wrapping ([_buildEntityCore]):
                            // selecting a tray card inserts brand-new
                            // Tooltip-bearing chip widgets into this same
                            // subtree as a direct result of its own tap --
                            // exactly what an on-desk selected card's chips
                            // already do safely under that wrapping.
                            child: RepaintBoundary(
                              child: GestureDetector(
                                key: donePileTrayCardKey(entity.id),
                                onTap: () => onCardTap(entity.id),
                                onDoubleTap: () => dataSource.onEntityDoubleTapped(entity.id),
                                // On the desk, `_buildCard`'s selected-state
                                // Stack (front card + chip Positioneds) is
                                // always laid out inside SpatialCanvas's own
                                // `Positioned(width:, height:)` per entity,
                                // which is what gives that Stack a bounded
                                // size to compute against. Here it's sitting
                                // in a Column inside a SingleChildScrollView
                                // instead, which hands children unbounded
                                // height -- an explicit SizedBox reproduces
                                // the same bounded footprint so the selected
                                // Stack doesn't hit RenderStack's
                                // "size.isFinite" layout assertion.
                                child: SizedBox(
                                  width: kCardSize.width,
                                  height: kCardSize.height,
                                  child: cardBuilder(entity, entity.id == selectedCardId),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
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
