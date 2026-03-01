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

  // Proxy to Supabase Edge Function
  const proxyUrl = new URL(SUPABASE_FUNCTION_URL);
  const incoming = new URL(request.url);
  // Preserve any sub-path after the Worker root
  if (incoming.pathname !== "/" && incoming.pathname !== "") {
    proxyUrl.pathname += incoming.pathname;
  }

  const proxyHeaders = new Headers(request.headers);
  proxyHeaders.set("Authorization", authHeader);

  const proxyRes = await fetch(proxyUrl.toString(), {
    method: request.method,
    headers: proxyHeaders,
    body: request.method !== "GET" && request.method !== "HEAD"
      ? request.body
      : undefined,
  });

  // Pass through response with CORS headers
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
