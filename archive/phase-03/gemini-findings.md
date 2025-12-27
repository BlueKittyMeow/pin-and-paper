## Issue: `createdAt` field is nullable in `UserSettings.copyWith`
**File:** pin_and_paper/lib/models/user_settings.dart:155
**Type:** Bug
**Found:** 2025-10-30

**Description:**
The `copyWith` method in `UserSettings` allows `createdAt` to be nullable, but the constructor requires it. This can lead to runtime errors if `copyWith` is called with a null `createdAt` value.

**Suggested Fix:**
Remove the `createdAt` field from the `copyWith` method's parameter list. The creation timestamp should be immutable and not change after the object is created.

**Impact:** Medium

---

## Issue: Inconsistent `databaseVersion` constant
**File:** pin_and_paper/lib/utils/constants.dart:5
**Type:** Inconsistency
**Found:** 2025-10-30

**Description:**
The `databaseVersion` is defined in `AppConstants`, but the migration logic in `database_service.dart` uses a hardcoded `4`. This could lead to issues if the constant is updated in one place but not the other.

**Suggested Fix:**
Use the `AppConstants.databaseVersion` constant in the `_upgradeDB` function in `database_service.dart`.

**Impact:** Low

---

## Issue: `TaskProvider` constructor allows nullable dependencies
**File:** pin_and_paper/lib/providers/task_provider.dart:8
**Type:** Code Smell
**Found:** 2025-10-30

**Description:**
The `TaskProvider` constructor allows for nullable `TaskService` and `PreferencesService` dependencies, but then immediately uses the null-coalescing operator to provide default instances. This makes the nullability misleading.

**Suggested Fix:**
Make the constructor parameters non-nullable and provide default instances directly in the constructor signature.

**Impact:** Low

---

## Issue: Pre-existing Linting Issues
**File:** Multiple
**Type:** Linting
**Found:** 2025-10-30

**Description:**
As noted in `3.1-issues.md`, there are 21 pre-existing linting issues from Phase 2. These should be addressed to improve code quality and prevent potential bugs.

**Suggested Fix:**
Address the 21 linting issues as outlined in `docs/phase-03/3.1-issues.md`.

**Impact:** Medium
