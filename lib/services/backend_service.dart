import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/backend_config.dart';

class CreateOrderResponse {
  final String orderId;
  final String pickupCode;

  CreateOrderResponse({
    required this.orderId,
    required this.pickupCode,
  });

  factory CreateOrderResponse.fromJson(
      Map<String, dynamic> json) {
    return CreateOrderResponse(
      orderId: json['orderId'],
      pickupCode: json['pickupCode'],
    );
  }
}

class BackendService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<CreateOrderResponse> createOrder(
      Map<String, dynamic> printSettings) async {

    final user = _auth.currentUser;
    final String userId = user?.email ?? "guest_user";

    final response = await http.post(
      Uri.parse(BackendConfig.createOrderUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "printSettings": printSettings,
        "userId": userId,   // ✅ SEND EMAIL OR GUEST
      }),
    );

    if (response.statusCode == 200) {
      return CreateOrderResponse.fromJson(
          jsonDecode(response.body));
    } else {
      throw Exception(
        "Backend order creation failed: ${response.body}",
      );
    }
  }

  /* =================================================
     RAZORPAY: CREATE ORDER
  ================================================= */
  Future<Map<String, dynamic>> createRazorpayOrder(double amount) async {
    try {
      debugPrint("📡 POST ${BackendConfig.createRazorpayOrderUrl} | amount: $amount");
      final response = await http.post(
        Uri.parse(BackendConfig.createRazorpayOrderUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"amount": amount}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Server returned ${response.statusCode}: ${response.body}");
      }
    } on SocketException {
      throw Exception("Network Unreachable: Ensure you have an active internet connection to reach our cloud server.");
    } on TimeoutException {
      throw Exception("The server is taking a moment to wake up (Render Cold Start). Please tap Retry to give it a few more seconds.");
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }

  /* =================================================
     RAZORPAY: VERIFY PAYMENT
  ================================================= */
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required Map<String, dynamic> printSettings,
    required double amount,
    required int totalPages,
    String printMode = 'autonomous', // New: added printMode
    String? customId, // Sequential ID (order_1)
  }) async {
    final user = _auth.currentUser;
    final String userId = user?.email ?? "guest_user";

    try {
      final response = await http.post(
        Uri.parse(BackendConfig.verifyPaymentUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "razorpay_order_id": razorpayOrderId,
          "razorpay_payment_id": razorpayPaymentId,
          "razorpay_signature": razorpaySignature,
          "printSettings": printSettings,
          "userId": userId,
          "amount": amount,
          "totalPages": totalPages,
          "printMode": printMode, // Pass mode to backend
          "customId": customId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Server verification failed (${response.statusCode}): ${response.body}");
      }
    } on SocketException {
      throw Exception("Verification Network Error: Check your connection to ${BackendConfig.verifyPaymentUrl}");
    } on TimeoutException {
      throw Exception("Verification Timed Out: The server took too long. Check if Render is active.");
    } catch (e) {
      throw Exception("Verification Logic Error: $e");
    }
  }

  /* =================================================
     XEROX SHOPS: FETCH LIVE DATA 
  ================================================= */
  Future<List<Map<String, dynamic>>> getXeroxShops() async {
    try {
      final url = BackendConfig.getXeroxShopsUrl;
      debugPrint("📡 Fetching shops from: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 30));

      debugPrint("📡 Backend Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['shops'] != null) {
          return List<Map<String, dynamic>>.from(data['shops']);
        }
        return [];
      } else {
        debugPrint("❌ Backend HTTP Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ BackendService: getXeroxShops Error: $e");
      return [];
    }
  }

  /* =================================================
     RAZORPAY: REFUND PAYMENT (In case of upload failure)
  ================================================= */
  Future<void> refundPayment({
    required String razorpayPaymentId,
    required double amount,
  }) async {
    try {
      debugPrint("💸 Requesting Refund for $razorpayPaymentId | Amount: $amount");
      final response = await http.post(
        Uri.parse(BackendConfig.refundPaymentUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "razorpay_payment_id": razorpayPaymentId,
          "amount": amount,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint("✅ Refund Processed Successfully");
      } else {
        debugPrint("⚠️ Refund Failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Refund Error: $e");
    }
  }

  /* =================================================
     ATTACH FILES TO ORDER (Backend-side to bypass Firestore rules)
  ================================================= */
  Future<void> completeOrder({
    required String orderId,
    required List<String> fileUrls,
    required List<String> publicIds,
    required List<String> localFilePaths,
    String printMode = 'autonomous',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(BackendConfig.completeOrderUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "orderId": orderId,
          "fileUrls": fileUrls,
          "publicIds": publicIds,
          "localFilePaths": localFilePaths,
          "printMode": printMode,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception("Server failed to attach files (${response.statusCode}): ${response.body}");
      }
    } on SocketException {
      throw Exception("Complete Order Network Error: Check your connection.");
    } on TimeoutException {
      throw Exception("Complete Order Timed Out: The server is not responding.");
    } catch (e) {
      throw Exception("Complete Order Logic Error: $e");
    }
  }

  /// Cloudinary: Delete files for order after pickup
  Future<void> deleteOrderFiles({
    required String orderId,
    required List<dynamic> publicIds,
  }) async {
    try {
      debugPrint("🗑️ Requesting Cloudinary Deletion for Order: $orderId");
      await http.post(
        Uri.parse(BackendConfig.deleteOrderFilesUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "orderId": orderId,
          "publicIds": publicIds,
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint("❌ Cloudinary Deletion Status/Error Trace: $e");
    }
  }
}
