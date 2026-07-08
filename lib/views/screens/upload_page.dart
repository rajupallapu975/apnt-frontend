import 'package:apnt/xerox_shop/xerox_shop_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../viewmodels/upload_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/modern_card.dart';
import '../../models/print_order_model.dart';
import '../../models/file_model.dart';
import '../../repositories/order_repository.dart';
import 'pickup_page.dart';
import 'history_page.dart'; // Rename reference if needed
import 'widgets/order_details_sheet.dart';
import '../profile_page.dart';
import 'notifications_page.dart';
import '../../services/notification_service.dart';
import '../../services/pwa_service.dart';
import '../../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_scanner_page.dart';
import '../../xerox_shop/xerox_shop_model.dart';
import '../../xerox_shop/xerox_shop_viewmodel.dart';
import 'print_options/print_options_page.dart';
import 'widgets/zikrinter_services_section.dart';
import 'zikrinter_service_details_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/backend_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FakeDocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;
  FakeDocumentSnapshot(this.id, this._data);
  Map<String, dynamic> data() => _data;
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final OrderRepository _orderRepo = OrderRepository();
  final Set<String> _autoOpenedIds = {}; // Prevent multiple auto-opens per session
  late Stream<List<PrintOrderModel>> _ordersStream;
  int _currentTabIndex = 0;

  List<FakeDocumentSnapshot> _backendServicesList = [];
  bool _isLoadingServices = true;
  StreamSubscription? _versionSubscription;

  void _listenToServiceVersion() {
    _fetchServicesFromBackend();
    _versionSubscription = FirebaseFirestore.instance
        .collection('shops')
        .doc('serviceVersion')
        .snapshots()
        .listen((doc) {
      _fetchServicesFromBackend();
    }, onError: (err) {
      debugPrint("Error listening to serviceVersion: $err");
    });
  }

  Future<void> _fetchServicesFromBackend() async {
    try {
      final response = await http.get(Uri.parse('${BackendConfig.baseUrl}/api/services'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final List<dynamic> services = data['services'] ?? [];
          setState(() {
            _backendServicesList = services
                .map((s) => FakeDocumentSnapshot(s['id'] ?? '', s as Map<String, dynamic>))
                .toList();
            _isLoadingServices = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
      if (mounted) {
        setState(() {
          _isLoadingServices = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _versionSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ordersStream = _orderRepo.getActiveOrders();
    _listenToServiceVersion();
    // 🔔 Prompt for notifications on home entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationService>().requestPermission();
        _checkPWAInstallation();
      }
    });
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final authVM = context.read<AuthViewModel>();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Sign Out?", style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        content: const Text("Are you sure you want to end your Zikrint session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authVM.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SIGN OUT"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPWAInstallation() async {
    if (!kIsWeb) return;

    final pwa = PWAService();
    if (!pwa.canInstall) return;

    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('pwa_prompted') ?? false;

    if (!hasPrompted && mounted) {
      // ⏳ Small delay to not overwhelm on entry
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: [
              const Icon(Icons.install_mobile_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Text('INSTALL APP', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          content: const Text('Install Zikrint on your home screen for a fast, app-like experience and easy access.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('NOT NOW', style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('INSTALL'),
            ),
          ],
        ),
      );

      if (shouldInstall == true) {
        await pwa.promptInstall();
      }
      
      // Mark as prompted so we don't ask again this session/re-login
      await prefs.setBool('pwa_prompted', true);
    }
  }


  void _showModeSheet({List<FileModel>? existingFiles}) {
    // 🚀 After modularization, only Xerox Shop mode remains in this app.
    // Autonomous is now a separate project.
    
    // Always navigate to XeroxShopPage first to select a shop
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => XeroxShopPage(files: existingFiles ?? const []),
      ),
    );
  }



  void _handleUploadedFiles(UploadViewModel uploadVM) {
    final files = List<FileModel>.from(uploadVM.files);
    uploadVM.clearPickedFiles();
    _handleSelectedFiles(files);
  }

  void _handleSelectedFiles(List<FileModel> files) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => XeroxShopPage(files: files),
      ),
    );
  }

  Future<void> _openQRScanner({PrintOrderModel? targetOrder}) async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );

    if (result != null && mounted) {
      // ── Order Verification Flow (scan order's shop QR) ──────────────────────
      if (targetOrder != null) {
        // Normalize: strip the zikrint-shop: prefix if present
        final String scannedShopId = result.startsWith('zikrint-shop:')
            ? result.replaceFirst('zikrint-shop:', '')
            : result;

        // Show loading while we check Firebase
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false, // 🛑 Disable system back button
            child: const Center(
              child: CircularProgressIndicator(
                 color: Colors.white, // White loader on dimmed background
                 strokeWidth: 4,
              ),
            ),
          ),
        );

        try {
          final bool verified = await FirestoreService().verifyOrderAtShop(
            orderId: targetOrder.orderId,
            scannedShopId: scannedShopId,
          );

          if (!mounted) return;
          
          if (verified) {
            // 🆕 Fetch the latest order state to check orderStatus
            final freshOrder = await FirestoreService().getOrder(
              targetOrder.orderId, 
              printMode: 'xeroxShop',
              projectId: targetOrder.projectId,
            );

            if (freshOrder != null) {
              // ✅ 1. Inform the user if it's not printed yet, but DON'T block them
              if (!freshOrder.isPrintingCompleted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("ℹ️ Note: Order not marked as printed yet by shopkeeper."),
                    backgroundColor: Colors.orange,
                ));
              }

              // ✅ 2. Persist scan status permanently (Reveals Code)
              await FirestoreService().markOrderScanned(
                orderId: targetOrder.orderId,
                shopId: targetOrder.shopId,
                projectId: targetOrder.projectId,
              );
              
              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                // 🚀 Navigate to dedicated Pickup Page (Now reveals code)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PickupPage(order: freshOrder)),
                );
              }
            } else {
              if (mounted) Navigator.pop(context);
            }
          } else {
            if (mounted) Navigator.pop(context); // close loading dialog
            // ❌ Wrong shop dialog
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Color(0xFFE53935)),
                    SizedBox(width: 12),
                    Text('Wrong Shop'),
                  ],
                ),
                content: const Text(
                  'This order was not placed at this shop. Please scan the correct Xerox shop\'s QR code.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
           if (mounted) Navigator.pop(context);
           debugPrint("❌ Scan Verification Error: $e");
        }
        return;
      }


      // General Shop Scan Flow
      final xeroxVM = context.read<XeroxShopViewModel>();

      // Normalize the scanned result (strip the zikrint-shop: prefix)
      final String normalizedResult = result.startsWith('zikrint-shop:')
          ? result.replaceFirst('zikrint-shop:', '')
          : result;

      // Only fetch from backend if we haven't loaded shops yet
      if (!xeroxVM.hasLoaded) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        await xeroxVM.fetchShops();
        if (mounted) Navigator.pop(context); // Close loading dialog
      }

      if (!mounted) return;

      // Find shop by ID or name  
      try {
        final shop = xeroxVM.shops.firstWhere(
          (s) => s.id == normalizedResult || s.name.toLowerCase() == normalizedResult.toLowerCase(),
          orElse: () => throw Exception('No shop matches: "$normalizedResult"'),
        );
        _handleScannedShop(shop);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shop not found for QR: "$normalizedResult"'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _handleScannedShop(XeroxShopModel shop) {
    // Similar to _handleShopSelection in XeroxShopPage
    // But since we are in UploadPage, we might need to pick files first if tray is empty
    final uploadVM = context.read<UploadViewModel>();
    
    if (uploadVM.pendingFiles.isNotEmpty) {
      final files = List<FileModel>.from(uploadVM.pendingFiles);
      uploadVM.clearPickedFiles();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrintOptionsPage(
            pickedFiles: files,
            printMode: PrintMode.xeroxShop,
            shopId: shop.id,
            shopName: shop.name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => XeroxShopPage(
            files: const <FileModel>[],
            initiallySelectedShopId: shop.id,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadVM = context.watch<UploadViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ZIKRINT',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompletedOrdersPage())),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            onPressed: () => _showLogoutConfirmation(context),
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: uploadVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentTabIndex,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    final xeroxVM = context.read<XeroxShopViewModel>();
                    await xeroxVM.fetchShops();
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) setState(() {});
                  },
                  child: _isLoadingServices
                      ? const Center(child: CircularProgressIndicator())
                      : () {
                          final allDocs = _backendServicesList;
                          FakeDocumentSnapshot? primaryDoc;
                          try {
                            primaryDoc = allDocs.firstWhere((doc) {
                              final data = doc.data();
                              return data['isPrimary'] == true || data['isHero'] == true || data['serviceType'] == 'xerox';
                            });
                          } catch (_) {}

                          if (primaryDoc == null) {
                            try {
                              primaryDoc = allDocs.firstWhere((doc) {
                                final data = doc.data();
                                final name = (data['serviceName'] ?? data['name'] ?? '').toString().toLowerCase();
                                return doc.id == 'ZHwQd18Vy08TZkyBFXjB' || name.contains('xerox') || name.contains('documents');
                              });
                            } catch (_) {}
                          }

                          final otherDocs = allDocs.where((doc) => doc.id != primaryDoc?.id).toList();

                          otherDocs.sort((a, b) {
                            final dataA = a.data();
                            final dataB = b.data();
                            
                            final orderA = dataA['displayOrder'] as num?;
                            final orderB = dataB['displayOrder'] as num?;
                            if (orderA != null && orderB != null) {
                              return orderA.compareTo(orderB);
                            } else if (orderA != null) {
                              return -1;
                            } else if (orderB != null) {
                              return 1;
                            }
                            return 0;
                          });

                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (primaryDoc != null)
                                  _buildDynamicHeroSection(uploadVM, primaryDoc)
                                else
                                  _buildHeroSection(uploadVM),
                                  
                                if (uploadVM.pendingFiles.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildPendingTray(uploadVM),
                                ],
                                const SizedBox(height: 24),
                                ZikrinterServicesSection(services: otherDocs),
                                const SizedBox(height: 24),
                              ],
                            ),
                          );
                        }(),
                ),
                // Tab 2: Active Orders
                RefreshIndicator(
                  onRefresh: () async {
                    final xeroxVM = context.read<XeroxShopViewModel>();
                    await xeroxVM.fetchShops();
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) setState(() {});
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildActiveOrdersHeader(),
                        const SizedBox(height: 16),
                        _buildOrdersList(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.print_outlined),
            activeIcon: Icon(Icons.print),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Active Orders',
          ),
        ],
      ),
    );
  }

  // ─── Documents Hero Card ─────────────────────────────────────────────────────
  Widget _buildHeroSection(UploadViewModel uploadVM) {
    const bulletColor = AppColors.primaryBlue;
    final bulletStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      height: 1.5,
    );

    return ModernCard(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: Text Content ──
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documents (Xerox)',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2D3142),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _bullet(bulletStyle, bulletColor, 'Price starting at ₹2/page'),
                const SizedBox(height: 6),
                _bullet(bulletStyle, bulletColor, 'Max 10MB per file'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _showModeSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(
                      'Upload Files',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ── Right: Document Fan Illustration ──
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Back card
                      Transform.rotate(
                        angle: 0.2,
                        child: _illustrationCard(Icons.image_rounded, AppColors.success.withValues(alpha: 0.7), 'JPG'),
                      ),
                      // Middle card
                      Transform.rotate(
                        angle: -0.1,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: _illustrationCard(Icons.article_rounded, AppColors.primaryBlue.withValues(alpha: 0.8), 'DOC'),
                        ),
                      ),
                      // Front card
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 8),
                        child: _illustrationCard(Icons.picture_as_pdf_rounded, AppColors.error.withValues(alpha: 0.85), 'PDF'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A4 SIZE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05, end: 0, duration: 400.ms);
  }

  Widget _buildDynamicHeroSection(UploadViewModel uploadVM, dynamic doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final serviceName = data['serviceName'] ?? data['name'] ?? 'Documents (Xerox)';
    final startingPrice = (data['startingPrice'] ?? 2.0).toDouble();
    final imageUrl = data['imageUrl'] ?? '';
    
    // We can extract custom bullet points if provided in Firestore, otherwise use defaults
    final rawBullets = data['bulletPoints'] as List<dynamic>?;
    final List<String> bullets = rawBullets != null
        ? List<String>.from(rawBullets)
        : [
            'Price starting at ₹${startingPrice.toStringAsFixed(0)}/page',
            'Max 10MB per file',
          ];

    const bulletColor = AppColors.primaryBlue;
    final bulletStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      height: 1.5,
    );

    return ModernCard(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: Text Content ──
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2D3142),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _bullet(bulletStyle, bulletColor, b),
                )),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ZikrinterServiceDetailsPage(
                            serviceId: doc.id,
                            serviceName: serviceName,
                            description: data['description'] ?? '',
                            imageUrl: imageUrl,
                            images: List<String>.from(data['images'] ?? []),
                            startingPrice: startingPrice,
                            globalParams: {
                              ...(data['parameters'] as Map<String, dynamic>? ?? {}),
                              'paperSizes': data['paperSizes'],
                            },
                            actionButtonLabel: data['actionLabel'],
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(
                      data['actionLabel'] ?? 'Upload Files',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ── Right: Image or Illustration ──
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 110,
                          fit: BoxFit.cover,
                          placeholder: (_, _b) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (_, _b, _c) => const Icon(Icons.image, size: 48, color: Colors.grey),
                        ),
                      )
                    : SizedBox(
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: 0.2,
                              child: _illustrationCard(Icons.image_rounded, AppColors.success.withValues(alpha: 0.7), 'JPG'),
                            ),
                            Transform.rotate(
                              angle: -0.1,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: _illustrationCard(Icons.article_rounded, AppColors.primaryBlue.withValues(alpha: 0.8), 'DOC'),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 8),
                              child: _illustrationCard(Icons.picture_as_pdf_rounded, AppColors.error.withValues(alpha: 0.85), 'PDF'),
                            ),
                          ],
                        ),
                      ),
                const SizedBox(height: 8),
                Text(
                  'A4 SIZE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05, end: 0, duration: 400.ms);
  }

  Widget _bullet(TextStyle style, Color iconColor, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.stars_rounded, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: style.copyWith(
              fontSize: 14,
              color: const Color(0xFF4F5B7D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _illustrationCard(IconData icon, Color color, String label) {
    return Container(
      width: 80,
      height: 113, // 80 / 113.1 = 0.707 (A4 Ratio)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Top colored header
            Container(height: 35, color: color),
            // Title placeholder
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Body lines
            Positioned(
              top: 45,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  5,
                  (i) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    height: 4,
                    width: i == 4 ? 40 : double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ─── Active Orders Header ────────────────────────────────────────────────────
  Widget _buildActiveOrdersHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVE PRINTS',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  // _actionChip helper removed (unused — see chip widgets in _buildOrdersList for reference)

  // ─── Orders Stream ───────────────────────────────────────────────────────────
  Widget _buildOrdersList() {
    return StreamBuilder<List<PrintOrderModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Error loading orders: ${snapshot.error}',
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        // 🚀 FIX: Keep orders visible even after 'completed' status (Admin Done) 
        // until the user actually picks them up (isPicked == false)
        final allOrders = snapshot.data!.where((o) => o.isActive || (o.status == OrderStatus.completed && !o.isPicked)).toList();


        // 🚀 AUTO-REOPEN PICKUP PAGE Logic
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final needsPickup = allOrders.where((o) => o.scanned && !o.isPicked).toList();
          if (needsPickup.isNotEmpty) {
            final order = needsPickup.first;
            if (!_autoOpenedIds.contains(order.orderId)) {
              _autoOpenedIds.add(order.orderId);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PickupPage(order: order)),
              );
            }
          }
        });

        if (allOrders.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'No active orders',
                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final xeroxOrders = allOrders.where((o) => o.printMode == PrintMode.xeroxShop).toList();

        return Column(
          children: [
            if (xeroxOrders.isNotEmpty) ...[
              _sectionHeader('XEROX SHOP ORDERS', Icons.store_rounded),
              const SizedBox(height: 12),
              ...xeroxOrders.map((order) => _buildOrderCard(order)),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.5, 
            color: AppColors.textTertiary
          ),
        ),
      ],
    );
  }

  void _showOrderDetails(PrintOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderDetailsSheet(order: order),
    );
  }

  // ─── Order Card ──────────────────────────────────────────────────────────────
  Widget _buildOrderCard(PrintOrderModel order) {
    final String displayId = order.displayId;
    // 🔐 Code is ONLY revealed after a successful QR scan (scanned) or legacy reveal
    final bool isVerified = order.scanned || order.codeRevealed;


    return Stack(
      children: [

        InkWell(
          onTap: () => _showOrderDetails(order),
          borderRadius: BorderRadius.circular(16),
          child: ModernCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // ── Accent bar ──
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: order.isXerox ? AppColors.success : AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                // ── Job ID column ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayId,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.isXerox) ...[
                        const SizedBox(height: 8),
                        // 📄 Print Status (Real-time from Admin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (order.isPrintingCompleted ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (order.isPrintingCompleted ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                order.isPrintingCompleted 
                                    ? Icons.check_circle_rounded 
                                    : Icons.hourglass_bottom_rounded, 
                                size: 12, 
                                color: order.isPrintingCompleted ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (order.orderStatus ?? 'NOT PRINTED YET').toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.w900, 
                                  color: order.isPrintingCompleted ? Colors.green : Colors.orange, 
                                  letterSpacing: 0.5
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Right: Pickup code (masked ↔ revealed) ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PICKUP CODE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // QR scan button — only shown when not yet verified
                        if (order.isXerox && !isVerified) ...[
                          GestureDetector(
                            onTap: () => _openQRScanner(targetOrder: order),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                        // Code: revealed number with animation
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(scale: anim, child: child),
                          ),
                          child: order.isXerox
                              ? isVerified
                                  ? Text(
                                      order.pickupCode,
                                      key: const ValueKey('revealed'),
                                      style: GoogleFonts.inter(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.success,
                                        letterSpacing: 3,
                                      ),
                                    ).animate().shimmer(duration: 800.ms, color: AppColors.success.withValues(alpha: 0.4))
                                  : Text(
                                      'LOCKED',
                                      key: const ValueKey('masked'),
                                      style: GoogleFonts.inter(
                                        letterSpacing: 4,
                                      ),
                                    )
                              : Text(
                                  order.pickupCode,
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryBlue,
                                    letterSpacing: 2,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // ── Shop/mode badge ──
        Positioned(
          top: 4,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: (order.isXerox ? AppColors.success : AppColors.primaryBlue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order.isXerox ? 'XEROX SHOP' : 'KIOSK PRINT',
              style: GoogleFonts.inter(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: order.isXerox ? AppColors.success : AppColors.primaryBlue,
                letterSpacing: 0.8,
            ),
          ),
        ),
      
        ),
      ],
    );
  }


  


  // ─── Blinkit-style Pending Tray ──────────────────────────────────────────────
  Widget _buildPendingTray(UploadViewModel uploadVM) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PENDING UPLOAD',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${uploadVM.pendingFiles.length}',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.warning),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: uploadVM.pendingFiles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final file = uploadVM.pendingFiles[i];
              return _PendingFileChip(
                file: file,
                onRemove: () => uploadVM.removeFile(file.id),
                onTap: () {
                  final files = List<FileModel>.from(uploadVM.pendingFiles);
                  uploadVM.clearPickedFiles();
                  _showModeSheet(existingFiles: files);
                },
              ).animate().fadeIn(delay: (i * 60).ms).scale(begin: const Offset(0.9, 0.9));
            },
          ),
        ),
      ],
    );
  }
}

// ─── Pending File Chip (Blinkit-style) ──────────────────────────────────────
class _PendingFileChip extends StatelessWidget {
  final FileModel file;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PendingFileChip({
    required this.file,
    required this.onRemove,
    required this.onTap,
  });

  bool get _isPdf => file.name.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Progress ring ──
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  ),
                ),
                Icon(
                  _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                  size: 20,
                  color: _isPdf ? AppColors.error : AppColors.primaryBlue,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                file.name.length > 10 ? '${file.name.substring(0, 8)}…' : file.name,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

