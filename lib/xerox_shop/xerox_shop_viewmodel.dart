import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'xerox_shop_model.dart';
import '../services/backend_service.dart';
import '../config/backend_config.dart';

class XeroxShopViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  List<XeroxShopModel> _shops = [];
  List<XeroxShopModel> get shops => _filteredShops.isEmpty && _searchQuery.isEmpty ? _shops : _filteredShops;

  List<XeroxShopModel> _filteredShops = [];
  String _searchQuery = '';

  XeroxShopModel? _selectedShop;
  XeroxShopModel? get selectedShop => _selectedShop;

  /// Ping the backend to wake it up before the actual fetch.
  Future<bool> _pingBackend() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches shops from backend with retry logic for cold starts.
  Future<void> fetchShops() async {
    _isLoading = true;
    notifyListeners();

    // 🏓 Attempt ping first (fire-and-forget wake-up)
    _pingBackend();

    const maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint("🔄 Retrying shop fetch (attempt ${attempt + 1})...");
          await Future.delayed(const Duration(seconds: 3));
        }

        final List<Map<String, dynamic>> data = await BackendService()
            .getXeroxShops()
            .timeout(const Duration(seconds: 20));

        _shops = data.map((json) {
          return XeroxShopModel.fromMap(json, json['id'] ?? '');
        }).toList();

        _hasLoaded = true;
        debugPrint("✅ Fetched ${_shops.length} shops (attempt ${attempt + 1})");
        break; // ✅ success — stop retrying
      } catch (e) {
        debugPrint("⚠️ Shop fetch attempt ${attempt + 1} failed: $e");
        if (attempt == maxRetries) {
          debugPrint("❌ All retries exhausted. Shops could not be loaded.");
          _shops = [];
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void searchShops(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredShops = [];
    } else {
      _filteredShops = _shops
          .where((shop) =>
              shop.name.toLowerCase().contains(query.toLowerCase()) ||
              shop.address.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  void selectShop(XeroxShopModel shop) {
    _selectedShop = shop;
    notifyListeners();
  }
}
