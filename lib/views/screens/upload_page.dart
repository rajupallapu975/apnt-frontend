import 'dart:io';

import 'package:apnt/models/file_model.dart';
import 'package:apnt/models/print_order_model.dart';
import 'package:apnt/services/firestore_service.dart';
import 'package:apnt/views/profile_page.dart';
import 'package:apnt/views/screens/history_page.dart';
import 'package:apnt/views/screens/payment_processing_page.dart';
import 'package:apnt/views/screens/print_options/print_options_page.dart';
import 'package:apnt/views/screens/widgets/web_camera_overlay.dart';
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

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Optional: Log web detection
      debugPrint("Web platform detected. Adjusting UI for monitor/laptop.");
    }
  }



  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromCamera(BuildContext context) async {
    if (kIsWeb) {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.85,
          child: WebCameraOverlay(),
        ),
      );

      if (result != null && result['bytes'] != null) {
        _handlePickedFiles([
          FileModel(
            id: DateTime.now().toString(),
            name: result['name'] ?? 'web_scan.jpg',
            path: '',
            file: null,
            bytes: result['bytes'],
            addedAt: DateTime.now(),
          ),
        ]);
        return;
      }
      return;
    }

    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      _handlePickedFiles([
        FileModel(
          id: DateTime.now().toString(),
          name: image.name,
          path: image.path,
          file: File(image.path),
          addedAt: DateTime.now(),
        ),
      ]);
    } catch (e) {
      _showNoCameraAlert();
    }
  }

  Future<void> _pickFromGallery() async {
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    final List<FileModel> picked = [];
    for (final img in images) {
      picked.add(FileModel(
        id: DateTime.now().toString(),
        name: img.name,
        path: img.path,
        file: kIsWeb ? null : File(img.path),
        bytes: kIsWeb ? await img.readAsBytes() : null,
        addedAt: DateTime.now(),
      ));
    }
    _handlePickedFiles(picked);
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result == null) return;

    final List<FileModel> picked = result.files.map((f) => FileModel(
      id: DateTime.now().toString(),
      name: f.name,
      path: f.path ?? '',
      file: f.path == null ? null : File(f.path!),
      bytes: f.bytes,
      addedAt: DateTime.now(),
    )).toList();

    _handlePickedFiles(picked);
  }

  void _showNoCameraAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.no_photography_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('No Camera Found'),
          ],
        ),
        content: const Text('We could not detect a camera on your device. Would you like to upload files from your local storage instead?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _pickFromFiles();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
            child: const Text('Upload Files', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadOptionsSheet(
        onCamera: () { Navigator.pop(context); _pickFromCamera(context); },
        onGallery: () { Navigator.pop(context); _pickFromGallery(); },
        onFiles: () { Navigator.pop(context); _pickFromFiles(); },
      ),
    );
  }

Future<void> _handlePickedFiles(List<FileModel> picked) async {
  setState(() => _isLoading = true);
  _files.clear(); _bytes.clear(); _pageIndices.clear();

  for (final f in picked) {
    _files.add(f.file);
    _bytes.add(f.bytes);
    _pageIndices.add(0);
  }

  setState(() => _isLoading = false);
  if (!mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PrintOptionsPage(
        files: _files,
        bytes: _bytes,
        pageIndices: _pageIndices,
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Files'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Order History',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔹 PLATFORM INDICATOR & WELCOME
                  if (kIsWeb)
                    _buildWebHero()
                  else
                    _buildMobileHero(),

                  const SizedBox(height: 32),

                  /// 🔹 MAIN ACTION BUTTON
                  Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload_rounded, size: 28),
                        label: const Text(
                          'UPLOAD FILES',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        onPressed: _openUploadOptions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: Colors.blue.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  
                  if (kIsWeb)
                    Center(
                      child: TextButton.icon(
                        onPressed: _pickFromFiles,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Prefer uploading local files? Click here'),
                      ),
                    ),

                  const SizedBox(height: 48),

                  /// 🔹 ACTIVE PRINTS SECTION
                  _buildActiveOrdersSection(),

                  const SizedBox(height: 32),

                  /// 🔹 EXPIRED PRINTS SECTION
                  _buildExpiredOrdersSection(),
                ],
              ),
            ),
          ),

          /// 🔄 LOADING OVERLAY
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  elevation: 8,
                  shape: CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.computer_rounded, color: Colors.blue.shade800),
              ),
              const SizedBox(width: 16),
              const Text(
                'Website Workspace',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Running on Monitor/Laptop. Optimized for webcam scanning and direct file uploads.',
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            '• Use Camera for instant document scanning\n• Drag & Drop files from your computer',
            style: TextStyle(color: Colors.blue.shade900, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.smartphone_rounded, color: Colors.indigo.shade800),
              ),
              const SizedBox(width: 16),
              const Text(
                'Mobile Companion',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Full features enabled: Quick Camera, Media Gallery, and File Picker for all your documents.',
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View All'),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
                  child: const Text('Access Archive'),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isExpired ? Colors.red.shade100 : Colors.blue.shade100, width: 1.5),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        'ORDER #${order.orderId.length >= 8 ? order.orderId.substring(0, 8).toUpperCase() : order.orderId.toUpperCase()}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[800], letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(dateFormat.format(order.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isExpired ? Colors.red.shade100 : Colors.green.shade100),
                    ),
                    child: Text(
                      isExpired ? 'EXPIRED' : 'ACTIVE',
                      style: TextStyle(color: isExpired ? Colors.red : Colors.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.grey.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pickup Token', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      order.pickupCode,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isExpired ? Colors.grey[400] : Colors.blue.shade900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (isExpired)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    onPressed: () => _reprintOrder(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    label: const Text('Reprint & Update Token', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Row(
                  children: [
                    Icon(Icons.description_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${order.totalPages} pages', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('₹${order.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                  ],
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
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Scan Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const Divider(height: 48),
                _detailRow('Reference ID', order.orderId),
                _detailRow('Pickup Token', order.pickupCode),
                _detailRow('Volume', '${order.totalPages} pages'),
                _detailRow('Grand Total', '₹${order.totalPrice.toStringAsFixed(2)}'),
                _detailRow('Issued At', DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt)),
                _detailRow('Expiration', DateFormat('MMM dd, yyyy • hh:mm a').format(order.expiresAt)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('CLOSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

Future<void> _reprintOrder(PrintOrderModel order) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Request Reprint?'),
      content: Text('Re-opening order for ${order.totalPages} pages.\nA new payment of ₹${order.totalPrice.toStringAsFixed(2)} is required.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white)),
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
/// 🔽 REFINED BOTTOM SHEET FOR WEBSITE & MOBILE
/// =======================================================

class _UploadOptionsSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFiles;

  const _UploadOptionsSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 24),
          const Row(
            children: [
              Text('Upload Files', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Select a preferred method to provide your documents.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 32),
          if (kIsWeb)
            Row(
              children: [
                Expanded(child: _buildFeature(icon: Icons.camera_alt_rounded, label: 'Camera Scanner', onTap: onCamera, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildFeature(icon: Icons.upload_file_rounded, label: 'Media Picker', onTap: onFiles, color: Colors.indigo)),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildFeature(icon: Icons.camera_enhance_rounded, label: 'Camera', onTap: onCamera, color: Colors.pink)),
                const SizedBox(width: 12),
                Expanded(child: _buildFeature(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: onGallery, color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildFeature(icon: Icons.grid_view_rounded, label: 'Files', onTap: onFiles, color: Colors.purple)),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeature({required IconData icon, required String label, required VoidCallback onTap, required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}


