import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import 'xerox_shop_model.dart';
import 'xerox_shop_viewmodel.dart';
import 'shop_card.dart';
import '../../models/file_model.dart';
import '../../models/print_order_model.dart';
import '../views/screens/print_options/print_options_page.dart';
import '../services/preferences_service.dart';
import '../services/firestore_service.dart';
import '../views/screens/widgets/upload_source_sheet.dart';
import '../viewmodels/upload_viewmodel.dart';
import '../views/screens/qr_scanner_page.dart';

class XeroxShopPage extends StatefulWidget {
  final List<FileModel> files;
  final String? initiallySelectedShopId;
  const XeroxShopPage({super.key, required this.files, this.initiallySelectedShopId});

  @override
  State<XeroxShopPage> createState() => _XeroxShopPageState();
}

class _XeroxShopPageState extends State<XeroxShopPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<XeroxShopViewModel>().fetchShops();
      _checkDefaultShop();
      _handleInitialShop();
    });
  }

  void _handleInitialShop() {
    if (widget.initiallySelectedShopId != null) {
      final viewModel = context.read<XeroxShopViewModel>();
      try {
        final shop = viewModel.shops.firstWhere(
          (s) => s.id == widget.initiallySelectedShopId,
        );
        _showShopDetails(context, shop);
      } catch (e) {
        debugPrint("Initial shop not found: ${widget.initiallySelectedShopId}");
      }
    }
  }

  Future<void> _checkDefaultShop() async {
    final defaultData = await PreferencesService.getDefaultShop();
    if (defaultData != null && mounted) {
      debugPrint("🎯 Default shop found: ${defaultData['name']}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<XeroxShopViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'XEROX SHOPS',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900, 
            letterSpacing: 1, 
            fontSize: 18,
            color: AppColors.primaryBlack,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.primaryBlack),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Header / Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a Nearby Shop',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlack,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse through available print stations near you',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSearchBar(viewModel),
                ],
              ),
            ),
          ),
          
          if (viewModel.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
              ),
            )
          else if (viewModel.shops.isEmpty)
            _buildEmptyState()
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final shop = viewModel.shops[index];
                    return ShopCard(
                      shop: shop,
                      onDetails: () => _showShopDetails(context, shop),
                      onTap: () => _handleShopSelection(context, shop),
                    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
                  },
                  childCount: viewModel.shops.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openScanner(XeroxShopViewModel viewModel) async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );

    if (result != null && mounted) {
      // Find the shop by ID or Name
      try {
        final shop = viewModel.shops.firstWhere(
          (s) {
            final String normalizedResult = result.startsWith('thinkink-shop:') 
                ? result.replaceFirst('thinkink-shop:', '') 
                : result;
            return s.id == normalizedResult || s.name.toLowerCase() == normalizedResult.toLowerCase();
          },
          orElse: () => throw Exception('Shop not found'),
        );
        _handleShopSelection(context, shop);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shop not found for scanned code: $result'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildSearchBar(XeroxShopViewModel viewModel) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (v) => viewModel.searchShops(v),
              decoration: InputDecoration(
                hintText: 'Search for shops...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const VerticalDivider(width: 24, indent: 16, endIndent: 16),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBlue, size: 24),
            onPressed: () => _openScanner(viewModel),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.store_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'No Shops Available',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleShopSelection(BuildContext context, XeroxShopModel shop) async {
    // 1. Check if closed
    if (!shop.isCurrentlyOpen) {
       final proceed = await _showClosedWarning(context, shop);
       if (!proceed) return;
    }

    // ✅ 2. Immediately record the shop selection in Firebase
    FirestoreService().saveSelectedShop(shopId: shop.id, shopName: shop.name);
    debugPrint("📌 Shop selected & saved to Firebase: ${shop.name} (${shop.id})");

    // 3. Check for Default Shop preference
    final defaultShop = await PreferencesService.getDefaultShop();
    if (!mounted) return;
    
    if (defaultShop == null || defaultShop['id'] != shop.id) {
       if (!context.mounted) return;
       final setAsDefault = await _showDefaultPrompt(context, shop);
       if (setAsDefault) {
          await PreferencesService.setDefaultShop(shop.id, shop.name);
       }
    }

    // 4. Trigger File Picker Sheet
    if (!mounted || !context.mounted) return;
    _showSourceSheet(context, shop);
  }

  Future<bool> _showClosedWarning(BuildContext context, XeroxShopModel shop) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Shop is Closed'),
        content: Text('${shop.name} is currently closed. Timings: ${shop.openingTime} - ${shop.closingTime}.\n\nDo you want to proceed and send files anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('PROCEED')),
        ],
      )
    ) ?? false;
  }

  Future<bool> _showDefaultPrompt(BuildContext context, XeroxShopModel shop) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Set as Default?'),
        content: Text('Would you like to set ${shop.name} as your default Xerox shop for faster access?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SET AS DEFAULT')),
        ],
      )
    ) ?? false;
  }

  void _showSourceSheet(BuildContext context, XeroxShopModel shop) {
    final uploadVM = context.read<UploadViewModel>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadSourceSheet(
        onCamera: () async {
          Navigator.pop(context);
          await uploadVM.pickFromCamera();
          if (!mounted || !context.mounted) return;
          _handlePickedFiles(context, shop, uploadVM);
        },
        onGallery: () async {
          Navigator.pop(context);
          await uploadVM.pickFromGallery();
          if (!mounted || !context.mounted) return;
          _handlePickedFiles(context, shop, uploadVM);
        },
        onFiles: () async {
          Navigator.pop(context);
          await uploadVM.pickFromFiles();
          if (!mounted || !context.mounted) return;
          _handlePickedFiles(context, shop, uploadVM);
        },
      ),
    );
  }

  void _handlePickedFiles(BuildContext context, XeroxShopModel shop, UploadViewModel uploadVM) {
    if (uploadVM.files.isEmpty) return;
    
    final files = List<FileModel>.from(uploadVM.files);
    uploadVM.clearPickedFiles(); // ✅ Clear tray after navigation

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrintOptionsPage(
          pickedFiles: files,
          printMode: PrintMode.xeroxShop,
          shopId: shop.id,
          shopName: shop.name,
          shopPhone: shop.phoneNumber,
        ),
      ),
    );
  }

  void _showShopDetails(BuildContext context, XeroxShopModel shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.store_rounded, color: AppColors.primaryBlue, size: 40),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryBlack),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop.address,
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: shop.activePrinters > 0 
                            ? AppColors.success.withValues(alpha: 0.1) 
                            : AppColors.textTertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded, 
                              size: 14, 
                              color: shop.activePrinters > 0 ? AppColors.success : AppColors.textTertiary
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${shop.activePrinters} PRINTERS ACTIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10, 
                                fontWeight: FontWeight.w900, 
                                color: shop.activePrinters > 0 ? AppColors.success : AppColors.textSecondary
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            _detailHeading('SHOPKEEPER DETAILS'),
            _detailRow(Icons.person_outline_rounded, 'Owner', shop.ownerName ?? 'Not Available'),
            _detailRow(Icons.phone_outlined, 'Contact', shop.phoneNumber ?? 'Not Available'),
            _detailRow(Icons.email_outlined, 'Email', shop.email ?? 'Not Available'),
            
            const SizedBox(height: 24),
            _detailHeading('WORKING HOURS'),
            _detailRow(Icons.access_time_rounded, 'Timings', '${shop.openingTime} - ${shop.closingTime}'),
            
            const SizedBox(height: 24),
            _detailHeading('PRICING'),
            Row(
              children: [
                _priceCard('Black & White', '₹${shop.pricePerBWPage.toStringAsFixed(0)}'),
                const SizedBox(width: 16),
                _priceCard('Colored Print', '₹${shop.pricePerColorPage.toStringAsFixed(0)}'),
              ],
            ),
            
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleShopSelection(context, shop);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'SELECT THIS SHOP',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlack),
          ),
        ],
      ),
    );
  }

  Widget _priceCard(String label, String price) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(price, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryBlue)),
          ],
        ),
      ),
    );
  }
}

