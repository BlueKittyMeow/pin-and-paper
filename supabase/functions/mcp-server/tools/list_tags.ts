import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { toolError, toolSuccess } from "../helpers/errors.ts";

export function registerListTags(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "list_tags",
    {
      description:
        "List all tags in Pin and Paper with the count of active tasks using each tag.",
      inputSchema: {},
    },
    async () => {
      try {
        // Fetch all non-deleted tags
        const { data: tags, error: tagErr } = await supabase
          .from("tags")
          .select("id, name, color")
          .is("deleted_at", null)
          .order("name", { ascending: true });

        if (tagErr) return toolError("INTERNAL_ERROR", tagErr.message);
        if (!tags?.length) return toolSuccess({ tags: [] });

        // Fetch all task_tags for active (non-deleted, incomplete) tasks
        const { data: taskTags, error: ttErr } = await supabase
          .from("task_tags")
          .select("tag_id, tasks!inner(id)")
          .is("tasks.deleted_at", null)
          .eq("tasks.completed", false);

        if (ttErr) return toolError("INTERNAL_ERROR", ttErr.message);

        // Count tasks per tag
        const countMap = new Map<string, number>();
        for (const tt of taskTags ?? []) {
          countMap.set(tt.tag_id, (countMap.get(tt.tag_id) ?? 0) + 1);
        }

        const result = tags.map((tag) => ({
          id: tag.id,
          name: tag.name,
          color: tag.color,
          task_count: countMap.get(tag.id) ?? 0,
        }));

        return toolSuccess({ tags: result });
      } catch (err) {
        return toolError(
          "INTERNAL_ERROR",
          err instanceof Error ? err.message : "Unknown error",
        );
      }
    },
  );
}
