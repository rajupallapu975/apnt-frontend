import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:apnt/config/backend_config.dart';
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
import 'widgets/payment_summary_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentProcessingPage extends StatefulWidget {
  final List<File?> selectedFiles;
  final List<Uint8List?> selectedBytes;
  final List<String> filenames;
  final Map<String, dynamic> printSettings;
  final int expectedPages;
  final double expectedPrice;

  const PaymentProcessingPage({
    super.key,
    required this.selectedFiles,
    required this.selectedBytes,
    required this.filenames,
    required this.printSettings,
    this.expectedPages = 0,
    this.expectedPrice = 0.0,
  });

  @override
  State<PaymentProcessingPage> createState() =>
      _PaymentProcessingPageState();
}

class _PaymentProcessingPageState
    extends State<PaymentProcessingPage> {
  String _status = "Preparing Summary...";
  double _progress = 0.1;
  RazorpayHandler? _paymentHandler;
  
  // ⚡ TACTICAL OPTIMIZATION: Start order creation immediately in background
  late Future<Map<String, dynamic>> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = BackendService().createRazorpayOrder(widget.expectedPrice);
    
    // Start the flow immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing());
  }

  Future<void> _startProcessing() async {
    try {
      // 1️⃣ IMMEDIATELY show Professional Payment Summary Bottom Sheet
      // This happens while the server call is running in the background.
      if (!mounted) return;
      
      final bool? proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => PaymentSummarySheet(
          totalPages: widget.expectedPages,
          totalPrice: widget.expectedPrice,
          printSettings: widget.printSettings,
          onProceed: () => Navigator.pop(context, true),
        ),
      );

      if (proceed != true) {
        debugPrint("👋 User cancelled payment summary sheet.");
        if (mounted) Navigator.pop(context);
        return;
      }

      // 2️⃣ Wait for server order to complete if it hasn't already
      setState(() {
        _status = "Finalizing Order Details...";
        _progress = 0.2;
      });

      debugPrint("📡 Waiting for background order creation...");
      final razorpayData = await _orderFuture.timeout(
        const Duration(seconds: 40),
        onTimeout: () => throw TimeoutException("The server is taking too long to respond. Please check your connection and try again.")
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

      var options = {
        'key': razorpayData['key'].toString(),
        'amount': razorpayData['amount'],
        'currency': 'INR',
        'name': 'Think Ink',
        'description': 'Payment',
        'order_id': razorpayData['razorpayOrderId'],
        'prefill': {
          'name': user?.displayName ?? 'Valued Customer',
          'contact': userPhone,
          'email': userEmail, 
        },
        'readonly': {
          'contact': true,
          'email': true
        },
        'config': {
          'display': {
            'hide': ['branding'],
            'blocks': {
              'upi': {
                'name': 'UPI Payment / QR',
                'instruments': [{'method': 'upi'}]
              }
            },
            'sequence': ['block.upi'],
            'preferences': {
              'show_default_blocks': false
            }
          }
        },
        'method': {
          'upi': true,
          'netbanking': false,
          'card': false,
          'wallet': false,
          'paylater': false
        },
        'modal': {
          'backdropClose': false,
          'escape': false,
          'handleback': false
        },
        'retry': {'enabled': false},
        'timeout': 300
      };

      _paymentHandler!.openCheckout(
        options: options,
        onSuccess: (paymentId, orderId, signature) async {
          debugPrint("💳 Razorpay Payment Success: $paymentId");
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
            final finalPickupCode = verifyResult['pickupCode'];

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

            await FirestoreService().attachFilesToOrder(
              orderId: finalOrderId,
              fileUrls: cloudinaryResult['urls']!,
              publicIds: cloudinaryResult['publicIds']!,
              localFilePaths: [],
            );

            final storage = LocalStorageService();
            final freshOrder = await FirestoreService().getOrder(finalOrderId);
            if (freshOrder != null) await storage.saveOrderLocally(freshOrder);

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
            await BackendService().refundPayment(
              razorpayPaymentId: paymentId,
              amount: widget.expectedPrice,
            );

            _goToError(
              "Payment was successful, but we encountered an error setting up your print job ($e). "
              "A refund has been initiated automatically."
            );
          }
        },
        onFailure: (error) {
          debugPrint("❌ Razorpay Payment Error: $error");
          if (mounted) Navigator.pop(context);
        },
      );
    } catch (e) {
      _goToError(e.toString());
    }
  }

  void _goToError(String message) {
    if (!mounted) return;

    String displayMessage = message;
    if (message.toLowerCase().contains("cancel")) {
      displayMessage = "Payment was cancelled.";
    }

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
      canPop: false,
      child: Scaffold(
        body: Container(
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
              const SizedBox(height: 16),
              Text(
                "Securing your documents for high-precision output. Do not close the application.",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 80),
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
      ),
    );
  }
}