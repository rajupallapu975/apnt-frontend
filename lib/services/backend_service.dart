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
    final String uid = user?.uid ?? "guest_user";

    final response = await http.post(
      Uri.parse(BackendConfig.createOrderUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "printSettings": printSettings,
        "userId": uid,   // ✅ SEND USER ID OR GUEST
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
  }) async {
    final user = _auth.currentUser;
    final String uid = user?.uid ?? "guest_user";

    try {
      final response = await http.post(
        Uri.parse(BackendConfig.verifyPaymentUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "razorpay_order_id": razorpayOrderId,
          "razorpay_payment_id": razorpayPaymentId,
          "razorpay_signature": razorpaySignature,
          "printSettings": printSettings,
          "userId": uid,
          "amount": amount,
          "totalPages": totalPages,
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
}
