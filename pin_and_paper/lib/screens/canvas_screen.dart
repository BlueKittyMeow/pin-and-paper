import 'package:flutter/material.dart';
import 'package:pin_and_paper_canvas/spatial_canvas.dart';
import 'package:pin_and_paper_card_renderer/card_renderer.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/task_service.dart';
import '../spatial/amethyst_desk_entity.dart';
import '../spatial/spatial_desk_background.dart';
import '../spatial/task_card_adapter.dart';
import '../spatial/task_spatial_data_source.dart';
import '../spatial/task_spatial_entity.dart';

/// Canvas bounds for the Spatial View — matches the canvas module's own
/// `example/` app (DRAG_DROP_CANVAS_MVP_PLAN.md Milestone 4) so gesture feel
/// carries over 1:1 from the module's manual verification pass.
const Size kCanvasScreenSize = Size(2000, 1500);

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
          if (dataSource != null)
            IconButton(
              tooltip: dataSource.trayArranged ? 'Restack the inbox' : 'Spread the inbox out',
              icon: Icon(dataSource.trayArranged ? Icons.layers : Icons.grid_view),
              // setState: the toggle repaints this AppBar icon; the canvas
              // itself already rebuilds via the data source's own listeners.
              onPressed: () => setState(() => dataSource.setTrayArranged(!dataSource.trayArranged)),
            ),
        ],
      ),
      body: dataSource == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              // Beyond the canvas edge is the "void" past the desk — same
              // treatment as the canvas module's own example app.
              color: const Color(0xFF0F0F17),
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
            _ResizeChip(icon: Icons.add, tooltip: 'Bigger', onTap: () => dataSource.resizeAmethyst(1.15)),
            const SizedBox(height: 4),
            _ResizeChip(icon: Icons.remove, tooltip: 'Smaller', onTap: () => dataSource.resizeAmethyst(1 / 1.15)),
          ]),
        ),
      ]);
    }
    final taskEntity = entity as TaskSpatialEntity;
    final taskProvider = context.read<TaskProvider>();
    return FlippableTaskCard(
      data: taskToCardData(taskEntity.task, taskProvider.getTagsForTask(taskEntity.id)),
      showBack: dataSource.isFlipped(taskEntity.id),
      isSelected: isSelected,
    );
  }
}

/// Small circular resize control shown on the selected amethyst. Amber on
/// dark, matching the app's accent language; deliberately tiny so it reads
/// as a handle, not a toolbar. (Ported with the stone from the canvas
/// example app.)
class _ResizeChip extends StatelessWidget {
  const _ResizeChip({required this.icon, required this.tooltip, required this.onTap});

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
            color: const Color(0xCC16161F),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC4941A), width: 1),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFFC4941A)),
        ),
      ),
    );
  }
}
