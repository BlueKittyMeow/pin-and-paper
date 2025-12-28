import 'package:flutter/foundation.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';
import '../utils/tag_colors.dart';

/// Provider for managing tag state and operations
///
/// Phase 3.5: Tags feature
/// - Load and display all tags
/// - Create new tags with color picker
/// - Manage tag-task associations
/// - Follow TaskProvider pattern for consistency
class TagProvider extends ChangeNotifier {
  final TagService _tagService;

  TagProvider({TagService? tagService})
      : _tagService = tagService ?? TagService();

  List<Tag> _tags = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Tag> get tags => _tags;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load all active tags from database
  ///
  /// Excludes soft-deleted tags
  /// Orders alphabetically by name
  Future<void> loadTags() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tags = await _tagService.getAllTags();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load tags: $e';
      debugPrint('Error loading tags: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new tag
  ///
  /// Validates name and color before creating
  /// Automatically reloads tags after creation
  ///
  /// Returns created tag on success, null on failure
  Future<Tag?> createTag(String name, {String? color}) async {
    try {
      // Validate name
      final nameError = Tag.validateName(name);
      if (nameError != null) {
        _errorMessage = nameError;
        notifyListeners();
        return null;
      }

      // Validate color
      final colorError = Tag.validateColor(color);
      if (colorError != null) {
        _errorMessage = colorError;
        notifyListeners();
        return null;
      }

      final tag = await _tagService.createTag(name, color: color);

      // Reload tags to get updated list
      await loadTags();

      _errorMessage = null;
      return tag;
    } catch (e) {
      // Gemini review: Provide specific, user-friendly error messages
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('unique constraint') || errorString.contains('already exists')) {
        _errorMessage = 'A tag with that name already exists';
      } else if (errorString.contains('too long') || errorString.contains('100 characters')) {
        _errorMessage = 'Tag name must be 100 characters or less';
      } else if (errorString.contains('empty') || errorString.contains('required')) {
        _errorMessage = 'Tag name cannot be empty';
      } else {
        _errorMessage = 'Failed to create tag. Please try again.';
      }
      debugPrint('Error creating tag: $e');
      notifyListeners();
      return null;
    }
  }

  /// Find tag by name (case-insensitive)
  ///
  /// Used for autocomplete and preventing duplicates
  Future<Tag?> findTagByName(String name) async {
    try {
      return await _tagService.getTagByName(name);
    } catch (e) {
      debugPrint('Error finding tag by name: $e');
      return null;
    }
  }

  /// Add tag to task
  ///
  /// Idempotent - does nothing if association already exists
  Future<bool> addTagToTask(String taskId, String tagId) async {
    try {
      await _tagService.addTagToTask(taskId, tagId);
      return true;
    } catch (e) {
      // Gemini review: Provide specific, user-friendly error messages
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('not found') || errorString.contains('does not exist')) {
        _errorMessage = 'Tag not found. It may have been deleted.';
      } else if (errorString.contains('task') && errorString.contains('not found')) {
        _errorMessage = 'Task not found. It may have been deleted.';
      } else {
        _errorMessage = 'Failed to add tag. Please try again.';
      }
      debugPrint('Error adding tag to task: $e');
      notifyListeners();
      return false;
    }
  }

  /// Remove tag from task
  ///
  /// Returns true if association was removed
  Future<bool> removeTagFromTask(String taskId, String tagId) async {
    try {
      return await _tagService.removeTagFromTask(taskId, tagId);
    } catch (e) {
      // Gemini review: Provide specific, user-friendly error messages
      _errorMessage = 'Failed to remove tag. Please try again.';
      debugPrint('Error removing tag from task: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get all tags for a specific task
  ///
  /// Returns empty list if task has no tags
  Future<List<Tag>> getTagsForTask(String taskId) async {
    try {
      return await _tagService.getTagsForTask(taskId);
    } catch (e) {
      debugPrint('Error getting tags for task: $e');
      return [];
    }
  }

  /// Get tags for multiple tasks (batch loading)
  ///
  /// Optimized for loading task lists with tags
  /// Prevents N+1 query problem
  ///
  /// Returns map of taskId to List of Tag
  /// Tasks with no tags are not included in the map
  Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds) async {
    try {
      return await _tagService.getTagsForAllTasks(taskIds);
    } catch (e) {
      debugPrint('Error getting tags for all tasks: $e');
      return {};
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get a random preset color for new tags
  ///
  /// Cycles through preset colors based on current tag count
  String getNextPresetColor() {
    final index = _tags.length % TagColors.presetColors.length;
    return TagColors.colorToHex(TagColors.presetColors[index]);
  }
}
