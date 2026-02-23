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
  String _status = "Initializing...";
  double _progress = 0.1;
  RazorpayHandler? _paymentHandler;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the UI is ready but call processing immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing());
  }

  Future<void> _startProcessing() async {
    try {
      final backend = BackendService();

      setState(() {
        _status = "Contacting Server...";
        _progress = 0.15;
      });

      debugPrint("📡 Connecting to: ${BackendConfig.createRazorpayOrderUrl}");
      debugPrint("💰 Amount: ${widget.expectedPrice}");
      
      // 1️⃣ Create Razorpay order
      final razorpayData = await backend
          .createRazorpayOrder(widget.expectedPrice)
          .timeout(const Duration(seconds: 12), onTimeout: () {
        throw TimeoutException("Check your internet or laptop's connection.");
      });

      debugPrint("✅ Razorpay Order Response: $razorpayData");

      debugPrint("✅ Razorpay Order Created: ${razorpayData['razorpayOrderId']}");

      _paymentHandler ??= RazorpayHandler();

      debugPrint("📦 Opening Razorpay gateway with options...");
      var options = {
        'key': razorpayData['key'].toString(),
        'amount': razorpayData['amount'],
        'currency': 'INR',
        'name': 'Think Ink',
        'description': 'Document Printing Payment',
        'order_id': razorpayData['razorpayOrderId'],
        'prefill': {
          'contact': '',
          'email': ''
        },
        'method': 'upi', // Force UPI
        'config': {
          'display': {
            'blocks': {
              'upi': {
                'name': 'Pay with UPI / QR',
                'instruments': [
                  {
                    'method': 'upi',
                  }
                ]
              }
            },
            'sequence': ['block.upi'],
            'preferences': {
              'show_default_blocks': false
            }
          }
        }
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

            // 2️⃣ Verify Payment
            final verifyResult = await backend.verifyPayment(
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

            // 3️⃣ Upload Files
            final cloudinaryResult =
                await CloudinaryStorageService().uploadFiles(
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

            // Optional local storage
            final storage = LocalStorageService();
            final freshOrder =
                await FirestoreService().getOrder(finalOrderId);
            if (freshOrder != null) {
              await storage.saveOrderLocally(freshOrder);
            }

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
            debugPrint("❌ Verification/Upload Error: $e");
            _goToError(e.toString());
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

  void _goToError(String message) {
    if (!mounted) return;

    // Filter message for common cancel strings
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
            // Push a fresh processing page to retry the flow
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
            // Go to Home Page (UploadPage) and clear navigation stack
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
                      backgroundColor: AppColors.primaryBlue
                          .withValues(alpha: 0.1),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryBlue),
                    ),
                  ).animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 3.seconds),
                  const Icon(Icons.print_rounded,
                      size: 40,
                      color: AppColors.primaryBlue),
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
              ).animate(key: ValueKey(_status))
                .fadeIn()
                .slideY(begin: 0.1, end: 0),
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