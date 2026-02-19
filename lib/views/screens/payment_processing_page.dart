// ============================================================================
// PAYMENT PROCESSING PAGE (UPDATED - BACKEND CONTROLLED)
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:apnt/services/firestore_service.dart';
import 'package:apnt/services/cloudinary_storage_service.dart';
import 'package:apnt/services/backend_service.dart';
import 'package:apnt/services/local_storage_service.dart';
import 'package:apnt/models/print_order_model.dart';
import 'package:path/path.dart' as path;
import 'package:apnt/views/screens/payment_error_page.dart';
import 'package:flutter/material.dart';
import 'payment_success_page.dart';

class PaymentProcessingPage extends StatefulWidget {
  final List<File?> selectedFiles;
  final List<Uint8List?> selectedBytes;
  final List<String> filenames; // 🔥 REQUIRED: Pass names from FileModel
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
  String _status = "Preparing files...";

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  // ==========================================================================
  // MAIN PROCESSING WORKFLOW
  // ==========================================================================
  Future<void> _startProcessing() async {
    setState(() => _status = "Locking memory...");
    try {
      // STEP 1: VALIDATE FILES
      final hasFiles =
          widget.selectedFiles.any((f) => f != null);
      final hasBytes =
          widget.selectedBytes.any((b) => b != null);

      if (!hasFiles && !hasBytes) {
        throw Exception("No valid files selected");
      }

      // STEP 1: CREATE ORDER VIA BACKEND (Generates 6-digit code & saves to Firebase)
      setState(() => _status = "Generating 6-digit code...");
      print('📡 Finalizing order and generating pickup code...');
      final backendResult = await BackendService()
          .createOrder(widget.printSettings);

      final String orderId = backendResult.orderId;
      final String pickupCode = backendResult.pickupCode;

      print('✅ Order Created: $orderId');
      print('🔑 Pickup Code: $pickupCode');

      // STEP 2: UPLOAD FILES TO CLOUDINARY (Using the generated Pickup Code)
      setState(() => _status = "Uploading files to cloud...");
      print('📤 Uploading files...');

      final cloudinaryResult = await CloudinaryStorageService().uploadFiles(
        pickupCode: pickupCode,
        files: widget.selectedFiles,
        bytes: widget.selectedBytes,
        filenames: widget.filenames, // Use the real names from UploadPage
      );

      final uploadedUrls = cloudinaryResult['urls']!;
      final publicIds = cloudinaryResult['publicIds']!;

      if (uploadedUrls.isEmpty) {
        throw Exception("File upload failed - no URLs returned");
      }

      print('✅ Files uploaded successfully');

      // STEP 3: SAVE FILES LOCALLY FOR REPRINTING
      setState(() => _status = "Saving files locally...");
      print('💾 Saving files locally...');
      final List<String> localPaths = [];
      final storage = LocalStorageService();

      for (int i = 0; i < widget.selectedFiles.length; i++) {
        final File? file = widget.selectedFiles[i];
        final Uint8List? fileBytes = widget.selectedBytes[i];

        if (file == null && fileBytes == null) continue;

        final bytes = fileBytes ?? await file!.readAsBytes();
        final String nameToUse = (widget.filenames.length > i) 
            ? widget.filenames[i] 
            : 'file_${i + 1}_$orderId';

        final localPath = await storage.saveFileLocally(nameToUse, bytes);
        localPaths.add(localPath);
      }

      // STEP 4: ATTACH CLOUD DATA TO FIRESTORE ORDER
      setState(() => _status = "Finalizing order...");
      await FirestoreService().attachFilesToOrder(
        orderId: orderId,
        fileUrls: uploadedUrls,
        publicIds: publicIds,
        localFilePaths: localPaths,
      );

      // STEP 5: ARCHIVE LOCALLY
      final freshOrder = await FirestoreService().getOrder(orderId);
      if (freshOrder != null) {
        await storage.saveOrderLocally(freshOrder);
      }

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
                    selectedFiles: widget.selectedFiles,
                    selectedBytes: widget.selectedBytes,
                    filenames: widget.filenames,
                    printSettings: widget.printSettings,
                    expectedPages: widget.expectedPages,
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
        body: Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 25),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "This may take a moment based on your connection",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
