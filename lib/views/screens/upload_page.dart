import 'package:apnt/views/screens/auth/login_view.dart';
import 'package:apnt/xerox_shop/xerox_shop_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../viewmodels/upload_viewmodel.dart';
import '../../viewmodels/auth/auth_viewmodel.dart';
import '../../viewmodels/auth/tester_viewmodel.dart';
import '../../utils/app_colors.dart';
import '../../utils/service_availability_helper.dart';
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
import '../../services/local_storage_service.dart';
import '../../services/backend_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_scanner_page.dart';
import '../../xerox_shop/xerox_shop_model.dart';
import '../../xerox_shop/xerox_shop_viewmodel.dart';
import 'print_options/print_options_page.dart';
import 'widgets/zikrinter_services_section.dart';
import 'widgets/print_progress_tracker.dart';
import 'zikrinter_service_details_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/backend_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  int _ordersSubTabIndex = 0; // 0 = Active Orders, 1 = Completed Orders
  late PageController _tabPageController;

  List<FakeDocumentSnapshot> _backendServicesList = [];
  bool _isLoadingServices = true;
  bool _isServerDown = false;
  StreamSubscription? _versionSubscription;

  void _listenToServiceVersion() {
    _fetchServicesFromBackend();
    _versionSubscription = FirebaseFirestore.instance
        .collection('app_config')
        .doc('services_version')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _fetchServicesFromBackend();
      }
    }, onError: (err) {
      debugPrint("Error listening to serviceVersion: $err");
    });
  }

  static final List<FakeDocumentSnapshot> _defaultServicesCatalog = [
    FakeDocumentSnapshot('ZHwQd18Vy08TZkyBFXjB', {
      'serviceName': 'Documents (Xerox)',
      'name': 'Documents (Xerox)',
      'startingPrice': 2.0,
      'isPrimary': true,
      'serviceType': 'xerox',
      'description': 'Precision black & white and color document printing on premium paper.',
      'actionLabel': 'Upload Files',
      'paperSizes': ['A4', 'Legal', 'A3'],
    }),
    FakeDocumentSnapshot('yPiaqNqbvhABcunanu5X', {
      'serviceName': 'Passport Size Photos',
      'name': 'Passport Size Photos',
      'startingPrice': 30.0,
      'serviceType': 'passport',
      'description': 'Official passport and visa size photos with premium photo finish.',
      'actionLabel': 'Order Photos',
      'paperSizes': ['Passport (8 Photos)', 'Passport (16 Photos)', 'Passport (32 Photos)'],
    }),
    FakeDocumentSnapshot('project_binding', {
      'serviceName': 'Project Binding',
      'name': 'Project Binding',
      'startingPrice': 25.0,
      'serviceType': 'binding',
      'description': 'Professional spiral, softcover, and hardcover book binding for college & office.',
      'actionLabel': 'Order Binding',
      'paperSizes': ['A4 Spiral', 'A4 Softcover', 'A4 Hardcover'],
    }),
  ];

  Future<void> _fetchServicesFromBackend() async {
    try {
      // 1. Try Backend REST API first
      try {
        final response = await http
            .get(Uri.parse('${BackendConfig.baseUrl}/api/services'))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && mounted) {
            final List<dynamic> services = data['services'] ?? [];
            if (services.isNotEmpty) {
              setState(() {
                _backendServicesList = services
                    .map((s) => FakeDocumentSnapshot(s['id'] ?? '', s as Map<String, dynamic>))
                    .toList();
                _isServerDown = false;
              });
              return;
            }
          }
        }
      } catch (httpErr) {
        debugPrint("⚠️ Backend services API fetch error: $httpErr");
      }

      // 2. Fetch directly from Services collection across available Firestore instances
      final List<String> appNames = ['psfc', 'zikrinter', 'zikrint_admin'];
      for (final appName in appNames) {
        try {
          FirebaseFirestore fs;
          if (appName == 'psfc') {
            fs = FirebaseFirestore.instance;
          } else {
            fs = FirebaseFirestore.instanceFor(app: Firebase.app(appName));
          }

          // Try 'services' collection
          var snapshot = await fs.collection('services').get().timeout(const Duration(seconds: 5));
          if (snapshot.docs.isEmpty) {
            // Try 'zikrinter' collection
            snapshot = await fs.collection('zikrinter').get().timeout(const Duration(seconds: 5));
          }

          if (snapshot.docs.isNotEmpty && mounted) {
            final validDocs = snapshot.docs.where((d) {
              final dData = d.data();
              return dData['isDeleted'] != true;
            }).toList();

            if (validDocs.isNotEmpty) {
              setState(() {
                _backendServicesList = validDocs
                    .map((doc) => FakeDocumentSnapshot(doc.id, doc.data()))
                    .toList();
                _isServerDown = false;
              });
              return;
            }
          }
        } catch (_) {}
      }

      // 3. Fallback to default services catalogue (Always show services)
      if (mounted) {
        setState(() {
          if (_backendServicesList.isEmpty) {
            _backendServicesList = List.from(_defaultServicesCatalog);
          }
          _isServerDown = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
      if (mounted) {
        setState(() {
          if (_backendServicesList.isEmpty) {
            _backendServicesList = List.from(_defaultServicesCatalog);
          }
          _isServerDown = false;
        });
      }
    } finally {
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
    _tabPageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabPageController = PageController(initialPage: _currentTabIndex);
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
            onPressed: () async {
              Navigator.pop(context);
              final testerVM = context.read<TesterViewModel>();
              await testerVM.signOut();
              await authVM.signOut(testerVM);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginView()),
                  (route) => false,
                );
              }
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
              // 🚫 BLOCK pickup if order is not yet printed by shopkeeper
              if (!freshOrder.isPrintingCompleted) {
                if (mounted) {
                  Navigator.pop(context); // Close loading dialog
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      backgroundColor: Colors.white,
                      title: const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 28),
                          SizedBox(width: 12),
                          Text('Not Printed Yet',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)
                          ),
                        ],
                      ),
                      content: const Text(
                        'Your order has not been printed yet.\n\nPlease wait for the shopkeeper to complete printing before scanning.',
                        style: TextStyle(fontSize: 14, height: 1.6),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }
                return; // ❌ Do NOT proceed to pickup or mark scanned
              }

              // ✅ Order IS printed — mark scanned and navigate to pickup page
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
        title: Image.asset(
          'assets/images/zikrint_logo_transparent.png',
          height: 26,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (ctx, err, stack) => Text.rich(
            TextSpan(
              text: 'zik',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(
                  text: 'rint',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    fontSize: 24,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 24),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ServiceSearchDelegate(
                  services: _backendServicesList,
                  uploadVM: uploadVM,
                  onUploadDocuments: _showModeSheet,
                ),
              );
            },
            tooltip: 'Search Services & Documents',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
            tooltip: 'Profile & Account',
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: uploadVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView(
              controller: _tabPageController,
              onPageChanged: (index) {
                setState(() {
                  _currentTabIndex = index;
                  if (index == 1) {
                    _ordersStream = _orderRepo.getActiveOrders();
                  }
                });
              },
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    final xeroxVM = context.read<XeroxShopViewModel>();
                    await xeroxVM.fetchShops();
                    await _fetchServicesFromBackend();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: _isLoadingServices
                      ? const Center(child: CircularProgressIndicator())
                      : _isServerDown
                          ? _buildServerDownSection()
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
                                else if (allDocs.isNotEmpty)
                                  _buildDynamicHeroSection(uploadVM, allDocs.first),
                                  
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
                    if (mounted) {
                      setState(() {
                        _ordersStream = _orderRepo.getActiveOrders();
                      });
                    }
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrdersHeader(),
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
            if (index == 1) {
              _ordersStream = _orderRepo.getActiveOrders();
            }
          });
          _tabPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Orders',
          ),
        ],
      ),
    );
  }

  // ─── Server Down Section ─────────────────────────────────────────────────────
  Widget _buildServerDownSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Our server is down',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We are working on that. Please try again in a few moments.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoadingServices = true;
                });
                _fetchServicesFromBackend();
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
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
                    onPressed: () => ServiceAvailabilityHelper.checkAndNavigate(
                      context: context,
                      serviceId: doc.id,
                      onAvailable: () => Navigator.push(
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
                      ),
                    ),
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


  // ─── Orders Sub-Tab Header ───────────────────────────────────────────────────
  Widget _buildOrdersHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ORDERS',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _ordersSubTabIndex = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _ordersSubTabIndex == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _ordersSubTabIndex == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Active Orders',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _ordersSubTabIndex == 0 ? AppColors.primaryBlue : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _ordersSubTabIndex = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _ordersSubTabIndex == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _ordersSubTabIndex == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Completed Orders',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _ordersSubTabIndex == 1 ? AppColors.primaryBlue : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final rawOrders = snapshot.data!;

        // 🚀 AUTO-REOPEN PICKUP PAGE Logic
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final needsPickup = rawOrders.where((o) => o.scanned && !o.isPicked).toList();
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

        // 🔀 Filter based on active vs completed sub-tab
        if (_ordersSubTabIndex == 0) {
          final currentUser = FirebaseAuth.instance.currentUser;
          // Active Orders Sub-tab: Live stream active orders are authoritative
          final activeOrders = rawOrders
              .where((o) => !o.isPicked && o.status != OrderStatus.completed && !o.orderDone)
              .toList();
          activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              // 🧪 Terminal Console Logger for Tester Account Active Orders
              final authVM = context.read<AuthViewModel>();
              final testerVM = context.read<TesterViewModel>();
              final String currentUserEmail = (currentUser?.email ?? authVM.user?.email ?? '').toLowerCase();
              final bool isReviewerAccount = testerVM.isReviewerSession || currentUserEmail == 'reviewer@zikrint.app' || currentUserEmail.contains('reviewer');

              if (isReviewerAccount) {
                debugPrint("\n==================================================");
                debugPrint("🧪 [TESTER ACCOUNT ACTIVE ORDERS]: Found ${activeOrders.length} active order(s)");
                if (activeOrders.isEmpty) {
                  debugPrint("⚠️ No active orders currently found for tester account.");
                } else {
                  for (int i = 0; i < activeOrders.length; i++) {
                    final o = activeOrders[i];
                    debugPrint("  [$i] Order ID: ${o.orderId} | Pickup Code: ${o.pickupCode} | Status: ${o.status.name} / ${o.orderStatus ?? 'active'} | Amount: ₹${o.totalPrice} | Files: ${o.fileUrls.length}");
                  }
                }
                debugPrint("==================================================\n");
              }

              if (activeOrders.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No active orders in progress',
                          style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final xeroxOrders = activeOrders.where((o) => o.printMode == PrintMode.xeroxShop).toList();
              final kioskOrders = activeOrders.where((o) => o.printMode == PrintMode.autonomous).toList();

              return Column(
                children: [
                  if (xeroxOrders.isNotEmpty) ...[
                    _sectionHeader('XEROX SHOP ORDERS', Icons.store_rounded),
                    const SizedBox(height: 12),
                    ...xeroxOrders.map((order) => _buildOrderCard(order)),
                  ],
                  if (kioskOrders.isNotEmpty) ...[
                    if (xeroxOrders.isNotEmpty) const SizedBox(height: 20),
                    _sectionHeader('KIOSK PRINT ORDERS', Icons.print_rounded),
                    const SizedBox(height: 12),
                    ...kioskOrders.map((order) => _buildOrderCard(order)),
                  ],
                ],
              );
        } else {
          // Completed Orders Sub-tab: Merge live stream, Firestore order_history & backend REST API
          final currentUser = FirebaseAuth.instance.currentUser;
          return FutureBuilder<List<PrintOrderModel>>(
            future: () async {
              final List<PrintOrderModel> list = [];
              final local = await LocalStorageService().getLocalOrders(
                userId: currentUser?.uid,
                userEmail: currentUser?.email,
              );
              list.addAll(local);

              try {
                final remote = await FirestoreService().getUserOrders().first.timeout(const Duration(seconds: 4));
                list.addAll(remote);
              } catch (_) {}

              if (currentUser != null) {
                try {
                  final restOrders = await BackendService().getOrderHistory(currentUser.uid);
                  for (final raw in restOrders) {
                    final id = (raw['orderId'] ?? raw['id'] ?? '').toString();
                    if (id.isNotEmpty) {
                      list.add(PrintOrderModel.fromLocalMap(raw));
                    }
                  }
                } catch (_) {}
              }

              final Map<String, PrintOrderModel> combinedMap = {};
              for (final o in rawOrders) {
                if (o.status == OrderStatus.completed || o.isPicked || o.orderDone || (o.orderStatus ?? '').toLowerCase().contains('completed')) {
                  combinedMap[o.orderId] = o;
                }
              }
              for (final o in list) {
                if (o.status == OrderStatus.completed || o.isPicked || o.orderDone || (o.orderStatus ?? '').toLowerCase().contains('completed')) {
                  combinedMap[o.orderId] = o;
                }
              }

              final res = combinedMap.values.where((o) => !o.deletedByUser).toList();
              res.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return res;
            }(),
            builder: (context, localSnapshot) {
              final completedOrders = localSnapshot.data ?? [];

              if (localSnapshot.connectionState == ConnectionState.waiting && completedOrders.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (completedOrders.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 40, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No completed orders yet',
                          style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final xeroxCompleted = completedOrders.where((o) => o.printMode == PrintMode.xeroxShop).toList();
              final kioskCompleted = completedOrders.where((o) => o.printMode == PrintMode.autonomous).toList();

              return Column(
                children: [
                  if (xeroxCompleted.isNotEmpty) ...[
                    _sectionHeader('COMPLETED XEROX ORDERS', Icons.store_rounded),
                    const SizedBox(height: 12),
                    ...xeroxCompleted.map((order) => _buildOrderCard(order)),
                  ],
                  if (kioskCompleted.isNotEmpty) ...[
                    if (xeroxCompleted.isNotEmpty) const SizedBox(height: 20),
                    _sectionHeader('COMPLETED KIOSK ORDERS', Icons.print_rounded),
                    const SizedBox(height: 12),
                    ...kioskCompleted.map((order) => _buildOrderCard(order)),
                  ],
                ],
              );
            },
          );
        }
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
    final bool isCompleted = order.status == OrderStatus.completed || order.isPicked || order.orderDone;
    final bool isVerified = order.scanned || order.codeRevealed || isCompleted;

    final String statusLabel = isCompleted
        ? 'ORDER COMPLETED'
        : (order.isPrintingCompleted
            ? 'READY FOR PICKUP'
            : (order.orderStatus != null && order.orderStatus!.isNotEmpty)
                ? order.orderStatus!.toUpperCase()
                : 'NOT PRINTED YET');

    final Color statusColor = (isCompleted || order.isPrintingCompleted) ? Colors.green : Colors.orange;
    final IconData statusIcon = (isCompleted || order.isPrintingCompleted)
        ? Icons.check_circle_rounded
        : Icons.hourglass_bottom_rounded;

    return Stack(
      children: [
        InkWell(
          onTap: () => _showOrderDetails(order),
          borderRadius: BorderRadius.circular(16),
          child: ModernCard(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusIcon, 
                                    size: 12, 
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      statusLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                        letterSpacing: 0.5
                                      ),
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
                if (!isCompleted && order.isXerox) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      String? shopAddr = order.printSettings['shopAddress'];
                      if (shopAddr == null || shopAddr.isEmpty || shopAddr == 'N/A') {
                        try {
                          final xeroxVM = context.read<XeroxShopViewModel>();
                          final matched = xeroxVM.shops.firstWhere((s) => s.id == order.shopId);
                          if (matched.address.isNotEmpty) shopAddr = matched.address;
                        } catch (_) {}
                      }
                      final query = (shopAddr != null && shopAddr.isNotEmpty && shopAddr != 'N/A')
                          ? shopAddr
                          : (order.shopName ?? 'Xerox Shop');
                      final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.map_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NAVIGATE TO SHOP',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryBlue,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  order.shopName != null ? '${order.shopName} • Tap for Map' : 'Tap to open Google Maps directions',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.directions_rounded,
                            size: 20,
                            color: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

// ─── Service & Document Search Delegate ──────────────────────────────────────
class ServiceSearchDelegate extends SearchDelegate<void> {
  final List<FakeDocumentSnapshot> services;
  final UploadViewModel uploadVM;
  final VoidCallback onUploadDocuments;

  ServiceSearchDelegate({
    required this.services,
    required this.uploadVM,
    required this.onUploadDocuments,
  });

  @override
  String get searchFieldLabel => 'Search services, documents, Xerox...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.inter(
          color: AppColors.textTertiary,
          fontSize: 15,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchContent(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchContent(context);
  }

  Widget _buildSearchContent(BuildContext context) {
    final q = query.trim().toLowerCase();

    // Check if query matches general document printing keywords
    final docKeywords = ['doc', 'document', 'pdf', 'xerox', 'print', 'a4', 'a3', 'copy', 'paper', 'file', 'upload', 'color', 'bw'];
    final matchesDocPrint = q.isEmpty || docKeywords.any((k) => k.contains(q) || q.contains(k));

    // Filter services list
    final filteredServices = services.where((doc) {
      final data = doc.data();
      final name = (data['serviceName'] ?? data['name'] ?? '').toString().toLowerCase();
      final desc = (data['description'] ?? '').toString().toLowerCase();
      final cat = (data['category'] ?? data['serviceType'] ?? '').toString().toLowerCase();
      if (q.isEmpty) return true;
      return name.contains(q) || desc.contains(q) || cat.contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (q.isEmpty) ...[
          Text(
            'POPULAR SEARCHES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, '📄 Document Xerox'),
              _chip(context, '📸 Photo Print'),
              _chip(context, '📘 Spiral Binding'),
              _chip(context, '🛡️ Lamination'),
              _chip(context, '💼 Resume / CV'),
              _chip(context, '🎨 Poster & Banner'),
              _chip(context, '🏷️ Stickers'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'AVAILABLE SERVICES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Hero Document Xerox Option
        if (matchesDocPrint) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded, color: AppColors.primaryBlue, size: 26),
                ),
                title: Text(
                  'Documents (Xerox & Print)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Upload PDF/Images • Color & B/W printing starting at ₹2/page',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    close(context, null);
                    onUploadDocuments();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text('Upload', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],

        // Service Items
        ...filteredServices.map((doc) {
          final data = doc.data();
          final serviceName = data['serviceName'] ?? data['name'] ?? 'Printing Service';
          final description = data['description'] ?? '';
          final imageUrl = data['imageUrl'] ?? (data['images'] != null && (data['images'] as List).isNotEmpty ? (data['images'] as List).first : '');
          final images = List<String>.from(data['images'] ?? []);
          final startingPrice = (data['startingPrice'] ?? 0.0).toDouble();
          final globalParams = {
            ...(data['parameters'] as Map<String, dynamic>? ?? {}),
            'paperSizes': data['paperSizes'],
          };
          final actionButtonLabel = data['actionLabel'] as String?;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.015),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: AppColors.background,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.print_rounded, color: AppColors.primaryBlue),
                          )
                        : const Icon(Icons.print_rounded, color: AppColors.primaryBlue),
                  ),
                ),
                title: Text(
                  serviceName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty)
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 2),
                    if (startingPrice > 0)
                      Text(
                        'Starting at ₹${startingPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                onTap: () => ServiceAvailabilityHelper.checkAndNavigate(
                  context: context,
                  serviceId: doc.id,
                  onAvailable: () {
                    close(context, null);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ZikrinterServiceDetailsPage(
                          serviceId: doc.id,
                          serviceName: serviceName,
                          description: description,
                          imageUrl: imageUrl,
                          images: images,
                          startingPrice: startingPrice,
                          globalParams: globalParams,
                          actionButtonLabel: actionButtonLabel,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }),

        if (filteredServices.isEmpty && !matchesDocPrint) ...[
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'No matching services found',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try searching for "document", "photo", "binding", etc.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(BuildContext context, String label) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        final cleanQuery = label.replaceAll(RegExp(r'^[^\s]+\s*'), ''); // strip emoji prefix
        query = cleanQuery;
        showResults(context);
      },
    );
  }
}


