import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = true;

  AuthViewModel() {
    _authService.user.listen((user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  /// 🔐 Sign in
  Future<bool> signIn() async {
    if (_isLoading) return false;

    _isLoading = true;
    notifyListeners();

    final user = await _authService.signInWithGoogle();

    _isLoading = false;
    notifyListeners();

    if (user != null) {
      HapticFeedback.lightImpact(); // ✅ SUCCESS FEEDBACK
      return true;
    }
    return false;
  }

  /// 🚪 Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
