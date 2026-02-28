import { SupabaseClient } from "npm:@supabase/supabase-js@2";

/** Shape a raw Supabase task row (with nested task_tags.tags) into the MCP response format. */
export function formatTask(
  row: Record<string, unknown>,
): Record<string, unknown> {
  // Extract tag names from the nested join structure
  const taskTags = (row.task_tags ?? []) as Array<{
    tags: { id: string; name: string; color: string } | null;
  }>;
  const tags = taskTags
    .map((tt) => tt.tags?.name)
    .filter((n): n is string => n != null);

  return {
    id: row.id,
    title: row.title,
    completed: row.completed,
    due_date: row.due_date,
    is_all_day: row.is_all_day,
    start_date: row.start_date,
    parent_id: row.parent_id,
    position: row.position,
    notes: row.notes,
    created_at: row.created_at,
    completed_at: row.completed_at,
    tags,
  };
}

/** Build a nested tree from a flat list of tasks. Returns only the roots (matching rootFilter). */
export function buildTaskTree(
  flatTasks: Array<Record<string, unknown>>,
  rootParentId: string | null = null,
): Array<Record<string, unknown>> {
  const formatted = flatTasks.map(formatTask);
  const byId = new Map<string, Record<string, unknown>>();
  for (const t of formatted) {
    byId.set(t.id as string, { ...t, children: [] });
  }

  const roots: Array<Record<string, unknown>> = [];
  for (const t of byId.values()) {
    const parentId = t.parent_id as string | null;
    if (parentId === rootParentId) {
      roots.push(t);
    } else if (parentId && byId.has(parentId)) {
      (byId.get(parentId)!.children as Array<Record<string, unknown>>).push(t);
    } else {
      // Orphan (parent not in result set) — treat as root
      roots.push(t);
    }
  }

  return roots;
}

/** Fetch the parent chain (breadcrumb) from a task up to the root. */
export async function fetchParentChain(
  supabase: SupabaseClient,
  taskId: string,
): Promise<Array<{ id: string; title: string }>> {
  const chain: Array<{ id: string; title: string }> = [];
  let currentId: string | null = taskId;

  // Walk up — max 4 levels
  for (let i = 0; i < 4 && currentId; i++) {
    const { data } = await supabase
      .from("tasks")
      .select("id, title, parent_id")
      .eq("id", currentId)
      .single();
    if (!data) break;
    if (data.id !== taskId) {
      chain.unshift({ id: data.id, title: data.title });
    }
    currentId = data.parent_id;
  }

  return chain;
}
