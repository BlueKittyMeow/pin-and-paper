import { SupabaseClient } from "npm:@supabase/supabase-js@2";

/**
 * Shift all sibling positions up by 1 to make room at position 0.
 * Uses the shift_sibling_positions PostgreSQL function for atomicity.
 */
export async function shiftSiblingsUp(
  supabase: SupabaseClient,
  parentId: string | null | undefined,
  userId: string,
): Promise<void> {
  await supabase.rpc("shift_sibling_positions", {
    p_parent_id: parentId ?? null,
    p_user_id: userId,
  });
}
