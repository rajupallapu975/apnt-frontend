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
        .map((snapshot) =>
            snapshot.docs
                .map((doc) =>
                    PrintOrderModel.fromFirestore(doc))
                .toList());
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
