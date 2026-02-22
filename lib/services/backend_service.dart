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

    if (user == null) {
      throw Exception("User not logged in");
    }

    final response = await http.post(
      Uri.parse(BackendConfig.createOrderUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "printSettings": printSettings,
        "userId": user.uid,   // ✅ SEND USER ID
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Server returned ${response.statusCode}: ${response.body}");
      }
    } on SocketException {
      throw Exception("Network Unreachable: Ensure your phone and laptop (10.14.211.155) are on the same WiFi and port 5000 is open.");
    } on TimeoutException {
      throw Exception("Connection Timed Out: The server at 10.14.211.155:5000 took too long to respond. Check your laptop's firewall.");
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
    if (user == null) throw Exception("User not logged in");

    final response = await http.post(
      Uri.parse(BackendConfig.verifyPaymentUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "razorpay_order_id": razorpayOrderId,
        "razorpay_payment_id": razorpayPaymentId,
        "razorpay_signature": razorpaySignature,
        "printSettings": printSettings,
        "userId": user.uid,
        "amount": amount,
        "totalPages": totalPages,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Payment verification failed: ${response.body}");
    }
  }
}
