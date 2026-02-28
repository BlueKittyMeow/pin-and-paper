import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { validateDepthForMove } from "../helpers/depth.ts";
import { shiftSiblingsUp } from "../helpers/position.ts";
import { replaceTaskTags } from "../helpers/tags.ts";
import { formatTask } from "../helpers/format.ts";

export function registerUpdateTask(
  server: McpServer,
  supabase: SupabaseClient,
  userId: string,
) {
  server.registerTool(
    "update_task",
    {
      description:
        "Update one or more properties of an existing task. Only include fields you want to change.",
      inputSchema: {
        task_id: z.string().describe("The UUID of the task to update."),
        title: z.string().optional().describe("New title for the task."),
        notes: z
          .string()
          .optional()
          .describe("New notes/description. Set to empty string to clear."),
        due_date: z
          .string()
          .nullable()
          .optional()
          .describe("New due date (ISO 8601) or null to remove."),
        is_all_day: z
          .boolean()
          .optional()
          .describe("Whether the due date is all-day."),
        start_date: z
          .string()
          .nullable()
          .optional()
          .describe("Start date (ISO 8601) or null to remove."),
        completed: z
          .boolean()
          .optional()
          .describe("Set to true to complete, false to uncomplete."),
        parent_id: z
          .string()
          .nullable()
          .optional()
          .describe("Move task under a new parent, or null for top-level."),
        tags: z
          .array(z.string())
          .optional()
          .describe(
            "Replace all tags with this list. Tags created automatically if they don't exist.",
          ),
      },
    },
    async ({
      task_id,
      title,
      notes,
      due_date,
      is_all_day,
      start_date,
      completed,
      parent_id,
      tags,
    }) => {
      try {
        // Fetch current task
        const { data: current, error: fetchErr } = await supabase
          .from("tasks")
          .select("*, task_tags(tags(id, name, color))")
          .eq("id", task_id)
          .single();

        if (fetchErr || !current) {
          return toolError("NOT_FOUND", `Task with ID ${task_id} not found`);
        }

        const updates: Record<string, unknown> = {};

        // Simple field updates
        if (title !== undefined) updates.title = title.trim();
        if (notes !== undefined) updates.notes = notes || null;
        if (due_date !== undefined) updates.due_date = due_date;
        if (is_all_day !== undefined) updates.is_all_day = is_all_day;
        if (start_date !== undefined) updates.start_date = start_date;

        // Completion toggling
        if (completed !== undefined && completed !== current.completed) {
          if (completed) {
            updates.completed = true;
            updates.completed_at = new Date().toISOString();
            updates.position_before_completion = current.position;
          } else {
            updates.completed = false;
            updates.completed_at = null;
            // Restore previous position if available
            if (current.position_before_completion != null) {
              updates.position = current.position_before_completion;
            }
            updates.position_before_completion = null;
          }
        }

        // Parent change (move)
        if (parent_id !== undefined && parent_id !== current.parent_id) {
          // Validate depth
          const depthCheck = await validateDepthForMove(
            supabase,
            task_id,
            parent_id,
          );
          if (!depthCheck.valid) {
            return toolError("DEPTH_EXCEEDED", depthCheck.message!);
          }

          // Verify new parent exists (if not null)
          if (parent_id) {
            const { data: newParent } = await supabase
              .from("tasks")
              .select("id")
              .eq("id", parent_id)
              .is("deleted_at", null)
              .single();
            if (!newParent) {
              return toolError(
                "NOT_FOUND",
                `Parent task ${parent_id} not found`,
              );
            }
          }

          // Shift siblings at new parent to make room at position 0
          await shiftSiblingsUp(supabase, parent_id, userId);
          updates.parent_id = parent_id;
          updates.position = 0;
        }

        // Apply updates
        if (Object.keys(updates).length > 0) {
          const { error: updateErr } = await supabase
            .from("tasks")
            .update(updates)
            .eq("id", task_id);

          if (updateErr) {
            return toolError("INTERNAL_ERROR", updateErr.message);
          }
        }

        // Tag replacement
        if (tags !== undefined) {
          await replaceTaskTags(supabase, task_id, tags, userId);
        }

        // Fetch and return updated task
        const { data: updated } = await supabase
          .from("tasks")
          .select("*, task_tags(tags(id, name, color))")
          .eq("id", task_id)
          .single();

        return toolSuccess(formatTask(updated ?? current));
      } catch (err) {
        return toolError(
          "INTERNAL_ERROR",
          err instanceof Error ? err.message : "Unknown error",
        );
      }
    },
  );
}
