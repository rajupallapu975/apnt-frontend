import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:apnt/services/notification_service.dart';
import 'package:flutter/material.dart';
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
  });

  @override
  State<PaymentProcessingPage> createState() =>
      _PaymentProcessingPageState();
}

class _PaymentProcessingPageState
    extends State<PaymentProcessingPage> {
  bool _isConfirming = true;
  String _status = "Preparing Summary...";
  double _progress = 0.1;
  RazorpayHandler? _paymentHandler;
  
  // ⚡ TACTICAL OPTIMIZATION: Start order creation immediately in background
  late Future<Map<String, dynamic>> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = BackendService().createRazorpayOrder(widget.expectedPrice);
    
    if (widget.autoStartPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startProcessing();
      });
    }
  }

  Future<void> _startProcessing() async {
    setState(() {
      _isConfirming = false;
      _status = "FAST TRACKING PAYMENT...";
      _progress = 0.25;
    });

    try {
      // 1️⃣ Wait for server order to complete (started in initState)

      debugPrint("📡 Waiting for background order creation...");
      // Re-added timeout to handle Render cold starts gracefully
      final razorpayData = await _orderFuture.timeout(
        const Duration(seconds: 50),
        onTimeout: () => throw TimeoutException("Connection timed out. Please check your internet and retry.")
      );

      debugPrint("✅ Razorpay Order Ready: ${razorpayData['razorpayOrderId']}");

      _paymentHandler ??= RazorpayHandler();

      debugPrint("📦 Opening Razorpay gateway...");
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? 'customer@thinkink.com';
      
      const String defaultPhone = '8888888888';
      String? rawPhone = user?.phoneNumber;
      String userPhone = (rawPhone != null && rawPhone.isNotEmpty) 
          ? rawPhone.replaceAll(RegExp(r'[^0-9]'), '') 
          : defaultPhone;

      if (userPhone.length > 10) {
        userPhone = userPhone.substring(userPhone.length - 10);
      }
      if (userPhone.length != 10) userPhone = defaultPhone;

      final String rzpId = razorpayData['razorpayOrderId'].toString();
      
      var options = {
        'key': razorpayData['key'].toString(),
        'amount': razorpayData['amount'],
        'currency': 'INR',
        'name': 'Think Ink',
        'description': 'Print Job #${rzpId.split('_').last.toUpperCase()}',
        'order_id': rzpId,
        'method': 'upi',
        'upi': {
          'flow': 'intent'
        },
        'prefill': {
          'name': user?.displayName ?? 'Valued Customer',
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

      _paymentHandler!.openCheckout(
        options: options,
        onSuccess: (paymentId, orderId, signature) async {
          debugPrint("💳 Razorpay Payment Success: $paymentId");
          String? currentOrderId;
          
          // We wrap the rest in a Future.microtask or just let it run 
          // to avoid holding the Razorpay UI for too long if needed, 
          // but the user wants it to stay while uploading.
          try {
            setState(() {
              _status = "Verifying payment...";
              _progress = 0.4;
            });

            final verifyResult = await BackendService().verifyPayment(
              razorpayOrderId: orderId,
              razorpayPaymentId: paymentId,
              razorpaySignature: signature,
              printSettings: widget.printSettings,
              amount: widget.expectedPrice,
              totalPages: widget.expectedPages,
            );

            final finalOrderId = verifyResult['orderId'];
            currentOrderId = finalOrderId;
            final finalPickupCode = verifyResult['pickupCode'];

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
              );
              finalFileUrls = cloudinaryResult['urls']!;
              finalPublicIds = cloudinaryResult['publicIds']!;
            } else {
              setState(() {
                _status = "Synchronizing files...";
                _progress = 0.7;
              });
            }

            final storage = LocalStorageService();
            final List<String> savedLocalPaths = [];
            
            setState(() {
              _status = "Finalizing order...";
            });

            if (widget.selectedBytes.isNotEmpty) {
              for (int i = 0; i < widget.filenames.length; i++) {
                final bytes = widget.selectedBytes[i];
                if (bytes != null) {
                  final path = await storage.saveFileLocally(widget.filenames[i], bytes);
                  savedLocalPaths.add(path);
                }
              }
            }

            await FirestoreService().attachFilesToOrder(
              orderId: finalOrderId,
              fileUrls: finalFileUrls,
              publicIds: finalPublicIds,
              localFilePaths: savedLocalPaths,
            );

            final freshOrder = await FirestoreService().getOrder(finalOrderId);
            if (freshOrder != null) {
              await storage.saveOrderLocally(freshOrder);
            }

            // 🔔 TRIGGER NOTIFICATION (with background scheduling)
            NotificationService().notifyOrderCreated(
              finalPickupCode, 
              freshOrder?.expiresAt ?? DateTime.now().add(const Duration(hours: 24)),
            );

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentSuccessPage(
                  orderId: finalOrderId,
                  pickupCode: finalPickupCode,
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
                );
              } catch (_) {}
            }

            await BackendService().refundPayment(
              razorpayPaymentId: paymentId,
              amount: widget.expectedPrice,
            );

            _goToError("Payment successful, but setup failed ($e). Refund initiated.");
          }
        },
        onFailure: (error) {
          debugPrint("❌ Razorpay Payment Error: $error");
          _goToError(error);
        },
      );
    } catch (e) {
      _goToError(e.toString());
    }
  }

  void _goToError(dynamic error) {
    if (!mounted) return;

    final String message = error.toString().toLowerCase();
    
    // 🛡️ Handles "Withdrawal" (User cancellation/dismissal)
    bool isUserCancel = message.contains("cancel") || 
                        message.contains("dismiss") || 
                        message.contains("back") ||
                        message.contains("pop") ||
                        message == "undefined" || 
                        message == "null" ||
                        message.trim().isEmpty;

    if (isUserCancel) {
      debugPrint("🛒 User withdrew from payment. Returning to editing...");
      Navigator.pop(context);
      return;
    }

    String displayMessage = error.toString();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentErrorPage(
          message: displayMessage,
          onRetry: () {
            Navigator.pushReplacement(
              context,
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
                ),
              ),
            );
          },
          onGoBack: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const UploadPage()),
              (route) => false,
            );
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
          Text(
            "ORDER RECAP",
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          
          // 🏷️ Amount Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
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
                Icon(Icons.payments_rounded, color: AppColors.primaryBlue.withOpacity(0.2), size: 48),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),

          // 📄 Details Cards
          Row(
            children: [
              _summaryMiniCard(Icons.description_outlined, "${widget.expectedPages}", "PAGES"),
              const SizedBox(width: 16),
              _summaryMiniCard(Icons.folder_open_rounded, "${widget.filenames.length}", "FILES"),
            ],
          ),
          
          // 📂 Documents List
          const SizedBox(height: 32),
          Text(
            "DOCUMENTS",
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: widget.filenames.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final String name = widget.filenames[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 350.ms),
          
          // 🚀 Action Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: ElevatedButton(
              onPressed: _startProcessing,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Text(
                "PROCEED TO PAY ₹${widget.expectedPrice.toStringAsFixed(0)}",
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
              ),
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
        ),
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
      ignoring: _progress > 0.1, 
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                 SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 8,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  ),
                ).animate(onPlay: (c) => c.repeat()).rotate(duration: 3.seconds),
                const Icon(Icons.print_rounded, size: 40, color: AppColors.primaryBlue),
              ],
            ),
            const SizedBox(height: 56),
            Text(
              _status.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryBlack,
                letterSpacing: 2,
              ),
            ).animate(key: ValueKey(_status)).fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ).animate().fadeIn(delay: 400.ms),
          
            Text(
              'POWERED BY THINK INK CORE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}