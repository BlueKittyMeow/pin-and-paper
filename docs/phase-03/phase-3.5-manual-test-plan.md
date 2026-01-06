# Phase 3.5 Manual Test Plan

**Phase:** 3.5 - Comprehensive Tagging System
**Created:** 2026-01-05
**Purpose:** Manual UI testing checklist for tag functionality
**Device:** Samsung Galaxy S22 Ultra

---

# Legend
- [ ] : Pending
- [X] : Completed successfully
- [0] : Failed
- [/] : Neither successful nor failure
- [NA] : Not applicable

** : When appended to a line of a task, it contains my notes clarifying the behavior

---

## Pre-Test Setup

- [X] Build and install latest version: `flutter run --release`
- [X] Ensure you have at least 5-10 tasks in the app
- [X] Clear any existing tags (fresh start)

---

## Test 1: Tag Creation

### 1.1 Create Tag from Task Editor
- [X] Open any task (tap to edit)
- [X] Tap the "Tags" section
- [X] Tag picker dialog opens
- [0] Tap "+ Create New Tag" button *No create new tag button. There is the search box, "Search or create tag" - after typing something, the "create new tag: "foo" appears with the text typed*
- [/] Create tag dialog appears with:
  - [0] Tag name field (auto-focused)
  - [0] Color picker with 12 preset colors
  - [/] Save/Cancel buttons *Cancel and Done from the main Manage Tags modal*
- [X] Type tag name: "Work"
- [X] Select blue color *Lots of blue colors, I went with dark blue. We need to change the middle two blue colors, they display far too similarly. The dark blue and cyan are fine though. Must tap "Select" here to change color*
- [/] Tap "Save" *Tapping select (see above for color selection) actually creates the tag*
- [X] Tag appears in tag picker list
- [X] "Work" tag is now selected (checkmark visible)
- [X] Tap "Done" to close picker
- [X] Task editor shows "Work" tag chip with blue color

**Expected:** Tag creation is smooth, color picker is visible, tag appears immediately

### 1.2 Create Multiple Tags
- [X] Create 5 more tags with different colors:
  - "Personal" (purple)
  - "Urgent" (red)
  - "Learning" (green)
  - "Ideas" (orange)
  - "Someday" (teal)

**Expected:** All tags created successfully with correct colors

---

## Test 2: Tag Picker UI

### 2.1 Search Functionality
- [X] Open tag picker on any task
- [X] Type "wo" in search field
- [X] Only "Work" tag appears in filtered list
- [X] Clear search
- [X] All tags reappear

**Expected:** Search filters tags immediately, case-insensitive

### 2.2 Tag Selection
- [X] Select "Work" tag (checkmark appears)
- [X] Select "Urgent" tag (checkmark appears)
- [X] Deselect "Work" tag (checkmark disappears)
- [X] Only "Urgent" remains selected
- [X] Tap "Done"
- [/] Task editor shows only "Urgent" tag chip *Task editor (from long pressing and choosing edit modal) only allows editing the title. The list of tasks does show the Urgent tag chip though*

**Expected:** Multi-select works, visual feedback is clear

### 2.3 Create Tag from Search
*This all works as expected but it's literally the same modal that comes up as from 1.1 and 1.2 (see issues from there)*
- [X] Open tag picker
- [X] Type "Meeting" in search
- [/] No existing tags match *we are doing fuzzy find and when I type "M" "Someday" comes up and it stays up until the second e of Meeting is typed. Maybe we want this interior fuzzyfinding, just noting that behavior*
- [X] Tap "+ Create New Tag" button
- [0] Dialog pre-fills with "Meeting" *No, it brings up the color picker modal*
- [X] Select yellow color
- [X] Save
- [X] "Meeting" tag is auto-selected
- [X] Tap "Done"

**Expected:** Creating tag from search context is seamless

---

## Test 3: Tag Display

### 3.1 Tag Chips in Task List
- [X] Navigate back to main task list
- [X] Find task with tags
- [X] Tag chips display with:
  - [X] Correct background color
  - [X] Readable text (WCAG AA contrast)
  - [X] Rounded pill shape
  - [X] Appropriate padding

**Expected:** Tags look good, text is readable on all colors

### 3.2 Tag Overflow Handling
- [X] Create a task with 5+ tags
- [X] In task list, only 3 tags + "+N more" should show
- [/] Open task editor *See above but task edit only allows edit title of task*
- [X] All tags visible in tag picker

**Expected:** Overflow indicator appears, doesn't break layout

---

## Test 4: Color Picker

### 4.1 Preset Colors
- [X] Open tag picker
- [0] Tap "+ Create New Tag" *Button doesn't exist, see above*
- [X] Color picker shows 12 Material Design colors in a grid
- [X] Each color is tappable
- [X] Selected color has visual indicator (border/checkmark)
- [X] Try each color
- [X] Save tag with each color

**Expected:** All 12 colors work, visual selection is clear

### 4.2 Color Contrast Validation
- [X] Create tags with all 12 preset colors
- [X] Verify text is readable on each:
  - Red (#F44336)
  - Pink (#E91E63)
  - Purple (#9C27B0)
  - Deep Purple (#673AB7)
  - Indigo (#3F51B5)
  - Blue (#2196F3)
  - Cyan (#00BCD4)
  - Teal (#009688)
  - Green (#4CAF50)
  - Orange (#FF9800)
  - Deep Orange (#FF5722)
  - Brown (#795548) *Brown? None of these read as brown to my eyes. I see a grid with colors: Orange (Tangerine); Hot pink; Medium Purple; Dark purple; Dark blue; Mid blue; Sky blue; Cyan; Dark green (I think this is what you call teal?); Green; Orange; Yellow. At any rate, see above for other color notes, but the two middle blue colors are not distinguishable for humans*

**Expected:** All text is readable (WCAG AA 4.5:1 contrast ratio)

---

## Test 5: Tag Persistence

### 5.1 Tag Survives App Restart
- [X] Add tags to multiple tasks
- [X] Close app completely (swipe away from recent apps)
- [X] Reopen app
- [X] Tags still visible on tasks
- [X] Open tag picker
- [X] All tags still exist in list

**Expected:** Tags persist correctly in SQLite database

### 5.2 Tag Deletion (via Task)
- [X] Open task with tags
- [X] Open tag picker
- [X] Deselect all tags *See Issue 6 for my thoughts on this*
- [X] Tap "Done"
- [X] Task shows no tags in list
- [X] Reopen tag picker
- [X] Tags still exist in global tag list (not deleted, just unassigned)

**Expected:** Removing tag from task doesn't delete tag globally

---

## Test 6: Edge Cases

### 6.1 Empty Tag Name
- [/] Try to create tag with empty name *Currently the only way the + for adding a task comes up is from searching for a tag. I can type spaces and don't get the option to add a tag, fwiw*
- [/] Save button should be disabled OR show validation error *See above. Does not apply, given workflow*

**Expected:** Can't create tag without name

### 6.2 Duplicate Tag Names
- [/] Try to create tag named "Work" when "Work" already exists *see above, impossible because searching for a tag is only want to add tags currently. Will have to retest all this type of thing later when/if we have an actual "add tag" area*
- [/] Should show error or prevent creation

**Expected:** Duplicate tag names handled gracefully

### 6.3 Very Long Tag Names
- [X] Create tag with 50+ character name
- [0] Tag chip should truncate with ellipsis OR wrap gracefully *See Issue 11 below*

**Expected:** Long tags don't break layout

### 6.4 Many Tags (Performance)
- [X] Create 20+ tags
- [X] Tag picker should load quickly
- [X] Search should remain responsive
- [X] Scrolling should be smooth

**Expected:** Handles many tags without lag

### 6.5 Many Tags on Single Task
- [X] Assign 10+ tags to one task
- [X] Task list shows overflow indicator
- [0] Task editor shows all tags in picker *See all other notes about task edit only editing name, not allowing for tag edit. Manage Tag from long press does show all tags properly*
- [X] No layout issues

**Expected:** Handles many tags per task gracefully

---

## Test 7: Integration with Other Features

### 7.1 Tags + Task Hierarchy
- [X] Create parent task with tags
- [X] Create subtask with different tags
- [X] Both show correct tags independently

**Expected:** Tags work correctly with nested tasks

### 7.2 Tags + Soft Delete
- [X] Tag a task
- [X] Delete task (soft delete)
- [X] Navigate to "Recently Deleted"
- [0] Task still shows tags *Not displayed in list, only task title, task deleted time, restore, and permanently delete options*
- [X] Restore task
- [X] Tags intact

**Expected:** Tags survive soft delete/restore cycle

### 7.3 Tags + Task Completion
- [X] Add tags to task
- [X] Complete task (checkmark)
- [X] Tags still visible
- [X] Uncomplete task
- [X] Tags still intact

**Expected:** Tags unaffected by completion state

---

## Test 8: Visual Polish

### 8.1 Animations
- [X] Tag picker opening/closing is smooth
- [X] Color picker selection has visual feedback
- [X] Tag chips appear/disappear smoothly

**Expected:** UI feels polished, no janky animations

### 8.2 Dark Mode (if implemented)
- [NA] Switch to dark mode (if available)
- [NA] Tags remain readable
- [NA] Dialogs have appropriate contrast

**Expected:** Tags work well in dark mode

### 8.3 Tap Targets
- [X] All buttons are easy to tap (48x48dp minimum)
- [X] No accidental taps on wrong elements

**Expected:** Touch targets are appropriately sized

---

## Known Issues / Limitations

_(Document any issues found during testing)_

- [ ] Issue 1: Tag Manage should have its own designated modal. If I want to create a bunch of new tags and NOT have them auto append to a task, I can't use the current workflow. The way we have it set up, it's only accessible from long pressing on a task, and new tasks we create are auto checked. 
- [ ] Issue 2: Should default behavior of text input be lowercase or should keyboard default to initial capital? I was capitalizing all tasks and it was irritating to have to toggle each time but this could be a user pref. 
- [ ] Issue 3: Red color is too pinky
- [ ] Issue 4: We need a scrollbar or a vertical indicator to show that there the list is scrollable when we have more than 4 tasks (all that displays on my screen)
- [ ] Issue 5: We should NOT have both an "add tag" section on each item AND a context menu (long press) option that both bring up the same "Manage Tags" modal. We should pick one or have different functionality. 
- [ ] Issue 6: All tags appended to a task and checked should be displayed at the top of the tag menu available associated with managing tags for a task. We may want to split out a basic "Tags" modal that comes up when you hit "add tag" or when you are creating a task, and have a different "manage tags" menu? Whatever we choose, the way we have it now is kind of awful. I like our quick add text and add button but we SHOULD have a full "+" add task modal where it gives us a modal that lets us put in the text of the task, attach tags, and (future feature) choose due date etc. This same modal can be what appears when we long press and click edit on any existing tag as well. Probably tag management should be possible here (change color, change text of a tag) but it should be subordinate to actually attaching tags and editing basics. We could have some kind of Manage Tag modal to do more if needed but right now the issue is it's both too much and too little. 
- [ ] Issue 7: We don't want the "add tag" AND long press "Manage Tags" to both exist. I vote we remove the "add tag" below each task because once a single tag is added that disappears and could be confusing to users who don't know you can long press a task and add more that way. 
- [ ] Issue 8: Not an issue, but just a note - it is impossible to create a lowercase and an uppercase version of a tag because we only have search not returning a result as bringing up an option to create a tag and we are not matching case in search, so if "Work" exists, typing "work" will bring up "Work" and no option to add a tag will trigger. Appending a space to the end of "work " changes nothing. 
- [ ] Issue 9: While creating a tag that is too long (100+ characters) the behavior is: Type the text into the "Search or create tag" text field; Click the + button that comes up below it. This hides the keyboard and brings up the color picker. I pick a color And click "Select". With failure, this closes the choose color modal, focuses the cursor back in the "Search or create tag" text section, and because the keyboard is brought back up, automatically, it hides screen real estate so the bottom failure banner is halfway hidden by the Manage Tags modal and the message is almost impossible to make out. 
- [ ] Issue 10: Tag length should be 250 characters. 
- [ ] Issue 11: When creating a tag that is too long, within the Manage Tags modal, the tag appears with a perpendicular vertical text over it which has a caution tape line (yellow and black) and then "FLOWED BY 174 PIXELS" line in red caps. This also applies to the chit on a task. Further, the white part of the text does not get truncated, it continues off the edge of the task to the edge of the screen, but the color pill DOES get bounded by the task box. 
- [ ] Issue 12: No dark mode, so no testing of 8.2, but let's add Dark Mode to our road map. 
- [ ] Issue 13: Reorder view does NOT show tags. This must be fixed. 
- [ ] Issue 14: Completing a child task and a parent task by clicking checkmarks, they do not display properly below the divider line in the recently completed task section. The child task has light grey text in its upper left saying the name of the parent task, but it is not nested. Completing the Child task moves it below the fold, shows it completed with the check and in the top left is the grey text of the parent task name. Completing the parent task moves that task below the fold as well and marks it completed with the check but it does not nest child under parent. No text anywhere on Parent notes name of child. Unchecking either parent or child moves both back above the fold and the proper check/uncheck status of each persists, but overal, behavior here is suspect. 

---

## Test Results Summary

**Date Tested:** 1/5/26
**Device:** Samsung Galaxy S22 Ultra
**Build:** _______________

**Tests Passed:** ___ / 50+
**Tests Failed:** ___
**Critical Issues:** ___
**Minor Issues:** ___

**Overall Status:** ✅ PASS / ⚠️ PASS WITH ISSUES / ❌ FAIL

**Notes:**
```
[Add any additional observations, performance notes, or UX feedback]
```

---

## Sign-Off

- [ ] **BlueKitty:** Manual testing complete, Phase 3.5 UI validated
- [ ] **Ready for Production:** Yes / No / With Caveats

---

**Next Steps:**
- Address any critical issues found
- Document any UX improvements for future phases
- Proceed to Phase 3.6 planning

---

*This test plan covers UI/UX aspects that automated tests can't verify.*
