# Pin and Paper — MCP Tool Definitions

**Version:** 1.1 (incorporates review feedback)
**Date:** 2026-02-27
**Target:** Supabase Edge Function (`supabase/functions/mcp-server/index.ts`)
**Auth:** Supabase JWT (passed via OAuth flow from Claude connector)
**Transport:** Remote MCP server (HTTPS + SSE or Streamable HTTP)

---

## Architecture

```
Claude (any client)                 Supabase Edge Function
┌──────────────────┐               ┌──────────────────────┐
│  Claude Connector │──── MCP ────►│  /mcp-server          │
│  (Pro/Max plan)   │   (HTTPS)    │  - validates JWT      │
│                   │◄─────────────│  - queries PostgreSQL  │
└──────────────────┘               │  - enforces RLS       │
                                   └──────────────────────┘
```

The Edge Function acts as a thin translation layer between MCP tool calls and Supabase PostgREST/SQL queries. RLS ensures the authenticated user can only access their own data.

---

## Tool Definitions

### 1. `list_tasks`

List tasks with optional filtering. This is the primary "show me my tasks" tool.

```json
{
  "name": "list_tasks",
  "description": "List the user's tasks from Pin and Paper. Returns active (non-deleted) tasks by default. Supports filtering by completion status, tags, due dates, and search.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "status": {
        "type": "string",
        "enum": ["active", "completed", "all", "deleted"],
        "default": "active",
        "description": "Filter by task status. 'active' = incomplete and not deleted, 'completed' = done, 'all' = active + completed, 'deleted' = soft-deleted (trash)."
      },
      "tag": {
        "type": "string",
        "description": "Filter to tasks with this tag name (case-insensitive)."
      },
      "due": {
        "type": "string",
        "enum": ["overdue", "today", "this_week", "no_date"],
        "description": "Filter by due date. 'overdue' = past due, 'today' = due today, 'this_week' = due within 7 days, 'no_date' = no due date set."
      },
      "search": {
        "type": "string",
        "description": "Search tasks by title or notes content (case-insensitive substring match)."
      },
      "parent_id": {
        "type": "string",
        "description": "List only children of this task ID. Use null/omit for top-level tasks."
      },
      "include_children": {
        "type": "boolean",
        "default": true,
        "description": "Whether to include subtasks nested under their parents."
      },
      "limit": {
        "type": "integer",
        "default": 50,
        "description": "Maximum number of tasks to return."
      },
      "offset": {
        "type": "integer",
        "default": 0,
        "description": "Number of tasks to skip (for pagination). Use with limit to page through results."
      }
    }
  }
}
```

**Response format:**
```json
{
  "tasks": [
    {
      "id": "uuid",
      "title": "Buy groceries",
      "completed": false,
      "due_date": "2026-02-28T00:00:00Z",
      "is_all_day": true,
      "parent_id": null,
      "position": 0,
      "notes": "Milk, eggs, bread",
      "tags": ["errands", "weekly"],
      "children": [
        { "id": "uuid", "title": "Get milk", "completed": true, ... }
      ]
    }
  ],
  "total_count": 42,
  "returned_count": 1
}
```

---

### 2. `get_task`

Get a single task with full detail including tags and subtasks.

```json
{
  "name": "get_task",
  "description": "Get detailed information about a specific task, including its tags, notes, subtasks, and parent chain.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "task_id": {
        "type": "string",
        "description": "The UUID of the task to retrieve."
      }
    },
    "required": ["task_id"]
  }
}
```

---

### 3. `create_task`

Create a new task.

```json
{
  "name": "create_task",
  "description": "Create a new task in Pin and Paper. Can create top-level tasks or subtasks under a parent.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "title": {
        "type": "string",
        "description": "The task title. Required."
      },
      "notes": {
        "type": "string",
        "description": "Optional notes/description for the task."
      },
      "due_date": {
        "type": "string",
        "format": "date-time",
        "description": "Optional due date in ISO 8601 format."
      },
      "is_all_day": {
        "type": "boolean",
        "default": true,
        "description": "Whether the due date is all-day (true) or has a specific time (false)."
      },
      "start_date": {
        "type": "string",
        "format": "date-time",
        "description": "Optional start date for multi-day tasks (ISO 8601). Use with due_date to define a date range."
      },
      "parent_id": {
        "type": "string",
        "description": "Optional parent task ID to create this as a subtask."
      },
      "tags": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Tag names to apply. Tags are created automatically if they don't exist."
      }
    },
    "required": ["title"]
  }
}
```

**Implementation notes:**
- Generate UUID server-side
- If `parent_id` is provided, compute depth by walking parent chain. **Reject with `VALIDATION_ERROR` if depth would exceed 3** (app max is 4 levels: 0, 1, 2, 3). [FIX: Review #2]
- New tasks insert at **position 0** (top of sibling list), shifting existing siblings' positions up by 1. This matches app behavior. [FIX: Review #3]
- Auto-create tags that don't exist (use default color)
- Insert into `tasks` table, then `task_tags` junction

---

### 4. `create_multiple_tasks`

Batch create tasks (for brain dump / bulk add).

```json
{
  "name": "create_multiple_tasks",
  "description": "Create multiple tasks at once. Useful for brain dumps or batch task creation. Each task can have its own title, notes, due date, and tags.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "tasks": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "title": { "type": "string" },
            "notes": { "type": "string" },
            "due_date": { "type": "string", "format": "date-time" },
            "is_all_day": { "type": "boolean", "default": true },
            "start_date": { "type": "string", "format": "date-time" },
            "parent_id": { "type": "string" },
            "tags": { "type": "array", "items": { "type": "string" } }
          },
          "required": ["title"]
        },
        "description": "Array of tasks to create."
      }
    },
    "required": ["tasks"]
  }
}
```

---

### 5. `update_task`

Update an existing task's properties.

```json
{
  "name": "update_task",
  "description": "Update one or more properties of an existing task. Only include fields you want to change.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "task_id": {
        "type": "string",
        "description": "The UUID of the task to update."
      },
      "title": {
        "type": "string",
        "description": "New title for the task."
      },
      "notes": {
        "type": "string",
        "description": "New notes/description. Set to empty string to clear."
      },
      "due_date": {
        "type": ["string", "null"],
        "format": "date-time",
        "description": "New due date (ISO 8601) or null to remove."
      },
      "is_all_day": {
        "type": "boolean",
        "description": "Whether the due date is all-day."
      },
      "start_date": {
        "type": ["string", "null"],
        "format": "date-time",
        "description": "Start date for multi-day tasks (ISO 8601) or null to remove."
      },
      "completed": {
        "type": "boolean",
        "description": "Set to true to complete the task, false to uncomplete."
      },
      "parent_id": {
        "type": ["string", "null"],
        "description": "Move task under a new parent, or null to make top-level."
      },
      "tags": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Replace all tags with this list. Tags created automatically if they don't exist."
      }
    },
    "required": ["task_id"]
  }
}
```

**Implementation notes:**
- If `completed` changes to true: set `completed_at = NOW()`, save `position_before_completion = position`
- If `completed` changes to false: restore `position_before_completion`, clear `completed_at`
- If `tags` is provided: delete all existing `task_tags` for this task, insert new ones
- If `parent_id` changes: insert at **position 0** among new siblings, shift others up [FIX: Review #3]
- If `parent_id` is provided, validate depth won't exceed 3 (including any children of the moved task) [FIX: Review #2]

---

### 6. `delete_task`

Soft-delete a task (moves to trash).

```json
{
  "name": "delete_task",
  "description": "Soft-delete a task (moves to trash with 30-day retention). Children are also soft-deleted.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "task_id": {
        "type": "string",
        "description": "The UUID of the task to delete."
      }
    },
    "required": ["task_id"]
  }
}
```

**Implementation:** Set `deleted_at = NOW()` on the task and all descendants.

---

### 7. `restore_task`

Restore a soft-deleted task from trash. [FIX: Review #1 — Claude needs undo for accidental deletes]

```json
{
  "name": "restore_task",
  "description": "Restore a soft-deleted task from trash. Also restores any children that were deleted at the same time.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "task_id": {
        "type": "string",
        "description": "The UUID of the task to restore."
      }
    },
    "required": ["task_id"]
  }
}
```

**Implementation:** Set `deleted_at = NULL` on the task and all descendants whose `deleted_at` matches (±1 second) the parent's `deleted_at`, to avoid restoring children that were independently deleted earlier.

---

### 8. `list_tags`

List all tags with task counts.

```json
{
  "name": "list_tags",
  "description": "List all tags in Pin and Paper with the count of active tasks using each tag.",
  "inputSchema": {
    "type": "object",
    "properties": {}
  }
}
```

**Response format:**
```json
{
  "tags": [
    { "id": "uuid", "name": "errands", "color": "#FF5722", "task_count": 5 },
    { "id": "uuid", "name": "work", "color": "#2196F3", "task_count": 12 }
  ]
}
```

---

### 9. `manage_tags`

Add or remove tags on a task without replacing all of them.

```json
{
  "name": "manage_tags",
  "description": "Add or remove specific tags on a task without affecting other existing tags.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "task_id": {
        "type": "string",
        "description": "The UUID of the task."
      },
      "add": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Tag names to add. Created automatically if they don't exist."
      },
      "remove": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Tag names to remove from the task."
      }
    },
    "required": ["task_id"]
  }
}
```

---

### 10. `get_summary`

Get a high-level overview of the user's task state. Designed for "what's on my plate?" questions.

```json
{
  "name": "get_summary",
  "description": "Get a summary overview of the user's tasks: counts by status, overdue items, upcoming due dates, and tag distribution. Use this when the user asks 'what do I have going on?' or 'what's on my plate?'",
  "inputSchema": {
    "type": "object",
    "properties": {
      "include_overdue_details": {
        "type": "boolean",
        "default": true,
        "description": "Whether to include the list of overdue tasks in the response."
      }
    }
  }
}
```

**Response format:**
```json
{
  "counts": {
    "active": 42,
    "completed": 128,
    "overdue": 3,
    "due_today": 2,
    "due_this_week": 7,
    "in_trash": 1
  },
  "overdue_tasks": [
    { "id": "uuid", "title": "Call dentist", "due_date": "2026-02-25T00:00:00Z" }
  ],
  "due_today": [
    { "id": "uuid", "title": "Submit report", "due_date": "2026-02-27T17:00:00Z" }
  ],
  "top_tags": [
    { "name": "work", "count": 12 },
    { "name": "errands", "count": 5 }
  ],
  "recent_completions_7d": 5
}
```

---

### 11. `search_tasks`

Full-text search across tasks.

```json
{
  "name": "search_tasks",
  "description": "Search tasks by title and notes content. Returns relevance-ranked results.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Search query string."
      },
      "scope": {
        "type": "string",
        "enum": ["all", "active", "completed"],
        "default": "all",
        "description": "Which tasks to search: 'all' includes active + completed, 'active' = incomplete only, 'completed' = completed only."
      },
      "limit": {
        "type": "integer",
        "default": 20,
        "description": "Maximum results to return."
      }
    },
    "required": ["query"]
  }
}
```

---

## Edge Function Implementation Notes

### Authentication flow
1. Claude connector sends OAuth token in MCP request
2. Edge Function validates JWT via `supabase.auth.getUser(token)`
3. All queries run as the authenticated user (RLS enforced)

### SQL patterns

**list_tasks with children:**
```sql
-- Top-level tasks
SELECT t.*,
  COALESCE(json_agg(DISTINCT tg.name) FILTER (WHERE tg.name IS NOT NULL), '[]') as tags
FROM tasks t
LEFT JOIN task_tags tt ON t.id = tt.task_id
LEFT JOIN tags tg ON tt.tag_id = tg.id AND tg.deleted_at IS NULL
WHERE t.user_id = $1
  AND t.deleted_at IS NULL
  AND t.completed = false
  AND t.parent_id IS NULL
GROUP BY t.id
ORDER BY t.position;
```

**get_summary counts:**
```sql
SELECT
  COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false) as active,
  COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = true) as completed,
  COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false AND due_date < NOW()) as overdue,
  COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false AND due_date::date = CURRENT_DATE) as due_today,
  COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false AND due_date BETWEEN NOW() AND NOW() + INTERVAL '7 days') as due_this_week,
  COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as in_trash
FROM tasks
WHERE user_id = $1;
```

### Error handling

All tools should return structured errors:
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Task with ID xyz not found"
  }
}
```

Error codes: `NOT_FOUND`, `VALIDATION_ERROR`, `UNAUTHORIZED`, `INTERNAL_ERROR`, `DEPTH_EXCEEDED`

### Child completion policy [Review discussion #4]

When `update_task` sets `completed: true`, the Edge Function does **NOT** auto-complete children. Rationale: the app's `auto_complete_children` preference is in `user_settings` which is local-only and not synced. Safest default is to only complete the requested task. Claude can always explicitly complete children in a follow-up call if the user asks.

---

## Review Changelog (v1.0 → v1.1)

| Fix | Finding | Change |
|-----|---------|--------|
| Add `restore_task` tool | Review #1 | New tool #7 — nulls `deleted_at` on task + descendants |
| Enforce max depth | Review #2 | `create_task` and `update_task` reject depth > 3 |
| Fix position semantics | Review #3 | New tasks insert at position 0 (top), matching app behavior |
| Add `start_date` to create/update | Review discussion #3 | Both tools now expose `start_date` for date-range tasks |
| Add pagination | Review discussion #2 | `list_tasks` now has `offset` parameter |
| Define `recent_completions` window | Review discussion #1 | Changed to `recent_completions_7d` (7-day window) |
| Document child completion policy | Review discussion #4 | No auto-complete of children; matches safest default |

---

## Migration Checklist

1. [ ] Scaffold Edge Function: `supabase functions new mcp-server`
2. [ ] Implement MCP protocol handler (JSON-RPC over HTTPS)
3. [ ] Implement each tool handler (11 tools)
4. [ ] Add JWT validation middleware
5. [ ] Deploy: `supabase functions deploy mcp-server`
6. [ ] Register as Claude connector (Settings → Connectors → Add)
7. [ ] Test: "What's on my todo list?" from Claude chat
