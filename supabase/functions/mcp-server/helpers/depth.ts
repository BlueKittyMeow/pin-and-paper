import { SupabaseClient } from "npm:@supabase/supabase-js@2";

const MAX_DEPTH = 3; // 4 levels: 0, 1, 2, 3

/**
 * Walk the parent chain from parentId to root.
 * Returns the depth of parentId (0 = top-level).
 */
export async function getParentDepth(
  supabase: SupabaseClient,
  parentId: string,
): Promise<number> {
  let depth = 0;
  let currentId: string | null = parentId;

  for (let i = 0; i < MAX_DEPTH + 1 && currentId; i++) {
    const { data } = await supabase
      .from("tasks")
      .select("parent_id")
      .eq("id", currentId)
      .single();
    if (!data) break;
    if (data.parent_id) {
      depth++;
      currentId = data.parent_id;
    } else {
      break;
    }
  }

  return depth;
}

/**
 * Validate that a new child under parentId would not exceed max depth.
 * Returns true if the insert is valid.
 */
export async function validateDepthForNewChild(
  supabase: SupabaseClient,
  parentId: string | null | undefined,
): Promise<{ valid: boolean; message?: string }> {
  if (!parentId) return { valid: true };

  const parentDepth = await getParentDepth(supabase, parentId);
  // New child would be at parentDepth + 1
  if (parentDepth + 1 > MAX_DEPTH) {
    return {
      valid: false,
      message: `Maximum nesting depth (${MAX_DEPTH + 1} levels) would be exceeded`,
    };
  }
  return { valid: true };
}

/**
 * Validate that moving a task (with its descendants) under newParentId
 * would not exceed max depth.
 */
export async function validateDepthForMove(
  supabase: SupabaseClient,
  taskId: string,
  newParentId: string | null | undefined,
): Promise<{ valid: boolean; message?: string }> {
  if (!newParentId) return { valid: true }; // Moving to top-level is always valid

  // Get depth of new parent
  const parentDepth = await getParentDepth(supabase, newParentId);

  // Get max depth of the task's own descendants via RPC
  const { data: maxChildDepth } = await supabase.rpc(
    "get_descendant_max_depth",
    { p_task_id: taskId },
  );

  // Task itself would be at parentDepth + 1
  // Its deepest descendant would be at parentDepth + 1 + maxChildDepth
  const deepest = parentDepth + 1 + (maxChildDepth ?? 0);
  if (deepest > MAX_DEPTH) {
    return {
      valid: false,
      message: `Moving this task would exceed maximum nesting depth (${MAX_DEPTH + 1} levels)`,
    };
  }
  return { valid: true };
}
