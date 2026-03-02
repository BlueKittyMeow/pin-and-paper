# Tag Management Plan Review — Codex

**Feature:** Tag Management (rename, recolor, delete) + Sync Merge Fix + MCP Tools
**Reviewer:** Codex
**Date:** 2026-03-01

---

## Instructions

We are about to implement full tag CRUD and a Manage Tags screen. Review the **proposed plan** below for logic bugs, edge cases, and gaps **before we start coding**. The implementation has NOT been written yet — you are reviewing the design.

Record ALL findings in THIS document. **Do not modify any other files.**

### Context files (read for reference)

- `pin_and_paper/lib/services/tag_service.dart` — Current TagService (create, read, tag-task associations only)
- `pin_and_paper/lib/services/sync_service.dart` — SyncService with `mergeTag()`, `logChange()`, `preparePushEntry()`
- `pin_and_paper/lib/providers/tag_provider.dart` — Current TagProvider (create, load, no update/delete)
- `pin_and_paper/lib/models/tag.dart` — Tag model with `validateName()`, `validateColor()`, `copyWith()`
- `pin_and_paper/lib/utils/tag_colors.dart` — 12 preset colors, hex/Color converters, WCAG AA contrast
- `pin_and_paper/lib/widgets/color_picker_dialog.dart` — Existing color picker widget
- `pin_and_paper/lib/widgets/tag_picker_dialog.dart` — Existing tag attachment dialog (333 lines)
- `pin_and_paper/lib/screens/settings_screen.dart` — Settings screen where entry point will be added
- `supabase/functions/mcp-server/tools/list_tags.ts` — Current list_tags tool
- `supabase/functions/mcp-server/tools/manage_tags.ts` — Current manage_tags tool (task-tag associations only)
- `supabase/functions/mcp-server/helpers/tags.ts` — Tag helpers (resolveTagNames, insertTaskTags)
- `docs/specs/sync-layer-spec.md` — Canonical sync spec v2.0

### What to look for

1. **updateTag() design** — Is the validation logic complete? Does it handle the UNIQUE constraint on `tags.name` (case-insensitive)? Is the sync logging pattern correct (`operation: 'UPDATE'` with full payload)?

2. **deleteTag() design** — Is soft-delete the right approach? Should task_tags be hard-deleted when the tag is soft-deleted? Is logging the tag as UPDATE (not DELETE) correct for sync? Should each task_tag removal be logged individually?

3. **mergeTag() color fix** — Is preserving local color when remote is `null` the right behavior? What about the name-collision branch — should it also preserve color? Any edge cases with both colors being `null`?

4. **MCP update_tag tool** — Is accepting any `#RRGGBB` hex (not just presets) safe? Should there be server-side hex validation? Is RLS sufficient or do we need explicit user_id checks?

5. **ManageTagsScreen design** — Is a full-page screen the right UX, or should it be a dialog? Is the edit flow (dialog with TextField + color picker) sufficient? Should there be swipe-to-delete or just icon buttons?

6. **Sync implications** — If a tag is renamed on desktop and recolored via MCP simultaneously, does LWW handle it correctly? What happens if a deleted tag's task_tags haven't been pushed before a pull brings them back?

7. **Anything else** — Race conditions, missing edge cases, UX issues.

### How to report

For each finding, rate severity:
- **CRITICAL** — Must fix before implementation. Broken functionality or data loss risk.
- **HIGH** — Should fix. Incorrect behavior in realistic scenarios.
- **MEDIUM** — Worth discussing. Design tradeoff or minor edge case.
- **LOW** — Nit or suggestion. Won't cause problems but could be better.

---

## Plan Reference

### Bug Fix: mergeTag() Color Preservation

**File:** `pin_and_paper/lib/services/sync_service.dart`

**Problem:** When `mergeTag()` does an LWW update and remote wins, it overwrites all fields including `color`. MCP-created tags have `color: null`, which wipes locally-set colors to default blue.

**Proposed fix:** In the LWW update branch, before writing to DB:
```dart
if (remoteUpdated >= localUpdated) {
  // Preserve local color if remote color is null
  if (localData['color'] == null && local['color'] != null) {
    localData['color'] = local['color'];
  }
  await db.update(AppConstants.tagsTable, localData, where: 'id = ?', whereArgs: [remote['id']]);
}
```

Same fix in the name-collision branch: when unifying tags with same name but different IDs, if remote tag has `null` color but local tag has a color, preserve the local color in the inserted row.

**Tests:** 2 new tests in `sync_service_test.dart`:
- `preserves local color when remote color is null`
- `overwrites local color when remote has an explicit color`

---

### TagService.updateTag()

**File:** `pin_and_paper/lib/services/tag_service.dart`

```dart
Future<Tag> updateTag(String id, {String? name, String? color}) async {
  // 1. At least one field must be provided (throw ArgumentError if both null)
  // 2. Validate name via Tag.validateName() if provided
  // 3. Validate color via Tag.validateColor() if provided
  // 4. Check tag exists and is not soft-deleted via getTagById()
  // 5. Build update map: { 'updated_at': now, 'name': name?.trim(), 'color': color }
  // 6. db.update(tagsTable, updates, where: 'id = ?', whereArgs: [id])
  //    — UNIQUE constraint on name will throw DatabaseException if duplicate
  // 7. Re-read tag via getTagById() for return value
  // 8. SyncService.instance.logChange(tableName: 'tags', recordId: id, operation: 'UPDATE', payload: updatedTag.toMap())
  // 9. Return updated Tag
}
```

**Tests:** 11 tests covering:
- Updates name only, color only, both
- Trims whitespace from name
- Sets updated_at timestamp
- Throws ArgumentError on: empty name, invalid color hex, no fields provided
- Throws StateError on: tag not found, tag is soft-deleted
- Throws DatabaseException on: duplicate name (case-insensitive)

---

### TagService.deleteTag()

**File:** `pin_and_paper/lib/services/tag_service.dart`

```dart
Future<void> deleteTag(String id) async {
  // 1. Check tag exists and is not already soft-deleted via getTagById()
  // 2. Query all task_tags for this tag (for sync logging)
  // 3. Soft-delete tag: db.update(tagsTable, {'deleted_at': now, 'updated_at': now}, where: 'id = ?')
  // 4. Hard-delete task_tags: db.delete(taskTagsTable, where: 'tag_id = ?', whereArgs: [id])
  // 5. Log tag UPDATE (with deleted_at set) for sync
  // 6. Log each task_tag DELETE individually for sync (matching removeTagFromTask pattern)
}
```

**Design decision:** task_tags are hard-deleted (not soft-deleted) because:
- The junction table has no `deleted_at` column
- A soft-deleted tag shouldn't be associated with any tasks
- `pullTaskTags()` does full union-merge reconciliation, so remote cleanup happens automatically

**Tests:** 8 tests covering:
- Soft-deletes tag (sets deleted_at), removes task_tags
- Preserves other tags on same tasks
- Sets updated_at
- Throws StateError on: tag not found, already deleted
- Deleted tag excluded from getAllTags() and getTagsForTask()

---

### TagProvider Wrappers

**File:** `pin_and_paper/lib/providers/tag_provider.dart`

```dart
Future<Tag?> updateTag(String id, {String? name, String? color}) async {
  // try: call _tagService.updateTag(), loadTags(), return tag
  // catch: set user-friendly _errorMessage (duplicate name, not found, generic), return null
}

Future<bool> deleteTag(String id) async {
  // try: call _tagService.deleteTag(), loadTags(), return true
  // catch: set user-friendly _errorMessage, return false
}
```

Follows existing `createTag()` pattern for error handling and state refresh.

---

### ManageTagsScreen

**New file:** `pin_and_paper/lib/screens/manage_tags_screen.dart`

```
┌─────────────────────────────────────────┐
│  ← Manage Tags                    [+]  │
├─────────────────────────────────────────┤
│  ● Work                    3 tasks [✎][🗑] │
│  ● Personal                1 task  [✎][🗑] │
│  ● Urgent                  0 tasks [✎][🗑] │
│                                         │
│  (empty state if no tags)               │
│  🏷  No tags yet                        │
│  Create your first tag with the + button│
└─────────────────────────────────────────┘
```

- Leading: 32px color circle
- Subtitle: task count from `TagService.getTaskCountsByTag(completed: false)`
- Edit icon → dialog with TextField (pre-filled name) + tappable color circle → `ColorPickerDialog`
- Delete icon → confirmation dialog showing task count → `TagProvider.deleteTag()`
- AppBar + button → create dialog (name + color) → `TagProvider.createTag()`

---

### Settings Entry Point

**File:** `pin_and_paper/lib/screens/settings_screen.dart`

Add "Manage Tags" ListTile in Data Management section (above "Recently Deleted"):
- Leading: `Icons.label_outline`
- Title: "Manage Tags"
- Subtitle: "Edit, rename, or delete tags"
- Trailing: tag count badge + chevron
- onTap: `Navigator.push()` → `ManageTagsScreen`

---

### TagPickerDialog Edit Icons

**File:** `pin_and_paper/lib/widgets/tag_picker_dialog.dart`

Add small edit icon (18px) next to each tag's `TagChip` in the CheckboxListTile. Tapping opens an inline edit dialog (same as ManageTagsScreen edit flow) and refreshes the tag list on save.

---

### MCP `update_tag` Tool

**New file:** `supabase/functions/mcp-server/tools/update_tag.ts`

```typescript
server.registerTool("update_tag", {
  description: "Update a tag's name and/or color.",
  inputSchema: {
    tag_id: z.string().describe("The UUID of the tag to update."),
    name: z.string().optional().describe("New name for the tag."),
    color: z.string().optional().describe("New hex color (e.g. '#FF5722'). Any #RRGGBB hex accepted."),
  },
}, async ({ tag_id, name, color }) => {
  // 1. Validate at least one field provided
  // 2. Validate hex format if color provided: /^#[0-9A-Fa-f]{6}$/
  // 3. Build update object: { name?, color?, updated_at: new Date().toISOString() }
  // 4. supabase.from("tags").update(updates).eq("id", tag_id).select().single()
  //    — RLS ensures user can only update their own tags
  //    — UNIQUE(user_id, name) constraint handles duplicate names
  // 5. Return updated tag or error
});
```

**Server-side hex validation:** Add `validateHexColor()` helper in `helpers/tags.ts`:
```typescript
export function validateHexColor(color: string): boolean {
  return /^#[0-9A-Fa-f]{6}$/.test(color);
}
```

Register in `index.ts`: `registerUpdateTag(server, supabase, user.id)`

---

### MCP `list_tags` Enhancement

**File:** `supabase/functions/mcp-server/tools/list_tags.ts`

Add preset color palette to the response:
```typescript
const PRESET_COLORS = [
  { hex: "#FF5722", name: "Deep Orange" },
  { hex: "#E91E63", name: "Pink" },
  { hex: "#9C27B0", name: "Purple" },
  { hex: "#673AB7", name: "Deep Purple" },
  { hex: "#3F51B5", name: "Indigo" },
  { hex: "#2196F3", name: "Blue" },
  { hex: "#03A9F4", name: "Light Blue" },
  { hex: "#00BCD4", name: "Cyan" },
  { hex: "#009688", name: "Teal" },
  { hex: "#4CAF50", name: "Green" },
  { hex: "#FF9800", name: "Orange" },
  { hex: "#FFC107", name: "Amber" },
];

return toolSuccess({
  tags: result,
  available_colors: PRESET_COLORS,
  color_note: "These are preset colors. Any valid #RRGGBB hex is also accepted via update_tag.",
});
```

---

## Findings

### Finding 1: deleteTag() needs transactional integrity + consistent timestamps

**Severity:** HIGH  
**Location:** Plan → TagService.deleteTag()  
**Description:** The plan performs (1) tag soft-delete, (2) task_tags delete, and (3) sync logging as separate steps. If any step fails mid-way, you can end up with a deleted tag but leftover task_tags, or logs that don’t match actual DB state. Also, `updated_at` and log timestamps may diverge across steps.  
**Suggested fix:** Wrap tag update + task_tags deletion in a single transaction, capture a single `now` timestamp, and log changes immediately after commit (or within the transaction if you accept the earlier-crash risk). Use the same `now` for `updated_at` and `deleted_at`.

---

### Finding 2: updateTag() should short-circuit no-op updates

**Severity:** MEDIUM  
**Location:** Plan → TagService.updateTag()  
**Description:** As written, updateTag() will write + log even if the new name/color is identical to the current values (e.g., same name with different casing or same color). This creates unnecessary sync traffic and updated_at churn, and can trigger UNIQUE constraint errors on case-only changes depending on DB collation.  
**Suggested fix:** Load the current tag first, normalize/trim the proposed name, and return early if no actual changes. If only casing changes and the DB is case-insensitive, treat as no-op.

---

### Finding 3: Task count in ManageTagsScreen may be misleading

**Severity:** LOW  
**Location:** Plan → ManageTagsScreen (task count from `getTaskCountsByTag(completed: false)`)  
**Description:** The count only includes active (incomplete) tasks, so a tag attached to completed tasks will show “0 tasks” and a delete confirmation may understate impact.  
**Suggested fix:** Either count all tasks (completed + active) for management purposes, or label it clearly as “active tasks”.

---

### Finding 4: TagPickerDialog edit icons can toggle selection unintentionally

**Severity:** LOW  
**Location:** Plan → TagPickerDialog edit icons  
**Description:** The edit icon lives inside a CheckboxListTile; tapping near the icon can also toggle selection unless gesture handling is isolated. This leads to accidental tag toggles while editing.  
**Suggested fix:** Use a trailing IconButton with `onPressed` and set `controlAffinity`/`onTap` carefully (or wrap in `IgnorePointer` for the tile) to prevent selection changes when editing.

---

### Finding 5: MCP update_tag should trim/validate name length, and clarify “clear color”

**Severity:** MEDIUM  
**Location:** Plan → MCP `update_tag` tool  
**Description:** The plan validates hex format but does not mention trimming whitespace, enforcing the 250-char limit, or how to clear a color (set to null). Without this, server behavior can diverge from app validation and make tags impossible to clear.  
**Suggested fix:** Trim name, enforce max length (same as app), and explicitly define how to clear color (e.g., allow `color: null` to clear).

---
