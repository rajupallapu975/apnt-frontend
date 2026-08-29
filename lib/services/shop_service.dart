import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../xerox_shop/xerox_shop_model.dart';
import '../viewmodels/auth/tester_viewmodel.dart';

class ShopService {
  /// Stream to fetch all active shops offering the specified service.
  /// Merges results from primary and secondary Firestore instances.
  Stream<List<XeroxShopModel>> streamShopsForService(String serviceId) {
    final primaryStream = FirebaseFirestore.instance.collection('shops').snapshots();
    
    Stream<QuerySnapshot>? secondaryStream;
    try {
      final secondaryApp = Firebase.app('zikrint_admin');
      secondaryStream = FirebaseFirestore.instanceFor(app: secondaryApp).collection('shops').snapshots();
    } catch (_) {
      // If zikrint_admin app is not initialized
    }

    if (secondaryStream == null) {
      return primaryStream.map((snap) => parseAndFilter(primaryDocs: snap.docs, secondaryDocs: [], serviceId: serviceId));
    }

    // Combine streams
    return primaryStream.asyncMap((primarySnap) async {
      final secondarySnap = await FirebaseFirestore.instanceFor(app: Firebase.app('zikrint_admin')).collection('shops').get();
      return parseAndFilter(primaryDocs: primarySnap.docs, secondaryDocs: secondarySnap.docs, serviceId: serviceId);
    });
  }

  /// Parses raw Firestore documents and filters by service availability and active status
  List<XeroxShopModel> parseAndFilter({
    required List<DocumentSnapshot> primaryDocs,
    required List<DocumentSnapshot> secondaryDocs,
    required String serviceId,
    String searchQuery = '',
    String filterType = 'Nearest', // 'Nearest', 'Rating', 'Lowest Price'
  }) {
    final bool isReviewer = TesterViewModel.isCurrentReviewerSession;

    final combined = <String, DocumentSnapshot>{};
    for (final doc in primaryDocs) {
      if (doc.exists) combined[doc.id] = doc;
    }
    for (final doc in secondaryDocs) {
      if (doc.exists) combined[doc.id] = doc;
    }

    final shops = <XeroxShopModel>[];

    combined.forEach((id, doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final String shopEmail = (data['email'] ?? '').toString().toLowerCase();
      final bool isTestShopDoc = id == 'reviewer_shop_store' || 
                              data['isTestShop'] == true || 
                              shopEmail == 'reviewer@zikrint.app';

      // 🛡️ Strict Test Shop Isolation:
      // Real users -> Exclude test shops
      // Test reviewer -> Include test shops only
      if (!isReviewer && isTestShopDoc) return;
      if (isReviewer && !isTestShopDoc) return;

      final isActive = data['isActive'] ?? true;
      if (!isActive) return;

      final services = data['zikrinterServices'] as Map<String, dynamic>? ?? {};
      final config = services[serviceId] as Map<String, dynamic>?;

      if (config != null && config['isEnabled'] == true) {
        final shop = XeroxShopModel.fromMap(data, id);
        
        // Search filter matching shop name
        if (searchQuery.isNotEmpty && !shop.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return;
        }

        shops.add(shop);
      }
    });

    // Apply sorting
    if (filterType == 'Rating') {
      shops.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (filterType == 'Lowest Price') {
      // Compare starting price or standard prices
      shops.sort((a, b) => a.pricePerBWPage.compareTo(b.pricePerBWPage));
    } else {
      // Default: Nearest/Distance (simulate or compare distance strings if numeric conversion is available)
      shops.sort((a, b) {
        final distA = _parseDistance(a.distance);
        final distB = _parseDistance(b.distance);
        return distA.compareTo(distB);
      });
    }

    return shops;
  }

  double _parseDistance(String distanceStr) {
    final clean = distanceStr.toLowerCase().trim();
    if (clean == 'nearby') return 0.1;
    final value = double.tryParse(clean.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 999.0;
    if (clean.contains('km')) {
      return value;
    } else if (clean.contains('m')) {
      return value / 1000.0;
    }
    return value;
  }
}
