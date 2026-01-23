# Phase 3.6A Tag Filtering - Manual Test Plan

**Phase:** Phase 3.6A - Tag Filtering System
**Tester:** BlueKitty
**Device:** Linux Desktop (Samsung Galaxy S22 Ultra for mobile testing)
**Build Mode:** Release (`flutter run --release`)
**Date:** _____________
**Created:** 2026-01-10

---

# Legend
- [ ] : Pending
- [X] : Completed successfully
- [0] : Failed
- [/] : Partial pass (works but has issues)
- [NA] : Not applicable

** : When appended to a line of a task, it contains notes clarifying the behavior

---

## Overview

**What This Tests:** Tag filtering system with advanced multi-select dialog and compact filter bar

**Why It Matters:** Allows users to quickly find tasks by tags using OR/AND logic, presence filters, and search. Critical for organization with large task lists.

**What Changed:**
- New filter button in AppBar (filled icon when filters active)
- ActiveFilterBar below task input (shows active filters with tag chips)
- TagFilterDialog with multi-select, search, AND/OR toggle
- Tag presence filters (Any/Tagged/Untagged)
- Optimized performance (single query for tag counts, operation ID pattern)

---

## Pre-Test Setup

- [X] **Clean build completed**
  ```bash
  cd pin_and_paper
  flutter clean
  flutter build linux --release
  ```

- [X] **Run app in release mode**
  ```bash
  ./build/linux/x64/release/bundle/pin_and_paper
  ```

- [X] **App version verified**
  - Expected version: **3.6.0+4**
  - Check in Settings > About

- [X] **Test data prepared**
  - Create at least 5 tags with different colors
  - Create at least 10 tasks (mix of tagged/untagged)
  - Some tasks should have multiple tags
  - Some tasks should have no tags

---

## Test 1: Filter Button Visual & Interaction

**Objective:** Verify filter button appears correctly and shows proper state

### 1.1 Filter Button Appearance
- [X] Filter button visible in AppBar (top right area)
- [X] Icon is `filter_alt_outlined` when no filters active
- [X] Icon changes to `filter_alt` (filled) when filters applied
- [X] Tooltip shows "Filter Tasks" on hover
- [X] Button has proper touch target size (min 48x48dp)

### 1.2 Filter Button States
- [X] Start with no filters - icon is outlined ✓
- [X] Apply any filter - icon becomes filled ✓
- [X] Clear filters - icon returns to outlined ✓
- [X] Icon transition is smooth (no flashing)

**Expected:**
```
Filter button should be visually distinct and clearly indicate
when filters are active vs inactive through icon style change.
```

**Actual Results:**
```
docs/images/3.6A/1.1.png (app home, no filters applied)
docs/images/3.6A/1.2.png (filter modal)


Notes:
```

---

## Test 2: TagFilterDialog - Opening & Layout

**Objective:** Verify dialog opens correctly with proper layout

### 2.1 Opening Dialog
- [X] Click filter button - dialog opens immediately
- [X] Dialog appears centered on screen
- [X] Dialog has proper elevation/shadow
- [X] Background dimmed appropriately
- [X] Dialog animation is smooth

### 2.2 Dialog Layout & Spacing
- [X] **Title:** "Filter by Tags" - clear and centered
- [X] **Search field:**
  - Label: "Search tags"
  - Has search icon (magnifying glass)
  - Proper padding around field
  - Placeholder text visible
- [X] **Presence filter buttons:**
  - Three segmented buttons: Any / Tagged / Untagged
  - Equal width, proper spacing
  - Material 3 styling applied
- [X] **AND/OR toggle:**
  - Only visible when 2+ tags selected
  - Two segments: ANY / ALL
  - Tooltip text on hover
- [X] **Tag list:**
  - Scrollable if many tags
  - Proper spacing between items
  - Not cramped or overlapping
- [X] **Action buttons:**
  - "Clear All" on left
  - Spacer in middle
  - "Cancel" and "Apply" on right
  - Proper button styling (Clear All = text, Apply = filled)

### 2.3 Visual Consistency
- [X] Colors match app theme
- [X] Fonts are consistent
- [X] Icons are properly sized
- [X] No visual glitches or clipping

**Expected:**
```
Dialog should feel polished and professional.
All elements properly aligned with adequate spacing.
Material 3 design guidelines followed.
```

**Actual Results:**
```
docs/images/3.6A/2.1.png

Notes:
```
- When filtering by multiple tags, once a second tag is selected and ALL is also selected, the modal should display the number of results. If selecting Work and Personal and ALL would yield not matches, the user should be able to see that fact before applying the filters. This would require dynamic response. 
- I'm actually not sure we need the tagged/untagged options? We at LEAST need a tooltip to explain the logic and how to use them because even I am baffled. 
- It is scrollable if many tags, however we need a tiny visual somewhere to show that it is scrollable (little arrows or a light/minimal scrollbar - SOMETHING)
---

## Test 3: Tag Display in Dialog

**Objective:** Verify tags are displayed correctly with colors and counts

### 3.1 Tag List Items
- [X] **Tag name:** Clear and readable
- [X] **Tag color circle:**
  - 24x24dp size
  - Perfect circle shape
  - Color matches tag's hex color
  - If tag has no color, shows grey (#9E9E9E)
- [X] **Task count:**
  - Shows "X tasks" below tag name
  - Count loads immediately (no "..." after initial load)
  - Count is accurate for current view (active tasks)
- [/] **Checkbox:**
  - Clear checked/unchecked states
  - Proper alignment with tag info

### 3.2 Tag Colors Visual Test
- [X] Create tags with various colors (red, blue, green, purple, etc.)
- [X] Verify each color displays correctly in dialog
- [X] Colors are vibrant and distinguishable
- [X] No color parsing errors (check console)

### 3.3 Empty States
- [ ] **No tags exist:**
  - Shows "No tags yet" icon (label_off)
  - Message: "No tags yet"
  - Guidance: "Create tags in Tag Management"
  - Icon and text properly styled
- [/] **Search returns no results:**
  - Shows "No results" icon (search_off)
  - Message: "No tags match '[query]'"
  - Clear indication of what to do (see notes below for suggestion)

**Expected:**
```
Tags should be visually appealing with clear color indicators.
Counts should load instantly (preloaded optimization).
Empty states should be helpful, not confusing.
```

**Actual Results:**
```
(Screenshots of tag list, color variety, empty states)
docs/images/3.6A/3.3.png

Notes:
```
- Currently tags are alphabetically displayed. I think we should display in descending hierarchy of most used. 
- I don't think it's possible to have a task without a color? 
- For desktop, the space between the task and the checkbox can be wide. We should perhaps have a rounded cornered bounding box around each selected task so it's more visually clear? 
- We should have a "clear text" button somewhere near the search box once text is entered. If the user enters a bunch of text and no tags match, they shouldn't have to backspace the entire thing character by character but should easily be able to clear it. 
---

## Test 4: Search Functionality

**Objective:** Verify search works smoothly and preserves selection state

### 4.1 Search Behavior
- [x] Type in search field - list filters immediately
- [X] Search is case-insensitive
- [X] Partial matches work (e.g., "wo" finds "work")
- [X] Clear search - full list returns
- [X] Search updates as you type (no lag)

### 4.2 Selection Preservation
- [X] Select 2 tags (e.g., "work", "urgent")
- [X] Type search query that hides one of them
- [/] Verify selected tags remain selected (chips visible in filter state)
- [X] Clear search - both tags still selected ✓
- [X] Selection state is not lost during search

### 4.3 Search Visual Feedback
- [X] Matching tags remain visible
- [X] Non-matching tags disappear smoothly
- [X] No jarring transitions
- [X] Empty state shows if no matches

**Expected:**
```
Search should be instant and smooth.
Selected tags should never be lost due to search.
User can confidently search while building filter.
```

**Actual Results:**
```
(Test with screenshots)

Notes:
```
- 4.2: while searching for "w" for work, other tags are not displayed, but they ARE selected. OH! This is what we should do! When a tag is selected, maybe it should display in a section near the top like a little  banner, the way they are actually displayed while selected in the actual task list filtered view? Idk. Or not. Thoughts? 
---

## Test 5: Tag Selection & Checkboxes

**Objective:** Verify tag selection works correctly with proper visual feedback

### 5.1 Checkbox Interactions
- [X] Tap checkbox - tag becomes selected
- [X] Checkbox shows filled state
- [X] Tap again - tag becomes deselected
- [X] Checkbox shows empty state
- [NA] **Haptic feedback:** Light tap vibration on each toggle
- [X] Transitions are smooth (no delay)

### 5.2 Multiple Selection
- [X] Select first tag - checkbox checked ✓
- [X] Select second tag - both checked ✓
- [/] AND/OR toggle appears when 2+ selected ✓
- [X] Select third tag - all three checked ✓
- [X] Deselect one - remains in multi-select mode
- [0] Deselect all - AND/OR toggle disappears

### 5.3 Disabled State
- [X] Select "Untagged" presence filter
- [X] Verify all tag checkboxes become disabled
- [X] Disabled checkboxes have greyed-out appearance
- [X] Tapping disabled checkbox does nothing
- [X] All previous selections are cleared
- [X] Switch back to "Any" - checkboxes re-enabled

**Expected:**
```
Checkbox interactions should feel responsive with haptic feedback.
Disabled state should be visually obvious.
Conflicts prevented (can't select tags if "Untagged" chosen).
```

**Actual Results:**
```
(Test checkboxes, disabled states)

Notes:
```
- No haptic testing, working on linux build. 
- 5.2, the wording is "ANY" and "ALL" not "AND" and "OR" but yes. I prefer it the way it is in the current build anyway. 
- 5.2 deselect all - the toggle disappears when all EXCEPT one task are deselected. This is expected and desired behavior however. Test was worded improperly. 
- 5.3 - I think we shouldn't show these exactly as radio buttons. There should be a button that says "Show only untagged tasks". And it should PROBABLY be displayed a different way, say, as a dropdown option from tapping the filter option. 
---

## Test 6: Presence Filter Buttons

**Objective:** Verify presence filter segmented buttons work correctly

### 6.1 Button Appearance & States
- [X] Three buttons: Any, Tagged, Untagged
- [X] "Any" selected by default
- [X] Selected button has distinct appearance (filled/highlighted)
- [X] Unselected buttons are clearly different
- [X] Button labels are clear and concise

### 6.2 Switching Presence Filters
- [X] Click "Tagged" - button becomes selected
- [X] "Any" becomes unselected
- [X] Click "Untagged" - button becomes selected
- [X] Previous selection clears
- [X] Only one can be selected at a time (mutually exclusive)

### 6.3 Interaction with Tag Selection
- [X] Select some tags with "Any" active - works ✓
- [X] Switch to "Tagged" - tags remain selected ✓
- [X] Switch to "Untagged":
  - All tag selections clear
  - Tag checkboxes become disabled
  - Cannot select new tags
- [X] Switch back to "Any":
  - Tag checkboxes re-enabled
  - Can select tags again

**Expected:**
```
Presence filters should be immediately understandable.
Mutual exclusivity clearly enforced.
"Untagged" prevents contradictory tag selection.
```

**Actual Results:**
```
(Screenshots of each state)

Notes:
```
- Switching from untagged back to any or tagged when having had some checkboxes selected before switching to untagged in the first place should REENABLE the previously checked boxes. A user playing around with the "untagged" option wouldn't want to have to go through and pick all their selections again if they accidentally clicked untagged. 

---

## Test 7: AND/OR Logic Toggle

**Objective:** Verify AND/OR toggle appears/works correctly

### 7.1 Visibility Conditions
- [X] Start with 0 tags selected - toggle hidden ✓
- [X] Select 1 tag - toggle still hidden ✓
- [X] Select 2nd tag - toggle appears ✓
- [X] Deselect down to 1 tag - toggle disappears ✓
- [X] Transition is smooth (no jarring layout shift)

### 7.2 Toggle Appearance
- [X] Two segments: "ANY" and "ALL"
- [X] "ANY" selected by default (OR logic)
- [X] Labels are clear and understandable
- [X] Tooltips explain behavior:
  - ANY: "Show tasks with ANY selected tag"
  - ALL: "Show tasks with ALL selected tags"

### 7.3 Switching Logic
- [X] Click "ALL" - becomes selected
- [X] "ANY" becomes unselected
- [X] Click "ANY" - switches back
- [X] Selection state preserved when dialog closes/reopens

**Expected:**
```
Toggle should only appear when relevant (2+ tags).
Labels "ANY"/"ALL" should be intuitive.
Tooltips provide clarity for users unsure of difference.
```

**Actual Results:**
```
(Screenshots showing toggle appearance/disappearance)

Notes:
```

---

## Test 8: Dialog Actions (Clear All, Cancel, Apply)

**Objective:** Verify all dialog buttons work correctly

### 8.1 Clear All Button
- [ ] Click "Clear All":
  - All tag selections cleared ✓
  - Presence filter returns to "Any" ✓
  - AND/OR toggle disappears (if shown) ✓
  - Dialog closes ✓
  - **Haptic feedback:** Medium impact ✓
- [ ] Filter bar disappears (no filters active) ✓
- [ ] Filter button returns to outlined icon ✓

### 8.2 Cancel Button
- [ ] Make some selections in dialog
- [ ] Click "Cancel"
- [ ] Dialog closes without applying changes ✓
- [ ] Previous filter state unchanged ✓
- [ ] No visual glitches on close

### 8.3 Apply Button
- [ ] Select tags/filters in dialog
- [ ] Click "Apply":
  - Dialog closes ✓
  - **Haptic feedback:** Medium impact ✓
  - Filter bar appears with selected tags ✓
  - Task list updates to show filtered results ✓
  - Filter button shows filled icon ✓

### 8.4 Button Visual States
- [ ] All buttons have proper touch targets
- [ ] Buttons show pressed state on tap
- [ ] "Apply" is filled button (primary action)
- [ ] "Cancel" is text button (secondary)
- [ ] "Clear All" is text button (destructive-ish)

**Expected:**
```
Buttons should provide clear feedback and proper haptic response.
"Apply" should feel like the primary action.
"Clear All" should be easy to access but not accidental.
```

**Actual Results:**
```
(Test all button interactions)

Notes:
```

---

## Test 9: ActiveFilterBar Appearance

**Objective:** Verify filter bar displays correctly with tag chips

### 9.1 Filter Bar Visibility
- [ ] No filters active - bar hidden (height 0) ✓
- [ ] Apply filter - bar appears below task input ✓
- [ ] Clear filter - bar disappears ✓
- [ ] Transition is smooth (animated)

### 9.2 Filter Bar Layout
- [ ] **Height:** 56dp (adequate but not excessive)
- [ ] **Background:** surfaceContainerHighest color
- [ ] **Shadow:** Subtle shadow below bar (elevation)
- [ ] **Padding:** 16dp horizontal, 8dp vertical
- [ ] Not cramped or crowded

### 9.3 Tag Chips Display
- [ ] **Tag chip appearance:**
  - Tag name displayed clearly
  - Background color = tag color with 20% opacity
  - Border color = tag color (solid)
  - Delete icon (X) on right side
  - Proper padding inside chip
- [ ] **Multiple tags:**
  - Chips displayed in horizontal row
  - 8dp spacing between chips
  - Scrollable if many tags (doesn't wrap)
- [ ] **Color parsing:**
  - Hex colors (#FF5722) render correctly
  - Default grey for null/invalid colors
  - Colors are distinguishable

### 9.4 Additional Indicators
- [ ] **Presence filter chip** (if not "Any"):
  - Shows "Has tags" for onlyTagged
  - Shows "No tags" for onlyUntagged
  - Secondary container color (different from tag chips)
- [ ] **Logic indicator** (if 2+ tags):
  - Shows "ALL" or "ANY" badge
  - Tertiary container color
  - Bold text, small size (12sp)
  - Rounded corners (12dp radius)

### 9.5 Clear All Button (Pinned)
- [ ] "Clear All" button on far right
- [ ] Does NOT scroll with chips (pinned)
- [ ] Always visible even with many tags
- [ ] Proper spacing from chips (8dp)

**Expected:**
```
Filter bar should be compact but informative.
Tag chips should be visually appealing with proper colors.
Layout should handle 1-10+ tags gracefully.
"Clear All" should never scroll offscreen.
```

**Actual Results:**
```
(Screenshots with 1 tag, 3 tags, 7+ tags)

Notes:
```

---

## Test 10: Filter Bar Interactions

**Objective:** Verify interactions in filter bar work correctly

### 10.1 Removing Individual Tags
- [ ] Apply filter with multiple tags
- [ ] Click X on first tag chip
- [ ] Tag removed from filter ✓
- [ ] Task list updates immediately ✓
- [ ] Chip disappears smoothly
- [ ] Other chips remain ✓

### 10.2 Removing Last Tag
- [ ] Have filter with 1 tag only
- [ ] Click X on chip
- [ ] Entire filter bar disappears ✓
- [ ] Filter button returns to outlined icon ✓
- [ ] All tasks reappear ✓

### 10.3 Clear All from Filter Bar
- [ ] Apply filter with tags and/or presence filter
- [ ] Click "Clear All" button in filter bar
- [ ] **Haptic feedback:** Medium impact ✓
- [ ] All filters cleared ✓
- [ ] Filter bar disappears ✓
- [ ] Task list shows all tasks ✓

### 10.4 Horizontal Scrolling (many tags)
- [ ] Apply filter with 7+ tags
- [ ] Verify chips are scrollable horizontally
- [ ] Scroll is smooth
- [ ] "Clear All" button stays visible (pinned right)
- [ ] No chips cut off or hidden

**Expected:**
```
Removing tags should feel immediate and responsive.
Scrolling should work smoothly when many tags selected.
"Clear All" should always be accessible.
```

**Actual Results:**
```
(Test all interactions)

Notes:
```

---

## Test 11: Filtering Logic - OR Mode

**Objective:** Verify OR filtering works correctly (tasks with ANY selected tag)

### 11.1 OR Filter Setup
- [ ] Create tags: "work", "urgent", "home"
- [ ] Create tasks:
  - Task A: tagged "work"
  - Task B: tagged "urgent"
  - Task C: tagged "home"
  - Task D: tagged "work" + "urgent"
  - Task E: no tags
  - Task F: tagged "random"

### 11.2 Apply OR Filter
- [ ] Open filter dialog
- [ ] Select "work" and "urgent" tags
- [ ] Verify "ANY" is selected (OR logic)
- [ ] Click Apply

### 11.3 Verify Results
- [ ] Task A visible (has "work") ✓
- [ ] Task B visible (has "urgent") ✓
- [ ] Task C hidden (only has "home") ✓
- [ ] Task D visible (has both "work" and "urgent") ✓
- [ ] Task E hidden (no tags) ✓
- [ ] Task F hidden (has "random") ✓
- [ ] Task list updates immediately (no delay)

### 11.4 Visual Verification
- [ ] Filtered tasks clearly visible
- [ ] No visual indication tasks are "missing" (clean, not broken)
- [ ] Scroll works if needed
- [ ] Task count makes sense

**Expected:**
```
OR filter should show tasks with ANY of the selected tags.
Results should be instant and accurate.
```

**Actual Results:**
```
(Screenshot of filtered results)

Notes:
```

---

## Test 12: Filtering Logic - AND Mode

**Objective:** Verify AND filtering works correctly (tasks with ALL selected tags)

### 12.1 AND Filter Setup
- [ ] Use same tasks from Test 11
- [ ] Open filter dialog
- [ ] Select "work" and "urgent" tags
- [ ] Click "ALL" toggle (AND logic)
- [ ] Click Apply

### 12.2 Verify Results
- [ ] Task A hidden (only has "work", missing "urgent") ✓
- [ ] Task B hidden (only has "urgent", missing "work") ✓
- [ ] Task C hidden (only has "home") ✓
- [ ] Task D visible (has BOTH "work" and "urgent") ✓
- [ ] Task E hidden (no tags) ✓
- [ ] Task F hidden (has "random") ✓

### 12.3 AND with 3+ Tags
- [ ] Add "home" tag to Task D (now has work + urgent + home)
- [ ] Apply filter: work + urgent + home with ALL logic
- [ ] Verify only Task D appears ✓

**Expected:**
```
AND filter should show ONLY tasks with ALL selected tags.
More restrictive than OR (fewer results).
3+ tag AND filter should work correctly.
```

**Actual Results:**
```
(Screenshot of AND filtered results)

Notes:
```

---

## Test 13: Presence Filters - Tagged/Untagged

**Objective:** Verify presence filters work correctly

### 13.1 "Tagged" Filter
- [ ] Open filter dialog
- [ ] Select "Tagged" presence filter (do NOT select specific tags)
- [ ] Click Apply
- [ ] Verify: All tasks with at least one tag visible ✓
- [ ] Verify: All tasks with no tags hidden ✓
- [ ] Counts should be correct

### 13.2 "Tagged" + Specific Tags
- [ ] Open filter dialog
- [ ] Select "Tagged" + specific tag ("work")
- [ ] Click Apply
- [ ] Verify: Same results as just filtering by "work" tag
  - (This is expected - specific tags override presence filter)

### 13.3 "Untagged" Filter
- [ ] Open filter dialog
- [ ] Select "Untagged" presence filter
- [ ] Verify tag checkboxes are disabled ✓
- [ ] Click Apply
- [ ] Verify: ONLY tasks with no tags visible ✓
- [ ] Verify: All tagged tasks hidden ✓

### 13.4 Visual Verification
- [ ] Results make logical sense
- [ ] No "missing" tasks that should be there
- [ ] No unexpected tasks appearing

**Expected:**
```
"Tagged" should show everything categorized.
"Untagged" should show only uncategorized tasks.
Filters should work correctly with edge cases.
```

**Actual Results:**
```
(Screenshots of Tagged and Untagged results)

Notes:
```

---

## Test 14: Ghost Tag Handling

**Objective:** Verify deleted tags don't break filter bar

### 14.1 Setup Ghost Tag Scenario
- [ ] Apply filter with tag "temporary"
- [ ] Filter bar shows "temporary" chip ✓
- [ ] Go to Tag Management
- [ ] Delete "temporary" tag
- [ ] Return to home screen

### 14.2 Verify Ghost Tag Handling
- [ ] Filter bar does NOT show "temporary" chip anymore ✓
- [ ] No "Unknown tag" or error messages ✓
- [ ] Filter bar gracefully hides deleted tag ✓
- [ ] Other tags (if any) still display correctly ✓
- [ ] No console errors about missing tags

### 14.3 Self-Healing Behavior
- [ ] Open filter dialog
- [ ] Deleted tag not in list ✓
- [ ] Filter state doesn't include ghost tag ✓
- [ ] Everything works normally

**Expected:**
```
Deleted tags should disappear gracefully from UI.
No error messages or "Unknown tag" placeholders.
Self-healing UI - adapts to changed tag list.
```

**Actual Results:**
```
(Test with screenshots)

Notes:
```

---

## Test 15: Filter Persistence & Navigation

**Objective:** Verify filters persist correctly across navigation

### 15.1 Filter Persistence in Session
- [ ] Apply filter (e.g., "work" tag)
- [ ] Navigate to Settings
- [ ] Return to home screen
- [ ] Filter still active ✓
- [ ] Filter bar still showing ✓
- [ ] Filtered results unchanged ✓

### 15.2 Filter State in Dialog
- [ ] Apply filter (select multiple tags, change logic)
- [ ] Close and reopen filter dialog
- [ ] Verify all selections preserved:
  - Tag selections match ✓
  - AND/OR logic matches ✓
  - Presence filter matches ✓
- [ ] Can modify and reapply

### 15.3 Clear Filter State
- [ ] Apply complex filter
- [ ] Click "Clear All" in filter bar
- [ ] Open filter dialog
- [ ] Verify everything reset:
  - No tags selected ✓
  - Presence = "Any" ✓
  - AND/OR toggle hidden ✓

**Expected:**
```
Filter state should persist during app session.
Opening dialog should show current filter state.
Clear All should truly reset everything.
```

**Actual Results:**
```
(Test navigation and persistence)

Notes:
```

---

## Test 16: Performance - Tag Count Loading

**Objective:** Verify tag counts load instantly (no N+1 query problem)

### 16.1 Setup for Performance Test
- [ ] Create 20+ tags
- [ ] Create 50+ tasks with various tag assignments
- [ ] Close app completely
- [ ] Reopen app

### 16.2 Open Dialog - Initial Load
- [ ] Click filter button
- [ ] **Observe tag counts:**
  - Do they show "..." for each tag? (BAD)
  - Do they all load at once immediately? (GOOD)
- [ ] Time the load: Should be <100ms
- [ ] No stuttering or lag
- [ ] All counts accurate

### 16.3 Performance Metrics
- [ ] Dialog opens in <100ms ✓
- [ ] Tag counts visible within <50ms of dialog open ✓
- [ ] No progressive loading (all at once) ✓
- [ ] No frame drops during load ✓

**Expected:**
```
Tag counts should load in a SINGLE query (optimized).
All counts should appear simultaneously, not one-by-one.
No "..." loading states after initial dialog render.
Performance: <100ms total for dialog + counts.
```

**Performance Metrics:**

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Dialog open time | <100ms | ___ms | ⬜ PASS / ⬜ FAIL |
| Tag counts load | <50ms | ___ms | ⬜ PASS / ⬜ FAIL |
| Frame rate | 60fps | ___fps | ⬜ PASS / ⬜ FAIL |

**Actual Results:**
```
Notes on performance:
```

---

## Test 17: Performance - Filter Application

**Objective:** Verify filter application is fast with large datasets

### 17.1 Large Dataset Test
- [ ] Create scenario:
  - 100+ tasks
  - 10+ tags
  - Mix of tagged/untagged tasks
- [ ] Apply filter with 3 tags (OR logic)
- [ ] Time the filter application
- [ ] Should be <100ms

### 17.2 Rapid Filter Changes
- [ ] Apply filter 1 (tag "work")
- [ ] Immediately change to filter 2 (tag "urgent")
- [ ] Immediately change to filter 3 (tag "home")
- [ ] Verify:
  - No race conditions ✓
  - Final result matches last filter ✓
  - No stale data shown ✓
  - No crashes ✓

### 17.3 Filter + Scroll Performance
- [ ] Apply filter showing 50+ tasks
- [ ] Scroll through filtered list
- [ ] Verify smooth scrolling (60fps)
- [ ] No stuttering or frame drops

**Performance Metrics:**

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Filter apply time | <100ms | ___ms | ⬜ PASS / ⬜ FAIL |
| Scroll frame rate | 60fps | ___fps | ⬜ PASS / ⬜ FAIL |
| Memory usage | Stable | ___ | ⬜ PASS / ⬜ FAIL |

**Actual Results:**
```
Notes on performance:
```

---

## Test 18: Regression - Existing Features

**Objective:** Verify new filter feature doesn't break existing functionality

### 18.1 Task Management
- [ ] Create new task - works ✓
- [ ] Complete task - works ✓
- [ ] Delete task - works ✓
- [ ] Edit task title - works ✓
- [ ] Task input still functional ✓

### 18.2 Tag Management
- [ ] Add tags to tasks - works ✓
- [ ] Remove tags from tasks - works ✓
- [ ] Tag chips display on tasks - works ✓
- [ ] Tag colors correct - works ✓
- [ ] Tag Management screen accessible ✓

### 18.3 Navigation & Settings
- [ ] Brain Dump button works ✓
- [ ] Settings button works ✓
- [ ] Reorder mode works ✓
- [ ] Quick Complete works ✓
- [ ] All navigation smooth ✓

### 18.4 Task Display
- [ ] Task hierarchy displays correctly ✓
- [ ] Completed tasks section works ✓
- [ ] Empty state shows when appropriate ✓
- [ ] Drag and drop works (if in reorder mode) ✓

**Actual Results:**
```
Notes on any regressions found:
```

---

## Test 19: Edge Cases & Error Handling

**Objective:** Verify edge cases are handled gracefully

### 19.1 Empty/No Data Cases
- [ ] **No tags exist at all:**
  - Filter dialog shows helpful empty state ✓
  - No crashes or errors ✓
- [ ] **No tasks exist:**
  - Filter can still be opened ✓
  - Tag counts all show "0 tasks" ✓
- [ ] **All tasks completed:**
  - Filter shows counts for active tasks (0s) ✓
  - No errors ✓

### 19.2 Single Item Cases
- [ ] **Only 1 tag exists:**
  - Dialog shows single tag ✓
  - Can filter by it ✓
  - AND/OR toggle doesn't appear ✓
- [ ] **Only 1 task exists:**
  - Filter works correctly ✓
  - Task appears/disappears based on filter ✓

### 19.3 Extreme Cases
- [ ] **Many tags (50+):**
  - Dialog scrolls properly ✓
  - Search still works ✓
  - No performance issues ✓
- [ ] **Many selected tags (20+):**
  - Filter bar scrolls horizontally ✓
  - Clear All still accessible ✓
  - Apply works correctly ✓
- [ ] **Very long tag names:**
  - Don't break layout ✓
  - Ellipsize if needed ✓

**Actual Results:**
```
Notes on edge case handling:
```

---

## Test 20: Visual Quality & Polish

**Objective:** Overall visual assessment

### 20.1 Visual Consistency
- [ ] All colors match app theme
- [ ] Fonts consistent throughout
- [ ] Icon sizes appropriate
- [ ] Spacing feels balanced
- [ ] No visual glitches or artifacts

### 20.2 Accessibility
- [ ] Touch targets adequate (min 48x48dp)
- [ ] Text is readable (WCAG AA compliance)
- [ ] Color contrast sufficient
- [ ] No critical information conveyed by color alone

### 20.3 Animations & Transitions
- [ ] Dialog open/close smooth
- [ ] Filter bar appear/disappear smooth
- [ ] Chip removal smooth
- [ ] State changes not jarring
- [ ] No flashing or flickering

### 20.4 Haptic Feedback
- [ ] Light haptic on checkbox toggle ✓
- [ ] Medium haptic on Apply button ✓
- [ ] Medium haptic on Clear All button ✓
- [ ] Haptics feel appropriate (not excessive)

### 20.5 Overall Polish
- [ ] Feature feels complete and professional
- [ ] No rough edges or "unfinished" feel
- [ ] Interactions feel natural
- [ ] Visual hierarchy clear
- [ ] Information density appropriate

**Screenshots:**
```
(Attach screenshots showing overall quality)
```

**Actual Results:**
```
Notes on visual quality:
```

---

## Sign-Off

### Test Summary

**Total Test Sections:** 20
**Passed:** ___
**Failed:** ___
**Partial:** ___
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

**Issue #2:**
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

### Visual/UX Observations

```
(Note any visual polish items, color choices, spacing issues, etc.)
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

**Recommendation:**
- ⬜ **APPROVE** - Feature works as expected, ready for merge to main
- ⬜ **APPROVE WITH NOTES** - Works but has minor issues (document above)
- ⬜ **REJECT** - Critical issues found, needs rework

---

## Appendix: Quick Reference

### Build Commands

```bash
# Clean build
cd pin_and_paper
flutter clean
flutter build linux --release

# Run release mode
./build/linux/x64/release/bundle/pin_and_paper

# Check for lint issues
flutter analyze

# Run tests
flutter test --concurrency=1
```

### Test Data Suggestions

**Recommended test tags:**
- work (red #F44336)
- urgent (orange #FF9800)
- home (blue #2196F3)
- personal (purple #9C27B0)
- fitness (green #4CAF50)

**Recommended test tasks:**
- "Call dentist" - work, urgent
- "Buy groceries" - home
- "Workout" - fitness, personal
- "Email boss" - work
- "Read book" - personal
- "Untagged task 1" - no tags
- "Untagged task 2" - no tags

---

**Document Version:** 1.0
**Last Updated:** 2026-01-10
**Created By:** Claude + BlueKitty
