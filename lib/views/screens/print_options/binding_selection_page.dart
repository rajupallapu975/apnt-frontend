import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../models/file_model.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/order_utils.dart';
import '../../../../services/backend_service.dart';
import '../../../../services/firestore_service.dart';
import '../widgets/payment_summary_sheet.dart';
import '../payment_processing_page.dart';
import 'print_options_page.dart';

class BindingSelectionPage extends StatefulWidget {
  final List<FileModel> pickedFiles;
  final List<PagePrintConfig> pageConfigs;
  final String shopId;
  final String shopName;
  final String shopPhone;
  final String serviceId;
  final String serviceName;
  final String selectedPaperSize;
  final Map<String, dynamic> shopData;
  final Map<String, dynamic> globalServiceParams;
  final double printingCost;
  final double printingCommission;

  const BindingSelectionPage({
    super.key,
    required this.pickedFiles,
    required this.pageConfigs,
    required this.shopId,
    required this.shopName,
    required this.shopPhone,
    required this.serviceId,
    required this.serviceName,
    required this.selectedPaperSize,
    required this.shopData,
    required this.globalServiceParams,
    required this.printingCost,
    required this.printingCommission,
  });

  @override
  State<BindingSelectionPage> createState() => _BindingSelectionPageState();
}

class _BindingSelectionPageState extends State<BindingSelectionPage> {
  String _selectedBinding = 'spiral';
  bool _isLoading = false;

  double _getBindingPrice(String type) {
    final zikrServices = widget.shopData['zikrinterServices'] as Map<String, dynamic>? ?? {};
    final serviceConfig = zikrServices[widget.serviceId] as Map<String, dynamic>? ?? {};
    final bindings = serviceConfig['bindings'] as Map<String, dynamic>? ?? {};
    
    final price = bindings[type];
    if (price != null) {
      if (price is num) return price.toDouble();
      return double.tryParse(price.toString()) ?? 0.0;
    }
    
    // Fallbacks
    switch (type) {
      case 'spiral':
        return 40.0;
      case 'thermal':
        return 50.0;
      case 'paper':
        return 30.0;
      default:
        return 0.0;
    }
  }

  double _getBindingCommission(String type, double cost) {
    final config = widget.globalServiceParams['${type}_binding'] as Map<String, dynamic>?;
    if (config == null || config['isEnabled'] != true) {
      return 0.0;
    }
    final commType = config['commissionType'] ?? 'percentage';
    final commValue = (config['commission'] as num? ?? 0.0).toDouble();

    if (commType == 'percentage') {
      return cost * (commValue / 100.0);
    } else {
      return commValue;
    }
  }

  double get _currentBindingCost => _getBindingPrice(_selectedBinding);
  double get _currentBindingCommission => _getBindingCommission(_selectedBinding, _currentBindingCost);
  
  double get _totalCommission => (widget.printingCommission + _currentBindingCommission).ceilToDouble();
  double get _totalPayable => widget.printingCost + _currentBindingCost + _totalCommission;

  Future<void> _handleProceed() async {
    setState(() => _isLoading = true);

    try {
      // 1. Verify shop status
      final isOnline = await BackendService().checkShopStatus(widget.shopId);
      if (!isOnline) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("This shop has gone offline. Please select another shop to proceed."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      int totalPg = 0;
      for (var pc in widget.pageConfigs) {
        totalPg += pc.pageCount * pc.copies;
      }

      // Generate order codes
      final String xeroxCode = OrderUtils.generateXeroxCode();
      final int nextIdx = await FirestoreService().getNextOrderIndex(true);
      final String sequentialId = 'order_$nextIdx';
      final String secureOrderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final printSettings = {
        'printMode': 'xeroxShop',
        'orderId': secureOrderId,
        'customId': sequentialId,
        'xeroxCode': xeroxCode,
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'shopPhone': widget.shopPhone,
        'serviceId': widget.serviceId,
        'serviceName': widget.serviceName,
        'paperSize': widget.selectedPaperSize,
        'serviceType': 'project_binding',
        'bindingType': _selectedBinding,
        'printingCost': widget.printingCost,
        'bindingCost': _currentBindingCost,
        'platformCommission': _totalCommission,
        'totalAmount': _totalPayable,
        'files': List.generate(widget.pageConfigs.length, (i) {
          final model = widget.pickedFiles[i];
          final cfg = widget.pageConfigs[i];
          return {
            'fileName': model.name,
            'pageCount': cfg.pageCount,
            'color': cfg.isColor ? 'COLOR' : 'BW',
            'orientation': cfg.isPortrait ? 'PORTRAIT' : 'LANDSCAPE',
            'copies': cfg.copies,
            'doubleSided': cfg.isDoubleSided,
            'paperSize': widget.selectedPaperSize,
            'fileSizeKB': (model.size / 1024).toStringAsFixed(1),
            'url': '',
            'publicId': '',
            'price': widget.pickedFiles.length > i ? (widget.printingCost / widget.pickedFiles.length) : 0.0,
          };
        }),
      };

      // Trigger razorpay order creation
      final razorpayFuture = BackendService().createRazorpayOrder(_totalPayable);

      final processingFuture = Future.wait(
        List.generate(widget.pickedFiles.length, (i) async {
          final model = widget.pickedFiles[i];
          Uint8List? originalBytes;
          if (model.bytes != null) {
            originalBytes = model.bytes;
          } else if (model.file != null) {
            originalBytes = await model.file!.readAsBytes();
          }
          return originalBytes;
        }),
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PaymentSummarySheet(
          totalPages: totalPg,
          totalPrice: _totalPayable,
          printSettings: printSettings,
          razorpayFuture: razorpayFuture,
          processingFuture: processingFuture,
          onProceed: (phone) async {
            try {
              final razorpayData = await razorpayFuture;
              final finalizedBytes = await processingFuture;

              if (!mounted) return;
              Navigator.pop(context); // Close sheet
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentProcessingPage(
                    selectedFiles: widget.pickedFiles.map((e) => e.file).toList(),
                    selectedBytes: finalizedBytes,
                    filenames: widget.pickedFiles.map((e) => e.name).toList(),
                    printSettings: printSettings,
                    expectedPages: totalPg,
                    expectedPrice: _totalPayable,
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
      setState(() => _isLoading = false);
      debugPrint("❌ Proceed failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final spiralPrice = _getBindingPrice('spiral');
    final thermalPrice = _getBindingPrice('thermal');
    final paperPrice = _getBindingPrice('paper');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Choose Binding Type",
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Binding Option",
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 8),
                    Text(
                      "Choose how you want your document project to be bound",
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                    ).animate().fadeIn(duration: 300.ms, delay: 50.ms),
                    const SizedBox(height: 24),
                    _buildBindingCard(
                      id: 'spiral',
                      title: 'Spiral Binding',
                      description: 'Flexible plastic coils wound through punched holes. Ideal for reports and workbooks.',
                      price: spiralPrice,
                      icon: Icons.loop_rounded,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildBindingCard(
                      id: 'thermal',
                      title: 'Thermal Binding',
                      description: 'Uses heat and glue to bind pages to a sleek cover spine. Gives a clean book-like finish.',
                      price: thermalPrice,
                      icon: Icons.local_fire_department_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildBindingCard(
                      id: 'paper',
                      title: 'Paper / Softcover Binding',
                      description: 'Classic wrap-around softbound cover. Perfect for thesis projects and final submissions.',
                      price: paperPrice,
                      icon: Icons.menu_book_rounded,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Summary Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Files + Binding",
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "₹${(widget.printingCost + _currentBindingCost).toStringAsFixed(0)}",
                            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 52,
                        width: 160,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleProceed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text("Proceed to Pay", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBindingCard({
    required String id,
    required String title,
    required String description,
    required double price,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedBinding == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBinding = id;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.04 : 0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        "₹${price.toStringAsFixed(0)}",
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
  }
}
