# Sync UI Plan Review — Gemini

**Document under review:** `docs/specs/sync-ui-plan.md` v1.0
**Reviewer:** Gemini
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

---

## Findings

### Finding 1: OAuth Redirect Gap on Linux (Broken Auth)

**Severity:** CRITICAL
**Location:** Section "Auth flow on Linux desktop" / `AuthService`
**Description:**
The plan correctly identifies that `supabase_flutter` doesn't support deep links on Linux. It proposes showing the OAuth URL for copy/paste and listening to `onAuthStateChange`. However, there is a fundamental logic gap: **How does the authentication session get back into the app?**

When the user finishes OAuth in their browser, Supabase will redirect them to `io.supabase.pinandpaper://login-callback/`. Since Linux doesn't handle this scheme, the browser will error. The Flutter app instance, which is merely "listening" to auth state changes, will never receive the session/token because nothing has provided it to the Supabase client. Unlike a web app, there is no shared cookie domain between the system browser and the compiled Linux binary.

**Suggested fix:**
On Linux desktop, you must either:
1.  **Manual Redirect Parsing**: Provide an input field in the UI for the user to paste the final "broken" redirect URL (the one starting with `io.supabase.pinandpaper://`). The app can then parse the `access_token` and `refresh_token` from that string and pass them to `Supabase.instance.client.auth.setSession()`.
2.  **Local Loopback Server**: Use a package or custom code to temporarily listen on `http://localhost:<port>` and provide that as the `redirectTo`.

---

### Finding 2: Race Condition in Auth Listener Setup

**Severity:** HIGH
**Location:** Section 2i, `_handleSignIn()`
**Description:**
The plan attaches the `_authSub` listener *after* awaiting `AuthService.instance.signInWithGoogle()`. 

```dart
final url = await AuthService.instance.signInWithGoogle();
// ...
_authSub = AuthService.instance.onAuthStateChange.listen(...);
```

If the sign-in flow completes near-instantly (e.g., the browser is already authenticated and redirects immediately), the `signedIn` event could fire before the listener is established in the Flutter app. This would leave the UI stuck in the `_isSigningIn` state.

**Suggested fix:**
Initialize the `_authSub` listener **before** calling `signInWithGoogle()`.

---

### Finding 3: Toggle State Inconsistency on Service Failure

**Severity:** HIGH
**Location:** Section 2i, `_handleSyncToggle()`
**Description:**
If `enableSync()` or `disableSync()` throws an error (e.g., network failure during `fullPush()`), the catch block shows a SnackBar but **fails to reset the toggle's local `_syncEnabled` state**. 

This results in a UI that lies to the user: the switch will show "Sync enabled" even though the underlying operation failed and the setting wasn't persisted in the metadata.

**Suggested fix:**
In the `catch` block of `_handleSyncToggle`, explicitly reset `_syncEnabled = !enabled` to ensure the UI reflects the actual state of the system.

---

### Finding 4: Stale UI State During Background Sync

**Severity:** MEDIUM
**Location:** Section 1, `HomeScreen.initState()` vs `SettingsScreen`
**Description:**
The plan wires `SyncService.onDataChanged` to `HomeScreen` to refresh the task list. However, it does not wire it to `SettingsScreen`. If a background pull updates the `lastPullAt` timestamp while the user is viewing the Settings screen, the "Last synced" text will not update until they leave and return.

**Suggested fix:**
`SettingsScreen` should also subscribe to `SyncService.onDataChanged` (or a similar stream) to refresh its local `_lastSyncAt` variable whenever background sync activity occurs.

---

### Finding 5: UI Feedback Gap for Long Initial Sync

**Severity:** MEDIUM
**Location:** Section 2i, `_handleSyncToggle()`
**Description:**
`enableSync()` triggers `fullPush()`, which can take several seconds if the user has many tasks. During this time, the toggle is flipped, but the UI provides no indication that a heavy "Initial Sync" is running. The user might close the app or navigate away, potentially interrupting the process if they think it's already done.

**Suggested fix:**
Add a loading indicator or status label (e.g., "Initializing cloud data...") to the sync card while `enableSync()` is in progress.

---

### Finding 6: Missing Imports

**Severity:** LOW
**Location:** Section 2a, `settings_screen.dart`
**Description:**
The plan uses `StreamSubscription` and `Clipboard` but does not include the necessary imports in the guide.

**Suggested fix:**
Add `import 'dart:async';` and `import 'package:flutter/services.dart';` to the implementation instructions.

---

## Summary

**Total findings:** 6
**Critical:** 1
**High:** 2
**Medium:** 2
**Low:** 1

**Overall assessment:**
The UI design is consistent with the app's existing patterns, but the **Linux auth redirect gap** is a critical functional blocker that must be solved before coding begins. The race condition in listener setup and the error-state handling for the sync toggle are also high-priority fixes needed to ensure a robust implementation.
