import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";

export function registerGetSummary(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "get_summary",
    {
      description:
        "Get a summary overview of the user's tasks: counts by status, overdue items, upcoming due dates, and tag distribution. Use this when the user asks 'what do I have going on?' or 'what's on my plate?'",
      inputSchema: {
        include_overdue_details: z
          .boolean()
          .default(true)
          .describe(
            "Whether to include the list of overdue tasks in the response.",
          ),
      },
    },
    async ({ include_overdue_details }) => {
      try {
        // Get aggregate counts via RPC function
        const { data: counts, error: countErr } = await supabase.rpc(
          "get_task_summary",
        );

        if (countErr) return toolError("INTERNAL_ERROR", countErr.message);

        const result: Record<string, unknown> = { counts };

        // Overdue task details
        if (include_overdue_details) {
          const { data: overdue } = await supabase
            .from("tasks")
            .select("id, title, due_date")
            .is("deleted_at", null)
            .eq("completed", false)
            .lt("due_date", new Date().toISOString())
            .not("due_date", "is", null)
            .order("due_date", { ascending: true });

          result.overdue_tasks = overdue ?? [];
        }

        // Due today
        const today = new Date();
        const startOfDay = new Date(
          today.getFullYear(),
          today.getMonth(),
          today.getDate(),
        ).toISOString();
        const endOfDay = new Date(
          today.getFullYear(),
          today.getMonth(),
          today.getDate() + 1,
        ).toISOString();

        const { data: dueToday } = await supabase
          .from("tasks")
          .select("id, title, due_date")
          .is("deleted_at", null)
          .eq("completed", false)
          .gte("due_date", startOfDay)
          .lt("due_date", endOfDay)
          .order("due_date", { ascending: true });

        result.due_today = dueToday ?? [];

        // Top tags (by active task count)
        const { data: taskTags } = await supabase
          .from("task_tags")
          .select("tag_id, tags!inner(name), tasks!inner(id)")
          .is("tasks.deleted_at", null)
          .eq("tasks.completed", false);

        const tagCounts = new Map<string, number>();
        for (const tt of taskTags ?? []) {
          const name = (tt.tags as unknown as { name: string })?.name;
          if (name) tagCounts.set(name, (tagCounts.get(name) ?? 0) + 1);
        }
        result.top_tags = Array.from(tagCounts.entries())
          .sort((a, b) => b[1] - a[1])
          .slice(0, 10)
          .map(([name, count]) => ({ name, count }));

        result.recent_completions_7d = counts?.recent_completions_7d ?? 0;

        return toolSuccess(result);
      } catch (err) {
        return toolError(
          "INTERNAL_ERROR",
          err instanceof Error ? err.message : "Unknown error",
        );
      }
    },
  );
}
