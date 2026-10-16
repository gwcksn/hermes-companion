import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

const googleScopes = ['https://www.googleapis.com/auth/calendar.readonly', 'https://www.googleapis.com/auth/tasks'];

/// Google account access for the Workspace page. Abstract so tests never touch Play Services.
abstract class GoogleAuth {
  /// Interactive: account picker + scope consent. Throws on cancel/failure.
  Future<void> signIn();

  Future<void> signOut();

  /// An access token if one is available without UI, else null (signed out / consent needed).
  Future<String?> accessToken({bool forceRefresh = false});
}

/// Web client ID of the Google Cloud project: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
const _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class PlatformGoogleAuth implements GoogleAuth {
  Future<void>? _init;
  GoogleSignInClientAuthorization? _cached;

  Future<void> _ensureInit() =>
      _init ??= GoogleSignIn.instance.initialize(serverClientId: _serverClientId.isEmpty ? null : _serverClientId);

  @override
  Future<void> signIn() async {
    await _ensureInit();
    final account = await GoogleSignIn.instance.authenticate(scopeHint: googleScopes);
    _cached = await account.authorizationClient.authorizeScopes(googleScopes);
  }

  @override
  Future<void> signOut() async {
    _cached = null;
    await _ensureInit();
    await GoogleSignIn.instance.signOut();
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!.accessToken;
    try {
      await _ensureInit();
      final stale = _cached?.accessToken;
      if (forceRefresh && stale != null) {
        await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: stale);
      }
      _cached = await GoogleSignIn.instance.authorizationClient.authorizationForScopes(googleScopes);
      if (_cached == null) {
        // Not remembered by the authorization client: try a silent sign-in once.
        final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
        _cached = await account?.authorizationClient.authorizationForScopes(googleScopes);
      }
      return _cached?.accessToken;
    } catch (_) {
      return null;
    }
  }
}

final googleAuthProvider = Provider<GoogleAuth>((ref) => PlatformGoogleAuth());
