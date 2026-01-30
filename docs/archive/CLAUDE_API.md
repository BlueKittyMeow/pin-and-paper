# Pin and Paper — Core API Contract

**Generated:** 2026-01-30
**App Version:** 3.9.0 · Database Version: 11
**Purpose:** Interface contract for building dev harnesses and visual modules. Implementation details (SQLite migrations, provider wiring, business logic internals) are intentionally omitted.

---

## 1. Data Models

### Task

```dart
class Task {
  String id;                       // UUID
  String title;
  bool completed;                  // Default: false
  DateTime createdAt;
  DateTime? completedAt;
  String? parentId;                // NULL = top-level task
  int position;                    // Order within parent (0-based)
  int depth;                       // Hierarchy level (0-3)
  bool isTemplate;                 // Default: false
  DateTime? dueDate;               // NULL = no due date
  bool isAllDay;                   // Default: true
  DateTime? startDate;             // For multi-day tasks
  String notificationType;         // 'use_global' | 'custom' | 'none'
  DateTime? notificationTime;      // Custom notification time
  DateTime? deletedAt;             // Soft delete (NULL = active, 30-day retention)
  String? notes;                   // Task description/body text
  int? positionBeforeCompletion;   // For restoring position on uncomplete

  Map<String, dynamic> toMap();
  factory Task.fromMap(Map<String, dynamic> map);
  Task copyWith({...});
}
```

### Tag

```dart
class Tag {
  String id;                       // UUID
  String name;                     // Unique, case-insensitive, max 250 chars
  String? color;                   // Hex color code e.g. "#FF5722" (NULL = default blue)
  DateTime createdAt;
  DateTime? deletedAt;             // Soft delete

  static String? validateName(String name);
  static String? validateColor(String? color);
}
```

### UserSettings

```dart
class UserSettings {
  int id;                          // Always 1 (single-row)

  // Time keyword hours (what "morning", "tonight", etc. mean to this user)
  int earlyMorningHour;            // Default: 5
  int morningHour;                 // Default: 9
  int noonHour;                    // Default: 12
  int afternoonHour;               // Default: 15
  int tonightHour;                 // Default: 19  (also used for "evening")
  int lateNightHour;               // Default: 22

  // Night owl / "today" boundary
  int todayCutoffHour;             // Default: 4   (hour when "today" rolls over)
  int todayCutoffMinute;           // Default: 59

  // Calendar
  int weekStartDay;                // 0=Sunday, 1=Monday, ... 6=Saturday

  // Timezone
  String? timezoneId;              // IANA format e.g. 'America/Detroit'

  // Display
  bool use24HourTime;              // Default: false

  // Task behavior
  String autoCompleteChildren;     // 'prompt' | 'always' | 'never'

  // Notifications
  int defaultNotificationHour;     // Default: 9
  int defaultNotificationMinute;   // Default: 0
  bool notificationsEnabled;       // Default: true
  bool notifyWhenOverdue;          // Default: false
  bool quietHoursEnabled;          // Default: false
  int? quietHoursStart;            // Minutes from midnight
  int? quietHoursEnd;              // Minutes from midnight
  String quietHoursDays;           // Comma-separated: '0,1,2,3,4,5,6'
  String defaultReminderTypes;     // Comma-separated: 'at_time'

  // Feature flags
  bool enableQuickAddDateParsing;  // Default: true

  // Voice
  bool voiceSmartPunctuation;      // Default: true

  // Timestamps
  DateTime createdAt;
  DateTime updatedAt;

  factory UserSettings.defaults();
  UserSettings copyWith({...});    // Uses Value<T> wrapper for nullable fields
}
```

### TaskReminder

```dart
class TaskReminder {
  String id;                       // UUID (auto-generated)
  String taskId;
  String reminderType;             // See ReminderType constants below
  int? offsetMinutes;              // Minutes before due date
  bool enabled;                    // Default: true

  int get notificationId;          // Deterministic, 31-bit Android-safe
}

class ReminderType {
  static const String atTime = 'at_time';
  static const String before1h = 'before_1h';
  static const String before1d = 'before_1d';
  static const String beforeCustom = 'before_custom';
  static const String overdue = 'overdue';

  static String label(String type);       // Human-readable label
  static int? defaultOffset(String type); // Default offset in minutes
}
```

### FilterState

```dart
class FilterState {
  List<String> selectedTagIds;     // Immutable list
  FilterLogic logic;               // Default: or
  TagPresenceFilter presenceFilter; // Default: any
  DateFilter dateFilter;           // Default: any

  bool get isActive;
  static const FilterState empty;  // Singleton for no-filter state

  FilterState copyWith({...});
  Map<String, dynamic> toJson();
  factory FilterState.fromJson(Map<String, dynamic>);
}
```

### SearchResult

```dart
class SearchResult {
  Task task;
  double score;                    // 0.0–1.0 relevance
  MatchPositions matches;
}

class MatchPositions {
  List<MatchRange> titleMatches;
  List<MatchRange> notesMatches;
  List<MatchRange> tagMatches;
}

class MatchRange {
  int start;                       // Starting index
  int end;                         // Ending index (exclusive)
}
```

### TaskMatch

```dart
class TaskMatch {
  Task task;
  double similarity;               // 0.0–1.0 string similarity score
}
```

### ParsedDate

```dart
class ParsedDate {
  String matchedText;              // The text fragment that was parsed
  TextRange matchedRange;          // Position in original string
  DateTime date;
  bool isAllDay;

  String get cleanTitle;           // For stripping matched text from input
}
```

### Badge

```dart
class Badge {
  String id;                       // e.g. 'night_owl'
  String name;                     // e.g. 'Night Owl'
  String description;
  String imagePath;                // Asset path
  BadgeCategory category;
  bool isCombo;                    // Default: false
}
```

### QuizQuestion / QuizAnswer

```dart
class QuizQuestion {
  int id;
  String title;
  String question;
  String? imagePath;
  List<QuizAnswer> answers;
}

class QuizAnswer {
  String id;                       // e.g. 'q1_a'
  String text;
  String? description;
  bool showTimePicker;             // Default: false
  bool showDayPicker;              // Default: false
}
```

### BrainDumpDraft

```dart
class BrainDumpDraft {
  String id;
  String content;
  DateTime createdAt;
  DateTime lastModified;
  String? failedReason;
}
```

### TaskSuggestion

```dart
class TaskSuggestion {
  String id;                       // Temporary UUID
  String title;
  String? notes;
  bool approved;                   // Default: true
  bool edited;                     // Default: false

  Task toTask();
  factory TaskSuggestion.fromJson(Map<String, dynamic> json, String id);
  TaskSuggestion copyWith({...});
}
```

### UsageStats

```dart
class UsageStats {
  int totalCalls;
  double totalCost;
  int monthCalls;
  double monthCost;
  double get averageCostPerCall;
}
```

---

## 2. Enums

```dart
enum TaskSortMode {
  manual,            // Drag-and-drop position order
  recentlyCreated,   // Newest first
  dueSoonest,        // Due date soonest first
}

enum FilterLogic { or, and }

enum TagPresenceFilter { any, onlyTagged, onlyUntagged }

enum DateFilter { any, overdue, noDueDate }

enum SearchScope {
  all,               // Active + completed
  current,           // Incomplete only
  recentlyCompleted, // Completed in last 30 days
  completed,         // All completed
}

enum BadgeCategory {
  circadianRhythm,
  weekStructure,
  dailyRhythm,
  displayPreference,
  taskManagement,
  combo,
}
```

---

## 3. Service Signatures

### TaskService

```dart
// CRUD
Future<Task>       createTask(String title, {DateTime? dueDate, bool isAllDay = true});
Future<List<Task>> createMultipleTasks(List<TaskSuggestion> suggestions);
Future<List<Task>> getAllTasks();
Future<Task?>      getTaskById(String taskId);
Future<Task>       updateTask(String taskId, {required String title, DateTime? dueDate, bool isAllDay, String? notes, String? notificationType});
Future<Task>       updateTaskTitle(String taskId, String newTitle);

// Completion
Future<Task>       toggleTaskCompletion(Task task);
Future<Task>       uncompleteTask(String taskId);

// Hierarchy
Future<List<Task>> getTaskHierarchy();
Future<List<Task>> getTaskWithChildren(String parentId);
Future<List<Task>> getParentChain(String taskId);
Future<String?>    updateTaskParent(String taskId, String? newParentId, int newPosition);
Future<int>        countDescendants(String taskId);

// Filtering & counts
Future<List<Task>> getFilteredTasks(FilterState filter, {required bool completed});
Future<int>        countFilteredTasks(FilterState filter, {required bool completed});
Future<int>        getIncompleteTaskCount();
Future<int>        getCompletedTaskCount();

// Soft delete / trash
Future<int>        softDeleteTask(String taskId);
Future<int>        restoreTask(String taskId);
Future<int>        permanentlyDeleteTask(String taskId);
Future<int>        deleteTaskWithChildren(String taskId);
Future<List<Task>> getRecentlyDeletedTasks();
Future<int>        countRecentlyDeletedTasks();
Future<int>        emptyTrash();
Future<int>        cleanupExpiredDeletedTasks();
Future<int>        cleanupOldDeletedTasks({int daysThreshold = 30});
Future<int>        countDeletedAncestors(String taskId);
Future<int>        countDeletedDescendants(String taskId);
```

### TagService

```dart
Future<Tag>                    createTag(String name, {String? color});
Future<List<Tag>>              getAllTags();
Future<Tag?>                   getTagById(String id);
Future<Tag?>                   getTagByName(String name);
Future<List<Tag>>              getTagsByIds(List<String> tagIds);
Future<void>                   addTagToTask(String taskId, String tagId);
Future<bool>                   removeTagFromTask(String taskId, String tagId);
Future<List<Tag>>              getTagsForTask(String taskId);
Future<Map<String, int>>       getTaskCountsByTag({required bool completed});
Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds);
```

### SearchService

```dart
SearchService(Database db);  // Constructor takes database instance

Future<List<SearchResult>> search({
  required String query,
  required SearchScope scope,
  FilterState? tagFilters,
});
```

### DateParsingService (Singleton)

```dart
Future<void> initialize();
ParsedDate?  parse(String text, {DateTime? now});
bool         containsPotentialDate(String text);
DateTime     getEffectiveToday(DateTime now, int todayWindowHours, int todayWindowMinutes);
DateTime     getCurrentEffectiveToday();
Future<void> loadSettings();
void         dispose();
```

### UserSettingsService

```dart
Future<UserSettings> getUserSettings();
Future<void>         updateUserSettings(UserSettings settings);
Future<void>         updateSettings(UserSettings Function(UserSettings) updateFn);
Future<void>         resetToDefaults();
```

### QuizService

```dart
Future<bool>             hasCompletedOnboardingQuiz();
Future<DateTime?>        getQuizCompletedAt();
Future<void>             saveQuizCompletion({required Map<int, String> answers, required List<String> badgeIds});
Future<Map<int, String>?> getSavedAnswers();
Future<List<String>?>    getEarnedBadgeIds();
Future<int?>             getQuizVersion();
Future<void>             resetQuiz();
```

### QuizInferenceService

```dart
UserSettings       inferSettings(Map<int, String> answers, UserSettings currentSettings);
List<Badge>        calculateBadges(Map<int, String> answers);
Map<int, String>   prefillFromSettings(UserSettings settings);
```

### ReminderService (Singleton)

```dart
Future<List<TaskReminder>> getRemindersForTask(String taskId);
Future<void>               setReminders(String taskId, List<TaskReminder> reminders);
Future<void>               deleteReminders(String taskId);
Future<void>               scheduleReminders(Task task);
Future<void>               cancelReminders(String taskId);
Future<void>               rescheduleAll();
Future<List<Task>>         checkMissed();
Future<void>               snooze(String taskId, Duration snoozeDuration);
tz.TZDateTime?             computeNotificationTime(Task task, TaskReminder reminder, UserSettings settings);
```

### NotificationService (Singleton)

```dart
Future<void>  initialize();
Future<bool>  requestPermission();
Future<bool>  isPermissionGranted();
Future<bool>  canScheduleExactAlarms();
Future<void>  schedule({required int id, required String title, required String body, required tz.TZDateTime scheduledTime, String? payload, List<AndroidNotificationAction>? actions});
Future<void>  showImmediate({required int id, required String title, required String body, String? payload});
Future<void>  cancel(int id);
Future<void>  cancelAll();
Future<int>   getPendingCount();
bool get      isInitialized;

// Callbacks (settable)
void Function(String? taskId)?        onNotificationTapped;
void Function(String taskId)?         onSnoozeRequested;
Future<void> Function(String taskId)? onCompleteRequested;
Future<void> Function(String taskId)? onCancelRequested;
```

### ClaudeService (Brain Dump AI)

```dart
Future<double>              estimateCost(String text);
Future<List<TaskSuggestion>> extractTasks(String dump, String apiKey);
```

### TaskMatchingService

```dart
String          extractAction(String input);
List<TaskMatch> findMatches(String input, List<Task> tasks);
TaskMatch?      getConfidentMatch(String input, List<Task> tasks);
// Thresholds: CONFIDENT = 0.75, POSSIBLE = 0.30
```

### SettingsService (API Key Management)

```dart
bool             isValidApiKey(String key);
Future<(bool, String?)> testApiKey(String apiKey);
Future<void>     saveApiKey(String apiKey);
Future<String?>  getApiKey();
Future<bool>     hasApiKey();
Future<void>     deleteApiKey();
```

### ApiUsageService

```dart
Future<void>       logUsage({required String operationType, required int inputTokens, required int outputTokens, required String model});
Future<UsageStats> getStats();
```

### PreferencesService (SharedPreferences)

```dart
Future<bool> getHideOldCompleted();
Future<void> setHideOldCompleted(bool value);
Future<int>  getHideThresholdHours();
Future<void> setHideThresholdHours(int hours);
Future<String> getSortMode();
Future<void>   setSortMode(String mode);
Future<bool>   getSortReversed();
Future<void>   setSortReversed(bool reversed);
```

---

## 4. Providers (State Management)

All providers extend `ChangeNotifier`. UI listens via `Consumer<T>` / `context.watch<T>()`.

### TaskProvider

The main provider. Orchestrates task loading, CRUD, hierarchy, filtering, sorting, and search navigation.

```dart
// State
List<Task> get tasks;
List<Task> get incompleteTasks;
List<Task> get completedTasks;
List<Task> get activeTasks;
List<Task> get recentlyCompletedTasks;
List<Task> get visibleTasks;
List<Task> get visibleCompletedTasks;
int get incompleteCount;
int get completedCount;
bool get isLoading;
String? get errorMessage;
bool get hideOldCompleted;
int get hideThresholdHours;

// Delegates to child providers
TreeController<Task> get treeController;
int get treeVersion;
bool get isReorderMode;
bool get areAllExpanded;
TaskSortMode get sortMode;
bool get sortReversed;
FilterState get filterState;
bool get hasActiveFilters;

// Task CRUD
Future<void> createTask(String title, {DateTime? dueDate, bool isAllDay = true});
Future<void> createMultipleTasks(List<TaskSuggestion> suggestions);
Future<void> toggleTaskCompletion(Task task);
Future<void> updateTaskTitle(String taskId, String newTitle);
Future<void> updateTask({required String taskId, required String title, DateTime? dueDate, bool isAllDay, String? notes, required List<String> tagIds, String? notificationType, List<String>? reminderTypes, bool? notifyIfOverdue});

// Hierarchy
Future<void> changeTaskParent({required String taskId, String? newParentId, required int newPosition});
Future<void> onNodeAccepted(TreeDragAndDropDetails<Task> details);
void toggleCollapse(Task task);
void expandAll();
void collapseAll();
void setReorderMode(bool enabled);

// Trash
Future<bool> deleteTaskWithConfirmation(String taskId, Future<bool> Function(int) showConfirmation);
Future<bool> restoreTask(String taskId);
Future<bool> permanentlyDeleteTask(String taskId, Future<bool> Function() showConfirmation);
Future<bool> emptyTrash(Future<bool> Function(int) showConfirmation);

// Tags
List<Tag> getTagsForTask(String taskId);
Future<void> refreshTags();

// Lookups
Task? getTaskById(String taskId);
String? getBreadcrumb(Task task);
IncompleteDescendantInfo? getIncompleteDescendantInfo(String taskId);
bool isCompletedParentWithIncomplete(String taskId);
bool hasCompletedChildren(String taskId);

// Highlighting (search navigation)
bool isTaskHighlighted(String taskId);

// Navigation (from search)
Future<void> navigateToTask(String taskId);
GlobalKey getKeyForTask(String taskId);
```

### TagProvider

```dart
List<Tag> get tags;
bool get isLoading;
String? get errorMessage;

Future<void>           loadTags();
Future<Tag?>           createTag(String name, {String? color});
Future<Tag?>           findTagByName(String name);
Future<bool>           addTagToTask(String taskId, String tagId);
Future<bool>           removeTagFromTask(String taskId, String tagId);
Future<List<Tag>>      getTagsForTask(String taskId);
Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds);
String                 getNextPresetColor();
```

### TaskFilterProvider

```dart
FilterState get filterState;
bool get hasActiveFilters;
int get filterOperationId;

int  setFilter(FilterState filter);        // Returns operation ID
void rollbackFilter(FilterState prev, int opId);
void addTagFilter(String tagId);
void removeTagFilter(String tagId);
void clearFilters();
```

### TaskSortProvider

```dart
TaskSortMode get sortMode;
bool get sortReversed;

Future<void> loadPreferences();
void setSortMode(TaskSortMode mode);
void toggleSortReversed();
```

### TaskHierarchyProvider

```dart
TreeController<Task> get treeController;
bool get isReorderMode;
int get treeVersion;
bool get areAllExpanded;

void refreshTreeController(List<Task> allTasks, List<Task> activeRoots, Set<String> allTaskIds);
void toggleCollapse(Task task);
void expandAll();
void collapseAll();
void setReorderMode(bool enabled);
void expandTask(Task task);
bool isExpanded(Task task);
bool hasChildren(Task task);
```

### BrainDumpProvider

```dart
String get dumpText;
List<TaskSuggestion> get suggestions;
bool get isProcessing;
bool get hasInternet;
double get estimatedCost;
String? get errorMessage;
List<BrainDumpDraft> get drafts;
Set<String> get selectedDraftIds;
int get selectedCount;
int get selectedTotalChars;
bool get isOverLimit;
int get excessCharacters;
static const int MAX_CHAR_LIMIT = 10000;

void updateDumpText(String text);
Future<void> checkConnectivity();
Future<void> estimateCost();
Future<void> processDump();                     // Calls Claude API
void toggleSuggestionApproval(String id);
void editSuggestion(String id, String newTitle);
void removeSuggestion(String id);
List<TaskSuggestion> getApprovedSuggestions();
Future<void> saveDraft(String content);
Future<void> loadDrafts();
Future<void> deleteDraft(String id);
void toggleDraftSelection(String draftId);
String getCombinedDraftsText();
Future<void> deleteSelectedDrafts();
void clearAfterSuccess();
```

### QuizProvider

```dart
List<QuizQuestion> get questions;
int get currentQuestionIndex;
QuizQuestion get currentQuestion;
Map<int, String> get answers;
Map<int, TimeOfDay> get customTimes;
bool get isSubmitting;
String? get errorMessage;
List<Badge>? get earnedBadges;
bool get isFirstQuestion;
bool get isLastQuestion;
bool get currentQuestionAnswered;
double get progress;                           // 0.0–1.0

void selectAnswer(int questionId, String answerId);
void selectAnswerWithTime(int questionId, String answerId, {required TimeOfDay customTime});
void nextQuestion();
void previousQuestion();
void goToQuestion(int index);
Future<bool> submitQuiz();                     // Returns true on success
Future<void> loadPrefillFromSettings();        // For retaking quiz
void reset();
```

### SettingsProvider

```dart
bool get hasApiKey;
bool get isLoading;
String? get errorMessage;

Future<void> initialize();
Future<void> saveApiKey(String apiKey);
Future<void> deleteApiKey();
Future<String?> getApiKey();
```

---

## 5. User Preferences That Affect Display

These `UserSettings` fields directly influence how the UI should render:

| Field | Effect |
|-------|--------|
| `use24HourTime` | 12h vs 24h time display everywhere |
| `weekStartDay` | Calendar week start (affects week views) |
| `todayCutoffHour/Minute` | When "today" rolls over (night owls: 4:59 AM) |
| `tonightHour` | What "tonight" means in date parsing (6pm? 10pm?) |
| `morningHour` | What "morning" means in date parsing |
| `autoCompleteChildren` | Prompt/always/never when completing parent tasks |
| `notificationsEnabled` | Whether notification UI elements are shown |
| `quietHoursEnabled/Start/End/Days` | Quiet hours badge/indicator |
| `enableQuickAddDateParsing` | Whether quick-add parses natural language dates |
| `timezoneId` | Time display offset |

**SharedPreferences (via PreferencesService):**

| Key | Effect |
|-----|--------|
| `hideOldCompleted` | Whether to hide completed tasks older than threshold |
| `hideThresholdHours` | Hours after which completed tasks are hidden |
| `sortMode` | Task sort order (manual/recent/due) |
| `sortReversed` | Sort direction |

---

## 6. Events / Reactive Patterns

There are **no Streams or StreamControllers** in the codebase. All reactivity uses Flutter's `ChangeNotifier` pattern:

### How state changes propagate

```
User action
  → Provider method call
    → Service call (DB/API)
      → Provider updates internal state
        → notifyListeners()
          → Consumer<T> widgets rebuild
```

### Key state change events a visual module would care about

| Event | Where it fires | What happens |
|-------|---------------|--------------|
| Task created | `TaskProvider.createTask()` | Task list rebuilds |
| Task completed | `TaskProvider.toggleTaskCompletion()` | Task moves to completed section |
| Task uncompleted | Same as above | Task moves back to active |
| Task deleted (soft) | `TaskProvider.deleteTaskWithConfirmation()` | Task disappears, SnackBar with undo |
| Task restored | `TaskProvider.restoreTask()` | Task reappears in list |
| Hierarchy changed | `TaskProvider.changeTaskParent()` | Tree rebuilds |
| Filter changed | `TaskFilterProvider.setFilter()` | Task list re-queries DB |
| Sort changed | `TaskSortProvider.setSortMode()` | Task list re-sorts |
| Brain dump processed | `BrainDumpProvider.processDump()` | Suggestions list populated |
| Tasks bulk-created | `TaskProvider.createMultipleTasks()` | Task list rebuilds |
| Quiz submitted | `QuizProvider.submitQuiz()` | Settings written, badges awarded |
| Tags changed | `TagProvider.loadTags()` | Tag list rebuilds |

### NotificationService callbacks

```dart
// Set these to handle notification interactions:
notificationService.onNotificationTapped = (String? taskId) { ... };
notificationService.onSnoozeRequested = (String taskId) { ... };
notificationService.onCompleteRequested = (String taskId) async { ... };
notificationService.onCancelRequested = (String taskId) async { ... };
```

---

## 7. Constants

```dart
class AppConstants {
  static const String appName = 'Pin and Paper';
  static const String appVersion = '3.9.0';
  static const int databaseVersion = 11;
  static const int maxTasksInMemory = 500;
  static const Duration autoSaveDelay = Duration(milliseconds: 500);
  static const int maxBrainDumpLength = 10000;
  static const double typicalCostPerDump = 0.01;
}
```

### Tag Colors

```dart
class TagColors {
  static const Color defaultColor;               // Blue 500
  static const List<Color> presetColors;          // 12 Material Design colors
  static Color getColorByIndex(int index);        // Wraps around
  static String colorToHex(Color color);
  static Color hexToColor(String hex);
  static Color getTextColor(String colorHex);     // WCAG AA compliant text color
}
```

### Badge Definitions

```dart
class BadgeDefinitions {
  static const List<Badge> allIndividual;         // 16 badges
  static const List<Badge> allCombo;              // 3 combo badges
  static const List<Badge> all;                   // 19 total
  static Badge? getBadgeById(String id);
  static String badgeAssetPath(String badgeId, {int density = 1});
}
```

### Quiz Questions

```dart
class QuizQuestions {
  static const List<QuizQuestion> all;            // 8 questions
}
```

---

## 8. Database Tables (schema only)

For mock harness setup — these are the tables services read/write:

| Table | Primary Key | Notes |
|-------|-------------|-------|
| `tasks` | `id TEXT` | Soft delete via `deleted_at` |
| `tags` | `id TEXT` | Soft delete via `deleted_at` |
| `task_tags` | `(task_id, tag_id)` | Many-to-many junction |
| `task_reminders` | `id TEXT` | One-to-many from tasks |
| `user_settings` | `id INTEGER` | Single row (id=1) |
| `quiz_responses` | `id INTEGER` | Single row (id=1), answers + badges as JSON |
| `brain_dump_drafts` | `id TEXT` | Temporary drafts |
| `api_usage_log` | `id TEXT` | Token usage tracking |

---

## 9. Helper Types

```dart
/// Used in TaskProvider for hierarchy indicators
class IncompleteDescendantInfo {
  int immediateCount;        // Direct incomplete children
  int totalCount;            // All incomplete descendants
  int maxDepth;              // Depth of deepest incomplete
  bool get hasIncomplete;
  bool get hasDeepIncomplete;
  String get displayText;    // "> 3 incomplete" or ">> 5 incomplete"
}

/// Used in UserSettings.copyWith() to distinguish "not set" from "set to null"
class Value<T> {
  final T value;
  const Value(this.value);
}
```

---

## 10. Error Types

```dart
class ClaudeApiException implements Exception {
  String message;
  int statusCode;
}

class SearchException implements Exception {
  String message;
}
```

---

## 11. Top-Level Functions

```dart
/// Background notification action handler (registered with flutter_local_notifications)
/// Called when user taps a notification action while the app is in the background.
void onBackgroundNotificationAction(NotificationResponse response);
```
```
