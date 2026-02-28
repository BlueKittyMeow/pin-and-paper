import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { validateDepthForNewChild } from "../helpers/depth.ts";
import { shiftSiblingsUp } from "../helpers/position.ts";
import { insertTaskTags, resolveTagNames } from "../helpers/tags.ts";

export function registerCreateTask(
  server: McpServer,
  supabase: SupabaseClient,
  userId: string,
) {
  server.registerTool(
    "create_task",
    {
      description:
        "Create a new task in Pin and Paper. Can create top-level tasks or subtasks under a parent.",
      inputSchema: {
        title: z.string().describe("The task title."),
        notes: z
          .string()
          .optional()
          .describe("Optional notes/description for the task."),
        due_date: z
          .string()
          .optional()
          .describe("Optional due date in ISO 8601 format."),
        is_all_day: z
          .boolean()
          .default(true)
          .describe("Whether the due date is all-day."),
        start_date: z
          .string()
          .optional()
          .describe("Optional start date for multi-day tasks (ISO 8601)."),
        parent_id: z
          .string()
          .optional()
          .describe("Optional parent task ID to create this as a subtask."),
        tags: z
          .array(z.string())
          .optional()
          .describe(
            "Tag names to apply. Tags are created automatically if they don't exist.",
          ),
      },
    },
    async ({ title, notes, due_date, is_all_day, start_date, parent_id, tags }) => {
      try {
        // Validate depth
        if (parent_id) {
          const depth = await validateDepthForNewChild(supabase, parent_id);
          if (!depth.valid) {
            return toolError("DEPTH_EXCEEDED", depth.message!);
          }
          // Verify parent exists
          const { data: parent } = await supabase
            .from("tasks")
            .select("id")
            .eq("id", parent_id)
            .is("deleted_at", null)
            .single();
          if (!parent) {
            return toolError("NOT_FOUND", `Parent task ${parent_id} not found`);
          }
        }

        // Shift siblings to make room at position 0
        await shiftSiblingsUp(supabase, parent_id, userId);

        // Resolve tags
        const resolvedTags = await resolveTagNames(
          supabase,
          tags ?? [],
          userId,
        );

        // Insert task
        const taskId = crypto.randomUUID();
        const { data: task, error } = await supabase
          .from("tasks")
          .insert({
            id: taskId,
            user_id: userId,
            title: title.trim(),
            notes: notes ?? null,
            due_date: due_date ?? null,
            is_all_day,
            start_date: start_date ?? null,
            parent_id: parent_id ?? null,
            position: 0,
            completed: false,
          })
          .select()
          .single();

        if (error) return toolError("INTERNAL_ERROR", error.message);

        // Insert task_tags
        await insertTaskTags(supabase, taskId, resolvedTags, userId);

        return toolSuccess({
          ...task,
          tags: resolvedTags.map((t) => t.name),
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
