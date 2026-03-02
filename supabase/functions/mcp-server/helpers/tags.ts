import { SupabaseClient } from "npm:@supabase/supabase-js@2";

/**
 * Validate a hex color string (#RRGGBB format).
 */
export function validateHexColor(color: string): boolean {
  return /^#[0-9A-Fa-f]{6}$/.test(color);
}

/**
 * Resolve an array of tag names to tag records.
 * Creates missing tags with a default color.
 */
export async function resolveTagNames(
  supabase: SupabaseClient,
  tagNames: string[],
  userId: string,
): Promise<Array<{ id: string; name: string }>> {
  if (!tagNames.length) return [];

  const results: Array<{ id: string; name: string }> = [];
  const seen = new Set<string>();

  for (const rawName of tagNames) {
    const name = rawName.trim();
    const lower = name.toLowerCase();
    if (!name || seen.has(lower)) continue;
    seen.add(lower);

    // Try to find existing tag (case-insensitive)
    const { data: existing } = await supabase
      .from("tags")
      .select("id, name")
      .ilike("name", name)
      .is("deleted_at", null)
      .limit(1)
      .single();

    if (existing) {
      results.push({ id: existing.id, name: existing.name });
    } else {
      // Create new tag with default color
      const newId = crypto.randomUUID();
      const { data: created, error } = await supabase
        .from("tags")
        .insert({
          id: newId,
          user_id: userId,
          name,
        })
        .select("id, name")
        .single();

      if (created) {
        results.push({ id: created.id, name: created.name });
      } else if (error) {
        // Tag might have been created concurrently — try fetching again
        const { data: retry } = await supabase
          .from("tags")
          .select("id, name")
          .ilike("name", name)
          .is("deleted_at", null)
          .limit(1)
          .single();
        if (retry) results.push({ id: retry.id, name: retry.name });
      }
    }
  }

  return results;
}

/**
 * Insert task_tags junction rows for a task.
 */
export async function insertTaskTags(
  supabase: SupabaseClient,
  taskId: string,
  tags: Array<{ id: string }>,
  userId: string,
): Promise<void> {
  if (!tags.length) return;

  const rows = tags.map((tag) => ({
    task_id: taskId,
    tag_id: tag.id,
    user_id: userId,
  }));

  await supabase.from("task_tags").upsert(rows, {
    onConflict: "task_id,tag_id",
    ignoreDuplicates: true,
  });
}

/**
 * Replace all tags on a task with a new set.
 */
export async function replaceTaskTags(
  supabase: SupabaseClient,
  taskId: string,
  tagNames: string[],
  userId: string,
): Promise<void> {
  // Delete all existing tags for this task
  await supabase.from("task_tags").delete().eq("task_id", taskId);

  // Resolve and insert new tags
  const tags = await resolveTagNames(supabase, tagNames, userId);
  await insertTaskTags(supabase, taskId, tags, userId);
}
