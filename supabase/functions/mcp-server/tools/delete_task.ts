import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";

export function registerDeleteTask(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "delete_task",
    {
      description:
        "Soft-delete a task (moves to trash with 30-day retention). Children are also soft-deleted.",
      inputSchema: {
        task_id: z.string().describe("The UUID of the task to delete."),
      },
    },
    async ({ task_id }) => {
      try {
        // Verify task exists
        const { data: task } = await supabase
          .from("tasks")
          .select("id, title")
          .eq("id", task_id)
          .is("deleted_at", null)
          .single();

        if (!task) {
          return toolError("NOT_FOUND", `Task with ID ${task_id} not found`);
        }

        // Recursive soft-delete via RPC
        const { data: affected, error } = await supabase.rpc(
          "soft_delete_task_tree",
          { p_task_id: task_id },
        );

        if (error) return toolError("INTERNAL_ERROR", error.message);

        return toolSuccess({
          deleted: true,
          task_id: task_id,
          title: task.title,
          tasks_affected: affected ?? 1,
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
