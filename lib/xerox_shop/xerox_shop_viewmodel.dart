import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'xerox_shop_model.dart';
import '../services/backend_service.dart';
import '../config/backend_config.dart';

class XeroxShopViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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
  /// Added: Direct Firestore fallback for Web to bypass HTTP/Mixed-Content issues.
  Future<void> fetchShops() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 🏓 Attempt ping first (fire-and-forget wake-up)
    _pingBackend();

    bool fetchSuccess = false;
    const maxRetries = 2;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint("🔄 Retrying shop fetch (attempt ${attempt + 1})...");
          await Future.delayed(const Duration(seconds: 3));
        }

        final List<Map<String, dynamic>> data = await BackendService()
            .getXeroxShops()
            .timeout(const Duration(seconds: 15));

        if (data.isNotEmpty) {
          _shops = data.map((json) => XeroxShopModel.fromMap(json, json['id'] ?? '')).toList();
          fetchSuccess = true;
          debugPrint("✅ Fetched ${_shops.length} shops from Backend");
          break; 
        }
      } catch (e) {
        debugPrint("⚠️ Shop fetch attempt ${attempt + 1} failed: $e");
      }
    }

    // 🛡️ WEB FALLBACK: If backend fails (Mixed Content on Web is common), fetch directly from Firestore
    if (!fetchSuccess) {
      debugPrint("🛡️ Backend fetch failed. Attempting Direct Firestore Fallback...");
      try {
        _errorMessage = "Backend unreachable. Checking Firestore...";
        notifyListeners();
        await _fetchShopsFromFirestore();
        _errorMessage = null; 
        fetchSuccess = true;
      } catch (e) {
        _errorMessage = "Shop loading failed: $e";
        debugPrint("❌ Firestore Fallback also failed: $e");
      }
    }

    _hasLoaded = fetchSuccess;
    _isLoading = false;
    notifyListeners();
  }

  /// 🛡️ Direct Fetch from Primary Firestore (Bypasses Backend HTTP issues on Web)
  /// Using primary instance is more reliable on mobile web (no cross-origin auth issues)
  Future<void> _fetchShopsFromFirestore() async {
    try {
      // 🛡️ AUTH FALLBACK: On Mobile Web, ensuring an active session is critical for rule-based reads
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint("👣 No user found. Attempting Anonymous Login for shop fetch...");
        try {
          await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 5));
          debugPrint("✅ Anonymous Login Success");
        } catch (e) {
          debugPrint("⚠️ Anonymous Login Failed: $e");
        }
      }

      // 🚀 HYBRID FETCH: Try Primary first, then Secondary (Admin Project) if Primary is empty/fails
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      debugPrint("📡 Fetching from Primary Firestore: collection('shops')...");
      var snapshot = await firestore.collection('shops').get().timeout(const Duration(seconds: 15));
      
      // If Primary is empty or fails, try the Secondary Admin project
      if (snapshot.docs.isEmpty) {
        debugPrint("⚠️ Primary shops collection is empty. Checking Secondary Admin Project...");
        try {
          final adminApp = Firebase.app('thinkink_admin');
          final adminFirestore = FirebaseFirestore.instanceFor(app: adminApp);
          snapshot = await adminFirestore.collection('shops').get().timeout(const Duration(seconds: 10));
          debugPrint("✅ Secondary Fetch Success: ${snapshot.docs.length} shops found in Admin project");
        } catch (e) {
          debugPrint("❌ Secondary Fetch also failed: $e");
          // Re-throw if both failed AND we have no data
          if (snapshot.docs.isEmpty) throw Exception("No shops found in either Primary or Secondary projects.");
        }
      }

      _shops = snapshot.docs.map((doc) {
        return XeroxShopModel.fromMap(doc.data(), doc.id);
      }).toList();

      debugPrint("✅ Final Shop Fetch Count: ${_shops.length} shops total");
    } catch (e) {
      debugPrint("❌ _fetchShopsFromFirestore Error: $e");
      rethrow;
    }
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
