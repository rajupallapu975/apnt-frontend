import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/backend_config.dart';
import '../../viewmodels/auth/tester_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_colors.dart';
import '../../xerox_shop/xerox_shop_model.dart';
import '../../models/file_model.dart';
import '../../models/print_order_model.dart';
import '../../services/pricing_service.dart';
import 'print_options/print_options_page.dart';
import 'widgets/service_image_carousel.dart';

class ZikrinterServiceDetailsPage extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String description;
  final String imageUrl;
  final List<String> images;
  final double startingPrice;
  final Map<String, dynamic> globalParams;
  final String? actionButtonLabel;

  const ZikrinterServiceDetailsPage({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.description,
    required this.imageUrl,
    required this.images,
    required this.startingPrice,
    required this.globalParams,
    this.actionButtonLabel,
  });

  @override
  State<ZikrinterServiceDetailsPage> createState() => _ZikrinterServiceDetailsPageState();
}

class _ZikrinterServiceDetailsPageState extends State<ZikrinterServiceDetailsPage> {
  String _selectedSize = '';
  List<String> _paperSizes = [];
  
  int _currentViewIndex = 0;
  int _prevViewIndex = 0;
  XeroxShopModel? _selectedShop;
  
  List<Map<String, dynamic>> _availableShops = [];
  bool _isLoadingShops = true;
  StreamSubscription<DocumentSnapshot>? _shopSubscription;
  StreamSubscription? _shopsRealtimeSubscription;
  StreamSubscription? _primaryShopsSubscription;

  @override
  void initState() {
    super.initState();
    _loadPaperSizes();
    _loadAvailableShops();
  }

  @override
  void dispose() {
    _shopSubscription?.cancel();
    _shopsRealtimeSubscription?.cancel();
    _primaryShopsSubscription?.cancel();
    super.dispose();
  }

  void _loadPaperSizes() {
    final rawSizes = widget.globalParams['paperSizes'] as List<dynamic>? ?? [];
    final bool isPhoto = widget.serviceName.toLowerCase().contains('passport') ||
                         widget.serviceId.contains('yPiaqNqbvhABcunanu5X');

    setState(() {
      if (isPhoto) {
        _paperSizes = ['4 photos', '8 photos'];
      } else {
        _paperSizes = rawSizes.isNotEmpty ? List<String>.from(rawSizes) : ['A4'];
      }

      final containsA4 = _paperSizes.any((s) => s.toUpperCase() == 'A4');
      if (containsA4) {
        _selectedSize = _paperSizes.firstWhere((s) => s.toUpperCase() == 'A4');
      } else {
        _selectedSize = _paperSizes.first;
      }
    });
  }

  void _setViewIndex(int index) {
    setState(() {
      _prevViewIndex = _currentViewIndex;
      _currentViewIndex = index;
      if (index < 2) {
        _shopSubscription?.cancel();
        _shopSubscription = null;
      }
    });
  }

  void _startListeningToSelectedShop(String shopId) {
    _shopSubscription?.cancel();
    _shopSubscription = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null && mounted) {
        final updatedShop = XeroxShopModel.fromMap(doc.data()!, doc.id);
        setState(() {
          _selectedShop = updatedShop;
        });
      }
    });
  }

  Future<void> _loadAvailableShops() async {
    if (_selectedSize.isEmpty) return;
    setState(() {
      _isLoadingShops = true;
    });

    try {
      final bool isReviewer = TesterViewModel.isCurrentReviewerSession;

      final response = await http.get(Uri.parse('${BackendConfig.baseUrl}/api/services/${widget.serviceId}/shops?paperSize=$_selectedSize&isTestUser=$isReviewer'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> list = data['shops'] ?? [];
          setState(() {
            _availableShops = List<Map<String, dynamic>>.from(list);
            _isLoadingShops = false;
          });
          _startRealtimeShopsListener();
          return;
        }
      }
      setState(() {
        _availableShops = [];
        _isLoadingShops = false;
      });
    } catch (e) {
      debugPrint("Error loading shops: $e");
      setState(() {
        _isLoadingShops = false;
      });
    }
  }

  void _startRealtimeShopsListener() {
    _shopsRealtimeSubscription?.cancel();
    try {
      final secondaryApp = Firebase.app('zikrint_admin');
      _shopsRealtimeSubscription = FirebaseFirestore.instanceFor(app: secondaryApp)
          .collection('shops')
          .snapshots()
          .listen((snapshot) {
        _updateShopsFromSnapshot(snapshot.docs);
      });
    } catch (e) {
      debugPrint("⚠️ Failed to start real-time shops secondary listener: $e");
    }

    _primaryShopsSubscription?.cancel();
    try {
      _primaryShopsSubscription = FirebaseFirestore.instance
          .collection('shops')
          .snapshots()
          .listen((snapshot) {
        _updateShopsFromSnapshot(snapshot.docs);
      });
    } catch (e) {
      debugPrint("⚠️ Failed to start real-time shops primary listener: $e");
    }
  }

  void _updateShopsFromSnapshot(List<DocumentSnapshot> docs) {
    if (!mounted || _availableShops.isEmpty) return;
    setState(() {
      final updatedData = <String, Map<String, dynamic>>{};
      for (final doc in docs) {
        if (doc.exists && doc.data() != null) {
          updatedData[doc.id] = doc.data() as Map<String, dynamic>;
        }
      }

      for (int i = 0; i < _availableShops.length; i++) {
        final shopId = _availableShops[i]['id'];
        if (updatedData.containsKey(shopId)) {
          _availableShops[i] = {
            ..._availableShops[i],
            ...updatedData[shopId]!,
          };
        }
      }
    });
  }

  List<Map<String, dynamic>> get _shopsForSelectedSize {
    return _availableShops;
  }

  String _getDimensions(String size) {
    final s = size.toUpperCase();
    if (s.contains('4 PHOTO') || s == '4 PHOTOS') return 'Set of 4 Photos  •  ₹60';
    if (s.contains('8 PHOTO') || s == '8 PHOTOS') return 'Set of 8 Photos  •  ₹100';
    if (s == 'A4' || s.contains('BOND')) {
      return '21.0 × 29.7 cm';
    }
    switch (s) {
      case 'A3':
        return '29.7 × 42.0 cm';
      case 'A2':
        return '42.0 × 59.4 cm';
      case 'A1':
        return '59.4 × 84.1 cm';
      case 'LEGAL':
        return '21.6 × 35.6 cm';
      default:
        return 'Standard size';
    }
  }

  String _getInches(String size) {
    final s = size.toUpperCase();
    if (s.contains('PHOTO')) return '3.5 × 4.5 cm (Passport)';
    if (s == 'A4' || s.contains('BOND')) {
      return '8.3 × 11.7 in';
    }
    switch (s) {
      case 'A3':
        return '11.7 × 16.5 in';
      case 'A2':
        return '16.5 × 23.4 in';
      case 'A1':
        return '23.4 × 33.1 in';
      case 'LEGAL':
        return '8.5 × 14.0 in';
      default:
        return '';
    }
  }

  // ─── Shop Details Bottom Sheet ───────────────────────────────────────────────
  void _showShopDetails(
    BuildContext context, 
    XeroxShopModel shop, 
    XeroxPricing pricing,
    double bwPrice,
    double colorPrice,
    double bulkBwPrice,
    int bulkStart,
  ) {
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                        color: shop.activePrinters > 0 ? AppColors.success : AppColors.textTertiary
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
                    Text(
                      'Shop Information',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlack),
                    ),
                    const SizedBox(height: 12),
                    _detailRow(Icons.access_time_rounded, 'Hours: ${shop.openingTime ?? "09:00 AM"} - ${shop.closingTime ?? "09:00 PM"}'),
                    _detailRow(Icons.print_outlined, 'Active Printers: ${shop.activePrinters} available'),
                    _detailRow(Icons.timer_outlined, 'Est. completion time: 15-20 mins'),
                    
                    const SizedBox(height: 24),
                    Text(
                      '${_selectedSize.toUpperCase()} Pricing Details',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlack),
                    ),
                    const SizedBox(height: 12),
                    _detailRow(Icons.brightness_medium_rounded, 'B&W Rate: ${bwPrice > 0 ? '₹${bwPrice.toStringAsFixed(1)} / page' : 'Unavailable'}'),
                    _detailRow(Icons.color_lens_outlined, 'Color Rate: ${colorPrice > 0 ? '₹${colorPrice.toStringAsFixed(1)} / page' : 'Unavailable'}'),
                    if (bulkBwPrice > 0)
                      _detailRow(Icons.discount_outlined, 'Bulk Discount: ₹${bulkBwPrice.toStringAsFixed(1)} / page after $bulkStart pages')
                    else
                      _detailRow(Icons.discount_outlined, 'Bulk Discount: Unavailable'),
                    _detailRow(Icons.settings_outlined, 'Options: Portrait, Landscape, Single, Double Sided'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Upload Bottom Sheet ─────────────────────────────────────────────────────
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
                'Select file source for $_selectedSize printout',
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

  bool get _isPassportPhotoService => widget.serviceName.toLowerCase().contains('passport') ||
                                      widget.serviceId.contains('yPiaqNqbvhABcunanu5X');

  Future<void> _pickFromFiles(BuildContext context, XeroxShopModel shop) async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
        allowMultiple: !_isPassportPhotoService,
      );
      if (result == null || result.files.isEmpty) return;

      var selectedFiles = result.files;
      if (_isPassportPhotoService && selectedFiles.length > 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passport photo service allows only 1 photo to be uploaded at a time.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        selectedFiles = [selectedFiles.first];
      }

      _navigateToOptions(selectedFiles.map((f) => FileModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${f.name}',
        name: f.name,
        path: f.path ?? '',
        file: f.path != null ? File(f.path!) : null,
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
      if (_isPassportPhotoService) {
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
        final bytes = await image.readAsBytes();
        final fileModel = FileModel(
          id: '${DateTime.now().millisecondsSinceEpoch}_${image.name}',
          name: image.name,
          path: image.path,
          file: File(image.path),
          bytes: bytes,
          addedAt: DateTime.now(),
          size: bytes.length,
        );
        _navigateToOptions([fileModel], shop);
      } else {
        final images = await picker.pickMultiImage();
        if (images.isEmpty) return;
        
        final List<FileModel> picked = [];
        for (final img in images) {
          final bytes = await img.readAsBytes();
          picked.add(FileModel(
            id: '${DateTime.now().millisecondsSinceEpoch}_${img.name}',
            name: img.name,
            path: img.path,
            file: File(img.path),
            bytes: bytes,
            addedAt: DateTime.now(),
            size: bytes.length,
          ));
        }
        _navigateToOptions(picked, shop);
      }
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
        file: File(image.path),
        bytes: bytes,
        addedAt: DateTime.now(),
        size: bytes.length,
      );
      _navigateToOptions([fileModel], shop);
    } catch (e) {
      debugPrint("Error capturing camera image: $e");
    }
  }

  Future<List<FileModel>> _autoCropPassportPhotosIfNeeded(List<FileModel> files) async {
    if (!_isPassportPhotoService) return files;
    final List<FileModel> inputFiles = files.length > 1 ? [files.first] : files;

    final List<FileModel> processed = [];
    for (final model in inputFiles) {
      final String src = kIsWeb ? model.path : (model.file?.path ?? model.path);
      if (src.isEmpty) {
        processed.add(model);
        continue;
      }
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: src,
          aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 4),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Fit Photo (3:4 Passport Ratio)',
              toolbarColor: AppColors.primaryBlue,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio4x3,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Fit Photo (3:4 Passport Ratio)',
              aspectRatioLockEnabled: true,
            ),
          ],
        );
        if (cropped != null) {
          final bytes = await cropped.readAsBytes();
          final String webPath = kIsWeb ? "data:image/png;base64,${base64Encode(bytes)}" : cropped.path;
          processed.add(FileModel(
            id: model.id,
            name: model.name,
            path: webPath,
            file: kIsWeb ? null : File(cropped.path),
            bytes: bytes,
            addedAt: DateTime.now(),
            size: bytes.length,
            pageCount: 1,
          ));
        } else {
          processed.add(model);
        }
      } catch (e) {
        debugPrint("Error auto-cropping passport photo: $e");
        processed.add(model);
      }
    }
    return processed;
  }

  Future<void> _navigateToOptions(List<FileModel> files, XeroxShopModel shop) async {
    final processedFiles = await _autoCropPassportPhotosIfNeeded(files);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrintOptionsPage(
          pickedFiles: processedFiles,
          printMode: PrintMode.xeroxShop,
          shopId: _selectedShop!.id,
          shopName: _selectedShop!.name,
          shopPhone: _selectedShop!.phoneNumber,
          serviceId: widget.serviceId,
          serviceName: widget.serviceName,
          selectedPaperSize: _selectedSize,
        ),
      ),
    );
  }

  Future<void> _handleUploadFilesClick(BuildContext context, XeroxShopModel shop) async {
    final navigator = Navigator.of(context);
    
    // 1. Show dynamic pricing verification loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  ),
                ),
                const SizedBox(width: 20),
                Flexible(
                  child: Text(
                    "Verifying shop pricing...",
                    softWrap: true,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // 2. Fetch the absolute latest shop document from Firestore to double verify pricing
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(shop.id).get();
      if (doc.exists && doc.data() != null) {
        final verifiedShop = XeroxShopModel.fromMap(doc.data()!, doc.id);
        if (mounted) {
          setState(() {
            _selectedShop = verifiedShop;
          });
        }
      }
    } catch (e) {
      debugPrint("Error double-verifying shop pricing: $e");
    }

    // 3. Guarantee at least a 1-second delay for smooth transitions
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // 4. Pop the loading dialog
    navigator.pop();

    // 5. Open the Upload Bottom Sheet directly (User confirmed offline status during selection)
    _showUploadBottomSheet(this.context, _selectedShop!);
  }

  // ─── Sub-views for Inline Switching ──────────────────────────────────────────
  Widget _buildConfigurationView() {
    return Stack(
      key: const ValueKey('config_view'),
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Information Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.serviceName,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Starts from ',
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            widget.startingPrice > 0 ? '₹${widget.startingPrice.toStringAsFixed(0)}' : 'Unavailable',
                            style: GoogleFonts.inter(
                              fontSize: 20, 
                              fontWeight: FontWeight.w900, 
                              color: widget.startingPrice > 0 ? AppColors.primaryBlue : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Select Paper Size Section Card (hidden when 1 or 0 sizes available)
                if (_paperSizes.length > 1)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final isPhoto = widget.serviceName.toLowerCase().contains('passport') ||
                                          _paperSizes.any((s) => s.toLowerCase().contains('photo'));
                          final title = isPhoto ? 'Select Photo Quantity' : 'Select Paper Size';
                          final subtitle = isPhoto
                              ? 'Choose how many passport size photos you need'
                              : 'Choose the sheet standard formatting for your printouts';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Selectable cards layout
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _paperSizes.length,
                        separatorBuilder: (_, _b) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final size = _paperSizes[index];
                          final isSelected = _selectedSize == size;
                          final dimensions = _getDimensions(size);
                          final inches = _getInches(size);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSize = size;
                              });
                              _loadAvailableShops();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryBlue : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: isSelected 
                                    ? AppColors.primaryBlue.withValues(alpha: 0.03) 
                                    : Colors.white,
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.primaryBlue : AppColors.textTertiary,
                                        width: 2,
                                      ),
                                      color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          size,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$dimensions  •  $inches',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Print Specifications',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final isPhoto = widget.serviceName.toLowerCase().contains('passport') || widget.serviceId.contains('yPiaqNqbvhABcunanu5X');
                          return Column(
                            children: [
                              _specRow(Icons.description_outlined, isPhoto ? 'Selected Package' : 'Selected Size', _selectedSize),
                              _specRow(Icons.aspect_ratio_outlined, isPhoto ? 'Package Pricing' : 'Dimensions', _getDimensions(_selectedSize)),
                              _specRow(Icons.square_foot_outlined, isPhoto ? 'Photo Size' : 'Inches', _getInches(_selectedSize)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Sticky Bottom Continue Button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedSize.isEmpty
                    ? null
                    : () {
                        _setViewIndex(1);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (context) {
                        final isPhoto = widget.serviceName.toLowerCase().contains('passport') || widget.serviceId.contains('yPiaqNqbvhABcunanu5X');
                        final label = widget.actionButtonLabel ?? (isPhoto ? 'Continue to Select Shop' : 'Continue');
                        return Text(
                          label,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShopCard(BuildContext context, XeroxShopModel shop) {
    final pricing = XeroxPricing.fromShopData({
      'zikrinterServices': shop.zikrinterServices,
      'pricePerBWPage': shop.pricePerBWPage,
      'pricePerColorPage': shop.pricePerColorPage,
    }, widget.globalParams, serviceId: widget.serviceId);
    
    final sizeKey = _selectedSize.toLowerCase();
    final double bwPrice = pricing.normalBwPrices[sizeKey] ?? 2.0;
    final double colorPrice = pricing.normalColorPrices[sizeKey] ?? 10.0;
    final double bulkBwPrice = pricing.bulkBwPrices[sizeKey] ?? 1.5;
    final int bulkStart = pricing.bwBulkStartPages[sizeKey] ?? 10;
    final bool isOnline = shop.isOpen;

    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue.withValues(alpha: 0.1), AppColors.primaryBlue.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.store_rounded, color: AppColors.primaryBlue, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              shop.name,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlack,
                              ),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOnline ? 'Online' : 'Offline',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shop.address,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Pricing Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.background.withValues(alpha: 0.4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bwPrice > 0 ? 'B/W: ₹${bwPrice.toStringAsFixed(0)}' : 'B/W: Unavailable',
                    style: GoogleFonts.inter(
                      fontSize: 11, 
                      fontWeight: FontWeight.w700, 
                      color: bwPrice > 0 ? AppColors.textPrimary : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    colorPrice > 0 ? 'Color: ₹${colorPrice.toStringAsFixed(0)}' : 'Color: Unavailable',
                    style: GoogleFonts.inter(
                      fontSize: 11, 
                      fontWeight: FontWeight.w700, 
                      color: colorPrice > 0 ? AppColors.textPrimary : AppColors.error,
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${shop.openingTime ?? "09:00 AM"} - ${shop.closingTime ?? "09:00 PM"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('SELECT SHOP'),
                    onPressed: () {
                      final isOnline = shop.isOpen;
                      if (isOnline) {
                        _confirmAndSelectShop(shop);
                      } else {
                        _showOfflineConfirmationDialog(context, shop);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndSelectShop(XeroxShopModel shop) {
    setState(() {
      _selectedShop = shop;
    });
    _startListeningToSelectedShop(shop.id);
    _setViewIndex(2);
  }

  void _showOfflineConfirmationDialog(BuildContext context, XeroxShopModel shop) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Shop is currently offline",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            "This shop is currently offline. You can still place your order now, but the shop will start processing it when they come back online. Do you want to continue?",
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Choose Another Shop",
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _confirmAndSelectShop(shop);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                "Continue Anyway",
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceUploadView() {
    if (_selectedShop == null) return const SizedBox();

    double? toDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final zikrinterServices = _selectedShop!.zikrinterServices;
    final isProjectBinding = widget.serviceId.toLowerCase().contains('project') == true;

    Map<String, dynamic> config;
    String lookupSizeKey = _selectedSize.toLowerCase();

    if (isProjectBinding) {
      final isBond = lookupSizeKey.contains('bond');
      final targetServiceId = isBond ? 'nyAKL7mMnGGkTx2Ow9HA' : 'ZHwQd18Vy08TZkyBFXjB';
      config = zikrinterServices[targetServiceId] as Map<String, dynamic>? ?? {};
      if (isBond) {
        lookupSizeKey = 'a4';
      }
    } else {
      config = zikrinterServices[widget.serviceId] as Map<String, dynamic>? ?? {};
    }

    final sizeKey = lookupSizeKey;
    
    double bwSingle = 0.0;
    double bwDouble = 0.0;
    double bwBulk = 0.0;
    double bwDoubleBulk = 0.0;
    double colorSingle = 0.0;
    double colorDouble = 0.0;
    double colorBulk = 0.0;
    double colorDoubleBulk = 0.0;
    
    final sizeConfig = config['paperSizes']?[sizeKey];
    if (sizeConfig != null) {
      bwSingle = toDouble(sizeConfig['bw']?['singleSidePrice']) ?? 0.0;
      bwDouble = toDouble(sizeConfig['bw']?['doubleSidePrice']) ?? 0.0;
      bwBulk = toDouble(sizeConfig['bw']?['bulkPrintingPrice']) ?? 0.0;
      bwDoubleBulk = toDouble(sizeConfig['bw']?['doubleBulkPrintingPrice'] ?? sizeConfig['bw']?['double_bulkPrintingPrice']) ?? 0.0;
      
      colorSingle = toDouble(sizeConfig['color']?['singleSidePrice']) ?? 0.0;
      colorDouble = toDouble(sizeConfig['color']?['doubleSidePrice']) ?? 0.0;
      colorBulk = toDouble(sizeConfig['color']?['bulkPrintingPrice']) ?? 0.0;
      colorDoubleBulk = toDouble(sizeConfig['color']?['doubleBulkPrintingPrice'] ?? sizeConfig['color']?['double_bulkPrintingPrice']) ?? 0.0;
    } else {
      bwSingle = toDouble(config['${sizeKey}_bw_singleSidePrice']) ?? 0.0;
      bwDouble = toDouble(config['${sizeKey}_bw_doubleSidePrice']) ?? 0.0;
      bwBulk = toDouble(config['${sizeKey}_bw_bulkPrintingPrice']) ?? 0.0;
      bwDoubleBulk = toDouble(config['${sizeKey}_bw_double_bulkPrintingPrice']) ?? 0.0;
      
      colorSingle = toDouble(config['${sizeKey}_color_singleSidePrice']) ?? 0.0;
      colorDouble = toDouble(config['${sizeKey}_color_doubleSidePrice']) ?? 0.0;
      colorBulk = toDouble(config['${sizeKey}_color_bulkPrintingPrice']) ?? 0.0;
      colorDoubleBulk = toDouble(config['${sizeKey}_color_double_bulkPrintingPrice']) ?? 0.0;
      
      if (sizeKey == 'a4') {
        bwSingle = toDouble(config['bw_singleSidePrice']) ?? bwSingle;
        bwDouble = toDouble(config['bw_doubleSidePrice']) ?? bwDouble;
        bwBulk = toDouble(config['bw_bulkPrintingPrice']) ?? bwBulk;
        bwDoubleBulk = toDouble(config['bw_double_bulkPrintingPrice']) ?? toDouble(config['double_bulkPrintingPrice']) ?? bwDoubleBulk;
        
        colorSingle = toDouble(config['color_singleSidePrice']) ?? toDouble(config['singleSidePrice']) ?? colorSingle;
        colorDouble = toDouble(config['color_doubleSidePrice']) ?? toDouble(config['doubleSidePrice']) ?? colorDouble;
        colorBulk = toDouble(config['color_bulkPrintingPrice']) ?? toDouble(config['bulkPrintingPrice']) ?? colorBulk;
        colorDoubleBulk = toDouble(config['color_double_bulkPrintingPrice']) ?? colorDoubleBulk;
      }
    }

    return Stack(
      key: const ValueKey('upload_view'),
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Info Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.serviceName,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Selected Shop: ',
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          Expanded(
                            child: Text(
                              _selectedShop!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pricing Details Card (Replaced with Photo Upload Rules for Passport Photos)
                if (widget.serviceName.toLowerCase().contains('passport') || widget.serviceId.contains('yPiaqNqbvhABcunanu5X'))
                  _buildPassportRulesCard()
                else
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pricing Details (${_selectedSize.toUpperCase()})',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 16),
                        _pricingRow('Black & White (Single Side)', bwSingle),
                        _pricingRow('Black & White (Double Side)', bwDouble),
                        _pricingRow('Black & White (Bulk Rate)', bwBulk),
                        _pricingRow('Black & White (Double Side Bulk)', bwDoubleBulk),
                        const Divider(height: 24),
                        _pricingRow('Color (Single Side)', colorSingle),
                        _pricingRow('Color (Double Side)', colorDouble),
                        _pricingRow('Color (Bulk Rate)', colorBulk),
                        _pricingRow('Color (Double Side Bulk)', colorDoubleBulk),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Sticky Bottom Upload Button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                label: Text(
                  'Upload Files',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _handleUploadFilesClick(context, _selectedShop!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _specRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, double price) {
    final bool isAvailable = price > 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 13, 
                color: isAvailable ? AppColors.textSecondary : AppColors.textTertiary, 
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            isAvailable ? '₹${price.toStringAsFixed(1)}' : 'Unavailable',
            style: GoogleFonts.inter(
              fontSize: 14, 
              fontWeight: FontWeight.bold, 
              color: isAvailable ? AppColors.textPrimary : AppColors.error.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allImages = <String>[];
    if (widget.imageUrl.isNotEmpty) allImages.add(widget.imageUrl);
    for (final img in widget.images) {
      if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
    }

    if (_currentViewIndex == 1) {
      // 🔄 Use scrollable RefreshIndicator with CustomScrollView for shops selection view
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadAvailableShops();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header Image Sliver
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                        child: ServiceImageCarousel(images: allImages, serviceId: widget.serviceId),
                      ),
                      Positioned(
                        top: 12,
                        left: 20,
                        child: GestureDetector(
                          onTap: () {
                            _setViewIndex(0);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Shops List Sliver
                if (_isLoadingShops)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
                    ),
                  )
                else if (_shopsForSelectedSize.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.storefront_rounded, size: 64, color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              'No shops support ${_selectedSize.toUpperCase()} for this service.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Shop',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryBlack,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose an online shop to submit your Xerox order',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final shopMap = _shopsForSelectedSize[index];
                          final shop = XeroxShopModel.fromMap(shopMap, shopMap['id']);
                          return _buildShopCard(context, shop);
                        },
                        childCount: _shopsForSelectedSize.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // For View Index 0 and 2, render the static layout
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Header Image and Dynamic back navigation
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  child: ServiceImageCarousel(images: allImages, serviceId: widget.serviceId),
                ),
                Positioned(
                  top: 12,
                  left: 20,
                  child: GestureDetector(
                    onTap: () {
                      if (_currentViewIndex > 0) {
                        _setViewIndex(_currentViewIndex - 1);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            
            // Dynamic sliding body
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final isForward = _currentViewIndex >= _prevViewIndex;
                  final beginOffset = isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
                  final offsetAnimation = Tween<Offset>(
                    begin: beginOffset,
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
                child: _currentViewIndex == 2
                    ? _buildServiceUploadView()
                    : _buildConfigurationView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassportRulesCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Soft light blue tint
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rule_folder_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photo Upload Rules',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Please follow these guidelines for file uploading:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFDBEAFE)),
          const SizedBox(height: 16),
          _buildRuleRow(Icons.crop_portrait_rounded, 'Orientation', 'Portrait'),
          _buildRuleRow(Icons.aspect_ratio_rounded, 'Aspect ratio', '3:4 (Auto-fit & Edit option)'),
          _buildRuleRow(Icons.color_lens_outlined, 'Background', 'Plain white/light background'),
          _buildRuleRow(Icons.face_retouching_natural_rounded, 'Face', 'Clearly visible and centered'),
          _buildRuleRow(Icons.high_quality_outlined, 'Photo quality', 'Clear, not blurry'),
        ],
      ),
    );
  }

  Widget _buildRuleRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: value, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
