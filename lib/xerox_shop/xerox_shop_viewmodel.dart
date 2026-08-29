import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'xerox_shop_model.dart';
import '../services/backend_service.dart';
import '../config/backend_config.dart';
import '../viewmodels/auth/tester_viewmodel.dart';

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
          _shops = data
              .map((json) => XeroxShopModel.fromMap(json, json['id'] ?? ''))
              .toList();
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

      // 🚀 HYBRID FETCH: Always fetch from BOTH Primary and Secondary (Admin Project) and merge
      final Map<String, DocumentSnapshot> combinedDocs = {};

      // 1. Fetch from Primary Firestore
      try {
        debugPrint("📡 Fetching from Primary Firestore: collection('shops')...");
        final primarySnap = await FirebaseFirestore.instance.collection('shops').get().timeout(const Duration(seconds: 8));
        for (final doc in primarySnap.docs) {
          if (doc.id != 'serviceVersion') {
            combinedDocs[doc.id] = doc;
          }
        }
      } catch (e) {
        debugPrint("⚠️ Primary shops fetch error: $e");
      }

      // 2. Fetch from Secondary Admin Project (where real shops live)
      try {
        final adminApp = Firebase.app('zikrint_admin');
        final adminFirestore = FirebaseFirestore.instanceFor(app: adminApp);
        debugPrint("📡 Fetching from Secondary Admin Firestore: collection('shops')...");
        final adminSnap = await adminFirestore.collection('shops').get().timeout(const Duration(seconds: 8));
        for (final doc in adminSnap.docs) {
          if (doc.id != 'serviceVersion') {
            combinedDocs[doc.id] = doc;
          }
        }
      } catch (e) {
        debugPrint("⚠️ Admin shops fetch error: $e");
      }

      final bool isReviewer = TesterViewModel.isCurrentReviewerSession;

      _shops = combinedDocs.values
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final String shopEmail = (data['email'] ?? '').toString().toLowerCase();
            final bool isTestShopDoc = doc.id == 'reviewer_shop_store' || 
                                    data['isTestShop'] == true || 
                                    shopEmail == 'reviewer@zikrint.app';

            if (!isReviewer && isTestShopDoc) return false;
            if (isReviewer && !isTestShopDoc) return false;
            return true;
          })
          .map((doc) => XeroxShopModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

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
