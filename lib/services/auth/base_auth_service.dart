import 'package:firebase_auth/firebase_auth.dart';

abstract class BaseAuthService {
  /// 👤 Current Firebase User
  User? get currentUser;

  /// 🔁 Stream of Firebase user auth state changes
  Stream<User?> get user;

  /// 🚪 Logout current session
  Future<void> signOut();

  /// 🗑️ Delete user account permanently
  Future<void> deleteAccount();
}
