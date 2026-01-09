# Scripts Directory

Utility scripts for Pin and Paper development and testing.

## Available Scripts

### `setup_performance_test_data.dart`

**Purpose:** Set up Test 7 performance testing data for Fix #C3 validation

**What it does:**
- Creates 10 parent tasks ("Performance Test Parent 1" through "Performance Test Parent 10")
- Creates 5 children under each parent (50 total children)
- Completes all 60 tasks
- Sets up hierarchical structure with proper depth values

**Usage:**

```bash
cd pin_and_paper

# Run the script
dart scripts/setup_performance_test_data.dart

# It will prompt for confirmation before creating data
# Type 'y' to proceed
```

**Requirements:**
- App must be run at least once to create the database
- Database location: `~/.local/share/pin_and_paper/pin_and_paper.db`

**Cleanup:**

After testing, remove the performance test data:

```bash
# Option 1: Via script (TODO: create cleanup script)
# Option 2: Manual SQL
sqlite3 ~/.local/share/pin_and_paper/pin_and_paper.db
DELETE FROM tasks WHERE id LIKE 'perf-%';
.quit

# Option 3: Via app - manually delete tasks
```

**Test Scenario:**

This data is used for:
- **Test 7** in `docs/phase-03/phase-3.5-fix-c3-manual-test-plan.md`
- Validates O(N) performance with 60+ completed tasks
- Tests scroll smoothness with hierarchical display
- Verifies no frame drops with large dataset

**Expected Results:**
- Frame rate: ≥60fps (target: 120fps on S22 Ultra)
- No stuttering during scroll
- Immediate response to scroll gestures
- Memory usage stable

---

## Adding New Scripts

When adding a new script:

1. **Create the script** in `pin_and_paper/scripts/`
2. **Add shebang** for direct execution: `#!/usr/bin/env dart`
3. **Make executable**: `chmod +x scripts/your_script.dart`
4. **Document here** in this README
5. **Add cleanup instructions** if the script modifies data

**Script Template:**

```dart
#!/usr/bin/env dart
// Brief description of what this script does

import 'dart:io';

void main() async {
  print('🚀 Script Name');
  // Your script logic here
}
```

---

**Maintained By:** BlueKitty + Claude
**Last Updated:** 2026-01-06
