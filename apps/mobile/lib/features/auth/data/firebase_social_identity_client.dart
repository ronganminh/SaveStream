import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/repositories/auth_repository.dart';

/// Firebase verifies external provider credentials; the SaveStream backend
/// remains the sole issuer of application sessions and credits.
final class FirebaseSocialIdentityClient {
  static bool _googleInitialized = false;

  Future<String> getIdToken(SocialAuthProvider provider) async {
    UserCredential credential;
    try {
      if (provider == SocialAuthProvider.google) {
        if (!_googleInitialized) {
          await GoogleSignIn.instance.initialize();
          _googleInitialized = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final authentication = account.authentication;
        final googleIdToken = authentication.idToken;
        if (googleIdToken == null || googleIdToken.isEmpty) {
          throw const AuthException(AuthFailureCode.server);
        }
        credential = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: googleIdToken),
        );
      } else {
        final appleProvider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        credential = await FirebaseAuth.instance.signInWithProvider(
          appleProvider,
        );
      }

      final token = await credential.user?.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const AuthException(AuthFailureCode.server);
      }
      return token;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'web-context-cancelled' ||
          error.code == 'cancelled' ||
          error.code == 'canceled') {
        throw const AuthException(AuthFailureCode.cancelled);
      }
      if (error.code == 'operation-not-allowed' ||
          error.code == 'unsupported-platform' ||
          error.code == 'invalid-api-key') {
        throw const AuthException(AuthFailureCode.socialUnavailable);
      }
      throw const AuthException(AuthFailureCode.server);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException(AuthFailureCode.cancelled);
      }
      throw const AuthException(AuthFailureCode.server);
    } finally {
      // Avoid maintaining a second long-lived authentication session.
      try {
        await FirebaseAuth.instance.signOut();
        if (provider == SocialAuthProvider.google && _googleInitialized) {
          await GoogleSignIn.instance.signOut();
        }
      } on Object {
        // SaveStream token exchange will still validate any retrieved token.
      }
    }
  }
}
