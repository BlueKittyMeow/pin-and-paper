import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { McpServer } from "npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js";
import { WebStandardStreamableHTTPServerTransport } from "npm:@modelcontextprotocol/sdk@1.25.3/server/webStandardStreamableHttp.js";
import { Hono } from "npm:hono@^4.9.7";
import { createAuthClient } from "./helpers/auth.ts";

// Tool registrations
import { registerListTags } from "./tools/list_tags.ts";
import { registerGetSummary } from "./tools/get_summary.ts";
import { registerSearchTasks } from "./tools/search_tasks.ts";
import { registerGetTask } from "./tools/get_task.ts";
import { registerListTasks } from "./tools/list_tasks.ts";
import { registerCreateTask } from "./tools/create_task.ts";
import { registerCreateMultiple } from "./tools/create_multiple.ts";
import { registerUpdateTask } from "./tools/update_task.ts";
import { registerDeleteTask } from "./tools/delete_task.ts";
import { registerRestoreTask } from "./tools/restore_task.ts";
import { registerManageTags } from "./tools/manage_tags.ts";

const app = new Hono().basePath("/mcp-server");

app.all("*", async (c) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader) {
    return c.json(
      {
        jsonrpc: "2.0",
        error: { code: -32600, message: "Missing Authorization header" },
        id: null,
      },
      401,
    );
  }

  const supabase = createAuthClient(authHeader);

  // Validate the JWT and get user info
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || !user) {
    return c.json(
      {
        jsonrpc: "2.0",
        error: { code: -32600, message: "Invalid or expired token" },
        id: null,
      },
      401,
    );
  }

  // Create a fresh MCP server per request (stateless, clean closure over auth)
  const server = new McpServer({
    name: "pin-and-paper",
    version: "1.0.0",
  });

  // Register all 11 tools, each closing over the authenticated client
  registerListTags(server, supabase, user.id);
  registerGetSummary(server, supabase, user.id);
  registerSearchTasks(server, supabase, user.id);
  registerGetTask(server, supabase, user.id);
  registerListTasks(server, supabase, user.id);
  registerCreateTask(server, supabase, user.id);
  registerCreateMultiple(server, supabase, user.id);
  registerUpdateTask(server, supabase, user.id);
  registerDeleteTask(server, supabase, user.id);
  registerRestoreTask(server, supabase, user.id);
  registerManageTags(server, supabase, user.id);

  const transport = new WebStandardStreamableHTTPServerTransport();
  await server.connect(transport);
  return transport.handleRequest(c.req.raw);
});

Deno.serve(app.fetch);
