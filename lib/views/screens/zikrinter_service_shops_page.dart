// lib/views/screens/zikrinter_service_shops_page.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/app_colors.dart';
import '../../xerox_shop/xerox_shop_model.dart';
import '../../models/file_model.dart';
import '../../models/print_order_model.dart';
import '../../services/pricing_service.dart';
import 'print_options/print_options_page.dart';

class ZikrinterServiceShopsPage extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final Map<String, dynamic> globalParams;
  final String selectedPaperSize;

  const ZikrinterServiceShopsPage({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.globalParams,
    required this.selectedPaperSize,
  });

  @override
  State<ZikrinterServiceShopsPage> createState() => _ZikrinterServiceShopsPageState();
}

class _ZikrinterServiceShopsPageState extends State<ZikrinterServiceShopsPage> {
  StreamSubscription<QuerySnapshot>? _primarySub;
  StreamSubscription<QuerySnapshot>? _secondarySub;

  final Map<String, DocumentSnapshot> _primaryDocs = {};
  final Map<String, DocumentSnapshot> _secondaryDocs = {};
  bool _isLoading = true;

  // Selected shop ID for expanded details card
  String? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _authenticateAndListen();
  }

  Future<void> _authenticateAndListen() async {
    try {
      final secondaryApp = Firebase.app('zikrint_admin');
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      if (secondaryAuth.currentUser == null) {
        await secondaryAuth.signInAnonymously();
      }
    } catch (_) {}
    _listenToShops();
  }

  void _listenToShops() {
    _primarySub = FirebaseFirestore.instance.collection('shops').snapshots().listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _primaryDocs.clear();
            for (final doc in snapshot.docs) {
              _primaryDocs[doc.id] = doc;
            }
            _isLoading = false;
          });
        }
      },
      onError: (err) {
        if (mounted) setState(() => _isLoading = false);
      },
    );

    try {
      final secondaryApp = Firebase.app('zikrint_admin');
      _secondarySub = FirebaseFirestore.instanceFor(app: secondaryApp).collection('shops').snapshots().listen(
        (snapshot) {
          if (mounted) {
            setState(() {
              _secondaryDocs.clear();
              for (final doc in snapshot.docs) {
                _secondaryDocs[doc.id] = doc;
              }
              _isLoading = false;
            });
          }
        },
        onError: (err) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _primarySub?.cancel();
    _secondarySub?.cancel();
    super.dispose();
  }

  Future<void> _showUploadBottomSheet(BuildContext context, XeroxShopModel shop) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Files',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryBlack),
              ),
              const SizedBox(height: 8),
              Text(
                'Select file source for ${widget.selectedPaperSize} printout',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _uploadOptionItem(
                    ctx,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: Colors.blueAccent,
                    onTap: () => _pickFromCamera(ctx, shop),
                  ),
                  _uploadOptionItem(
                    ctx,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: Colors.orangeAccent,
                    onTap: () => _pickFromGallery(ctx, shop),
                  ),
                  _uploadOptionItem(
                    ctx,
                    icon: Icons.folder_open_rounded,
                    label: 'Files',
                    color: Colors.green,
                    onTap: () => _pickFromFiles(ctx, shop),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _uploadOptionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromFiles(BuildContext context, XeroxShopModel shop) async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      _navigateToOptions(result.files.map((f) => FileModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${f.name}',
        name: f.name,
        path: f.path ?? '',
        bytes: f.bytes,
        addedAt: DateTime.now(),
        size: f.size,
      )).toList(), shop);
    } catch (e) {
      debugPrint("Error picking files: $e");
    }
  }

  Future<void> _pickFromGallery(BuildContext context, XeroxShopModel shop) async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;
      
      final List<FileModel> picked = [];
      for (final img in images) {
        final bytes = await img.readAsBytes();
        picked.add(FileModel(
          id: '${DateTime.now().millisecondsSinceEpoch}_${img.name}',
          name: img.name,
          path: img.path,
          bytes: bytes,
          addedAt: DateTime.now(),
          size: bytes.length,
        ));
      }
      _navigateToOptions(picked, shop);
    } catch (e) {
      debugPrint("Error picking gallery images: $e");
    }
  }

  Future<void> _pickFromCamera(BuildContext context, XeroxShopModel shop) async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      
      final bytes = await image.readAsBytes();
      final fileModel = FileModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${image.name}',
        name: image.name,
        path: image.path,
        bytes: bytes,
        addedAt: DateTime.now(),
        size: bytes.length,
      );
      _navigateToOptions([fileModel], shop);
    } catch (e) {
      debugPrint("Error capturing camera image: $e");
    }
  }

  void _navigateToOptions(List<FileModel> files, XeroxShopModel shop) {
    Navigator.pop(context); // Pop the ZikrinterServiceShopsPage bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrintOptionsPage(
          pickedFiles: files,
          printMode: PrintMode.xeroxShop,
          shopId: shop.id,
          shopName: shop.name,
          shopPhone: shop.phoneNumber,
          serviceId: widget.serviceId,
          serviceName: widget.serviceName,
          selectedPaperSize: widget.selectedPaperSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final combinedDocs = <String, DocumentSnapshot>{
      ..._primaryDocs,
      ..._secondaryDocs,
    };

    final providerShops = <_ShopWithService>{};

    combinedDocs.forEach((id, doc) {
      final shopData = doc.data() as Map<String, dynamic>? ?? {};
      final zikrinterServices = shopData['zikrinterServices'] as Map<String, dynamic>? ?? {};
      final serviceConfig = zikrinterServices[widget.serviceId] as Map<String, dynamic>?;
      
      final isActive = shopData['isActive'] ?? true;
      final isOnline = shopData['isOpen'] as bool? ?? true;
      final isBlocked = shopData['isBlocked'] == true;
      final isAcceptingOrders = shopData['isAcceptingOrders'] != false;

      if (isActive && isOnline && !isBlocked && isAcceptingOrders && serviceConfig != null && serviceConfig['isEnabled'] == true) {
        final sizeKey = widget.selectedPaperSize.toLowerCase();
        
        final pricing = XeroxPricing.fromShopData(shopData, widget.globalParams, serviceId: widget.serviceId);
        final bwPrice = pricing.normalBwPrices[sizeKey] ?? 0.0;
        final colorPrice = pricing.normalColorPrices[sizeKey] ?? 0.0;

        final bwSingleGlobal = widget.globalParams['${sizeKey}_bw_singleSide'] ?? widget.globalParams['bw_singleSide'] ?? {};
        final colorSingleGlobal = widget.globalParams['${sizeKey}_color_singleSide'] ?? widget.globalParams['color_singleSide'] ?? {};

        final bool isBwEnabledGlobally = bwSingleGlobal['isEnabled'] == true || widget.globalParams['bw_singleSide']?['isEnabled'] == true;
        final bool isColorEnabledGlobally = colorSingleGlobal['isEnabled'] == true || widget.globalParams['color_singleSide']?['isEnabled'] == true;

        bool isBwConfigured = !isBwEnabledGlobally || bwPrice > 0.0;
        bool isColorConfigured = !isColorEnabledGlobally || colorPrice > 0.0;

        if (isBwConfigured && isColorConfigured && (bwPrice > 0.0 || colorPrice > 0.0)) {
          final shop = XeroxShopModel.fromMap(shopData, doc.id);
          providerShops.add(_ShopWithService(shop: shop, config: serviceConfig));
        }
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Shop (${widget.selectedPaperSize})',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : providerShops.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          'No shops support ${widget.selectedPaperSize} for this service.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: providerShops.length,
                  itemBuilder: (context, index) {
                    final item = providerShops.elementAt(index);
                    final shop = item.shop;
                    final pricing = XeroxPricing.fromShopData({
                      'zikrinterServices': shop.zikrinterServices,
                      'pricePerBWPage': shop.pricePerBWPage,
                      'pricePerColorPage': shop.pricePerColorPage,
                    }, widget.globalParams, serviceId: widget.serviceId);
                    
                    final sizeKey = widget.selectedPaperSize.toLowerCase();
                    final double startingPrice = pricing.normalBwPrices[sizeKey] ?? 2.0;
                    final double colorPrice = pricing.normalColorPrices[sizeKey] ?? 10.0;
                    final double bulkBwPrice = pricing.bulkBwPrices[sizeKey] ?? 1.5;
                    final int bulkStart = pricing.bwBulkStartPages[sizeKey] ?? 10;
                    
                    final isExpanded = _selectedShopId == shop.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isExpanded ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.5),
                          width: isExpanded ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedShopId = isExpanded ? null : shop.id;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main Header Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      color: Colors.grey[100],
                                      child: shop.imageUrl.isNotEmpty
                                          ? Image.network(
                                              shop.imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _b, _c) => const Icon(Icons.store_rounded, color: Colors.grey),
                                            )
                                          : const Icon(Icons.store_rounded, color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                shop.name,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF9C4),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.star_rounded, size: 12, color: Colors.orange),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    shop.rating.toStringAsFixed(1),
                                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          shop.address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                                            const SizedBox(width: 3),
                                            Text(
                                              shop.distance,
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                            ),
                                            const Spacer(),
                                            Text(
                                              shop.isCurrentlyOpen ? 'Open Now' : 'Closed',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: shop.isCurrentlyOpen ? Colors.green[700] : Colors.red[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const Divider(height: 24),
                              
                              // Expandable details block
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: !isExpanded
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Starting Price',
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                              Text(
                                                '₹${startingPrice.toStringAsFixed(0)}',
                                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                                              ),
                                            ],
                                          ),
                                          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Shop Information',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                          ),
                                          const SizedBox(height: 8),
                                          _detailRow(Icons.access_time_rounded, 'Hours: ${shop.openingTime ?? '09:00 AM'} - ${shop.closingTime ?? '09:00 PM'}'),
                                          _detailRow(Icons.print_outlined, 'Active Printers: ${shop.activePrinters} available'),
                                          _detailRow(Icons.timer_outlined, 'Est. completion time: 15-20 mins'),
                                          
                                          const SizedBox(height: 12),
                                          Text(
                                            '${widget.selectedPaperSize} Pricing Details',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                          ),
                                          const SizedBox(height: 8),
                                          _detailRow(Icons.brightness_medium_rounded, 'B&W Rate: ₹${startingPrice.toStringAsFixed(1)} / page'),
                                          _detailRow(Icons.color_lens_outlined, 'Color Rate: ₹${colorPrice.toStringAsFixed(1)} / page'),
                                          _detailRow(Icons.discount_outlined, 'Bulk Discount: ₹${bulkBwPrice.toStringAsFixed(1)} / page after $bulkStart pages'),
                                          _detailRow(Icons.settings_outlined, 'Options: Portrait, Landscape, Single, Double Sided'),

                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              onPressed: !shop.isCurrentlyOpen
                                                  ? null
                                                  : () => _showUploadBottomSheet(context, shop),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primaryBlue,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              child: Text(
                                                shop.isCurrentlyOpen ? 'Upload Files' : 'Shop Closed',
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopWithService {
  final XeroxShopModel shop;
  final Map<String, dynamic> config;

  _ShopWithService({required this.shop, required this.config});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ShopWithService &&
          runtimeType == other.runtimeType &&
          shop.id == other.shop.id;

  @override
  int get hashCode => shop.id.hashCode;
}
