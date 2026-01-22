# Natural Language Date Parsing Manual Test Plan

**Phase:** Phase 3.7 - Natural Language Date Parsing
**Tester:** BlueKitty
**Device:** Linux Desktop (x64)
**Build Mode:** Release (`build/linux/x64/release/bundle/pin_and_paper`)
**Date:** _____________
**Created:** 2026-01-20

---

# Legend
- [ ] : Pending
- [X] : Completed successfully
- [0] : Failed
- [/] : Neither successful nor failure
- [?] : Test instructions unclear
- [NA] : Not applicable

** : When appended to a line of a task, it contains my notes clarifying the behavior

---

## Overview

**What This Tests:** Natural language date parsing in EditTaskDialog with inline highlighting, date preview, and date options sheet.

**Why It Matters:** Allows users to type dates naturally ("tomorrow", "Monday at 5pm") instead of clicking through date pickers, significantly improving task creation speed and UX.

**What Changed:**
- EditTaskDialog title field now uses HighlightedTextEditingController
- Date phrases are highlighted in light blue during typing (300ms debounce)
- Date preview appears below title field showing parsed date/time
- Tapping highlighted text opens DateOptionsSheet with alternatives
- Date text is automatically stripped from title when task is saved
- Pre-filter reduces unnecessary parsing by 80-90%

---

## Pre-Test Setup

- [ ] **Build completed and QuickJS library copied**
  ```bash
  cd /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper
  flutter build linux --release
  cp ~/.pub-cache/hosted/pub.dev/flutter_js-0.8.5/linux/shared/libquickjs_c_bridge_plugin.so \
     build/linux/x64/release/bundle/lib/
  ```

- [ ] **Check initialization log**
  ```bash
  build/linux/x64/release/bundle/pin_and_paper 2>&1 | grep -i "DateParsing\|initialized"
  ```
  - Should see: `DateParsingService initialized successfully (with warmup)`
  - No errors related to chrono.js or QuickJS

- [ ] **Fresh app state** (optional)
  - Clean slate for testing, or use existing tasks

---

## Test 1: Basic Date Highlighting & Preview

**Objective:** Verify that date phrases are visually highlighted and preview text appears.

### 1.1 Open EditTaskDialog
- [X] Launch app
- [X] Long-press any existing task (or create new task first)
- [ ] Tap "Edit" from context menu
- [X] EditTaskDialog opens with title field focused

### 1.2 Type Simple Relative Dates
- [X] Type: `Call dentist tomorrow`
- [X] Wait 300ms (debounce)
- [X] **VERIFY:** Word "tomorrow" has light blue background highlight
- [X] **VERIFY:** Below title field shows: `Due: Tomorrow (Wed, Jan 21)` in blue text
- [X] Clear field, type: `Meeting today`
- [X] **VERIFY:** "today" highlighted
- [X] **VERIFY:** Preview shows: `Due: Today (Tue, Jan 20)`

### 1.3 Type Day Names
- [X] Type: `Dinner with Alex Monday`
- [X] **VERIFY:** "Monday" highlighted
- [X] **VERIFY:** Preview shows: `Due: Monday (Mon, Jan 26)` (next Monday)
- [X] Clear field, type: `Friday presentation`
- [X] **VERIFY:** "Friday" highlighted

### 1.4 Type Dates with Time
- [X] Type: `Team standup at 10am`
- [X] **VERIFY:** "at 10am" highlighted
- [0] **VERIFY:** Preview shows date AND time: `Due: Today (Tue, Jan 21) at 10:00 AM`
Text shows 3:00pm, while date/time pill shows 10:00. 10:00 has already happened today so that IS an impossible, or at least overdue tiime, but it's v ery unclear why the time is being parsed as 3:00pm in the text below the box (another utc issue?)
Screenshot: docs/images/phase-3/3.7/1.4.png
- [X] Clear field, type: `Dentist Monday at 3:30pm`
- [X] **VERIFY:** "Monday at 3:30pm" highlighted
- [0] **VERIFY:** Preview shows: `Due: Monday (Mon, Jan 27) at 3:30 PM`

Incorrect - blue text shows 8:30pm while the clock pill correctly shows 15:30pm (24 hour equivalent to 3:30pm)

**Expected Visual:**
```
┌─────────────────────────────────────┐
│ Title                               │
│ ┌─────────────────────────────────┐ │
│ │ Dentist Monday at 3:30pm        │ │
│ │         ^^^^^^^^^^^^^ (blue bg) │ │
│ └─────────────────────────────────┘ │
│ Due: Monday (Mon, Jan 27) at 3:30 PM│ ← Blue preview text
│     (tap to change)                 │
└─────────────────────────────────────┘
```

**Actual Results:**
```
(Paste screenshot or describe appearance)

Notes:
- Highlight color visible?
- Preview text readable?
- Layout looks correct?
```

---

## Test 2: DateOptionsSheet Interaction

**Objective:** Verify tapping highlighted date opens options sheet with alternatives.

docs/images/phase-3/3.7/2.1.png

Popup does appear but it is pinned to the bottom and oddly cut off (see screenshot above)

### 2.1 Open DateOptionsSheet
- [X] Type: `Buy groceries tomorrow`
- [X] Wait for "tomorrow" to be highlighted
- [X] **TAP** on the highlighted "tomorrow" text
- [X] DateOptionsSheet appears as bottom sheet

### 2.2 Verify Options Content
- [/] **VERIFY:** Sheet title shows "Due Date"
Text shows "Due Date Options"
- [X] **VERIFY:** "Tomorrow" option has checkmark (selected)
- [X] **VERIFY:** "Today" appears as alternative (no checkmark)
- [X] **VERIFY:** "Next week" appears as alternative
- [X] **VERIFY:** "Pick custom date..." appears
- [X] **VERIFY:** "Remove due date" appears in red at bottom

### 2.3 Test Selecting Alternative
- [X] Tap "Today" alternative
- [X] Sheet closes
- [0] **VERIFY:** Highlight moves to show "today" would be recognized
Text does NOT update, still says "tomorrow"

docs/images/phase-3/3.7/2.3.png

- [X] **VERIFY:** Preview updates to show today's date
- [X] **VERIFY:** Due date field shows today's date

### 2.4 Test Manual Date Picker
- [X] Re-open sheet (tap highlighted text again)
- [X] Tap "Pick custom date..."
- [X] Calendar picker appears
- [X] Select a date (e.g., Feb 1)
- [X] **VERIFY:** Due date updates to selected date
- [/] **VERIFY:** Highlight remains (or disappears - document behavior)

Highlight remains and text does NOT change

docs/images/phase-3/3.7/2.4.png

### 2.5 Test Remove Due Date
- [X] Re-open sheet
- [X] Tap "Remove due date" (red option)
- [0] **VERIFY:** Due date field clears
- [X] **VERIFY:** Highlight disappears
- [X] **VERIFY:** Preview text disappears



**Expected:**
```
DateOptionsSheet should:
- Appear smoothly from bottom
- Show current selection with checkmark
- Show 2-3 smart alternatives
- Manual picker and remove options always present
- Close when option selected
```

**Actual Results:**
```
(Describe UX, note any visual issues)

Notes:
```
Due date remains as Feb 1, 2026 (see screenshot: docs/images/phase-3/3.7/2.5.png)

Also! Once I have done the "remove date" from the popup, now NOTHING that I type for nat lang gets parsed. Typing "tomorrow" or anything similar does NOTHING. 
---

## Test 3: Date Text Stripping on Save

**Objective:** Verify date text is removed from title when task is saved.

### 3.1 Save Task with Parsed Date
- [X] Type: `Call dentist tomorrow`
- [X] Wait for parsing (highlight appears)
- [X] Tap "Save" button
- [X] Task list refreshes

### 3.2 Verify Title and Due Date
- [X] Find the saved task in list
- [X] **VERIFY:** Title shows: `Call dentist` (NOT "Call dentist tomorrow")
- [X] **VERIFY:** Due date badge/chip shows tomorrow's date
- [X] Long-press task, tap "Edit"
- [X] **VERIFY:** Title field shows: `Call dentist` (date text stripped)
- [X] **VERIFY:** Due date field shows tomorrow's date

### 3.3 Test with Multiple Words Stripped
- [0] Create new task, type: `Meeting at 3pm on Monday` 

This DOES NOT WORK on creating a new task in the "Add a task" bar at the top. It SHOULD and MUST, but does not right now. 

I followed the rest of this test in an Edit Task window. 

- [X] Wait for parsing
- [X] **VERIFY:** "at 3pm on Monday" highlighted
- [X] Save task
- [X] **VERIFY:** Title becomes: `Meeting` (all date text removed)
- [X] **VERIFY:** Due date shows Monday at 3:00 PM

**Why This Matters:**
Users shouldn't have redundant information (date in both title AND due date field). Clean titles improve readability in task list.

**Actual Results:**
```
(Check several examples, note any cases where stripping fails)

Notes:
```

---

## Test 4: Pre-Filter False Positive Prevention

**Objective:** Verify pre-filter prevents incorrect date detection.

### 4.1 Test Month Names Without Day
- [X] Type: `May need to buy milk`
- [X] Wait 300ms
- [X] **VERIFY:** NO highlighting (month "May" alone doesn't trigger)
- [X] Clear field, type: `March forward with the project`
- [X] **VERIFY:** NO highlighting ("March" verb, not date)
- [X] Clear field, type: `Meet with April` (person's name)
- [X] **VERIFY:** NO highlighting

### 4.2 Test Month Names WITH Day (Should Parse)
- [X] Type: `Meeting May 15`
- [X] **VERIFY:** "May 15" IS highlighted
- [X] Clear field, type: `Due Jan 30`
- [X] **VERIFY:** "Jan 30" IS highlighted

### 4.3 Test Non-Date Words
- [X] Type: `Call mom`
- [X] **VERIFY:** NO highlighting (no date-like words)
- [X] Type: `Buy milk`
- [X] **VERIFY:** NO highlighting
- [X] Type: `Read book`
- [X] **VERIFY:** NO highlighting

**Expected:**
```
Pre-filter should:
✓ Allow: "tomorrow", "Monday", "at 3pm", "Jan 15"
✗ Block: "May need", "March forward", "Call mom"
```

**Actual Results:**
```
(Document any false positives or false negatives)

Notes:
```

---

## Test 5: Timezone Handling (Critical Fix)

**Objective:** Verify time parsing displays correct local time (not UTC).

### 5.1 Test Morning Time
- [X] Type: `Meeting at 9am`
- [0] **VERIFY:** Preview shows: `at 9:00 AM` (NOT 14:00 or other UTC hour)
Shows 2:00pm in preview text. 
- [X] Save task, re-edit
- [X] **VERIFY:** Due time field shows: `9:00 AM`

It is only the preview text that is being calculated incorrectly

### 5.2 Test Afternoon Time
- [ ] Type: `Dentist at 2:30pm`
- [ ] **VERIFY:** Preview shows: `at 2:30 PM`
- [ ] Save task, re-edit
- [ ] **VERIFY:** Due time shows: `2:30 PM` (NOT 19:30/7:30 PM)

### 5.3 Test Evening Time
- [ ] Type: `Dinner Monday at 5:30pm`
- [ ] **VERIFY:** Preview shows: `at 5:30 PM`
- [ ] **VERIFY:** When saved, time field shows: `5:30 PM` (NOT 22:30/10:30 PM)

**Why This Matters:**
This was a critical bug fix. chrono.js returns UTC times, and we must convert to local timezone before displaying. Failure here means times display incorrectly to users.

**Actual Results:**
```
(Test multiple times, verify NONE show UTC offsets)

Notes:
```

---

## Test 6: Disambiguation Limitation

**Objective:** Document behavior when multiple dates are present.

### 6.1 Test "Or" Syntax
- [ ] Type: `Meeting tomorrow or Monday`
- [ ] **VERIFY:** Only "tomorrow" is highlighted (first date)
- [ ] **VERIFY:** Preview shows tomorrow's date
- [ ] **NOTE:** This is expected behavior (chrono.js limitation)

### 6.2 Test Multiple Times
- [ ] Type: `Call at 3pm or 5pm`
- [ ] **VERIFY:** Only "at 3pm" highlighted
- [ ] **NOTE:** User must manually adjust if they want 5pm

**Expected:**
```
Only first date is parsed - this is documented in TESTING_GUIDE.md
as a known limitation.
```

**Actual Results:**
```
Notes:
```

---

## Performance Testing

### Test 7: Debouncer Responsiveness

**Objective:** Verify parsing doesn't lag during typing.

**Steps:**

1. **Test Rapid Typing**
   - [ ] Type quickly: `Meeting tomorrow at 3pm`
   - [ ] **VERIFY:** No highlighting appears until 300ms after LAST keystroke
   - [ ] **VERIFY:** App doesn't freeze or stutter during typing
   - [ ] **VERIFY:** Highlight appears smoothly after pause

2. **Test Deletion**
   - [ ] With highlighted text, press backspace rapidly
   - [ ] **VERIFY:** Highlight disappears as text is deleted
   - [ ] **VERIFY:** No lag or visual glitches

**Expected Results:**

- [ ] **Typing feels smooth** (no visible lag)
- [ ] **Highlight appears after pause** (~300ms)
- [ ] **No frame drops** during normal typing

**Actual Results:**
```
Notes on responsiveness:
```

---

## Regression Testing

### Test 8: Existing Features Still Work

**Objective:** Verify date parsing doesn't break normal task editing.

**Checklist:**

- [ ] **Manual date picker still works**
  - [ ] Tap "Due date" field (NOT highlighted text)
  - [ ] Calendar picker opens normally
  - [ ] Can select date, time works
  - [ ] Saved correctly

- [ ] **Editing tasks without dates**
  - [ ] Create task with no date keywords: "Buy milk"
  - [ ] No highlighting (correct)
  - [ ] Save, edit, works normally
  - [ ] Can manually add due date

- [ ] **Clearing fields**
  - [ ] Type date, let it parse
  - [ ] Clear entire title field
  - [ ] **VERIFY:** Highlight disappears
  - [ ] **VERIFY:** Preview disappears
  - [ ] No errors in console

- [ ] **Canceling edit**
  - [ ] Type and parse a date
  - [ ] Tap "Cancel" button
  - [ ] **VERIFY:** Dialog closes
  - [ ] **VERIFY:** No changes saved

**Actual Results:**
```
Notes on any regressions:
```

---

## Edge Cases & Error Handling

### Test 9: Boundary Conditions

**Checklist:**

- [ ] **Very long titles**
  - [ ] Type 200+ character title with "tomorrow" at end
  - [ ] **VERIFY:** Highlight works
  - [ ] **VERIFY:** No text overflow issues

- [ ] **Special characters**
  - [ ] Type: `Meeting @3pm #important`
  - [ ] **VERIFY:** Parses "3pm" (or doesn't - document)
  - [ ] No crashes

- [ ] **Unicode/emoji**
  - [ ] Type: `Lunch 🍕 tomorrow`
  - [ ] **VERIFY:** "tomorrow" still highlighted
  - [ ] No crashes

- [ ] **Empty date edge cases**
  - [ ] Type just: `tomorrow` (nothing else)
  - [ ] **VERIFY:** Parses, but title becomes empty after stripping
  - [ ] **VERIFY:** App handles gracefully (reject or allow - document)

- [ ] **Past dates**
  - [ ] Type: `Yesterday meeting` (past date)
  - [ ] **VERIFY:** Parses as yesterday (or doesn't - document)
  - [ ] Behavior consistent with expectations

**Actual Results:**
```
Notes on edge cases:
```

---

## Visual Verification Checklist

### UI/UX Quality

- [ ] **Visual consistency**
  - [ ] Highlight color matches app theme
  - [ ] Preview text color is blue/accent color
  - [ ] "(tap to change)" hint is subtle gray

- [ ] **Text readability**
  - [ ] Highlighted text still readable (contrast OK)
  - [ ] Preview text size appropriate
  - [ ] No text cutoff or overflow

- [ ] **Layout spacing**
  - [ ] Preview text positioned correctly below title
  - [ ] No overlap with other fields
  - [ ] Spacing looks professional

- [ ] **Touch targets**
  - [ ] Highlighted text is tappable (easy to tap)
  - [ ] DateOptionsSheet options have good spacing
  - [ ] No accidental taps

- [ ] **Animation smoothness**
  - [ ] Highlight appears smoothly (no flash)
  - [ ] DateOptionsSheet slides in smoothly
  - [ ] No jank or stuttering

**Screenshots:**
(Attach screenshots showing:)
- [ ] Highlighted text in title field
- [ ] Date preview below title
- [ ] DateOptionsSheet open
- [ ] Task list with stripped titles

---

## Sign-Off

### Test Summary

**Total Tests:** 9 major test areas
**Passed:** ___
**Failed:** ___
**Skipped:** ___

**Overall Status:** ⬜ APPROVED | ⬜ NEEDS FIXES | ⬜ BLOCKED

---

### Critical Issues Found

**Issue #1:**
```
Description:
Severity: ⬜ CRITICAL | ⬜ HIGH | ⬜ MEDIUM | ⬜ LOW
Steps to reproduce:
Expected:
Actual:
```

---

### Minor Issues / Observations

```
(List any minor UX issues, suggestions, or observations)
```

---

### Performance Notes

```
(Any performance observations beyond dedicated performance tests)
```

---

### Tester Notes

```
Overall impression:

Confidence in feature:

Recommendation:
```

---

### Final Sign-Off

**Tester:** BlueKitty
**Date:** _____________
**Signature:** _____________

**Recommendation:**
- ⬜ **APPROVE** - Feature works as expected, ready for release
- ⬜ **APPROVE WITH NOTES** - Works but has minor issues (document above)
- ⬜ **REJECT** - Critical issues found, needs rework

---

## Appendix: Quick Reference

### Build Commands

```bash
# Build release (Linux)
cd /home/bluekitty/Documents/Git/pin-and-paper/pin_and_paper
flutter build linux --release

# Copy QuickJS library (required after each build)
cp ~/.pub-cache/hosted/pub.dev/flutter_js-0.8.5/linux/shared/libquickjs_c_bridge_plugin.so \
   build/linux/x64/release/bundle/lib/

# Run release build
build/linux/x64/release/bundle/pin_and_paper

# Check for initialization message
build/linux/x64/release/bundle/pin_and_paper 2>&1 | grep -i "initialized"
```

### Expected Log Output

```
DateParsingService initialized successfully (with warmup)
```

### Test Data Examples

```
Good test phrases:
- "Call dentist tomorrow"
- "Meeting Monday at 3pm"
- "Dinner at 5:30pm"
- "Due Jan 30"
- "in 3 days"

False positive prevention:
- "May need to buy milk" → NO highlight
- "March forward" → NO highlight
- "Call mom" → NO highlight
```

---

**Document Version:** 1.0
**Last Updated:** 2026-01-20
**Created By:** Claude (Anthropic AI)
