# Core API Contract (Pin and Paper)

This document summarizes the core app interfaces that the visual layer may need to mock.
Scope: `pin_and_paper/lib` (models, services, providers, utils). Implementation details omitted.

## 1) Data Models (fields only)

```dart
class Task {
  String id;
  String title;
  bool completed;
  DateTime createdAt;
  DateTime? completedAt;

  String? parentId;   // null = top-level
  int position;       // order among siblings
  int depth;          // computed by queries (0-3)

  bool isTemplate;

  DateTime? dueDate;
  bool isAllDay;
  DateTime? startDate; // multi-day tasks

  String notificationType; // 'use_global' | 'custom' | 'none'
  DateTime? notificationTime; // custom notification time

  DateTime? deletedAt; // soft delete timestamp

  String? notes;
  int? positionBeforeCompletion;
}

class Tag {
  String id;
  String name;
  String? color; // hex string like "#FF5722"
  DateTime createdAt;
  DateTime? deletedAt;
}

class TaskReminder {
  String id;
  String taskId;
  String reminderType; // one of ReminderType.*
  int? offsetMinutes;  // for 'before_custom'
  bool enabled;
}

class UserSettings {
  int id; // always 1

  // Time keyword preferences
  int earlyMorningHour;
  int morningHour;
  int noonHour;
  int afternoonHour;
  int tonightHour;
  int lateNightHour;

  // Night owl settings
  int todayCutoffHour;
  int todayCutoffMinute;

  // Week/calendar
  int weekStartDay; // 0=Sunday

  // Timezone
  String? timezoneId; // IANA

  // Display
  bool use24HourTime;

  // Task behavior
  String autoCompleteChildren; // 'prompt' | 'always' | 'never'

  // Notifications
  int defaultNotificationHour;
  int defaultNotificationMinute;
  bool notificationsEnabled;
  bool notifyWhenOverdue;
  bool quietHoursEnabled;
  int? quietHoursStart; // minutes from midnight
  int? quietHoursEnd;   // minutes from midnight
  String quietHoursDays; // "0,1,2,3,4,5,6" (0=Mon)
  String defaultReminderTypes; // "at_time,before_1h"

  // Quick add
  bool enableQuickAddDateParsing;

  // Voice
  bool voiceSmartPunctuation;

  // Timestamps
  DateTime createdAt;
  DateTime updatedAt;
}

class Value<T> {
  T value; // wrapper for copyWith nullability semantics
}

class FilterState {
  List<String> selectedTagIds;
  FilterLogic logic;           // and/or
  TagPresenceFilter presenceFilter; // any/onlyTagged/onlyUntagged
  DateFilter dateFilter;       // any/overdue/noDueDate
}

class BrainDumpDraft {
  String id;
  String content;
  DateTime createdAt;
  DateTime lastModified;
  String? failedReason;
}

class TaskSuggestion {
  String id;      // temporary UUID
  String title;
  String? notes;
  bool approved;
  bool edited;
}

class SearchResult {
  Task task;
  double score;            // 0.0 - 1.0
  MatchPositions matches;  // highlight info
}

class TaskWithTags {
  Task task;
  String? tagNames; // space-separated names from SQL
}

class MatchPositions {
  List<MatchRange> titleMatches;
  List<MatchRange> notesMatches;
  List<MatchRange> tagMatches;
}

class MatchRange {
  int start;
  int end; // exclusive
}

class QuizAnswer {
  String id;
  String text;
  String? description;
  bool showTimePicker;
  bool showDayPicker;
}

class QuizQuestion {
  int id;
  String title;
  String question;
  String? imagePath;
  List<QuizAnswer> answers;
}

class Badge {
  String id;
  String name;
  String description;
  String imagePath;
  BadgeCategory category;
  bool isCombo;
}

class ParsedDate {
  String matchedText;
  TextRange matchedRange;
  DateTime date;
  bool isAllDay;
}

class TaskMatch {
  Task task;
  double similarity;
}

class UsageStats {
  int totalCalls;
  double totalCost;
  int monthCalls;
  double monthCost;

  double averageCostPerCall; // computed
}

class IncompleteDescendantInfo {
  int immediateCount;
  int totalCount;
  int maxDepth;
}
```

## 2) Enums and Key Constants

```dart
enum TaskSortMode { manual, recentlyCreated, dueSoonest }

enum FilterLogic { or, and }

enum TagPresenceFilter { any, onlyTagged, onlyUntagged }

enum DateFilter { any, overdue, noDueDate }

enum BadgeCategory {
  circadianRhythm,
  weekStructure,
  dailyRhythm,
  displayPreference,
  taskManagement,
  combo,
}

enum SearchScope { all, current, recentlyCompleted, completed }

class ReminderType {
  static const String atTime = 'at_time';
  static const String before1h = 'before_1h';
  static const String before1d = 'before_1d';
  static const String beforeCustom = 'before_custom';
  static const String overdue = 'overdue';
  static const List<String> all = [ ... ];
}

class AppConstants {
  // DB
  static const String databaseName = 'pin_and_paper.db';
  static const int databaseVersion = 11;

  // Tables
  static const String tasksTable = 'tasks';
  static const String brainDumpDraftsTable = 'brain_dump_drafts';
  static const String apiUsageLogTable = 'api_usage_log';
  static const String userSettingsTable = 'user_settings';
  static const String taskImagesTable = 'task_images';
  static const String entitiesTable = 'entities';
  static const String tagsTable = 'tags';
  static const String taskEntitiesTable = 'task_entities';
  static const String taskTagsTable = 'task_tags';
  static const String taskRemindersTable = 'task_reminders';
  static const String quizResponsesTable = 'quiz_responses';

  // Notifications
  static const String notificationChannelId = 'pin_paper_task_reminders';
  static const String notificationChannelName = 'Task Reminders';
  static const String notificationChannelDescription = 'Notifications for upcoming task due dates';
  static const String notificationGroupKey = 'pin_paper_task_group';

  // App
  static const String appName = 'Pin and Paper';
  static const String appVersion = '3.9.0';

  // Misc
  static const int maxTasksInMemory = 500;
  static const Duration autoSaveDelay = Duration(milliseconds: 500);
  static const int maxBrainDumpLength = 10000;
  static const double typicalCostPerDump = 0.01;
}

class Tag {
  static const int maxNameLength = 250;
}

class TaskMatchingService {
  static const double CONFIDENT_THRESHOLD = 0.75;
  static const double POSSIBLE_THRESHOLD = 0.30;
}

class BrainDumpProvider {
  static const int MAX_CHAR_LIMIT = 10000;
}

class TagColors {
  static const Color defaultColor = Color(0xFF2196F3);
  static const List<Color> presetColors = [ ... ];
  static const Map<String, Color> textColorMap = { ... };
}
```

## 3) Service Method Signatures

### TaskService
```dart
class TaskService {
  Future<Task> createTask(String title, {DateTime? dueDate, bool isAllDay = true});
  Future<List<Task>> createMultipleTasks(List<TaskSuggestion> suggestions);

  Future<List<Task>> getAllTasks();
  Future<Task?> getTaskById(String taskId);
  Future<List<Task>> getTaskHierarchy();
  Future<List<Task>> getTaskWithChildren(String parentId);
  Future<List<Task>> getParentChain(String taskId);

  Future<List<Task>> getFilteredTasks(FilterState filter, {required bool completed});
  Future<int> countFilteredTasks(FilterState filter, {required bool completed});

  Future<Task> toggleTaskCompletion(Task task);
  Future<Task> uncompleteTask(String taskId);

  Future<Task> updateTask(
    String taskId, {
    required String title,
    DateTime? dueDate,
    bool isAllDay = true,
    String? notes,
    String? notificationType,
  });
  Future<Task> updateTaskTitle(String taskId, String newTitle);

  Future<int> getIncompleteTaskCount();
  Future<int> getCompletedTaskCount();

  Future<String?> updateTaskParent(String taskId, String? newParentId, int newPosition);

  Future<int> countDescendants(String taskId);
  Future<int> deleteTaskWithChildren(String taskId);

  // Soft delete / trash
  Future<int> softDeleteTask(String taskId);
  Future<int> restoreTask(String taskId);
  Future<int> countDeletedAncestors(String taskId);
  Future<int> countDeletedDescendants(String taskId);
  Future<int> permanentlyDeleteTask(String taskId);
  Future<List<Task>> getRecentlyDeletedTasks();
  Future<int> countRecentlyDeletedTasks();
  Future<int> emptyTrash();
  Future<int> cleanupExpiredDeletedTasks();
  Future<int> cleanupOldDeletedTasks({int daysThreshold = 30});
}
```

### TagService
```dart
class TagService {
  Future<Tag> createTag(String name, {String? color});
  Future<List<Tag>> getAllTags();
  Future<Tag?> getTagById(String id);
  Future<Tag?> getTagByName(String name);
  Future<List<Tag>> getTagsByIds(List<String> tagIds);

  Future<void> addTagToTask(String taskId, String tagId);
  Future<bool> removeTagFromTask(String taskId, String tagId);
  Future<List<Tag>> getTagsForTask(String taskId);
  Future<Map<String, int>> getTaskCountsByTag({required bool completed});
  Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds);
}
```

### UserSettingsService
```dart
class UserSettingsService {
  Future<UserSettings> getUserSettings();
  Future<void> updateUserSettings(UserSettings settings);
  Future<void> updateSettings(UserSettings Function(UserSettings) updateFn);
  Future<void> resetToDefaults();
}
```

### PreferencesService
```dart
class PreferencesService {
  Future<bool> getHideOldCompleted();
  Future<void> setHideOldCompleted(bool value);
  Future<int> getHideThresholdHours();
  Future<void> setHideThresholdHours(int hours);

  Future<String> getSortMode();
  Future<void> setSortMode(String mode);
  Future<bool> getSortReversed();
  Future<void> setSortReversed(bool reversed);
}
```

### SettingsService (Claude API key)
```dart
class SettingsService {
  bool isValidApiKey(String key);
  Future<(bool, String?)> testApiKey(String apiKey);
  Future<void> saveApiKey(String apiKey);
  Future<String?> getApiKey();
  Future<bool> hasApiKey();
  Future<void> deleteApiKey();
}
```

### SecureStorageService
```dart
class SecureStorageService {
  Future<void> saveClaudeApiKey(String apiKey);
  Future<String?> getClaudeApiKey();
  Future<void> deleteClaudeApiKey();
  Future<bool> hasClaudeApiKey();
}
```

### ClaudeService
```dart
class ClaudeService {
  Future<double> estimateCost(String text);
  Future<List<TaskSuggestion>> extractTasks(String dump, String apiKey);
}
```

### ApiUsageService
```dart
class ApiUsageService {
  Future<void> logUsage({
    required String operationType,
    required int inputTokens,
    required int outputTokens,
    required String model,
  });

  Future<UsageStats> getStats();
}
```

### QuizService
```dart
class QuizService {
  Future<bool> hasCompletedOnboardingQuiz();
  Future<DateTime?> getQuizCompletedAt();
  Future<void> saveQuizCompletion({required Map<int, String> answers, required List<String> badgeIds});
  Future<Map<int, String>?> getSavedAnswers();
  Future<List<String>?> getEarnedBadgeIds();
  Future<int?> getQuizVersion();
  Future<void> resetQuiz();
}
```

### QuizInferenceService
```dart
class QuizInferenceService {
  UserSettings inferSettings(Map<int, String> answers, UserSettings currentSettings);
  List<Badge> calculateBadges(Map<int, String> answers);
  Map<int, String> prefillFromSettings(UserSettings settings);
}
```

### DateParsingService
```dart
class DateParsingService {
  Future<void> initialize();
  ParsedDate? parse(String text, {DateTime? now});
  bool containsPotentialDate(String text);
  DateTime getEffectiveToday(DateTime now, int todayWindowHours, int todayWindowMinutes);
  DateTime getCurrentEffectiveToday();
  Future<void> loadSettings();
  void dispose();
}
```

### SearchService
```dart
class SearchService {
  SearchService(Database db);
  Future<List<SearchResult>> search({
    required String query,
    required SearchScope scope,
    FilterState? tagFilters,
  });
}
```

### TaskMatchingService
```dart
class TaskMatchingService {
  String extractAction(String input);
  List<TaskMatch> findMatches(String input, List<Task> tasks);
  TaskMatch? getConfidentMatch(String input, List<Task> tasks);
}
```

### NotificationService
```dart
class NotificationService {
  bool get isInitialized;

  // Callbacks set by UI layer
  void Function(String? taskId)? onNotificationTapped;
  void Function(String taskId)? onSnoozeRequested;
  Future<void> Function(String taskId)? onCompleteRequested;
  Future<void> Function(String taskId)? onCancelRequested;

  Future<void> initialize();
  void handleNotificationResponse(NotificationResponse response);
  Future<bool> requestPermission();
  Future<bool> isPermissionGranted();
  Future<bool> canScheduleExactAlarms();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    String? payload,
    List<AndroidNotificationAction>? actions,
  });

  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<int> getPendingCount();
  Future<NotificationResponse?> getLaunchNotification();

  tz.Location get localTimezone;
  tz.TZDateTime toLocalTZ(DateTime dateTime);

  void dispose();
}
```

### ReminderService
```dart
class ReminderService {
  Future<List<TaskReminder>> getRemindersForTask(String taskId);
  Future<void> setReminders(String taskId, List<TaskReminder> reminders);
  Future<void> deleteReminders(String taskId);

  Future<void> scheduleReminders(Task task);
  Future<void> cancelReminders(String taskId);
  Future<void> rescheduleAll();
  Future<List<Task>> checkMissed();

  tz.TZDateTime? computeNotificationTime(
    Task task,
    TaskReminder reminder,
    UserSettings settings,
  );
}
```

### DatabaseService
```dart
class DatabaseService {
  static final DatabaseService instance;

  Future<Database> get database;
  static void setTestDatabase(Database testDb);
  static Future<void> resetDatabase();

  Future<void> close();

  // Brain dump drafts
  Future<List<BrainDumpDraft>> getBrainDumpDrafts();
  Future<void> deleteBrainDumpDraft(String id);
  Future<void> cleanupOldDrafts();

  // API usage log
  Future<void> insertApiUsageLog(Map<String, dynamic> logEntry);
}
```

## 4) UI State Providers (ChangeNotifier)

These are the primary UI-facing APIs (visual modules typically listen via Provider/ChangeNotifier).

### TaskProvider
```dart
class TaskProvider extends ChangeNotifier {
  // State getters
  List<Task> get tasks;
  bool get isLoading;
  String? get errorMessage;

  // Hierarchy / tree state
  bool get isReorderMode;
  TreeController<Task> get treeController;
  int get treeVersion;
  bool get areAllExpanded;

  // Sorting (delegates to TaskSortProvider)
  TaskSortMode get sortMode;
  bool get sortReversed;

  // Task lists
  List<Task> get activeTasks;
  List<Task> get recentlyCompletedTasks;
  List<Task> get oldCompletedTasks;
  List<Task> get visibleTasks;

  // Counts
  int get incompleteCount;
  int get completedCount;

  // Preferences
  bool get hideOldCompleted;
  int get hideThresholdHours;

  // Tag filtering state (delegates to TaskFilterProvider)
  FilterState get filterState;
  bool get hasActiveFilters;

  // Core actions
  Future<void> loadTasks();
  Future<void> refreshTags();
  Future<void> loadPreferences();
  Future<void> setHideOldCompleted(bool value);
  Future<void> setHideThresholdHours(int hours);

  Future<void> createTask(
    String title, {
    DateTime? dueDate,
    bool isAllDay = true,
  });
  Future<void> createMultipleTasks(List<TaskSuggestion> suggestions);

  Future<void> toggleTaskCompletion(Task task);
  Future<void> updateTaskTitle(String taskId, String newTitle);
  Future<void> updateTask({
    required String taskId,
    required String title,
    DateTime? dueDate,
    bool isAllDay = true,
    String? notes,
    required List<String> tagIds,
    String? notificationType,
    List<String>? reminderTypes,
    bool? notifyIfOverdue,
  });

  void setReorderMode(bool enabled);
  void toggleCollapse(Task task);
  void expandAll();
  void collapseAll();

  Future<void> changeTaskParent({
    required String taskId,
    String? newParentId,
    required int newPosition,
  });
  Future<void> onNodeAccepted(TreeDragAndDropDetails<Task> details);

  Future<bool> deleteTaskWithConfirmation(
    String taskId,
    Future<bool> Function(int) showConfirmation,
  );
  Future<bool> restoreTask(String taskId);
  Future<bool> permanentlyDeleteTask(String taskId, Future<bool> Function() showConfirmation);
  Future<bool> emptyTrash(Future<bool> Function(int) showConfirmation);
  Future<int> getRecentlyDeletedCount();
  Future<List<Task>> getRecentlyDeletedTasks();

  // Search state for UI
  GlobalKey getKeyForTask(String taskId);
  void saveSearchState(Map<String, dynamic> state);
  Map<String, dynamic>? getSearchState();
  Future<void> navigateToTask(String taskId);

  // Highlighting
  bool isTaskHighlighted(String taskId);

  // Utility getters
  Task? getTaskById(String taskId);
  List<Tag> getTagsForTask(String taskId);
  IncompleteDescendantInfo? getIncompleteDescendantInfo(String taskId);
  bool hasCompletedChildren(String taskId);
  bool isCompletedParentWithIncomplete(String taskId);
  String? getBreadcrumb(Task task);
  List<Task> get visibleCompletedTasks;
  List<Task> get completedTasksWithHierarchy;
}
```

### TagProvider
```dart
class TagProvider extends ChangeNotifier {
  List<Tag> get tags;
  bool get isLoading;
  String? get errorMessage;

  Future<void> loadTags();
  Future<Tag?> createTag(String name, {String? color});
  Future<Tag?> findTagByName(String name);
  Future<bool> addTagToTask(String taskId, String tagId);
  Future<bool> removeTagFromTask(String taskId, String tagId);
  Future<List<Tag>> getTagsForTask(String taskId);
  Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds);

  void clearError();
  String getNextPresetColor();
}
```

### TaskSortProvider
```dart
class TaskSortProvider extends ChangeNotifier {
  TaskSortMode get sortMode;
  bool get sortReversed;

  Future<void> loadPreferences();
  void setSortMode(TaskSortMode mode);
  void toggleSortReversed();
}
```

### TaskFilterProvider
```dart
class TaskFilterProvider extends ChangeNotifier {
  FilterState get filterState;
  bool get hasActiveFilters;
  int get filterOperationId;

  int setFilter(FilterState filter);
  void rollbackFilter(FilterState previousFilter, int operationId);
  void addTagFilter(String tagId);
  void removeTagFilter(String tagId);
  void clearFilters();
}
```

### TaskHierarchyProvider
```dart
class TaskHierarchyProvider extends ChangeNotifier {
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
}
```

### SettingsProvider
```dart
class SettingsProvider extends ChangeNotifier {
  bool get hasApiKey;
  bool get isLoading;
  String? get errorMessage;

  Future<void> initialize();
  Future<void> saveApiKey(String apiKey);
  Future<void> deleteApiKey();
  Future<String?> getApiKey();
}
```

### QuizProvider
```dart
class QuizProvider extends ChangeNotifier {
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
  double get progress;

  void selectAnswer(int questionId, String answerId);
  void selectAnswerWithTime(int questionId, String answerId, {required TimeOfDay customTime});
  void nextQuestion();
  void previousQuestion();
  void goToQuestion(int index);

  Future<bool> submitQuiz();
  Future<void> loadPrefillFromSettings();
  void reset();
}
```

### BrainDumpProvider
```dart
class BrainDumpProvider extends ChangeNotifier {
  String get dumpText;
  List<TaskSuggestion> get suggestions;
  bool get isProcessing;
  bool get hasInternet;
  double get estimatedCost;
  String? get errorMessage;
  List<BrainDumpDraft> get drafts;
  Set<String> get selectedDraftIds;
  int get selectedCount;
  String? get originalDumpText;
  int get selectedTotalChars;
  bool get isOverLimit;
  int get excessCharacters;

  void updateDumpText(String text);
  Future<void> checkConnectivity();
  Future<void> estimateCost();
  Future<void> processDump();

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

  void clearOriginalText();
  void clearAfterSuccess();
  Future<void> clearAndDeleteDraft();
  void clear();
  Future<void> loadDraft(String draftId, String content);
}
```

## 5) User Preferences That Affect UI/Behavior

### Stored in UserSettings (SQLite)
- Time keyword mapping: `earlyMorningHour`, `morningHour`, `noonHour`, `afternoonHour`, `tonightHour`, `lateNightHour`
- Night owl “today” window: `todayCutoffHour`, `todayCutoffMinute`
- Week start: `weekStartDay`
- Timezone: `timezoneId`
- Display format: `use24HourTime`
- Task behavior: `autoCompleteChildren` (`prompt` | `always` | `never`)
- Notifications: `defaultNotificationHour`, `defaultNotificationMinute`, `notificationsEnabled`, `notifyWhenOverdue`, `quietHoursEnabled`, `quietHoursStart`, `quietHoursEnd`, `quietHoursDays`, `defaultReminderTypes`
- Quick add: `enableQuickAddDateParsing`
- Voice: `voiceSmartPunctuation`

### Stored in SharedPreferences (PreferencesService)
- `hideOldCompleted` (bool)
- `hideThresholdHours` (int)
- `sortMode` (string, TaskSortMode.name)
- `sortReversed` (bool)

## 6) Events / Callbacks / Subscriptions

- All `*Provider` classes are `ChangeNotifier`: UI subscribes via Provider/`addListener` and reacts to `notifyListeners()`.
- `NotificationService` exposes callbacks for UI to handle notification actions:
  - `onNotificationTapped(String? taskId)`
  - `onSnoozeRequested(String taskId)`
  - `onCompleteRequested(String taskId)`
  - `onCancelRequested(String taskId)`
- Top-level notification action entrypoint:
  - `void onBackgroundNotificationAction(NotificationResponse response)`

## 7) Error Types Exposed

```dart
class ClaudeApiException implements Exception {
  String message;
  int statusCode;
}

class SearchException implements Exception {
  String message;
}
```

## 8) Static Data Sources

```dart
class QuizQuestions {
  static const List<QuizQuestion> all = [ ... ]; // 8 questions
}
```
