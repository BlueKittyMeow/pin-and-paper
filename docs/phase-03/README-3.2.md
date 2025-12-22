# Phase 3.2 Quick Reference

**Subphase:** 3.2 - Task Nesting & Hierarchical UI
**Status:** 🔄 IN PROGRESS
**Started:** 2025-12-22

---

## Document Map

### Active Work
- **[phase-3.2-implementation.md](./phase-3.2-implementation.md)** - Implementation tracking & checklist
- **[phase-3.2-issues.md](./phase-3.2-issues.md)** - Phase 3.2-specific issues

### Reference Docs
- **[group1.md](./group1.md)** - Detailed specification for 3.1, 3.2, 3.3
  - Lines 726-844: Phase 3.2 detailed plan
- **[prelim-plan.md](./prelim-plan.md)** - Overall Phase 3 scope

### Bug Tracking
- **[phase-03-bugs.md](./phase-03-bugs.md)** - All Phase 3 bugs (24/27 fixed)
- **[codex-findings.md](./codex-findings.md)** - Codex's ongoing bug findings
- **[gemini-findings.md](./gemini-findings.md)** - Gemini's ongoing bug findings
- **[claude-findings.md](./claude-findings.md)** - Claude's self-review notes

---

## Implementation Overview

### What We're Building
Hierarchical task organization with:
- 4-level nesting (parent → child → grandchild → great-grandchild)
- Drag-and-drop reordering
- Visual tree view with expand/collapse
- Context menu (long press)
- CASCADE delete protection
- Auto-complete children prompt

### Technology Stack
- `flutter_fancy_tree_view2` - Tree visualization
- Existing Task model with parent_id, position, depth
- TreeController for state management
- Custom drag-and-drop tile widget

### Key Files
**Services:**
- `lib/services/task_service.dart` - Hierarchical query methods

**Providers:**
- `lib/providers/task_provider.dart` - TreeController integration

**Screens:**
- `lib/screens/home_screen.dart` - AnimatedTreeView replacement

**Widgets (New):**
- `lib/widgets/drag_and_drop_task_tile.dart`
- `lib/widgets/context_menu.dart`
- `lib/widgets/delete_confirmation_dialog.dart`
- `lib/widgets/auto_complete_children_dialog.dart`

---

## Quick Commands

```bash
# Run tests
cd pin_and_paper && flutter test

# Analyze specific files
flutter analyze lib/services/task_service.dart lib/providers/task_provider.dart

# Build APK
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
flutter build apk

# Check dependencies
flutter pub outdated
```

---

## Current Status

**Prerequisites:** ✅ All complete
- Database v4 migration
- Task model extended
- All HIGH/MEDIUM bugs fixed

**In Progress:**
- Hierarchical query methods (TaskService)

**Next Up:**
- TreeController integration (TaskProvider)
- AnimatedTreeView UI (HomeScreen)

---

## Questions?

- **Detailed specs:** See group1.md (Lines 726-844)
- **Database schema:** See group1.md (Lines 95-287)
- **Bug found?** Add to phase-3.2-issues.md or phase-03-bugs.md
- **Need review?** Tag BlueKitty, Codex, or Gemini in findings docs

---

**Updated:** 2025-12-22
**Next Review:** After first commit
