import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";

export function registerRestoreTask(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "restore_task",
    {
      description:
        "Restore a soft-deleted task from trash. Also restores any children that were deleted at the same time.",
      inputSchema: {
        task_id: z.string().describe("The UUID of the task to restore."),
      },
    },
    async ({ task_id }) => {
      try {
        // Verify task exists and is deleted
        const { data: task } = await supabase
          .from("tasks")
          .select("id, title, deleted_at")
          .eq("id", task_id)
          .not("deleted_at", "is", null)
          .single();

        if (!task) {
          return toolError(
            "NOT_FOUND",
            `Deleted task with ID ${task_id} not found`,
          );
        }

        // Recursive restore via RPC (restores descendants with matching deleted_at ±1s)
        const { data: affected, error } = await supabase.rpc(
          "restore_task_tree",
          { p_task_id: task_id },
        );

        if (error) return toolError("INTERNAL_ERROR", error.message);

        return toolSuccess({
          restored: true,
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
