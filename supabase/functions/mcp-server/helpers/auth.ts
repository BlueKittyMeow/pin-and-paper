import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

/**
 * Create a Supabase client that carries the user's JWT.
 * All queries through this client enforce RLS automatically.
 */
export function createAuthClient(authHeader: string): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
}
