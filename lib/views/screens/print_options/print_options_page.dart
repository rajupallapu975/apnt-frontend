import 'dart:io';
import 'dart:convert';
import 'package:apnt/utils/file_validator.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../payment_processing_page.dart';
import '../widgets/payment_summary_sheet.dart';
import 'binding_selection_page.dart';
import '../../../models/print_order_model.dart';
import '../../../models/file_model.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/modern_card.dart';
import 'widgets/print_preview_carousel.dart';
import '../../../services/backend_service.dart';
import '../../../services/image_processing_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../../utils/order_utils.dart';
import '../../../services/firestore_service.dart';
import '../../../services/pricing_service.dart';
import 'package:http/http.dart' as http;
import '../../../config/backend_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config model
// ─────────────────────────────────────────────────────────────────────────────
class PagePrintConfig {
  bool isPortrait;
  bool isColor;
  bool isDoubleSided;
  int copies;
  int pageCount;

  PagePrintConfig({
    this.isPortrait = true,
    this.isColor = false,
    this.isDoubleSided = false,
    this.copies = 1,
    this.pageCount = 1,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PrintOptionsPage
// ─────────────────────────────────────────────────────────────────────────────
class PrintOptionsPage extends StatefulWidget {
  final List<FileModel> pickedFiles;
  final PrintMode printMode;
  final String? shopId;
  final String? shopName;
  final String? shopPhone;
  final String? serviceId;
  final String? serviceName;
  final String? selectedPaperSize;
  
  const PrintOptionsPage({
    super.key, 
    required this.pickedFiles, 
    required this.printMode,
    this.shopId,
    this.shopName,
    this.shopPhone,
    this.serviceId,
    this.serviceName,
    this.selectedPaperSize,
  });

  @override
  State<PrintOptionsPage> createState() => _PrintOptionsPageState();
}

class _PrintOptionsPageState extends State<PrintOptionsPage> {
  int _currentPageIndex = 0;
  final PageController _pageController = PageController();

  late List<FileModel> pickedFiles;
  late List<PagePrintConfig> pageConfigs;
  late List<Uint8List?> _thumbnails;
  bool _isLoading = false;
  bool _isInitializing = true;

  PagePrintConfig get _current => pageConfigs[_currentPageIndex];

  int get _totalPages {
    int t = 0;
    for (final p in pageConfigs) {
      t += p.pageCount * p.copies;
    }
    return t;
  }

  Map<String, dynamic>? shopData;
  Map<String, dynamic>? globalServiceParams;
  String commissionType = 'percentage';
  double commissionValue = 0.0;
  List<dynamic> _allShopServices = [];

  bool _isCustomService = false;
  List<Map<String, dynamic>> _customParameters = [];
  Map<String, dynamic> _customValues = {};
  List<String> _supportedPaperSizes = ['A4'];
  String _selectedPaperSize = 'A4';

  PricingCalculationResult get _pricingResult {
    return PricingService.calculate(
      fileConfigs: pageConfigs.map((c) => {
        'pageCount': c.pageCount,
        'copies': c.copies,
        'isColor': c.isColor,
        'isDoubleSided': c.isDoubleSided,
        'paperSize': _selectedPaperSize,
      }).toList(),
      shopData: shopData ?? {},
      globalServiceParams: globalServiceParams,
      commissionType: commissionType,
      commissionValue: commissionValue,
      serviceId: widget.serviceId,
      allShopServices: _allShopServices,
    );
  }

  XeroxPricing _getResolvedPricing() {
    final isProjectBinding = widget.serviceId?.toLowerCase().contains('project') == true ||
        (globalServiceParams != null && globalServiceParams?['serviceType'] == 'project_binding');

    if (isProjectBinding) {
      final isBond = _selectedPaperSize.toLowerCase().contains('bond');
      final targetServiceId = isBond ? 'nyAKL7mMnGGkTx2Ow9HA' : 'ZHwQd18Vy08TZkyBFXjB';
      Map<String, dynamic>? targetGlobalParams;
      if (_allShopServices.isNotEmpty) {
        final serviceDoc = _allShopServices.firstWhere(
          (s) => s['id'] == targetServiceId,
          orElse: () => null,
        );
        if (serviceDoc != null) {
          targetGlobalParams = serviceDoc['parameters'] as Map<String, dynamic>?;
        }
      }
      return XeroxPricing.fromShopData(shopData ?? {}, targetGlobalParams, serviceId: targetServiceId);
    }
    return XeroxPricing.fromShopData(shopData ?? {}, globalServiceParams, serviceId: widget.serviceId);
  }

  String _getResolvedSizeKey() {
    final isBond = _selectedPaperSize.toLowerCase().contains('bond');
    return isBond ? 'a4' : _selectedPaperSize.toLowerCase();
  }

  double get _totalPrice => _pricingResult.shopSubtotal;
  double get _totalCommission => _pricingResult.commissionAmount;
  double get _payablePrice => _pricingResult.finalAmount;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    pickedFiles = List.from(widget.pickedFiles);
    _thumbnails = List.generate(pickedFiles.length, (i) => pickedFiles[i].bytes);
    pageConfigs = List.generate(pickedFiles.length, (i) {
      final model = pickedFiles[i];
      return PagePrintConfig(pageCount: model.pageCount ?? 1);
    });
    _initData();
  }

  Future<void> _initData() async {
    try {
      // 1. Fetch shop pricing first
      await _loadShopPricing();

      // 2. Fetch all PDF metadata concurrently
      final List<Future<void>> pdfFutures = [];
      for (int i = 0; i < pickedFiles.length; i++) {
        final model = pickedFiles[i];
        final fileName = model.name.toLowerCase();
        if (fileName.endsWith('.pdf') && model.pageCount == null) {
          pdfFutures.add(_loadPdfMetadata(i, model));
        }
      }
      if (pdfFutures.isNotEmpty) {
        await Future.wait(pdfFutures);
      }
    } catch (e) {
      debugPrint("Error initializing print options: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _loadShopPricing() async {
    if (widget.shopId == null) return;
    try {
      final response = await http.get(Uri.parse('${BackendConfig.baseUrl}/api/shop/services?shopId=${widget.shopId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final shop = data['shop'] as Map<String, dynamic>? ?? {};
          final services = data['services'] as List<dynamic>? ?? [];
          
          final String targetServiceId = widget.serviceId ?? 'ZHwQd18Vy08TZkyBFXjB';
          final service = services.firstWhere((s) => s['id'] == targetServiceId, orElse: () => null);

          if (service != null) {
            final params = service['parameters'] as Map<String, dynamic>? ?? {};

            String type = service['commissionType'] ?? 'percentage';
            double val = (service['commissionValue'] ?? 0.0).toDouble();

            if (service['commissionValue'] == null) {
              final colorSingle = params['color_singleSide'] ?? params['singleSide'] ?? {};
              final bwSingle = params['bw_singleSide'] ?? {};
              
              type = colorSingle['commissionType'] ?? bwSingle['commissionType'] ?? type;
              val = (colorSingle['commission'] ?? bwSingle['commission'] ?? val).toDouble();
            }

            final bool isCustom = targetServiceId != 'ZHwQd18Vy08TZkyBFXjB';
            final rawCustom = service['customParameters'] as List<dynamic>? ?? [];
            final List<Map<String, dynamic>> customParams = rawCustom.map((item) => Map<String, dynamic>.from(item as Map)).toList();
            customParams.sort((a, b) => (a['displayOrder'] as num? ?? 0).compareTo(b['displayOrder'] as num? ?? 0));

            final Map<String, dynamic> initialValues = {};
            for (final cp in customParams) {
              final String name = cp['name'] ?? '';
              final String defVal = cp['defaultValue'] ?? '';
              final String inputType = cp['inputType'] ?? '';
              if (name.isNotEmpty) {
                if (inputType == 'switch') {
                  initialValues[name] = (defVal.toLowerCase() == 'true' || defVal == '1');
                } else if (inputType == 'counter') {
                  initialValues[name] = int.tryParse(defVal) ?? 1;
                } else if (inputType == 'checkbox') {
                  initialValues[name] = <String>[];
                } else {
                  initialValues[name] = defVal;
                }
              }
            }

            final List<dynamic> rawSizes = service['paperSizes'] as List<dynamic>? ?? [];
            final List<String> pSizes = rawSizes.isNotEmpty 
                ? List<String>.from(rawSizes) 
                : ['A4'];
            
            if (widget.selectedPaperSize != null && !pSizes.any((s) => s.toLowerCase() == widget.selectedPaperSize!.toLowerCase())) {
              pSizes.add(widget.selectedPaperSize!);
            }

             setState(() {
              shopData = shop;
              _allShopServices = services;
              globalServiceParams = params;
              commissionType = type;
              commissionValue = val;
              _isCustomService = isCustom;
              _customParameters = customParams;
              _customValues = initialValues;
              _supportedPaperSizes = pSizes;
              _selectedPaperSize = widget.selectedPaperSize != null && pSizes.any((s) => s.toLowerCase() == widget.selectedPaperSize!.toLowerCase())
                  ? pSizes.firstWhere((s) => s.toLowerCase() == widget.selectedPaperSize!.toLowerCase())
                  : (pSizes.contains('A4') ? 'A4' : pSizes.first);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading shop pricing from backend: $e");
    }
  }

  Future<void> _loadPdfMetadata(int index, FileModel model) async {
    try {
      Uint8List? data = model.bytes;
      if (data == null && !kIsWeb && model.file != null) {
        data = await model.file!.readAsBytes();
      }
      if (data != null) {
        final doc = await PdfDocument.openData(Uint8List.fromList(data));
        final count = doc.pagesCount;
        
        // 🖼️ RENDER FIRST PAGE FOR PREVIEW
        final page = await doc.getPage(1);
        final pageImage = await page.render(
          width: page.width * 1.5,
          height: page.height * 1.5,
          format: PdfPageImageFormat.jpeg,
          quality: 70,
        );
        await page.close();
        await doc.close();

        if (mounted) {
          setState(() {
            pageConfigs[index].pageCount = count;
            if (pageImage != null) {
              _thumbnails[index] = pageImage.bytes;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('PDF metadata/preview load error: $e');
    }
  }

  // ── Back confirmation ──────────────────────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Dismiss Preview Pages',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to discard the changes?',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Yes', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _getDimensions(bool isPortrait) {
    const Map<String, List<double>> sizeMap = {
      'A4': [8.3, 11.7],
      'A3': [11.7, 16.5],
      'A2': [16.5, 23.4],
      'A1': [23.4, 33.1],
      'LEGAL': [8.5, 14.0],
      'LETTER': [8.5, 11.0],
      'A5': [5.8, 8.3],
    };

    final size = _selectedPaperSize.toUpperCase();
    final dims = sizeMap[size] ?? [8.3, 11.7]; // default A4

    if (isPortrait) {
      return '${dims[0]} x ${dims[1]} in';
    } else {
      return '${dims[1]} x ${dims[0]} in';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isInitializing || pageConfigs.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryBlue),
              const SizedBox(height: 16),
              Text(
                'LOADING PRINT OPTIONS...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(isWide),
                    Expanded(
                      child: isWide ? _buildWideBody() : _buildMobileBody(),
                    ),
                    if (!isWide) _buildMobileBottomBar(),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primaryBlue),
                    const SizedBox(height: 16),
                    Text(
                      'PROCESSING DOCUMENTS...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isWide) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Circle back button
          GestureDetector(
            onTap: () async {
              final confirmed = await _confirmDiscard();
              if (confirmed && mounted) Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
                color: Colors.white,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textPrimary),
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 16),
            Text('Print Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
          ],
          const Spacer(),
          // Add files outlined pill
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Add files',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: _addMoreFiles,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wide body (≥800px) ─────────────────────────────────────────────────────
  Widget _buildWideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left 3/5: preview + settings
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 28, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilePreviewCard(wide: true),
                const SizedBox(height: 24),
                _buildSettingsCard(),
              ],
            ),
          ),
        ),
        // Right 2/5: payment summary
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 28, 32, 48),
            child: Column(
              children: [
                _buildPaymentSummaryCard(),
                const SizedBox(height: 16),
                _buildPricingGuide(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile body ────────────────────────────────────────────────────────────
  Widget _buildMobileBody() {
    final cfg = _current;
    final pricing = _getResolvedPricing();
    final divider = Divider(height: 1, thickness: 1, color: AppColors.border.withValues(alpha: 0.4), indent: 24, endIndent: 24);

    final String sizeKey = _getResolvedSizeKey();
    final double currentBwPrice = pricing.normalBwPrices[sizeKey] ?? pricing.normalBwPrices['a4'] ?? 2.0;
    final double currentColorPrice = pricing.normalColorPrices[sizeKey] ?? pricing.normalColorPrices['a4'] ?? 10.0;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview card (white, prominent)
          _buildFilePreviewCard(wide: false),

          // Copies — flat section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Number of copies',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF2D3142))),
                      const SizedBox(height: 4),
                      Text(
                        'File ${_currentPageIndex + 1} (${cfg.pageCount} ${cfg.pageCount == 1 ? 'page' : 'pages'})',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                _pillStepper(cfg),
              ],
            ),
          ),

          divider,

          // Color mode — Blinkit-style circular indicators
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose print color',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF2D3142))),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _mobileColorTile(
                      colorIndicator: _colorCircle(),
                      label: 'Coloured',
                      price: '₹${currentColorPrice.toStringAsFixed(0)}/page',
                      selected: cfg.isColor,
                      onTap: () => setState(() => cfg.isColor = true),
                    ),
                    const SizedBox(width: 12),
                    _mobileColorTile(
                      colorIndicator: _bwCircle(),
                      label: 'B & W',
                      price: '₹${currentBwPrice.toStringAsFixed(0)}/page',
                      selected: !cfg.isColor,
                      onTap: () => setState(() => cfg.isColor = false),
                    ),
                  ],
                ),
              ],
            ),
          ),

          divider,

          // Orientation
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose print orientation',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF2D3142))),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _mobileOrientationTile(
                      icon: Icons.stay_current_portrait_rounded,
                      label: 'Portrait',
                      sublabel: _getDimensions(true),
                      selected: cfg.isPortrait,
                      onTap: () => setState(() => cfg.isPortrait = true),
                    ),
                    const SizedBox(width: 12),
                    _mobileOrientationTile(
                      icon: Icons.stay_current_landscape_rounded,
                      label: 'Landscape',
                      sublabel: _getDimensions(false),
                      selected: !cfg.isPortrait,
                      onTap: () => setState(() => cfg.isPortrait = false),
                    ),
                  ],
                ),
              ],
            ),
          ),

          divider,

          // Paper Size
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choosed paper size',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF2D3142))),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedPaperSize.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (cfg.pageCount >= 2)
            Column(
              children: [
                divider,
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Double sided print',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF2D3142))),
                          Text('Print on both sides of paper',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                      Switch.adaptive(
                        value: cfg.isDoubleSided,
                        activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (v) => setState(() => cfg.isDoubleSided = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (_isCustomService)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildCustomParametersSection(),
            ),

          // Proper bottom spacing before the bottom bar
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ── File preview card ──────────────────────────────────────────────────────

  String _formatFileSize(FileModel model) {
    int bytes = model.bytes?.length ?? 0;
    if (bytes == 0 && !kIsWeb && model.file != null) {
      try { bytes = model.file!.lengthSync(); } catch (_) {}
    }
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildFilePreviewCard({required bool wide}) {
    final file = pickedFiles[_currentPageIndex];
    final cfg = _current;
    final ext = file.name.toLowerCase().split('.').last;
    final isPdf = ext == 'pdf';
    final isDoc = ext == 'doc' || ext == 'docx';

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // File name row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPdf
                        ? const Color(0xFFFFF3E0)
                        : isDoc
                            ? AppColors.primaryBlue.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPdf
                        ? Icons.description_outlined
                        : isDoc
                            ? Icons.article_rounded
                            : Icons.image_rounded,
                    color: isPdf
                        ? const Color(0xFFE65100)
                        : isDoc
                            ? AppColors.primaryBlue
                            : AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file.name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          // File size chip
                          if (_formatFileSize(file).isNotEmpty)
                            _infoChip(
                              icon: Icons.cloud_upload_outlined,
                              label: _formatFileSize(file),
                              color: AppColors.primaryBlue,
                            ),
                          // Page count chip
                          _infoChip(
                            icon: Icons.description_outlined,
                            label: '${cfg.pageCount} ${cfg.pageCount == 1 ? 'page' : 'pages'}',
                            color: AppColors.textSecondary,
                          ),
                          // Multi-file indicator
                          if (pickedFiles.length > 1)
                            _infoChip(
                              icon: Icons.folder_outlined,
                              label: 'File ${_currentPageIndex + 1}/${pickedFiles.length}',
                              color: AppColors.textSecondary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _removeFile(_currentPageIndex),
                ),
              ],
            ),
          ),

          // Preview
          SizedBox(
            height: wide ? 320 : 280,
            child: PrintPreviewCarousel(
              controller: _pageController,
              fileNames: pickedFiles.map((e) => e.name).toList(),
              files: pickedFiles.map((e) => e.file).toList(),
              bytes: _thumbnails,
              isPortraitList: pageConfigs.map((e) => e.isPortrait).toList(),
              isColorList: pageConfigs.map((e) => e.isColor).toList(),
              onPageChanged: (i) => setState(() => _currentPageIndex = i),
              onEdit: _handleEditOrOpen,
              onRemove: _removeFile,
              paperSize: _selectedPaperSize,
            ),
          ),
        ],
      ),
    );
  }

  // ── Web: Settings card ─────────────────────────────────────────────────────
  Widget _buildSettingsCard() {
    final cfg = _current;
    final pricing = _getResolvedPricing();

    final String sizeKey = _getResolvedSizeKey();
    final double currentBwPrice = pricing.normalBwPrices[sizeKey] ?? pricing.normalBwPrices['a4'] ?? 2.0;
    final double currentColorPrice = pricing.normalColorPrices[sizeKey] ?? pricing.normalColorPrices['a4'] ?? 10.0;

    return ModernCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_rounded, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text('Print Settings',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 24),

          // Number of Copies
          _webSettingLabel('Number of Copies'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'File ${_currentPageIndex + 1} (${cfg.pageCount} ${cfg.pageCount == 1 ? 'page' : 'pages'})',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              _webCountControl(cfg),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 24),

          // Color Mode — Blinkit-style circular indicators
          _webSettingLabel('Color Mode'),
          const SizedBox(height: 12),
          Row(
            children: [
              _webColorTile('Black & White', '₹${currentBwPrice.toStringAsFixed(0)}/page', !cfg.isColor, _bwCircle(), () => setState(() => cfg.isColor = false)),
              const SizedBox(width: 12),
              _webColorTile('Color', '₹${currentColorPrice.toStringAsFixed(0)}/page', cfg.isColor, _colorCircle(), () => setState(() => cfg.isColor = true)),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 24),

          // Orientation
          _webSettingLabel('Orientation'),
          const SizedBox(height: 12),
          Row(
            children: [
              _webTile('Portrait', _getDimensions(true), cfg.isPortrait, () => setState(() => cfg.isPortrait = true)),
              const SizedBox(width: 12),
              _webTile('Landscape', _getDimensions(false), !cfg.isPortrait, () => setState(() => cfg.isPortrait = false)),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 24),

          _webSettingLabel('Choosed paper size'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _selectedPaperSize.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (cfg.pageCount >= 2) ...[
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 24),
            _webSettingLabel('Double Sided'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Print on both sides of paper',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                Switch.adaptive(
                  value: cfg.isDoubleSided,
                  activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
                  activeThumbColor: AppColors.primaryBlue,
                  onChanged: (v) => setState(() => cfg.isDoubleSided = v),
                ),
              ],
            ),
          ],
          if (_isCustomService) _buildCustomParametersSection(),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 300.ms);
  }

  Widget _buildPaymentSummaryCard() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text('Order Summary',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 20),

          // Print Mode Info Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.printMode == PrintMode.autonomous 
                  ? AppColors.primaryBlue.withValues(alpha: 0.04)
                  : AppColors.success.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (widget.printMode == PrintMode.autonomous 
                    ? AppColors.primaryBlue 
                    : AppColors.success).withValues(alpha: 0.1)
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.printMode == PrintMode.autonomous 
                      ? Icons.smart_toy_rounded 
                      : Icons.store_rounded,
                  color: widget.printMode == PrintMode.autonomous 
                      ? AppColors.primaryBlue 
                      : AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRINT MODE',
                        style: GoogleFonts.inter(
                          fontSize: 9, 
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTertiary, 
                          letterSpacing: 1.2
                        ),
                      ),
                      Text(
                        widget.printMode == PrintMode.autonomous ? 'Autonomous' : 'Xerox Shop',
                        style: GoogleFonts.inter(
                          fontSize: 14, 
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (widget.shopName != null) ...[
            _summaryLine('Selected Shop', widget.shopName!),
            const SizedBox(height: 8),
          ],
          
          _summaryLine('Total Pages', '$_totalPages ${_totalPages == 1 ? 'page' : 'pages'}'),

          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Price', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17)),
              Text('₹${_payablePrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 26, color: AppColors.primaryBlue)),
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _handlePayment(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.print_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Pay ₹${_payablePrice.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
            ),
          ),

          const SizedBox(height: 16),
          _trustRow(Icons.lock_outline_rounded, 'Secure payment'),
          const SizedBox(height: 7),
          _trustRow(Icons.bolt_rounded, 'Instant processing'),
          const SizedBox(height: 7),
          _trustRow(Icons.confirmation_num_outlined, 'Pickup code will be generated after payment'),
        ],
      ),
    );
  }

  Widget _buildPricingGuide() {
    final pricing = _getResolvedPricing();
    final String sizeKey = _getResolvedSizeKey();
    final double currentBwPrice = pricing.normalBwPrices[sizeKey] ?? pricing.normalBwPrices['a4'] ?? 2.0;
    final double currentDoubleBwPrice = pricing.doubleBwPrices[sizeKey] ?? pricing.doubleBwPrices['a4'] ?? 4.0;
    final double currentColorPrice = pricing.normalColorPrices[sizeKey] ?? pricing.normalColorPrices['a4'] ?? 10.0;

    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, size: 14, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text('Pricing Guide',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _priceGuideRow('B&W Print', '₹${currentBwPrice.toStringAsFixed(1)}/page'),
          _priceGuideRow('Double Sided', '₹${currentDoubleBwPrice.toStringAsFixed(1)}/sheet'),
          _priceGuideRow('Color Print', '₹${currentColorPrice.toStringAsFixed(1)}/page'),
        ],
      ),
    );
  }

  // ── Mobile bottom bar ──────────────────────────────────────────────────────
  Widget _buildMobileBottomBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 1, color: AppColors.border.withValues(alpha: 0.4)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total $_totalPages ${_totalPages == 1 ? 'page' : 'pages'}',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('₹$_totalPrice',
                        style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w900, color: const Color(0xFF2D3142))),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: () {
                    final isProjectBinding = widget.serviceId?.toLowerCase().contains('project') == true ||
                        widget.serviceName?.toLowerCase().contains('project') == true ||
                        (globalServiceParams != null && globalServiceParams?['serviceType'] == 'project_binding');
                    
                    if (isProjectBinding) {
                      return ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BindingSelectionPage(
                                pickedFiles: pickedFiles,
                                pageConfigs: pageConfigs,
                                shopId: widget.shopId ?? '',
                                shopName: widget.shopName ?? '',
                                shopPhone: widget.shopPhone ?? '',
                                serviceId: widget.serviceId ?? '',
                                serviceName: widget.serviceName ?? '',
                                selectedPaperSize: _selectedPaperSize,
                                shopData: shopData ?? {},
                                globalServiceParams: globalServiceParams ?? {},
                                printingCost: _totalPrice,
                                printingCommission: _totalCommission,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Continue',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      );
                    }

                    return ElevatedButton(
                      onPressed: _isLoading ? null : () => _handlePayment(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            width: 24, 
                            height: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.print_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text('Pay ₹${_totalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                    );
                  }(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mobile tile helpers ────────────────────────────────────────────────────

  /// Color tiles with Blinkit-style circular indicator on the left
  Widget _mobileColorTile({
    required Widget colorIndicator,
    required String label,
    required String price,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final selColor = AppColors.primaryBlue;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? selColor.withValues(alpha: 0.06) : Colors.white,
            border: Border.all(
              color: selected ? selColor : AppColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              colorIndicator,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selected ? selColor : AppColors.textPrimary)),
                    Text(price,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: selected ? selColor.withValues(alpha: 0.7) : AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Blinkit-style colour circles for Color print
  Widget _colorCircle() {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1),
              color: Colors.white,
            ),
          ),
          // CMYK-style arcs via small coloured circles
          // Three overlapping circles for color indicator
          Positioned(
            left: 2, top: 4,
            child: _dot(20, const Color(0xFF4285F4)), // Blue
          ),
          Positioned(
            right: 2, top: 4,
            child: _dot(20, const Color(0xFFEA4335)), // Red
          ),
          Positioned(
            bottom: 4,
            child: _dot(20, const Color(0xFFFBBC05)), // Yellow
          ),
        ],
      ),
    );
  }

  /// Dual-tone circle for B&W print
  Widget _bwCircle() {
    return SizedBox(
      width: 38,
      height: 38,
      child: CustomPaint(
        painter: _BWCirclePainter(),
      ),
    );
  }

  Widget _dot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.9),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );

  /// Web color tile: circle indicator on top, label + price below
  Widget _webColorTile(
    String label,
    String price,
    bool selected,
    Widget indicator,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              indicator,
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected ? AppColors.primaryBlue : AppColors.textPrimary)),
                  Text(price,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: selected
                              ? AppColors.primaryBlue.withValues(alpha: 0.7)
                              : AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Orientation/generic tiles (icon top, label + sublabel)
  Widget _mobileOrientationTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final selColor = AppColors.primaryBlue;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: selected ? selColor.withValues(alpha: 0.06) : Colors.white,
            border: Border.all(
              color: selected ? selColor : AppColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? selColor.withValues(alpha: 0.1) : AppColors.border.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: selected ? selColor : AppColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: selected ? selColor : const Color(0xFF2D3142))),
                    Text(sublabel,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: selected ? selColor.withValues(alpha: 0.8) : AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill-shaped copies stepper
  Widget _pillStepper(PagePrintConfig cfg) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () { if (cfg.copies > 1) setState(() => cfg.copies--); },
            child: const SizedBox(
              width: 42,
              child: Icon(Icons.remove_rounded, color: Colors.white, size: 20),
            ),
          ),
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text('${cfg.copies}',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          GestureDetector(
            onTap: () => setState(() => cfg.copies++),
            child: const SizedBox(
              width: 42,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Labelled chip for the file preview header
  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  // ── Web helpers ────────────────────────────────────────────────────────────
  Widget _webSettingLabel(String text) =>
      Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primaryBlue));

  Widget _webCountControl(PagePrintConfig cfg) {
    return Row(
      children: [
        _webCountBtn(Icons.remove_rounded, () { if (cfg.copies > 1) setState(() => cfg.copies--); }),
        SizedBox(
          width: 40,
          child: Text('${cfg.copies}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        _webCountBtn(Icons.add_rounded, () => setState(() => cfg.copies++)),
      ],
    );
  }

  Widget _webCountBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      );

  Widget _webTile(String label, String? sublabel, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected ? AppColors.primaryBlue : AppColors.textPrimary)),
              if (sublabel != null) ...[
                const SizedBox(height: 3),
                Text(sublabel,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: selected ? AppColors.primaryBlue.withValues(alpha: 0.7) : AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _trustRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      );

  Widget _priceGuideRow(String label, String price) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            Text(price,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      );

  // ── Logic ──────────────────────────────────────────────────────────────────
  Future<void> _handlePayment() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. Verify shop online status before initiating order/payment
      final isOnline = await BackendService().checkShopStatus(widget.shopId ?? '');
      if (!isOnline) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("This shop has gone offline. Please select another shop to proceed."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      int totalPg = 0;
      for (var pc in pageConfigs) {
        totalPg += pc.pageCount * pc.copies;
      }

      // 🆔 GENERATE 4-DIGIT UNIQUE CODE (ONLY FOR XEROX SHOP)
      final bool isXerox = widget.printMode == PrintMode.xeroxShop;
      final String xeroxCode = isXerox ? OrderUtils.generateXeroxCode() : '';
      
      // Get the sequential index (1, 2, 3...) separately for Kiosk and Xerox
      final int nextIdx = await FirestoreService().getNextOrderIndex(isXerox);
      final String sequentialId = 'order_$nextIdx';
      
      // Use a secure unique ID for the order itself so it doesn't leak the pickup code in URLs
      final String secureOrderId = isXerox ? 'ORDER_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}' : '';

      final printSettings = {
        'printMode': widget.printMode.name,
        'orderId': isXerox ? secureOrderId : '', 
        'customId': sequentialId, // Store the sequential 'order_N' ID
        'xeroxCode': xeroxCode, // This is the actual pickup code
        'shopId': widget.shopId,
        'shopName': widget.shopName, // Pass the destination shop name
        'shopPhone': widget.shopPhone, // Track shop contact
        'serviceId': widget.serviceId ?? 'ZHwQd18Vy08TZkyBFXjB',
        'serviceName': widget.serviceName ?? 'Documents (Xerox)',
        'customParameters': _customValues,
        'doubleSide': pageConfigs.any((c) => c.isDoubleSided),
        'files': List.generate(pageConfigs.length, (i) {
          final model = pickedFiles[i];
          final cfg = pageConfigs[i];
          return {
            'fileName': model.name,
            'pageCount': cfg.pageCount,
            'color': cfg.isColor ? 'COLOR' : 'BW',
            'orientation': cfg.isPortrait ? 'PORTRAIT' : 'LANDSCAPE',
            'copies': cfg.copies,
            'doubleSided': cfg.isDoubleSided,
            'paperSize': _selectedPaperSize,
            'fileSizeKB': (model.size / 1024).toStringAsFixed(1),
            'url': '', 
            'publicId': '',
            'price': _pricingResult.fileCosts[i],
          };
        }),
        'paperSize': _selectedPaperSize,
        'subtotal': _totalPrice,
        'commission': _totalCommission,
        'shopSubtotal': _pricingResult.shopSubtotal,
        'commissionType': _pricingResult.commissionType,
        'commissionValue': _pricingResult.commissionValue,
        'commissionAmount': _pricingResult.commissionAmount,
        'finalAmount': _pricingResult.finalAmount,
        'totalBwPages': _pricingResult.totalBwPages,
        'totalBwPagesWithCopies': _pricingResult.totalBwPagesWithCopies,
        'bwPricingMode': _pricingResult.bwPricingMode,
        'bwPricePerPage': _pricingResult.bwPricePerPage,
        'bwCost': _pricingResult.bwCost,
        'bwOriginalCost': _pricingResult.bwOriginalCost,
        'isBwBulkApplied': _pricingResult.isBwBulkApplied,
        'totalColorPages': _pricingResult.totalColorPages,
        'totalColorPagesWithCopies': _pricingResult.totalColorPagesWithCopies,
        'colorPricingMode': _pricingResult.colorPricingMode,
        'colorPricePerPage': _pricingResult.colorPricePerPage,
        'colorCost': _pricingResult.colorCost,
        'colorOriginalCost': _pricingResult.colorOriginalCost,
        'isColorBulkApplied': _pricingResult.isColorBulkApplied,
        'isBulkApplied': _pricingResult.isBulkApplied,
        'originalShopSubtotal': _pricingResult.originalShopSubtotal,
        'amountSaved': _pricingResult.amountSaved,
        'originalFinalAmount': _pricingResult.originalFinalAmount,
        'generateCoverPage': _pricingResult.generateCoverPage,
        'coverPageCharge': _pricingResult.extraPageFee,
      };

      final razorpayFuture = BackendService().createRazorpayOrder(_payablePrice.toDouble());
      
      final processingFuture = Future.wait(
        List.generate(pickedFiles.length, (i) async {
          final model = pickedFiles[i];
          final cfg = pageConfigs[i];
          Uint8List? originalBytes;
          if (model.bytes != null) {
            originalBytes = model.bytes;
          } else if (model.file != null) {
            originalBytes = await model.file!.readAsBytes();
          }
          if (originalBytes == null) return null;

          if (!model.name.toLowerCase().endsWith('.pdf') && !kIsWeb) {
            try {
              return await ImageProcessingService.processImageToA4(
                imageBytes: originalBytes,
                isPortrait: cfg.isPortrait,
              );
            } catch (e) {
              debugPrint("⚠️ Image processing failed: $e");
              return originalBytes;
            }
          }
          return originalBytes;
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PaymentSummarySheet(
          totalPages: _totalPages,
          totalPrice: _payablePrice.toDouble(),
          printSettings: printSettings,
          razorpayFuture: razorpayFuture,
          processingFuture: processingFuture,
          onProceed: (phone) async {
            try {
              // Futures are guaranteed ready because PaymentSummarySheet awaits them
              final razorpayData = await razorpayFuture;
              final finalizedBytes = await processingFuture;

              if (!mounted) return;
              if (!context.mounted) return;
              Navigator.pop(context); // Close sheet
              
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentProcessingPage(
                    selectedFiles: pickedFiles.map((e) => e.file).toList(),
                    selectedBytes: finalizedBytes,
                    filenames: pickedFiles.map((e) => e.name).toList(),
                    printSettings: printSettings,
                    expectedPages: totalPg,
                    expectedPrice: _payablePrice.toDouble(),
                    autoStartPayment: true,
                    prefillPhone: phone,
                    preCreatedOrder: razorpayData,
                  ),
                ),
              );
            } catch (e) {
              debugPrint("❌ Navigation failed: $e");
            }
          },
        ),
      );
    } catch (e) {
      debugPrint("❌ Error opening payment sheet: $e");
    }
  }

  void _removeFile(int index) {
    setState(() {
      pickedFiles.removeAt(index);
      pageConfigs.removeAt(index);
      _thumbnails.removeAt(index);
      if (pageConfigs.isEmpty) {
        Navigator.pop(context);
      } else if (_currentPageIndex >= pageConfigs.length) {
        _currentPageIndex = pageConfigs.length - 1;
      }
    });
  }

  Future<void> _handleEditOrOpen(int index) async {
    final model = pickedFiles[index];
    final isImage = ['.jpg', '.jpeg', '.png', '.bmp', '.tiff'].any((ext) => model.name.toLowerCase().endsWith(ext));
    
    if (!isImage) {
      // 📂 OPEN DOCUMENT FLOW
      if (kIsWeb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document preview is only available in the mobile app.')));
        return;
      }
      
      try {
        if (model.file != null) {
          if (!kIsWeb && Platform.isAndroid) {
            final channel = const MethodChannel('com.example.apnt/file_opener');
            await channel.invokeMethod('openFile', {
              'path': model.file!.path,
              'mimeType': null, // native will detect
            });
          } else {
            final uri = Uri.file(model.file!.path);
            if (await url_launcher.canLaunchUrl(uri)) {
              await url_launcher.launchUrl(uri);
            } else {
              await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
            }
          }
        }
      } catch (e) {
        debugPrint("Error opening file: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the document.')));
      }
      return;
    }
    
    // 🎨 IMAGE EDIT FLOW
    
    // For Web, 'path' is a Data URI from bytes. On Native, it's a file path.
    final String src = kIsWeb ? model.path : (model.file?.path ?? model.path);
    if (src.isEmpty) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: src,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Image',
          toolbarColor: AppColors.primaryBlue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Edit Image',
          aspectRatioLockEnabled: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        WebUiSettings(
          context: context,
          presentStyle: (kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS))
              ? WebPresentStyle.page 
              : WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 520),
          translations: const WebTranslations(
            title: 'Edit Image',
            rotateLeftTooltip: 'Rotate Left',
            rotateRightTooltip: 'Rotate Right',
            cropButton: 'DONE',
            cancelButton: 'CANCEL',
          ),
        ),
      ],
    );
    if (cropped == null) return;

    final bytes = await cropped.readAsBytes();
    final String webPath = kIsWeb ? "data:image/png;base64,${base64Encode(bytes)}" : cropped.path;

    setState(() {
      pickedFiles[index] = FileModel(
        id: model.id,
        name: model.name,
        path: webPath,
        file: kIsWeb ? null : File(cropped.path),
        bytes: bytes,
        addedAt: model.addedAt,
        size: bytes.length,
      );
    });
  }

  Future<void> _addMoreFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    final List<String> oversizedFiles = [];

    for (final f in result.files) {
      if (!FileValidator.isValidSize(f.size)) {
        oversizedFiles.add(f.name);
        continue;
      }

      final String webPath = kIsWeb && f.bytes != null 
          ? "data:image/png;base64,${base64Encode(f.bytes!)}" 
          : (f.path ?? '');
          
      final newFile = FileModel(
        id: '${DateTime.now().millisecondsSinceEpoch}${f.name}',
        name: f.name,
        path: webPath,
        file: f.path == null ? null : File(f.path!),
        bytes: f.bytes,
        addedAt: DateTime.now(),
        size: f.size,
      );
      final cfg = PagePrintConfig(pageCount: 1);
      setState(() {
        pickedFiles.add(newFile);
        pageConfigs.add(cfg);
        _thumbnails.add(f.bytes);
      });
      if (f.name.toLowerCase().endsWith('.pdf')) {
        _loadPdfMetadata(pickedFiles.length - 1, newFile);
      }
    }

    if (oversizedFiles.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The file must be below 10 MB. Omitted: ${oversizedFiles.join(", ")}')),
      );
    }
  }

  Widget _buildCustomParametersSection() {
    if (_customParameters.isEmpty) return const SizedBox.shrink();

    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Divider(color: AppColors.border.withValues(alpha: 0.4)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        divider,
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text(
              'Service Configuration',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _customParameters.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final cp = _customParameters[index];
            final String name = cp['name'] ?? '';
            final String type = cp['inputType'] ?? 'text';
            final List<String> options = List<String>.from(cp['options'] ?? []);
            final bool isRequired = cp['isRequired'] as bool? ?? false;

            if (type == 'dropdown') {
              return DropdownButtonFormField<String>(
              initialValue: _customValues[name] as String?,
                decoration: InputDecoration(
                  labelText: name + (isRequired ? ' *' : ''),
                  border: const OutlineInputBorder(),
                ),
                items: options.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt,
                    child: Text(opt),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _customValues[name] = val);
                },
                validator: (val) {
                  if (isRequired && (val == null || val.isEmpty)) {
                    return '$name is required';
                  }
                  return null;
                },
              );
            } else if (type == 'radio') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name + (isRequired ? ' *' : ''), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: options.map((opt) {
                      final isSelected = _customValues[name] == opt;
                      return ChoiceChip(
                        label: Text(opt),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _customValues[name] = opt);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            } else if (type == 'checkbox') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name + (isRequired ? ' *' : ''), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: options.map((opt) {
                      final List<String> list = List<String>.from(_customValues[name] ?? []);
                      final isChecked = list.contains(opt);
                      return FilterChip(
                        label: Text(opt),
                        selected: isChecked,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (val) {
                          setState(() {
                            if (val == true) {
                              list.add(opt);
                            } else {
                              list.remove(opt);
                            }
                            _customValues[name] = list;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            } else if (type == 'switch') {
              return SwitchListTile.adaptive(
                title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                value: _customValues[name] as bool? ?? false,
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primaryBlue,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  setState(() => _customValues[name] = val);
                },
              );
            } else if (type == 'counter') {
              final int count = _customValues[name] as int? ?? 1;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: count > 1 ? () => setState(() => _customValues[name] = count - 1) : null,
                        ),
                        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () => setState(() => _customValues[name] = count + 1),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else if (type == 'file') {
              final String fileName = _customValues[name] as String? ?? 'No file selected';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name + (isRequired ? ' *' : ''), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(fileName, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Choose File'),
                    onPressed: () async {
                      final pickerResult = await FilePicker.platform.pickFiles();
                      if (pickerResult != null && pickerResult.files.isNotEmpty) {
                        setState(() {
                          _customValues[name] = pickerResult.files.first.name;
                        });
                      }
                    },
                  ),
                ],
              );
            } else if (type == 'number') {
              return TextFormField(
                initialValue: _customValues[name] as String? ?? '',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: name + (isRequired ? ' *' : ''),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) => _customValues[name] = val,
                validator: (val) {
                  if (isRequired && (val == null || val.isEmpty)) {
                    return '$name is required';
                  }
                  return null;
                },
              );
            } else {
              return TextFormField(
                initialValue: _customValues[name] as String? ?? '',
                decoration: InputDecoration(
                  labelText: name + (isRequired ? ' *' : ''),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) => _customValues[name] = val,
                validator: (val) {
                  if (isRequired && (val == null || val.isEmpty)) {
                    return '$name is required';
                  }
                  return null;
                },
              );
            }
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B&W circle painter — half black / half grey dual-tone
// ─────────────────────────────────────────────────────────────────────────────
class _BWCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Grey half (left)
    final greyPaint = Paint()..color = const Color(0xFF757575);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.5708, // π/2 (90°)
      3.1416, // π (180°)
      true,
      greyPaint,
    );

    // Black half (right)
    final blackPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -π/2 (270°)
      3.1416,
      true,
      blackPaint,
    );

    // Subtle border
    final borderPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 0.6, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
