/**
 * Pin and Paper — OAuth Proxy for MCP Connector
 *
 * Cloudflare Worker that sits between Claude and the Supabase Edge Function.
 * Handles OAuth 2.0 + PKCE at the domain root (which Supabase can't serve)
 * and proxies MCP traffic to the Edge Function.
 */

interface Env {
  MCP_OAUTH: KVNamespace;
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
}

const SUPABASE_FUNCTION_URL =
  "https://qasieyfuspuoauffochm.supabase.co/functions/v1/mcp-server";

const ALLOWED_REDIRECT_URIS = [
  "https://claude.ai/api/mcp/auth_callback",
  "https://claude.com/api/mcp/auth_callback",
  "http://localhost:6274/oauth/callback",
];

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    try {
      // OAuth endpoints
      if (path === "/.well-known/oauth-authorization-server") {
        return handleMetadata(url);
      }
      if (path === "/authorize") {
        return handleAuthorize(url, env);
      }
      if (path === "/oauth/callback") {
        return handleOAuthCallback(url, env);
      }
      if (path === "/token" && request.method === "POST") {
        return handleToken(request, env);
      }
      if (path === "/register" && request.method === "POST") {
        return handleRegister(request, env);
      }
      if (path === "/icon.png") {
        return handleIcon();
      }

      // Everything else: proxy MCP traffic to Supabase Edge Function
      return handleMcpProxy(request, env);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Internal error";
      return jsonResponse({ error: message }, 500);
    }
  },
} satisfies ExportedHandler<Env>;

// ═══════════════════════════════════════
// 1. OAuth Metadata
// ═══════════════════════════════════════

function handleMetadata(url: URL): Response {
  const origin = url.origin;
  return jsonResponse({
    issuer: origin,
    authorization_endpoint: `${origin}/authorize`,
    token_endpoint: `${origin}/token`,
    registration_endpoint: `${origin}/register`,
    response_types_supported: ["code"],
    grant_types_supported: ["authorization_code", "refresh_token"],
    token_endpoint_auth_methods_supported: ["none", "client_secret_post"],
    code_challenge_methods_supported: ["S256"],
    scopes_supported: ["openid", "profile", "email"],
  });
}

// ═══════════════════════════════════════
// 2. Authorize — redirect to Google OAuth
// ═══════════════════════════════════════

async function handleAuthorize(url: URL, env: Env): Promise<Response> {
  const clientId = url.searchParams.get("client_id") ?? "";
  const redirectUri = url.searchParams.get("redirect_uri") ?? "";
  const codeChallenge = url.searchParams.get("code_challenge") ?? "";
  const codeChallengeMethod = url.searchParams.get("code_challenge_method");
  const state = url.searchParams.get("state") ?? "";
  const scope = url.searchParams.get("scope") ?? "";

  // Validate redirect URI
  if (!ALLOWED_REDIRECT_URIS.includes(redirectUri)) {
    return jsonResponse({ error: "Invalid redirect_uri" }, 400);
  }

  // Validate PKCE
  if (codeChallengeMethod && codeChallengeMethod !== "S256") {
    return jsonResponse(
      { error: "Only S256 code_challenge_method is supported" },
      400,
    );
  }

  // Store session params in KV (5-min TTL)
  const sessionKey = crypto.randomUUID();
  await env.MCP_OAUTH.put(
    `session:${sessionKey}`,
    JSON.stringify({ clientId, redirectUri, codeChallenge, state, scope }),
    { expirationTtl: 300 },
  );

  // Redirect to Google OAuth
  const googleAuthUrl = new URL(
    "https://accounts.google.com/o/oauth2/v2/auth",
  );
  googleAuthUrl.searchParams.set("client_id", env.GOOGLE_CLIENT_ID);
  googleAuthUrl.searchParams.set(
    "redirect_uri",
    `${url.origin}/oauth/callback`,
  );
  googleAuthUrl.searchParams.set("response_type", "code");
  googleAuthUrl.searchParams.set("scope", "email profile openid");
  googleAuthUrl.searchParams.set("state", sessionKey);
  googleAuthUrl.searchParams.set("access_type", "offline");
  googleAuthUrl.searchParams.set("prompt", "consent");

  return Response.redirect(googleAuthUrl.toString(), 302);
}

// ═══════════════════════════════════════
// 3. OAuth Callback — exchange Google code for Supabase JWT
// ═══════════════════════════════════════

async function handleOAuthCallback(url: URL, env: Env): Promise<Response> {
  const googleCode = url.searchParams.get("code");
  const sessionKey = url.searchParams.get("state");
  const error = url.searchParams.get("error");

  if (error) {
    return jsonResponse({ error: `Google OAuth error: ${error}` }, 400);
  }
  if (!googleCode || !sessionKey) {
    return jsonResponse({ error: "Missing code or state" }, 400);
  }

  // Retrieve original session params
  const sessionData = await env.MCP_OAUTH.get(`session:${sessionKey}`);
  if (!sessionData) {
    return jsonResponse({ error: "Session expired or invalid" }, 400);
  }
  const session = JSON.parse(sessionData) as {
    clientId: string;
    redirectUri: string;
    codeChallenge: string;
    state: string;
  };

  // Exchange Google code for Google tokens
  const googleTokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      code: googleCode,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: `${url.origin}/oauth/callback`,
      grant_type: "authorization_code",
    }),
  });

  if (!googleTokenRes.ok) {
    const text = await googleTokenRes.text();
    return jsonResponse(
      { error: "Failed to exchange Google code", details: text },
      502,
    );
  }

  const googleTokens = (await googleTokenRes.json()) as {
    id_token: string;
    access_token: string;
  };

  // Exchange Google id_token for Supabase JWT
  const supabaseTokenRes = await fetch(
    `${env.SUPABASE_URL}/auth/v1/token?grant_type=id_token`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: env.SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({
        provider: "google",
        id_token: googleTokens.id_token,
      }),
    },
  );

  if (!supabaseTokenRes.ok) {
    const text = await supabaseTokenRes.text();
    return jsonResponse(
      { error: "Failed to exchange with Supabase", details: text },
      502,
    );
  }

  const supabaseTokens = (await supabaseTokenRes.json()) as {
    access_token: string;
    refresh_token: string;
    expires_in: number;
  };

  // Generate a short-lived authorization code
  const authCode = crypto.randomUUID();
  await env.MCP_OAUTH.put(
    `auth_code:${authCode}`,
    JSON.stringify({
      accessToken: supabaseTokens.access_token,
      refreshToken: supabaseTokens.refresh_token,
      expiresIn: supabaseTokens.expires_in,
      codeChallenge: session.codeChallenge,
      clientId: session.clientId,
    }),
    { expirationTtl: 300 },
  );

  // Clean up session
  await env.MCP_OAUTH.delete(`session:${sessionKey}`);

  // Redirect back to Claude with the authorization code
  const callbackUrl = new URL(session.redirectUri);
  callbackUrl.searchParams.set("code", authCode);
  callbackUrl.searchParams.set("state", session.state);

  return Response.redirect(callbackUrl.toString(), 302);
}

// ═══════════════════════════════════════
// 4. Token Exchange
// ═══════════════════════════════════════

async function handleToken(request: Request, env: Env): Promise<Response> {
  let params: URLSearchParams;

  const contentType = request.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    const body = (await request.json()) as Record<string, string>;
    params = new URLSearchParams(body);
  } else {
    params = new URLSearchParams(await request.text());
  }

  const grantType = params.get("grant_type");

  // ── Refresh token flow ──
  if (grantType === "refresh_token") {
    const refreshToken = params.get("refresh_token");
    if (!refreshToken) {
      return jsonResponse({ error: "missing_refresh_token" }, 400);
    }

    const res = await fetch(
      `${env.SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: env.SUPABASE_ANON_KEY,
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      },
    );

    if (!res.ok) {
      const text = await res.text();
      return jsonResponse(
        { error: "refresh_failed", details: text },
        res.status,
      );
    }

    const tokens = (await res.json()) as {
      access_token: string;
      refresh_token: string;
      expires_in: number;
    };

    return jsonResponse(
      {
        access_token: tokens.access_token,
        token_type: "Bearer",
        expires_in: tokens.expires_in,
        refresh_token: tokens.refresh_token,
      },
      200,
      { "Cache-Control": "no-store" },
    );
  }

  // ── Authorization code flow ──
  if (grantType !== "authorization_code") {
    return jsonResponse({ error: "unsupported_grant_type" }, 400);
  }

  const code = params.get("code");
  const codeVerifier = params.get("code_verifier");
  const clientId = params.get("client_id");

  if (!code) {
    return jsonResponse({ error: "missing_code" }, 400);
  }

  // Look up auth code
  const stored = await env.MCP_OAUTH.get(`auth_code:${code}`);
  if (!stored) {
    return jsonResponse({ error: "invalid_grant" }, 400);
  }

  const data = JSON.parse(stored) as {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
    codeChallenge: string;
    clientId: string;
  };

  // Delete auth code immediately (single use)
  await env.MCP_OAUTH.delete(`auth_code:${code}`);

  // Validate client_id
  if (clientId && clientId !== data.clientId) {
    return jsonResponse({ error: "invalid_client" }, 400);
  }

  // Validate PKCE
  if (data.codeChallenge && codeVerifier) {
    const encoder = new TextEncoder();
    const digest = await crypto.subtle.digest(
      "SHA-256",
      encoder.encode(codeVerifier),
    );
    const computed = btoa(String.fromCharCode(...new Uint8Array(digest)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

    if (computed !== data.codeChallenge) {
      return jsonResponse({ error: "invalid_grant", reason: "PKCE mismatch" }, 400);
    }
  } else if (data.codeChallenge) {
    return jsonResponse({ error: "missing_code_verifier" }, 400);
  }

  return jsonResponse(
    {
      access_token: data.accessToken,
      token_type: "Bearer",
      expires_in: data.expiresIn,
      refresh_token: data.refreshToken,
    },
    200,
    { "Cache-Control": "no-store" },
  );
}

// ═══════════════════════════════════════
// 5. Dynamic Client Registration
// ═══════════════════════════════════════

async function handleRegister(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    client_name?: string;
    redirect_uris?: string[];
    grant_types?: string[];
    response_types?: string[];
    token_endpoint_auth_method?: string;
  };

  const clientId = crypto.randomUUID();
  const registration = {
    client_id: clientId,
    client_name: body.client_name ?? "MCP Client",
    redirect_uris: body.redirect_uris ?? [],
    grant_types: body.grant_types ?? ["authorization_code", "refresh_token"],
    response_types: body.response_types ?? ["code"],
    token_endpoint_auth_method:
      body.token_endpoint_auth_method ?? "none",
  };

  await env.MCP_OAUTH.put(
    `client:${clientId}`,
    JSON.stringify(registration),
  );

  return jsonResponse(registration, 201);
}

// ═══════════════════════════════════════
// 6. MCP Proxy
// ═══════════════════════════════════════

async function handleMcpProxy(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse(
      {
        error: "unauthorized",
        message: "Bearer token required",
      },
      401,
      {
        "WWW-Authenticate": `Bearer resource_metadata="${new URL(request.url).origin}/.well-known/oauth-authorization-server"`,
      },
    );
  }

  // Proxy to Supabase Edge Function (always use the base function URL)
  const proxyUrl = SUPABASE_FUNCTION_URL;

  // Build proxy headers: pass through MCP-relevant headers, add apikey for Supabase gateway
  const proxyHeaders = new Headers();
  proxyHeaders.set("Authorization", authHeader);
  proxyHeaders.set("apikey", env.SUPABASE_ANON_KEY);
  proxyHeaders.set("Content-Type", request.headers.get("Content-Type") ?? "application/json");
  // MCP Streamable HTTP requires Accept header with both JSON and SSE
  proxyHeaders.set("Accept", request.headers.get("Accept") ?? "application/json, text/event-stream");
  // Preserve MCP session header if present
  const sessionId = request.headers.get("Mcp-Session-Id");
  if (sessionId) {
    proxyHeaders.set("Mcp-Session-Id", sessionId);
  }

  const proxyRes = await fetch(proxyUrl, {
    method: request.method,
    headers: proxyHeaders,
    body: request.method !== "GET" && request.method !== "HEAD"
      ? request.body
      : undefined,
  });

  // Stream the response through (don't buffer — preserves SSE streaming)
  const resHeaders = new Headers(proxyRes.headers);
  for (const [k, v] of Object.entries(corsHeaders())) {
    resHeaders.set(k, v);
  }

  return new Response(proxyRes.body, {
    status: proxyRes.status,
    headers: resHeaders,
  });
}

// ═══════════════════════════════════════
// 7. Static Icon
// ═══════════════════════════════════════

// 48x48 Pin and Paper app icon (base64-encoded PNG)
const ICON_PNG_B64 =
  "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";

function handleIcon(): Response {
  const bytes = Uint8Array.from(atob(ICON_PNG_B64), (c) => c.charCodeAt(0));
  return new Response(bytes, {
    headers: {
      "Content-Type": "image/png",
      "Cache-Control": "public, max-age=86400",
      ...corsHeaders(),
    },
  });
}

// ═══════════════════════════════════════
// Helpers
// ═══════════════════════════════════════

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "Authorization, Content-Type, Accept, Mcp-Session-Id",
  };
}

function jsonResponse(
  data: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
      ...extraHeaders,
    },
  });
}
