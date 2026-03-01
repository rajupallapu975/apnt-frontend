import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/print_order_model.dart';
import '../utils/app_exceptions.dart';
import 'local_storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  CollectionReference get _ordersCollection =>
      _firestore.collection('orders');

  String? get _currentUserId =>
      _auth.currentUser?.uid;

  CollectionReference get _usersCollection => _firestore.collection('users');

  /* =================================================
     USER PROFILE MANAGEMENT
  ================================================= */

  Future<void> updateUserPhone(String phone) async {
    if (_currentUserId == null) return;
    try {
      await _usersCollection.doc(_currentUserId).set({
        'phoneNumber': phone,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("❌ Profile Phone Update Error: $e");
    }
  }

  /// 🔄 SYNC USER STATS AFTER SUCCESSFUL PAYMENT
  Future<void> syncUserPostPayment({
    required double amount,
    required String? phone,
    required int pages,
    required int files,
  }) async {
    if (_currentUserId == null) return;
    try {
      final userDoc = _usersCollection.doc(_currentUserId);
      final batch = _firestore.batch();

      batch.set(userDoc, {
        if (phone != null) 'phoneNumber': phone,
        'totalSpent': FieldValue.increment(amount),
        'totalOrders': FieldValue.increment(1),
        'totalPages': FieldValue.increment(pages),
        'totalFiles': FieldValue.increment(files),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint("✅ Account-wide stats updated for user: $_currentUserId");
    } catch (e) {
      debugPrint("❌ User Stats Sync Error: $e");
    }
  }

  Future<String?> getUserPhone() async {
    if (_currentUserId == null) return null;
    try {
      final doc = await _usersCollection.doc(_currentUserId).get();
      if (doc.exists) {
        return doc.get('phoneNumber') as String?;
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint("🔐 Profile Read: Permission Denied (Check Firestore Rules)");
      } else {
        debugPrint("❌ Profile Read Error: $e");
      }
    }
    return null;
  }

  /* =================================================
     ATTACH FILE URLS AFTER CLOUDINARY UPLOAD
  ================================================= */

  Future<void> attachFilesToOrder({
    required String orderId,
    required List<String> fileUrls,
    required List<String> publicIds,
    required List<String> localFilePaths,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'fileUrls': fileUrls,
        'publicIds': publicIds,
        'localFilePaths': localFilePaths,
        'status': 'ACTIVE',
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 12))),
      });
    } catch (e) {
      throw FirestoreException(
        "Failed to attach files: $e",
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /* =================================================
     GET ALL USER ORDERS
  ================================================= */

  Stream<List<PrintOrderModel>> getUserOrders() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _ordersCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs
                .map((doc) =>
                    PrintOrderModel.fromFirestore(doc))
                .toList());
  }

  /* =================================================
     GET ACTIVE ORDERS
  ================================================= */

  Stream<List<PrintOrderModel>> getActiveOrders() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _ordersCollection
        .where('userId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'ACTIVE')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => PrintOrderModel.fromFirestore(doc))
          .toList();

      // 🕒 Background Auto-Expiry Check
      final now = DateTime.now();
      for (var order in orders) {
        if (order.expiresAt.isBefore(now)) {
          updateOrderStatus(orderId: order.orderId, status: 'EXPIRED');
        }
      }

      // Only return orders that are actually still active (not expired)
      return orders.where((o) => o.expiresAt.isAfter(now)).toList();
    });
  }

  /* =================================================
     ACCOUNT-WIDE STATISTICS
  ================================================= */

  Future<Map<String, dynamic>> getUserStatistics() async {
    if (_currentUserId == null) {
      return {
        'totalAmount': 0.0,
        'totalOrders': 0,
        'totalPages': 0,
        'totalFiles': 0,
      };
    }

    try {
      // 🥇 First, try to get cached totals from user document
      final userDoc = await _usersCollection.doc(_currentUserId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('totalSpent')) {
          return {
            'totalAmount': (data['totalSpent'] ?? 0.0).toDouble(),
            'totalOrders': (data['totalOrders'] ?? 0).toInt(),
            'totalPages': (data['totalPages'] ?? 0).toInt(), // Future: increment on completion
            'totalFiles': (data['totalFiles'] ?? 0).toInt(),
          };
        }
      }

      // 🥈 Fallback: Manual aggregation if user doc doesn't have fields yet
      final querySnapshot = await _ordersCollection
          .where('userId', isEqualTo: _currentUserId)
          .get();

      double totalAmount = 0.0;
      int totalOrders = 0;
      int totalPages = 0;
      int totalFiles = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toUpperCase() ?? '';
        
        if (status == 'COMPLETED' || status == 'ACTIVE' || status == 'EXPIRED') {
          totalAmount += (data['totalPrice'] ?? 0.0).toDouble();
          totalOrders++;
          totalPages += (data['totalPages'] as num? ?? 0).toInt();
          totalFiles += (data['printSettings']?['files'] as List? ?? []).length;
        }
      }

      return {
        'totalAmount': totalAmount,
        'totalOrders': totalOrders,
        'totalPages': totalPages,
        'totalFiles': totalFiles,
      };
    } catch (e) {
      debugPrint("❌ Stats Calculation Error: $e");
      return {
        'totalAmount': 0.0,
        'totalOrders': 0,
        'totalPages': 0,
        'totalFiles': 0,
      };
    }
  }

  /* =================================================
     UPDATE ORDER STATUS
  ================================================= */

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'status': status,
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(
        "Failed to update order status: ${e.message}",
        e,
      );
    }
  }

  /* =================================================
     GET SINGLE ORDER
  ================================================= */

  Future<PrintOrderModel?> getOrder(
      String orderId) async {
    try {
      final doc =
          await _ordersCollection.doc(orderId).get();

      if (!doc.exists) return null;

      return PrintOrderModel.fromFirestore(doc);

    } on FirebaseException catch (e) {
      throw FirestoreException(
        "Failed to fetch order: ${e.message}",
        e,
      );
    }
  }

  /* =================================================
     DELETE ORDER
  ================================================= */

  Future<void> deleteOrder(String orderId) async {
    try {
      await _ordersCollection.doc(orderId).delete();
    } on FirebaseException catch (e) {
      throw FirestoreException(
        "Failed to delete order: ${e.message}",
        e,
      );
    }
  }

  /* =================================================
     ARCHIVE ORDER LOCALLY (After Print or Expiry)
  ================================================= */

  Future<void> archiveOrderLocally(
      PrintOrderModel order) async {
    try {
      await LocalStorageService()
          .saveOrderLocally(order);

      debugPrint(
          '✅ Order ${order.orderId} archived locally');
    } catch (e) {
      debugPrint('❌ Error archiving order: $e');
    }
  }

  /* =================================================
     GET ARCHIVED ORDERS (Local Only)
  ================================================= */

  Future<List<PrintOrderModel>>
      getArchivedOrders() async {
    try {
      return await LocalStorageService()
          .getLocalOrders();
    } catch (e) {
      return [];
    }
  }
}
