import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/print_order_model.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/primary_button.dart';
import '../payment_processing_page.dart';
import '../../../xerox_shop/xerox_shop_viewmodel.dart';
import '../../../xerox_shop/xerox_shop_model.dart';

class OrderDetailsSheet extends StatelessWidget {
  final PrintOrderModel order;

  const OrderDetailsSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    // For Xerox orders: code is only shown after QR scan (codeRevealed == true)
    final bool showCode = !order.isXerox || order.codeRevealed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER DETAILS',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w900,
                        color: AppColors.textTertiary, letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${order.orderId.substring(0, order.orderId.length > 12 ? 12 : order.orderId.length).toUpperCase()}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                StatusBadge(
                  label: (order.reason ?? order.status.name).toUpperCase(),
                  type: order.status == OrderStatus.active ? StatusType.active : StatusType.success,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Dates ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CREATED ON', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 0.5)),
                    Text(dateFormat.format(order.createdAt), style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('EXPIRES ON', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.error, letterSpacing: 0.5)),
                    Text(dateFormat.format(order.expiresAt), style: GoogleFonts.manrope(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),
            
            // ── Xerox Print Status (Real-time) ──
            if (order.isXerox) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: (order.isPrintingCompleted ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (order.isPrintingCompleted ? Colors.green : Colors.orange).withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (order.isPrintingCompleted ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        order.isPrintingCompleted ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                        size: 20,
                        color: order.isPrintingCompleted ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRINTING STATUS',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (order.orderStatus ?? 'NOT PRINTED YET').toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: order.isPrintingCompleted ? Colors.green : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.isPrintingCompleted
                                ? 'Your documents are ready. Visit the shop to collect.'
                                : 'The shop has received your order and will print it soon.',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Divider(),
            const SizedBox(height: 16),

            // ── Shop Details (Xerox only) ──
            if (order.isXerox) ...[
              Text('XEROX SHOP', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _showShopDetails(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.store_rounded, color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.shopName ?? 'Xerox Shop',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  'TAP TO VIEW SHOP DETAILS',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 0.5),
                                ),
                                if (order.printSettings['shopPhone'] != null) ...[
                                  Text(' • ', style: TextStyle(color: AppColors.success.withValues(alpha: 0.5))),
                                  Text(
                                    order.printSettings['shopPhone'].toString(),
                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 0.5),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.success),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // ── Files Section (Uploaded from Mobile) ──
            Text('UPLOADED FILES FROM MOBILE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            if (order.fileUrls.isNotEmpty)
              ...order.fileUrls.asMap().entries.map((entry) {
                final i = entry.key;
                final url = entry.value;
                final fileName = order.filenames.length > i ? order.filenames[i] : 'File ${i + 1}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          // Fix for Cloudinary URLs missing extensions for PDF viewing
                          String finalUrl = url;
                          final ext = path.extension(fileName).toLowerCase();
                          if (url.contains('cloudinary.com') && ext.isNotEmpty && !url.toLowerCase().endsWith(ext)) {
                            finalUrl = '$url$ext';
                          }

                          final uri = Uri.tryParse(finalUrl);
                          if (uri != null) {
                            try {
                              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!launched && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Could not open the file. Try another Browser."), behavior: SnackBarBehavior.floating),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error opening file: $e"), behavior: SnackBarBehavior.floating),
                                );
                              }
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // ── Pickup Code / ID Section ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: order.isXerox
                    ? AppColors.success.withValues(alpha: 0.05)
                    : AppColors.primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: order.isXerox
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.primaryBlue.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  // Xerox: show locked or revealed code
                  if (order.isXerox) ...[
                    if (!showCode) ...[
                      // 🔒 Code not yet revealed
                      Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pickup code locked — scan the shop\'s QR code to reveal it',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• • • •',
                        style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 10),
                      ),
                    ] else ...[
                      // 🔓 Code revealed
                      Text('PICKUP CODE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            order.pickupCode,
                            style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 10),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: order.pickupCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied!'), behavior: SnackBarBehavior.floating),
                              );
                            },
                            child: const Icon(Icons.copy_rounded, color: AppColors.success, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, color: AppColors.success, size: 14),
                          const SizedBox(width: 6),
                          Text('Verified at shop', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                        ],
                      ),
                    ],
                  ],

                  // Autonomous: always show pickup code
                  if (!order.isXerox)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PICKUP CODE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryBlue, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              order.pickupCode,
                              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryBlue, letterSpacing: 4),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('TOTAL AMOUNT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('₹${order.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                          ],
                        ),
                      ],
                    ),

                  // Xerox: total paid row
                  if (order.isXerox) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TOTAL PAID', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary)),
                        Text('₹${order.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ],
                    ),
                  ],

                  ],
                
              ),
            ),

            const SizedBox(height: 24),

            if (order.isActive && !order.isXerox) ...[
              PrimaryButton(
                label: 'REPRINT THIS ORDER',
                icon: Icons.replay_rounded,
                onPressed: () => _handleReprint(context),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
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
    Navigator.pop(context);
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

  void _showShopDetails(BuildContext context) {
    final shopId = order.shopId;
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop identifier not found.')));
      return;
    }

    final xeroxVM = context.read<XeroxShopViewModel>();
    
    // Find shop in current list or show error
    XeroxShopModel? shop;
    try {
      shop = xeroxVM.shops.firstWhere((s) => s.id == shopId);
    } catch (_) {
      // Not loaded or not found
    }

    if (shop == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Loading Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Fetching shop details...', style: GoogleFonts.inter()),
            ],
          ),
        ),
      );
      
      // Attempt to fetch if not loaded
      xeroxVM.fetchShops().then((_) {
        if (context.mounted) {
           Navigator.pop(context); // Close loading dialog
           _showShopDetails(context); // Try again
        }
      });
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                shop!.name,
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: shop.isCurrentlyOpen ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                shop.isCurrentlyOpen ? 'OPEN' : 'CLOSED',
                style: GoogleFonts.inter(
                  fontSize: 10, 
                  fontWeight: FontWeight.w900, 
                  color: shop.isCurrentlyOpen ? AppColors.success : AppColors.error
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _detailRow(Icons.location_on_rounded, 'LOCATION', shop.address),
             const SizedBox(height: 16),
             _detailRow(Icons.phone_rounded, 'MOBILE NUMBER', shop.phoneNumber ?? 'N/A'),
             const SizedBox(height: 16),
             _detailRow(Icons.access_time_filled_rounded, 'HOURS', '${shop.openingTime} - ${shop.closingTime}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CLOSE', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textTertiary)),
          ),
          if (shop.phoneNumber != null && shop.phoneNumber != 'N/A')
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${shop!.phoneNumber}')),
              icon: const Icon(Icons.call_rounded, size: 16),
              label: const Text('CALL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
