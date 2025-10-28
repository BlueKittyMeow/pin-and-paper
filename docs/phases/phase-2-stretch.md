# Phase 2 Stretch Goals - Planning Document (CORRECTED)

**Branch:** `phase-2-stretch`
**Status:** Planning (Reviewed & Corrected by Codex, Gemini, Claude)
**Target:** Q4 2025 (after Phase 2 completion)
**Database Version:** 3 (unified migration for all stretch goals)

---

## ⚠️ Corrections Applied

This document has been reviewed and corrected based on feedback from Codex and Gemini. Major fixes:

1. **✅ FIXED:** Removed duplicate `completed_at` column migration (already exists from Phase 1)
2. **✅ FIXED:** BrainDumpProvider architecture - provider returns text, widget owns controller
3. **✅ FIXED:** Added proper database migration for `api_usage_log` table (version 2→3)
4. **✅ FIXED:** Unified all database schema changes under single version bump (v3)
5. **✅ FIXED:** Corrected Task model references (`completed` not `isCompleted`, `DateTime` not `int`)
6. **✅ FIXED:** Efficient task categorization (calculate once, not per build)
7. **✅ FIXED:** String similarity API usage (StringSimilarity.compareTwoStrings, not .similarityTo())
8. **✅ FIXED:** toStringAsFixed(0) compile error on int
9. **✅ ADDED:** Unique draft separator (`--- DRAFT SEPARATOR ---`)
10. **✅ ADDED:** Reset Usage Data button in Cost Tracking UI

---

## Overview

Phase 2 Stretch Goals focus on polish, usability improvements, and power-user features that enhance the core Brain Dump + AI workflow without adding major new complexity.

**Guiding Principles:**
- Improve existing features rather than add new ones
- Maintain simplicity and zero-friction philosophy
- Keep costs low (minimize API usage)
- ADHD-friendly: reduce cognitive load, not increase it

---

## Stretch Goals Summary

| Feature | Priority | Complexity | Estimated Cost Impact |
|---------|----------|------------|----------------------|
| 1. Hide Completed (Time-Based) | High | Medium | None |
| 2. Natural Language Task Completion | High | Medium | ~$0.00 (local fuzzy search) |
| 3. Draft Management (Multi-Select) | Medium | Medium | None |
| 4. Brain Dump Review Bottom Sheet | Medium | Low | None |
| 5. Cost Tracking Dashboard | Medium | Low | None |
| 6. Improved Loading States | Low | Medium | None |

---

## 1. Hide Completed Tasks (Advanced Time-Based) ✨

### Problem
- Completed tasks clutter the list
- Hard to focus on active tasks
- Need to see recently completed tasks (sense of accomplishment)
- But old completed tasks are just noise

### Solution
**Time-based visibility with customizable threshold.**

**Settings Option:** "Hide completed tasks older than [24 hours]"

**Visual Treatment:**
- **Recently completed** (< 24 hours):
  - Faint + crossed out
  - Moved to bottom of list
  - Below a separator line
  - Still visible (sense of accomplishment!)

- **Old completed** (> 24 hours):
  - Completely hidden
  - Helps with future daybook/planner view

### Design

**Settings Screen:**
```
┌─────────────────────────────────┐
│ Task Display                    │
├─────────────────────────────────┤
│ ☑️ Hide old completed tasks     │
│                                 │
│ Hide tasks completed more than: │
│ [ 24 hours ▼ ]                  │
│                                 │
│ Options: 6h, 12h, 24h, 3 days,  │
│          1 week, Never          │
└─────────────────────────────────┘
```

**Home Screen Visual:**
```
Active Tasks
┌─────────────────────────────────┐
│ ☐ Call dentist                  │
│ ☐ Work on dev project           │
│ ☐ Buy groceries                 │
└─────────────────────────────────┘

───── Recently Completed ─────

┌─────────────────────────────────┐
│ ☑️ Tell Kyla about yarn (faint)│
│ ☑️ Fill out vet paperwork       │
└─────────────────────────────────┘

(Tasks >24h old: hidden completely)
```

**Behavior:**
- Tasks sort automatically: Active → Recent completed → Hidden
- Recently completed are faint (50% opacity) + strikethrough
- If task uncompleted, timer resets (starts fresh when re-completed)
- Smooth animation when tasks cross threshold

### Technical Implementation

#### 1.1 Database Schema - No Changes Needed! ✅

**IMPORTANT:** The `completed_at` column ALREADY EXISTS in the tasks table from Phase 1!

**Current Task Model (Phase 2):**
```dart
// lib/models/task.dart
class Task {
  final String id;
  final String title;
  final bool completed;          // Note: "completed" not "isCompleted"
  final DateTime createdAt;      // Note: DateTime not int
  final DateTime? completedAt;   // ✅ ALREADY EXISTS - ready to use!

  // Helper: How long has this task been completed?
  Duration? get timeSinceCompletion {
    if (completedAt == null) return null;
    return DateTime.now().difference(completedAt!);
  }
}
```

#### 1.2 Settings Service

```dart
// lib/services/preferences_service.dart
class PreferencesService {
  static const String _hideOldCompletedKey = 'hide_old_completed';
  static const String _hideThresholdKey = 'hide_threshold_hours';

  Future<bool> getHideOldCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideOldCompletedKey) ?? true;  // Default: ON
  }

  Future<void> setHideOldCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideOldCompletedKey, value);
  }

  Future<int> getHideThresholdHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hideThresholdKey) ?? 24;  // Default: 24 hours
  }

  Future<void> setHideThresholdHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hideThresholdKey, hours);
  }
}
```

#### 1.3 Provider Updates

```dart
// lib/providers/task_provider.dart
class TaskProvider extends ChangeNotifier {
  bool _hideOldCompleted = true;
  int _hideThresholdHours = 24;

  // Pre-categorized lists (calculated once per load, not on every build)
  List<Task> _activeTasks = [];
  List<Task> _recentlyCompletedTasks = [];
  List<Task> _oldCompletedTasks = [];

  // Public getters for categorized lists
  List<Task> get activeTasks => _activeTasks;
  List<Task> get recentlyCompletedTasks => _recentlyCompletedTasks;
  List<Task> get oldCompletedTasks => _oldCompletedTasks;

  // For rendering: active + recently completed (old are hidden)
  List<Task> get visibleTasks {
    if (_hideOldCompleted) {
      return [..._activeTasks, ..._recentlyCompletedTasks];
    }
    return _tasks;  // Show all
  }

  // Categorize tasks after loading (called once per load, not per build)
  void _categorizeTasks() {
    final now = DateTime.now();

    _activeTasks = _tasks.where((t) => !t.completed).toList();

    _recentlyCompletedTasks = _tasks.where((t) {
      if (!t.completed) return false;
      if (t.completedAt == null) return false;

      final hoursSinceCompletion =
        now.difference(t.completedAt!).inHours;

      return hoursSinceCompletion < _hideThresholdHours;
    }).toList();

    _oldCompletedTasks = _tasks.where((t) {
      if (!t.completed) return false;
      if (t.completedAt == null) return true;  // Show if no timestamp

      final hoursSinceCompletion =
        now.difference(t.completedAt!).inHours;

      return hoursSinceCompletion >= _hideThresholdHours;
    }).toList();
  }

  Future<void> loadTasks() async {
    _tasks = await _taskService.getAllTasks();
    _categorizeTasks();  // Categorize once after load
    notifyListeners();
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    final newCompletionState = !task.completed;

    // Set or clear completed_at timestamp
    final completedAt = newCompletionState
      ? DateTime.now()
      : null;

    await _taskService.updateTask(
      taskId,
      completed: newCompletionState,
      completedAt: completedAt,
    );

    await loadTasks();  // Reload and re-categorize
  }

  Future<void> loadPreferences() async {
    _hideOldCompleted = await PreferencesService().getHideOldCompleted();
    _hideThresholdHours = await PreferencesService().getHideThresholdHours();
    notifyListeners();
  }
}
```

#### 1.4 UI Implementation

```dart
// lib/screens/home_screen.dart
ListView(
  children: [
    // Active tasks
    ...taskProvider.activeTasks.map((task) =>
      TaskItem(task: task, isFaint: false)),

    // Separator (if there are recent completed tasks)
    if (taskProvider.recentlyCompletedTasks.isNotEmpty) ...[
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Recently Completed',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
      ),

      // Recently completed tasks (faint + strikethrough)
      ...taskProvider.recentlyCompletedTasks.map((task) =>
        TaskItem(task: task, isFaint: true)),
    ],
  ],
)

// lib/widgets/task_item.dart
class TaskItem extends StatelessWidget {
  final Task task;
  final bool isFaint;

  const TaskItem({
    required this.task,
    required this.isFaint,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isFaint ? 0.5 : 1.0,
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (value) {
            context.read<TaskProvider>().toggleTaskCompletion(task.id);
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed
              ? TextDecoration.lineThrough
              : null,
          ),
        ),
        // Note: Task model has no notes field currently
      ),
    );
  }
}
```

### Dependencies
- `shared_preferences: ^2.2.0` (already used in Flutter ecosystem, lightweight)

### Testing Checklist
- [ ] ✅ Verified `completed_at` column exists in database (no migration needed)
- [ ] Timestamp set correctly when task completed
- [ ] Timestamp cleared when task uncompleted
- [ ] Active tasks show at top
- [ ] Recently completed show below separator (faint)
- [ ] Old completed tasks hidden
- [ ] Separator only shows when recent tasks exist
- [ ] Settings threshold dropdown works
- [ ] Preference persists across restarts
- [ ] Edge case: Task completed exactly at threshold
- [ ] Works for future daybook/planner (timestamps ready!)
- [ ] Performance: Task categorization runs once per load, not per build

### Estimated Time
- **No database migration needed** (column already exists)
- **Implementation:** 4-5 hours (efficient categorization pattern)
- **Testing:** 1 hour

---

## 2. Natural Language Task Completion 🎯

### Problem
User wants to mark tasks complete via natural language:
- "I finished calling the dentist"
- "Done with grocery shopping"
- "Completed the report"

Current flow requires:
1. Finding task in list
2. Tapping checkbox

This is friction, especially for ADHD users.

### Solution: Local Fuzzy Search + Smart Matching

**Key Insight:** We can avoid expensive AI calls by using local fuzzy string matching for 95% of cases.

### Design

#### Option A: Dedicated "Quick Complete" Screen (Recommended)
New screen with:
- Text input: "What did you finish?"
- Fuzzy search matches as you type
- Tap match to mark complete
- Confirmation animation

**Flow:**
1. Tap "⚡ Quick Complete" button on home screen
2. Type: "finished calling dentist"
3. App shows: "Call dentist for appointment" (85% match)
4. Tap to confirm → marked complete
5. Success animation + navigate back

#### Option B: Add to Brain Dump Screen
Brain Dump detects completion phrases and offers to mark tasks complete instead of creating new ones.

**Pros of Option A:**
- Clearer intent (separate screen)
- Faster (no AI processing)
- Works offline
- Free (no API cost)

**Cons:**
- One more screen to implement

### Technical Implementation

#### 2.1 Fuzzy Matching Logic

```dart
// lib/services/task_matching_service.dart
import 'package:string_similarity/string_similarity.dart';

class TaskMatchingService {
  static const double CONFIDENT_THRESHOLD = 0.75;  // 75% similarity = auto-match
  static const double POSSIBLE_THRESHOLD = 0.50;    // 50% = show as option

  // Extract action from completion phrase
  String extractAction(String input) {
    // Remove completion indicators
    final cleaned = input.toLowerCase()
      .replaceAll(RegExp(r'\b(i |i\'ve |finished |done |completed |did )\b'), '')
      .replaceAll(RegExp(r'\b(the |a |an )\b'), '')
      .trim();

    return cleaned;
  }

  // Find best matching tasks
  List<TaskMatch> findMatches(String input, List<Task> tasks) {
    final action = extractAction(input);
    final incompleteTasks = tasks.where((t) => !t.completed).toList();

    return incompleteTasks
      .map((task) {
        // Use StringSimilarity.compareTwoStrings (NOT .similarityTo())
        final similarity = StringSimilarity.compareTwoStrings(
          action,
          task.title.toLowerCase(),
        );
        return TaskMatch(task: task, similarity: similarity);
      })
      .where((match) => match.similarity >= POSSIBLE_THRESHOLD)
      .toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));  // Best first
  }

  // Get best match if confident
  TaskMatch? getConfidentMatch(String input, List<Task> tasks) {
    final matches = findMatches(input, tasks);
    if (matches.isEmpty) return null;

    final best = matches.first;
    return best.similarity >= CONFIDENT_THRESHOLD ? best : null;
  }
}

class TaskMatch {
  final Task task;
  final double similarity;

  TaskMatch({required this.task, required this.similarity});

  // Note: UI-specific labels moved to widget for better separation of concerns
}
```

#### 2.2 Quick Complete Screen

```dart
// lib/screens/quick_complete_screen.dart
class QuickCompleteScreen extends StatefulWidget {
  @override
  State<QuickCompleteScreen> createState() => _QuickCompleteScreenState();
}

class _QuickCompleteScreenState extends State<QuickCompleteScreen> {
  final TextEditingController _controller = TextEditingController();
  List<TaskMatch> _matches = [];

  void _searchMatches(String input) {
    if (input.trim().isEmpty) {
      setState(() => _matches = []);
      return;
    }

    final taskProvider = context.read<TaskProvider>();
    final matches = TaskMatchingService().findMatches(
      input,
      taskProvider.tasks,
    );

    setState(() => _matches = matches);
  }

  Future<void> _completeTask(TaskMatch match) async {
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.toggleTaskCompletion(match.task.id);

    // Success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Completed: ${match.task.title}'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Complete')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input field
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'What did you finish?',
                hintText: 'e.g., "finished calling dentist"',
                border: OutlineInputBorder(),
              ),
              onChanged: _searchMatches,
            ),
            SizedBox(height: 16),

            // Matches list
            Expanded(
              child: _matches.isEmpty
                ? Center(child: Text('Type to search your tasks...'))
                : ListView.builder(
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      final match = _matches[index];
                      // UI logic for confidence label (not in model)
                      String getConfidenceLabel(double similarity) {
                        if (similarity >= 0.90) return 'Exact match';
                        if (similarity >= 0.75) return 'Likely match';
                        return 'Possible match';
                      }

                      return ListTile(
                        leading: Icon(
                          Icons.task_alt,
                          color: match.similarity >= 0.75
                            ? Colors.green
                            : Colors.orange,
                        ),
                        title: Text(match.task.title),
                        subtitle: Text(
                          '${(match.similarity * 100).toStringAsFixed(0)}% match - ${getConfidenceLabel(match.similarity)}',
                        ),
                        trailing: Icon(Icons.check_circle_outline),
                        onTap: () => _completeTask(match),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 2.3 Add Button to Home Screen

```dart
// lib/screens/home_screen.dart
FloatingActionButton.extended(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuickCompleteScreen()),
    );
  },
  icon: Icon(Icons.bolt),
  label: Text('Quick Complete'),
)
```

### Dependencies
- `string_similarity: ^2.0.0` (Levenshtein distance, fuzzy matching)
  - **Note:** Package hasn't been updated in 2+ years, but is stable and functional
  - Algorithm is mathematical (Levenshtein distance) - doesn't need frequent updates
  - Alternative for future: `fuzzy` package (more actively maintained)
  - Acceptable for Phase 2 Stretch; re-evaluate for Phase 3 if issues arise

### Future Enhancements (Phase 3+)
- Voice input for completion
- ML model for better phrase understanding
- Auto-complete suggestions
- "Recently completed" quick-access

### Design Consideration: "Call in Claude" Fallback

**User Feedback:** Should we add a "Call in Claude" toggle for more difficult searches?

**Pros of AI Fallback:**
- Handles complex natural language ("finished that thing I mentioned yesterday")
- Better context understanding
- Could learn from past patterns

**Cons:**
- Adds API cost (~$0.01 per query)
- Slower than local matching
- More complexity in UI

**Recommendation:**
- **Phase 2 Stretch:** Stick with local fuzzy matching only (95% accuracy, FREE)
- **Phase 3:** Add AI fallback if user testing shows it's needed
- **Implementation:** Add button below matches list: "Can't find it? Ask Claude" (only shows if no good local matches)

**Code Sketch (for future reference):**
```dart
// Show "Call in Claude" button if no confident matches
if (_matches.isEmpty || _matches.first.similarity < 0.50) {
  TextButton.icon(
    icon: Icon(Icons.psychology),
    label: Text('Ask Claude to find it'),
    onPressed: () async {
      // Call Claude API with full task list context
      final match = await ClaudeService().findTaskMatch(
        userInput: _controller.text,
        tasks: taskProvider.tasks,
      );
      // ...
    },
  );
}
```

**Decision:** Defer to Phase 3+ based on user feedback. Start with free local matching.

### Testing Checklist
- [ ] Exact matches work (100% similarity)
- [ ] Close matches work (75-99%)
- [ ] Partial matches show as options (50-74%)
- [ ] No matches shows empty state
- [ ] Completion animation works
- [ ] Task removed from list when completed
- [ ] Works with hide completed toggle
- [ ] Doesn't match already-completed tasks

### Estimated Time
- **Implementation:** 4-6 hours
- **Testing & polish:** 2 hours

---

## 3. Draft Management UI 📝

### Problem
- Drafts are saved when Brain Dump fails
- No way to see or access saved drafts
- User loses track of incomplete thoughts

### Solution
Add "Saved Drafts" UI with **multi-selection** to combine drafts.

### Design

**UI Location:** Brain Dump screen - Add button at top
```
[Brain Dump]              [📑 Drafts (3)]
```

**Drafts List Screen:**
- List of saved drafts with **checkboxes** for multi-select
- Show preview (first 100 chars) + date + character count
- Select multiple drafts to combine
- "Load X Drafts" button (updates with selection count)
- **Character limit warning** if combined > 10,000 chars
- Swipe individual drafts to delete
- Empty state: "No saved drafts"

**Character Limit Handling:**

**Why 10,000 characters?** This limit comes from the existing Brain Dump screen (Phase 2 implementation). The limit balances:
- API cost control (~500-1000 tokens ≈ $0.01)
- Claude context window usage
- User cognitive load (even ADHD brain dumps rarely exceed 10k chars)
- Mobile text input performance

```
Selected: 2 drafts (8,240 characters)
[Load 2 Drafts]

─── OR (if over limit) ───

⚠️ Selected: 3 drafts (12,450 characters)
   Exceeds 10,000 character limit by 2,450

[Too much text - remove a draft]  (button disabled)
```

### Technical Implementation

#### 3.1 Brain Dump Draft Model

**IMPORTANT:** Define the model before using it in providers and services.

```dart
// lib/models/brain_dump_draft.dart
class BrainDumpDraft {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime lastModified;
  final String? failedReason;  // Error message if processing failed

  BrainDumpDraft({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.lastModified,
    this.failedReason,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_modified': lastModified.millisecondsSinceEpoch,
      'failed_reason': failedReason,
    };
  }

  // Create from Map (database row)
  factory BrainDumpDraft.fromMap(Map<String, dynamic> map) {
    return BrainDumpDraft(
      id: map['id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastModified: DateTime.fromMillisecondsSinceEpoch(map['last_modified'] as int),
      failedReason: map['failed_reason'] as String?,
    );
  }
}
```

#### 3.2 Provider Updates

```dart
// lib/providers/brain_dump_provider.dart
class BrainDumpProvider extends ChangeNotifier {
  static const int MAX_CHAR_LIMIT = 10000;

  List<BrainDumpDraft> _drafts = [];
  Set<String> _selectedDraftIds = {};

  List<BrainDumpDraft> get drafts => _drafts;
  Set<String> get selectedDraftIds => _selectedDraftIds;

  int get selectedCount => _selectedDraftIds.length;

  // Calculate total characters in selected drafts
  int get selectedTotalChars {
    return _drafts
      .where((draft) => _selectedDraftIds.contains(draft.id))
      .fold(0, (sum, draft) => sum + draft.content.length);
  }

  bool get isOverLimit => selectedTotalChars > MAX_CHAR_LIMIT;

  int get excessCharacters =>
    isOverLimit ? selectedTotalChars - MAX_CHAR_LIMIT : 0;

  Future<void> loadDrafts() async {
    _drafts = await DatabaseService.instance.getBrainDumpDrafts();
    _selectedDraftIds.clear();
    notifyListeners();
  }

  void toggleDraftSelection(String draftId) {
    if (_selectedDraftIds.contains(draftId)) {
      _selectedDraftIds.remove(draftId);
    } else {
      _selectedDraftIds.add(draftId);
    }
    notifyListeners();
  }

  // Return combined text for widget to set in its controller
  // Provider should NOT own UI controllers (architectural violation)
  String getCombinedDraftsText() {
    final selectedDrafts = _drafts
      .where((draft) => _selectedDraftIds.contains(draft.id))
      .toList();

    return selectedDrafts
      .map((draft) => draft.content)
      .join('\n\n--- DRAFT SEPARATOR ---\n\n');  // Unique separator
  }

  Future<void> deleteSelectedDrafts() async {
    // Delete loaded drafts (they're now in the editor)
    for (final draftId in _selectedDraftIds) {
      await DatabaseService.instance.deleteBrainDumpDraft(draftId);
    }

    _selectedDraftIds.clear();
    await loadDrafts();
  }

  Future<void> deleteDraft(String draftId) async {
    await DatabaseService.instance.deleteBrainDumpDraft(draftId);
    _selectedDraftIds.remove(draftId);
    await loadDrafts();
  }
}
```

#### 3.3 Database Service

**CRITICAL:** Use the correct constant name from the codebase.

```dart
// lib/services/database_service.dart
Future<List<BrainDumpDraft>> getBrainDumpDrafts() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    AppConstants.brainDumpDraftsTable,  // FIXED: Use correct constant name
    orderBy: 'last_modified DESC',
  );

  return maps.map((m) => BrainDumpDraft.fromMap(m)).toList();
}

Future<void> deleteBrainDumpDraft(String id) async {
  final db = await database;
  await db.delete(
    AppConstants.brainDumpDraftsTable,  // FIXED: Use correct constant name
    where: 'id = ?',
    whereArgs: [id],
  );
}
```

#### 3.4 Drafts List Screen (Multi-Select)

```dart
// lib/screens/drafts_list_screen.dart
class DraftsListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Drafts')),
      body: Consumer<BrainDumpProvider>(
        builder: (context, provider, child) {
          if (provider.drafts.isEmpty) {
            return Center(child: Text('No saved drafts'));
          }

          return Column(
            children: [
              // Selection summary + load button
              if (provider.selectedCount > 0)
                Container(
                  padding: EdgeInsets.all(16),
                  color: provider.isOverLimit
                    ? Colors.red.shade50
                    : Colors.blue.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.isOverLimit
                          ? '⚠️ Selected: ${provider.selectedCount} drafts (${provider.selectedTotalChars} characters)'
                          : 'Selected: ${provider.selectedCount} drafts (${provider.selectedTotalChars} characters)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: provider.isOverLimit ? Colors.red : Colors.blue,
                        ),
                      ),
                      if (provider.isOverLimit) ...[
                        SizedBox(height: 4),
                        Text(
                          'Exceeds 10,000 character limit by ${provider.excessCharacters}',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: provider.isOverLimit
                          ? null
                          : () async {
                              // Get combined text from provider
                              final combinedText = provider.getCombinedDraftsText();

                              // Widget sets its own controller (not provider)
                              // This must be done in the parent screen that owns the controller
                              Navigator.pop(context, combinedText);
                            },
                        child: Text(
                          provider.isOverLimit
                            ? 'Too much text - remove a draft'
                            : 'Load ${provider.selectedCount} Draft${provider.selectedCount > 1 ? "s" : ""}',
                        ),
                      ),
                    ],
                  ),
                ),

              // Draft list
              Expanded(
                child: ListView.builder(
                  itemCount: provider.drafts.length,
                  itemBuilder: (context, index) {
                    final draft = provider.drafts[index];
                    final preview = draft.content.length > 100
                      ? '${draft.content.substring(0, 100)}...'
                      : draft.content;

                    final isSelected = provider.selectedDraftIds.contains(draft.id);

                    return Dismissible(
                      key: Key(draft.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => provider.deleteDraft(draft.id),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => provider.toggleDraftSelection(draft.id),
                        title: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatDate(draft.lastModified)} • ${draft.content.length} chars',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
```

#### 3.5 Add to Brain Dump Screen

```dart
// lib/screens/brain_dump_screen.dart - AppBar
AppBar(
  title: const Text('Brain Dump'),
  actions: [
    Consumer<BrainDumpProvider>(
      builder: (context, provider, child) {
        final draftCount = provider.drafts.length;
        return Badge(
          label: Text('$draftCount'),
          isLabelVisible: draftCount > 0,
          child: IconButton(
            icon: Icon(Icons.article_outlined),
            tooltip: 'Saved Drafts',
            onPressed: () async {
              // Navigate to drafts screen, await result
              final combinedText = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (context) => DraftsListScreen()),
              );

              // Widget owns the controller - provider returns text
              if (combinedText != null) {
                _textController.text = combinedText;

                // Delete drafts after loading
                await context.read<BrainDumpProvider>().deleteSelectedDrafts();
              }
            },
          ),
        );
      },
    ),
  ],
)
```

### Auto-Cleanup Strategy

Add cleanup for old drafts (optional):

```dart
// Delete drafts older than 30 days
Future<void> cleanupOldDrafts() async {
  final db = await database;
  final cutoffDate = DateTime.now().subtract(Duration(days: 30));

  await db.delete(
    AppConstants.brainDumpDraftsTable,  // FIXED: Use correct constant name
    where: 'last_modified < ?',
    whereArgs: [cutoffDate.millisecondsSinceEpoch],
  );
}
```

### Testing Checklist
- [ ] Drafts list loads correctly
- [ ] Tap draft loads into editor
- [ ] Swipe to delete works
- [ ] Badge shows correct count
- [ ] Empty state displays
- [ ] Date formatting correct
- [ ] Loading draft clears after successful processing

### Estimated Time
- **Implementation:** 3-4 hours
- **Testing:** 1 hour

---

## 4. Brain Dump Review (Bottom Sheet) 📄

### Problem
- User can't see their original brain dump text on Task Suggestion Preview screen
- No way to verify Claude captured everything
- Uncertainty: "Did I mention that thing about...?"

### Solution
Add a **toggleable bottom sheet** showing the original brain dump text.

### Important Behavior: Text Clearing Logic

**User Feedback:** Clarify when brain dump text is cleared vs. persisted.

**Correct Behavior:**
1. **Bottom sheet visibility:** Only controls display, does NOT affect the underlying text
   - Swipe down = hide sheet
   - Tap "View Original" = show sheet
   - Text remains in provider during entire review process

2. **Text clearing:** Only happens on successful task addition
   - User reviews suggestions → taps "Add X Tasks" → tasks added → **text CLEARED**
   - NOT archived as draft (draft only saved on error/failure)

3. **Text persistence:** Remains until successful completion cycle
   - Text stays in memory during: process → review → edit suggestions
   - Allows user to return to Brain Dump screen if they cancel
   - Only cleared after "successful input, edit, confirm, exit cycle"

**Example Flow:**
```
1. User types brain dump text
2. Taps "Claude, Help Me"
3. Processing succeeds → navigate to suggestions screen
4. User taps "View Original" → bottom sheet slides up
5. User swipes down → sheet hides (text still in provider)
6. User taps "View Original" again → sheet shows again
7. User taps "Add 5 Tasks" → tasks added → **text cleared**
8. Navigate back to home
```

### Design

**UI Location:** Task Suggestion Preview screen - App bar action

```
[Review Tasks]  [👁️ View Original]  [✕]
```

**Bottom Sheet Behavior:**
- Tap "View Original" icon in app bar
- Bottom sheet slides up from bottom (50% screen height)
- Shows original brain dump text (read-only)
- Swipe down or tap outside to dismiss
- Stays open while scrolling suggestions above

**Visual:**
```
┌─────────────────────────────────┐
│ Review Tasks          [👁️]  [✕] │
├─────────────────────────────────┤
│ Suggested tasks list...         │
│                                 │
│  ☑ Call dentist for appt        │
│  ☑ Work on dev project          │
│                                 │
└─────────────────────────────────┘
        ↑ Bottom sheet slides up
┌─────────────────────────────────┐
│ ─────                           │ ← Drag handle
│ Original Text                   │
│                                 │
│ I have to take Raffles to the   │
│ vet at 10:00am and I need to    │
│ fill out his pre exam...        │
│                                 │
│ [Swipe down to close]           │
└─────────────────────────────────┘
```

### Technical Implementation

#### 4.1 Store Original Text

```dart
// lib/providers/brain_dump_provider.dart
class BrainDumpProvider extends ChangeNotifier {
  String? _originalDumpText;  // NEW: Store for review
  String? get originalDumpText => _originalDumpText;

  Future<void> processDump() async {
    final text = _textController.text.trim();
    _originalDumpText = text;  // Save before processing

    // ... rest of processing logic ...
  }

  void clearOriginalText() {
    _originalDumpText = null;
    notifyListeners();
  }

  // Called after tasks are successfully added
  void clearAfterSuccess() {
    _textController.clear();  // Clear the Brain Dump text field
    _originalDumpText = null;  // Clear stored original text
    _suggestions.clear();      // Clear suggestions
    notifyListeners();
  }
}
```

#### 4.2 Task Suggestion Preview - Bottom Sheet

```dart
// lib/screens/task_suggestion_preview_screen.dart
class TaskSuggestionPreviewScreen extends StatefulWidget {
  @override
  State<TaskSuggestionPreviewScreen> createState() =>
    _TaskSuggestionPreviewScreenState();
}

class _TaskSuggestionPreviewScreenState
    extends State<TaskSuggestionPreviewScreen> {
  bool _showOriginalText = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Tasks'),
        actions: [
          Consumer<BrainDumpProvider>(
            builder: (context, provider, child) {
              if (provider.originalDumpText == null) return SizedBox.shrink();

              return IconButton(
                icon: Icon(_showOriginalText
                  ? Icons.visibility_off
                  : Icons.visibility),
                tooltip: _showOriginalText
                  ? 'Hide original text'
                  : 'View original text',
                onPressed: () {
                  setState(() => _showOriginalText = !_showOriginalText);
                  if (_showOriginalText) {
                    _showOriginalBottomSheet();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content (task suggestions list)
          Padding(
            padding: EdgeInsets.only(
              bottom: _showOriginalText ? 250 : 0,
            ),
            child: Consumer<BrainDumpProvider>(
              builder: (context, provider, child) {
                return ListView(/* ... suggestions ... */);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showOriginalBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,  // Start at 50% height
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<BrainDumpProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original Text',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() => _showOriginalText = false);
                            },
                          ),
                        ],
                      ),

                      Divider(),

                      // Original text (scrollable)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Text(
                            provider.originalDumpText ?? '',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),

                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Swipe down to close',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() => _showOriginalText = false);
    });
  }
}
```

### Dependencies
None - uses Flutter's built-in `showModalBottomSheet` and `DraggableScrollableSheet`.

### Implementation Notes

**IMPORTANT: Clear text after successful task addition**

In `TaskSuggestionPreviewScreen`, after tasks are added:

```dart
// When "Add X Tasks" button is pressed
Future<void> _addTasks() async {
  final provider = context.read<BrainDumpProvider>();

  // Add approved tasks to database
  await taskProvider.createMultipleTasks(
    provider.suggestions.where((s) => s.approved).toList()
  );

  // Clear brain dump text and original text (USER REQUIREMENT!)
  provider.clearAfterSuccess();

  // Navigate back to home
  Navigator.popUntil(context, (route) => route.isFirst);
}
```

This ensures:
- Brain dump text field is cleared (not archived as draft)
- Original text is cleared from memory
- Suggestions are cleared
- User returns to clean state

### Testing Checklist
- [ ] Original text stored correctly after processing
- [ ] Bottom sheet slides up smoothly
- [ ] Can drag to resize (30% to 90% height)
- [ ] Swipe down dismisses sheet (text remains in provider)
- [ ] Tap outside dismisses sheet (text remains in provider)
- [ ] Icon toggles visibility state
- [ ] Text scrolls if longer than sheet
- [ ] Works on different screen sizes
- [ ] **Brain dump text CLEARED after tasks added (not drafted)**
- [ ] Text persists if user navigates back during review
- [ ] Bottom sheet visibility does NOT affect text state

### Estimated Time
- **Implementation:** 2-3 hours
- **Testing:** 30 minutes

---

## 5. Cost Tracking Dashboard 💰

### Problem
- Users don't know how much they're spending on API calls
- No visibility into usage patterns
- Can't estimate monthly costs

### Solution
Track API usage and display in Settings screen.

### Design

**UI Location:** Settings screen - New section below API key

```
┌─────────────────────────────────┐
│ API Usage & Costs               │
├─────────────────────────────────┤
│ Total Spent (est.): $0.45       │
│ This Month: $0.12               │
│ Brain Dumps: 15                 │
│ Avg Cost: $0.008/dump           │
│                                 │
│ [View Detailed Usage]           │
└─────────────────────────────────┘
```

**Detailed Usage Screen:**
- List of API calls with timestamps
- Input/output tokens
- Cost per call
- Daily/weekly/monthly summaries

### Technical Implementation

#### 5.1 Database Schema & Migration

**Database Version Bump:** 2 → 3 (Phase 2 Stretch Goals)

```dart
// lib/utils/constants.dart
static const int databaseVersion = 3; // Phase 2 Stretch: api_usage_log table
```

```dart
// lib/services/database_service.dart - _upgradeDB
Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  // Migrate from version 1 to 2: Add brain_dump_drafts table
  if (oldVersion < 2) {
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

  // Migrate from version 2 to 3: Add api_usage_log table (Phase 2 Stretch)
  if (oldVersion < 3) {
    await db.execute('''
      CREATE TABLE ${AppConstants.apiUsageLogTable} (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        operation_type TEXT NOT NULL,
        input_tokens INTEGER NOT NULL,
        output_tokens INTEGER NOT NULL,
        estimated_cost_usd REAL NOT NULL,
        model TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_api_usage_timestamp
      ON ${AppConstants.apiUsageLogTable}(timestamp DESC)
    ''');
  }

  // Future migrations will be added here
  // if (oldVersion < 4) { ... }
}
```

```dart
// lib/utils/constants.dart - Add constant
static const String apiUsageLogTable = 'api_usage_log';
```

**Database Helper Method:**

```dart
// lib/services/database_service.dart
// Add this method to DatabaseService class
Future<void> insertApiUsageLog(Map<String, dynamic> logEntry) async {
  final db = await database;
  await db.insert(
    AppConstants.apiUsageLogTable,
    logEntry,
  );
}
```

#### 5.2 Service Layer

```dart
// lib/services/api_usage_service.dart
class ApiUsageService {
  // Pricing for claude-sonnet-4-5 (as of 2025)
  static const double INPUT_COST_PER_MILLION = 3.0;   // $3/MTok
  static const double OUTPUT_COST_PER_MILLION = 15.0;  // $15/MTok

  Future<void> logUsage({
    required String operationType,
    required int inputTokens,
    required int outputTokens,
    required String model,
  }) async {
    final cost = _calculateCost(inputTokens, outputTokens);

    await DatabaseService.instance.insertApiUsageLog({
      'id': Uuid().v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'operation_type': operationType,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'estimated_cost_usd': cost,
      'model': model,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  double _calculateCost(int inputTokens, int outputTokens) {
    final inputCost = (inputTokens / 1000000) * INPUT_COST_PER_MILLION;
    final outputCost = (outputTokens / 1000000) * OUTPUT_COST_PER_MILLION;
    return inputCost + outputCost;
  }

  Future<UsageStats> getStats() async {
    final db = await DatabaseService.instance.database;

    // Total stats
    final total = await db.rawQuery('''
      SELECT
        COUNT(*) as call_count,
        SUM(estimated_cost_usd) as total_cost,
        SUM(input_tokens) as total_input_tokens,
        SUM(output_tokens) as total_output_tokens
      FROM api_usage_log
    ''');

    // This month
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final thisMonth = await db.rawQuery('''
      SELECT
        COUNT(*) as call_count,
        SUM(estimated_cost_usd) as total_cost
      FROM api_usage_log
      WHERE timestamp >= ?
    ''', [monthStart.millisecondsSinceEpoch]);

    return UsageStats(
      totalCalls: total[0]['call_count'] as int,
      totalCost: total[0]['total_cost'] as double? ?? 0.0,
      monthCalls: thisMonth[0]['call_count'] as int,
      monthCost: thisMonth[0]['total_cost'] as double? ?? 0.0,
    );
  }
}

class UsageStats {
  final int totalCalls;
  final double totalCost;
  final int monthCalls;
  final double monthCost;

  UsageStats({
    required this.totalCalls,
    required this.totalCost,
    required this.monthCalls,
    required this.monthCost,
  });

  double get averageCostPerCall =>
    totalCalls > 0 ? totalCost / totalCalls : 0.0;
}
```

#### 5.3 Integrate into ClaudeService

```dart
// lib/services/claude_service.dart
Future<List<TaskSuggestion>> extractTasks(String dump, String apiKey) async {
  // ... existing code ...

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);

    // Log usage
    await ApiUsageService().logUsage(
      operationType: 'brain_dump',
      inputTokens: decoded['usage']['input_tokens'],
      outputTokens: decoded['usage']['output_tokens'],
      model: _model,
    );

    return _parseResponse(response.body);
  }

  // ... rest of code ...
}
```

#### 5.4 Settings Screen UI

```dart
// lib/screens/settings_screen.dart
Consumer<UsageStats>(
  builder: (context, stats, child) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Usage & Costs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),

            _buildStatRow('Total Spent (est.)',
              '\$${stats.totalCost.toStringAsFixed(2)}'),
            _buildStatRow('This Month',
              '\$${stats.monthCost.toStringAsFixed(2)}'),
            _buildStatRow('Brain Dumps',
              '${stats.totalCalls}'),
            _buildStatRow('Avg Cost',
              '\$${stats.averageCostPerCall.toStringAsFixed(3)}/dump'),

            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailedUsageScreen(),
                        ),
                      );
                    },
                    child: Text('View Detailed Usage'),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.delete_outline),
                  label: Text('Reset'),
                  onPressed: () => _confirmResetUsageData(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
)
```

### Reset Usage Data Implementation

```dart
Future<void> _confirmResetUsageData(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reset Usage Data?'),
      content: Text(
        'This will permanently delete all API usage history and cost tracking data. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('Reset'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await DatabaseService.instance.database.then((db) =>
      db.delete(AppConstants.apiUsageLogTable)
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usage data reset')),
    );

    // Refresh stats
    setState(() {});
  }
}
```

### Privacy Note
- All data stored locally
- No telemetry sent to external services
- User owns their usage data
- User can reset/delete data at any time

### Testing Checklist
- [ ] ✅ Database migration v2→v3 runs successfully
- [ ] ✅ Constant added to AppConstants.apiUsageLogTable
- [ ] Usage logged after each API call
- [ ] Stats calculate correctly
- [ ] Monthly stats reset properly
- [ ] Detailed usage screen shows history
- [ ] Costs match actual API pricing
- [ ] Test connection calls tracked separately
- [ ] Reset usage data confirmation works
- [ ] Reset actually deletes all usage records

### Estimated Time
- **Implementation:** 4-5 hours
- **Testing:** 1 hour

---

## 5. Improved Loading States & Animations ✨

### Problem
- Generic loading spinner
- No feedback on what's happening
- Sudden transitions feel jarring

### Solution
Progressive loading states with helpful text + success animations.

### Design

#### Brain Dump Processing States

**Loading:**
```
⏳ Connecting to Claude...      (0-1s)
🧠 Analyzing your thoughts...   (1-3s)
✨ Extracting tasks...          (3-5s)
```

**Success:**
```
✅ Found 5 tasks!
[Animated checkmark + task count badge]
[Smooth transition to suggestions screen]
```

**Error:**
```
❌ Something went wrong
[Helpful error message]
[Retry button]
```

### Technical Implementation

#### 5.1 Loading Widget

```dart
// lib/widgets/brain_dump_loading.dart
class BrainDumpLoading extends StatefulWidget {
  @override
  State<BrainDumpLoading> createState() => _BrainDumpLoadingState();
}

class _BrainDumpLoadingState extends State<BrainDumpLoading> {
  int _currentStep = 0;

  final List<String> _steps = [
    '⏳ Connecting to Claude...',
    '🧠 Analyzing your thoughts...',
    '✨ Extracting tasks...',
  ];

  @override
  void initState() {
    super.initState();
    _startStepTimer();
  }

  void _startStepTimer() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
        _startStepTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: Text(
            _steps[_currentStep],
            key: ValueKey(_currentStep),
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
```

#### 5.2 Success Animation

```dart
// lib/widgets/success_animation.dart
class SuccessAnimation extends StatefulWidget {
  final int taskCount;
  final VoidCallback onComplete;

  const SuccessAnimation({
    required this.taskCount,
    required this.onComplete,
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Navigate after animation
    Future.delayed(Duration(milliseconds: 1200), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Found ${widget.taskCount} tasks!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

#### 5.3 Integration into Brain Dump

```dart
// lib/screens/brain_dump_screen.dart
bool _isProcessing = false;
bool _showSuccess = false;
int _taskCount = 0;

Future<void> _processWithClaude() async {
  setState(() => _isProcessing = true);

  try {
    // processDump returns void - stores suggestions internally in provider
    await _brainDumpProvider.processDump();

    // Show success animation (get count from provider's suggestions)
    setState(() {
      _isProcessing = false;
      _showSuccess = true;
      _taskCount = _brainDumpProvider.suggestions.length;
    });

    // Auto-navigate after animation
    Future.delayed(Duration(milliseconds: 1200), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TaskSuggestionPreviewScreen(),
        ),
      );
    });

  } catch (e) {
    setState(() {
      _isProcessing = false;
      _showSuccess = false;
    });
    // Show error...
  }
}

// In build():
if (_showSuccess) {
  return SuccessAnimation(
    taskCount: _taskCount,
    onComplete: () { /* navigation handled above */ },
  );
}

if (_isProcessing) {
  return Center(child: BrainDumpLoading());
}
```

### Optional: Lottie Animations

For more polish, use Lottie JSON animations:

```yaml
# pubspec.yaml
dependencies:
  lottie: ^3.0.0
```

Download free animations from: https://lottiefiles.com/
- Success checkmark
- Loading brain
- Error animation

### Testing Checklist
- [ ] Loading states progress smoothly
- [ ] Success animation plays correctly
- [ ] Timing feels natural (not too fast/slow)
- [ ] Animations don't block interaction
- [ ] Works on different screen sizes
- [ ] Animations skip if already complete

### Estimated Time
- **Implementation:** 3-4 hours
- **Polish & timing:** 2 hours

---

## Implementation Order (Recommended)

### Sprint 1: Quick Wins (High value, low effort)
1. **Hide Completed Toggle** (2.5 hours)
   - Immediate user value
   - Simple implementation
   - No dependencies

2. **Draft Management UI** (4 hours)
   - Database already exists
   - High utility for failed dumps
   - Prevents data loss anxiety

### Sprint 2: Power User Features
3. **Cost Tracking Dashboard** (5 hours)
   - Transparency builds trust
   - Helps users budget
   - Professional feature

4. **Natural Language Task Completion** (6-8 hours)
   - High user request
   - Reduces friction
   - Uses free local matching (no API cost)

### Sprint 3: Polish (Optional)
5. **Improved Loading States** (5-6 hours)
   - Nice-to-have
   - Improves perceived performance
   - Can defer if time-constrained

---

## Dependencies to Add

```yaml
# pubspec.yaml
dependencies:
  # Existing dependencies...

  # Phase 2 Stretch Goals
  shared_preferences: ^2.2.0      # UI preferences (hide completed)
  string_similarity: ^2.0.0        # Fuzzy matching (stable, 2+ years old but functional)
  # lottie: ^3.0.0                 # Optional: animations
```

**Note on `string_similarity`:** While this package hasn't been updated in 2+ years, it implements mathematical algorithms (Levenshtein distance) that don't require frequent updates. It remains functional and stable. Consider migrating to the more actively maintained `fuzzy` package in Phase 3+ if compatibility issues arise.

---

## Success Metrics

Track these to measure stretch goal success:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Hide Completed usage | >50% users | Count toggles in analytics |
| Quick Complete usage | >30% completions | Compare manual vs quick complete |
| Draft recovery rate | >80% drafts loaded | Track draft load vs delete |
| Cost tracking views | >25% users | Settings page analytics |
| User satisfaction | >4.5/5 | In-app feedback prompt |

---

## Testing Strategy

### Unit Tests
- TaskMatchingService fuzzy logic
- UsageStats calculations
- PreferencesService persistence

### Widget Tests
- Hide completed toggle behavior
- Draft list interactions
- Loading state transitions

### Integration Tests
- End-to-end Quick Complete flow
- Draft save → load → process flow
- Cost tracking across multiple dumps

### Manual Testing Checklist
- [ ] All features work on Galaxy S21 Ultra
- [ ] Smooth performance (no lag)
- [ ] Animations feel natural
- [ ] Error states handle gracefully
- [ ] Data persists across app restarts

---

## Documentation Updates Needed

1. **User Guide** (`docs/user-guide.md`)
   - How to use Quick Complete
   - Understanding cost tracking
   - Managing drafts

2. **README.md**
   - Update Phase 2 Stretch Goals section
   - Add feature screenshots

3. **CHANGELOG.md**
   - Document all new features
   - Breaking changes (if any)

---

## Questions for User

Before implementation:

1. **Hide Completed Toggle:**
   - Default state: Show all or hide completed?
   - Icon preference: Eye or filter icon?

2. **Quick Complete:**
   - Should we add voice input immediately or save for Phase 3?
   - Confidence threshold: 75% auto-complete or always ask?

3. **Draft Management:**
   - Auto-delete drafts after 30 days, or never?
   - Max drafts to keep (e.g., 50)?

4. **Cost Tracking:**
   - Show detailed token counts or just $ amounts?
   - Export usage data to CSV?

5. **Animations:**
   - Use simple built-in animations or add Lottie (8MB+ app size)?

---

## Timeline Estimate

**Total estimated time:** 25-30 hours

**Breakdown:**
- Sprint 1 (Quick Wins): 6-7 hours
- Sprint 2 (Power Features): 11-13 hours
- Sprint 3 (Polish): 5-6 hours
- Testing & bug fixes: 3-4 hours

**Realistic schedule:**
- **Week 1:** Hide completed + Draft management
- **Week 2:** Cost tracking + Natural language completion
- **Week 3:** Loading states + testing + polish

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Fuzzy matching accuracy too low | Medium | High | Iterate on thresholds, add user feedback |
| Animation performance issues | Low | Medium | Profile on device, simplify if needed |
| Cost tracking privacy concerns | Low | Low | Clear documentation, local-only storage |
| Feature creep (too many toggles) | Medium | Medium | Strict scope adherence, defer to Phase 3 |

---

## Rollback Plan

If any feature causes issues:

1. **Feature flag in settings:**
   ```dart
   // settings_service.dart
   bool get enableQuickComplete =>
     _prefs.getBool('feature_quick_complete') ?? true;
   ```

2. **Easy to disable:**
   - Remove button from UI
   - Keep backend code (can re-enable later)

3. **User data preserved:**
   - Don't delete database tables
   - Graceful degradation

---

**Status:** Ready for implementation
**Next Step:** Review with user → Prioritize features → Start Sprint 1

**Questions?** Check this doc or ask in GitHub Discussions.

---

*Built with ❤️ for ADHD brains everywhere.*
