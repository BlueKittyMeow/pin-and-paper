# Build and Release Checklist

**Purpose:** Ensure all version numbers are updated and builds are tested before release
**Used by:** Claude + BlueKitty
**Last Updated:** 2026-01-05

---

## Overview

This document covers the complete workflow for building and releasing Pin and Paper, from version updates through testing to final deployment.

**Key Principle:** Version numbers should match the current phase and be updated BEFORE building for release.

---

## Pre-Build Checklist: Update Version Numbers

**IMPORTANT:** Update these BEFORE building a release version!

### 1. App Version (pubspec.yaml)

**File:** `pin_and_paper/pubspec.yaml`

**Search for:** `version:`

**Format:** `MAJOR.MINOR.PATCH+BUILD`
- **MAJOR.MINOR** should match current phase (e.g., Phase 3.5 = version 3.5.x)
- **PATCH** increments for bug fixes within a phase (usually 0)
- **BUILD** increments for every build (even if version stays same)

**Example:**
```yaml
# Current
version: 0.2.0+2

# Should be (for Phase 3.5)
version: 3.5.0+5

# Next build (same phase)
version: 3.5.0+6

# Phase 3.6
version: 3.6.0+7
```

**Update:**
```bash
cd pin_and_paper
# Edit pubspec.yaml
# Update version line to match current phase
```

---

### 2. Database Version (constants.dart)

**File:** `pin_and_paper/lib/utils/constants.dart`

**Search for:** `static const int databaseVersion`

**Current:** `6` (Phase 3.5 - Tags)

**When to increment:**
- ONLY when schema changes (new tables, columns, migrations)
- NOT for every phase (only if DB changes)

**Example:**
```dart
// Phase 3.5 (current)
static const int databaseVersion = 6;

// Phase 3.6 (if no schema changes, stays 6)
static const int databaseVersion = 6;

// Phase 4 (if adding spatial tables)
static const int databaseVersion = 7;
```

**Database version history:**
- v1: Phase 1 (basic tasks)
- v2: Phase 2 (AI integration)
- v3: Phase 2 Stretch (API usage)
- v4: Phase 3.1 (task nesting)
- v5: Phase 3.3-3.4 (soft delete, editing)
- v6: Phase 3.5 (tags)

---

### 3. App Version Constant (constants.dart)

**File:** `pin_and_paper/lib/utils/constants.dart`

**Search for:** `static const String appVersion`

**Should match pubspec.yaml version** (without build number)

**Example:**
```dart
// Current (OUTDATED)
static const String appVersion = '0.2.0';

// Should be (Phase 3.5)
static const String appVersion = '3.5.0';
```

---

### 4. Version Update Summary

**Quick verification checklist:**
- [ ] `pubspec.yaml` version matches phase (e.g., 3.5.0+X)
- [ ] `pubspec.yaml` build number incremented (+X)
- [ ] `constants.dart` appVersion matches pubspec (without +X)
- [ ] `constants.dart` databaseVersion correct for schema state

---

## Build Modes

### Debug Build (Development)

**When to use:**
- Daily development
- Quick testing
- Hot reload needed

**Command:**
```bash
cd pin_and_paper
flutter run
```

**Characteristics:**
- Debug symbols included
- Slower performance
- Larger APK size
- Separate data directory from release
- Hot reload available

---

### Release Build (Production)

**When to use:**
- End of phase testing
- Performance testing
- Final user release
- Production deployment

**Command:**
```bash
cd pin_and_paper
flutter run --release
```

**Or build APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Characteristics:**
- Optimized code
- Full performance (120fps target)
- Smaller APK size
- Production data directory
- No hot reload

---

### Profile Build (Performance Analysis)

**When to use:**
- Performance profiling
- Frame rate analysis
- Memory leak detection

**Command:**
```bash
cd pin_and_paper
flutter run --profile
```

---

## Pre-Release Testing Checklist

**Before marking a phase complete, test in RELEASE mode!**

### 1. Version Verification

- [ ] Open app in release mode
- [ ] Check Settings > About (if available)
- [ ] Verify version displayed matches expected

### 2. Performance Testing

**Device:** Samsung Galaxy S22 Ultra

- [ ] App launches in <2 seconds
- [ ] Scrolling feels smooth (60fps minimum, 120fps target)
- [ ] No frame drops during animations
- [ ] Tag picker loads instantly (<100ms)
- [ ] Large task lists (100+ tasks) scroll smoothly

### 3. Database Migration Testing

**If database version changed:**
- [ ] Install previous version with test data
- [ ] Install new version over it
- [ ] Verify all data migrated correctly
- [ ] Check no data loss
- [ ] Verify new schema features work

### 4. Fresh Install Testing

- [ ] Uninstall app completely
- [ ] Install new release build
- [ ] Verify fresh database created (v6)
- [ ] Test all features from scratch

### 5. Feature Completeness

- [ ] All phase features working
- [ ] No critical bugs
- [ ] All tests passing (flutter test)
- [ ] Manual test plan completed
- [ ] AI review findings addressed

---

## Build Commands Reference

### Install to Connected Device

```bash
cd pin_and_paper

# Debug (development)
flutter run

# Release (production testing)
flutter run --release

# Profile (performance analysis)
flutter run --profile
```

### Build APK (Android)

```bash
cd pin_and_paper

# Release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Debug APK (for sharing debug builds)
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Split per ABI (smaller downloads)
flutter build apk --split-per-abi --release
```

### Build App Bundle (Google Play)

```bash
cd pin_and_paper

# Release bundle
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build for Other Platforms

```bash
# iOS (requires macOS)
flutter build ios --release

# Linux
flutter build linux --release

# Windows
flutter build windows --release

# Web
flutter build web --release
```

---

## Test Execution

### Running Tests

**Default command:**
```bash
cd pin_and_paper
flutter test
```

**Recommended command (Phase 3.5+):**
```bash
flutter test --concurrency=1
```

### Why --concurrency=1?

**Issue:** sqflite_common_ffi has limitations with parallel in-memory databases

**Symptoms without --concurrency=1:**
- "database is locked" SQLite errors
- Random test failures
- Race conditions with shared database instances

**Solution:** Run tests sequentially instead of in parallel

**Impact:**
- ✅ All 154+ tests pass reliably
- ✅ No database lock errors
- ✅ Predictable test results
- ⚠️ Adds ~30 seconds to test execution time

**Trade-off:** Reliability > Speed for test execution

### Test Execution in Different Contexts

**Local development:**
```bash
flutter test --concurrency=1
```

**CI/CD pipelines:**
```yaml
test:
  script:
    - cd pin_and_paper
    - flutter test --concurrency=1
```

**Testing specific files:**
```bash
# Single test file
flutter test --concurrency=1 test/services/tag_service_test.dart

# Multiple test files
flutter test --concurrency=1 test/services/

# All tests
flutter test --concurrency=1
```

### Test Coverage

**Generate coverage report:**
```bash
flutter test --coverage --concurrency=1
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Current test count:** 154+ tests (as of Phase 3.5)

### Test Failures Troubleshooting

**Problem:** Tests fail with "database is locked"

**Solution:**
1. Ensure using `--concurrency=1` flag
2. Verify no tearDown() functions closing shared database
3. Check for static database variables in test helpers
4. Run tests again with --concurrency=1

**Problem:** Tests pass locally but fail in CI

**Solution:**
1. Add `--concurrency=1` to CI script
2. Ensure CI uses same Flutter version
3. Check for environment-specific dependencies

---

## Release Workflow

### End of Phase Release

**When:** Completing Phase X.Y

**Steps:**

1. **Update version numbers** (see Pre-Build Checklist above)
   - pubspec.yaml version
   - constants.dart appVersion
   - constants.dart databaseVersion (if schema changed)

2. **Run full test suite**
   ```bash
   cd pin_and_paper
   flutter test
   ```
   - All tests must pass

3. **Build release APK**
   ```bash
   flutter build apk --release
   ```

4. **Install and test on device**
   ```bash
   flutter install --release
   ```
   - Run through manual test plan
   - Verify performance targets
   - Check version display

5. **Update documentation** (see documentation-workflow.md)
   - PROJECT_SPEC.md
   - README.md
   - Phase completion docs

6. **Commit version updates**
   ```bash
   git add pubspec.yaml lib/utils/constants.dart
   git commit -m "chore: Bump version to 3.5.0 for Phase 3.5 release"
   ```

7. **Tag release**
   ```bash
   git tag -a v3.5.0 -m "Phase 3.5: Comprehensive Tagging System"
   git push origin v3.5.0
   ```

8. **Archive phase documentation** (see phase-end-checklist.md)

---

## Troubleshooting

### "Version is outdated" Warning

**Problem:** Version in pubspec.yaml doesn't match phase

**Solution:**
1. Update pubspec.yaml version to match current phase
2. Update constants.dart appVersion to match
3. Rebuild

### Database Migration Failure

**Problem:** App crashes on upgrade with database error

**Solution:**
1. Check DatabaseService migration code
2. Verify databaseVersion incremented
3. Test migration path from previous version
4. Check migration logs in console

### Debug/Release Data Mismatch

**Problem:** Tasks exist in debug but not release (or vice versa)

**Explanation:** Debug and release builds use separate data directories

**Solution:**
- Use consistent build mode for testing
- For production testing, always use release mode
- For development, debug mode is fine

### Performance Issues in Release

**Problem:** Release build feels slower than expected

**Steps to diagnose:**
1. Build in profile mode: `flutter run --profile`
2. Open DevTools Performance tab
3. Look for frame drops, jank
4. Check for expensive operations in build() methods
5. Verify batch loading for large datasets

---

## Version Number Strategy

### Semantic Versioning for Phases

**Format:** `PHASE.SUBPHASE.PATCH+BUILD`

**Examples:**
- Phase 3.5 initial release: `3.5.0+1`
- Phase 3.5 bug fix: `3.5.1+2`
- Phase 3.6 initial release: `3.6.0+3`
- Phase 4.1 initial release: `4.1.0+10`

**Build number:**
- Increments monotonically (never goes down)
- Increments for every APK built (even if version stays same)
- Used by app stores to determine "newer" version

**When to increment what:**
- **MAJOR (phase):** New major phase (1.x → 2.x → 3.x)
- **MINOR (subphase):** New subphase (3.1 → 3.2 → 3.3)
- **PATCH:** Bug fixes within subphase (3.5.0 → 3.5.1)
- **BUILD:** Every build (+1 → +2 → +3)

---

## Integration with Phase Workflow

**Phase Start:** (see phase-start-checklist.md)
- Version numbers can stay unchanged during planning

**During Implementation:**
- Debug builds for development
- Version updates not required yet

**Phase End:** (see phase-end-checklist.md)
- **CRITICAL:** Update all version numbers BEFORE release build
- Build in release mode for final testing
- Run full test suite
- Complete manual test plan
- Update master documentation
- Tag release in git

---

## Quick Reference Card

**Before every release build:**
```bash
# 1. Update versions
vim pubspec.yaml  # version: 3.5.0+5
vim lib/utils/constants.dart  # appVersion = '3.5.0', databaseVersion = 6

# 2. Run tests
flutter test

# 3. Build release
flutter build apk --release

# 4. Install and test
flutter install --release

# 5. Commit and tag
git add pubspec.yaml lib/utils/constants.dart
git commit -m "chore: Bump version to 3.5.0 for Phase 3.5 release"
git tag -a v3.5.0 -m "Phase 3.5: Comprehensive Tagging System"
git push origin main --tags
```

---

## Appendix: Current Version Status

**As of 2026-01-05:**

| File | Field | Current Value | Should Be (Phase 3.5) |
|------|-------|---------------|----------------------|
| pubspec.yaml | version | 0.2.0+2 | 3.5.0+5 |
| constants.dart | appVersion | '0.2.0' | '3.5.0' |
| constants.dart | databaseVersion | 6 | 6 ✓ |

**Action needed:** Update pubspec.yaml and constants.dart appVersion before Phase 3.5 release build.

---

**Template Version:** 1.0
**Last Updated:** 2026-01-05
**Maintained By:** BlueKitty + Claude
