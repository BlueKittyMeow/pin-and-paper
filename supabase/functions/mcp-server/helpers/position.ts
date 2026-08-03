import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

/**
 * Smallest position among non-deleted siblings, defaulting to 1 when there
 * are none — the PostgREST equivalent of the app's
 * `SELECT COALESCE(MIN(position), 1) FROM tasks WHERE ... AND deleted_at IS NULL`.
 *
 * New-task-top-insert: the list is ordered by position ascending, so new
 * tasks go at MIN - 1 (going negative over time). Single-row write, no
 * sibling shifting, no sync churn (see docs/specs/new-task-top-insert.md
 * and review finding M-1).
 */
export async function minSiblingPosition(
  supabase: SupabaseClient,
  parentId: string | null | undefined,
  userId: string,
): Promise<number> {
  let query = supabase
    .from("tasks")
    .select("position")
    .eq("user_id", userId)
    .is("deleted_at", null);
  query = parentId ? query.eq("parent_id", parentId) : query.is("parent_id", null);
  const { data, error } = await query
    .order("position", { ascending: true })
    .limit(1);
  if (error) throw new Error(error.message);
  return data && data.length > 0 ? (data[0].position as number) : 1;
}

/**
 * Position for a single new task: above the current minimum among its
 * non-deleted siblings, so it appears at the top of the list.
 */
export async function topInsertPosition(
  supabase: SupabaseClient,
  parentId: string | null | undefined,
  userId: string,
): Promise<number> {
  return (await minSiblingPosition(supabase, parentId, userId)) - 1;
}

/**
 * Positions for a batch of new tasks, in input order. For each distinct
 * parent, its n new siblings take MIN - n .. MIN - 1, so the batch displays
 * in the given order at the top of that parent's list (mirrors the app's
 * `TaskService.createMultipleTasks`).
 *
 * Minimums are queried before any insert, so a batch item whose parent is
 * itself created earlier in the same batch simply starts from the empty-list
 * default (positions 1 - n .. 0).
 */
export async function planBatchPositions(
  supabase: SupabaseClient,
  parentIds: Array<string | null>,
  userId: string,
): Promise<number[]> {
  const counts = new Map<string | null, number>();
  for (const parentId of parentIds) {
    counts.set(parentId, (counts.get(parentId) ?? 0) + 1);
  }

  const next = new Map<string | null, number>();
  for (const [parentId, count] of counts) {
    const min = await minSiblingPosition(supabase, parentId, userId);
    next.set(parentId, min - count);
  }

  return parentIds.map((parentId) => {
    const position = next.get(parentId)!;
    next.set(parentId, position + 1);
    return position;
  });
}
