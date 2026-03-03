import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In Service - wraps the google_sign_in package
class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  static GoogleSignInService get instance => _instance;
  GoogleSignInService._internal();

  static const String _webClientId = '552313058949-hm5abs4p6drln1usnr0n984ptru5hv2a.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: _webClientId,
  );

  /// Sign in with Google and return the ID token.
  /// Returns null if cancelled or failed.
  Future<String?> signIn() async {
    try {
      // Sign out first to force account picker
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSignIn] User cancelled');
        return null;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        debugPrint('[GoogleSignIn] No ID token received');
        return null;
      }

      debugPrint('[GoogleSignIn] Got ID token for ${account.email}');
      return idToken;
    } on PlatformException catch (e) {
      debugPrint('[GoogleSignIn] PlatformException: code=${e.code}, message=${e.message}, details=${e.details}');
      rethrow;
    } catch (e) {
      debugPrint('[GoogleSignIn] Error: ${e.runtimeType}: $e');
      rethrow;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[GoogleSignIn] Sign out error: $e');
    }
  }
}
