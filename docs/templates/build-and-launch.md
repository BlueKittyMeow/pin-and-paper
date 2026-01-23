# Build and Launch Guide

**Purpose:** Reliable steps for building and launching Pin and Paper on Linux

**Last Updated:** 2026-01-10

---

## Prerequisites

- Flutter SDK installed
- Working directory: `/home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper`

---

## Build Methods

### Method 1: Clean Build (Recommended After Code Changes)

Use this when you've made code changes to ensure no cached artifacts cause issues.

```bash
cd pin_and_paper  # Navigate to Flutter project directory
flutter clean && flutter build linux --release
```

**Why clean?** Flutter sometimes caches build artifacts even when code changes. Clean ensures a fresh build.

### Method 2: Quick Rebuild (Cache OK)

Use this when you're confident the cache is valid (e.g., no code changes, just relaunching).

```bash
cd pin_and_paper
flutter build linux --release
```

---

## Launch Methods

### From Project Directory

When in `/home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper`:

```bash
./build/linux/x64/release/bundle/pin_and_paper
```

### Background Launch (for development/testing)

```bash
./build/linux/x64/release/bundle/pin_and_paper &
```

Or use process ID tracking:
```bash
nohup ./build/linux/x64/release/bundle/pin_and_paper > /tmp/pin_and_paper.log 2>&1 &
echo $!  # Prints process ID
```

---

## Verification Steps

### Verify Build is Fresh

Check the executable's modification time:

```bash
stat build/linux/x64/release/bundle/pin_and_paper | grep Modify
date
```

**Compare timestamps:** The executable's modification time should be recent (within last few minutes).

**Example:**
```
Modify: 2026-01-10 15:44:52.000000000 -0500
Sat Jan 10 03:45:00 PM EST 2026
```
✓ Build is fresh (1 minute ago)

### Verify App is Running

```bash
ps aux | grep pin_and_paper | grep -v grep
```

Should show process if running.

---

## Troubleshooting

### Problem: "No such file or directory"

**Symptom:** `/bin/bash: line 1: ./build/linux/x64/release/bundle/pin_and_paper: No such file or directory`

**Cause:** Wrong working directory

**Solution:**
```bash
pwd  # Should show: /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper
cd /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper
./build/linux/x64/release/bundle/pin_and_paper
```

### Problem: Code Changes Not Reflected

**Symptom:** App behavior doesn't match recent code changes

**Cause:** Flutter cached old build artifacts

**Solution:**
```bash
flutter clean
flutter build linux --release
```

**Verification:**
```bash
stat build/linux/x64/release/bundle/pin_and_paper | grep Modify
# Timestamp should be very recent
```

### Problem: Build Succeeds But Binary Unchanged

**Symptom:** `flutter build` says "✓ Built" but timestamp is old

**Cause:** Flutter's incremental build detected no changes (incorrectly)

**Solution:**
```bash
flutter clean  # Force clean
rm -rf build/  # Nuclear option if clean doesn't work
flutter build linux --release
```

### Problem: App Won't Launch (No Window)

**Possible causes:**
1. Wrong working directory (see above)
2. Missing dependencies
3. Display environment issues

**Debug steps:**
```bash
# Run in foreground to see error messages
./build/linux/x64/release/bundle/pin_and_paper

# Check for missing libraries
ldd build/linux/x64/release/bundle/pin_and_paper

# Verify DISPLAY variable (for GUI)
echo $DISPLAY
```

---

## Complete Workflow Example

### After Making Code Changes

```bash
# 1. Navigate to project
cd /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper

# 2. Clean build
flutter clean && flutter build linux --release

# 3. Verify fresh build
stat build/linux/x64/release/bundle/pin_and_paper | grep Modify

# 4. Launch
./build/linux/x64/release/bundle/pin_and_paper
```

### Quick Relaunch (No Code Changes)

```bash
cd /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper
./build/linux/x64/release/bundle/pin_and_paper
```

---

## CI/CD Notes

For automated builds:

```bash
#!/bin/bash
set -e  # Exit on error

cd /path/to/pin_and_paper
flutter clean
flutter pub get
flutter build linux --release

# Verify build succeeded
if [ ! -f "build/linux/x64/release/bundle/pin_and_paper" ]; then
    echo "Build failed: executable not found"
    exit 1
fi

echo "Build successful"
```

---

## Debug Build

For development with debug symbols and hot reload:

```bash
flutter run --debug
# or
flutter run  # Defaults to debug
```

**Note:** Debug builds are slower but provide better error messages and debugging capabilities.

---

## Key Learnings

1. **Always use `flutter clean` after code changes** to avoid cached build issues
2. **Working directory matters** - must be in the Flutter project directory (`pin_and_paper/`)
3. **Verify timestamps** to ensure the binary was actually rebuilt
4. **Relative paths work** from project directory: `./build/linux/x64/release/bundle/pin_and_paper`
5. **Flutter caches aggressively** - when in doubt, clean first

---

## Related Documents

- `docs/templates/build-and-release.md` - Release process and versioning
- `docs/templates/manual-test-plan-template.md` - Testing procedures
