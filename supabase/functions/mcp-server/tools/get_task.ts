import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { buildTaskTree, fetchParentChain, formatTask } from "../helpers/format.ts";

export function registerGetTask(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "get_task",
    {
      description:
        "Get detailed information about a specific task, including its tags, notes, subtasks, and parent chain.",
      inputSchema: {
        task_id: z.string().describe("The UUID of the task to retrieve."),
      },
    },
    async ({ task_id }) => {
      try {
        // Fetch the task with tags
        const { data: task, error } = await supabase
          .from("tasks")
          .select("*, task_tags(tags(id, name, color))")
          .eq("id", task_id)
          .single();

        if (error || !task) {
          return toolError("NOT_FOUND", `Task with ID ${task_id} not found`);
        }

        const formatted = formatTask(task);

        // Fetch children (all descendants under this task)
        const { data: descendants } = await supabase
          .from("tasks")
          .select("*, task_tags(tags(id, name, color))")
          .eq("parent_id", task_id)
          .is("deleted_at", null)
          .order("position", { ascending: true });

        // Build children tree recursively — fetch deeper levels if needed
        if (descendants?.length) {
          const allChildren = [...descendants];
          // Fetch up to 2 more levels of depth
          let parentIds = descendants.map(
            (d: Record<string, unknown>) => d.id as string,
          );
          for (let depth = 0; depth < 2 && parentIds.length > 0; depth++) {
            const { data: deeper } = await supabase
              .from("tasks")
              .select("*, task_tags(tags(id, name, color))")
              .in("parent_id", parentIds)
              .is("deleted_at", null)
              .order("position", { ascending: true });
            if (!deeper?.length) break;
            allChildren.push(...deeper);
            parentIds = deeper.map(
              (d: Record<string, unknown>) => d.id as string,
            );
          }
          formatted.children = buildTaskTree(allChildren, task_id);
        } else {
          formatted.children = [];
        }

        // Fetch parent chain (breadcrumb)
        formatted.parent_chain = await fetchParentChain(supabase, task_id);

        return toolSuccess(formatted);
      } catch (err) {
        return toolError(
          "INTERNAL_ERROR",
          err instanceof Error ? err.message : "Unknown error",
        );
      }
    },
  );
}
