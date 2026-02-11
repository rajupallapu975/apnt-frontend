import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/print_order_model.dart';

class LocalStorageService {
  static const String _keyOrders = 'local_orders';

  /// Save an order locally for reprint history
  Future<void> saveOrderLocally(PrintOrderModel order) async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_keyOrders);
    
    List<dynamic> ordersList = [];
    if (ordersJson != null) {
      ordersList = jsonDecode(ordersJson);
    }

    // Convert order to map and check if it already exists by orderId
    final orderMap = order.toJson();
    
    final existingIndex = ordersList.indexWhere((o) => o['orderId'] == order.orderId);
    if (existingIndex != -1) {
      ordersList[existingIndex] = orderMap;
    } else {
      ordersList.insert(0, orderMap); // Newest first
    }

    // Keep only last 50 orders to save space
    if (ordersList.length > 50) {
      ordersList = ordersList.sublist(0, 50);
    }

    await prefs.setString(_keyOrders, jsonEncode(ordersList));
  }

  /// Get all locally saved orders (history)
  Future<List<PrintOrderModel>> getLocalOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_keyOrders);
    
    if (ordersJson == null) return [];

    final List<dynamic> ordersList = jsonDecode(ordersJson);
    return ordersList.map((o) {
      // Create a mock document snapshot equivalent or just use a helper
      return PrintOrderModel.fromLocalMap(o);
    }).toList();
  }
}
