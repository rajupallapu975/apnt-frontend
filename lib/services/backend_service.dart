import 'dart:convert';
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
}
