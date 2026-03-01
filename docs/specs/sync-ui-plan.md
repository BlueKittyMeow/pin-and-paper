# Pin and Paper — Sync UI Implementation Plan

**Version:** 2.0 (post-review)
**Date:** 2026-03-01
**Depends on:** `sync_service.dart` (network ops), `auth_service.dart`, `settings_screen.dart`
**Spec reference:** `docs/specs/sync-layer-spec.md` v2.0, Section 10 items 7–8

---

## Goal

Add a "Cloud Sync" section to the existing Settings screen that lets the user:
1. Sign in with Google (OAuth)
2. Enable/disable sync
3. See sync status (last sync time, signed-in account)
4. Sign out

Also wire `SyncService.onDataChanged` to `TaskProvider` so the task list refreshes automatically when remote changes are pulled.

---

## Architecture Decisions

### Why not a SyncProvider?

The app's other settings (notifications, date parsing, time preferences) are managed directly in `SettingsScreen` via local `setState()` + service calls. They don't use dedicated providers. Sync should follow this same pattern for consistency.

**SyncService already manages all state internally** — `SyncMeta` tracks `syncEnabled`, `userId`, `lastPushAt`, `lastPullAt`. The UI just needs to read this state and call `enableSync()` / `disableSync()`. There's no shared state that other screens need to observe.

The only cross-cutting concern is the `onDataChanged` callback, which is a single `VoidCallback` wired once at startup — no provider needed.

### Where to place the section

Insert "Cloud Sync" as a new section **between "Claude AI" and "Task Display"**. Rationale:
- Cloud sync is a primary feature (not buried at the bottom)
- It's related to the Claude AI section (sync enables Claude MCP access)
- It's independent of all the task behavior/display settings below it

### Auth flow on Linux desktop

[FIX: Gemini #1, Codex #1] `supabase_flutter` uses `app_links` internally for deep link handling. `app_links_linux` is already in the dependency tree. Deep links CAN work on Linux if the platform is configured:

1. Modify `my_application.cc` — change GApplication flags to `G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN`
2. Ensure a `.desktop` file registers `x-scheme-handler/io.supabase.pinandpaper`

**However**, in dev/debug builds (no installed `.desktop` file), the custom scheme won't be registered. The UI provides a two-pronged fallback:

1. **Primary path (production):** Deep link triggers `onAuthStateChange` automatically via `app_links`
2. **Fallback path (dev/broken deep link):** User pastes the redirect URL from the browser's address bar into a text field. `AuthService.handleRedirectUrl()` parses tokens from the URL fragment and calls `supabase.auth.getSessionFromUrl()`.

The sign-in UI always shows both the "Sign in" button AND (after clicking) a "Paste redirect URL" field, so the user can complete auth regardless of whether deep links work.

### Error handling philosophy

Same as the rest of the sync layer: **never block the UI**. All sync operations are wrapped in try/catch. Errors are shown as temporary SnackBars, not blocking dialogs. The user can always dismiss and continue using the app offline.

---

## Implementation Steps

### Step 0: Linux deep link platform config

**File:** `pin_and_paper/linux/runner/my_application.cc`

Patch per `app_links` Linux setup:

1. Change `G_APPLICATION_NON_UNIQUE` to `G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN` in `my_application_new()`
2. Change `return TRUE;` to `return FALSE;` in `my_application_local_command_line()`
3. In `my_application_activate()`, check for existing windows and present them instead of always creating a new one

**Lines changed:** ~15 in `my_application.cc`

---

### Step 0b: Update AuthService for redirect URL parsing

**File:** `pin_and_paper/lib/services/auth_service.dart`

Add a method to handle the paste-URL fallback:

```dart
/// Handle a pasted redirect URL to complete OAuth on platforms
/// where deep links don't work (e.g., Linux dev builds).
///
/// The URL looks like: io.supabase.pinandpaper://login-callback/#access_token=...&refresh_token=...
/// Returns true if session was established, false otherwise.
Future<bool> handleRedirectUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    await _supabase.auth.getSessionFromUrl(uri);
    return true;
  } catch (e) {
    debugPrint('[Auth] Failed to parse redirect URL: $e');
    return false;
  }
}
```

**Lines changed:** ~15 in `auth_service.dart`

---

### Step 1: Wire `onDataChanged` callback (HomeScreen)

**File:** `pin_and_paper/lib/screens/home_screen.dart`

[FIX: Codex #4] The callback must respect active filters. `TaskProvider.loadTasks()` loads the full unfiltered hierarchy. If the user has tag/date filters active, use `_onFilterChanged()` instead.

In `HomeScreen.initState()`:

```dart
// Phase 4.0: Refresh task list when sync pulls remote changes
SyncService.instance.onDataChanged = () {
  if (mounted) {
    final taskProvider = context.read<TaskProvider>();
    if (taskProvider.hasActiveFilters) {
      // Re-run filter query to preserve filtered view
      taskProvider.reapplyFilters();
    } else {
      taskProvider.loadTasks();
    }
  }
};
```

**Note:** `TaskProvider` already has `_onFilterChanged()` as a private listener. We need a public entry point. The simplest approach: add a `reapplyFilters()` method that delegates to the existing filter-changed logic, or just call `loadTasks()` followed by the filter provider notifying (which triggers `_onFilterChanged`). Alternatively, since `loadTasks()` calls `notifyListeners()` and the filter provider is still set, we can just call `loadTasks()` — the `visibleTasks` getter already filters. **Actually**, looking at the code more carefully: `_onFilterChanged()` does a separate DB query with WHERE clauses for active filters, while `loadTasks()` loads the full hierarchy. The `visibleTasks` getter only splits active/completed, it doesn't apply tag/date filters. So we DO need to call the filter path.

**Simplest fix:** Just always call `loadTasks()`. After `loadTasks()` completes and calls `notifyListeners()`, the `_filterProvider` listener will fire `_onFilterChanged()` on the next frame. Wait — no, `_onFilterChanged` is only triggered when filter *state* changes, not when data changes.

**Correct approach:** Call `loadTasks()` then, if filters are active, manually trigger the filter re-query:

```dart
SyncService.instance.onDataChanged = () {
  if (mounted) {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.loadTasks().then((_) {
      if (taskProvider.hasActiveFilters) {
        taskProvider.refreshWithCurrentFilters();
      }
    });
  }
};
```

We'll add `refreshWithCurrentFilters()` as a thin public method on `TaskProvider` that calls the existing private `_onFilterChanged()`.

**Cleanup in dispose:**

```dart
SyncService.instance.onDataChanged = null;
```

**Lines changed:** ~10 in `home_screen.dart`, ~5 in `task_provider.dart`

---

### Step 2: Add Cloud Sync section to Settings screen

**File:** `pin_and_paper/lib/screens/settings_screen.dart`

#### 2a. New imports

```dart
import 'dart:async';                        // Phase 4.0: StreamSubscription
import '../services/auth_service.dart';     // Phase 4.0
import '../services/sync_service.dart';     // Phase 4.0
```

[FIX: Gemini #6] `dart:async` needed for `StreamSubscription`. `package:flutter/services.dart` is already imported.

#### 2b. New state fields

```dart
// Phase 4.0: Cloud Sync state
bool _syncEnabled = false;
bool _isSyncLoading = true;    // true while loading initial sync state
bool _isSyncToggling = false;  // [FIX: Codex #6, Gemini #5] true during enable/disable
bool _isSigningIn = false;     // true during OAuth flow
String? _signedInEmail;        // null if not signed in
DateTime? _lastSyncAt;         // max of lastPushAt and lastPullAt
String? _oauthUrl;             // non-null during sign-in flow (copy/paste fallback)
StreamSubscription<AuthState>? _authSub;
TextEditingController? _redirectUrlController;  // [FIX: Gemini #1] paste-URL fallback
```

#### 2c. Initialize in `initState()`

[FIX: Codex #3] Subscribe to auth state changes permanently (not just during sign-in):

```dart
@override
void initState() {
  super.initState();
  _loadApiKey();
  _usageStatsFuture = _apiUsageService.getStats();
  _loadNotificationSettings();
  _loadTimeAndPreferenceSettings();
  _loadQuizStatus();
  _loadSyncState();  // Phase 4.0

  // [FIX: Codex #3] Permanent auth listener — react to sign-out from token expiry
  _authSub = AuthService.instance.onAuthStateChange.listen(_onAuthStateChanged);

  // [FIX: Gemini #4] Refresh sync timestamps when background sync completes
  SyncService.instance.onSyncComplete = _refreshSyncTimestamp;
}
```

Implementation of `_loadSyncState()`:

```dart
Future<void> _loadSyncState() async {
  try {
    final meta = await SyncService.instance.getSyncMeta();
    final user = AuthService.instance.currentUser;

    if (mounted) {
      setState(() {
        _syncEnabled = meta.syncEnabled;
        _signedInEmail = user?.email;
        _lastSyncAt = _latestOf(meta.lastPushAt, meta.lastPullAt);
        _isSyncLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isSyncLoading = false;
      });
    }
  }
}

DateTime? _latestOf(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
```

[FIX: Codex #3] Permanent auth state handler:

```dart
void _onAuthStateChanged(AuthState state) {
  if (!mounted) return;
  if (state.event == AuthChangeEvent.signedIn) {
    _loadSyncState();  // [FIX: Codex #7] Refresh all sync state
  } else if (state.event == AuthChangeEvent.signedOut) {
    setState(() {
      _syncEnabled = false;
      _signedInEmail = null;
      _lastSyncAt = null;
      _isSigningIn = false;
      _oauthUrl = null;
    });
  }
}
```

[FIX: Gemini #4] Live sync timestamp refresh:

```dart
void _refreshSyncTimestamp() async {
  if (!mounted) return;
  try {
    final meta = await SyncService.instance.getSyncMeta();
    if (mounted) {
      setState(() {
        _lastSyncAt = _latestOf(meta.lastPushAt, meta.lastPullAt);
      });
    }
  } catch (_) {}
}
```

**Note:** This requires adding a second callback `VoidCallback? onSyncComplete` to `SyncService`, called at the end of both `push()` and `pull()`. This is separate from `onDataChanged` (which only fires when pull merges new data).

#### 2d. Clean up in `dispose()`

```dart
@override
void dispose() {
  _apiKeyController.dispose();
  _authSub?.cancel();  // Phase 4.0
  _redirectUrlController?.dispose();  // Phase 4.0
  SyncService.instance.onSyncComplete = null;  // Phase 4.0
  super.dispose();
}
```

#### 2e. Build the Cloud Sync section

Insert after the Claude AI section (after `const SizedBox(height: 32)` at ~line 208), before "Task Display":

```dart
// ── Cloud Sync Section (Phase 4.0) ──────────────
Text(
  'Cloud Sync',
  style: Theme.of(context).textTheme.headlineSmall,
),
const SizedBox(height: 8),
Text(
  'Sync your tasks with the cloud so Claude can help manage them.',
  style: TextStyle(
    color: AppTheme.muted,
    fontSize: 13,
  ),
),
const SizedBox(height: 16),
_buildSyncCard(),
const SizedBox(height: 32),
```

#### 2f. `_buildSyncCard()` — the main UI widget

Three visual states:

**State A: Not signed in**
```
┌─────────────────────────────────────────┐
│  ☁  Sign in to sync with Claude        │
│                                         │
│  [  Sign in with Google  ]              │
│                                         │
│  ─ ─ ─ (if _oauthUrl != null) ─ ─ ─ ─  │
│  If your browser didn't open, copy      │
│  this link and paste it in your browser:│
│  ┌─────────────────────────────┐ [Copy] │
│  │ https://...oauth-url...     │        │
│  └─────────────────────────────┘        │
│                                         │
│  Or paste the redirect URL here:        │
│  ┌─────────────────────────────┐ [Go]   │
│  │                             │        │
│  └─────────────────────────────┘        │
│                                         │
│  [Cancel]                               │
└─────────────────────────────────────────┘
```

**State B: Signed in, sync disabled**
```
┌─────────────────────────────────────────┐
│  👤 user@example.com                    │
│                                         │
│  Sync disabled                          │
│  ──────────────────────────(  toggle  ) │
│  Last synced: 2 minutes ago             │
│                                         │
│  ─────────────────────                  │
│  [Sign Out]                             │
└─────────────────────────────────────────┘
```

**State C: Signed in, sync enabled**
```
┌─────────────────────────────────────────┐
│  👤 user@example.com                    │
│                                         │
│  Sync enabled                           │
│  ──────────────────────────(  toggle  ) │
│  Last synced: 2 minutes ago             │
│                                         │
│  ─────────────────────                  │
│  [Sign Out]                             │
└─────────────────────────────────────────┘
```

Implementation:

```dart
Widget _buildSyncCard() {
  if (_isSyncLoading) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  final isSignedIn = _signedInEmail != null;

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSignedIn) ..._buildSignedOutContent(),
          if (isSignedIn) ..._buildSignedInContent(),
        ],
      ),
    ),
  );
}
```

#### 2g. Signed-out content (State A)

```dart
List<Widget> _buildSignedOutContent() {
  return [
    Row(
      children: [
        Icon(Icons.cloud_outlined, color: AppTheme.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Sign in to sync your tasks with Claude',
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSigningIn ? null : _handleSignIn,
        icon: _isSigningIn
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login),
        label: Text(_isSigningIn ? 'Opening browser...' : 'Sign in with Google'),
      ),
    ),
    // [FIX: Gemini #1, Codex #1] OAuth URL + paste redirect fallback
    if (_oauthUrl != null) ...[
      const SizedBox(height: 16),
      Text(
        'If your browser didn\'t open, copy this link and paste it in your browser:',
        style: TextStyle(fontSize: 12, color: AppTheme.muted),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: SelectableText(
              _oauthUrl!,
              style: TextStyle(fontSize: 11, color: AppTheme.info),
              maxLines: 2,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _oauthUrl!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            tooltip: 'Copy link',
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'After signing in, paste the redirect URL here:',
        style: TextStyle(fontSize: 12, color: AppTheme.muted),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _redirectUrlController ??= TextEditingController(),
              decoration: const InputDecoration(
                hintText: 'io.supabase.pinandpaper://...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _handleRedirectUrlPaste,
            child: const Text('Go'),
          ),
        ],
      ),
      // [FIX: Codex #2] Cancel button to reset stuck sign-in state
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _handleCancelSignIn,
          child: Text('Cancel', style: TextStyle(color: AppTheme.muted)),
        ),
      ),
    ],
  ];
}
```

#### 2h. Signed-in content (States B & C)

[FIX: Codex #5] Show last sync time whenever `_lastSyncAt != null`, regardless of toggle state.
[FIX: Codex #6, Gemini #5] `_isSyncToggling` disables toggle and shows progress during enable/disable.

```dart
List<Widget> _buildSignedInContent() {
  return [
    // User email
    Row(
      children: [
        Icon(Icons.account_circle, color: AppTheme.deepShadow),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _signedInEmail!,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),

    // Sync toggle
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Text(_syncEnabled ? 'Sync enabled' : 'Sync disabled'),
          if (_isSyncToggling) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
      // [FIX: Codex #5] Show last sync time regardless of toggle state
      subtitle: _lastSyncAt != null
          ? Text(
              'Last synced: ${_formatLastSync(_lastSyncAt!)}',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            )
          : null,
      value: _syncEnabled,
      // [FIX: Codex #6] Disable toggle while operation is in flight
      onChanged: _isSyncToggling ? null : _handleSyncToggle,
      activeColor: AppTheme.success,
    ),

    const Divider(),
    const SizedBox(height: 4),

    // Sign out button
    TextButton.icon(
      onPressed: _handleSignOut,
      icon: Icon(Icons.logout, size: 18, color: AppTheme.danger),
      label: Text('Sign out', style: TextStyle(color: AppTheme.danger)),
    ),
  ];
}
```

#### 2i. Action handlers

[FIX: Gemini #2] Auth listener set up BEFORE calling `signInWithGoogle()`.
[FIX: Codex #2] Cancel button to escape stuck sign-in state.
[FIX: Gemini #3] Toggle reverts to actual sync_meta state on error.
[FIX: Codex #7] Sign-in completion calls `_loadSyncState()`.

```dart
/// Sign in with Google OAuth.
/// [FIX: Gemini #2] Listener established before signIn to avoid race.
Future<void> _handleSignIn() async {
  setState(() {
    _isSigningIn = true;
    _oauthUrl = null;
  });

  try {
    final url = await AuthService.instance.signInWithGoogle();
    if (mounted) {
      setState(() {
        _oauthUrl = url;
      });
    }
    // Note: auth completion is handled by _onAuthStateChanged (permanent listener)
  } catch (e) {
    if (mounted) {
      setState(() {
        _isSigningIn = false;
        _oauthUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }
}

/// [FIX: Gemini #1] Handle pasted redirect URL for OAuth completion.
Future<void> _handleRedirectUrlPaste() async {
  final url = _redirectUrlController?.text.trim();
  if (url == null || url.isEmpty) return;

  final success = await AuthService.instance.handleRedirectUrl(url);
  if (!success && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid redirect URL. Please try again.')),
    );
  }
  // If successful, _onAuthStateChanged will handle the UI update
}

/// [FIX: Codex #2] Cancel sign-in flow.
void _handleCancelSignIn() {
  setState(() {
    _isSigningIn = false;
    _oauthUrl = null;
    _redirectUrlController?.clear();
  });
}

/// Toggle sync on/off.
/// [FIX: Gemini #3, Gemini #5, Codex #6] Reverts on error, shows progress.
Future<void> _handleSyncToggle(bool enabled) async {
  setState(() => _isSyncToggling = true);

  try {
    if (enabled) {
      await SyncService.instance.enableSync();
    } else {
      await SyncService.instance.disableSync();
    }

    // Re-read meta to get accurate state
    final meta = await SyncService.instance.getSyncMeta();
    if (mounted) {
      setState(() {
        _syncEnabled = meta.syncEnabled;
        _lastSyncAt = _latestOf(meta.lastPushAt, meta.lastPullAt);
        _isSyncToggling = false;
      });
    }
  } catch (e) {
    // [FIX: Gemini #3] Re-read actual meta state instead of guessing
    try {
      final meta = await SyncService.instance.getSyncMeta();
      if (mounted) {
        setState(() {
          _syncEnabled = meta.syncEnabled;
          _isSyncToggling = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSyncToggling = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ${enabled ? "enable" : "disable"} sync: $e')),
      );
    }
  }
}

/// Sign out — disables sync, clears auth.
Future<void> _handleSignOut() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'Sync will be disabled. Your local tasks will not be deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Sign out', style: TextStyle(color: AppTheme.danger)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await AuthService.instance.signOut();
    // UI update handled by _onAuthStateChanged (permanent listener)
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-out failed: $e')),
      );
    }
  }
}
```

#### 2j. Time formatting helper

```dart
String _formatLastSync(DateTime lastSync) {
  final now = DateTime.now();
  final diff = now.difference(lastSync);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  // Fallback to date
  return '${lastSync.month}/${lastSync.day}/${lastSync.year}';
}
```

---

### Step 3: Add `onSyncComplete` callback to SyncService

**File:** `pin_and_paper/lib/services/sync_service.dart`

Add a second callback alongside `onDataChanged`:

```dart
/// Called after any push() or pull() completes (success or empty).
/// Used by SettingsScreen to refresh the "Last synced" timestamp.
VoidCallback? onSyncComplete;
```

Call `onSyncComplete?.call()` at the end of `push()` and `pull()` (in `finally` blocks).

**Lines changed:** ~6 in `sync_service.dart`

---

### Step 4: Add `refreshWithCurrentFilters()` to TaskProvider

**File:** `pin_and_paper/lib/providers/task_provider.dart`

[FIX: Codex #4] Public method to re-run filter query after data changes:

```dart
/// Re-apply current filters after external data changes (e.g., sync pull).
/// Delegates to the existing _onFilterChanged() logic.
void refreshWithCurrentFilters() {
  _onFilterChanged();
}
```

**Lines changed:** ~4 in `task_provider.dart`

---

### Step 5: Summary of changes

| File | Change | Est. Lines |
|------|--------|-----------|
| `my_application.cc` | Linux deep link platform config (GApplication flags) | ~15 |
| `auth_service.dart` | Add `handleRedirectUrl()` for paste-URL fallback | ~15 |
| `sync_service.dart` | Add `onSyncComplete` callback, call from push/pull | ~6 |
| `task_provider.dart` | Add `refreshWithCurrentFilters()` public method | ~4 |
| `home_screen.dart` | Wire `onDataChanged` → filter-aware refresh | ~10 |
| `settings_screen.dart` | Full Cloud Sync section with all review fixes | ~280 |
| **Total** | | **~330** |

No new files. No new providers. No new dependencies. Six existing files modified.

---

## Review Fixes Incorporated (v1.0 → v2.0)

| Fix | Finding | Change |
|-----|---------|--------|
| Linux deep link config | Gemini #1 CRITICAL, Codex #1 HIGH | Platform config + paste-URL fallback in AuthService |
| Auth listener before signIn | Gemini #2 HIGH | Permanent listener in initState, not after signIn call |
| Toggle revert on error | Gemini #3 HIGH | Re-read sync_meta in catch block |
| Cancel stuck sign-in | Codex #2 MEDIUM | Cancel button resets _isSigningIn |
| Permanent auth listener | Codex #3 MEDIUM | Subscribe in initState, handle signedOut |
| Toggle in-flight guard | Codex #6 LOW + Gemini #5 MEDIUM | _isSyncToggling disables toggle, shows spinner |
| Filter-aware refresh | Codex #4 MEDIUM | refreshWithCurrentFilters() in TaskProvider |
| Live sync timestamp | Gemini #4 MEDIUM | onSyncComplete callback refreshes _lastSyncAt |
| Last synced always visible | Codex #5 LOW | Show when _lastSyncAt != null, not just when enabled |
| Refresh meta after sign-in | Codex #7 LOW | _onAuthStateChanged calls _loadSyncState() |
| Missing imports | Gemini #6 LOW | dart:async for StreamSubscription |

---

## Edge Cases

### 1. Sign in → don't enable sync

The user may sign in but leave the sync toggle off. This is valid. Their account is authenticated but no data flows to Supabase. `SyncService.enableSync()` is only called when the toggle is switched on.

### 2. App restart while signed in

On app restart, `SyncService.initialize()` checks `sync_meta.syncEnabled` and the current auth user. If both valid, sync resumes automatically. The Settings screen reads the same meta on `initState()` and shows the correct state.

### 3. OAuth URL display timing

The `_oauthUrl` is set immediately after `getOAuthSignInUrl()` returns. It stays visible until auth succeeds, the user cancels, or navigates away. If the user navigates away and back, the URL is gone but they can tap "Sign in" again. [FIX: Codex #2] A "Cancel" button lets the user reset the flow.

### 4. Auth token expiry

Supabase handles token refresh automatically via `supabase_flutter`. If the refresh token is also expired, the user will be signed out (auth listener fires `signedOut`). [FIX: Codex #3] The permanent `_authSub` listener resets the UI immediately.

### 5. Sync toggle while offline

If the user enables sync while offline, `enableSync()` calls `fullPush()` which will fail silently (try/catch in SyncService). The sync_meta is already set to enabled, so when connectivity returns, the connectivity listener triggers push → pull. No data loss.

### 6. Multiple rapid toggles

[FIX: Codex #6] The `_isSyncToggling` flag disables the toggle while an operation is in flight, preventing overlapping calls.

### 7. Deep link works vs. doesn't

In production (installed with `.desktop` file), the custom scheme is registered and deep links work automatically. In dev builds, deep links may not work — the paste-URL fallback handles this case. Both paths converge on the same `_onAuthStateChanged` handler.

---

## What This Plan Does NOT Include

1. **Sync status indicator on HomeScreen** — No persistent sync icon or spinner on the main screen. Sync is invisible background work. The user checks status in Settings.

2. **Manual push/pull buttons** — Unnecessary complexity. Sync is automatic (2s debounce push, realtime pull). If the user wants to force sync, they can toggle off and on.

3. **Conflict resolution UI** — LWW is fully automatic. No "choose which version" dialogs.

4. **Per-task sync status** — No "synced" checkmark on individual tasks. This would require tracking per-task sync state and adds visual clutter.

5. **Detailed sync log viewer** — The sync_log table exists for debugging but exposing it in the UI would confuse users.

---

## Verification

1. **Fresh install (never signed in):** Settings shows "Sign in to sync" with Google button. No errors.
2. **Sign in flow (deep link works):** Tap "Sign in" → browser opens → complete Google OAuth → deep link fires → Settings updates to show email, toggle off.
3. **Sign in flow (paste fallback):** Tap "Sign in" → browser opens → complete OAuth → browser shows error page with redirect URL → user copies URL → pastes into text field → taps "Go" → Settings updates.
4. **Cancel sign-in:** Tap "Sign in" → "Cancel" → button re-enabled, URL hidden.
5. **Enable sync:** Toggle on → spinner shows → `fullPush()` runs → spinner stops → last sync time appears.
6. **Disable sync:** Toggle off → sync stops → last sync time remains visible.
7. **Sign out:** Tap "Sign out" → confirmation dialog → confirm → UI resets to signed-out state.
8. **Remote change refresh:** Claude creates a task via MCP → realtime fires → `pull()` merges → `onDataChanged` fires → task list refreshes (respects active filters).
9. **App restart:** Reopen app → Settings shows correct signed-in state and sync toggle position.
10. **Offline behavior:** All buttons work. Sync failures are silent. SnackBars appear only for auth errors (not sync errors).
11. **Background sync timestamps:** While viewing Settings, sync pull occurs → "Last synced" updates live.
12. **Token expiry:** Auth token expires → Settings immediately shows signed-out state.
