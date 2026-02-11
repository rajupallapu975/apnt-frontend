import 'dart:io';
import 'dart:typed_data';

import 'package:apnt/services/firestore_service.dart';
import 'package:apnt/services/cloudinary_storage_service.dart';
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

class _PaymentProcessingPageState extends State<PaymentProcessingPage> {
  
  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

Future<void> _startProcessing() async {
  try {
    // Check if there are any valid files or bytes
    final hasFiles = widget.selectedFiles.any((f) => f != null);
    final hasBytes = widget.selectedBytes.any((b) => b != null);

    if (!hasFiles && !hasBytes) {
      throw Exception("No valid files selected");
    }

    // 🚀 CLOUD-ONLY FLOW (No Backend Connection Required during upload)
    final String tempOrderId = "ORD_${DateTime.now().millisecondsSinceEpoch}";
    
    print('📤 Uploading files to Cloudinary...');
    // Pass original lists (with nulls) to maintain index alignment
    final uploadedUrls = await CloudinaryStorageService().uploadFiles(
      orderId: tempOrderId,
      files: widget.selectedFiles,
      bytes: widget.selectedBytes,
    );

    if (uploadedUrls.isEmpty) {
      throw Exception("Internal Error: File upload returned no links.");
    }

    print('💾 Saving order directly to Firestore...');
    // This generates the 6-digit pickup code and saves everything to the cloud
    final pickupCode = await FirestoreService().saveOrderDirectly(
      printSettings: widget.printSettings,
      totalPages: widget.expectedPages,
      totalPrice: widget.expectedPrice,
      fileUrls: uploadedUrls,
    );

    print('✅ Cloud Save Successful! Pickup Code: $pickupCode');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentSuccessPage(
          orderId: tempOrderId,
          pickupCode: pickupCode,
        ),
      ),
    );
  } catch (e, st) {
    print("❌ CLOUD UPLOAD ERROR: $e");
    print(st);

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
                builder: (_) => PaymentProcessingPage(
                  selectedFiles: widget.selectedFiles,
                  selectedBytes: widget.selectedBytes,
                  printSettings: widget.printSettings,
                  expectedPages: widget.expectedPages,
                  expectedPrice: widget.expectedPrice,
                ),
              ),
            );
          },
          onGoBack: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text("Processing Order"), automaticallyImplyLeading: false,),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Uploading and securing your files...\nPlease wait"),
            ],
          ),
        ),
      ),
    );
  }
}
