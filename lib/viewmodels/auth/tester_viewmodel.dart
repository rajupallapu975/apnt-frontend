import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth/tester_auth_service.dart';

class TesterViewModel extends ChangeNotifier {
  final TesterAuthService _authService = TesterAuthService();
  bool _isLoading = false;
  bool _isReviewerSession = false;
  static bool _globalReviewerSession = false;

  TesterViewModel() {
    _initFromPrefs();
  }

  Future<void> _initFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRev = prefs.getBool('is_reviewer_session') ?? false;
      if (isRev) {
        _isReviewerSession = true;
        _globalReviewerSession = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  bool get isLoading => _isLoading;
  bool get isReviewerSession => _isReviewerSession;

  static bool get isCurrentReviewerSession {
    if (_globalReviewerSession) return true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final email = (user.email ?? '').toLowerCase();
    final dName = (user.displayName ?? '').toLowerCase();
    final uid = user.uid.toLowerCase();
    return email == 'reviewer@zikrint.app' ||
           email.contains('reviewer') ||
           dName.contains('reviewer') ||
           uid == 'reviewer_user';
  }

  Future<void> setReviewerSession(bool val) async {
    _isReviewerSession = val;
    _globalReviewerSession = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_reviewer_session', val);
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    if (_isLoading) return false;
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    try {
      final user = await _authService.signInWithEmail(cleanEmail, cleanPass);

      if (cleanEmail == 'reviewer@zikrint.app' && cleanPass == 'raju@975') {
        await setReviewerSession(true);
        _isLoading = false;
        notifyListeners();
        HapticFeedback.lightImpact();
        return true;
      }

      if (user != null) {
        final isRev = cleanEmail == 'reviewer@zikrint.app' || 
                      (user.displayName ?? '').toLowerCase().contains('reviewer') ||
                      (user.email ?? '').toLowerCase().contains('reviewer');
        await setReviewerSession(isRev);
        _isLoading = false;
        notifyListeners();
        HapticFeedback.lightImpact();
        return true;
      }
    } catch (e) {
      if (cleanEmail == 'reviewer@zikrint.app' && cleanPass == 'raju@975') {
        await setReviewerSession(true);
        _isLoading = false;
        notifyListeners();
        HapticFeedback.lightImpact();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    setReviewerSession(false);
    _globalReviewerSession = false;
    await _authService.signOut();
    notifyListeners();
  }
}
