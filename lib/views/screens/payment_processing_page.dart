import 'dart:async';
import 'dart:io';
import 'package:apnt/models/print_order_model.dart';
import 'package:apnt/services/notification_service.dart';
import 'package:apnt/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/razorpay_handler.dart';

import '../../services/firestore_service.dart';
import '../../services/cloudinary_storage_service.dart';
import '../../services/backend_service.dart';
import '../../services/local_storage_service.dart';
import '../../utils/app_colors.dart';
import 'payment_success_page.dart';
import 'payment_error_page.dart';
import 'upload_page.dart';

import 'package:firebase_auth/firebase_auth.dart';

class PaymentProcessingPage extends StatefulWidget {
  final List<File?> selectedFiles;
  final List<Uint8List?> selectedBytes;
  final List<String> filenames;
  final Map<String, dynamic> printSettings;
  final int expectedPages;
  final double expectedPrice;

  final List<String>? initialFileUrls;
  final List<String>? initialPublicIds;
  final bool autoStartPayment;

  final String? prefillPhone;
  final Map<String, dynamic>? preCreatedOrder; 
  final Future<Map<String, dynamic>>? orderFuture;
  final Future<List<Uint8List?>>? processingFuture;

  const PaymentProcessingPage({
    super.key,
    required this.selectedFiles,
    required this.selectedBytes,
    required this.filenames,
    required this.printSettings,
    this.expectedPages = 0,
    this.expectedPrice = 0.0,
    this.initialFileUrls,
    this.initialPublicIds,
    this.autoStartPayment = false,

    this.prefillPhone,
    this.preCreatedOrder,
    this.orderFuture,
    this.processingFuture,
  });

  @override
  State<PaymentProcessingPage> createState() =>
      _PaymentProcessingPageState();
}

class _PaymentProcessingPageState
    extends State<PaymentProcessingPage> {
  bool _isConfirming = true;
  bool _isHandlingSuccess = false; // 🛡️ Prevent duplicate processing
  String _status = "Preparing Summary...";
  double _progress = 0.1;
  RazorpayHandler? _paymentHandler;
  
  late Future<Map<String, dynamic>> _orderFuture;
  late List<Uint8List?> _finalizedBytes;

  @override
  void initState() {
    super.initState();
    _finalizedBytes = widget.selectedBytes;
    
    if (widget.orderFuture != null) {
      _orderFuture = widget.orderFuture!;
    } else if (widget.preCreatedOrder != null) {
      _orderFuture = Future.value(widget.preCreatedOrder!);
    } else {
      _orderFuture = BackendService().createRazorpayOrder(widget.expectedPrice);
    }
    
    if (widget.autoStartPayment) {
      _isConfirming = false; 
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startProcessing();
      });
    }
  }

  Future<void> _startProcessing() async {
    setState(() {
      _isConfirming = false;
      _status = "Wait for your payment request...";
      _progress = 0.25;
    });

    try {
      final authVM = context.read<AuthViewModel>();
      
      setState(() {
        _status = "Preparing your print request...";
        _progress = 0.2;
      });
      
      final results = await Future.wait([
        _orderFuture.timeout(const Duration(seconds: 50)),
        widget.processingFuture ?? Future.value(_finalizedBytes),
      ]);

      final razorpayData = results[0] as Map<String, dynamic>;
      _finalizedBytes = results[1] as List<Uint8List?>;

      final String rzpId = razorpayData['razorpayOrderId'].toString();

      setState(() {
        _status = "Proceed to Pay..."; 
        _progress = 0.4;
      });
      _paymentHandler ??= RazorpayHandler();

      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? 'customer_${DateTime.now().millisecondsSinceEpoch}@thinkink.com';
      String? userPhone = widget.prefillPhone ?? authVM.phoneNumber;
      userPhone ??= '0000000000'; 
      final String userName = user?.displayName ?? 'Valued Customer';
      
      final bool isMobileWeb = kIsWeb && 
          (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

      var options = {
        'key': razorpayData['key'].toString(),
        'amount': razorpayData['amount'],
        'currency': 'INR',
        'name': 'Think Ink',
        'description': 'Print Job #${rzpId.split('_').last.toUpperCase()}',
        'order_id': rzpId,
        'method': 'upi',
        'upi': {'flow': isMobileWeb ? 'intent' : 'qr'},
        'prefill': {
          'name': userName,
          'contact': userPhone,
          'email': userEmail, 
          'method': 'upi'
        },
        'readonly': {
          'contact': true,
          'email': true,
          'name': true,
          'method': true
        },
        'modal': {
          'backdropClose': false,
          'escape': false,
          'handleback': false
        },
        'retry': {'enabled': false},
        'timeout': 180 
      };

      final bool isBypass = widget.printSettings['isBypass'] == true;

      if (isBypass) {
        debugPrint("🔑 ADMIN BYPASS DETECTED: 9750");
        setState(() {
          _status = "Admin Code Verified...";
          _progress = 0.5;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        _handlePaymentSuccess(
          'pay_admin_9750', 
          rzpId, 
          'mock_signature_9750'
        );
        return;
      }

      _paymentHandler!.openCheckout(
        options: options,
        onSuccess: _handlePaymentSuccess,
        onFailure: (error) => _goToError(error),
      );
    } catch (e) {
      _goToError(e.toString());
    }
  }

  Future<void> _handlePaymentSuccess(String paymentId, String orderId, String signature) async {
    if (_isHandlingSuccess) {
      debugPrint("🛡️ Duplicate success callback ignored for $paymentId");
      return; 
    }
    _isHandlingSuccess = true;
    
    debugPrint("💳 Payment Success Action: $paymentId");
    String? currentOrderId;
    final authVM = context.read<AuthViewModel>();
    final String userPhone = widget.prefillPhone ?? authVM.phoneNumber ?? '0000000000';

    try {
      setState(() {
        _status = "Verifying payment...";
        _progress = 0.45;
      });

      final verifyResult = await BackendService().verifyPayment(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        printSettings: widget.printSettings,
        amount: widget.expectedPrice,
        totalPages: widget.expectedPages,
        printMode: widget.printSettings['printMode'] ?? 'autonomous',
      );

      final finalOrderId = verifyResult['orderId'];
      currentOrderId = finalOrderId;
      
      // 🆔 MATCH GENERATED 4-DIGIT UNIQUE CODE
      String finalPickupCode = (verifyResult['pickupCode'] ?? '').toString();
      if (widget.printSettings['printMode'] == 'xeroxShop') {
        finalPickupCode = (widget.printSettings['xeroxCode'] ?? '').toString(); 
      }

      List<String> finalFileUrls = widget.initialFileUrls ?? [];
      List<String> finalPublicIds = widget.initialPublicIds ?? [];

      if (finalFileUrls.isEmpty) {
        setState(() {
          _status = "Uploading files...";
          _progress = 0.6;
        });

        final cloudinaryResult = await CloudinaryStorageService().uploadFiles(
          pickupCode: finalPickupCode,
          files: widget.selectedFiles,
          bytes: widget.selectedBytes,
          filenames: widget.filenames,
          printMode: widget.printSettings['printMode'] ?? 'autonomous',
        );
        finalFileUrls = cloudinaryResult['urls']!;
        finalPublicIds = cloudinaryResult['publicIds']!;
      }

      final storage = LocalStorageService();
      final List<String> savedLocalPaths = [];
      
      setState(() { _status = "Finalizing order..."; });

      if (widget.selectedBytes.isNotEmpty) {
        for (int i = 0; i < widget.filenames.length; i++) {
          final bytes = widget.selectedBytes[i];
          if (bytes != null) {
            final path = await storage.saveFileLocally(widget.filenames[i], bytes);
            savedLocalPaths.add(path);
          }
        }
      }

      await BackendService().completeOrder(
        orderId: finalOrderId,
        fileUrls: finalFileUrls,
        publicIds: finalPublicIds,
        localFilePaths: savedLocalPaths,
        printMode: widget.printSettings['printMode'] ?? 'autonomous',
      );

      PrintOrderModel? freshOrder;
      try {
        freshOrder = await FirestoreService().getOrder(
          finalOrderId, 
          printMode: widget.printSettings['printMode'] ?? 'autonomous'
        );
      } catch (e) {
        debugPrint("🤫 Warning: Document fetch failed (maybe rules?). Processing locally...");
      }

      if (freshOrder != null) {
        await storage.saveOrderLocally(freshOrder);
      }

      // Always try to sync stats
      try {
        await FirestoreService().syncUserPostPayment(
          amount: widget.expectedPrice,
          phone: userPhone,
          pages: widget.expectedPages,
          files: widget.filenames.length,
          isXerox: widget.printSettings['printMode'] == 'xeroxShop',
        );
      } catch (_) {}

      NotificationService().notifyOrderCreated(
        finalPickupCode, 
        freshOrder?.expiresAt ?? DateTime.now().add(const Duration(hours: 12)),
        isXerox: widget.printSettings['printMode'] == 'xeroxShop',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessPage(
            orderId: finalOrderId,
            pickupCode: finalPickupCode,
            xeroxId: verifyResult['xeroxId'],
            isXerox: widget.printSettings['printMode'] == 'xeroxShop',
            expiresAt: freshOrder?.expiresAt ?? DateTime.now().add(const Duration(hours: 12)),
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ CRITICAL ERROR IN SUCCESS CALLBACK: $e");
      if (currentOrderId != null) {
        try { 
          await FirestoreService().updateOrderStatus(
            orderId: currentOrderId, 
            status: 'CANCELLED',
            printMode: widget.printSettings['printMode'] ?? 'autonomous'
          ); 
        } catch (_) {}
      }
      await BackendService().refundPayment(razorpayPaymentId: paymentId, amount: widget.expectedPrice);
      _goToError("Payment successful, but setup failed. Refund initiated.");
    }
  }

  void _goToError(dynamic error) {
    if (!mounted) return;
    final String message = error.toString().toLowerCase();
    bool isUserCancel = message.contains("cancel") || message.contains("dismiss") || message.contains("back") || message.contains("pop") || message == "undefined" || message == "null" || message.trim().isEmpty;

    if (isUserCancel) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentErrorPage(
          message: error.toString(),
          onRetry: (errorCtx) {
            Navigator.pushReplacement(
              errorCtx,
              MaterialPageRoute(
                builder: (_) => PaymentProcessingPage(
                  selectedFiles: widget.selectedFiles,
                  selectedBytes: widget.selectedBytes,
                  filenames: widget.filenames,
                  printSettings: widget.printSettings,
                  expectedPages: widget.expectedPages,
                  expectedPrice: widget.expectedPrice,
                  initialFileUrls: widget.initialFileUrls,
                  initialPublicIds: widget.initialPublicIds,
                  autoStartPayment: true,

                  prefillPhone: widget.prefillPhone,
                ),
              ),
            );
          },
          onGoBack: (errorCtx) {
            Navigator.pushAndRemoveUntil(errorCtx, MaterialPageRoute(builder: (_) => const UploadPage()), (route) => false);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _paymentHandler?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isConfirming && _progress < 0.2, 
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _isConfirming ? AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryBlack),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'CONFIRM ORDER',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5, color: AppColors.primaryBlack),
          ),
          centerTitle: true,
        ) : null,
        body: _isConfirming ? _buildSummaryUI() : _buildProcessingUI(),
      ),
    );
  }

  Widget _buildSummaryUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text("ORDER RECAP", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TOTAL AMOUNT", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)),
                    const SizedBox(height: 4),
                    Text("₹${widget.expectedPrice.toStringAsFixed(0)}", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primaryBlue)),
                  ],
                ),
                Icon(Icons.payments_rounded, color: AppColors.primaryBlue.withValues(alpha: 0.2), size: 48),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryMiniCard(Icons.description_outlined, "${widget.expectedPages}", "PAGES"),
              const SizedBox(width: 16),
              _summaryMiniCard(Icons.folder_open_rounded, "${widget.filenames.length}", "FILES"),
            ],
          ),
          const SizedBox(height: 32),
          Text("DOCUMENTS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: widget.filenames.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(widget.filenames[index], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 350.ms),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)))),
            child: ElevatedButton(
              onPressed: _progress > 0.1 ? null : _startProcessing,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
              child: _progress > 0.1 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text("PROCEED TO PAY ₹${widget.expectedPrice.toStringAsFixed(0)}", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _summaryMiniCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryBlack, size: 24),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryBlack)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingUI() {
    return IgnorePointer(
      ignoring: true, 
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (index) {
                    return Positioned(
                      top: 60,
                      child: Container(
                        width: 55, height: 75,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 35, height: 4, color: AppColors.border.withValues(alpha: 0.3)),
                              const SizedBox(height: 6),
                              Container(width: 25, height: 4, color: AppColors.border.withValues(alpha: 0.3)),
                              const SizedBox(height: 6),
                              Container(width: 38, height: 4, color: AppColors.border.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat()).moveY(begin: 0, end: 140, duration: 2.seconds, delay: (index * 600).ms, curve: Curves.easeInOut).fadeIn(duration: 400.ms).fadeOut(begin: 1, duration: 400.ms, delay: (index * 600 + 1600).ms),
                    );
                  }),
                  Positioned(
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 10)]),
                      child: const Icon(Icons.print_rounded, size: 64, color: AppColors.primaryBlue),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.3)).shake(hz: 3, curve: Curves.easeInOut, rotation: 0.02),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 64),
            Text(_status.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryBlack, letterSpacing: 2.0)).animate(key: ValueKey(_status)).fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primaryBlack.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primaryBlack.withValues(alpha: 0.05))),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.timer_outlined, size: 14, color: AppColors.primaryBlue), const SizedBox(width: 8), Text("ORDER VALIDITY", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primaryBlue, letterSpacing: 1.0))]),
                  const SizedBox(height: 6),
                  Text("This print order will automatically expire 12 hours after creation.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryBlack.withValues(alpha: 0.8), height: 1.3)),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 72),
            Text('THINK INK • SECURE PRINTING', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary.withValues(alpha: 0.6), letterSpacing: 3)).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}