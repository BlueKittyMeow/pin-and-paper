# Phase 3.5 Plan: Tags Feature

**Version:** 1
**Created:** 2025-12-27
**Status:** Draft - Awaiting Review
**Scope:** Task tagging with filtering

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

**Filtering (Phase 3.5b):**
- ✅ Filter tasks by single tag
- ✅ Filter by multiple tags (OR logic)
- ✅ Clear active filters
- ✅ Visual filter indicator

### Out of Scope (Future Phases)

**Deferred to Phase 3.5c (Stretch):**
- Inline #hashtag parsing in titles
- Fuzzy search/autocomplete for tags
- AND/OR filter toggle
- Tag usage statistics
- Bulk tag operations
- Tag renaming

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

## Open Questions

### Design Decisions Needed

**Question 1:** Tag creation flow
- **Option A:** Two-step (name → color picker)
- **Option B:** One-step (name with default color, edit later)
- **Recommendation:** Option B (faster, less friction)

**Question 2:** Where to put "Filter" button?
- **Option A:** App bar (top right)
- **Option B:** Floating action button
- **Option C:** Bottom navigation bar
- **Recommendation:** Option A (discoverable, standard pattern)

**Question 3:** Tag color palette
- **Option A:** Fixed 12 colors (Material Design)
- **Option B:** Full color picker
- **Option C:** Both (12 presets + custom)
- **Recommendation:** Option C (balance quick vs custom)

**Question 4:** Should child tasks show parent tags?
- **Option A:** No (tags are per-task)
- **Option B:** Yes (inherit from parent)
- **Recommendation:** Option A (simpler, clearer)

**Question 5:** Soft delete for tags?
- **Option A:** Hard delete (CASCADE removes associations)
- **Option B:** Soft delete (mark deleted, hide from UI)
- **Recommendation:** Option A (simpler, defer soft delete to Phase 4+)

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
- Day 2: UI widgets (TagChip, TagPickerDialog)
- Day 3: Tag management screen + polish

**Phase 3.5b: Filtering**
- Day 1: Filter UI + TagProvider integration
- Day 2: Testing + bug fixes

**Total: 4-5 days**

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

**Status:** Ready for team review and feedback!

**Companion Document:** See `phase-3.5-ultrathinking.md` for deep analysis and detailed considerations.
