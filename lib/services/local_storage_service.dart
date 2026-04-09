import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/print_order_model.dart';

class LocalStorageService {
  static const String _keyOrders = 'local_orders';
  static const String _keyLastPhone = 'last_used_phone';

  /// Save bytes to local file system for reprinting
  Future<String> saveFileLocally(String fileName, List<int> bytes) async {
    if (kIsWeb) {
      // Browsers don't allow arbitrary file system writing like this.
      // We rely on browser cache or re-selection for reprints on Web.
      return 'web_stored'; 
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final apntDir = Directory('${directory.path}/reprints');
      if (!await apntDir.exists()) {
        await apntDir.create(recursive: true);
      }
      
      final localPath = '${apntDir.path}/$fileName';
      final file = File(localPath);
      await file.writeAsBytes(bytes);
      return localPath;
    } catch (e) {
      debugPrint('❌ Failed to save file locally: $e');
      return 'error_saving';
    }
  }

  /// Save an order locally for reprint history
  Future<void> saveOrderLocally(PrintOrderModel order) async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_keyOrders);
    
    List<dynamic> ordersList = [];
    if (ordersJson != null) {
      ordersList = jsonDecode(ordersJson);
    }

    final orderMap = order.toJson();
    
    final existingIndex = ordersList.indexWhere((o) => o['orderId'] == order.orderId);
    if (existingIndex != -1) {
      ordersList[existingIndex] = orderMap;
    } else {
      ordersList.insert(0, orderMap); // Newest first
    }

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

  /// 🗑️ Delete an order from local history
  Future<void> deleteOrderLocally(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_keyOrders);
    
    if (ordersJson != null) {
      List<dynamic> ordersList = jsonDecode(ordersJson);
      ordersList.removeWhere((o) => o['orderId'] == orderId);
      await prefs.setString(_keyOrders, jsonEncode(ordersList));
    }
  }

  /// 🗑️ CLEAR ALL local orders history
  Future<void> clearAllOrdersLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOrders);
  }


  /// 📞 Save the last used phone number for prefilling
  Future<void> saveLastPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPhone, phone);
  }

  /// 📞 Get the last used phone number for prefilling
  Future<String?> getLastPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastPhone);
  }
}
