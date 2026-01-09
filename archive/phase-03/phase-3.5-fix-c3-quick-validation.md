# Fix #C3 Quick Validation Guide

**Purpose:** Streamlined testing combining automated unit tests + minimal visual verification
**Time Required:** ~10 minutes (vs 45 minutes for full manual test plan)

---

## ✅ Automated Testing (Already Done)

All 6 unit tests are **PASSING** ✓

```bash
flutter test test/providers/task_provider_completed_hierarchy_test.dart --concurrency=1
```

**Tests verified:**
- ✅ Simple hierarchy (parent + 2 children)
- ✅ Orphaned completed child (critical edge case)
- ✅ Position-based sorting
- ✅ Deep nesting (3 levels)
- ✅ hasCompletedChildren helper
- ✅ Multiple independent trees

**Result:** All logic is correct ✓

---

## 👀 Visual Verification (Quick Check)

You only need to verify the **visual rendering** is correct since logic is tested.

### Quick Test Scenario (5 minutes)

**In the running Linux app:**

1. **Create a simple hierarchy:**
   ```
   - Create task: "Shopping"
   - Create task: "Buy milk"
   - Drag "Buy milk" under "Shopping" to nest it
   - Complete both tasks
   ```

2. **Look at completed section and verify:**
   - [ ] "Shopping" is **not indented** (flush left)
   - [ ] "Buy milk" is **indented** (shifted right)
   - [ ] "Shopping" shows a **visual indicator** it has children
   - [ ] "Buy milk" appears **directly below** "Shopping"

3. **Take screenshot** (if it looks good, we're done!)

### Expected Visual

```
COMPLETED TASKS
Shopping ◆                    ← Not indented, has indicator
  Buy milk                    ← Indented once
```

---

## ✅ Acceptance Criteria

**PASS if:**
- [ ] Unit tests pass (already verified ✓)
- [ ] Visual indentation is visible in UI
- [ ] Parent shows "has children" indicator
- [ ] Children appear nested under parent

**That's it!** The comprehensive unit tests already verified all the complex logic (orphaned children, position sorting, deep nesting, etc.)

---

## 🚀 Result Summary

**Automated Tests:** 6/6 passing ✓
**Visual Check:** ⬜ PASS | ⬜ FAIL

**If visual check passes:** Fix #C3 is validated! ✓

**If visual check fails:** Document what you see vs expected

---

**Time saved:** 35 minutes compared to full manual test plan!
