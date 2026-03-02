import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Authentication service for Google OAuth sign-in.
///
/// Phase 4.0: On desktop Linux, uses a localhost callback server
/// since custom URL schemes require OS-level registration (.desktop file).
/// On mobile, uses deep links with app_links to catch the OAuth redirect.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange;

  HttpServer? _callbackServer;
  StreamSubscription? _deepLinkSub;

  /// Deep link redirect URL for mobile OAuth (Android/iOS).
  /// The app intercepts this via intent-filter / app_links.
  static const _mobileRedirectUrl =
      'io.supabase.pinandpaper://login-callback/';

  /// Sign in with Google OAuth.
  ///
  /// On desktop: starts a temporary localhost HTTP server to catch the
  /// OAuth callback, then opens the browser for Google sign-in.
  ///
  /// On mobile: uses a deep link redirect that the OS routes back to
  /// the app, then manually exchanges the PKCE code for a session.
  ///
  /// Returns the OAuth URL (for copy/paste fallback if browser doesn't open).
  Future<String> signInWithGoogle() async {
    final String redirectUrl;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: use deep link with explicit listener
      redirectUrl = _mobileRedirectUrl;
      _listenForDeepLink();
    } else {
      // Desktop: use localhost callback server
      const callbackPort = 54321;
      await _callbackServer?.close(force: true);
      _callbackServer = await HttpServer.bind('localhost', callbackPort);
      redirectUrl = 'http://localhost:$callbackPort/auth-callback';

      debugPrint('[Auth] Callback server listening on port $callbackPort');

      // Listen for the OAuth callback (don't await — runs in background)
      _listenForCallback(_callbackServer!);
    }

    // Get the OAuth URL with our platform-appropriate redirect
    final res = await _supabase.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: redirectUrl,
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

  /// Listen for the OAuth deep link callback on mobile.
  void _listenForDeepLink() {
    _deepLinkSub?.cancel();
    final appLinks = AppLinks();
    _deepLinkSub = appLinks.uriLinkStream.listen((uri) async {
      debugPrint('[Auth] Deep link received: $uri');
      final code = uri.queryParameters['code'];
      if (code != null) {
        try {
          await _supabase.auth.exchangeCodeForSession(code);
          debugPrint('[Auth] Session established via deep link');
        } catch (e) {
          debugPrint('[Auth] Failed to exchange code for session: $e');
        }
        _deepLinkSub?.cancel();
        _deepLinkSub = null;
      }
    });
  }

  /// Listen for the OAuth callback on the localhost server.
  void _listenForCallback(HttpServer server) {
    server.listen((request) async {
      final code = request.uri.queryParameters['code'];

      if (code != null) {
        // Send a nice response to the browser
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(
            '<html><body style="font-family: system-ui; text-align: center; padding: 60px;">'
            '<h1>Sign-in successful!</h1>'
            '<p>You can close this tab and return to Pin and Paper.</p>'
            '</body></html>',
          );
        await request.response.close();

        // Exchange the PKCE code for a session
        try {
          await _supabase.auth.exchangeCodeForSession(code);
          debugPrint('[Auth] Session established via localhost callback');
        } catch (e) {
          debugPrint('[Auth] Failed to exchange code for session: $e');
        }

        // Clean up the server
        await server.close();
        _callbackServer = null;
      } else {
        // Not the callback we're looking for
        request.response
          ..statusCode = 404
          ..write('Not found');
        await request.response.close();
      }
    });
  }

  /// Cancel an in-progress sign-in (closes the callback server).
  Future<void> cancelSignIn() async {
    await _callbackServer?.close(force: true);
    _callbackServer = null;
    _deepLinkSub?.cancel();
    _deepLinkSub = null;
  }

  /// Handle a pasted redirect URL to complete OAuth on platforms
  /// where the localhost callback didn't work.
  ///
  /// Accepts URLs like:
  /// - http://localhost:PORT/auth-callback?code=...
  /// - io.supabase.pinandpaper://login-callback/?code=...
  /// Returns true if session was established, false otherwise.
  Future<bool> handleRedirectUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      // Try extracting the code parameter (PKCE flow)
      final code = uri.queryParameters['code'];
      if (code != null) {
        await _supabase.auth.exchangeCodeForSession(code);
        await cancelSignIn(); // Clean up server if still running
        return true;
      }

      // Fallback: try getSessionFromUrl for implicit flow URLs
      await _supabase.auth.getSessionFromUrl(uri);
      await cancelSignIn();
      return true;
    } catch (e) {
      debugPrint('[Auth] Failed to parse redirect URL: $e');
      return false;
    }
  }

  /// Sign out. SyncService listens for auth changes and will
  /// auto-disable sync on sign-out.
  Future<void> signOut() async {
    await cancelSignIn();
    await _supabase.auth.signOut();
  }
}
