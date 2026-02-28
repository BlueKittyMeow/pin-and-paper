import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { formatTask } from "../helpers/format.ts";

export function registerSearchTasks(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "search_tasks",
    {
      description:
        "Search tasks by title and notes content. Returns relevance-ranked results.",
      inputSchema: {
        query: z.string().describe("Search query string."),
        scope: z
          .enum(["all", "active", "completed"])
          .default("all")
          .describe(
            "Which tasks to search: 'all' includes active + completed, 'active' = incomplete only, 'completed' = completed only.",
          ),
        limit: z
          .number()
          .int()
          .min(1)
          .max(100)
          .default(20)
          .describe("Maximum results to return."),
      },
    },
    async ({ query, scope, limit }) => {
      try {
        // Escape special PostgREST characters in the search term
        const escaped = query.replace(/%/g, "\\%").replace(/_/g, "\\_");

        let q = supabase
          .from("tasks")
          .select("*, task_tags(tags(id, name, color))", { count: "exact" })
          .is("deleted_at", null)
          .or(`title.ilike.%${escaped}%,notes.ilike.%${escaped}%`)
          .order("position", { ascending: true })
          .limit(limit);

        if (scope === "active") q = q.eq("completed", false);
        else if (scope === "completed") q = q.eq("completed", true);

        const { data, count, error } = await q;
        if (error) return toolError("INTERNAL_ERROR", error.message);

        const tasks = (data ?? []).map(formatTask);

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
