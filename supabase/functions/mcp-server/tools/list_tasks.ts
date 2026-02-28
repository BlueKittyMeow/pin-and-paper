import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { buildTaskTree, formatTask } from "../helpers/format.ts";

export function registerListTasks(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "list_tasks",
    {
      description:
        "List the user's tasks from Pin and Paper. Returns active (non-deleted) tasks by default. Supports filtering by completion status, tags, due dates, and search.",
      inputSchema: {
        status: z
          .enum(["active", "completed", "all", "deleted"])
          .default("active")
          .describe(
            "Filter by task status. 'active' = incomplete and not deleted, 'completed' = done, 'all' = active + completed, 'deleted' = soft-deleted (trash).",
          ),
        tag: z
          .string()
          .optional()
          .describe("Filter to tasks with this tag name (case-insensitive)."),
        due: z
          .enum(["overdue", "today", "this_week", "no_date"])
          .optional()
          .describe("Filter by due date."),
        search: z
          .string()
          .optional()
          .describe("Search tasks by title or notes (case-insensitive)."),
        parent_id: z
          .string()
          .optional()
          .describe(
            "List only children of this task ID. Omit for top-level tasks.",
          ),
        include_children: z
          .boolean()
          .default(true)
          .describe("Whether to include subtasks nested under their parents."),
        limit: z
          .number()
          .int()
          .min(1)
          .max(200)
          .default(50)
          .describe("Maximum number of tasks to return."),
        offset: z
          .number()
          .int()
          .min(0)
          .default(0)
          .describe("Number of tasks to skip (for pagination)."),
      },
    },
    async ({
      status,
      tag,
      due,
      search,
      parent_id,
      include_children,
      limit,
      offset,
    }) => {
      try {
        // If filtering by tag, resolve tag name to IDs first
        let tagTaskIds: string[] | null = null;
        if (tag) {
          const { data: matchingTags } = await supabase
            .from("tags")
            .select("id")
            .ilike("name", tag)
            .is("deleted_at", null);

          if (!matchingTags?.length) {
            return toolSuccess({
              tasks: [],
              total_count: 0,
              returned_count: 0,
            });
          }

          const tagIds = matchingTags.map(
            (t: Record<string, unknown>) => t.id as string,
          );
          const { data: tagLinks } = await supabase
            .from("task_tags")
            .select("task_id")
            .in("tag_id", tagIds);

          tagTaskIds = (tagLinks ?? []).map(
            (tl: Record<string, unknown>) => tl.task_id as string,
          );
          if (!tagTaskIds.length) {
            return toolSuccess({
              tasks: [],
              total_count: 0,
              returned_count: 0,
            });
          }
        }

        // Build base query
        let q = supabase
          .from("tasks")
          .select("*, task_tags(tags(id, name, color))", { count: "exact" });

        // Status filter
        switch (status) {
          case "active":
            q = q.is("deleted_at", null).eq("completed", false);
            break;
          case "completed":
            q = q.is("deleted_at", null).eq("completed", true);
            break;
          case "all":
            q = q.is("deleted_at", null);
            break;
          case "deleted":
            q = q.not("deleted_at", "is", null);
            break;
        }

        // Tag filter (already resolved to task IDs)
        if (tagTaskIds) {
          q = q.in("id", tagTaskIds);
        }

        // Due date filters
        if (due) {
          const now = new Date();
          switch (due) {
            case "overdue":
              q = q.lt("due_date", now.toISOString()).not("due_date", "is", null);
              break;
            case "today": {
              const start = new Date(
                now.getFullYear(),
                now.getMonth(),
                now.getDate(),
              ).toISOString();
              const end = new Date(
                now.getFullYear(),
                now.getMonth(),
                now.getDate() + 1,
              ).toISOString();
              q = q.gte("due_date", start).lt("due_date", end);
              break;
            }
            case "this_week": {
              const weekEnd = new Date(
                now.getTime() + 7 * 24 * 60 * 60 * 1000,
              ).toISOString();
              q = q
                .gte("due_date", now.toISOString())
                .lt("due_date", weekEnd);
              break;
            }
            case "no_date":
              q = q.is("due_date", null);
              break;
          }
        }

        // Search filter
        if (search) {
          const escaped = search.replace(/%/g, "\\%").replace(/_/g, "\\_");
          q = q.or(`title.ilike.%${escaped}%,notes.ilike.%${escaped}%`);
        }

        // Parent filter — if include_children is false or parent_id is set
        if (parent_id !== undefined) {
          q = q.eq("parent_id", parent_id);
        } else if (!include_children) {
          q = q.is("parent_id", null);
        }

        // Order and paginate
        q = q
          .order("position", { ascending: true })
          .range(offset, offset + limit - 1);

        const { data, count, error } = await q;
        if (error) return toolError("INTERNAL_ERROR", error.message);

        let tasks: Array<Record<string, unknown>>;

        if (include_children && parent_id === undefined) {
          // Fetch all tasks and build tree, then take only the roots in the page
          // For efficiency, we already have the paginated top-level tasks.
          // Now fetch their descendants.
          const topLevel = data ?? [];
          if (topLevel.length > 0) {
            const topIds = topLevel.map(
              (t: Record<string, unknown>) => t.id as string,
            );
            const allTasks = [...topLevel];

            // Fetch children iteratively (max 3 more levels)
            let parentIds = topIds;
            for (let depth = 0; depth < 3 && parentIds.length > 0; depth++) {
              const { data: children } = await supabase
                .from("tasks")
                .select("*, task_tags(tags(id, name, color))")
                .in("parent_id", parentIds)
                .is("deleted_at", null)
                .order("position", { ascending: true });
              if (!children?.length) break;
              allTasks.push(...children);
              parentIds = children.map(
                (c: Record<string, unknown>) => c.id as string,
              );
            }

            tasks = buildTaskTree(allTasks, null);
          } else {
            tasks = [];
          }
        } else {
          tasks = (data ?? []).map(formatTask);
        }

        return toolSuccess({
          tasks,
          total_count: count ?? tasks.length,
          returned_count: tasks.length,
        });
      } catch (err) {
        return toolError(
          "INTERNAL_ERROR",
          err instanceof Error ? err.message : "Unknown error",
        );
      }
    },
  );
}
