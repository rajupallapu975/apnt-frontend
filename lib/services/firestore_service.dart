import 'dart:convert';
import 'package:rxdart/rxdart.dart';

import 'package:apnt/config/backend_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/print_order_model.dart';
import '../utils/app_exceptions.dart';
import 'local_storage_service.dart';
import 'backend_service.dart';
// rxdart already imported above

class FirestoreService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  static FirebaseFirestore getFirestore(String? projectId) {
    if (projectId == null || projectId.isEmpty || projectId == 'psfc-43b5a') {
      return FirebaseFirestore.instance;
    }
    try {
      final app = Firebase.app(projectId);
      return FirebaseFirestore.instanceFor(app: app);
    } catch (e) {
      debugPrint('⚠️ Error getting Firestore instance for project $projectId: $e');
      return FirebaseFirestore.instance;
    }
  }

  FirebaseFirestore _getFirestoreForProject(String? projectId) {
    return getFirestore(projectId);
  }

  CollectionReference get _ordersCollection =>
      _firestore.collection('orders');

  String? get _currentUserId =>
      _auth.currentUser?.uid;

  CollectionReference get _usersCollection => _firestore.collection('users');

  /// ⚙️ Dynamic Auth Config (Controls showEmailLogin from backend)
  Stream<Map<String, dynamic>> streamAuthConfig() {
    return _firestore.collection('app_config').doc('auth').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      return {'showEmailLogin': false};
    });
  }

  /* =================================================
     USER PROFILE MANAGEMENT
  ================================================= */

  Future<void> updateUserPhone(String phone) async {
    if (_currentUserId == null) return;
    try {
      final user = _auth.currentUser;
      await _usersCollection.doc(_currentUserId).set({
        'phoneNumber': phone,
        if (user?.email != null) 'email': user!.email,
        if (user?.displayName != null) 'displayName': user!.displayName,
        if (user?.photoURL != null) 'photoUrl': user!.photoURL,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("❌ Profile Phone Update Error: $e");
    }
  }

  Future<void> syncUserProfile({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      await _usersCollection.doc(uid).set({
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("✅ User profile synced to Firestore: $uid");
    } catch (e) {
      debugPrint("❌ User Profile Sync Error: $e");
    }
  }

  Future<void> updateUserName(String name) async {
    if (_currentUserId == null) return;
    try {
      await _usersCollection.doc(_currentUserId).set({
        'displayName': name,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("✅ User name updated to Firestore: $name");
    } catch (e) {
      debugPrint("❌ User Name Update Error: $e");
    }
  }

  Future<Map<String, String?>> getUserProfileData([String? uid]) async {
    final targetUid = uid ?? _currentUserId;
    if (targetUid == null || targetUid.isEmpty) return {};
    try {
      final doc = await _usersCollection.doc(targetUid).get().timeout(const Duration(seconds: 5));
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'phoneNumber': data['phoneNumber'] as String?,
          'displayName': data['displayName'] as String?,
        };
      }
    } catch (e) {
      debugPrint("❌ User Profile Data Read Error: $e");
    }
    return {};
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
      final userDoc = await _usersCollection.doc(_currentUserId).get().timeout(const Duration(seconds: 4));
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
      final doc = await _usersCollection.doc(_currentUserId).get().timeout(const Duration(seconds: 4));
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
    String? projectId,
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
        await _getFirestoreForProject(projectId).collection('xerox_orders').doc(orderId).update({
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
    String? projectId,
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
        await _getFirestoreForProject(projectId).collection('xerox_orders').doc(orderId).update({
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
    String? projectId,
  }) async {
    try {
      // ✅ Update customer-facing xerox_orders collection
      await _getFirestoreForProject(projectId).collection('xerox_orders').doc(orderId).update({
        'codeRevealed': true,
        'codeRevealedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Code marked as revealed for order: $orderId");

      // ✅ Also update shops/{shopId}/orders/{orderId} (admin DB sync)
      if (shopId != null && shopId.isNotEmpty) {
        try {
          final adminApp = Firebase.app('zikrint_admin');
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
      };

      // ✅ 1. Update/Merge the customer-facing collection
      await _firestore.collection(collection).doc(orderId).set(updatePayload, SetOptions(merge: true));

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
    return _auth.userChanges().switchMap((user) {
      if (user == null) return Stream.value(<PrintOrderModel>[]);

      final String uid = user.uid;
      final String? email = user.email;

      final db2 = _getFirestoreForProject('zikrint-944a4');
      final db3 = _getFirestoreForProject('think-ink');

      final List<Stream<List<PrintOrderModel>>> streams = [
        // Kiosk (UID)
        _ordersCollection
            .where('userId', isEqualTo: uid)
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturn(<PrintOrderModel>[]),

        // Xerox (UID) - Project 1
        _firestore.collection('xerox_orders')
            .where('userId', isEqualTo: uid)
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturn(<PrintOrderModel>[]),
      ];

      if (db2 != _firestore) {
        streams.add(
          db2.collection('xerox_orders')
              .where('userId', isEqualTo: uid)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
      }

      if (db3 != _firestore) {
        streams.add(
          db3.collection('xerox_orders')
              .where('userId', isEqualTo: uid)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
      }

      if (email != null && email.isNotEmpty) {
        streams.add(
          _ordersCollection
              .where('userId', isEqualTo: email)
              .snapshots()
              .map((snapshot) => snapshot.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
        streams.add(
          _firestore.collection('xerox_orders')
              .where('userId', isEqualTo: email)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
        streams.add(
          _firestore.collection('xerox_orders')
              .where('userEmail', isEqualTo: email)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );

        if (db2 != _firestore) {
          streams.add(
            db2.collection('xerox_orders')
                .where('userId', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
          streams.add(
            db2.collection('xerox_orders')
                .where('userEmail', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
        }

        if (db3 != _firestore) {
          streams.add(
            db3.collection('xerox_orders')
                .where('userId', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
          streams.add(
            db3.collection('xerox_orders')
                .where('userEmail', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
        }
      }

      final preparedStreams = streams.map((s) => s.startWith(<PrintOrderModel>[])).toList();

      return Rx.combineLatest(preparedStreams, (List<List<PrintOrderModel>> results) {
        final all = results.expand((list) => list).toList();
        final uniqueIds = <String>{};
        final unique = all.where((o) => uniqueIds.add(o.orderId)).toList();
        unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return unique;
      });
    }).asBroadcastStream();
  }

  /* =================================================
     GET ACTIVE ORDERS
  ================================================= */

  Stream<List<PrintOrderModel>> getActiveOrders() {
    final user = _auth.currentUser;
    final String uid = user?.uid ?? 'guest_user';
    final String? email = user?.email;
    final bool isReviewer = (email != null && email.toLowerCase() == 'reviewer@zikrint.app') || 
                            (user?.displayName != null && user!.displayName!.toLowerCase().contains('reviewer')) || 
                            uid == 'reviewer_user';

    // 🏎️ 1. Fetch Streams (Single-field queries without composite index requirement)
    final List<Stream<List<PrintOrderModel>>> streams = [
      // Kiosk (UID)
      _ordersCollection
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
          .onErrorReturnWith((err, stack) {
            debugPrint("⚠️ Kiosk Stream Error: $err");
            return <PrintOrderModel>[];
          }),
      
      // Xerox (UID) - Project 1
      _firestore.collection('xerox_orders')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
          .onErrorReturnWith((err, stack) {
            debugPrint("⚠️ Xerox UID Stream Error: $err");
            return <PrintOrderModel>[];
          }),
    ];

    // 🛡️ Reviewer Test Streams - Only included for Reviewer Account
    if (isReviewer) {
      streams.addAll([
        _firestore.collection('xerox_orders')
            .where('userEmail', isEqualTo: 'reviewer@zikrint.app')
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturnWith((err, stack) => <PrintOrderModel>[]),
        _firestore.collection('xerox_orders')
            .where('userId', isEqualTo: 'reviewer_user')
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturnWith((err, stack) => <PrintOrderModel>[]),
        _firestore.collection('xerox_orders')
            .where('customerName', isEqualTo: 'Reviewer User')
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturnWith((err, stack) => <PrintOrderModel>[]),
      ]);
    } else {
      // Guest User Stream only for guest non-reviewer
      streams.add(
        _firestore.collection('xerox_orders')
            .where('userId', isEqualTo: 'guest_user')
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturnWith((err, stack) => <PrintOrderModel>[])
      );
    }

    if (email != null && email.isNotEmpty) {
      streams.add(
        _ordersCollection
            .where('userId', isEqualTo: email)
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturnWith((err, stack) => <PrintOrderModel>[])
      );
      streams.add(
        _firestore.collection('xerox_orders')
            .where('userId', isEqualTo: email)
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturnWith((err, stack) => <PrintOrderModel>[])
      );
      streams.add(
        _firestore.collection('xerox_orders')
            .where('userEmail', isEqualTo: email)
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturnWith((err, stack) => <PrintOrderModel>[])
      );
    }

    final preparedStreams = streams.map((s) => s.startWith(<PrintOrderModel>[])).toList();

    return Rx.combineLatest(preparedStreams, (List<List<PrintOrderModel>> results) {
      final all = results.expand((list) => list).toList();
      final uniqueIds = <String>{};
      final unique = all.where((o) => uniqueIds.add(o.orderId)).toList();
      
      final activeOnly = unique.where((o) {
        final uId = o.userId.toLowerCase();
        final cId = (o.customId ?? '').toLowerCase();
        final oId = o.orderId.toLowerCase();
        final uEmail = (o.userEmail ?? '').toLowerCase();
        final cName = (o.customerName ?? '').toLowerCase();

        final bool isOrderBelongsToReviewer = uId == uid.toLowerCase() ||
                                             uEmail.contains('reviewer') ||
                                             cName.contains('reviewer') ||
                                             uId.contains('reviewer') ||
                                             cId.contains('reviewer') ||
                                             oId.contains('reviewer');

        if (isReviewer) {
          if (!isOrderBelongsToReviewer) return false;
        } else {
          if (isOrderBelongsToReviewer) return false;
        }

        final st = o.status.toString().toUpperCase();
        final ordSt = (o.orderStatus ?? '').toLowerCase();
        return !st.contains('CANCELLED') && !st.contains('DELETED') && ordSt != 'files purged';
      }).toList();

      activeOnly.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (isReviewer) {
        debugPrint("📡 [Firestore Stream Emitted for Tester]: ${activeOnly.length} active order(s) retrieved from Cloud.");
      }

      return activeOnly;
    }).asBroadcastStream();
  }

  Stream<List<PrintOrderModel>> getActiveXeroxOrders() {
    return _auth.userChanges().switchMap((user) {
      if (user == null) return Stream.value(<PrintOrderModel>[]);
      
      final String uid = user.uid;
      final String? email = user.email;
      final bool isReviewer = (email != null && email.toLowerCase() == 'reviewer@zikrint.app') ||
                              (user.displayName != null && user.displayName!.toLowerCase().contains('reviewer')) ||
                              uid == 'reviewer_user';

      final List<Stream<List<PrintOrderModel>>> streams = [
        _firestore.collection('xerox_orders')
            .where('userId', isEqualTo: uid)
            .snapshots()
            .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
            .onErrorReturn(<PrintOrderModel>[]),
      ];

      if (isReviewer) {
        streams.addAll([
          _firestore.collection('xerox_orders')
              .where('userEmail', isEqualTo: 'reviewer@zikrint.app')
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[]),
          _firestore.collection('xerox_orders')
              .where('customerName', isEqualTo: 'Reviewer User')
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[]),
        ]);
      }

      final db2 = _getFirestoreForProject('zikrint-944a4');
      if (db2 != _firestore) {
        streams.add(
          db2.collection('xerox_orders')
              .where('userId', isEqualTo: uid)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
      }

      final db3 = _getFirestoreForProject('think-ink');
      if (db3 != _firestore) {
        streams.add(
          db3.collection('xerox_orders')
              .where('userId', isEqualTo: uid)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
      }

      if (email != null && email.isNotEmpty) {
        streams.add(
          _firestore.collection('xerox_orders')
              .where('userId', isEqualTo: email)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
        streams.add(
          _firestore.collection('xerox_orders')
              .where('userEmail', isEqualTo: email)
              .snapshots()
              .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
              .onErrorReturn(<PrintOrderModel>[])
        );
        if (db2 != _firestore) {
          streams.add(
            db2.collection('xerox_orders')
                .where('userId', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
          streams.add(
            db2.collection('xerox_orders')
                .where('userEmail', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
        }
        if (db3 != _firestore) {
          streams.add(
            db3.collection('xerox_orders')
                .where('userId', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
          streams.add(
            db3.collection('xerox_orders')
                .where('userEmail', isEqualTo: email)
                .snapshots()
                .map((s) => s.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList())
                .onErrorReturn(<PrintOrderModel>[])
          );
        }
      }

      final preparedStreams = streams.map((s) => s.startWith(<PrintOrderModel>[])).toList();

      return Rx.combineLatest(preparedStreams, (List<List<PrintOrderModel>> results) {
        final all = results.expand((list) => list).toList();
        final uniqueIds = <String>{};
        final unique = all.where((o) => uniqueIds.add(o.orderId)).toList();
        
        final activeOnly = unique.where((o) {
          final st = o.status.toString().toUpperCase();
          final ordSt = (o.orderStatus ?? '').toLowerCase();
          return !st.contains('CANCELLED') && !st.contains('DELETED') && ordSt != 'files purged';
        }).toList();

        activeOnly.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return activeOnly;
      });
    }).asBroadcastStream();
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
      final userDoc = await _usersCollection.doc(_currentUserId).get().timeout(const Duration(seconds: 4));
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
      final user = _auth.currentUser;
      final querySnapshot = await _ordersCollection
          .where('userId', isEqualTo: user?.uid)
          .get();

      double totalAmount = 0.0;
      int totalOrders = 0;
      int totalPages = 0;
      int totalFiles = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toUpperCase() ?? '';
        
        if (status == 'COMPLETED' || status == 'ACTIVE') {
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
      String orderId, {
      String printMode = 'autonomous',
      String? projectId,
  }) async {
    try {
      final collection = printMode == 'xeroxShop' ? 'xerox_orders' : 'orders';
      final firestore = _getFirestoreForProject(projectId);
      final doc =
          await firestore.collection(collection).doc(orderId).get();

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
      // 🕵️ Get order details FIRST before deleting record to have publicIds
      final orderDoc = await getOrder(orderId, printMode: printMode);
      if (orderDoc != null && orderDoc.publicIds.isNotEmpty) {
        // 🚀 FORCE Cloudinary cleanup BEFORE Firebase deletion
        try {
          await BackendService().deleteOrderFiles(
            orderId: orderId, 
            publicIds: orderDoc.publicIds
          ).timeout(const Duration(seconds: 15));
          debugPrint("🗑️ Cloudinary Purge Request Success for $orderId");
        } catch (e) {
          debugPrint("⚠️ Cloudinary Purge Request failed/timeout: $e");
          // Proceed anyway to avoid stuck records after attempt
        }
      }

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

  /* =================================================
     DELETE USER ACCOUNT DATA PERMANENTLY
  ================================================= */

  /// 🗑️ PERMANENTLY DELETE USER DATA across all collections and storage
  Future<void> deleteUserAccountData(String uid, {String? email}) async {
    debugPrint('🗑️ Permanently deleting user data for UID: $uid');
    
    // 1. Delete user profile document from users collection
    try {
      await _usersCollection.doc(uid).delete();
      debugPrint('✅ Deleted user profile doc for $uid');
    } catch (e) {
      debugPrint('⚠️ Error deleting user profile doc: $e');
    }

    // 2. Delete all kiosk orders for this user
    try {
      final userOrdersSnapshot = await _ordersCollection
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in userOrdersSnapshot.docs) {
        await deleteOrder(doc.id, printMode: 'autonomous');
      }
      if (email != null && email.isNotEmpty) {
        final emailOrdersSnapshot = await _ordersCollection
            .where('userId', isEqualTo: email)
            .get();
        for (var doc in emailOrdersSnapshot.docs) {
          await deleteOrder(doc.id, printMode: 'autonomous');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting user kiosk orders: $e');
    }

    // 3. Delete all xerox orders for this user across projects
    final projects = [null, 'zikrint-944a4', 'think-ink'];
    for (var proj in projects) {
      try {
        final db = _getFirestoreForProject(proj);
        final xeroxSnapshot = await db.collection('xerox_orders')
            .where('userId', isEqualTo: uid)
            .get();
        for (var doc in xeroxSnapshot.docs) {
          final shopId = (doc.data())['shopId']?.toString();
          await deleteOrder(doc.id, printMode: 'xeroxShop', shopId: shopId);
        }
        if (email != null && email.isNotEmpty) {
          final emailXeroxSnapshot = await db.collection('xerox_orders')
              .where('userId', isEqualTo: email)
              .get();
          for (var doc in emailXeroxSnapshot.docs) {
            final shopId = (doc.data())['shopId']?.toString();
            await deleteOrder(doc.id, printMode: 'xeroxShop', shopId: shopId);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error deleting xerox orders for project $proj: $e');
      }
    }
  }
}
