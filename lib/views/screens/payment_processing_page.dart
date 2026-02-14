// ============================================================================
// PAYMENT PROCESSING PAGE (UPDATED - BACKEND CONTROLLED)
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:apnt/services/firestore_service.dart';
import 'package:apnt/services/cloudinary_storage_service.dart';
import 'package:apnt/services/backend_service.dart';
import 'package:apnt/views/screens/payment_error_page.dart';
import 'package:flutter/material.dart';
import 'payment_success_page.dart';

class PaymentProcessingPage extends StatefulWidget {
  final List<File?> selectedFiles;
  final List<Uint8List?> selectedBytes;
  final Map<String, dynamic> printSettings;
  final int expectedPages;
  final double expectedPrice;

  const PaymentProcessingPage({
    super.key,
    required this.selectedFiles,
    required this.selectedBytes,
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

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  // ==========================================================================
  // MAIN PROCESSING WORKFLOW
  // ==========================================================================
  Future<void> _startProcessing() async {
    try {
      // STEP 1: VALIDATE FILES
      final hasFiles =
          widget.selectedFiles.any((f) => f != null);
      final hasBytes =
          widget.selectedBytes.any((b) => b != null);

      if (!hasFiles && !hasBytes) {
        throw Exception("No valid files selected");
      }

      print('📡 Creating order via backend...');

      // STEP 2: CREATE ORDER VIA BACKEND
      final backendResult = await BackendService()
          .createOrder(widget.printSettings);

      final String orderId = backendResult.orderId;
      final String pickupCode =
          backendResult.pickupCode;

      print('✅ Order Created: $orderId');
      print('🔑 Pickup Code: $pickupCode');

      // STEP 3: UPLOAD FILES TO CLOUDINARY
      print('📤 Uploading files...');

      final uploadedUrls =
          await CloudinaryStorageService()
              .uploadFiles(
        pickupCode: pickupCode,
        files: widget.selectedFiles,
        bytes: widget.selectedBytes,
      );

      if (uploadedUrls.isEmpty) {
        throw Exception(
            "File upload failed - no URLs returned");
      }

      print('✅ Files uploaded successfully');

      // STEP 4: ATTACH FILE URLS TO ORDER
      await FirestoreService().attachFilesToOrder(
        orderId: orderId,
        fileUrls: uploadedUrls,
      );

      print('✅ Files attached to order');

      // STEP 5: NAVIGATE TO SUCCESS PAGE
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessPage(
            orderId: orderId,
            pickupCode: pickupCode,
          ),
        ),
      );

    } catch (e, stackTrace) {
      print("❌ ORDER PROCESSING ERROR: $e");
      print(stackTrace);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentErrorPage(
            message: e.toString(),
            onRetry: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentProcessingPage(
                    selectedFiles:
                        widget.selectedFiles,
                    selectedBytes:
                        widget.selectedBytes,
                    printSettings:
                        widget.printSettings,
                    expectedPages:
                        widget.expectedPages,
                    expectedPrice:
                        widget.expectedPrice,
                  ),
                ),
              );
            },
            onGoBack: () =>
                Navigator.pop(context),
          ),
        ),
      );
    }
  }

  // ==========================================================================
  // UI
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Processing Order"),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                "Processing payment and securing your files...\nPlease wait",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
