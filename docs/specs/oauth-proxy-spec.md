# Pin and Paper — OAuth Proxy for MCP Connector

**Version:** 1.0
**Date:** 2026-02-28
**Target:** Cloudflare Worker (or equivalent edge runtime)
**Depends on:** MCP Edge Function (`supabase/functions/mcp-server/`)

---

## Problem

Claude's MCP connector follows the [MCP Authorization Spec (2025-03-26)](https://modelcontextprotocol.io/specification/2025-03-26/basic/authorization) which requires OAuth endpoints at the **domain root**:

```
MCP Server URL:  https://example.com/functions/v1/mcp-server
Auth base URL:   https://example.com          (path stripped)
Metadata:        https://example.com/.well-known/oauth-authorization-server
Fallback:        https://example.com/authorize
                 https://example.com/token
                 https://example.com/register
```

Supabase locks down root-level routing on project domains — we can only serve under `/functions/v1/`, `/auth/v1/`, etc. **We cannot serve `/.well-known/`, `/authorize`, or `/token` on the Supabase domain.**

## Solution

Deploy a Cloudflare Worker as the **front-door MCP server URL** that Claude connects to. The Worker handles OAuth at the root level and proxies MCP traffic to the existing Supabase Edge Function.

```
Claude (MCP Client)
    │
    ▼
Cloudflare Worker  (https://pin-and-paper-mcp.{account}.workers.dev)
    │
    ├── GET  /.well-known/oauth-authorization-server  →  metadata JSON
    ├── GET  /authorize                                →  redirect to Google OAuth
    ├── POST /token                                    →  exchange code → Supabase JWT
    ├── POST /register                                 →  dynamic client registration
    │
    └── POST|GET /mcp  (all other MCP traffic)         →  proxy to Supabase Edge Function
                                                          https://qasieyfuspuoauffochm.supabase.co/functions/v1/mcp-server
```

The URL registered in Claude's connector settings becomes the Worker URL, not the Supabase URL.

---

## Architecture

### Flow: First Connection (OAuth)

```
1. User adds connector in Claude settings:
   Server URL: https://pin-and-paper-mcp.workers.dev

2. Claude sends MCP request → Worker → 401 Unauthorized

3. Claude fetches:
   GET https://pin-and-paper-mcp.workers.dev/.well-known/oauth-authorization-server
   → Returns metadata JSON with authorize/token endpoints

4. Claude opens browser to:
   GET https://pin-and-paper-mcp.workers.dev/authorize
       ?response_type=code
       &client_id=<dynamic_or_static>
       &redirect_uri=https://claude.ai/api/mcp/auth_callback
       &code_challenge=<pkce_challenge>
       &code_challenge_method=S256
       &state=<state>

5. Worker redirects to Google OAuth:
   → https://accounts.google.com/o/oauth2/v2/auth
       ?client_id=<GOOGLE_CLIENT_ID>
       &redirect_uri=https://pin-and-paper-mcp.workers.dev/oauth/callback
       &response_type=code
       &scope=email+profile
       &state=<encoded_original_params>

6. User authorizes with Google → Google redirects to Worker /oauth/callback

7. Worker exchanges Google code for tokens with Supabase Auth:
   POST https://qasieyfuspuoauffochm.supabase.co/auth/v1/token?grant_type=id_token
   → Gets Supabase JWT (access_token + refresh_token)

8. Worker generates its own authorization code, stores mapping to Supabase JWT

9. Worker redirects back to Claude:
   → https://claude.ai/api/mcp/auth_callback?code=<worker_auth_code>&state=<state>

10. Claude exchanges code for token:
    POST https://pin-and-paper-mcp.workers.dev/token
    → Worker returns Supabase JWT as the access_token

11. Claude sends MCP requests with Bearer token
    → Worker proxies to Supabase Edge Function with same token
```

### Flow: Subsequent MCP Requests

```
Claude  →  POST https://pin-and-paper-mcp.workers.dev/mcp
           Authorization: Bearer <supabase_jwt>
           Body: MCP JSON-RPC

Worker  →  POST https://qasieyfuspuoauffochm.supabase.co/functions/v1/mcp-server
           Authorization: Bearer <supabase_jwt>
           Body: MCP JSON-RPC (passthrough)

        ←  MCP response (passthrough)
```

---

## Endpoint Specifications

### 1. `GET /.well-known/oauth-authorization-server`

Returns OAuth 2.0 Authorization Server Metadata ([RFC 8414](https://datatracker.ietf.org/doc/html/rfc8414)).

**Response:**
```json
{
  "issuer": "https://pin-and-paper-mcp.workers.dev",
  "authorization_endpoint": "https://pin-and-paper-mcp.workers.dev/authorize",
  "token_endpoint": "https://pin-and-paper-mcp.workers.dev/token",
  "registration_endpoint": "https://pin-and-paper-mcp.workers.dev/register",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "token_endpoint_auth_methods_supported": ["none", "client_secret_post"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": ["openid", "profile", "email"]
}
```

### 2. `GET /authorize`

Initiates the OAuth flow. This is the "third-party authorization flow" from the MCP spec — the Worker acts as an authorization server to Claude while delegating to Google.

**Query Parameters (from Claude):**
| Param | Description |
|-------|-------------|
| `response_type` | `code` |
| `client_id` | Claude's client ID (from dynamic registration or manual config) |
| `redirect_uri` | `https://claude.ai/api/mcp/auth_callback` |
| `code_challenge` | PKCE challenge |
| `code_challenge_method` | `S256` |
| `state` | Opaque state string |
| `scope` | Requested scopes |

**Worker behavior:**
1. Validate `redirect_uri` is `https://claude.ai/api/mcp/auth_callback` (or allowlisted)
2. Store the original OAuth params (client_id, redirect_uri, code_challenge, state) in KV with a session key
3. Redirect to Google OAuth:
   ```
   https://accounts.google.com/o/oauth2/v2/auth
     ?client_id=${GOOGLE_CLIENT_ID}
     &redirect_uri=https://pin-and-paper-mcp.workers.dev/oauth/callback
     &response_type=code
     &scope=email%20profile%20openid
     &state=${session_key}
     &access_type=offline
     &prompt=consent
   ```

### 3. `GET /oauth/callback`

Internal callback from Google OAuth. Not called by Claude directly.

**Worker behavior:**
1. Extract `code` and `state` (session key) from query params
2. Exchange Google auth code for Google tokens:
   ```
   POST https://oauth2.googleapis.com/token
   {
     "code": "<google_code>",
     "client_id": "${GOOGLE_CLIENT_ID}",
     "client_secret": "${GOOGLE_CLIENT_SECRET}",
     "redirect_uri": "https://pin-and-paper-mcp.workers.dev/oauth/callback",
     "grant_type": "authorization_code"
   }
   ```
3. Use Google `id_token` to sign in via Supabase Auth:
   ```
   POST https://qasieyfuspuoauffochm.supabase.co/auth/v1/token?grant_type=id_token
   Headers: { apikey: SUPABASE_ANON_KEY }
   Body: {
     "provider": "google",
     "id_token": "<google_id_token>"
   }
   ```
4. Supabase returns `{ access_token, refresh_token, user, ... }`
5. Generate a short-lived authorization code (random string)
6. Store in KV: `auth_code:{code}` → `{ supabase_access_token, supabase_refresh_token, code_challenge, client_id }` with 5-minute TTL
7. Retrieve original OAuth params from KV using session key
8. Redirect to Claude's callback:
   ```
   https://claude.ai/api/mcp/auth_callback?code=${auth_code}&state=${original_state}
   ```

### 4. `POST /token`

Token exchange endpoint. Called by Claude after receiving the authorization code.

**Request body (form-encoded):**
```
grant_type=authorization_code
code=<worker_auth_code>
redirect_uri=https://claude.ai/api/mcp/auth_callback
code_verifier=<pkce_verifier>
client_id=<client_id>
```

**Worker behavior:**
1. Look up `auth_code:{code}` in KV
2. Validate PKCE: compute `SHA256(code_verifier)` and compare to stored `code_challenge`
3. Validate `client_id` matches stored value
4. Delete the auth code from KV (single use)
5. Return token response:
   ```json
   {
     "access_token": "<supabase_jwt>",
     "token_type": "Bearer",
     "expires_in": 3600,
     "refresh_token": "<supabase_refresh_token>"
   }
   ```

**Refresh flow** (`grant_type=refresh_token`):
1. Extract `refresh_token` from request
2. Call Supabase Auth to refresh:
   ```
   POST https://qasieyfuspuoauffochm.supabase.co/auth/v1/token?grant_type=refresh_token
   Headers: { apikey: SUPABASE_ANON_KEY }
   Body: { "refresh_token": "<refresh_token>" }
   ```
3. Return new tokens to Claude

### 5. `POST /register`

Dynamic Client Registration ([RFC 7591](https://datatracker.ietf.org/doc/html/rfc7591)). Optional but recommended.

**Request body:**
```json
{
  "client_name": "Claude",
  "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

**Worker behavior:**
1. Generate a `client_id` (UUID)
2. Store in KV: `client:{client_id}` → registration metadata
3. Return:
   ```json
   {
     "client_id": "<generated_uuid>",
     "client_name": "Claude",
     "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
     "grant_types": ["authorization_code", "refresh_token"],
     "response_types": ["code"],
     "token_endpoint_auth_method": "none"
   }
   ```

### 6. `ALL /*` (MCP Traffic)

Everything that isn't an OAuth endpoint is proxied to the Supabase Edge Function.

**Worker behavior:**
1. If request has `Authorization: Bearer <token>`, pass it through
2. If no auth, return `401 Unauthorized`
3. Proxy request to `https://qasieyfuspuoauffochm.supabase.co/functions/v1/mcp-server`
4. Return response unmodified

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GOOGLE_CLIENT_ID` | Google OAuth 2.0 Client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth 2.0 Client Secret |
| `SUPABASE_URL` | `https://qasieyfuspuoauffochm.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon/public API key |

All stored as Cloudflare Worker secrets (encrypted at rest).

## Storage

Uses **Cloudflare Workers KV** for short-lived OAuth state:
- `session:{key}` → original OAuth params (5-min TTL)
- `auth_code:{code}` → Supabase tokens + PKCE challenge (5-min TTL)
- `client:{client_id}` → DCR registration data (no TTL)

KV namespace: `MCP_OAUTH`

---

## Google OAuth Setup Changes

The Google OAuth client (already created in Google Cloud Console) needs one additional authorized redirect URI:

```
https://pin-and-paper-mcp.workers.dev/oauth/callback
```

This is **in addition to** the existing Supabase callback URI. The Worker receives the Google callback, not Claude directly.

**Important:** Claude's callback URL (`https://claude.ai/api/mcp/auth_callback`) does NOT need to be registered with Google — it's the Worker's OAuth callback, not Google's.

---

## Claude Connector Setup

When registering the connector in Claude Settings → Connectors:

| Field | Value |
|-------|-------|
| Server URL | `https://pin-and-paper-mcp.workers.dev` |
| Client ID | *(leave blank if using DCR, or enter static ID)* |
| Client Secret | *(leave blank if using DCR)* |

If the Worker implements Dynamic Client Registration (endpoint 5 above), Claude will auto-register and no manual client credentials are needed.

---

## Security Considerations

1. **PKCE is mandatory** — the Worker validates `code_challenge`/`code_verifier` on every token exchange
2. **Auth codes are single-use** — deleted from KV immediately after exchange
3. **Short TTLs** — session state and auth codes expire after 5 minutes
4. **Redirect URI validation** — only `https://claude.ai/api/mcp/auth_callback` is accepted
5. **Token passthrough** — the Worker does NOT modify Supabase JWTs, it passes them through to the Edge Function where RLS enforces authorization
6. **Secrets management** — Google credentials and Supabase keys stored as Cloudflare Worker secrets, never exposed in code
7. **HTTPS only** — Cloudflare Workers are HTTPS by default

---

## Deployment

```bash
# Install Wrangler CLI
npm install -g wrangler

# Create project
wrangler init pin-and-paper-mcp

# Create KV namespace
wrangler kv namespace create MCP_OAUTH

# Set secrets
wrangler secret put GOOGLE_CLIENT_ID
wrangler secret put GOOGLE_CLIENT_SECRET
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_ANON_KEY

# Deploy
wrangler deploy
```

---

## Estimated Size

~150-250 lines of TypeScript. The Worker is deliberately thin — all business logic lives in the Supabase Edge Function.

---

## Review Changelog

| Version | Changes |
|---------|---------|
| 1.0 | Initial spec — OAuth proxy architecture, 6 endpoints, KV storage, security model |
