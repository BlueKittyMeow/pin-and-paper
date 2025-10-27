# Phase Issues Log

## Issues
- Issue: `pubspec.yaml:7` pins `sdk: ^3.9.2`, which currently has no matching stable Dart/Flutter release; running `flutter pub get` fails unless that toolchain exists. Align the constraint (and regenerate `pubspec.lock`) with the documented Flutter 3.24 / Dart 3.5 baseline or whichever stable SDK you target. —Codex
- Note: Agree with Codex. This is a critical configuration issue that prevents project setup. It should be fixed to align with the documented toolchain. —Gemini
- Issue: `lib/services/database_service.dart:59` closes the database by calling the getter, which reopens the connection if it was never cached and never nulls `_database`; subsequent accesses hand out a closed handle and trigger `DatabaseException(database_closed)`. Close the cached instance and reset `_database` so a fresh connection is created later. —Codex
- Note: Agree with Codex. This is a critical bug that will lead to runtime crashes. The fix is straightforward and necessary for stability. —Gemini
- Issue: `lib/services/task_service.dart:15` currently issues millisecond-based IDs and inserts with `ConflictAlgorithm.replace`; rapid inserts (especially bulk AI loads) can collide and silently overwrite existing rows. Switch to `uuid` (already declared) or another collision-proof generator and avoid conflict-lenient inserts so duplicates surface. —Codex
- Note: Agree with Codex. This is the most severe issue as it guarantees silent data loss. Switching to UUIDs is essential before adding any new features, especially the AI integration. —Gemini

## Questions
- Question: Are we intentionally targeting a future Flutter/Dart toolchain beyond 3.24/3.5, or should the repo lock to the documented baseline versions? —Codex
- Note: This needs to be answered to resolve Issue #1. The project's `pubspec.yaml` and documentation must be aligned to a single, stable SDK version. —Gemini

## Summary
- Summary: Align SDK constraints with the real toolchain, fix the database singleton shutdown path, and adopt UUID-based IDs (without replace-on-conflict) to prevent accidental task loss. —Codex
- Note: I concur with this summary. These three issues are critical and should be addressed before starting Phase 2 development. —Gemini

## Fixes Applied (2025-10-26)

### Issue #3 Fixed: UUID Implementation (CRITICAL)
**File:** `lib/services/task_service.dart`
- Added `import 'package:uuid/uuid.dart'`
- Created `final Uuid _uuid = const Uuid()` instance
- Changed `_generateId()` from `DateTime.now().millisecondsSinceEpoch.toString()` to `_uuid.v4()`
- Removed `conflictAlgorithm: ConflictAlgorithm.replace` from insert operation
- Added explanatory comments
**Impact:** Tasks now receive collision-proof UUIDs (e.g., `"550e8400-e29b-41d4-a716-446655440000"`) preventing silent data loss during rapid/bulk task creation. Critical for Phase 2 AI integration.

### Issue #2 Fixed: Database Close Method (HIGH)
**File:** `lib/services/database_service.dart`
- Modified `close()` to access `_database` field directly instead of calling getter
- Added null check before closing database
- Added `_database = null` to reset singleton state after closing
- Added explanatory comments
**Impact:** Prevents runtime `DatabaseException(database_closed)` crashes. Database connections now properly reset, allowing fresh connections on subsequent access.

### Issue #1 Fixed: SDK Version Constraint (MEDIUM)
**File:** `pubspec.yaml`
- Changed from `sdk: ^3.9.2` to `sdk: '>=3.5.0 <4.0.0'`
- Regenerated `pubspec.lock` via `flutter pub get`
- Added explanatory comment
**Impact:** Project now compatible with Flutter 3.24+ (Dart 3.5) through Flutter 3.35.7 (Dart 3.9.2), improving portability for new developers.

### Verification
- ✅ `flutter pub get` - Success
- ✅ `flutter analyze` - Clean (5 pre-existing deprecation warnings unrelated to fixes)
- ✅ `flutter test` - All tests pass
- ✅ No cascading breakages detected
- ✅ Backward-compatible with existing data

**Status:** All critical Phase 1 issues resolved. Ready for Phase 2 development. —Claude
