import 'package:apnt/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  String? _phoneNumber;
  String? _displayName;
  bool _isLoading = true;

  AuthViewModel() {
    _authService.user.listen((user) async {
      _user = user;
      if (user != null) {
        await _loadUserProfile();
        _syncUserProfileToFirestore(user);
        // 🔔 Restart notification listeners with correct user email
        NotificationService().initOrderListeners();
        _signInSecondaryAppsAnonymously();
        _isLoading = false;
        notifyListeners();
      } else {
        _phoneNumber = null;
        _signInAnonymously();
      }
    });
  }

  Future<void> _signInAnonymously() async {
    try {
      debugPrint("🚀 Triggering auto-anonymous sign-in for guest user...");
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint("⚠️ Auto-anonymous sign-in failed: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _signInSecondaryAppsAnonymously() async {
    try {
      final secondaryApps = ["zikrint_admin", "zikrinter", "zikrint-944a4", "think-ink"];
      for (final appName in secondaryApps) {
        try {
          final app = Firebase.app(appName);
          final auth = FirebaseAuth.instanceFor(app: app);
          if (auth.currentUser == null) {
            await auth.signInAnonymously();
            debugPrint("🚀 Signed in anonymously to secondary app: $appName");
          }
        } catch (e) {
          debugPrint("⚠️ Anonymous auth failed for $appName: $e");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Secondary apps auth error: $e");
    }
  }

  Future<void> _syncUserProfileToFirestore(User user) async {
    try {
      await FirestoreService().syncUserProfile(
        uid: user.uid,
        email: user.email,
        displayName: null, // Do not auto-populate from Google in database
        photoUrl: user.photoURL,
      );
    } catch (e) {
      debugPrint("⚠️ Failed to sync user profile: $e");
    }
  }

  Future<void> _loadUserProfile() async {
    // 🔍 Try Firestore first
    final data = await FirestoreService().getUserProfileData();
    String? phone = data['phoneNumber'];
    _displayName = data['displayName'];

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
  String? get displayName => _displayName;
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

  Future<void> updateDisplayName(String name) async {
    _displayName = name;
    notifyListeners();
    
    FirestoreService().updateUserName(name).catchError((e) {
      debugPrint("⚠️ Firestore name update failed: $e");
    });
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
