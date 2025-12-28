# Phase 3.5 Plan: Tags Feature

**Version:** 2
**Created:** 2025-12-27
**Updated:** 2025-12-27 (Gemini feedback addressed)
**Status:** Updated - Ready for Implementation
**Scope:** Task tagging with filtering (expanded MVP)

---

## Overview

**What is Phase 3.5?** Implementation of flexible task tagging with color-coded labels and filtering capabilities.

**Why now?**
- Database schema already exists (added in Phase 3.1)
- Natural complement to hierarchical organization
- Requested feature for flexible task categorization

**Philosophy:** "Tags over categories" - Fluid, overlapping organization without rigid hierarchies

---

## Scope

### In Scope

**Core Tag Management (Phase 3.5a):**
- ✅ Create tags with names and colors
- ✅ Add/remove tags from tasks
- ✅ Display tags as colored chips on tasks
- ✅ View all tags (tag management screen)
- ✅ Edit tag properties (name, color)
- ✅ Delete tags (with confirmation)
- ✅ **Tag renaming** (CRITICAL for "forgiving" ADHD-friendly design)
- ✅ **Tag autocomplete** (CRITICAL for "zero friction" - prevents duplicate tags)
- ✅ Empty states for UI (tag management, tag picker)

**Filtering (Phase 3.5b):**
- ✅ Filter tasks by single tag
- ✅ Filter by multiple tags (OR logic initially)
- ✅ AND/OR filter toggle (moved from stretch - essential for power users)
- ✅ Clear active filters
- ✅ Visual filter indicator
- ✅ Handle edge case: deleting actively filtered tag

### Out of Scope (Future Phases)

**Deferred to Phase 3.5c (Stretch):**
- Inline #hashtag parsing in titles
- Tag usage statistics dashboard
- Bulk tag operations (merge, delete multiple)

**Deferred to Phase 4+:**
- Smart/auto-tagging with AI
- Tag hierarchies
- Tag merging
- Tag templates

---

## Technical Approach

### Database Schema

**Already exists** (created in Phase 3.1, database version 5):

```sql
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE task_tags (
  task_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (task_id, tag_id),
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);
```

**No database migration needed** - tables ready to use!

### Architecture

**Model Layer:**
- `Tag` model class (id, name, color, createdAt)
- Validation: non-empty name, valid hex color

**Service Layer:**
- `TagService` - CRUD operations for tags and task-tag associations
- Methods: createTag, getAllTags, addTagToTask, getTagsForTask, etc.

**Provider Layer:**
- `TagProvider` - State management for tags
- Integration with existing `TaskProvider` for filtering

**UI Layer:**
- `TagChip` widget - Display tag with color
- `TagPickerDialog` - Select/create tags
- `TagFilterWidget` - Filter UI (bottom sheet)
- `TagManagementScreen` - Manage all tags

---

## User Workflows

### 1. Add Tag to Task
1. Long-press task → context menu
2. Tap "Add Tag"
3. Select existing tag OR create new tag with color
4. Tag chip appears on task

### 2. Filter by Tag
1. Tap "Filter" button (new!)
2. Select tag(s) from list
3. Task list shows only matching tasks
4. Tap "Clear" to remove filter

### 3. Manage Tags
1. Navigate to "Manage Tags" (from Settings or dedicated screen)
2. View all tags with usage counts
3. Edit tag (change color/name)
4. Delete tag (with confirmation showing affected tasks)

---

## Implementation Strategy

### Phase 3.5a: Core Tag Management
**Goal:** Create, display, and manage tags

**Deliverables:**
- Tag model + TagService
- Add/remove tags from tasks
- Display tag chips
- Tag management screen

**Estimated Effort:** 2-3 days

**Acceptance Criteria:**
- User can create tags with colors
- Tags display as colored chips on tasks
- User can view/edit/delete tags
- Deleting tag removes all associations

### Phase 3.5b: Filtering
**Goal:** Filter tasks by tags

**Deliverables:**
- Tag filter UI (bottom sheet)
- Multi-tag filtering (OR logic)
- Active filter indicator
- Integration with TaskProvider

**Estimated Effort:** 1-2 days

**Acceptance Criteria:**
- User can filter by one or more tags
- Filtered list updates immediately
- Active filters clearly indicated
- Filter persists across app restarts (optional)

---

## Dependencies

**From Previous Phases:**
- ✅ Phase 3.1: Database schema with tags tables
- ✅ Phase 3.2: Task hierarchy (tags are orthogonal)
- ✅ Phase 3.3: Soft delete (applies to tags too?)
- ✅ Phase 3.4: Context menu (extends for "Add Tag")

**No blocking dependencies** - ready to implement!

---

## Design Decisions ✅ LOCKED IN

All design questions have been answered by BlueKitty:

**Decision 1: Tag Creation Flow**
- ✅ **Two-step (name → color picker)** with smart default
- Defaults to last used color for quick creation
- Can skip color picker if happy with default

**Decision 2: Filter Button Location**
- ✅ **Top app bar** (next to search/menu)
- Standard, discoverable pattern

**Decision 3: Tag Color Palette**
- ✅ **Preset palette (12 colors) + full custom picker + user-saved palettes**
- 12 Material Design preset colors
- Full color picker for custom colors
- Users can save their own custom palettes

**Decision 4: Tag Display Limit**
- ✅ **Show first 3 tags, click to expand**
- Prevents visual clutter
- Tap to show all tags

**Decision 5: Tag Deletion**
- ✅ **Hybrid approach:**
  - **Hard delete** if tag has zero task associations
  - **Forced soft delete** if tag is used by any tasks (preserves associations)
- Best of both worlds: clean unused tags, preserve data for used tags

**Decision 6: Tag Inheritance from Parents**
- ✅ **No inheritance** (each task has independent tags)
- Tags are orthogonal to hierarchy

---

## Testing Strategy

### Unit Tests
- TagService CRUD operations
- Tag validation (empty names, duplicate names)
- Task-tag associations
- Filter logic (single tag, multiple tags)

### Widget Tests
- TagChip rendering
- TagPickerDialog interaction
- TagFilterWidget selection

### Integration Tests
- Add tag to task → chip appears
- Delete tag → associations removed
- Filter by tag → correct tasks shown
- Multiple tags filter → OR logic works

---

## Success Criteria

**MVP Success (Phase 3.5a):**
- User can create and manage tags
- Tags display correctly on tasks
- No performance degradation

**Full Success (Phase 3.5b):**
- User can filter by tags
- Filtering is fast (<200ms for 500 tasks)
- UX is intuitive (no training needed)

**User Adoption Metrics:**
- >30% of tasks tagged within 1 week
- Tag filtering used in >20% of sessions
- 5-15 unique tags created per user

---

## Timeline Estimate

**Phase 3.5a: Core Tag Management**
- Day 1: Tag model + TagService + tests
- Day 2: UI widgets (TagChip, TagPickerDialog with autocomplete)
- Day 3: Tag management screen (renaming, empty states)
- Day 4: Polish + edge case handling

**Phase 3.5b: Filtering**
- Day 1: Filter UI + TagProvider integration
- Day 2: AND/OR toggle + edge cases (deleting filtered tag)
- Day 3: Testing + bug fixes

**Total: 6-7 days** (expanded from 4-5 to include critical features)

---

## Next Steps

1. **Team review of this plan** (Codex, Gemini, BlueKitty feedback)
2. **Answer open questions** (design decisions)
3. **Create detailed implementation spec** (phase-3.5-implementation.md)
4. **Get approval to proceed**
5. **Implement Phase 3.5a** (core management)
6. **User testing / validation**
7. **Implement Phase 3.5b** (filtering)
8. **Ship it!** 🚀

---

## Risk Mitigation

**Risk:** Filter performance with many tags/tasks
- **Mitigation:** Optimize queries, cache results, test with 500 tasks

**Risk:** Tag overload (user creates too many tags)
- **Mitigation:** Show usage counts, future: suggest merging similar tags

**Risk:** Confusion between nesting and tagging
- **Mitigation:** In-app tips: "Nest for structure, tag for facets"

**Risk:** Accidental tag deletion
- **Mitigation:** Confirmation dialog with impact ("Delete #work from 12 tasks?")

---

## Feedback Requested

**From Codex:**
- Review technical architecture (TagService design)
- Identify potential bugs/edge cases
- Query optimization suggestions

**From Gemini:**
- UX flow validation
- Tag management screen layout
- Filter UI design
- Missing edge cases?

**From BlueKitty:**
- Scope approval (3.5a + 3.5b together or separate?)
- Design decision answers (see Open Questions)
- Priority: Core management first or filtering first?

---

**Status:** Updated based on Gemini feedback - Ready for implementation!

**Companion Document:** See `phase-3.5-ultrathinking.md` for deep analysis and detailed considerations.

---

## Team Feedback Addressed

### Gemini's Review (2025-12-27)

**CRITICAL - Contradictory Scope:**
- ✅ **FIXED:** Moved tag renaming and autocomplete from stretch (3.5c) to MVP (3.5a)
- **Rationale:** These features are essential for "zero friction" and "forgiving" ADHD-friendly design principles
- Without autocomplete, users create duplicate tags (#errands vs #running-errands)
- Without renaming, users must delete+recreate to fix typos (losing all associations)

**HIGH - Ambiguous Tag Deletion:**
- ✅ **FIXED:** Added edge case handling to 3.5b scope
- When deleting a tag that's actively being filtered:
  - Remove tag from `_activeFilters` in TagProvider
  - TaskProvider listens for filter changes and refreshes list
  - User sees filtered list with remaining tags (or full list if no filters remain)

**MEDIUM - Soft-Deleted Tasks in Counts:**
- ✅ **FIXED:** Added to implementation spec
- Tag usage counts will exclude soft-deleted tasks
- Query includes `WHERE tasks.deleted_at IS NULL`
- Ensures counts reflect visible, active tasks

**LOW - No Empty State:**
- ✅ **FIXED:** Added empty states to 3.5a scope
- Tag Management Screen: "No tags created yet. Add a tag to a task to get started!"
- Tag Picker Dialog: "No existing tags" message when empty

**Scope Impact:** Timeline extended from 4-5 days to 6-7 days to accommodate critical features.
