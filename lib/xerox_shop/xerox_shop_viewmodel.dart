import 'package:flutter/material.dart';
import 'xerox_shop_model.dart';
import '../services/backend_service.dart';

class XeroxShopViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<XeroxShopModel> _shops = [];
  List<XeroxShopModel> get shops => _filteredShops.isEmpty && _searchQuery.isEmpty ? _shops : _filteredShops;

  List<XeroxShopModel> _filteredShops = [];
  String _searchQuery = '';

  XeroxShopModel? _selectedShop;
  XeroxShopModel? get selectedShop => _selectedShop;

  void fetchShops() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data = await BackendService().getXeroxShops();
      
      _shops = data.map((json) {
        return XeroxShopModel.fromMap(json, json['id'] ?? '');
      }).toList();
      
      debugPrint("✅ Fetched ${_shops.length} real-time shops");
    } catch (e) {
      debugPrint("❌ Failed to fetch shops: $e");
      _shops = [];
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
