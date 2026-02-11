import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/print_order_model.dart';
import '../utils/app_exceptions.dart';
import 'local_storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _ordersCollection => _firestore.collection('orders');

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Generate a random 6-digit pickup code locally
  String _generateLocalPickupCode() {
    final random = Random();
    int code = 100000 + random.nextInt(900000);
    return code.toString();
  }

  /// Save order directly to Firestore (Cloud-Only Flow)
  Future<String> saveOrderDirectly({
    required Map<String, dynamic> printSettings,
    required int totalPages,
    required double totalPrice,
    required List<String> fileUrls,
  }) async {
    try {
      if (_currentUserId == null) {
        throw ValidationException('You must be logged in to save an order.');
      }

      final String orderId = "ORD_${DateTime.now().millisecondsSinceEpoch}";
      final String pickupCode = _generateLocalPickupCode();

      final order = PrintOrderModel(
        orderId: orderId,
        pickupCode: pickupCode,
        userId: _currentUserId!,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        status: OrderStatus.active,
        printSettings: printSettings,
        totalPages: totalPages,
        totalPrice: totalPrice,
        fileUrls: fileUrls,
      );

      await _ordersCollection.doc(orderId).set(order.toFirestore());
      return pickupCode; 
    } on FirebaseException catch (e) {
      throw FirestoreException("Cloud storage failed: ${e.message}", e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw FirestoreException("Unexpected error saving to cloud.", e);
    }
  }

  /// Get all orders for current user from Firestore
  Stream<List<PrintOrderModel>> getUserOrders() {
    if (_currentUserId == null) return Stream.value([]);
    return _ordersCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PrintOrderModel.fromFirestore(doc)).toList());
  }

  /// Archive order locally and delete from Firestore
  Future<void> _archiveAndDeleteOrder(PrintOrderModel order) async {
    try {
      await LocalStorageService().saveOrderLocally(order);
      await deleteOrder(order.orderId);
      print('✅ Order ${order.orderId} archived locally and removed from Firestore');
    } catch (e) {
      print('❌ Error archiving order: $e');
    }
  }

  /// Get active orders (not expired and status is active)
  Stream<List<PrintOrderModel>> getActiveOrders() {
    if (_currentUserId == null) return Stream.value([]);

    return _ordersCollection
        .where('userId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: OrderStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final now = DateTime.now();
      final List<PrintOrderModel> active = [];
      
      for (var doc in snapshot.docs) {
        try {
          final order = PrintOrderModel.fromFirestore(doc);
          
          if (order.status == OrderStatus.completed) {
            await _archiveAndDeleteOrder(order);
            continue;
          }

          if (order.expiresAt.isAfter(now)) {
            active.add(order);
          } else {
            await _archiveAndDeleteOrder(order);
          }
        } catch (e) {
          print('⚠️ Error processing document ${doc.id}: $e');
        }
      }
      return active;
    });
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'status': status.name,
      });
    } on FirebaseException catch (e) {
      throw FirestoreException("Failed to update order status: ${e.message}", e);
    }
  }

  /// Get a single order by ID
  Future<PrintOrderModel?> getOrder(String orderId) async {
    try {
      final doc = await _ordersCollection.doc(orderId).get();
      if (!doc.exists) return null;
      return PrintOrderModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException("Failed to fetch order: ${e.message}", e);
    }
  }

  /// Delete an order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _ordersCollection.doc(orderId).delete();
    } on FirebaseException catch (e) {
      throw FirestoreException("Failed to delete order: ${e.message}", e);
    }
  }

  /// Reprint an expired order (Cloud-Only)
  Future<String> reprintOrder(PrintOrderModel oldOrder) async {
    try {
      if (_currentUserId == null) {
        throw ValidationException('User not authenticated');
      }

      final String newOrderId = "ORD_REPRINT_${DateTime.now().millisecondsSinceEpoch}";
      final String newPickupCode = _generateLocalPickupCode();

      final newOrder = PrintOrderModel(
        orderId: newOrderId,
        pickupCode: newPickupCode,
        userId: _currentUserId!,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        status: OrderStatus.active,
        printSettings: oldOrder.printSettings,
        totalPages: oldOrder.totalPages,
        totalPrice: oldOrder.totalPrice,
        fileUrls: oldOrder.fileUrls,
      );

      await _ordersCollection.doc(newOrderId).set(newOrder.toFirestore());
      return newPickupCode; 
    } on FirebaseException catch (e) {
      throw FirestoreException("Failed to create reprint: ${e.message}", e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw FirestoreException("An unexpected error occurred during reprint.", e);
    }
  }

  /// Get archived orders from local storage
  Future<List<PrintOrderModel>> getArchivedOrders() async {
    try {
      return await LocalStorageService().getLocalOrders();
    } catch (e) {
      return [];
    }
  }
}
