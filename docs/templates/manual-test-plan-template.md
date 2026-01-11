# [Feature Name] Manual Test Plan

**Phase:** [Phase number and name]
**Tester:** BlueKitty
**Device:** [Device name, e.g., Samsung Galaxy S22 Ultra]
**Build Mode:** Release (`flutter run --release`)
**Date:** _____________
**Created:** [YYYY-MM-DD]

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

**What This Tests:** [Brief description of the feature being tested]

**Why It Matters:** [Why this feature is important, what it enables]

**What Changed:**
- [Key change 1]
- [Key change 2]
- [Key change 3]

---

## Pre-Test Setup

- [ ] **Clean build completed**
  ```bash
  cd pin_and_paper
  flutter clean
  flutter build apk --release
  flutter install --release
  ```

- [ ] **Fresh app state** (optional but recommended)
  - Uninstall app from device
  - Reinstall to start with clean database
  - OR use existing data if you want to test with real data

- [ ] **Device connected**
  ```bash
  flutter devices
  # Verify device appears in list
  ```

- [ ] **App version verified**
  - Expected version: [version number]
  - Check in Settings > About (if available)

---

## Test 1: [Test Name]

**Objective:** [What this specific test verifies]

### 1.1 [Sub-test Name]
- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

### 1.2 [Another Sub-test]
- [ ] Step 1
- [ ] Step 2

### 1.3 Verify [Expected Behavior]
- [ ] Check item 1
- [ ] Check item 2
- [ ] Take screenshot

**Expected:**
```
[Visual representation or description of expected behavior]
```

**Actual Results:**
```
(Paste screenshot or describe what you see)

Notes:
```

---

## Test 2: [Second Test Name]

**Objective:** [What this test verifies]

### 2.1 [Setup Steps]
- [ ] Step 1
- [ ] Step 2

### 2.2 [Action Steps]
- [ ] Step 1
- [ ] Step 2

### 2.3 [Verification Steps]
- [ ] Check item 1
- [ ] Check item 2
- [ ] Take screenshot

**Expected:**
```
[Description of expected results]
```

**Why This Matters:**
[Optional explanation of why this particular test case is critical]

**Actual Results:**
```
(Paste screenshot or describe what you see)

Notes:
```

---

## Performance Testing

### Test [N]: [Performance Test Name]

**Objective:** [What performance aspect is being tested]

**Steps:**

1. **Setup**
   - [ ] Create test scenario
   - [ ] Prepare large dataset (if applicable)

2. **Execute**
   - [ ] Perform action
   - [ ] Monitor metrics

**Expected Results:**

- [ ] **Metric 1:** [Expected value]
- [ ] **Metric 2:** [Expected value]
- [ ] **No performance degradation**

**Performance Metrics:**

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Frame rate | ≥60fps | ___fps | ⬜ PASS / ⬜ FAIL |
| Response time | <100ms | ___ms | ⬜ PASS / ⬜ FAIL |
| Memory usage | Stable | ___________ | ⬜ PASS / ⬜ FAIL |

**Actual Results:**
```
Notes on performance:
```

---

## Regression Testing

### Test [N]: Existing Features Still Work

**Objective:** Verify new feature doesn't break existing functionality.

**Checklist:**

- [ ] **Feature group 1**
  - [ ] Sub-feature works ✓
  - [ ] Sub-feature works ✓

- [ ] **Feature group 2**
  - [ ] Sub-feature works ✓
  - [ ] Sub-feature works ✓

- [ ] **Feature group 3**
  - [ ] Sub-feature works ✓
  - [ ] Sub-feature works ✓

**Actual Results:**
```
Notes on any issues found:
```

---

## Edge Cases & Error Handling

### Test [N]: Boundary Conditions

**Checklist:**

- [ ] **Edge case 1**
  - [ ] Behavior is correct ✓
  - [ ] No crash or error ✓

- [ ] **Edge case 2**
  - [ ] Behavior is correct ✓
  - [ ] No crash or error ✓

- [ ] **Edge case 3**
  - [ ] Behavior is correct ✓
  - [ ] No crash or error ✓

**Actual Results:**
```
Notes:
```

---

## Visual Verification Checklist

### UI/UX Quality

- [ ] **Visual consistency**
  - Item appears correctly
  - Styling matches design

- [ ] **Accessibility**
  - Touch targets are adequate
  - Text is readable (WCAG AA)
  - Color contrast is sufficient

- [ ] **Responsive design**
  - Works on different screen sizes
  - Layout doesn't break

- [ ] **Dark mode** (if supported)
  - Feature works in dark theme
  - Visibility is maintained

**Screenshots:**
(Attach screenshots for each major test case)

---

## Sign-Off

### Test Summary

**Total Tests:** [number]
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

**Issue #2:**
```
(Add more as needed)
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
# Clean build
cd pin_and_paper
flutter clean
flutter build apk --release
flutter install --release

# Run in release mode
flutter run --release

# Check for lint issues
flutter analyze

# Run tests
flutter test --concurrency=1
```

### Useful Git Commands

```bash
# Check current status
git status

# View recent commits
git log --oneline -5

# Create new branch for testing
git checkout -b test/[feature-name]
```

---

**Document Version:** 1.0
**Last Updated:** [YYYY-MM-DD]
**Created By:** [Your name]
