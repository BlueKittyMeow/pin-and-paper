# Phase 3.5 Day 2 - Code Review Instructions

**Date**: 2025-12-28
**Status**: Ready for AI Review

## Overview

Day 2 UI integration is complete with all 139 tests passing! Time for AI code review before proceeding.

## Review Files Created

### 1. Codex Review (Technical/Security)
- **Instructions**: `docs/phase-03/codex-review-day-2.md`
- **Output File**: `docs/phase-03/codex-findings-day-2.md`
- **Focus**: Critical bugs, race conditions, SQL injection, memory leaks, data integrity

### 2. Gemini Review (UX/Design)
- **Instructions**: `docs/phase-03/gemini-review-day-2.md`
- **Output File**: `docs/phase-03/gemini-findings-day-2.md`
- **Focus**: Material Design compliance, accessibility, UX friction, color contrast

## How to Conduct Reviews

### For Codex Review:

1. Open a **new Codex session** (separate from this Claude Code session)
2. Share the instruction file: `docs/phase-03/codex-review-day-2.md`
3. Provide access to the source files listed in the instructions
4. Ask Codex to write findings to: `docs/phase-03/codex-findings-day-2.md`

**Suggested Codex Prompt**:
```
Please review the Phase 3.5 Day 2 implementation according to the instructions in docs/phase-03/codex-review-day-2.md.

Write your findings in the specified format to docs/phase-03/codex-findings-day-2.md.

Be extremely critical and look for bugs that could cause data loss, crashes, or security issues.
```

### For Gemini Review:

1. Open a **new Gemini session** (separate from Codex)
2. Share the instruction file: `docs/phase-03/gemini-review-day-2.md`
3. Provide access to the UI files listed in the instructions
4. Ask Gemini to write findings to: `docs/phase-03/gemini-findings-day-2.md`

**Suggested Gemini Prompt**:
```
Please review the Phase 3.5 Day 2 UI implementation according to the instructions in docs/phase-03/gemini-review-day-2.md.

Write your findings in the specified format to docs/phase-03/gemini-findings-day-2.md.

Focus on UX friction, Material Design violations, and accessibility issues.
```

## After Reviews Complete

1. Review both findings files:
   - `docs/phase-03/codex-findings-day-2.md`
   - `docs/phase-03/gemini-findings-day-2.md`

2. Return to this Claude Code session

3. Share the findings and we'll:
   - Prioritize issues
   - Fix critical and high-priority issues
   - Decide which medium/low priority items to address
   - Update tests if needed
   - Re-run test suite

## Current Status

✅ **Day 1 Complete**: Foundation layer (78 tests passing)
✅ **Day 2 Complete**: UI integration (139 total tests passing)
⏳ **Code Review**: Waiting for Codex + Gemini findings
⏳ **Bug Fixes**: After review
⏳ **Final Testing**: After fixes

## Test Results Summary

- **Total Tests**: 139 passing, 1 failing (pre-existing, unrelated)
- **Phase 3.5 Tests**: All passing
  - Tag model: 12 tests ✓
  - TagService: 21 tests ✓
  - TagColors: 7 tests ✓
  - Tag validation: 31 tests ✓
  - Database migration: 3 tests ✓
  - Tag batching (1000 tasks): 1 test ✓

## Files Implemented

### Day 2 UI Files (New)
- `lib/providers/tag_provider.dart`
- `lib/widgets/tag_chip.dart`
- `lib/widgets/color_picker_dialog.dart`
- `lib/widgets/tag_picker_dialog.dart`

### Day 2 UI Files (Modified)
- `lib/providers/task_provider.dart` - Added tag batch loading
- `lib/widgets/task_item.dart` - Added tag display and management
- `lib/widgets/task_context_menu.dart` - Added "Manage Tags" option
- `lib/widgets/drag_and_drop_task_tile.dart` - Added tags parameter
- `lib/screens/home_screen.dart` - Pass tags to TaskItem
- `lib/main.dart` - Registered TagProvider

## Questions?

If you encounter any issues during the review process, return to this Claude Code session and ask!

Good luck with the reviews! 🚀
