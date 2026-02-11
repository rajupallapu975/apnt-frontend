import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import '../models/order_model.dart';
import '../utils/app_exceptions.dart';

class OrderService {
  /// Calls the local backend to create an initial order record
  Future<OrderModel> createOrderFromBackend(Map<String, dynamic> printSettings) async {
    try {
      print('🌐 Creating order on backend...');
      final url = Uri.parse(BackendConfig.createOrderUrl);
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "printSettings": printSettings,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Order created on backend: ${data['orderId']}');
        return OrderModel.fromJson(data);
      } else {
        throw NetworkException("Failed to create order on server (Status: ${response.statusCode})");
      }
    } on http.ClientException catch (e) {
      throw NetworkException("Could not connect to the printing server. Make sure it's running and your IP is correct.", e);
    } catch (e) {
      if (e is AppException) rethrow;
      print('❌ Order Creation Error: $e');
      throw AppException(e.toString(), "Order Error");
    }
  }

  /// Sends Cloudinary URLs to the local backend so it can download them
  Future<void> finalizeOrderOnBackend({
    required String orderId,
    required List<String> fileUrls,
  }) async {
    try {
      print('🌐 Sending Cloudinary URLs to backend...');
      final url = Uri.parse("${BackendConfig.baseUrl}/finalize-order");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "orderId": orderId,
          "fileUrls": fileUrls,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw NetworkException("Backend failed to receive Cloudinary URLs (Status: ${response.statusCode})");
      }
      print('✅ Backend updated with Cloudinary URLs');
    } catch (e) {
      print('⚠️ Backend finalize error: $e');
      // We don't throw here to avoid stopping the flow if only the notification fails
    }
  }
}
