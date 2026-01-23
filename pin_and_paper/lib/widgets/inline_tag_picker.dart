import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';
import '../utils/tag_colors.dart';

/// Phase 3.6.5: Lightweight inline tag picker with fuzzy search
///
/// Displays as:
/// - Search TextField
/// - Dropdown with filtered results (multi-select)
/// - Selected tags as removable chips below
///
/// Key Features:
/// - Inline display (no separate dialog)
/// - Fuzzy search filtering
/// - Multi-select with visual checkmarks
/// - Selected tags shown as removable chips
/// - TapRegion for reliable focus handling (v3 fix)
/// - Overlay guard to prevent duplicate insertion (v3 fix)
/// - TagColors.hexToColor for color parsing (v3 fix)
class InlineTagPicker extends StatefulWidget {
  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onChanged;

  const InlineTagPicker({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
  });

  @override
  State<InlineTagPicker> createState() => _InlineTagPickerState();
}

class _InlineTagPickerState extends State<InlineTagPicker> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  // Unique group ID for TapRegion to include overlay dropdown
  final Object _tapRegionGroupId = Object();

  List<Tag> _allTags = [];
  List<Tag> _filteredTags = [];
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    // Defer tag loading to after build phase to avoid
    // "setState() or markNeedsBuild() called during build" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTags();
    });
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadTags() async {
    final tagProvider = context.read<TagProvider>();
    await tagProvider.loadTags();

    // v2 FIX: Check mounted before setState
    if (!mounted) return;

    setState(() {
      _allTags = tagProvider.tags;
      _filteredTags = _allTags;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTags = query.isEmpty
          ? _allTags
          : _allTags.where((t) => t.name.toLowerCase().contains(query)).toList();
    });
    _updateOverlay();
  }

  void _showOverlay() {
    // v3 FIX: Guard against multiple insertions (Codex #11)
    if (_overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          // Wrap overlay in TapRegion with same groupId so taps inside don't close it
          child: TapRegion(
            groupId: _tapRegionGroupId,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: _filteredTags.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        final isSelected = widget.selectedTagIds.contains(tag.id);

                        // v3 FIX: Use TagColors helper for hex string parsing (Codex #9)
                        final tagColor = tag.color != null
                            ? TagColors.hexToColor(tag.color!)
                            : TagColors.defaultColor;

                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: tagColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(tag.name),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () => _toggleTag(tag.id),
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          _searchController.text.isEmpty ? 'No tags available' : 'No matching tags',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _toggleTag(String tagId) {
    final newSelection = List<String>.from(widget.selectedTagIds);
    if (newSelection.contains(tagId)) {
      newSelection.remove(tagId);
    } else {
      newSelection.add(tagId);
    }
    widget.onChanged(newSelection);
    _updateOverlay();
  }

  void _removeTag(String tagId) {
    final newSelection = List<String>.from(widget.selectedTagIds);
    newSelection.remove(tagId);
    widget.onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTags =
        _allTags.where((t) => widget.selectedTagIds.contains(t.id)).toList();

    // v3 FIX: Use TapRegion instead of Future.delayed for focus handling (Gemini #17)
    // Use groupId to include overlay dropdown in the same tap region
    return TapRegion(
      groupId: _tapRegionGroupId,
      onTapOutside: (_) => _hideOverlay(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field with dropdown
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onTap: _showOverlay, // v3: Show on tap instead of focus listener
              decoration: InputDecoration(
                labelText: 'Tags',
                hintText: 'Search tags...',
                prefixIcon: const Icon(Icons.label_outline),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          // Selected tags as chips
          if (selectedTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: selectedTags.map((tag) {
                // v3 FIX: Use TagColors helper for hex string parsing (Codex #9)
                final tagColor = tag.color != null
                    ? TagColors.hexToColor(tag.color!)
                    : TagColors.defaultColor;

                return Chip(
                  avatar: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tagColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: Text(
                    tag.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeTag(tag.id),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: tagColor.withValues(alpha: 0.2),
                  side: BorderSide(color: tagColor.withValues(alpha: 0.5)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
