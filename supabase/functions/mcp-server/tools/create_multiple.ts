import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { validateDepthForNewChild } from "../helpers/depth.ts";
import { shiftSiblingsUp } from "../helpers/position.ts";
import { insertTaskTags, resolveTagNames } from "../helpers/tags.ts";

export function registerCreateMultiple(
  server: McpServer,
  supabase: SupabaseClient,
  userId: string,
) {
  server.registerTool(
    "create_multiple_tasks",
    {
      description:
        "Create multiple tasks at once. Useful for brain dumps or batch task creation.",
      inputSchema: {
        tasks: z
          .array(
            z.object({
              title: z.string(),
              notes: z.string().optional(),
              due_date: z.string().optional(),
              is_all_day: z.boolean().default(true),
              start_date: z.string().optional(),
              parent_id: z.string().optional(),
              tags: z.array(z.string()).optional(),
            }),
          )
          .describe("Array of tasks to create."),
      },
    },
    async ({ tasks: taskInputs }) => {
      try {
        const created: Array<Record<string, unknown>> = [];

        for (const input of taskInputs) {
          // Validate depth
          if (input.parent_id) {
            const depth = await validateDepthForNewChild(
              supabase,
              input.parent_id,
            );
            if (!depth.valid) {
              return toolError(
                "DEPTH_EXCEEDED",
                `Task "${input.title}": ${depth.message}`,
              );
            }
          }

          // Shift siblings
          await shiftSiblingsUp(supabase, input.parent_id, userId);

          // Resolve tags
          const resolvedTags = await resolveTagNames(
            supabase,
            input.tags ?? [],
            userId,
          );

          // Insert task
          const taskId = crypto.randomUUID();
          const { data: task, error } = await supabase
            .from("tasks")
            .insert({
              id: taskId,
              user_id: userId,
              title: input.title.trim(),
              notes: input.notes ?? null,
              due_date: input.due_date ?? null,
              is_all_day: input.is_all_day,
              start_date: input.start_date ?? null,
              parent_id: input.parent_id ?? null,
              position: 0,
              completed: false,
            })
            .select()
            .single();

          if (error) return toolError("INTERNAL_ERROR", error.message);

          // Insert task_tags
          await insertTaskTags(supabase, taskId, resolvedTags, userId);

          created.push({
            ...task,
            tags: resolvedTags.map((t) => t.name),
          });
        }

        return toolSuccess({
          created: created.length,
          tasks: created,
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
