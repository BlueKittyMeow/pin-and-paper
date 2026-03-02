import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@^4.1.13";
import { toolError, toolSuccess } from "../helpers/errors.ts";
import { validateHexColor } from "../helpers/tags.ts";

export function registerUpdateTag(
  server: McpServer,
  supabase: SupabaseClient,
  _userId: string,
) {
  server.registerTool(
    "update_tag",
    {
      description:
        "Update a tag's name and/or color. Accepts any valid #RRGGBB hex color — use preset colors from list_tags for consistency, or any custom hex value.",
      inputSchema: {
        tag_id: z.string().describe("The UUID of the tag to update."),
        name: z.string().optional().describe("New name for the tag."),
        color: z
          .string()
          .optional()
          .describe(
            "New color as hex code (e.g. '#FF5722'). Accepts ANY valid #RRGGBB hex — not limited to presets.",
          ),
      },
    },
    async ({ tag_id, name, color }) => {
      try {
        // Validate at least one field provided
        if (!name && !color) {
          return toolError(
            "VALIDATION_ERROR",
            "At least one field (name or color) must be provided.",
          );
        }

        // Validate hex format if color provided
        if (color && !validateHexColor(color)) {
          return toolError(
            "VALIDATION_ERROR",
            `Invalid color format: "${color}". Must be #RRGGBB hex (e.g. "#FF5722").`,
          );
        }

        // Trim and validate name if provided
        const trimmedName = name?.trim();
        if (trimmedName !== undefined && trimmedName.length === 0) {
          return toolError("VALIDATION_ERROR", "Tag name cannot be empty.");
        }
        if (trimmedName && trimmedName.length > 250) {
          return toolError(
            "VALIDATION_ERROR",
            "Tag name must be 250 characters or less.",
          );
        }

        // Build update object
        const updates: Record<string, unknown> = {
          updated_at: new Date().toISOString(),
        };
        if (trimmedName) updates.name = trimmedName;
        if (color) updates.color = color;

        // Update tag — RLS ensures user can only update their own tags
        const { data, error } = await supabase
          .from("tags")
          .update(updates)
          .eq("id", tag_id)
          .is("deleted_at", null)
          .select("id, name, color, created_at, updated_at")
          .single();

        if (error) {
          // Check for UNIQUE constraint violation (Postgres error code 23505)
          if (error.code === "23505") {
            return toolError(
              "DUPLICATE_NAME",
              `A tag with the name "${trimmedName}" already exists.`,
            );
          }
          // No rows matched (tag not found or deleted)
          if (error.code === "PGRST116") {
            return toolError(
              "NOT_FOUND",
              `Tag with ID "${tag_id}" not found.`,
            );
          }
          return toolError("INTERNAL_ERROR", error.message);
        }

        return toolSuccess({
          tag: data,
          message: `Tag "${data.name}" updated successfully.`,
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
