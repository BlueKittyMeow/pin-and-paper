# Claude's Bug Hunting - Phase 3.4 (Task Editing)

**Phase:** 3.4 - Task Editing
**Status:** 🔜 Planning
**Last Updated:** 2025-12-27

---

## Instructions

This document tracks bugs, edge cases, and potential issues discovered during Phase 3.4 implementation.

**Format:**
- Report bugs as they're discovered
- Include severity (CRITICAL, HIGH, MEDIUM, LOW)
- Provide reproduction steps
- Suggest fixes when possible
- Mark as FIXED when resolved

---

## Bugs Discovered

*No bugs yet - implementation pending*

---

## Edge Cases to Test

### Context Menu Behavior
- [ ] Tap "Edit" on root task
- [ ] Tap "Edit" on deeply nested subtask
- [ ] Tap "Edit" on completed task
- [ ] Tap "Edit" on deleted task (should not be accessible)
- [ ] Open context menu, tap outside to dismiss
- [ ] Rapidly tap "Edit" multiple times

### Edit Dialog Behavior
- [ ] Enter empty string and save
- [ ] Enter whitespace-only and save
- [ ] Enter very long title (500+ chars)
- [ ] Enter special characters (emoji, unicode, symbols)
- [ ] Press Enter key to submit
- [ ] Click "Cancel" button
- [ ] Click outside dialog to dismiss
- [ ] Edit same task twice in quick succession

### Database & State Management
- [ ] Edit task while another task is being edited
- [ ] Edit task immediately after creating it
- [ ] Edit task immediately after completing it
- [ ] Edit task immediately after soft deleting it
- [ ] Database error during save
- [ ] Network interruption (if cloud sync added later)

### UI State Updates
- [ ] Task title updates immediately in list
- [ ] Task title updates in parent/child views
- [ ] Scroll position maintained after edit
- [ ] Focus returns to appropriate location
- [ ] Keyboard dismisses properly

### Platform-Specific
- [ ] Linux desktop keyboard behavior
- [ ] Android soft keyboard behavior
- [ ] Different screen sizes/orientations

---

## Potential Issues

### Issue Categories

**Input Validation:**
- What's the max title length? Should we enforce one?
- Do we allow emoji/unicode in all SQLite implementations?
- Should we sanitize input to prevent SQL injection? (Parameterized queries already do this)

**Concurrency:**
- What if user edits task A while TaskProvider is reloading from database?
- What if background auto-cleanup deletes task while user is editing it?

**UX Flow:**
- Should pressing back button while editing cancel the edit?
- Should edit dialog be dismissible by tapping outside?
- Should we show "unsaved changes" warning if user cancels with changes?

**Performance:**
- Does `loadTasks()` after every edit cause lag with 1000+ tasks?
- Should we update in-place rather than full reload?

---

## Testing Notes

*Will be updated during implementation*

---

## Fixed Issues

*Will be updated as bugs are found and fixed*
