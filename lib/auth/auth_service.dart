import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  // iOS is configured via ios/Runner/Info.plist (GIDClientID + URL scheme).
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  SupabaseClient get _supabase => Supabase.instance.client;

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User canceled the flow.
      return;
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('Google sign-in did not return an ID token.');
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut({bool alsoSignOutGoogle = true}) async {
    // Supabase sign-out first so the app UI transitions immediately.
    await _supabase.auth.signOut();

    if (alsoSignOutGoogle) {
      // `signOut` is sufficient for most apps. Use `disconnect` if you want to
      // revoke consent and require a full account picker next time.
      await _googleSignIn.signOut();
    }
  }
}


