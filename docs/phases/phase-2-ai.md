# Phase 2: Claude AI Integration - THE KILLER FEATURE

**Version:** 1.0
**Created:** 2025-10-26
**Status:** Planning
**Depends On:** Phase 1 (Complete ✅)

---

## Executive Summary

Phase 2 implements the **core differentiator** of Pin and Paper: AI-assisted task organization for ADHD users. This phase adds a "brain dump" interface where users can pour out chaotic thoughts, and Claude AI intelligently extracts, organizes, and structures them into actionable tasks.

**⚠️ CRITICAL VALIDATION POINT:** If users don't find this feature genuinely helpful, the project should pivot. Everything else is polish. This feature must work.

---

## Goals & Success Metrics

### Primary Goal
Enable ADHD users to dump chaotic thoughts and get back organized, actionable tasks without friction.

### Success Metrics
- ✅ User uses brain dump feature **weekly minimum** (ideally daily)
- ✅ Claude extracts tasks accurately **>80% of the time**
- ✅ User reports feeling **less overwhelmed** after using it
- ✅ API calls complete in **<5 seconds** (including network)
- ✅ User would **pay for API costs** (proves value)
- ✅ Zero data loss on network failures

### User Flow (Ideal Experience)
1. User feeling overwhelmed, taps "Brain Dump" button
2. Speaks or types chaotic thoughts (2-3 minutes)
3. Taps "Claude, Help Me" button
4. Sees cost estimate ($0.05 typical)
5. Confirms, waits 3-5 seconds
6. Reviews 8-12 suggested tasks with smart defaults
7. Edits/approves/deletes suggestions
8. Taps "Add All" → tasks appear in main list
9. Feels relief and clarity

---

## Features Overview

### Core Features
- **Brain Dump Screen** - Large, distraction-free text area for chaos
- **Claude API Integration** - Send dump to Claude with structured prompt
- **API Key Management** - Secure storage with flutter_secure_storage
- **Settings Screen** - Enter/save/validate Claude API key
- **Task Suggestion Preview** - Show parsed tasks before committing
- **Bulk Task Creation** - Create multiple tasks at once
- **Cost Transparency** - Estimate API cost before sending
- **Offline Handling** - Graceful degradation when no internet
- **Draft Persistence** - Save brain dump text on API failure (NEVER lose user's text)
- **Clear Confirmation** - "Are you sure?" dialog before clearing brain dump text

### Deferred to Phase 3
- ❌ Natural language date parsing ("next Tuesday" → due date)
- ❌ Tag suggestions from content
- ❌ Priority suggestions
- ❌ Voice-to-text brain dump (use device keyboard mic)

**Rationale:** Keep Phase 2 focused on core validation. Add intelligence in Phase 3 after proving base concept works.

---

## Technical Architecture

### New Dependencies

```yaml
# Add to pubspec.yaml
dependencies:
  # Existing from Phase 1
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  provider: ^6.1.0
  uuid: ^4.0.0
  intl: ^0.19.0
  path: ^1.9.1

  # New for Phase 2
  http: ^1.2.0                        # HTTP requests to Claude API
  flutter_secure_storage: ^9.0.0     # Secure API key storage
  connectivity_plus: ^6.0.0          # Check internet connectivity
```

### Architecture Layers

```
┌─────────────────────────────────────────────┐
│      PRESENTATION LAYER                     │
│  BrainDumpScreen, SettingsScreen,           │
│  TaskSuggestionPreviewScreen                │
│  → TaskProvider, SettingsProvider           │
└──────────────┬──────────────────────────────┘
               ↓
┌──────────────┴──────────────────────────────┐
│      BUSINESS LOGIC LAYER                   │
│  TaskService, ClaudeService,                │
│  SettingsService                            │
└──────────────┬──────────────────────────────┘
               ↓
┌──────────────┴──────────────────────────────┐
│          DATA LAYER                         │
│  DatabaseService (SQLite)                   │
│  SecureStorageService (flutter_secure_storage) │
│  ClaudeAPI (HTTP client)                    │
└─────────────────────────────────────────────┘
```

### Data Flow: Brain Dump → Tasks

```
1. User enters text in BrainDumpScreen
   ↓
2. User taps "Claude, Help Me"
   ↓
3. SettingsProvider checks for API key
   ↓ (if missing) → Navigate to SettingsScreen
   ↓ (if present)
4. ClaudeService.estimateCost(text) → Show cost modal
   ↓
5. User confirms
   ↓
6. ClaudeService.extractTasks(text)
   - Builds prompt
   - Calls Claude API (Messages endpoint)
   - Parses JSON response
   - Returns List<TaskSuggestion>
   ↓
7. Navigate to TaskSuggestionPreviewScreen
   ↓
8. User edits/approves/deletes suggestions
   ↓
9. User taps "Add All"
   ↓
10. TaskService.createBulk(approvedSuggestions)
    ↓
11. Navigate back to HomeScreen
    ↓
12. Tasks appear in list
```

---

## Database Schema Changes

**⚠️ CRITICAL: Phase 2 requires database migration!**

### New Table: brain_dump_drafts

Phase 2 adds draft persistence to ensure we NEVER lose user's brain dump text.

```sql
CREATE TABLE brain_dump_drafts (
  id TEXT PRIMARY KEY,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_modified INTEGER NOT NULL,
  failed_reason TEXT  -- Store error message for context
);

CREATE INDEX idx_drafts_modified ON brain_dump_drafts(last_modified DESC);
```

### Migration Steps

**Update DatabaseService** (`lib/services/database_service.dart`):

1. **Bump database version:**
```dart
class AppConstants {
  static const int databaseVersion = 2; // Changed from 1 to 2
  static const String tasksTable = 'tasks';
  static const String brainDumpDraftsTable = 'brain_dump_drafts'; // NEW
}
```

2. **Add onUpgrade callback:**
```dart
Future<Database> _initDB() async {
  final docDir = await getApplicationDocumentsDirectory();
  final path = join(docDir.path, AppConstants.databaseName);

  return await openDatabase(
    path,
    version: AppConstants.databaseVersion, // Now 2
    onCreate: _createDB,
    onUpgrade: _upgradeDB, // NEW
    onConfigure: _onConfigure,
  );
}

Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Upgrading from version 1 to 2: Add brain_dump_drafts table
    await db.execute('''
      CREATE TABLE ${AppConstants.brainDumpDraftsTable} (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_modified INTEGER NOT NULL,
        failed_reason TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_drafts_modified
      ON ${AppConstants.brainDumpDraftsTable}(last_modified DESC)
    ''');
  }
  // Future migrations will go here (version 2->3, 3->4, etc.)
}
```

3. **Existing users:** The app will automatically upgrade from version 1 to 2 on next launch. No data loss.

4. **New users:** onCreate will create version 2 database from scratch (both tables).

### Existing Tables (No Changes)

```sql
-- Phase 1 schema (unchanged)
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  completed INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  completed_at INTEGER
);
```

**Future Phase 3 additions** (not now):
- `notes TEXT` column in tasks table
- `due_date INTEGER` column in tasks table
- Tags system (separate tables)

---

## New Models

### 1. TaskSuggestion Model
**File:** `lib/models/task_suggestion.dart`

```dart
class TaskSuggestion {
  final String id;              // Temporary UUID (becomes real on creation)
  final String title;
  final String? notes;          // Context extracted by Claude
  final bool approved;          // User approved this suggestion
  final bool edited;            // User manually edited this

  TaskSuggestion({
    required this.id,
    required this.title,
    this.notes,
    this.approved = true,       // Default to approved
    this.edited = false,
  });

  // Convert to Task for creation
  Task toTask() {
    return Task(
      id: id,                    // Reuse the suggestion ID
      title: title,
      createdAt: DateTime.now(),
    );
  }

  // Parse from Claude JSON response
  factory TaskSuggestion.fromJson(Map<String, dynamic> json, String id) {
    return TaskSuggestion(
      id: id,
      title: json['title'] as String,
      notes: json['notes'] as String?,
    );
  }

  // Copyable for edits
  TaskSuggestion copyWith({
    String? title,
    String? notes,
    bool? approved,
    bool? edited,
  }) {
    return TaskSuggestion(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      approved: approved ?? this.approved,
      edited: edited ?? this.edited,
    );
  }
}
```

---

## New Services

### 1. SecureStorageService
**File:** `lib/services/secure_storage_service.dart`

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._init();
  SecureStorageService._init();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,  // Use EncryptedSharedPreferences
    ),
  );

  // Keys
  static const String _claudeApiKeyKey = 'claude_api_key';

  // Save Claude API key
  Future<void> saveClaudeApiKey(String apiKey) async {
    await _storage.write(key: _claudeApiKeyKey, value: apiKey);
  }

  // Get Claude API key
  Future<String?> getClaudeApiKey() async {
    return await _storage.read(key: _claudeApiKeyKey);
  }

  // Delete Claude API key
  Future<void> deleteClaudeApiKey() async {
    await _storage.delete(key: _claudeApiKeyKey);
  }

  // Check if API key exists
  Future<bool> hasClaudeApiKey() async {
    final key = await getClaudeApiKey();
    return key != null && key.isNotEmpty;
  }
}
```

**Why SecureStorage:**
- API keys must NEVER be stored in SharedPreferences (plain text)
- flutter_secure_storage uses Android Keystore (hardware-backed)
- Encrypted at rest
- Survives app reinstalls (unless user clears data)

---

### 2. ClaudeService
**File:** `lib/services/claude_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/task_suggestion.dart';
import '../utils/constants.dart';

class ClaudeService {
  final String _baseUrl = 'https://api.anthropic.com/v1';
  final String _model = 'claude-3-5-sonnet-20241022';  // Latest Sonnet
  final Uuid _uuid = const Uuid();

  // Estimate API cost before sending
  // Claude pricing (as of 2024): ~$3 per million input tokens, ~$15 per million output tokens
  // Average brain dump: ~500 tokens input, ~500 tokens output = ~$0.01
  Future<double> estimateCost(String text) async {
    final inputTokens = _estimateTokens(text);
    final outputTokens = 500; // Conservative estimate for JSON response

    // Pricing for Claude 3.5 Sonnet
    final inputCost = (inputTokens / 1000000) * 3.0;   // $3/MTok
    final outputCost = (outputTokens / 1000000) * 15.0; // $15/MTok

    return inputCost + outputCost;
  }

  // Extract tasks from brain dump
  Future<List<TaskSuggestion>> extractTasks(String dump, String apiKey) async {
    final prompt = _buildPrompt(dump);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 2000,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      } else {
        throw ClaudeApiException(
          'API request failed: ${response.statusCode} ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ClaudeApiException('Network error: $e', 0);
    }
  }

  // Build structured prompt for Claude
  String _buildPrompt(String dump) {
    return '''
You are helping someone with ADHD organize their thoughts. They've dumped chaotic text below. Your task is to extract clear, actionable tasks.

RULES:
1. Extract ONLY actionable items (things they need to DO)
2. Each task should be a single, specific action
3. Keep task titles concise (max 50 characters)
4. If context is important, put it in "notes"
5. Don't add tasks they didn't mention
6. Return ONLY valid JSON (no markdown, no explanation)

OUTPUT FORMAT (JSON array):
[
  {"title": "Call dentist for appointment", "notes": "Mentioned tooth pain"},
  {"title": "Buy groceries", "notes": "Needs: milk, eggs, bread"},
  {"title": "Reply to Sarah's email", "notes": null}
]

USER'S BRAIN DUMP:
$dump

TASKS (JSON only):''';
  }

  // Parse Claude's JSON response into TaskSuggestion objects
  List<TaskSuggestion> _parseResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      final content = decoded['content'][0]['text'] as String;

      // Claude should return pure JSON, but might wrap it
      final jsonString = _extractJson(content);
      final List<dynamic> taskList = jsonDecode(jsonString);

      return taskList.map((json) {
        return TaskSuggestion.fromJson(
          json as Map<String, dynamic>,
          _uuid.v4(), // Generate ID for suggestion
        );
      }).toList();
    } catch (e) {
      throw ClaudeApiException('Failed to parse response: $e', 0);
    }
  }

  // Extract JSON array from potential markdown wrapper
  String _extractJson(String text) {
    // Remove markdown code blocks if present
    final jsonMatch = RegExp(r'```(?:json)?\s*(\[.*?\])\s*```', dotAll: true)
        .firstMatch(text);
    if (jsonMatch != null) {
      return jsonMatch.group(1)!;
    }

    // Look for JSON array
    final arrayMatch = RegExp(r'\[.*?\]', dotAll: true).firstMatch(text);
    if (arrayMatch != null) {
      return arrayMatch.group(0)!;
    }

    return text.trim();
  }

  // Estimate tokens (rough approximation: 1 token ≈ 4 characters)
  int _estimateTokens(String text) {
    return (text.length / 4).ceil();
  }
}

// Custom exception for Claude API errors
class ClaudeApiException implements Exception {
  final String message;
  final int statusCode;

  ClaudeApiException(this.message, this.statusCode);

  @override
  String toString() => 'ClaudeApiException: $message';
}
```

**Key Design Decisions:**
- **Model choice:** Claude 3.5 Sonnet (latest, best for structured output)
- **Prompt engineering:** Clear rules, JSON format, ADHD-aware language
- **Error handling:** Custom exception with status code
- **JSON parsing:** Robust extraction handles markdown wrappers
- **Token estimation:** Rough but good enough for cost preview

---

### 3. TaskService Updates (Phase 1 → Phase 2)
**File:** `lib/services/task_service.dart` (UPDATE existing file)

**Add bulk task creation for performance:**

```dart
// ADD THIS METHOD to existing TaskService class

// Create multiple tasks in a single transaction (CRITICAL for performance)
// Used by Brain Dump to add all approved suggestions at once
Future<List<Task>> createMultipleTasks(List<TaskSuggestion> suggestions) async {
  if (suggestions.isEmpty) return [];

  final db = await _dbService.database;
  final List<Task> createdTasks = [];

  // Use a transaction for atomicity and performance
  await db.transaction((txn) async {
    for (final suggestion in suggestions) {
      final task = Task(
        id: suggestion.id, // Reuse suggestion ID (already UUID)
        title: suggestion.title,
        createdAt: DateTime.now(),
      );

      await txn.insert(
        AppConstants.tasksTable,
        task.toMap(),
      );

      createdTasks.add(task);
    }
  });

  return createdTasks;
}
```

**Why this is critical:**
- Single database transaction (fast)
- Returns all created tasks at once
- Provider can call `notifyListeners()` ONCE instead of N times
- UI updates once with all tasks → smooth, no stuttering
- Much better UX when adding 10+ tasks from Brain Dump

**Alternative (if you need to notify for each task):**
```dart
// For TaskProvider: Add all tasks to state THEN notify once
Future<void> createMultipleTasks(List<TaskSuggestion> suggestions) async {
  if (suggestions.isEmpty) return;

  try {
    final createdTasks = await _taskService.createMultipleTasks(suggestions);

    // Add all tasks to state
    _tasks.insertAll(0, createdTasks);

    // Notify ONCE (not N times)
    notifyListeners();
  } catch (e) {
    _errorMessage = 'Failed to create tasks: $e';
    notifyListeners();
  }
}
```

---

### 4. SettingsService
**File:** `lib/services/settings_service.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'secure_storage_service.dart';
import 'claude_service.dart';

class SettingsService {
  final SecureStorageService _storage = SecureStorageService.instance;

  // Validate API key format (simple non-empty check)
  // Don't hardcode prefix/length - Anthropic could change formats
  bool isValidApiKey(String key) {
    return key.trim().isNotEmpty && key.trim().length > 10;
  }

  // Test API key with a lightweight Claude API call
  // Returns (success, errorMessage)
  Future<(bool, String?)> testApiKey(String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 10, // Minimal tokens to save cost
          'messages': [
            {
              'role': 'user',
              'content': 'Hi', // Minimal test message
            }
          ],
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return (true, null); // Success!
      } else if (response.statusCode == 401) {
        return (false, 'Invalid API key');
      } else if (response.statusCode == 429) {
        return (false, 'Rate limited - but key is valid');
      } else {
        return (false, 'API error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return (false, 'Connection timeout - check your internet');
      }
      return (false, 'Connection error: $e');
    }
  }

  // Save API key (no brittle format validation)
  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (!isValidApiKey(trimmed)) {
      throw ArgumentError('API key cannot be empty');
    }
    await _storage.saveClaudeApiKey(trimmed);
  }

  // Get API key
  Future<String?> getApiKey() async {
    return await _storage.getClaudeApiKey();
  }

  // Check if API key is configured
  Future<bool> hasApiKey() async {
    return await _storage.hasClaudeApiKey();
  }

  // Delete API key
  Future<void> deleteApiKey() async {
    await _storage.deleteClaudeApiKey();
  }
}
```

---

## New Providers

### 1. SettingsProvider
**File:** `lib/providers/settings_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  bool _hasApiKey = false;
  bool _isLoading = true;
  String? _errorMessage;

  bool get hasApiKey => _hasApiKey;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize - check if API key exists
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _hasApiKey = await _settingsService.hasApiKey();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to check API key: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Save API key
  Future<void> saveApiKey(String apiKey) async {
    try {
      await _settingsService.saveApiKey(apiKey);
      _hasApiKey = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save API key: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Delete API key
  Future<void> deleteApiKey() async {
    try {
      await _settingsService.deleteApiKey();
      _hasApiKey = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete API key: $e';
      notifyListeners();
    }
  }

  // Get API key (for API calls)
  Future<String?> getApiKey() async {
    return await _settingsService.getApiKey();
  }
}
```

---

### 2. BrainDumpProvider
**File:** `lib/providers/brain_dump_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/task_suggestion.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';
import 'settings_provider.dart';

class BrainDumpProvider extends ChangeNotifier {
  final ClaudeService _claudeService = ClaudeService();
  final SettingsProvider _settingsProvider;
  final Connectivity _connectivity = Connectivity(); // Reuse instance
  final Uuid _uuid = const Uuid(); // For generating draft IDs

  String _dumpText = '';
  List<TaskSuggestion> _suggestions = [];
  bool _isProcessing = false;
  bool _hasInternet = true;
  double _estimatedCost = 0.0;
  String? _errorMessage;
  String? _currentDraftId; // Track current draft ID for upsert logic

  BrainDumpProvider(this._settingsProvider);

  String get dumpText => _dumpText;
  List<TaskSuggestion> get suggestions => _suggestions;
  bool get isProcessing => _isProcessing;
  bool get hasInternet => _hasInternet;
  double get estimatedCost => _estimatedCost;
  String? get errorMessage => _errorMessage;

  // Update brain dump text
  void updateDumpText(String text) {
    _dumpText = text;
    _errorMessage = null;
    notifyListeners();
  }

  // Check internet connectivity
  Future<void> checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    _hasInternet = connectivityResult.contains(ConnectivityResult.mobile) ||
                   connectivityResult.contains(ConnectivityResult.wifi) ||
                   connectivityResult.contains(ConnectivityResult.ethernet);
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
        AppConstants.brainDumpDraftsTable,
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
      await db.update(
        AppConstants.brainDumpDraftsTable,
        {
          'content': content,
          'last_modified': now,
          'failed_reason': _errorMessage,
        },
        where: 'id = ?',
        whereArgs: [_currentDraftId],
      );
    }
  }

  // Load saved drafts
  Future<List<Map<String, dynamic>>> loadDrafts() async {
    final db = await DatabaseService.instance.database;
    return await db.query(
      'brain_dump_drafts',
      orderBy: 'last_modified DESC',
    );
  }

  // Delete draft
  Future<void> deleteDraft(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      'brain_dump_drafts',
      where: 'id = ?',
      whereArgs: [id],
    );
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
```

---

## New Screens

### 1. SettingsScreen
**File:** `lib/screens/settings_screen.dart`

**Purpose:** Configure Claude API key

**UI Elements:**
- App bar with "Settings" title
- Section header: "Claude AI"
- Text field for API key (obscured by default, toggle visibility)
- "Save" button
- "Test API Key" button (validates with a small API call)
- "Delete API Key" button (with confirmation)
- Help text: "Get your API key from console.anthropic.com"

**Behavior:**
- Validate format on save (starts with "sk-ant-")
- Show success/error messages
- Navigate back after successful save

---

### 2. BrainDumpScreen
**File:** `lib/screens/brain_dump_screen.dart`

**Purpose:** Large text area for chaotic thought capture

**UI Elements:**
- App bar with "Brain Dump" title
- Large multiline text field (expands to fill screen)
- Placeholder: "Pour out your thoughts... everything that's on your mind"
- Character counter (for token estimation)
- Bottom bar with:
  - "Clear" button
  - "Claude, Help Me" button (primary action, disabled if empty)

**Behavior:**
- Auto-focus text field on launch
- Check for API key before processing
- If no API key → navigate to SettingsScreen
- If API key exists → show cost confirmation modal
- After confirmation → call ClaudeService
- Show loading indicator during processing
- On success → navigate to TaskSuggestionPreviewScreen
- On error → show error message at top

---

### 3. TaskSuggestionPreviewScreen
**File:** `lib/screens/task_suggestion_preview_screen.dart`

**Purpose:** Review and approve suggested tasks

**UI Elements:**
- App bar with "Review Tasks" title
- Count: "X tasks suggested"
- Scrollable list of suggestions:
  - Checkbox (tap to toggle approval)
  - Editable text field (tap to edit title)
  - Delete button (swipe or icon)
  - Notes preview (if present)
- Bottom bar:
  - "Cancel" button (discard all)
  - "Add X Tasks" button (shows count of approved, primary action)

**Behavior:**
- All suggestions approved by default
- User can uncheck to exclude
- User can edit titles inline
- User can delete suggestions
- "Add Tasks" button updates count in real-time
- On "Add Tasks" → bulk create via TaskService → navigate back to HomeScreen
- Show success toast: "8 tasks added"

---

## New Widgets

### 1. TaskSuggestionItem
**File:** `lib/widgets/task_suggestion_item.dart`

**Purpose:** Reusable widget for suggestion list item

**UI Elements:**
- Checkbox (left)
- Text field for title (center, editable)
- Delete icon button (right)
- Optional notes text (smaller, gray, below title)
- Cream paper background (matches theme)

**Behavior:**
- Toggle checkbox → calls provider.toggleSuggestionApproval()
- Edit text → calls provider.editSuggestion()
- Tap delete → calls provider.removeSuggestion()
- Disabled state if not approved (grayed out)

---

## Implementation Steps

### Step 0: Preparation
**Time Estimate:** 15 minutes

1. Read this entire document
2. Ensure Phase 1 is working and committed
3. Create new git branch: `git checkout -b phase-2-ai`
4. Update pubspec.yaml with new dependencies
5. Run `flutter pub get`

---

### Step 1: Models & Constants
**Time Estimate:** 30 minutes

**Files to create:**
- `lib/models/task_suggestion.dart` (see above)

**Files to update:**
- `lib/utils/constants.dart` - Add Claude API constants

```dart
// lib/utils/constants.dart - ADD THESE
class AppConstants {
  // Existing...
  static const String databaseName = 'pin_and_paper.db';
  static const int databaseVersion = 1;
  static const String tasksTable = 'tasks';

  // NEW for Phase 2
  static const String claudeApiBaseUrl = 'https://api.anthropic.com/v1';
  static const String claudeModel = 'claude-3-5-sonnet-20241022';
  static const int maxBrainDumpLength = 10000; // Characters
  static const double typicalCostPerDump = 0.01; // USD
}
```

**Testing:**
- Create a TaskSuggestion object
- Convert to Task via toTask()
- Verify all fields

---

### Step 2: Secure Storage Service
**Time Estimate:** 30 minutes

**Files to create:**
- `lib/services/secure_storage_service.dart` (see above)

**Testing:**
```dart
// Manual test in main.dart or widget test
final storage = SecureStorageService.instance;
await storage.saveClaudeApiKey('sk-ant-test-key-123');
final key = await storage.getClaudeApiKey();
print(key); // Should print 'sk-ant-test-key-123'
await storage.deleteClaudeApiKey();
final hasKey = await storage.hasClaudeApiKey();
print(hasKey); // Should print false
```

**Android Permissions:**
No additional permissions needed - flutter_secure_storage handles this.

---

### Step 3: Settings Service & Provider
**Time Estimate:** 45 minutes

**Files to create:**
- `lib/services/settings_service.dart` (see above)
- `lib/providers/settings_provider.dart` (see above)

**Files to update:**
- `lib/main.dart` - Add SettingsProvider to MultiProvider

```dart
// lib/main.dart - UPDATE
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => TaskProvider()),
    ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
  ],
  child: MyApp(),
)
```

**Testing:**
- Verify API key validation (accept "sk-ant-...", reject others)
- Save and retrieve API key
- Check hasApiKey logic

---

### Step 4: Settings Screen UI
**Time Estimate:** 1.5 hours

**Files to create:**
- `lib/screens/settings_screen.dart`

**UI Implementation:**
```dart
// Pseudo-code structure
class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _isTesting = false;
  bool? _connectionValid; // null=unknown, true=valid, false=invalid
  String? _connectionMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Claude AI', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),

            // API Key Input
            TextField(
              decoration: InputDecoration(
                labelText: 'API Key',
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              obscureText: _obscureKey,
              controller: _apiKeyController,
              onChanged: (_) {
                // Reset connection status when key changes
                setState(() {
                  _connectionValid = null;
                  _connectionMessage = null;
                });
              },
            ),
            SizedBox(height: 16),

            // Connection Status Indicator
            if (_connectionValid != null)
              Row(
                children: [
                  Icon(
                    _connectionValid! ? Icons.check_circle : Icons.error,
                    color: _connectionValid! ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionMessage ?? (_connectionValid! ? 'Connected' : 'Connection failed'),
                      style: TextStyle(
                        color: _connectionValid! ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: _saveApiKey,
                  child: Text('Save API Key'),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.wifi_find),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: _deleteApiKey,
              child: Text('Delete API Key', style: TextStyle(color: Colors.red)),
            ),
            SizedBox(height: 24),

            // Help Text
            Text(
              'Get your API key from console.anthropic.com',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _connectionValid = false;
        _connectionMessage = 'Please enter an API key first';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _connectionValid = null;
    });

    try {
      final settingsService = SettingsService();
      final (success, errorMessage) = await settingsService.testApiKey(apiKey);

      if (mounted) {
        setState(() {
          _connectionValid = success;
          _connectionMessage = success ? 'Connected successfully!' : errorMessage;
          _isTesting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionValid = false;
          _connectionMessage = 'Test failed: $e';
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveApiKey() async {
    // ... save logic
    // After successful save, optionally run test
  }

  Future<void> _deleteApiKey() async {
    // ... delete logic with confirmation
  }
}
```

**Navigation:**
- Add Settings button to HomeScreen (app bar action)
- `Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()))`

**Testing:**
- Enter valid API key → save → verify stored
- Enter invalid key → show error
- Toggle visibility works
- Delete key → confirmation dialog → verify deleted

---

### Step 5: Claude Service
**Time Estimate:** 2 hours

**Files to create:**
- `lib/services/claude_service.dart` (see complete implementation above)

**Testing Strategy:**
1. **Manual API test** (use your real API key):
   ```dart
   final service = ClaudeService();
   final suggestions = await service.extractTasks(
     'I need to call the dentist and buy groceries. Also remind me to email Sarah.',
     'sk-ant-...',
   );
   print(suggestions);
   ```

2. **Test error handling:**
   - Invalid API key (401)
   - Network timeout
   - Malformed JSON response

3. **Test prompt engineering:**
   - Try different brain dumps
   - Check quality of extracted tasks
   - Verify JSON parsing is robust

**Common Issues:**
- Claude wraps JSON in markdown: ` ```json\n[...]\n``` ` → _extractJson() handles this
- API key format changed → update validation
- Rate limits → add retry logic if needed

---

### Step 6: Brain Dump Provider
**Time Estimate:** 1 hour

**Files to create:**
- `lib/providers/brain_dump_provider.dart` (see above)

**Files to update:**
- `lib/main.dart` - Add BrainDumpProvider

```dart
// lib/main.dart - UPDATE MultiProvider
ChangeNotifierProvider(
  create: (context) => BrainDumpProvider(
    context.read<SettingsProvider>(),
  ),
),
```

**Testing:**
- Update dump text → verify notifyListeners called
- Process dump → verify loading states
- Check error formatting for common API errors

---

### Step 7: Brain Dump Screen UI
**Time Estimate:** 1.5 hours

**Files to create:**
- `lib/screens/brain_dump_screen.dart`

**Key Implementation Details:**

```dart
// Large text field
TextField(
  controller: _textController,
  maxLines: null,  // Unlimited lines
  minLines: 20,    // Start with good height
  maxLength: AppConstants.maxBrainDumpLength,
  decoration: InputDecoration(
    hintText: 'Pour out your thoughts... everything that\'s on your mind',
    border: InputBorder.none,
    counterText: '${_textController.text.length} / ${AppConstants.maxBrainDumpLength}',
  ),
  style: TextStyle(fontSize: 16, height: 1.5),
  autofocus: true,
)
```

**Bottom Bar:**
```dart
BottomAppBar(
  child: Row(
    children: [
      TextButton(
        onPressed: _showClearConfirmation,  // Changed: confirmation before clear
        child: Text('Clear'),
      ),
      Spacer(),
      ElevatedButton.icon(
        onPressed: _dumpText.isEmpty ? null : _showCostConfirmation,
        icon: Icon(Icons.auto_awesome),
        label: Text('Claude, Help Me'),
      ),
    ],
  ),
)
```

**Clear Confirmation Dialog:**
```dart
void _showClearConfirmation() {
  if (_textController.text.isEmpty) {
    return; // Nothing to clear
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Clear Brain Dump?'),
      content: Text(
        'Are you sure you want to clear all text? This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _clearText();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Clear'),
        ),
      ],
    ),
  );
}
```

**Back Button / Navigation Away Handling:**
```dart
// IMPORTANT: PopScope intercepts ALL navigation methods:
// - Android back button press
// - iOS/Android swipe-back gesture
// - AppBar back button tap
// - Programmatic Navigator.pop() calls
//
// NOTE: Using PopScope (Flutter 3.12+). WillPopScope is deprecated.
// Project requires Flutter 3.24+ so PopScope is guaranteed available.

class BrainDumpScreen extends StatefulWidget {
  @override
  _BrainDumpScreenState createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends State<BrainDumpScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent automatic navigation
      onPopInvoked: (bool didPop) async {
        if (didPop) return; // Already popped, do nothing

        // Intercept ALL navigation attempts (button, gesture, etc.)
        if (_textController.text.trim().isNotEmpty) {
          final shouldExit = await _showExitConfirmation();
          if (shouldExit && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          // Empty text, allow navigation
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Brain Dump'),
          // Note: No custom leading needed, PopScope handles all back navigation
        ),
        body: /* ... brain dump UI ... */,
      ),
    );
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save Brain Dump?'),
        content: Text(
          'You have unsaved text. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text('Save Draft'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveDraft();
      return true; // Allow exit after saving
    } else if (result == 'discard') {
      return true; // Allow exit
    }
    return false; // Stay on screen (cancel)
  }

  Future<void> _saveDraft() async {
    final provider = context.read<BrainDumpProvider>();
    await provider.saveDraft(_textController.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draft saved')),
      );
    }
  }
}
```

**Cost Confirmation Modal:**
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Confirm Processing'),
    content: Text(
      'Estimated cost: \$${_estimatedCost.toStringAsFixed(3)}\n\n'
      'This will send your text to Claude AI for processing.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _processDump();
        },
        child: Text('Confirm'),
      ),
    ],
  ),
);
```

**Navigation:**
- Add "Brain Dump" FAB or button to HomeScreen
- After processing → navigate to TaskSuggestionPreviewScreen with suggestions
- **Any exit attempt with text** → Show save/discard/cancel dialog
  - Android back button press
  - iOS/Android swipe-back gesture
  - AppBar back button tap
- **App backgrounded with text** → Auto-save draft (handled in lifecycle)

**Testing:**
- Type long text → verify scrolling
- Tap "Claude, Help Me" with no API key → navigate to Settings
- Tap with API key → show cost modal
- Confirm → call API → verify loading state
- Success → navigate to preview
- Error → show error message
- **Exit behavior testing:**
  - Type text → tap back button → verify save/discard dialog
  - Type text → swipe back (iOS/Android gesture) → verify save/discard dialog
  - Tap "Save Draft" → verify draft saved and navigation allowed
  - Tap "Discard" → verify text lost and navigation allowed
  - Tap "Cancel" → verify stays on screen

---

### Step 8: Task Suggestion Preview Screen
**Time Estimate:** 2 hours

**Files to create:**
- `lib/screens/task_suggestion_preview_screen.dart`
- `lib/widgets/task_suggestion_item.dart`

**Screen Structure:**
```dart
Scaffold(
  appBar: AppBar(
    title: Text('Review Tasks'),
    actions: [
      IconButton(
        icon: Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  ),
  body: Column(
    children: [
      Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '${suggestions.length} tasks suggested',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            return TaskSuggestionItem(
              suggestion: suggestions[index],
              onToggle: (id) => provider.toggleSuggestionApproval(id),
              onEdit: (id, title) => provider.editSuggestion(id, title),
              onDelete: (id) => provider.removeSuggestion(id),
            );
          },
        ),
      ),
    ],
  ),
  bottomNavigationBar: BottomAppBar(
    child: Row(
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        Spacer(),
        ElevatedButton(
          onPressed: _addApprovedTasks,
          child: Text('Add ${approvedCount} Tasks'),
        ),
      ],
    ),
  ),
)
```

**TaskSuggestionItem Widget:**
```dart
Card(
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: ListTile(
    leading: Checkbox(
      value: suggestion.approved,
      onChanged: (_) => onToggle(suggestion.id),
    ),
    title: TextField(
      controller: TextEditingController(text: suggestion.title),
      onChanged: (value) => onEdit(suggestion.id, value),
      decoration: InputDecoration(border: InputBorder.none),
    ),
    subtitle: suggestion.notes != null
        ? Text(suggestion.notes!, style: TextStyle(fontSize: 12))
        : null,
    trailing: IconButton(
      icon: Icon(Icons.delete_outline, color: Colors.red),
      onPressed: () => onDelete(suggestion.id),
    ),
  ),
)
```

**Add Tasks Logic:**
```dart
Future<void> _addApprovedTasks() async {
  final provider = context.read<BrainDumpProvider>();
  final taskProvider = context.read<TaskProvider>();

  final approved = provider.getApprovedSuggestions();

  if (approved.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No tasks selected')),
    );
    return;
  }

  // Bulk create tasks in a single transaction (MUCH faster!)
  // Uses TaskProvider.createMultipleTasks() which:
  // 1. Creates all tasks in one database transaction
  // 2. Updates UI ONCE instead of N times
  // 3. No stuttering/flashing as tasks appear
  await taskProvider.createMultipleTasks(approved);

  // Clear brain dump
  provider.clear();

  // Navigate back to home
  if (context.mounted) {
    Navigator.popUntil(context, (route) => route.isFirst);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${approved.length} tasks added!')),
    );
  }
}
```

**Testing:**
- Receive suggestions → all checked by default
- Uncheck some → verify button count updates
- Edit title → verify saved
- Delete suggestion → verify removed
- Add tasks → verify created in TaskProvider
- Navigate back → verify tasks visible in HomeScreen

---

### Step 9: Integration & Polish
**Time Estimate:** 2 hours

**HomeScreen Updates:**
- Add floating action button with two options:
  - Quick Add (existing)
  - Brain Dump (new)
- OR: Add "Brain Dump" button in app bar

**Error Handling Polish:**
- Network errors → helpful messages
- API key errors → prompt to check settings
- Rate limits → explain and suggest wait time
- Empty responses → suggest rephrasing

**Loading States:**
- Show spinner during API call
- Disable buttons during processing
- Show progress text: "Claude is thinking..."

**Offline Handling:**
```dart
// Check connectivity before showing Brain Dump
final connectivity = Connectivity();
final connectivityResult = await connectivity.checkConnectivity();
final hasInternet = connectivityResult.contains(ConnectivityResult.mobile) ||
                    connectivityResult.contains(ConnectivityResult.wifi) ||
                    connectivityResult.contains(ConnectivityResult.ethernet);

if (!hasInternet) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('No Internet'),
      content: Text('Brain Dump requires an internet connection. Please connect and try again.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
  return;
}
```

---

### Step 10: Testing & Validation
**Time Estimate:** 2 hours

**Manual Testing Checklist:**

1. **Happy Path:**
   - [ ] Open app → tap Brain Dump
   - [ ] No API key → prompted to Settings
   - [ ] Enter API key → save → return
   - [ ] Enter brain dump text (realistic chaos)
   - [ ] Tap "Claude, Help Me" → see cost estimate
   - [ ] Confirm → wait for response (3-5 seconds)
   - [ ] Review suggestions → all checked by default
   - [ ] Edit one title
   - [ ] Uncheck one suggestion
   - [ ] Delete one suggestion
   - [ ] Tap "Add X Tasks" → see success message
   - [ ] Verify tasks appear in main list

2. **Error Cases:**
   - [ ] Invalid API key → see error message
   - [ ] No internet → see offline message
   - [ ] Empty brain dump → button disabled
   - [ ] API timeout → see timeout message
   - [ ] Malformed response → graceful error

3. **Edge Cases:**
   - [ ] Very long brain dump (5000+ chars) → still works
   - [ ] Brain dump with no actionable items → Claude returns empty array
   - [ ] Rapid consecutive calls → no crashes
   - [ ] App backgrounded during API call → resume gracefully
   - [ ] API key deleted while processing → handle error

**Performance Metrics:**
- [ ] API call completes in <5 seconds (typical)
- [ ] UI remains responsive during processing
- [ ] No memory leaks (check with DevTools)
- [ ] Battery impact minimal (<2% per dump)

**User Acceptance:**
- [ ] You find it genuinely helpful
- [ ] Would use weekly minimum
- [ ] Willing to pay API costs
- [ ] Feel less overwhelmed after using

---

### Step 11: Documentation
**Time Estimate:** 30 minutes

**Update README.md:**
```markdown
## Phase 2: Claude AI Integration

Pin and Paper now includes AI-assisted task organization!

### Setup:
1. Get a Claude API key from https://console.anthropic.com
2. Open Settings in the app
3. Enter your API key
4. Start using Brain Dump!

### Usage:
1. Tap "Brain Dump" button
2. Pour out all your chaotic thoughts
3. Tap "Claude, Help Me"
4. Review and edit suggested tasks
5. Add approved tasks to your list

### Cost:
Brain Dump uses Claude 3.5 Sonnet. Typical cost: $0.01-0.03 per dump.
```

**Code Comments:**
- Add docstrings to ClaudeService methods
- Explain prompt engineering choices
- Document error handling strategy

---

## Prompt Engineering Strategy

### Current Prompt (v1.0)
See ClaudeService._buildPrompt() above

### Iteration Plan
After initial testing, refine prompt based on:
- **Accuracy:** Are extracted tasks actually what user meant?
- **Completeness:** Missing important tasks?
- **Noise:** Extracting non-tasks?
- **Format:** JSON parsing issues?

### Future Enhancements (Phase 3)
```dart
// Add to prompt for Phase 3:
// - Date parsing: "next Tuesday" → due_date
// - Priority inference: "urgent" → priority: high
// - Tag suggestions: "work meeting" → tags: ["work", "meetings"]
```

---

## Error Handling & Edge Cases

### Network Errors
- **Timeout:** "Claude is taking too long. Check your connection and try again."
- **No internet:** "No internet connection. Brain Dump requires online access."
- **DNS failure:** "Can't reach Claude API. Check your network settings."

### API Errors
- **401 Unauthorized:** "Invalid API key. Please check Settings."
- **429 Rate Limited:** "Too many requests. Please wait 60 seconds and try again."
- **500 Internal Error:** "Claude API is having issues. Try again in a few minutes."
- **503 Overloaded:** "Claude is busy. Try again shortly."

### Parsing Errors
- **Invalid JSON:** Log error, show generic message, suggest retry
- **Empty response:** "Claude couldn't find any tasks. Try being more specific?"
- **Malformed tasks:** Skip invalid entries, show valid ones

### User Errors
- **Empty dump:** Disable button, show hint
- **No API key:** Navigate to Settings automatically
- **No approved tasks:** Show warning before closing preview

### Draft Persistence (CRITICAL)
**NEVER lose user's brain dump text.** When API calls fail, save the text for later processing.

**Implementation:**
- Save draft to local database on API failure
- Auto-save draft every 30 seconds while typing
- Show "Saved drafts" option in Brain Dump screen
- User can load saved draft and retry processing
- Drafts persist until successfully processed or manually deleted

**Draft Schema (add to database):**
```sql
CREATE TABLE brain_dump_drafts (
  id TEXT PRIMARY KEY,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_modified INTEGER NOT NULL,
  failed_reason TEXT  -- Store error message for context
);
```

**When to save draft:**
- API call fails (network, timeout, rate limit, etc.)
- App backgrounded during processing
- User navigates away from Brain Dump screen with unsaved text
- Every 30 seconds of typing (auto-save)

**Draft recovery flow:**
1. User opens Brain Dump screen
2. Check for saved drafts
3. If drafts exist, show "Load Draft" button
4. User taps → show draft picker
5. Select draft → load into text field
6. User can edit and retry processing
7. On success → delete draft
8. Manual "Delete Draft" option available

---

## Security Considerations

### ⚠️ CRITICAL: API Key Protection

**NEVER expose API keys in logs, error messages, or UI:**

```dart
// ❌ NEVER DO THIS:
print('API key: $apiKey'); // Exposed in logs!
throw Exception('Failed with key: $apiKey'); // Exposed in error!
Text('Using key: $apiKey'); // Exposed in UI!

// ✅ ALWAYS DO THIS:
print('API key: ${apiKey.substring(0, 10)}...'); // Only show prefix
throw Exception('API authentication failed'); // No key in message
// Never show full key in UI (already obscured in TextField)
```

**Code Review Checklist:**
- [ ] No `print()` statements with API keys
- [ ] No exception messages containing API keys
- [ ] No logging of HTTP headers containing API keys
- [ ] No debug screens showing full API keys

### API Key Storage
✅ **DO:**
- Store in flutter_secure_storage (encrypted)
- Use Android Keystore (hardware-backed)
- Never commit API keys to git
- Obscure in UI (TextField with obscureText: true)

❌ **DON'T:**
- Store in SharedPreferences (plain text)
- Store in app files
- Include in any logs (debug, error, analytics)
- Hardcode API keys
- Include in error messages or stack traces

### API Communication
✅ **DO:**
- Use HTTPS only
- Validate SSL certificates
- Set reasonable timeouts
- Rate limit client-side

❌ **DON'T:**
- Allow HTTP fallback
- Store request/response bodies
- Retry indefinitely
- Cache API responses with sensitive data

### User Privacy
- Brain dump text is sent to Claude API (Anthropic)
- Anthropic's privacy policy applies
- Consider adding privacy notice in Settings
- Option to delete data after processing

---

## Performance Optimization

### API Call Optimization
- **Timeout:** 30 seconds max
- **Retry logic:** Don't retry on 4xx errors
- **Caching:** Don't cache (each dump is unique)
- **Compression:** HTTP client handles this

### UI Responsiveness
- All API calls in async/await (never block UI thread)
- Show loading indicators immediately
- Cancel requests on navigation away
- Background isolate if processing large responses (unlikely needed)

### Memory Management
- Clear brain dump text after processing
- Don't keep API response in memory
- Dispose controllers properly
- Use const constructors where possible

---

## Cost Analysis

### Claude 3.5 Sonnet Pricing (2024)
- **Input:** $3 per million tokens (~$0.003 per 1K tokens)
- **Output:** $15 per million tokens (~$0.015 per 1K tokens)

### Typical Brain Dump
- **Input:** 500-1000 tokens (user text + prompt)
- **Output:** 200-500 tokens (JSON response)
- **Total Cost:** $0.005 - $0.015 per dump

### Monthly Estimate
- **Daily user:** 1 dump/day × 30 days = $0.15 - $0.45/month
- **Weekly user:** 4 dumps/month = $0.02 - $0.06/month

**Conclusion:** Very affordable for the value provided.

---

## Testing Strategy

### Unit Tests
```dart
// test/services/claude_service_test.dart
test('estimateCost calculates correctly', () {
  final service = ClaudeService();
  final cost = service.estimateCost('This is a test' * 100);
  expect(cost, greaterThan(0));
  expect(cost, lessThan(1.0)); // Sanity check
});

test('_extractJson handles markdown wrapper', () {
  final service = ClaudeService();
  final input = '```json\n[{"title": "Task"}]\n```';
  final result = service._extractJson(input);
  expect(result, '[{"title": "Task"}]');
});
```

### Widget Tests
```dart
// test/screens/brain_dump_screen_test.dart
testWidgets('shows cost confirmation before processing', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('Brain Dump'));
  await tester.pump();

  await tester.enterText(find.byType(TextField), 'Test brain dump');
  await tester.tap(find.text('Claude, Help Me'));
  await tester.pump();

  expect(find.text('Confirm Processing'), findsOneWidget);
  expect(find.textContaining('Estimated cost'), findsOneWidget);
});
```

### Integration Tests
```dart
// integration_test/brain_dump_flow_test.dart
testWidgets('complete brain dump flow', (tester) async {
  // Set up mock API key
  final storage = SecureStorageService.instance;
  await storage.saveClaudeApiKey('sk-ant-test-key');

  await tester.pumpWidget(MyApp());

  // Navigate to brain dump
  await tester.tap(find.text('Brain Dump'));
  await tester.pumpAndSettle();

  // Enter text
  await tester.enterText(
    find.byType(TextField),
    'I need to buy groceries and call the dentist',
  );

  // Process (with mocked API response)
  await tester.tap(find.text('Claude, Help Me'));
  await tester.pumpAndSettle();

  // Verify suggestions shown
  expect(find.text('Buy groceries'), findsOneWidget);
  expect(find.text('Call the dentist'), findsOneWidget);

  // Add tasks
  await tester.tap(find.text('Add 2 Tasks'));
  await tester.pumpAndSettle();

  // Verify tasks in main list
  expect(find.text('Buy groceries'), findsOneWidget);
});
```

---

## Success Criteria (Phase 2 Complete)

### Technical Success
- ✅ API integration works reliably
- ✅ API key stored securely
- ✅ Error handling covers all cases
- ✅ UI is responsive during processing
- ✅ All tests pass
- ✅ No crashes in 1 week of testing

### User Success
- ✅ User opens Brain Dump **weekly minimum**
- ✅ Claude extracts tasks accurately **>80%**
- ✅ User reports feeling **less overwhelmed**
- ✅ User would **pay for API costs**
- ✅ User recommends feature to others

### Critical Decision Point
**If user success criteria are NOT met:**
- Iterate on prompt engineering (2-3 attempts)
- Try different Claude model
- Consider alternative AI providers
- **If still not helpful → pivot away from AI feature**

**If user success criteria ARE met:**
- ✅ Proceed to Phase 3 (Core Features)
- Consider Phase 3 enhancements:
  - Natural language date parsing
  - Tag suggestions
  - Priority inference
  - Multi-language support

---

## Future Enhancements (Post-Phase 2)

### Phase 3 Intelligence
- **Date parsing:** "next Tuesday" → set due_date
- **Tag suggestions:** Analyze content for relevant tags
- **Priority inference:** "urgent" → set priority
- **Related task detection:** Group similar tasks

### Phase 4+ Features
- **Voice brain dump:** Record audio → transcribe → process
- **Scheduled dumps:** "Daily brain dump" reminder
- **Dump history:** Review past dumps and learnings
- **Custom prompts:** User-defined extraction rules
- **Multi-model support:** Try GPT-4, Gemini, etc.

### Enterprise/Advanced
- **Team brain dumps:** Collaborative task extraction
- **Project templates:** Pre-defined prompt templates
- **Analytics:** Track dump effectiveness over time
- **Cost controls:** Budget limits, warning thresholds

---

## Appendix: Example Brain Dumps

### Example 1: Work Overwhelm
**Input:**
```
I have so much to do today. Need to finish the Q4 report by EOD, it's been sitting
there for a week. Also my boss wants to meet about the project timeline but I haven't
even looked at it yet. I should probably update the spreadsheet first. Oh and I need
to email Sarah back about the client meeting next week, she's been waiting since
Tuesday. And I still haven't called the IT desk about my laptop being slow. This is
too much.
```

**Expected Output:**
```json
[
  {"title": "Finish Q4 report", "notes": "Due end of day"},
  {"title": "Review project timeline", "notes": "Prep for boss meeting"},
  {"title": "Update project spreadsheet", "notes": null},
  {"title": "Email Sarah about client meeting", "notes": "She's been waiting since Tuesday"},
  {"title": "Call IT desk about slow laptop", "notes": null}
]
```

### Example 2: Personal Life
**Input:**
```
Dentist appointment is next week but I haven't called to confirm. Need groceries:
milk, eggs, bread, coffee. Car is making that weird noise again, should probably
get it checked before it gets worse. Mom's birthday is coming up, need to order
something on Amazon. And I promised I'd clean out the garage this weekend.
```

**Expected Output:**
```json
[
  {"title": "Confirm dentist appointment", "notes": "Appointment is next week"},
  {"title": "Buy groceries", "notes": "milk, eggs, bread, coffee"},
  {"title": "Get car checked", "notes": "Making weird noise"},
  {"title": "Order Mom's birthday gift on Amazon", "notes": null},
  {"title": "Clean out garage", "notes": "Promised to do this weekend"}
]
```

---

## Resources & References

### API Documentation
- Claude API Docs: https://docs.anthropic.com/en/api/
- Messages endpoint: https://docs.anthropic.com/en/api/messages
- Pricing: https://www.anthropic.com/pricing

### Flutter Packages
- http: https://pub.dev/packages/http
- flutter_secure_storage: https://pub.dev/packages/flutter_secure_storage
- connectivity_plus: https://pub.dev/packages/connectivity_plus

### Design References
- Material 3 text fields: https://m3.material.io/components/text-fields
- Loading states: https://m3.material.io/foundations/interaction/states

---

## Next Steps After Phase 2

**Immediate (within 1 week):**
1. Test with real usage for 7 days
2. Measure success metrics
3. Gather user feedback
4. Iterate on prompt engineering

**Short-term (within 1 month):**
1. If successful → Plan Phase 3
2. If not successful → Analyze why, iterate or pivot
3. Share with ADHD community for feedback
4. Consider soft launch / beta testing

**Decision Point:**
This phase is THE validation of Pin and Paper's unique value. If it works, continue building. If it doesn't, reconsider the entire product direction. Don't proceed to Phase 3 without validating Phase 2 first.

---

**Let's build the killer feature.** 🧠✨🤖

*From chaos to clarity, with Claude as your co-pilot.*
