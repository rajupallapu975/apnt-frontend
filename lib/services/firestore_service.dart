import 'dart:convert';

import 'package:apnt/config/backend_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/print_order_model.dart';
import '../utils/app_exceptions.dart';
import 'local_storage_service.dart';
import 'package:rxdart/rxdart.dart';

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
    required bool isXerox,
  }) async {
    if (_currentUserId == null) return;
    try {
      final userDoc = _usersCollection.doc(_currentUserId);
      final batch = _firestore.batch();

      batch.set(userDoc, {
        ...?phone != null ? {'phoneNumber': phone} : null,
        'totalSpent': FieldValue.increment(amount),
        'totalOrders': FieldValue.increment(1),
        isXerox ? 'totalXeroxOrders' : 'totalKioskOrders': FieldValue.increment(1),
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

  /// 📐 GET THE NEXT ORDER NUMBER (e.g. 1, 2, 3...) FOR THE GIVEN TYPE
  Future<int> getNextOrderIndex(bool isXerox) async {
    if (_currentUserId == null) return 1;
    try {
      final userDoc = await _usersCollection.doc(_currentUserId).get();
      if (!userDoc.exists) return 1;
      
      final data = userDoc.data() as Map<String, dynamic>;
      final field = isXerox ? 'totalXeroxOrders' : 'totalKioskOrders';
      final currentCount = data[field] ?? 0;
      return (currentCount as int) + 1;
    } catch (e) {
      debugPrint("❌ Error getting order index: $e");
      return 1;
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

  /* =================================================
     SAVE SELECTED XEROX SHOP FOR USER
  ================================================= */

  /// Saves the shop the user just selected to their Firestore profile.
  Future<void> saveSelectedShop({
    required String shopId,
    required String shopName,
  }) async {
    if (_currentUserId == null) return;
    try {
      await _usersCollection.doc(_currentUserId).set({
        'selectedShop': {
          'id': shopId,
          'name': shopName,
          'selectedAt': FieldValue.serverTimestamp(),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("✅ Selected shop saved to Firebase: $shopName ($shopId)");
    } catch (e) {
      debugPrint("❌ Failed to save selected shop: $e");
    }
  }

  /* =================================================
     MARK CODE REVEALED (After QR Scan) — Permanent
  ================================================= */

  /// 📸 STEP 1: Marks the order as SCANNED via Backend (Dual-Sync)
  Future<void> markOrderScanned({
    required String orderId,
    String? shopId,
  }) async {
    try {
      debugPrint("📡 Calling Backend /mark-delivered for scan: $orderId at $shopId");
      
      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}/mark-delivered'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'shopId': shopId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint("✅ Backend Delivery Sync SUCCESS for Scan!");
      } else {
        debugPrint("⚠️ Backend Delivery Sync failed (${response.statusCode}). Falling back to primary only...");
        // 🏗️ Fallback: At least update primary if mirror failed
        await _firestore.collection('xerox_orders').doc(orderId).update({
          'scanned': true,
          'isPicked': true,
          'status': 'completed',
          'orderStatus': 'order completed',
          'scannedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("❌ Scanned Status Finalization Error: $e");
      rethrow;
    }
  }

  /// 🏁 STEP 2: Finalizes the pickup (Dual-Sync via Backend)
  Future<void> completeOrderPickup({
    required String orderId,
    String? shopId,
  }) async {
    try {
      debugPrint("📡 Calling Backend /mark-delivered for pickup: $orderId at $shopId");
      
      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}/mark-delivered'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'shopId': shopId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint("✅ Backend Delivery Sync SUCCESS for Pickup!");
      } else {
        debugPrint("⚠️ Backend Delivery Sync failed (${response.statusCode}). Falling back to primary only...");
        // 🏗️ Fallback: At least update primary
        await _firestore.collection('xerox_orders').doc(orderId).update({
          'isPicked': true,
          'orderDone': true,
          'status': 'completed',
          'orderStatus': 'order completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("❌ Pickup Finalization Error: $e");
      rethrow;
    }
  }

  /// Marks codeRevealed=true on the Xerox order permanently so the pickup
  /// code stays revealed across app restarts. Also writes to shops/{shopId}/orders/.
  Future<void> markCodeRevealed({
    required String orderId,
    String? shopId,
  }) async {
    try {
      // ✅ Update customer-facing xerox_orders collection
      await _firestore.collection('xerox_orders').doc(orderId).update({
        'codeRevealed': true,
        'codeRevealedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Code marked as revealed for order: $orderId");

      // ✅ Also update shops/{shopId}/orders/{orderId} (admin DB sync)
      if (shopId != null && shopId.isNotEmpty) {
        try {
          final adminApp = Firebase.app('thinkink_admin');
          final adminFirestore = FirebaseFirestore.instanceFor(app: adminApp);

          await adminFirestore
              .collection('shops')
              .doc(shopId)
              .collection('orders')
              .doc(orderId)
              .update({
            'codeRevealed': true,
            'codeRevealedAt': FieldValue.serverTimestamp(),
          });
          debugPrint("✅ Code reveal synced to shops/$shopId/orders/$orderId (Admin project)");
        } catch (e) {
          debugPrint("⚠️ Note: Shop-level code reveal not synced (Admin project): $e");
        }
      }
    } catch (e) {
      debugPrint("❌ Failed to mark code as revealed: $e");
    }
  }

  /* =================================================
     ATTACH FILE URLS AFTER CLOUDINARY UPLOAD
  ================================================= */

  Future<void> attachFilesToOrder({
    required String orderId,
    required List<String> fileUrls,
    required List<String> publicIds,
    required List<String> localFilePaths,
    String printMode = 'autonomous',
    String? shopId, // Pass shopId for Xerox to also update shop subcollection
  }) async {
    try {
      final isXerox = printMode == 'xeroxShop';
      final collection = isXerox ? 'xerox_orders' : 'orders';

      final updatePayload = {
        'fileUrls': fileUrls,
        'publicIds': publicIds,
        'localFilePaths': localFilePaths,
        'status': 'ACTIVE',
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 12))),
      };

      // ✅ 1. Update the customer-facing collection
      await _firestore.collection(collection).doc(orderId).update(updatePayload);

      // ✅ 2. For Xerox orders, also sync to shop's subcollection so admin sees files
      if (isXerox && shopId != null && shopId.isNotEmpty) {
        try {
          await _firestore
              .collection('shops')
              .doc(shopId)
              .collection('orders')
              .doc(orderId)
              .update({
            'fileUrls': fileUrls,
            'fileUrl': fileUrls.isNotEmpty ? fileUrls[0] : null,
            'status': 'pending',
            'paymentStatus': 'done',
          });
          debugPrint("✅ File URLs synced to shop subcollection: shops/$shopId/orders/$orderId");
        } catch (e) {
          debugPrint("⚠️ Shop subcollection sync failed (order may still be ok): $e");
        }
      }
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
    final String? userEmail = _auth.currentUser?.email;
    if (userEmail == null) {
      return Stream.value([]);
    }

    return _ordersCollection
        .where('userId', isEqualTo: userEmail)
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
    final user = _auth.currentUser;
    final String userEmail = user?.email ?? 'guest_user';

    debugPrint("🔍 FirestoreService: getActiveOrders - Fetching for email: $userEmail");
    
    // Stream 1: Kiosk Orders
    final kioskStream = _ordersCollection
        .where('userId', isEqualTo: userEmail)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList());

    // Stream 2: Xerox Shop Orders
    final xeroxStream = _firestore.collection('xerox_orders')
        .where('userId', isEqualTo: userEmail)
        .where('status', whereIn: ['ACTIVE', 'completed', 'printing', 'ready'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList());

    return CombineLatestStream.combine2<List<PrintOrderModel>, List<PrintOrderModel>, List<PrintOrderModel>>(
      kioskStream,
      xeroxStream,
      (kiosk, xerox) {
        // Merge both lists
        final merged = [...kiosk, ...xerox];
        
        // Remove duplicates by orderId (just in case)
        final uniqueMap = <String, PrintOrderModel>{};
        for (var o in merged) {
          uniqueMap[o.orderId] = o;
        }

        final now = DateTime.now();
        // Filter by expiry and sort by creation time
        final filtered = uniqueMap.values.where((o) => o.expiresAt.isAfter(now)).toList();
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return filtered;
      },
    );
  }

  Stream<List<PrintOrderModel>> getActiveXeroxOrders() {
    final user = _auth.currentUser;
    final String userEmail = user?.email ?? 'guest_user';

    debugPrint("🔍 FirestoreService: getActiveXeroxOrders - Fetching for email: $userEmail");
    
    return _firestore.collection('xerox_orders')
        .where('userId', isEqualTo: userEmail)
        .where('status', whereIn: ['ACTIVE', 'completed', 'printing', 'ready'])
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList();
      final now = DateTime.now();
      final filtered = orders.where((o) => o.expiresAt.isAfter(now)).toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
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
      final String? userEmail = _auth.currentUser?.email;
      final querySnapshot = await _ordersCollection
          .where('userId', isEqualTo: userEmail)
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
    String printMode = 'autonomous',
  }) async {
    try {
      final collection = printMode == 'xeroxShop' ? 'xerox_orders' : 'orders';
      await _firestore.collection(collection).doc(orderId).update({
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
      String orderId, {String printMode = 'autonomous'}) async {
    try {
      final collection = printMode == 'xeroxShop' ? 'xerox_orders' : 'orders';
      final doc =
          await _firestore.collection(collection).doc(orderId).get();

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
     VERIFY ORDER EXISTS AT SCANNED SHOP (Firebase check)
  ================================================= */

  /// Returns true only if:
  ///   1. The xerox_order document exists in Firestore
  ///   2. Its `xeroxId` field matches [scannedShopId]
  /// This replaces the local-only check so the user cannot spoof verification.
  Future<bool> verifyOrderAtShop({
    required String orderId,
    required String scannedShopId,
  }) async {
    try {
      debugPrint('🔍 Verifying order $orderId at shop $scannedShopId');
      final doc = await _firestore
          .collection('xerox_orders')
          .doc(orderId)
          .get();

      if (!doc.exists) {
        debugPrint('❌ Verify: order $orderId not found in xerox_orders');
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final storedXeroxId = data['xeroxId']?.toString() ?? '';
      final storedShopId = data['shopId']?.toString() ?? '';

      // Match if xeroxId OR shopId matches the scanned shop ID
      // (old orders: xeroxId=4-digit BUT shopId=Firestore shop doc ID ✅)
      // (new orders: xeroxId=Firestore shop doc ID ✅)
      final match = storedXeroxId == scannedShopId || storedShopId == scannedShopId;
      debugPrint(match
          ? '✅ Verify: order $orderId belongs to shop $scannedShopId'
          : '❌ Verify: no match — xeroxId=$storedXeroxId shopId=$storedShopId scanned=$scannedShopId');
      return match;
    } catch (e) {
      debugPrint('❌ Verify error: $e');
      return false;
    }
  }


  /* =================================================
     DELETE ORDER
  ================================================= */

  /// 🗑️ CASCADE DELETE — removes order from ALL collections:
  /// - xerox_orders/{orderId}
  /// - shops/{shopId}/orders/{orderId}  (if shopId is known)
  /// - orders/{orderId} (for kiosk orders)
  Future<void> deleteOrder(
    String orderId, {
    String printMode = 'autonomous',
    String? shopId,
  }) async {
    debugPrint('🗑️ Cascade deleting order: $orderId (mode: $printMode, shop: $shopId)');
    final futures = <Future<void>>[];

    if (printMode == 'xeroxShop') {
      // 1. Delete from primary xerox_orders collection (user-facing)
      futures.add(
        _firestore.collection('xerox_orders').doc(orderId).delete()
          .catchError((e) => debugPrint('⚠️ xerox_orders delete: $e')),
      );

      // 2. Delete from shop mirror (admin-facing)
      if (shopId != null && shopId.isNotEmpty) {
        futures.add(
          _firestore.collection('shops').doc(shopId).collection('orders').doc(orderId).delete()
            .catchError((e) => debugPrint('⚠️ shop orders delete: $e')),
        );
      }
    } else {
      // Kiosk order — only in orders collection
      futures.add(
        _ordersCollection.doc(orderId).delete()
          .catchError((e) => debugPrint('⚠️ kiosk orders delete: $e')),
      );
    }

    try {
      await Future.wait(futures);
      debugPrint('✅ Order $orderId fully cascade-deleted');
    } on FirebaseException catch (e) {
      throw FirestoreException(
        'Failed to delete order: ${e.message}',
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
