import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { insertTaskTags, resolveTagNames } from "../helpers/tags.ts";

export function registerManageTags(
  server: McpServer,
  supabase: SupabaseClient,
  userId: string,
) {
  server.registerTool(
    "manage_tags",
    {
      description:
        "Add or remove specific tags on a task without affecting other existing tags.",
      inputSchema: {
        task_id: z.string().describe("The UUID of the task."),
        add: z
          .array(z.string())
          .optional()
          .describe(
            "Tag names to add. Created automatically if they don't exist.",
          ),
        remove: z
          .array(z.string())
          .optional()
          .describe("Tag names to remove from the task."),
      },
    },
    async ({ task_id, add, remove }) => {
      try {
        // Verify task exists
        const { data: task } = await supabase
          .from("tasks")
          .select("id")
          .eq("id", task_id)
          .is("deleted_at", null)
          .single();

        if (!task) {
          return toolError("NOT_FOUND", `Task with ID ${task_id} not found`);
        }

        // Add tags
        if (add?.length) {
          const resolved = await resolveTagNames(supabase, add, userId);
          await insertTaskTags(supabase, task_id, resolved, userId);
        }

        // Remove tags
        if (remove?.length) {
          // Find tag IDs by name
          for (const tagName of remove) {
            const { data: tag } = await supabase
              .from("tags")
              .select("id")
              .ilike("name", tagName.trim())
              .is("deleted_at", null)
              .limit(1)
              .single();

            if (tag) {
              await supabase
                .from("task_tags")
                .delete()
                .eq("task_id", task_id)
                .eq("tag_id", tag.id);
            }
          }
        }

        // Return updated tag list
        const { data: currentTags } = await supabase
          .from("task_tags")
          .select("tags(id, name, color)")
          .eq("task_id", task_id);

        const tagList = (currentTags ?? [])
          .map(
            (tt: Record<string, unknown>) =>
              (tt.tags as { name: string } | null)?.name,
          )
          .filter((n): n is string => n != null);

        return toolSuccess({
          task_id,
          tags: tagList,
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
