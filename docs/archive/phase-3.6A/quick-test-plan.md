# Phase 3.6A - Quick Test Plan (Core Functionality)

**Tester:** BlueKitty
**Date:** 2026-01-10
**Status:** Tests 1-7 already completed ✓

---

## Legend
- [ ] : Pending
- [X] : Pass
- [0] : Fail
- [?] : Test instructions unclear
- [/] : Partial (note issues)

---

## Test 8: Dialog Actions (5 min)

### 8.1 Clear All Button
- [X] Open filter dialog
- [X] Select 2-3 tags
- [X] Click "Clear All"
- X ] **Verify:**
  - [X] All tag selections cleared
  - [X] Presence filter returns to "Any"
  - [X] Dialog closes
  - [X] Filter bar disappears
  - [X] Filter button shows outlined icon

### 8.2 Cancel Button
- [X] Open dialog, select some tags
- [X] Click "Cancel"
- [X] **Verify:**
  - [X] Dialog closes
  - [X] No changes applied (filter unchanged)

### 8.3 Apply Button
- [X] Open dialog, select 2 tags
- [X] Click "Apply"
- [X] **Verify:**
  - [X] Dialog closes
  - [X] Filter bar appears with selected tags
  - [X] Task list updates
  - [X] Filter button shows filled icon

**Notes:**
```
- The "Clear All" button on the modal is confusing. I think it shouldn't be visible on the modal, ONLY on the top bar where the selected filters are visible. We SHOULD though, on the modal, have a deselect all. 
- On the top bar on the task view, with multiple filters selected and the "ANY" chit visible, that should be CLICKABLE and toggleable to switch state between ANY and ALL. 

```

---

## Test 9: ActiveFilterBar Appearance (3 min)

### Quick Visual Check
- [X] Apply filter with 1 tag
  - [X] Bar appears below task input
  - [X] Shows tag chip with color
  - [X] "Clear All" button on right
- [X] Apply filter with 3 tags
  - [X] All chips visible
  - [X] Proper spacing between chips
  - [NA] Chips scrollable if needed
- [?] Add presence filter ("Tagged")
  - [?] Shows presence chip
- [X] Select 2+ tags with ALL mode
  - [X] Shows "ALL" logic indicator

**Notes:**
```
- What is "presence filter" and "presence chip"????

```

---

## Test 10: Filter Bar Interactions (5 min)

### 10.1 Remove Individual Tag
- [X] Apply filter with 3 tags
- [X] Click X on first tag chip
- [X] **Verify:**
  - [X] Tag removed from filter
  - [X] Task list updates immediately
  - [X] Other chips remain

### 10.2 Remove Last Tag
- [X] Have filter with 1 tag only
- [X] Click X on chip
- [X] **Verify:**
  - [X] Filter bar disappears
  - [X] All tasks reappear
  - [X] Filter button outlined

### 10.3 Clear All from Bar
- [X] Apply filter
- [X] Click "Clear All" in filter bar
- [X] **Verify:**
  - [X] All filters cleared
  - [X] Bar disappears
  - [X] All tasks visible

**Notes:**
```


```

---

## Test 11: OR Filtering Logic (CRITICAL - 10 min)

### 11.1 Setup Test Data
Using the existing test data:
- "Fix critical bug in production" → Urgent, Work
- "Brainstorm new features for Q2" → Work, Ideas
- "Call dentist about appointment" → Urgent
- "Plan weekend camping trip" → Personal
- "Buy groceries for dinner party" → Shopping, Personal
- "Review code for PR #247" → Work
- "Clean garage" → (no tags)
- "Research new productivity methods" → Ideas
- "Water the plants" → (no tags)
- "Renew passport before expiry" → Urgent, Personal

### 11.2 Test OR Filter: Work + Urgent
- [ ] Open filter dialog
- [ ] Select "Work" and "Urgent" tags
- [ ] Verify "ANY" is selected (OR logic)
- [ ] Click Apply
- [ ] **Verify tasks shown:**
  - [ ] "Fix critical bug in production" ✓ (has both)
  - [ ] "Brainstorm new features for Q2" ✓ (has Work)
  - [ ] "Call dentist about appointment" ✓ (has Urgent)
  - [ ] "Review code for PR #247" ✓ (has Work)
  - [ ] "Renew passport before expiry" ✓ (has Urgent)
- [ ] **Verify tasks hidden:**
  - [ ] "Plan weekend camping trip" (only Personal)
  - [ ] "Buy groceries for dinner party" (only Shopping, Personal)
  - [ ] "Research new productivity methods" (only Ideas)
  - [ ] "Clean garage" (no tags)
  - [ ] "Water the plants" (no tags)

**Expected count:** 5 tasks visible

**Notes:**
```


```

---

## Test 12: AND Filtering Logic (CRITICAL - 10 min)

### 12.1 Test AND Filter: Work + Urgent
- [ ] Open filter dialog
- [ ] Select "Work" and "Urgent" tags
- [ ] Click "ALL" toggle (AND logic)
- [ ] Click Apply
- [ ] **Verify tasks shown:**
  - [ ] "Fix critical bug in production" ✓ (has BOTH Work and Urgent)
- [ ] **Verify tasks hidden:**
  - [ ] "Brainstorm new features for Q2" (only has Work)
  - [ ] "Call dentist about appointment" (only has Urgent)
  - [ ] "Review code for PR #247" (only has Work)
  - [ ] "Renew passport before expiry" (only has Urgent, not Work)
  - [ ] All others (don't have both tags)

**Expected count:** 1 task visible

### 12.2 Test AND Filter: Personal + Shopping
- [ ] Open filter dialog
- [ ] Select "Personal" and "Shopping" tags
- [ ] Ensure "ALL" is selected
- [ ] Click Apply
- [ ] **Verify tasks shown:**
  - [ ] "Buy groceries for dinner party" ✓ (has both)
- [ ] **Verify tasks hidden:**
  - [ ] Everything else

**Expected count:** 1 task visible

**Notes:**
```


```

---

## Test 13: Presence Filters (10 min)

### 13.1 "Tagged" Filter (Any Tag)
- [ ] Open filter dialog
- [ ] Select "Tagged" presence filter
- [ ] Do NOT select specific tags
- [ ] Click Apply
- [ ] **Verify all tasks WITH tags are visible:**
  - [ ] "Fix critical bug in production"
  - [ ] "Brainstorm new features for Q2"
  - [ ] "Call dentist about appointment"
  - [ ] "Plan weekend camping trip"
  - [ ] "Buy groceries for dinner party"
  - [ ] "Review code for PR #247"
  - [ ] "Research new productivity methods"
  - [ ] "Renew passport before expiry"
- [ ] **Verify tasks WITHOUT tags are hidden:**
  - [ ] "Clean garage"
  - [ ] "Water the plants"

**Expected count:** 8 tasks visible

### 13.2 "Untagged" Filter
- [ ] Open filter dialog
- [ ] Select "Untagged" presence filter
- [ ] Verify tag checkboxes are disabled
- [ ] Click Apply
- [ ] **Verify only untagged tasks visible:**
  - [ ] "Clean garage" ✓
  - [ ] "Water the plants" ✓
- [ ] **Verify all tagged tasks hidden**

**Expected count:** 2 tasks visible

### 13.3 "Tagged" + Specific Tag
- [ ] Open filter dialog
- [ ] Select "Tagged" + "Work" tag
- [ ] Click Apply
- [ ] **Verify same results as just filtering by "Work":**
  - [ ] "Fix critical bug in production"
  - [ ] "Brainstorm new features for Q2"
  - [ ] "Review code for PR #247"

**Expected count:** 3 tasks visible

**Notes:**
```


```

---

## Test 14: Quick Regression Check (5 min)

### Basic Functionality Still Works
- [X] **Create new task** - works
- [X] **Complete a task** - works
- [X] **Delete a task** - works
- [X] **Add tag to task** - works
- [X] **Navigate to Settings and back** - works
- [X] **Filter persists after navigation** - works
- [X] **Brain Dump accessible** - works

**Notes:**
```
UX improvement - completed tasks below the fold should be displayed by recency (respecting and keeping hierarchy of parent/child tasks ofc, dont' separate those) and this should be able to be filtered/changed (alphabetical, most recent, etc). For the dev roadmap, can we add this to the future features? 

```

---

## Summary

**Total Test Time:** ~45 minutes

**Sections:**
- [X] Test 8: Dialog Actions
- [/] Test 9: Filter Bar Appearance
- [X] Test 10: Filter Bar Interactions
- [ ] Test 11: OR Filtering Logic ⚠️ CRITICAL
- [ ] Test 12: AND Filtering Logic ⚠️ CRITICAL
- [ ] Test 13: Presence Filters ⚠️ CRITICAL
- [X] Test 14: Quick Regression

**Result:** ⬜ PASS | ⬜ FAIL (note issues below)

---

## Issues Found

```
(List any issues found during testing)




```

---

## Final Recommendation

**After completing these tests:**
- ⬜ **APPROVE** - Core functionality works, UX improvements tracked
- ⬜ **NEEDS FIXES** - Critical issues found

**Tester:** _______________
**Date:** _______________
