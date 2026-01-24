# Palette Regression Test - Semantic Colors

**Created:** 2026-01-23 (Phase 3.9.0 theme cleanup)
**Purpose:** Manual testing guide for verifying semantic color migration

---

## Background

Phase 3.9.0 migrated 6 screens from hardcoded Material colors (Colors.green, Colors.red, etc.) to semantic AppTheme colors (success, danger, warning, info, muted). This test ensures visual consistency was maintained during the migration.

---

## Test Screens

### 4. Task Suggestion Preview Screen

**Access:** Brain Dump → Process text → View suggestions

**Test Cases:**

1. **Original/Enhanced Toggle**
   - Toggle between "Original" and "Enhanced" view
   - **Expected:** Active toggle should be **sage green** (#7A9B7A, AppTheme.success)
   - **Expected:** Inactive toggle should be **muted gray-brown** (#9B8F85, AppTheme.muted)

2. **Drag Handles**
   - View the drag handles (6 dots) on task items
   - **Expected:** Should be **muted gray-brown** with transparency (AppTheme.muted.withValues(alpha: 0.5))

3. **Hint Text**
   - Check any placeholder or hint text
   - **Expected:** Should be **muted gray-brown** (#9B8F85, AppTheme.muted)

4. **Error Snackbar**
   - Try to save without a title or trigger validation error
   - **Expected:** Error snackbar background should be **dusty rose red** (#C17A7A, AppTheme.danger)

---

### 5. Quick Complete Screen

**Access:** Tap quick-complete notification OR from task detail → "Quick Complete"

**Test Cases:**

1. **High Confidence Success**
   - Complete a task with high confidence match
   - **Expected:** Success indicator should be **sage green** (#7A9B7A, AppTheme.success), NOT bright Material green

2. **Medium Confidence Warning**
   - Complete a task with medium confidence match
   - **Expected:** Warning indicator should be **warm amber** (#D4A574, AppTheme.warning)

3. **Muted Text**
   - Check secondary text throughout the screen
   - **Expected:** Should be **muted gray-brown** (#9B8F85, AppTheme.muted)

4. **Shadow Colors**
   - Check card shadows and subtle depth effects
   - **Expected:** Should use **richBlack** (#1C1C1C, AppTheme.richBlack) instead of Colors.black

---

### 6. Settings Screen

**Access:** Home → Settings (gear icon)

**Test Cases:**

1. **Claude Connection Status - Connected**
   - Ensure Claude API key is configured and valid
   - **Expected:** "Connected" text should be **sage green** (#7A9B7A, AppTheme.success)

2. **Claude Connection Status - Disconnected**
   - Remove API key or use invalid key
   - **Expected:** "Disconnected" text should be **dusty rose red** (#C17A7A, AppTheme.danger)

3. **Disabled/Muted States**
   - Check any disabled settings or muted text
   - **Expected:** Should be **muted gray-brown** (#9B8F85, AppTheme.muted)

4. **Notification Toggles**
   - Toggle notification settings on/off
   - **Expected:** Active states should use theme colors consistently

5. **Validation Messages**
   - Enter invalid values in settings fields
   - **Expected:** Error messages should use **dusty rose red** (AppTheme.danger)

---

## What to Look For

### ✅ Pass Criteria

- All colors match the **Witchy Flatlay** aesthetic (warm, muted, earthy tones)
- **No bright Material colors** (no bright green #4CAF50, bright red #F44336, bright blue #2196F3)
- Colors are **identical to pre-migration** appearance
- All semantic colors use the documented hex values:
  - Success: `#7A9B7A` (Muted sage green)
  - Danger: `#C17A7A` (Dusty rose red)
  - Warning: `#D4A574` (Warm amber)
  - Info: `#7A8FA5` (Muted slate blue)
  - Muted: `#9B8F85` (Warm gray-brown)

### ❌ Fail Criteria

- Bright, saturated Material Design colors appear anywhere
- Color values don't match the documented palette
- Visual appearance changed from before migration
- Any hardcoded `Colors.*` usage in the affected screens

---

## Semantic Color Reference

| Color Name | Hex Code | RGB | Use Case |
|-----------|----------|-----|----------|
| **Success** | #7A9B7A | rgb(122, 155, 122) | Affirmative actions, connection status, completion |
| **Danger** | #C17A7A | rgb(193, 122, 122) | Errors, delete actions, warnings |
| **Warning** | #D4A574 | rgb(212, 165, 116) | Medium confidence, caution states |
| **Info** | #7A8FA5 | rgb(122, 143, 165) | Informational states, selection |
| **Muted** | #9B8F85 | rgb(155, 143, 133) | Disabled states, secondary text |

---

## Related Files

- [lib/utils/theme.dart](../../pin_and_paper/lib/utils/theme.dart) - Semantic color definitions
- [scripts/check_theme_compliance.sh](../../pin_and_paper/scripts/check_theme_compliance.sh) - Automated compliance checker
- [docs/phase-3.9/phase-3.9-plan-v2.md](../phase-3.9/phase-3.9-plan-v2.md) - Phase 3.9.0 implementation plan

---

**Last Updated:** 2026-01-23
**Tested By:** [Your initials]
**Result:** [ ] PASS / [ ] FAIL
**Notes:**
