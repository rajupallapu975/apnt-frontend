import 'dart:io';

import 'package:apnt/models/file_model.dart';
import 'package:apnt/models/print_order_model.dart';
import 'package:apnt/services/firestore_service.dart';
import 'package:apnt/views/profile_page.dart';
import 'package:apnt/views/screens/history_page.dart';
import 'package:apnt/views/screens/payment_processing_page.dart';
import 'package:apnt/views/screens/print_options/print_options_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';



class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();

  final List<File?> _files = [];
  final List<Uint8List?> _bytes = [];
  final List<int> _pageIndices = []; // Track page index for PDFs



  void _openUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UploadOptionsSheet(
        onFilesPicked: _handlePickedFiles,
      ),
    );
  }

Future<void> _handlePickedFiles(List<FileModel> picked) async {
  Navigator.pop(context);
  setState(() => _isLoading = true);

  // 🔥 CLEAR OLD DATA (VERY IMPORTANT)
  _files.clear();
  _bytes.clear();
  _pageIndices.clear();

  for (final f in picked) {
    // ---------- PDF ----------
    if (f.name.toLowerCase().endsWith('.pdf')) {
      // ✅ PDF: Keep as ONE item (backend will handle rendering)
      // On web: file will be null, bytes will have data
      // On mobile: file will have data, bytes will be null
      _files.add(f.file);
      _bytes.add(f.bytes);
      _pageIndices.add(0); // Not used for PDFs anymore
    }
    // ---------- IMAGE ----------
    else {
      _files.add(f.file);
      _bytes.add(f.bytes);
      _pageIndices.add(0);
    }
  }

  setState(() => _isLoading = false);

  if (!mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PrintOptionsPage(
        files: _files,
        bytes: _bytes,
        pageIndices: _pageIndices, // ✅ PASS PAGE INDICES
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Order History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfilePage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// 🔹 UPLOAD BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _openUploadOptions,
                    child: const Text(
                      'Upload Files',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// 🔹 ACTIVE PRINTS SECTION
                _buildActiveOrdersSection(),

                const SizedBox(height: 24),

                /// 🔹 EXPIRED PRINTS SECTION
                _buildExpiredOrdersSection(),
              ],
            ),
          ),

          /// 🔄 LOADING OVERLAY
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Build Active Orders Section
  Widget _buildActiveOrdersSection() {
    return StreamBuilder<List<PrintOrderModel>>(
      stream: _firestoreService.getActiveOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Deliveries',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryPage(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...orders.take(3).map((order) => _buildOrderCard(order, isActive: true)),
          ],
        );
      },
    );
  }

  /// Build Expired Orders Section
  Widget _buildExpiredOrdersSection() {
    return FutureBuilder<List<PrintOrderModel>>(
      future: _firestoreService.getArchivedOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Expired Prints',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryPage(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...orders.take(3).map((order) => _buildOrderCard(order, isExpired: true)),
          ],
        );
      },
    );
  }

  /// Build Order Card
  Widget _buildOrderCard(PrintOrderModel order, {bool isActive = false, bool isExpired = false}) {
    final dateFormat = DateFormat('MMM dd, hh:mm a');

    return InkWell(
      onTap: () => _showOrderDetails(order),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isExpired ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: ${order.orderId.length >= 10 ? order.orderId.substring(0, 10).toUpperCase() : order.orderId.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        dateFormat.format(order.createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isExpired ? 'EXPIRED' : 'ACTIVE',
                      style: TextStyle(
                        color: isExpired ? Colors.red : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red.withOpacity(0.05) : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pickup Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(
                      order.pickupCode,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isExpired ? Colors.red : Colors.blue.shade900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (isExpired)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _reprintOrder(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Reprint', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                )
              else
                Text(
                  '${order.totalPages} pages • ₹${order.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(PrintOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 32),
                _detailRow('Order ID', order.orderId),
                _detailRow('Pickup Code', order.pickupCode),
                _detailRow('Total Pages', '${order.totalPages}'),
                _detailRow('Total Price', '₹${order.totalPrice.toStringAsFixed(2)}'),
                _detailRow('Created', DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt)),
                _detailRow('Expires', DateFormat('MMM dd, yyyy • hh:mm a').format(order.expiresAt)),
                const SizedBox(height: 20),
                const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(order.status.name.toUpperCase(), style: const TextStyle(color: Colors.blue)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

Future<void> _reprintOrder(
    PrintOrderModel order) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reprint Order'),
      content: Text(
        'Pages: ${order.totalPages}\n'
        'Price: ₹${order.totalPrice.toStringAsFixed(2)}\n\n'
        'Proceed to payment?',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, true),
          child: const Text('Proceed'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentProcessingPage(
        selectedFiles: [],
        selectedBytes: [],
        printSettings: order.printSettings,
        expectedPages: order.totalPages,
        expectedPrice: order.totalPrice,
      ),
    ),
  );
}


}

/// =======================================================
/// 🔽 BOTTOM SHEET
/// =======================================================

class _UploadOptionsSheet extends StatelessWidget {
  final ImagePicker _picker = ImagePicker();
  final Function(List<FileModel>) onFilesPicked;

  _UploadOptionsSheet({required this.onFilesPicked});

  Future<void> _pickFromCamera(BuildContext context) async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    onFilesPicked([
      FileModel(
        id: DateTime.now().toString(),
        name: image.name,
        path: image.path,
        file: kIsWeb ? null : File(image.path),
        bytes: kIsWeb ? await image.readAsBytes() : null,
        addedAt: DateTime.now(),
      ),
    ]);
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    onFilesPicked(
      await Future.wait(
        images.map((img) async => FileModel(
              id: DateTime.now().toString(),
              name: img.name,
              path: img.path,
              file: kIsWeb ? null : File(img.path),
              bytes: kIsWeb ? await img.readAsBytes() : null,
              addedAt: DateTime.now(),
            )),
      ),
    );
  }

  Future<void> _pickFromFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result == null) return;

    onFilesPicked(
      result.files
          .map(
            (f) => FileModel(
              id: DateTime.now().toString(),
              name: f.name,
              path: f.path ?? '',
              file: f.path == null ? null : File(f.path!),
              bytes: f.bytes,
              addedAt: DateTime.now(),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _option(Icons.camera_alt, 'Camera', () => _pickFromCamera(context)),
        _option(Icons.photo_library, 'Gallery', () => _pickFromGallery(context)),
        _option(Icons.folder, 'Media Picker', () => _pickFromFiles(context)),
      ],
    );
  }

  Widget _option(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
