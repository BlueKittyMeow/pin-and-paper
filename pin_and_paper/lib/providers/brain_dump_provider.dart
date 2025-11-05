import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/task_suggestion.dart';
import '../models/brain_dump_draft.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart'; // IMPLEMENTATION REMINDER FIX: Use AppConstants
import 'settings_provider.dart';

class BrainDumpProvider extends ChangeNotifier {
  final ClaudeService _claudeService = ClaudeService();
  final SettingsProvider _settingsProvider;
  final Connectivity _connectivity = Connectivity(); // Reuse instance
  final Uuid _uuid = const Uuid(); // For generating draft IDs

  static const int MAX_CHAR_LIMIT = 10000;

  String _dumpText = '';
  List<TaskSuggestion> _suggestions = [];
  bool _isProcessing = false;
  bool _hasInternet = true;
  double _estimatedCost = 0.0;
  String? _errorMessage;
  String? _currentDraftId; // Track current draft ID for upsert logic
  List<BrainDumpDraft> _drafts = [];
  Set<String> _selectedDraftIds = {};
  String? _originalDumpText; // For brain dump review bottom sheet

  BrainDumpProvider(this._settingsProvider);

  String get dumpText => _dumpText;
  List<TaskSuggestion> get suggestions => _suggestions;
  bool get isProcessing => _isProcessing;
  bool get hasInternet => _hasInternet;
  double get estimatedCost => _estimatedCost;
  String? get errorMessage => _errorMessage;
  List<BrainDumpDraft> get drafts => _drafts;
  Set<String> get selectedDraftIds => _selectedDraftIds;
  int get selectedCount => _selectedDraftIds.length;
  String? get originalDumpText => _originalDumpText;

  int get selectedTotalChars {
    int total = 0;
    for (final draft in _drafts) {
      if (_selectedDraftIds.contains(draft.id)) {
        total += draft.content.length;
      }
    }
    return total;
  }

  bool get isOverLimit => selectedTotalChars > MAX_CHAR_LIMIT;

  int get excessCharacters {
    final excess = selectedTotalChars - MAX_CHAR_LIMIT;
    return excess > 0 ? excess : 0;
  }

  // Update brain dump text
  void updateDumpText(String text) {
    _dumpText = text;
    _errorMessage = null;
    notifyListeners();
  }

  // Check internet connectivity
  Future<void> checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    // Bug fix: Include VPN, other, and bluetooth for tethering
    _hasInternet = connectivityResult.contains(ConnectivityResult.mobile) ||
                   connectivityResult.contains(ConnectivityResult.wifi) ||
                   connectivityResult.contains(ConnectivityResult.ethernet) ||
                   connectivityResult.contains(ConnectivityResult.vpn) ||
                   connectivityResult.contains(ConnectivityResult.other) ||
                   connectivityResult.contains(ConnectivityResult.bluetooth);
    notifyListeners();
  }

  // Estimate cost of processing
  Future<void> estimateCost() async {
    if (_dumpText.trim().isEmpty) {
      _estimatedCost = 0.0;
      return;
    }

    try {
      _estimatedCost = await _claudeService.estimateCost(_dumpText);
      notifyListeners();
    } catch (e) {
      _estimatedCost = 0.05; // Default fallback estimate
    }
  }

  // Process brain dump with Claude
  Future<void> processDump() async {
    if (_dumpText.trim().isEmpty) {
      _errorMessage = 'Please enter some text first';
      notifyListeners();
      return;
    }

    _isProcessing = true;
    _errorMessage = null;
    _originalDumpText = _dumpText; // Store original text before processing
    notifyListeners();

    try {
      // Get API key
      final apiKey = await _settingsProvider.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('No API key configured');
      }

      // Check connectivity
      await checkConnectivity();
      if (!_hasInternet) {
        throw Exception('No internet connection');
      }

      // Call Claude API
      _suggestions = await _claudeService.extractTasks(_dumpText, apiKey);

      if (_suggestions.isEmpty) {
        _errorMessage = 'Claude didn\'t find any actionable tasks. Try being more specific?';
      } else {
        // Success! Delete the draft (no longer needed)
        if (_currentDraftId != null) {
          await deleteDraft(_currentDraftId!);
          _currentDraftId = null;
        }
      }
    } catch (e) {
      _errorMessage = _formatError(e);
      _suggestions = [];

      // CRITICAL: Save draft on error (NEVER lose user's text!)
      await saveDraft(_dumpText);
    }

    _isProcessing = false;
    notifyListeners();
  }

  // Toggle suggestion approval
  void toggleSuggestionApproval(String id) {
    final index = _suggestions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _suggestions[index] = _suggestions[index].copyWith(
        approved: !_suggestions[index].approved,
      );
      notifyListeners();
    }
  }

  // Edit suggestion
  void editSuggestion(String id, String newTitle) {
    final index = _suggestions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _suggestions[index] = _suggestions[index].copyWith(
        title: newTitle,
        edited: true,
      );
      notifyListeners();
    }
  }

  // Remove suggestion
  void removeSuggestion(String id) {
    _suggestions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // Get approved suggestions
  List<TaskSuggestion> getApprovedSuggestions() {
    return _suggestions.where((s) => s.approved).toList();
  }

  // Save draft to database (UPSERT logic to prevent duplicate drafts)
  Future<void> saveDraft(String content) async {
    if (content.trim().isEmpty) return;

    final db = await DatabaseService.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // If we don't have a current draft ID, generate one and insert
    if (_currentDraftId == null) {
      _currentDraftId = _uuid.v4();

      await db.insert(
        AppConstants.brainDumpDraftsTable, // IMPLEMENTATION REMINDER FIX
        {
          'id': _currentDraftId,
          'content': content,
          'created_at': now,
          'last_modified': now,
          'failed_reason': _errorMessage,
        },
      );
    } else {
      // Update existing draft (auto-save scenario)
      final rowsAffected = await db.update(
        AppConstants.brainDumpDraftsTable, // IMPLEMENTATION REMINDER FIX
        {
          'content': content,
          'last_modified': now,
          'failed_reason': _errorMessage,
        },
        where: 'id = ?',
        whereArgs: [_currentDraftId],
      );

      // Bug fix: If update affected 0 rows (draft was deleted), create new draft
      if (rowsAffected == 0) {
        _currentDraftId = _uuid.v4();
        await db.insert(
          AppConstants.brainDumpDraftsTable,
          {
            'id': _currentDraftId,
            'content': content,
            'created_at': now,
            'last_modified': now,
            'failed_reason': _errorMessage,
          },
        );
      }
    }
  }

  // Load saved drafts
  Future<void> loadDrafts() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.brainDumpDraftsTable, // IMPLEMENTATION REMINDER FIX
      orderBy: 'last_modified DESC',
    );
    _drafts = maps.map((map) => BrainDumpDraft.fromMap(map)).toList();
    notifyListeners();
  }

  // Delete draft
  Future<void> deleteDraft(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      AppConstants.brainDumpDraftsTable, // IMPLEMENTATION REMINDER FIX
      where: 'id = ?',
      whereArgs: [id],
    );
    _drafts.removeWhere((draft) => draft.id == id);
    _selectedDraftIds.remove(id);

    // Bug fix: If deleting the currently active draft, reset ID
    if (_currentDraftId == id) {
      _currentDraftId = null;
    }

    notifyListeners();
  }

  // Toggle draft selection
  void toggleDraftSelection(String draftId) {
    if (_selectedDraftIds.contains(draftId)) {
      _selectedDraftIds.remove(draftId);
    } else {
      _selectedDraftIds.add(draftId);
    }
    notifyListeners();
  }

  // Get combined text from selected drafts
  String getCombinedDraftsText() {
    final selectedDrafts = _drafts
        .where((draft) => _selectedDraftIds.contains(draft.id))
        .toList();

    return selectedDrafts
        .map((draft) => draft.content)
        .join('\n\n--- DRAFT SEPARATOR ---\n\n');
  }

  // Delete selected drafts
  Future<void> deleteSelectedDrafts() async {
    await loadDrafts(); // Reload to ensure we have fresh data
    final idsToDelete = _selectedDraftIds.toList();
    for (final id in idsToDelete) {
      await deleteDraft(id);
    }
    _selectedDraftIds.clear();
    notifyListeners();
  }

  // Clear original text
  void clearOriginalText() {
    _originalDumpText = null;
    notifyListeners();
  }

  // Clear after successful task addition
  void clearAfterSuccess() {
    _dumpText = '';
    _originalDumpText = null;
    _suggestions = [];
    notifyListeners();
  }

  // Clear all (also resets draft ID for new session)
  void clear() {
    _dumpText = '';
    _suggestions = [];
    _errorMessage = null;
    _estimatedCost = 0.0;
    _currentDraftId = null; // Reset so next save creates new draft
    notifyListeners();
  }

  // Load a draft (when user selects from saved drafts)
  Future<void> loadDraft(String draftId, String content) async {
    _dumpText = content;
    _currentDraftId = draftId; // Reuse this draft ID for updates
    notifyListeners();
  }

  // Format error messages for user
  String _formatError(dynamic error) {
    if (error.toString().contains('401')) {
      return 'Invalid API key. Please check your settings.';
    } else if (error.toString().contains('429')) {
      return 'Rate limit exceeded. Please wait a moment and try again.';
    } else if (error.toString().contains('500')) {
      return 'Claude API error. Please try again later.';
    } else if (error.toString().contains('No internet')) {
      return 'No internet connection. Please connect to Wi-Fi or mobile data.';
    } else {
      return 'Something went wrong: ${error.toString()}';
    }
  }
}
