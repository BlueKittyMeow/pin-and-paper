# Core Application API

This document outlines the core data models, service methods, and user preferences that the visual layer of the application might need to interact with. It serves as an API contract for building mock data and developing UI modules separately from the core business logic.

## 1. Data Models

### Task
Represents a single to-do item.

```dart
class Task {
  final String id;
  final String title;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  
  // Hierarchy
  final String? parentId;
  final int depth;
  final int position;
  final int? positionBeforeCompletion;

  // Dates & Notifications
  final DateTime? dueDate;
  final DateTime? startDate;
  final bool isAllDay;
  final String notificationType; // 'use_global', 'custom', 'none'
  final DateTime? notificationTime;
  
  // State
  final bool isTemplate;
  final DateTime? deletedAt;
}
```

### Tag
Represents a label that can be attached to tasks.

```dart
class Tag {
  final String id;
  final String name;
  final String? color; // Hex color code
  final DateTime createdAt;
  final DateTime? deletedAt;
}
```

### Badge
Represents a personality badge earned from the onboarding quiz.

```dart
class Badge {
  final String id;
  final String name;
  final String description;
  final String imagePath;
  final BadgeCategory category;
  final bool isCombo;
}
```

### UserSettings
A single object representing all user-configurable preferences.

```dart
class UserSettings {
  // Time Keywords
  final int earlyMorningHour;
  final int morningHour;
  final int noonHour;
  final int afternoonHour;
  final int tonightHour;
  final int lateNightHour;

  // Time Perception
  final int todayCutoffHour;
  final int todayCutoffMinute;
  final int weekStartDay; // 0=Sunday, 1=Monday...

  // Display
  final bool use24HourTime;
  
  // Behavior
  final String autoCompleteChildren; // 'prompt', 'always', 'never'
  final bool enableQuickAddDateParsing;
  final bool voiceSmartPunctuation;

  // Notifications
  final bool notificationsEnabled;
  final bool notifyWhenOverdue;
  final String defaultReminderTypes;
  final bool quietHoursEnabled;

  // IANA timezone ID (e.g., 'America/Detroit')
  final String? timezoneId; 
  final int? quietHoursStart; // Minutes from midnight
  final int? quietHoursEnd; // Minutes from midnight
  final String quietHoursDays; // Comma-separated day indices
}
```

---

## 2. Service Method Signatures

### TaskService
Handles all CRUD and hierarchy operations for tasks.

```dart
abstract class TaskService {
  Future<Task> createTask(String title, {DateTime? dueDate, bool isAllDay});
  Future<List<Task>> createMultipleTasks(List<TaskSuggestion> suggestions);
  
  Future<Task?> getTaskById(String taskId);
  Future<List<Task>> getAllTasks();
  Future<List<Task>> getTaskHierarchy();
  Future<List<Task>> getFilteredTasks(FilterState filter, {required bool completed});
  Future<List<Task>> getRecentlyDeletedTasks();
  
  Future<Task> updateTask(String taskId, {required String title, DateTime? dueDate, bool isAllDay, String? notes, String? notificationType});
  Future<String?> updateTaskParent(String taskId, String? newParentId, int newPosition);

  Future<Task> toggleTaskCompletion(Task task);
  Future<Task> uncompleteTask(String taskId);

  Future<int> softDeleteTask(String taskId);
  Future<int> restoreTask(String taskId);
  Future<int> permanentlyDeleteTask(String taskId);
  Future<int> emptyTrash();

  Future<int> countDescendants(String taskId);
  Future<int> getIncompleteTaskCount();
  Future<int> getCompletedTaskCount();
}
```

### TagService
Handles all CRUD operations for tags and their association with tasks.

```dart
abstract class TagService {
  Future<Tag> createTag(String name, {String? color});
  Future<List<Tag>> getAllTags();
  Future<Tag?> getTagById(String id);
  Future<List<Tag>> getTagsByIds(List<String> tagIds);
  Future<List<Tag>> getTagsForTask(String taskId);
  Future<Map<String, List<Tag>>> getTagsForAllTasks(List<String> taskIds);

  Future<void> addTagToTask(String taskId, String tagId);
  Future<bool> removeTagFromTask(String taskId, String tagId);

  Future<Map<String, int>> getTaskCountsByTag({required bool completed});
}
```

### UserSettingsService
Manages loading and updating the user's preferences.

```dart
abstract class UserSettingsService {
  Future<UserSettings> getUserSettings();
  Future<void> updateUserSettings(UserSettings settings);
  Future<void> updateSettings(UserSettings Function(UserSettings) updateFn);
  Future<void> resetToDefaults();
}
```

### QuizService
Manages the state and results of the onboarding quiz.

```dart
abstract class QuizService {
  Future<bool> hasCompletedOnboardingQuiz();
  Future<DateTime?> getQuizCompletedAt();
  Future<void> saveQuizCompletion({required Map<int, String> answers, required List<String> badgeIds});
  Future<Map<int, String>?> getSavedAnswers();
  Future<List<String>?> getEarnedBadgeIds();
  Future<void> resetQuiz();
}
```

---

## 3. User Preferences That Affect Display

The `UserSettings` model contains several fields the visual layer needs to be aware of:

- `weekStartDay`: Determines the first day of the week in calendars. (0 = Sunday)
- `use24HourTime`: Affects all time displays (due dates, reminders, etc.).
- `autoCompleteChildren`: Determines the behavior when completing a parent task.
- `todayCutoffHour` / `todayCutoffMinute`: Defines when "today" ends and "tomorrow" begins for date calculations.
- `quietHoursEnabled`, `quietHoursStart`, `quietHoursEnd`: Determines when notifications should be silenced.

---

## 4. Key Enums & States

```dart
// For sorting task lists
enum TaskSortMode { manual, recentlyCreated, dueSoonest }

// For filtering tasks by tag
enum FilterLogic { or, and }
enum TagPresenceFilter { any, onlyTagged, onlyUntagged }
enum DateFilter { any, overdue, noDueDate }

// For organizing personality badges
enum BadgeCategory {
  circadianRhythm,
  weekStructure,
  dailyRhythm,
  displayPreference,
  taskManagement,
  combo,
}

// For notification types
// Stored as strings: 'at_time', 'before_5m', 'before_10m', 'before_15m', 
// 'before_30m', 'before_1h', 'before_2h', 'before_1d', 'overdue'
class ReminderType {
  static const String at_time = 'at_time';
  // ... and others
}
```

---

## 5. Events the Visual Layer Might React To

The application uses a `Provider` architecture. UI components can listen for changes on specific providers to react to events. A call to `notifyListeners()` on a provider signals that its state has changed and the UI should rebuild.

### TaskProvider Events
- **A task is created, deleted, or updated:** The main task list changes.
- **Task completion status toggles:** A task moves between the active and completed lists; animations may trigger.
- **Hierarchy changes:** A task is nested, un-nested, or re-ordered.
- **Filter or sort order changes:** The visible list of tasks is re-ordered or re-filtered.
- **A task is highlighted:** A task briefly changes appearance after being navigated to from search.

### QuizProvider Events
- **An answer is selected:** The UI for a quiz question updates.
- **Navigation between questions:** The quiz screen shows a new question.
- **Quiz is submitted:** The UI transitions from the quiz to the badge reveal screen.

### UserSettingsProvider Events (Hypothetical)
- While there is no dedicated `UserSettingsProvider`, changes to `UserSettings` via the service would typically be reflected through a provider that holds the settings state, triggering UI updates like a change in time format (12h/24h).
