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
  bool _isReviewerSession = false;
  bool _showEmailLogin = false;

  bool _isAttemptingAnonSignIn = false;
  bool _anonSignInFailed = false;

  bool get isReviewerSession => _isReviewerSession;
  bool get showEmailLogin => _showEmailLogin;

  AuthViewModel() {
    // ⚙️ Stream auth config from backend (controls showEmailLogin)
    FirestoreService().streamAuthConfig().listen((config) {
      final newValue = config['showEmailLogin'] == true;
      if (_showEmailLogin != newValue) {
        _showEmailLogin = newValue;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint("⚠️ Auth config stream error: $e");
    });

    _authService.user.listen((user) async {
      _user = user;
      if (user != null) {
        _anonSignInFailed = false;
        _isAttemptingAnonSignIn = false;
        final email = (user.email ?? '').toLowerCase();
        final dName = (user.displayName ?? '').toLowerCase();
        if (email == 'reviewer@zikrint.app' || dName.contains('reviewer') || _isReviewerSession) {
          _isReviewerSession = true;
          _displayName = 'Reviewer User';
        }
        await _loadUserProfile();
        _syncUserProfileToFirestore(user);
        // 🔔 Restart notification listeners with correct user email
        NotificationService().initOrderListeners();
        _signInSecondaryAppsAnonymously();
        _isLoading = false;
        notifyListeners();
      } else {
        if (!_isReviewerSession) {
          _phoneNumber = null;
        }
        if (!_anonSignInFailed && !_isAttemptingAnonSignIn) {
          _signInAnonymously();
        } else {
          _isLoading = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> _signInAnonymously() async {
    if (_isAttemptingAnonSignIn || _anonSignInFailed) return;
    _isAttemptingAnonSignIn = true;
    try {
      debugPrint("🚀 Triggering auto-anonymous sign-in for guest user...");
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint("⚠️ Auto-anonymous sign-in failed: $e");
      _anonSignInFailed = true;
      _isLoading = false;
      notifyListeners();
    } finally {
      _isAttemptingAnonSignIn = false;
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
    final uid = _user?.uid;
    if (uid == null) return;

    // 🔍 1. Try Firestore first
    final data = await FirestoreService().getUserProfileData(uid);
    String? phone = data['phoneNumber'];
    String? name = data['displayName'];

    // 🌐 2. Fallback to Google Account name if Firestore name is not set
    if ((name == null || name.trim().isEmpty) && _user?.displayName != null && _user!.displayName!.trim().isNotEmpty) {
      name = _user!.displayName;
      FirestoreService().updateUserName(name!);
    }

    // 📂 3. Fallback to local storage if Firestore name is empty/fails
    if (name == null || name.trim().isEmpty) {
      name = await LocalStorageService().getLastName();
    }

    // 📂 4. Fallback to local storage if phone is empty
    if (phone == null || phone.isEmpty) {
      phone = await LocalStorageService().getLastPhone();
    }

    if (_isReviewerSession || (_user?.email ?? '').toLowerCase() == 'reviewer@zikrint.app') {
      _displayName = 'Reviewer User';
    } else {
      _displayName = name;
    }

    _phoneNumber = phone;
    notifyListeners();

    // 💾 Persist to local storage & sync so it is remembered across reinstalls
    if (name != null && name.isNotEmpty) {
      LocalStorageService().saveLastName(name);
    }
    if (phone != null && phone.isNotEmpty) {
      LocalStorageService().saveLastPhone(phone);
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
    LocalStorageService().saveLastName(name);
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

  /// 📧 Email Sign In (Reviewer Test Account)
  Future<bool> signInWithEmail(String email, String password) async {
    if (_isLoading) return false;

    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    try {
      final user = await _authService.signInWithEmail(cleanEmail, cleanPass);

    if (cleanEmail == 'reviewer@zikrint.app' && cleanPass == 'raju@975') {
      _isReviewerSession = true;
      _user = user ?? _authService.currentUser ?? FirebaseAuth.instance.currentUser;
      _displayName = 'Reviewer User';
      _isLoading = false;
      notifyListeners();
      HapticFeedback.lightImpact();
      return true;
    }

      if (user != null) {
        _user = user;
        _displayName = user.displayName ?? user.email ?? 'Reviewer User';
        _isLoading = false;
        notifyListeners();
        HapticFeedback.lightImpact();
        return true;
      }
    } catch (e) {
      if (cleanEmail == 'reviewer@zikrint.app' && cleanPass == 'raju@975') {
        _user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
        _displayName = 'Reviewer User';
        _isLoading = false;
        notifyListeners();
        HapticFeedback.lightImpact();
        return true;
      }
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 🚪 Sign out
  Future<void> signOut() async {
    _isReviewerSession = false;
    _displayName = null;
    _phoneNumber = null;
    _user = null;
    await LocalStorageService().clearAllData();
    await _authService.signOut();
    notifyListeners();
  }

  /// 🗑️ Delete Account Permanently
  Future<bool> deleteAccount() async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final uid = _user!.uid;
      final email = _user!.email;

      // 1. Delete user data from Firestore (user profile, orders, Cloudinary files)
      await FirestoreService().deleteUserAccountData(uid, email: email);

      // 2. Clear all local storage data
      await LocalStorageService().clearAllData();

      // 3. Delete Firebase Authentication User Account
      await _authService.deleteAccount();

      _user = null;
      _phoneNumber = null;
      _displayName = null;
      _isReviewerSession = false;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint("❌ Delete Account Failed in ViewModel: $e");
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
