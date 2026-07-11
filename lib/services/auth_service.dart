import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔁 Auth state
  Stream<User?> get user => _auth.authStateChanges();

  /// 🔐 Google Sign-In
  Future<User?> signInWithGoogle() async {
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

  /// 🚪 Logout
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
}
