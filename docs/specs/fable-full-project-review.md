# Fable — Full Project Review (All Repos)

**Date:** 2026-07-09
**Scope:** pin-and-paper (app, MCP worker, Supabase functions/schema), pin_and_paper_sketchpad, pin_and_paper_journal, pin_and_paper_canvas, pin_and_paper_card_renderer, pin_and_paper_dev_harness
**Verification:** Read all service/provider/backend code; `flutter analyze` (217 issues, 13 warnings, rest infos); `flutter test` (460 passed, 22 failed — see M-9).

---

## Overall assessment

Codebase quality is high: parameterized SQL throughout, transactional migrations, disciplined service/provider separation, complete and correct RLS, visible multi-AI review culture. The risk is concentrated in the newest code: the sync layer and the MCP server. The modular multi-repo architecture is well-designed but mostly aspirational — canvas/card_renderer are empty, journal is a stub, and the dev harness contains only docs.

---

## High severity

### H-1. `fullPush` tag remapping violates FK constraints (likely crash)
`pin_and_paper/lib/services/sync_service.dart:849-867`
When a tag name exists remotely under a different UUID, the code updates `task_tags.tag_id` to the remote ID **before** any `tags` row with that ID exists locally. With `PRAGMA foreign_keys = ON` (set in `DatabaseService._onConfigure`) this is an immediate FK violation whenever the colliding tag has task associations. `mergeTag` (~line 391) already handles the identical case correctly with `PRAGMA foreign_keys = OFF` + insert-new/migrate/delete-old — use the same pattern.

### H-2. MCP `update_task` has no cycle detection → can hang the app
`supabase/functions/mcp-server/tools/update_task.ts:108-139`, `helpers/depth.ts`
Moves validate depth only. Example: root A with child B; `update_task(A, parent_id: B)` passes the depth check and creates a parent cycle in Supabase. After pull: `getTaskHierarchy`'s CTE silently drops both tasks from the UI, and `TaskService._wouldCreateCycle` (task_service.dart:1292) — an unbounded walk-up loop — hangs forever on any later move near the cycle.
Fix both ends: reject moves under a descendant in `update_task`; cap `_wouldCreateCycle` iterations as defense.

### H-3. Sibling position shifts invisible to sync
`pin_and_paper/lib/services/task_service.dart:492-502, 743-748, 788-796`
Raw `UPDATE ... SET position = position + 1` shifts set neither `updated_at` nor `sync_log` entries (unlike `_reindexSiblings`). Other devices never receive shifted positions, and stale `updated_at` means remote LWW resurrects pre-shift positions → duplicate positions, scrambled manual order across devices.

### H-4. Pull cursor poisoned by client clock skew
`docs/specs/supabase-schema.sql:69-80`, `sync_service.dart:996-997`
The `updated_at = NOW()` trigger fires on UPDATE but not INSERT, so inserted rows keep the pushing device's clock time. `pull()` advances `lastPullAt` to the max `updated_at` seen; a fast-clock device pushes a future timestamp, and other devices then skip server-stamped updates until real time catches up. Fix: stamp `updated_at` server-side on INSERT too.

### H-5. Hard deletes have no tombstones → resurrection
`emptyTrash`/`cleanupExpiredDeletedTasks` push DELETEs, but another device that still holds the row re-creates it via upsert (or `fullPush`). Affects trash-emptied items only. Options: remote tombstones (keep `deleted_at` rows), or document and accept.

---

## Medium severity

### M-1. MCP creates tasks at position 0 + shifts all siblings
`tools/create_task.ts:69-70`, `migrations/20260228000000_mcp_helper_functions.sql` (`shift_sibling_positions`)
App semantics: new task = `MAX(position)+1`, list ordered `position DESC`. MCP semantics: insert at 0, bump every sibling +1. Result: (a) MCP tasks appear at the **bottom** of the app list; (b) every MCP create updates all sibling rows → trigger bumps their `updated_at` → realtime churn, full re-pulls, and LWW clobbering of unsynced local position changes. Switch MCP to `MAX+1`.

### M-2. MCP `restore_task` doesn't restore deleted ancestors
`restore_task_tree` restores task + same-timestamp descendants only. The app's `restoreTask` restores ancestors precisely because a task under a deleted parent is unreachable by `getTaskHierarchy` — an MCP-restored subtask can become invisible (not in list, not in trash).

### M-3. One bad row aborts pull forever
`sync_service.dart:993-998` — `mergeTask` per-row failures (e.g., FK: parent hard-deleted locally) throw out of `pull()`, cursor never advances, every retry fails at the same row. Add per-row try/catch (skip + log) or orphan-to-root handling.

### M-4. `navigateToTask` race under active filters
`task_provider.dart:1375-1392` — after `clearFilters()` the code re-searches `_tasks` synchronously, before the async reload triggered by the filter change completes → search navigation silently does nothing. Await the reload before the second lookup.

### M-5. `pullTaskTags` union-merge wipes legacy tag links
`sync_service.dart:493-502` — tasks with non-UUID IDs are excluded from `fullPush`, so their junction rows never reach the server; the "remove local rows not in remote" branch then deletes those local associations. Skip junctions whose task/tag was never pushed.

### M-6. App startup blocks on network
`main.dart:54` — `await SyncService.instance.initialize()` runs a full pull before `runApp`, no timeout. Fire it after first frame; `onDataChanged` already refreshes the UI.

### M-7. MCP OAuth worker is open registration
`pin-and-paper-mcp/src/index.ts` — any Google account can mint a Supabase JWT (RLS isolates data; no leak, but strangers can store data in the project). Add an allowed-email check (as in Catalogue). Also: `/register` KV entries have no TTL; PKCE is skipped when the client omits `code_challenge` (`index.ts:350-366`). The uncommitted ChatGPT redirect-prefix change is safe as written (`startsWith` on full origin+path).

### M-8. `ClaudeService` error handling
`claude_service.dart:80-82` — outer `catch` re-wraps its own `ClaudeApiException`s as `'Network error', statusCode 0`, losing status codes (provider survives via string-matching "401" — luck). Rethrow `ClaudeApiException` untouched. Also `_extractJson`'s non-greedy `\[.*?\]` truncates at the first `]` — a note containing `]` breaks the whole batch parse.

### M-9. 22 test failures on Linux
All but one stem from `flutter_js` missing `libquickjs_c_bridge_plugin.so` on Linux desktop (DateParsingService suites + one widget test). Environment gap, but it means date parsing is dead on Linux desktop at runtime and the suite isn't a clean green/red signal here. Guard/skip those suites when the library is absent.

---

## Low severity / polish

- `resolveTagNames` uses `.ilike("name", name)` with raw input — `%`/`_` act as wildcards, can match wrong tags (`helpers/tags.ts:33`).
- `getRecentlyDeletedTasks` computes hierarchical `sort_key` then orders by `deleted_at DESC`, interleaving trees (task_service.dart:1136).
- Search ignores `notes` — "model doesn't have notes yet" comments predate migration v8 (search_service.dart:135, 256).
- `DatabaseService.database` first-call race (two concurrent awaits → double `openDatabase`); cache a `Future<Database>`.
- `app_links` imported by `auth_service.dart` but undeclared in pubspec (transitive via supabase_flutter).
- Desktop OAuth callback binds fixed port 54321 — collides with `supabase start` local stack. Bind port 0.
- `get_task_summary` `overdue` uses raw `due_date < NOW()`, ignoring all-day/today-cutoff semantics — MCP and app disagree on "overdue".
- Sketchpad (prototype-grade): `LayerStack(layers: [...])` with <3 layers → RangeError (`_activeLayerIndex` hardcoded to 2); no `onPointerCancel`; no pointer-ID/device-kind filtering (palm rejection will matter for S-Pen); no stroke serialization yet (blocks `CardDrawingSource`/journal persistence contracts).
- Hardcoded Supabase URL/anon key in `main.dart` — fine by design (anon key public, RLS complete), noting intent.

---

## Architecture / docs drift

- **Dev harness has no code**: README documents `lib/main.dart`, `lib/mocks/`, `lib/pages/`, `pubspec.yaml` — none exist; repo is docs-only.
- **Broken spec paths**: harness `CLAUDE.md` references `specs/phase-4.1-canvas-mvp/...` etc. — exist in no repo. Real specs: harness `docs/module_specs/`, main app `docs/specs/`.
- **"Phase 4" collision**: main app Phase 4.0 = Supabase sync (shipped); harness Phase 4.x = spatial canvas MVP (not started).
- **CORE_API.md stale**: DB v11 (now 12); `resetDatabase`/`setTestDatabase` documented as instance (they're static); no SyncService/AuthService; "no Streams" no longer true. `AppConstants.appVersion` still 3.9.0.
- **Module status**: sketchpad ~1k lines working prototype; journal = placeholder screen; canvas/card_renderer = `.gitkeep` only.

---

## Strengths

Parameterized SQL everywhere; transactional migrations (careful v6 tag rebuild/dedupe); correct v4 position backfill; `logChange`-inside-transaction design (incl. the uncommitted deadlock fix, which is correct); push dedup with per-entry synced marking; stateless per-request MCP server with RLS-scoped client; SQL helpers correctly SECURITY INVOKER so RLS applies inside; tag service is the best-tested corner.

## Suggested order of attack

H-1 + H-3 (small diffs, sync correctness) → H-2 + M-2 (MCP data integrity) → H-4 (one schema migration) → M-4/M-6 (UX) → docs-sync pass.
