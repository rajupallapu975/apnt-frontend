import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'base_auth_service.dart';

class GoogleAuthService implements BaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> get user => _auth.authStateChanges();

  /// 🔐 Google Sign-In
  Future<User?> signIn() async {
    try {
      // 🌐 WEB
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final credential = await _auth.signInWithPopup(provider);
        return credential.user;
      }

      // 📱 MOBILE
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null; // User cancelled the sign-in

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final result = await _auth.signInWithCredential(credential);

      return result.user;
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      if (e is FirebaseAuthException) {
        throw Exception("Auth Error: ${e.message}");
      }
      throw Exception("Authentication Failed: $e");
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (e) {
      debugPrint('❌ Logout Error: $e');
      throw Exception("Logout Error: $e");
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (e) {
      debugPrint('❌ Account Deletion Error: $e');
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          throw Exception("For security reasons, please sign out and sign back in before deleting your account.");
        }
        throw Exception("Auth Error: ${e.message}");
      }
      throw Exception("Account Deletion Failed: $e");
    }
  }
}
