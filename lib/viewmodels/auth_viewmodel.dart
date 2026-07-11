import 'package:apnt/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  String? _phoneNumber;
  bool _isLoading = true;

  AuthViewModel() {
    _authService.user.listen((user) async {
      _user = user;
      if (user != null) {
        await _loadUserProfile();
        _syncUserProfileToFirestore(user);
        // 🔔 Restart notification listeners with correct user email
        NotificationService().initOrderListeners();
      } else {
        _phoneNumber = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _syncUserProfileToFirestore(User user) async {
    try {
      await FirestoreService().syncUserProfile(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
    } catch (e) {
      debugPrint("⚠️ Failed to sync user profile: $e");
    }
  }

  Future<void> _loadUserProfile() async {
    // 🔍 Try Firestore first
    String? phone = await FirestoreService().getUserPhone();
    bool fromLocal = false;
    
    // 📂 Fallback to local storage if Firestore is empty/fails
    if (phone == null || phone.isEmpty) {
      phone = await LocalStorageService().getLastPhone();
      fromLocal = true;
    }

    _phoneNumber = phone;
    notifyListeners();

    // If we loaded it from local storage, sync it to Firestore so it's saved in Firebase!
    if (fromLocal && phone != null && phone.isNotEmpty) {
      FirestoreService().updateUserPhone(phone).catchError((e) {
        debugPrint("⚠️ Syncing local phone to Firestore failed: $e");
      });
    }
  }

  User? get user => _user;
  String? get phoneNumber => _phoneNumber;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<void> updatePhoneNumber(String phone) async {
    _phoneNumber = phone;
    notifyListeners();
    
    // 🔥 Fire and forget both updates
    FirestoreService().updateUserPhone(phone).catchError((e) {
      debugPrint("⚠️ Firestore phone update failed: $e");
    });
    LocalStorageService().saveLastPhone(phone);
  }

  /// 🔐 Sign in
  Future<bool> signIn() async {
    if (_isLoading) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();

      if (user != null) {
        HapticFeedback.lightImpact(); // ✅ SUCCESS FEEDBACK
        return true;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 🚪 Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
