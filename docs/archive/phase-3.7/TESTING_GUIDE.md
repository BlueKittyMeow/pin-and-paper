# Phase 3.7 Testing Guide: Natural Language Date Parsing

## Quick Test

### 1. Run the App

```bash
cd /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper

# Option A: Release build (faster, no logging)
build/linux/x64/release/bundle/pin_and_paper

# Option B: Debug build (with logging)
flutter run -d linux
```

### 2. Test Date Parsing in Edit Task Dialog

**Steps:**
1. Launch the app
2. Create or select any task
3. Click to edit the task (opens EditTaskDialog)
4. In the **Title field**, type: `Call dentist tomorrow`
5. **Wait 300ms** (debounce delay)

**Expected Behavior:**

✅ **You should see:**
- The word "tomorrow" highlighted in light blue background
- Below the title field: `Due: Tomorrow (Thu, Jan 23)` in blue text
- When you save, the title becomes "Call dentist" (date text stripped)
- The due date field shows "Due: Jan 23, 2026"

### 3. Test Pre-Filter

**These should NOT trigger parsing** (no highlight):
- `Call mom` - no date keywords
- `Buy milk` - no date keywords
- `May need to buy groceries` - "May" alone doesn't count

**These SHOULD trigger parsing** (highlight expected):
- `Meeting tomorrow` → highlights "tomorrow"
- `Call dentist Monday` → highlights "Monday"
- `Due Jan 15` → highlights "Jan 15"
- `Meeting at 3pm` → highlights "at 3pm"
- `in 3 days` → highlights "in 3 days"

### 4. Test Date Options Sheet

**Steps:**
1. Type a task with a date (e.g., "Call dentist tomorrow")
2. **Tap on the highlighted date text** ("tomorrow")
3. A bottom sheet should appear with options:
   - Current selection (Tomorrow) with checkmark
   - Alternative: Today
   - Alternative: Next week
   - "Pick custom date..."
   - "Remove due date" (red)

### 5. Verify Initialization

Check the console output for:

```
DateParsingService initialized successfully (with warmup)
```

If you see this error instead:
```
Error initializing DateParsingService: ...
```

Then chrono.js failed to load. Check that:
- `assets/js/chrono.min.js` exists (236KB UMD bundle)
- `build/linux/x64/release/bundle/lib/libquickjs_c_bridge_plugin.so` exists

## Common Issues

### Issue: No highlighting appears

**Possible causes:**
1. **Debounce delay** - Wait 300ms after typing
2. **Pre-filter rejecting** - Check if your text has date keywords
3. **Initialization failed** - Check console for error messages
4. **Web platform** - Date parsing is disabled on web (flutter_js not available)

**Debug:**
```bash
# Run with logging to see what's happening
flutter run -d linux 2>&1 | grep -i "date\|parse\|chrono"
```

### Issue: Highlighting appears but doesn't parse correctly

**Possible causes:**
1. **chrono.js version** - Verify you're using the UMD bundle (not ESM)
2. **Today Window** - Before 4:59am, "today" means yesterday
3. **Ambiguous dates** - chrono.js might interpret differently than expected

**Debug:**
Add logging to `_parseDateFromTitle` in EditTaskDialog:
```dart
void _parseDateFromTitle(String text) {
  try {
    final parsed = _dateParser.parse(text);
    print('DEBUG: Parsed "$text" → ${parsed?.matchedText} = ${parsed?.date}');
    // ... rest of method
  }
}
```

### Issue: "Cannot open shared object file"

**Error:**
```
Failed to load dynamic library 'libquickjs_c_bridge_plugin.so'
```

**Fix:**
```bash
# Copy QuickJS library to bundle
cp ~/.pub-cache/hosted/pub.dev/flutter_js-0.8.5/linux/shared/libquickjs_c_bridge_plugin.so \
   build/linux/x64/release/bundle/lib/
```

This is a flutter_js packaging issue. You need to copy the library after each clean build.

### Issue: "SyntaxError: unsupported keyword: export"

**Error:**
```
Failed to load chrono.js: SyntaxError: unsupported keyword: export
```

**Cause:** Using ESM bundle instead of UMD

**Fix:** Rebuild chrono.min.js using the process in [CHRONO_BUILD_NOTES.md](CHRONO_BUILD_NOTES.md)

## Performance Verification

### Pre-Filter Effectiveness

The pre-filter should reduce FFI calls by 80-90%.

**Test:**
1. Type 10 tasks without dates (e.g., "Call mom", "Buy milk")
   - Expected: 0 chrono.js calls (pre-filter rejects)
2. Type 10 tasks with dates (e.g., "Call dentist tomorrow")
   - Expected: 10 chrono.js calls (pre-filter accepts)

### Debouncer Effectiveness

The debouncer should prevent rapid parsing during typing.

**Test:**
1. Type "Call dentist tomorrow" character by character
   - Expected: Only 1 parse call (after 300ms of no typing)
   - Not 23 parse calls (one per keystroke)

### Warmup Verification

**Test:**
1. Launch app (cold start)
2. Type a date immediately
3. Parse should be fast (<10ms, not 1200ms)

## Integration Checklist

- [ ] EditTaskDialog shows date highlighting
- [ ] Date preview appears below title field
- [ ] Tapping highlighted date opens DateOptionsSheet
- [ ] DateOptionsSheet shows alternatives (Today, Tomorrow, Next week)
- [ ] Manual date picker works
- [ ] "Remove due date" option works
- [ ] Saving task strips date text from title
- [ ] Due date field populated correctly
- [ ] Pre-filter prevents false positives ("May need to...")
- [ ] Web platform gracefully degrades (no errors)

## Manual Test Script

Run this sequence to verify all functionality:

```bash
# 1. Build and run
cd /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper
flutter run -d linux

# 2. In the app:
# - Create task "Buy groceries tomorrow"
#   → See "tomorrow" highlighted
#   → See "Due: Tomorrow (Thu, Jan 23)" below
#   → Save → Title becomes "Buy groceries"
#
# - Edit task, change to "Buy groceries Monday"
#   → See "Monday" highlighted
#   → Tap "Monday" → Sheet opens with alternatives
#   → Select "Today" → Date changes
#
# - Edit task, change to "Buy groceries"
#   → No highlighting (no date)
#   → Due date unchanged (manual date preserved)
#
# - Edit task, change to "May need milk tomorrow"
#   → "tomorrow" highlighted (NOT "May")
#   → Confirms pre-filter working

# 3. Verify cleanup
# - Deleted tasks should strip date text
# - Completed tasks should keep due dates
```

## Expected Log Output

```
[Maintenance] Permanently deleted N expired task(s)
DateParsingService initialized successfully (with warmup)
Dart VM service listening on http://127.0.0.1:XXXXX/
Flutter app running...
```

No errors should appear related to date parsing.

## Known Limitations

### Disambiguation of Multiple Dates

**Limitation:** When a task title contains multiple date expressions (e.g., "tomorrow or Monday"), only the **first date** is recognized and parsed.

**Examples:**
- `"Call dentist tomorrow or Monday"` → Parses "tomorrow" only
- `"Meeting at 3pm or 5pm"` → Parses "3pm" only
- `"Due Jan 15 or Jan 20"` → Parses "Jan 15" only

**Rationale:**
This is expected behavior from the underlying chrono.js library, which returns the first match found when parsing. The library is designed for simple, unambiguous date extraction rather than complex scheduling logic.

**Workaround:**
Users should create separate tasks for each date option, or manually edit the due date after parsing to select the preferred alternative.

**Future Enhancement:**
A future phase could add:
- Detection of multiple date matches
- Prompt user to select which date to use
- Or create multiple tasks automatically

For now, this limitation is acceptable as it covers the common case (single date per task) and doesn't break functionality.
