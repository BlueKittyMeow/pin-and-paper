import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Authentication service for Google OAuth sign-in.
///
/// Phase 4.0: Supports desktop Linux with a copy/paste URL fallback
/// since supabase_flutter's deep link handling doesn't cover Linux.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange;

  /// Sign in with Google OAuth.
  ///
  /// Returns the OAuth URL for copy/paste fallback on desktop.
  /// Attempts to launch the URL in the system browser automatically.
  ///
  /// On Linux desktop:
  /// - Browser may or may not open automatically via url_launcher
  /// - UI should always display the URL as a clickable/copyable link
  /// - Auth completes when user finishes the flow in browser and
  ///   the redirect callback is processed
  Future<String> signInWithGoogle() async {
    // Use the underlying gotrue client to get the OAuth URL
    // (signInWithOAuth auto-launches but doesn't return the URL)
    final res = await _supabase.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: 'io.supabase.pinandpaper://login-callback/',
    );

    final url = res.url;

    // Attempt to auto-open browser
    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[Auth] Could not auto-open browser: $e');
      // UI will show the URL for manual copy/paste
    }

    return url;
  }

  /// Sign out. SyncService listens for auth changes and will
  /// auto-disable sync on sign-out.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
