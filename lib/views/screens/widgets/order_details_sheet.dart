import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../../../models/print_order_model.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/primary_button.dart';
import '../payment_processing_page.dart';

class OrderDetailsSheet extends StatelessWidget {
  final PrintOrderModel order;

  const OrderDetailsSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final files = order.printSettings['files'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDER DETAILS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${order.orderId.substring(0, 12).toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: (order.reason ?? order.status.name).toUpperCase(),
                type: order.status == OrderStatus.active ? StatusType.active : StatusType.success,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CREATED ON',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 0.5),
                  ),
                  Text(
                    dateFormat.format(order.createdAt),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EXPIRES ON',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.error, letterSpacing: 0.5),
                  ),
                  Text(
                    dateFormat.format(order.expiresAt),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Files Section
          Text(
            'FILES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...files.map((f) => _buildFileItem(f)),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Pickup Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                if (order.isXerox && order.xeroxId != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'XEROX SHOP ID',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.xeroxId!,
                            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 6),
                          ),
                        ],
                      ),
                      if (order.printSettings['shopName'] != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'DESTINATION',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                              ),
                              Text(
                                order.printSettings['shopName'],
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PICKUP CODE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.pickupCode,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryBlue,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL AMOUNT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${order.totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (order.printSettings['watermarking'] == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SECURITY WATERMARK VERIFIED: ${order.printSettings['watermarkCode']}',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
          
          if (order.isActive) ...[
            PrimaryButton(
              label: 'REPRINT THIS ORDER',
              icon: Icons.replay_rounded,
              onPressed: () => _handleReprint(context),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildFileItem(Map<String, dynamic> fileData) {
    final fileName = fileData['fileName'] ?? 'Unknown File';
    final size = fileData['fileSizeKB'] ?? '0.0';
    final pages = fileData['pageCount'] ?? 1;
    final color = fileData['color'] ?? 'BW';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description_outlined, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$size KB • $pages ${pages == 1 ? 'page' : 'pages'} • $color',
                  style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (order.status == OrderStatus.completed)
             const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
        ],
      ),
    );
  }

  Future<void> _handleReprint(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reprint Documents'),
        content: Text('Estimated Total: ₹${order.totalPrice.toStringAsFixed(2)}\n\nA fresh pickup code will be generated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final List<File> reprintFiles = [];
    final List<Uint8List> reprintBytes = [];
    final List<String> filenames = [];

    if (order.localFilePaths.isNotEmpty) {
      for (final filePath in order.localFilePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          reprintFiles.add(file);
          reprintBytes.add(await file.readAsBytes());
          filenames.add(path.basename(filePath));
        }
      }
    }

    if (reprintFiles.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source files were not found on this device.')));
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentProcessingPage(
          selectedFiles: reprintFiles,
          selectedBytes: reprintBytes,
          filenames: filenames,
          printSettings: order.printSettings,
          expectedPages: order.totalPages,
          expectedPrice: order.totalPrice,
          initialFileUrls: order.fileUrls,
          initialPublicIds: order.publicIds,
        ),
      ),
    );
  }
}
