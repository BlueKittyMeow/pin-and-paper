# Phase 3 Bug Tracker

**Created:** 2025-11-05
**Status:** Active
**Purpose:** Consolidated bug list from Codex and Gemini findings

---

## Fixed in 47ef2d4 ✅

These bugs were fixed before Phase 3.2:

1. ✅ **Position backfill duplicates** (database_service.dart:415) - HIGH
   - Fixed: Added id tie-breaker for identical timestamps

2. ✅ **Missing indexes in migration** (database_service.dart:524) - MEDIUM
   - Fixed: Added idx_tasks_created and idx_tasks_completed

3. ✅ **New tasks default to position=0** (task_service.dart:19) - HIGH
   - Fixed: Calculate max position + 1 for new tasks

4. ✅ **TaskService orders by created_at** (task_service.dart:68) - HIGH
   - Fixed: Changed to ORDER BY position ASC

## Fixed in 754e072 ✅

These HIGH priority bugs were fixed after Phase 3 review:

5. ✅ **Draft update silently fails if deleted** (brain_dump_provider.dart:202)
   - Fixed: Check rowsAffected, fallback to insert if 0 rows touched

6. ✅ **Deleting active draft leaves stale ID** (brain_dump_provider.dart:253)
   - Fixed: Reset _currentDraftId when deleting active draft

7. ✅ **Loading draft creates duplicate** (drafts_list_screen.dart:85)
   - Fixed: Call loadDraft() for single selection, clear() for multiple

8. ✅ **Claude API deprecated** (claude_service.dart:10)
   - Fixed: Updated to claude-3-5-sonnet-20241022 model and 2024-10-22 API

9. ✅ **VPN treated as offline** (brain_dump_provider.dart:71)
   - Fixed: Include vpn, other, bluetooth in connectivity check

10. ✅ **No network timeout** (claude_service.dart:51)
    - Fixed: Added 30s timeout to http.post

11. ✅ **API usage logging crashes on missing tokens** (claude_service.dart:63)
    - Fixed: Guard with null checks before logging

---

## High Priority - Should Fix Soon

No remaining HIGH priority bugs!

---

## Medium Priority - Fix When Convenient

### BuildContext / Async Issues

12. **BuildContext reused after await** (brain_dump_screen.dart:86)
    - Impact: MEDIUM
    - Issue: Navigator/setState after await without mounted check
    - Fix: Add `if (!context.mounted) return;` after awaits

13. **Success animation fires after dispose** (success_animation.dart:24)
    - Impact: MEDIUM
    - Issue: Future.delayed callback not cancelled
    - Fix: Cancel timer in dispose, guard with mounted check

14. **Bottom sheet setState after dispose** (task_suggestion_preview_screen.dart:223)
    - Impact: MEDIUM
    - Issue: whenComplete callback runs after screen popped
    - Fix: Wrap with `if (!mounted) return;` guard

15. **Task suggestion snackbar after pop** (task_suggestion_preview_screen.dart:252)
    - Impact: MEDIUM
    - Issue: Navigator.popUntil then SnackBar on disposed context
    - Fix: Capture messenger before popping

16. **Quick complete snackbars vanish** (quick_complete_screen.dart:56)
    - Impact: MEDIUM
    - Issue: SnackBar shown then immediate pop
    - Fix: Capture root messenger or pop first

### Brain Dump / UI Issues

17. **Clear button never flushes draft** (brain_dump_screen.dart:292)
    - Impact: MEDIUM
    - Issue: _clearText doesn't call deleteDraft, stale drafts linger
    - Fix: Call provider.clear() and deleteDraft in _clearText

18. **Cost estimate never updates on errors** (brain_dump_provider.dart:77)
    - Impact: MEDIUM
    - Issue: notifyListeners only on happy path
    - Fix: Always notify after updating _estimatedCost

### Settings / Preferences Issues

19. **Hide-completed preference never loads** (task_provider.dart:104)
    - Impact: MEDIUM
    - Issue: loadPreferences() never called
    - Fix: Call in main.dart or HomeScreen.initState

---

## Low Priority - Nice to Have

### Performance Issues

20. **Usage stats query re-runs on every rebuild** (settings_screen.dart:220)
    - Impact: LOW
    - Issue: FutureBuilder receives new future each rebuild
    - Fix: Cache future in state, only refresh explicitly

### Deprecation Warnings

21. **Deprecated DropdownButtonFormField value** (settings_screen.dart:185)
    - Impact: LOW
    - Issue: Flutter 3.24 deprecates value parameter
    - Fix: Use initialValue instead

22. **Deprecated Color.withOpacity** (home_screen.dart:96)
    - Impact: LOW
    - Issue: Flutter 3.24 deprecates withOpacity
    - Fix: Replace with .withValues(alpha: x)

---

## Gemini-Specific Findings

### Phase 3.1 Code Issues

23. **UserSettings.copyWith allows nullable createdAt** (user_settings.dart:155)
    - Impact: MEDIUM
    - Issue: Constructor requires it, but copyWith allows null
    - Fix: Remove createdAt from copyWith parameters

24. **Inconsistent databaseVersion constant** (constants.dart:5)
    - Impact: LOW
    - Issue: Defined in AppConstants but hardcoded in _upgradeDB
    - Fix: Use AppConstants.databaseVersion everywhere

25. **TaskProvider constructor allows nullable dependencies** (task_provider.dart:8)
    - Impact: LOW
    - Issue: Nullable params with null-coalescing is misleading
    - Fix: Make params non-nullable with default instances

---

## Statistics

**Total Bugs:** 25
- **Fixed:** 11 (4 in 47ef2d4, 7 in 754e072)
- **High:** 0 (all fixed!)
- **Medium:** 11
- **Low:** 3

**By Category:**
- Brain Dump / Drafts: 3 remaining (3 fixed)
- API / Connectivity: 0 remaining (4 fixed)
- BuildContext / Async: 5 remaining
- Settings / Preferences: 1 remaining
- Performance: 1 remaining
- Deprecations: 2 remaining
- Code Quality: 2 remaining

**Sources:**
- Codex: 22 bugs
- Gemini: 3 bugs

---

## Notes

- This is a living document - bugs are added as found
- Bugs are removed when fixed (moved to "Fixed" section)
- Priority reflects impact on user experience and Phase 3.2 readiness
- All HIGH priority bugs should be addressed before Phase 3.2 completion
- MEDIUM priority bugs can be deferred to cleanup task
- LOW priority bugs can be deferred to separate linting/deprecation cleanup

---

**See Also:**
- `codex-findings.md` - Codex's detailed exploration notes
- `gemini-findings.md` - Gemini's linting and analysis
- `claude-findings.md` - Claude's self-review notes
- `archive/phase-03/3.1-issues.md` - Original Gemini findings (archived)
- `archive/phase-03/3.1-issues-response.md` - Original Claude response (archived)
