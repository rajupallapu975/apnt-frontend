import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/backend_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 👤 Current User
  User? get currentUser => _auth.currentUser;

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

  /// 📧 Email & Password Sign-In (For Reviewer Test Account)
  Future<User?> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    // 🔑 Special Reviewer Test Account Fallback: reviewer@zikrint.app / raju@975
    if (cleanEmail == 'reviewer@zikrint.app' && cleanPass == 'raju@975') {
      // 1. Attempt standard Email/Password sign-in
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPass,
        );
        await credential.user?.updateDisplayName('Reviewer User');
        return credential.user;
      } catch (e) {
        debugPrint('⚠️ Firebase Email Auth failed ($e), attempting custom token from backend...');
      }

      // 2. Attempt custom token from backend (bypasses Firebase Console Email Provider restriction)
      try {
        final urlsToTry = [
          BackendConfig.baseUrl,
          'http://192.168.0.206:5001',
          'http://localhost:5001',
        ];
        for (final baseUrl in urlsToTry) {
          try {
            final res = await http.post(
              Uri.parse('$baseUrl/api/reviewer-token'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': cleanEmail, 'password': cleanPass}),
            ).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              if (data['success'] == true && data['token'] != null) {
                final userCred = await _auth.signInWithCustomToken(data['token']);
                await userCred.user?.updateDisplayName('Reviewer User');
                debugPrint('✅ Reviewer custom token sign-in successful!');
                return userCred.user;
              }
            }
          } catch (_) {}
        }
      } catch (tokenErr) {
        debugPrint('⚠️ Custom token fetch failed: $tokenErr');
      }

      // 3. Attempt anonymous sign-in fallback
      try {
        final anonCred = await _auth.signInAnonymously();
        await anonCred.user?.updateDisplayName('Reviewer User');
        return anonCred.user;
      } catch (_) {
        return _auth.currentUser;
      }
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPass,
      );
      return credential.user;
    } catch (e) {
      debugPrint('❌ Email Sign-In Error: $e');
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

  /// 🗑️ Delete Account permanently from Firebase Auth
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
