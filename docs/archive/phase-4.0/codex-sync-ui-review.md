# Sync UI Plan Review — Codex

**Document under review:** `docs/specs/sync-ui-plan.md` v1.0
**Reviewer:** Codex
**Date:** 2026-03-01

---

## Instructions

We are about to implement the Settings UI for Cloud Sync in Pin and Paper. The plan is written — we need you to review the **proposed design** for logic bugs, edge cases, and gaps **before we start coding**.

Record ALL findings in THIS document. **Do not modify any other files.**

### Plan to review

Read `docs/specs/sync-ui-plan.md` carefully. The full plan is also pasted below for reference.

### Context files (read for reference)

- `pin_and_paper/lib/screens/settings_screen.dart` — Existing settings UI (10 sections, 955 lines)
- `pin_and_paper/lib/screens/home_screen.dart` — Main screen where `onDataChanged` callback is wired
- `pin_and_paper/lib/services/sync_service.dart` — Sync engine with `enableSync()`, `disableSync()`, `getSyncMeta()`, `onDataChanged`, `push()`, `pull()`
- `pin_and_paper/lib/services/auth_service.dart` — Google OAuth wrapper (62 lines)
- `pin_and_paper/lib/providers/task_provider.dart` — Task state management, has `loadTasks()` for full refresh
- `pin_and_paper/lib/main.dart` — App entry point with `Supabase.initialize()` and `SyncService.instance.initialize()`
- `pin_and_paper/lib/utils/theme.dart` — Theme constants (`AppTheme.success`, `.danger`, `.muted`, `.info`, `.deepShadow`, etc.)
- `docs/specs/sync-layer-spec.md` — Canonical sync spec v2.0

### What to look for

1. **OAuth flow completeness** — The plan uses `AuthService.onAuthStateChange` to detect sign-in completion. Does `supabase_flutter` fire `AuthChangeEvent.signedIn` after a browser-based OAuth redirect on Linux desktop? Or does the auth only complete if the redirect URL is handled by the app? If the deep link isn't supported on Linux, how does the auth token get back to the Flutter app?

2. **Auth subscription lifecycle** — `_authSub` is created in `_handleSignIn()` and cancelled in `_onSignInComplete()` and `dispose()`. Could the subscription leak if the user navigates away from Settings before sign-in completes? Is `dispose()` sufficient cleanup?

3. **`_isSyncLoading` initial state** — The field starts as `true` and is set to `false` after `_loadSyncState()` completes. But what if Supabase was never initialized (e.g., app started offline and `Supabase.initialize()` failed)? Will `getSyncMeta()` throw? Will the card stay in loading state forever?

4. **Sync toggle error recovery** — If `enableSync()` throws (e.g., user is null, network error), the UI never calls `setState()` to reset `_syncEnabled`. The toggle could show the wrong state. Is the catch block sufficient?

5. **`onDataChanged` callback ownership** — The plan wires the callback in `HomeScreen.initState()`. But what if the user is on `QuizScreen` (first launch) and a sync pull happens? `HomeScreen` hasn't been created yet, so `onDataChanged` is null. Is this a problem?

6. **Multiple `HomeScreen` instances** — If `HomeScreen` is pushed/popped multiple times (e.g., from QuizScreen → HomeScreen → Settings → pop → HomeScreen), could the callback get set to a disposed widget's method? The `mounted` check helps, but is there a lifecycle issue?

7. **Sign-out confirmation UX** — The plan shows a confirmation dialog for sign-out. Is this consistent with other destructive actions in the app? Does the dialog follow the existing AlertDialog pattern?

8. **`_lastSyncAt` accuracy** — The plan computes `max(lastPushAt, lastPullAt)`. But these are stored as epoch milliseconds in sync_meta. After toggling sync on for the first time, `fullPush()` runs but may not update `lastPushAt` (depending on whether `push()` updates meta after fullPush). Will `_lastSyncAt` be null even after a successful enable?

9. **Theme consistency** — Does the proposed UI (ElevatedButton, SwitchListTile, TextButton, SelectableText, Card) match the existing settings screen patterns? Any widget or style mismatches?

10. **Anything else** — Race conditions, missing edge cases, UX issues, accessibility.

### How to report

For each finding, rate severity:
- **CRITICAL** — Must fix before implementation. Broken functionality or data issue.
- **HIGH** — Should fix. Incorrect behavior in realistic scenarios.
- **MEDIUM** — Worth discussing. Design tradeoff or minor edge case.
- **LOW** — Nit or suggestion. Won't cause problems but could be better.

---

## Plan Reference

(Full plan pasted below for convenience)

---

# Pin and Paper — Sync UI Implementation Plan

**Version:** 1.0
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

`supabase_flutter` doesn't support deep link redirect on Linux. The flow:
1. Call `AuthService.signInWithGoogle()` which returns the OAuth URL
2. `url_launcher` attempts to open the URL in the system browser
3. **Also display the URL** in a selectable text field with a copy button
4. Show instruction: "Sign in with your browser. If it didn't open automatically, copy the link below."
5. Listen for `AuthService.onAuthStateChange` to detect successful sign-in
6. On `AuthChangeEvent.signedIn` → update UI, optionally auto-enable sync

### Error handling philosophy

Same as the rest of the sync layer: **never block the UI**. All sync operations are wrapped in try/catch. Errors are shown as temporary SnackBars, not blocking dialogs. The user can always dismiss and continue using the app offline.

---

## Implementation Steps

### Step 1: Wire `onDataChanged` callback (main.dart)

**File:** `pin_and_paper/lib/main.dart`

After `SyncService.instance.initialize()`, wire the callback:

```dart
// Wire sync pull → UI refresh
SyncService.instance.onDataChanged = () {
  // TaskProvider isn't available here (no BuildContext), so we use
  // a global key or a static reference. Simplest: just use the
  // navigatorKey approach, or set it up in the widget tree.
};
```

**Problem:** `main()` doesn't have a `BuildContext` to access `TaskProvider`. The cleanest approach: set the callback in `_LaunchRouter.initState()` (or `HomeScreen.initState()`), where we have access to `Provider.of<TaskProvider>`.

**Recommended approach:** In `HomeScreen.initState()`:

```dart
@override
void initState() {
  super.initState();
  // ... existing init code ...

  // Phase 4.0: Refresh task list when sync pulls remote changes
  SyncService.instance.onDataChanged = () {
    if (mounted) {
      context.read<TaskProvider>().loadTasks();
    }
  };
}
```

This is minimal and follows the existing pattern — `HomeScreen.initState()` already sets up notification callbacks. The callback calls `loadTasks()` (full reload) since pull can change tasks, tags, and task_tags simultaneously.

**Cleanup in dispose:**

```dart
@override
void dispose() {
  SyncService.instance.onDataChanged = null;
  // ... existing dispose ...
  super.dispose();
}
```

**Lines changed:** ~6 in `home_screen.dart`

---

### Step 2: Add Cloud Sync section to Settings screen

**File:** `pin_and_paper/lib/screens/settings_screen.dart`

#### 2a. New imports

```dart
import '../services/auth_service.dart';     // Phase 4.0
import '../services/sync_service.dart';     // Phase 4.0
```

#### 2b. New state fields

```dart
// Phase 4.0: Cloud Sync state
bool _syncEnabled = false;
bool _isSyncLoading = true;   // true while loading initial sync state
bool _isSigningIn = false;    // true during OAuth flow
String? _signedInEmail;       // null if not signed in
DateTime? _lastSyncAt;        // max of lastPushAt and lastPullAt
String? _oauthUrl;            // non-null during sign-in flow (copy/paste fallback)
StreamSubscription<AuthState>? _authSub;
```

#### 2c. Load sync state in `initState()`

Add call to `_loadSyncState()`:

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
}
```

Implementation:

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

#### 2d. Clean up auth subscription in `dispose()`

```dart
@override
void dispose() {
  _apiKeyController.dispose();
  _authSub?.cancel();  // Phase 4.0
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
│  ☁  Cloud Sync                          │
│  Sign in to sync your tasks with Claude │
│                                         │
│  [  Sign in with Google  ]              │
│                                         │
│  ─ ─ ─ (if _oauthUrl != null) ─ ─ ─ ─  │
│  If your browser didn't open, copy      │
│  this link and paste it in your browser:│
│  ┌─────────────────────────────┐ [Copy] │
│  │ https://...oauth-url...     │        │
│  └─────────────────────────────┘        │
└─────────────────────────────────────────┘
```

**State B: Signed in, sync disabled**
```
┌─────────────────────────────────────────┐
│  user@example.com              [Switch] │
│                                         │
│  ○ Sync disabled                        │
│  ──────────────────────────(  toggle  ) │
│                                         │
│  [Sign Out]                             │
└─────────────────────────────────────────┘
```

**State C: Signed in, sync enabled**
```
┌─────────────────────────────────────────┐
│  user@example.com              [Switch] │
│                                         │
│  ● Sync enabled                         │
│  ──────────────────────────(  toggle  ) │
│                                         │
│  Last synced: 2 minutes ago             │
│                                         │
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
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login),
        label: Text(_isSigningIn ? 'Opening browser...' : 'Sign in with Google'),
      ),
    ),
    // Copy/paste fallback for OAuth URL
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
    ],
  ];
}
```

#### 2h. Signed-in content (States B & C)

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
      title: Text(
        _syncEnabled ? 'Sync enabled' : 'Sync disabled',
      ),
      subtitle: _syncEnabled && _lastSyncAt != null
          ? Text(
              'Last synced: ${_formatLastSync(_lastSyncAt!)}',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            )
          : null,
      value: _syncEnabled,
      onChanged: _handleSyncToggle,
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

```dart
/// Sign in with Google OAuth.
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

    // Listen for auth completion
    _authSub?.cancel();
    _authSub = AuthService.instance.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        _authSub?.cancel();
        _onSignInComplete();
      }
    });
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

/// Called when OAuth flow completes successfully.
void _onSignInComplete() {
  final user = AuthService.instance.currentUser;
  if (mounted) {
    setState(() {
      _isSigningIn = false;
      _oauthUrl = null;
      _signedInEmail = user?.email;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed in successfully')),
    );
  }
}

/// Toggle sync on/off.
Future<void> _handleSyncToggle(bool enabled) async {
  try {
    if (enabled) {
      await SyncService.instance.enableSync();
    } else {
      await SyncService.instance.disableSync();
    }

    // Re-read meta to get accurate timestamps
    final meta = await SyncService.instance.getSyncMeta();
    if (mounted) {
      setState(() {
        _syncEnabled = enabled;
        _lastSyncAt = _latestOf(meta.lastPushAt, meta.lastPullAt);
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ${enabled ? "enable" : "disable"} sync: $e')),
      );
    }
  }
}

/// Sign out — disables sync, clears auth.
Future<void> _handleSignOut() async {
  // Confirmation dialog
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
    // SyncService auto-disables on sign-out (auth listener)
    if (mounted) {
      setState(() {
        _syncEnabled = false;
        _signedInEmail = null;
        _lastSyncAt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out')),
      );
    }
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

### Step 3: Summary of changes

| File | Change | Est. Lines |
|------|--------|-----------|
| `home_screen.dart` | Wire `SyncService.onDataChanged` → `TaskProvider.loadTasks()` in initState/dispose | ~8 |
| `settings_screen.dart` | Add imports, state fields, `_loadSyncState()`, Cloud Sync section with 3 states, action handlers, time formatting | ~220 |
| **Total** | | **~228** |

No new files. No new providers. No new dependencies. Two existing files modified.

---

## Edge Cases

### 1. Sign in → don't enable sync

The user may sign in but leave the sync toggle off. This is valid. Their account is authenticated but no data flows to Supabase. `SyncService.enableSync()` is only called when the toggle is switched on.

### 2. App restart while signed in

On app restart, `SyncService.initialize()` checks `sync_meta.syncEnabled` and the current auth user. If both valid, sync resumes automatically. The Settings screen reads the same meta on `initState()` and shows the correct state.

### 3. OAuth URL display timing

The `_oauthUrl` is set immediately after `getOAuthSignInUrl()` returns. It stays visible until auth succeeds or the user leaves the screen. If the user navigates away and back, the URL is gone but they can tap "Sign in" again.

### 4. Auth token expiry

Supabase handles token refresh automatically via `supabase_flutter`. If the refresh token is also expired, the user will be signed out (auth listener fires `signedOut` → `_onUserSignedOut()` → sync disabled). The Settings UI will show the signed-out state on next visit.

### 5. Sync toggle while offline

If the user enables sync while offline, `enableSync()` calls `fullPush()` which will fail silently (try/catch in SyncService). The sync_meta is already set to enabled, so when connectivity returns, the connectivity listener triggers push → pull. No data loss.

### 6. Multiple rapid toggles

`enableSync()` calls `fullPush()` which is guarded by `_isSyncing`. If the user rapidly toggles, the second call returns `SyncResult.skipped`. The `_syncEnabled` state tracks the toggle position, not the network result.

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
2. **Sign in flow:** Tap "Sign in" → browser opens → complete Google OAuth → Settings updates to show email, toggle off.
3. **Copy/paste fallback:** OAuth URL appears below button. Copy button works. URL disappears after sign-in.
4. **Enable sync:** Toggle on → `fullPush()` runs → last sync time appears.
5. **Disable sync:** Toggle off → sync stops → last sync time remains visible.
6. **Sign out:** Tap "Sign out" → confirmation dialog → confirm → UI resets to signed-out state.
7. **Remote change refresh:** Claude creates a task via MCP → realtime fires → `pull()` merges → `onDataChanged` fires → task list refreshes automatically.
8. **App restart:** Reopen app → Settings shows correct signed-in state and sync toggle position.
9. **Offline behavior:** All buttons work. Sync failures are silent. SnackBars appear only for auth errors (not sync errors).

---

## Findings

### Finding 1: OAuth completion on Linux is not actually solved

**Severity:** HIGH  
**Location:** Plan → “Auth flow on Linux desktop”, Step 2i `_handleSignIn()`  
**Description:** The plan assumes `AuthChangeEvent.signedIn` will fire after browser-based OAuth on Linux, but the redirect URL is a custom scheme (`io.supabase...`) that Linux won’t handle unless you register a desktop deep link. Without a loopback server or a manual “paste redirect URL” path that calls `supabase.auth.getSessionFromUrl`, the sign-in may never complete.  
**Suggested fix:** Add an explicit Linux-safe completion path: either a localhost redirect with a tiny listener, or a manual “paste redirect URL” flow that exchanges the code for a session.

---

### Finding 2: Sign-in can get stuck in a disabled state

**Severity:** MEDIUM  
**Location:** Step 2i `_handleSignIn()`  
**Description:** `_isSigningIn` is set to true and only reset on success or exception. If the user closes the browser or abandons OAuth, the UI stays “Opening browser…” and the sign-in button stays disabled indefinitely.  
**Suggested fix:** Add a timeout/reset (e.g., 60s) or a “Cancel / Retry” action that re-enables the button.

---

### Finding 3: Settings UI doesn’t react to auth sign-out events

**Severity:** MEDIUM  
**Location:** Step 2c/2i (`_loadSyncState`, auth listener)  
**Description:** The UI only listens for `signedIn` during OAuth. If the user is signed out elsewhere (token expiry, sign-out from another screen), Settings continues to show signed-in state until reopened.  
**Suggested fix:** Subscribe to `AuthService.onAuthStateChange` in `initState()` (not just during sign-in) and handle `signedOut` by resetting `_signedInEmail` and `_syncEnabled`.

---

### Finding 4: `onDataChanged` → `loadTasks()` breaks active filters

**Severity:** MEDIUM  
**Location:** Step 1 (HomeScreen callback)  
**Description:** `TaskProvider.loadTasks()` resets `_tasks` to the full hierarchy and ignores active filters. If a user has an active tag/date filter, a sync pull will reload unfiltered tasks while the UI still shows filter state, causing inconsistent views.  
**Suggested fix:** In the callback, detect active filters and reapply filter logic after load (or invoke the filter provider to re-run `_onFilterChanged`).

---

### Finding 5: “Last synced” display contradicts the plan

**Severity:** LOW  
**Location:** Step 2h (`_buildSignedInContent`), Verification step 5  
**Description:** The plan says last sync time remains visible after disabling sync, but the UI only shows it when `_syncEnabled == true`.  
**Suggested fix:** Show last sync time whenever `_lastSyncAt != null`, regardless of toggle state.

---

### Finding 6: Toggle lacks in-flight guard

**Severity:** LOW  
**Location:** Step 2h/2i (`SwitchListTile` + `_handleSyncToggle`)  
**Description:** The toggle is always enabled, so rapid toggles can issue overlapping enable/disable calls. If `SyncService` skips due to `_isSyncing`, the UI may not reflect the actual sync state.  
**Suggested fix:** Add an `_isSyncToggling` flag to disable the switch and show a spinner while enable/disable is running.

---

### Finding 7: Sign-in completion doesn’t refresh sync meta

**Severity:** LOW  
**Location:** Step 2i `_onSignInComplete()`  
**Description:** `_onSignInComplete()` updates only `_signedInEmail`. If sync was previously enabled for this user (e.g., app restart with valid session), the toggle might remain stale.  
**Suggested fix:** After sign-in, re-run `_loadSyncState()` to populate `_syncEnabled` and `_lastSyncAt` from `sync_meta`.
