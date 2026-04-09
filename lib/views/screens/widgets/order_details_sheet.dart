import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/print_order_model.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/primary_button.dart';
import '../../../xerox_shop/xerox_shop_viewmodel.dart';
import '../../../xerox_shop/xerox_shop_model.dart';
class OrderDetailsSheet extends StatelessWidget {
  final PrintOrderModel order;
  const OrderDetailsSheet({super.key, required this.order});
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    // 🚀 LIVE STREAM: Listen specifically to this order to reveal code instantly
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(order.isXerox ? 'xerox_orders' : 'orders')
          .doc(order.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        // Fallback to the passed 'order' object if stream is loading/empty
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        
        // Use live data from Firestore if available, otherwise fallback to the initial 'order' state
        final bool liveRevealed = data != null 
            ? (data['codeRevealed'] == true || data['scanned'] == true) 
            : (order.codeRevealed || order.scanned);

        final String livePickupCode = data != null ? (data['pickupCode'] ?? order.pickupCode).toString() : order.pickupCode;
        final String? liveStatus = data != null ? data['orderStatus'] : order.orderStatus;
        
        final bool showCode = !order.isXerox || liveRevealed;
        // Dynamically fetch phone number if available from the Shop ViewModel
        String? dynamicPhone = order.printSettings['shopPhone'];
        if (order.isXerox && order.shopId != null) {
          try {
            final xeroxVM = context.watch<XeroxShopViewModel>();
            final matchedShop = xeroxVM.shops.firstWhere((s) => s.id == order.shopId);
            if (matchedShop.phoneNumber?.isNotEmpty == true) {
              dynamicPhone = matchedShop.phoneNumber;
            }
          } catch (_) {}
        }
        String? formattedPhone;
        if (dynamicPhone != null && dynamicPhone.isNotEmpty && dynamicPhone != 'N/A') {
          var c = dynamicPhone.trim();
          if (c.startsWith('0')) c = c.substring(1).trim();
          formattedPhone = c.startsWith('+') ? c : '+91 $c';
        }
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
              const SizedBox(height: 16),
              // ── Header (Watermark style) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER DETAILS',
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w900,
                          color: AppColors.textTertiary, letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (order.customId ?? order.pickupCode).toUpperCase(), 
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 1),
                      ),
                    ],
                  ),
                  StatusBadge(
                    label: (order.reason ?? order.status.name).toUpperCase(),
                    type: order.status == OrderStatus.active ? StatusType.active : StatusType.success,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Dates (Compact Row) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoSegment('CREATED ON', dateFormat.format(order.createdAt), AppColors.textTertiary),
                  _infoSegment('EXPIRES ON', dateFormat.format(order.expiresAt), AppColors.error),
                ],
              ),
              const SizedBox(height: 16),
              
              // ── Xerox Print Status (Real-time from Firestore) ──
              if (order.isXerox) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: (liveStatus == 'printing completed' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (liveStatus == 'printing completed' ? Colors.green : Colors.orange).withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        liveStatus == 'printing completed' ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                        size: 18,
                        color: liveStatus == 'printing completed' ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              (liveStatus ?? 'NOT PRINTED YET').toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: liveStatus == 'printing completed' ? Colors.green : Colors.orange,
                              ),
                            ),
                            Text(
                              liveStatus == 'printing completed'
                                  ? 'Your documents are ready. Visit shop now.'
                                  : 'Shop will print this soon.',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Divider(),
              const SizedBox(height: 16),
              // ── Xerox Shop Details (Call & Info) ──
              if (order.isXerox) ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showShopDetails(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('XEROX SHOP', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(order.shopName ?? 'Xerox Shop', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                if (formattedPhone != null) ...[
                                  const SizedBox(width: 6),
                                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.textTertiary, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(formattedPhone, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (formattedPhone != null)
                      IconButton(
                        onPressed: () async {
                          final Uri launchUri = Uri(scheme: 'tel', path: formattedPhone!.replaceAll(' ', ''));
                          if (await canLaunchUrl(launchUri)) {
                            await launchUrl(launchUri);
                          }
                        },
                        icon: const Icon(Icons.call_rounded, color: AppColors.success, size: 22),
                        style: IconButton.styleFrom(backgroundColor: AppColors.success.withValues(alpha: 0.1), padding: const EdgeInsets.all(10)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
              ],
              // ── Files Section ──
              Text('FILES', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: order.fileUrls.length,
                  itemBuilder: (context, i) {
                    final fileName = order.filenames.length > i ? order.filenames[i] : 'File ${i + 1}';
                    final url = order.fileUrls[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_rounded, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fileName,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          // ── Print Badges (Color, Landscape, etc.) ──
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _settingBadge(
                                order.getIsColor(i) ? 'COLOR' : 'B&W',
                                order.getIsColor(i) ? Colors.pink : AppColors.textPrimary,
                              ),
                              _settingBadge(
                                order.getOrientation(i).toUpperCase(),
                                AppColors.primaryBlue,
                              ),
                              if (order.getIsDuplex(i))
                                _settingBadge('DOUBLE SIDED', Colors.indigo),
                              _settingBadge(
                                '${order.getCopies(i)} COPIES',
                                AppColors.textSecondary,
                              ),
                              _settingBadge(
                                '${order.getPageCount(i)} PAGES',
                                AppColors.success,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              // ── Pickup Code (Revealed via QR Scan) ──
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: order.isXerox ? AppColors.success.withValues(alpha: 0.05) : AppColors.primaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (order.isXerox ? AppColors.success : AppColors.primaryBlue).withValues(alpha: 0.15)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
                    child: !showCode ? 
                      Column(
                        key: const ValueKey('hidden'),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_person_rounded, size: 16, color: AppColors.textTertiary),
                              const SizedBox(width: 8),
                              Text('SCAN QR TO REVEAL CODE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textTertiary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('• • • • • •', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 8)),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Scan shop QR to reveal code and collect your documents.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600, height: 1.5),
                            ),
                          ),
                        ],

                      ) :
                      Column(
                        key: const ValueKey('revealed'),
                        children: [
                          Text('PICKUP CODE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: (order.isXerox ? AppColors.success : AppColors.primaryBlue), letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(livePickupCode, style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: (order.isXerox ? AppColors.success : AppColors.primaryBlue), letterSpacing: 8)),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => Clipboard.setData(ClipboardData(text: livePickupCode)),
                                icon: Icon(Icons.copy_rounded, size: 18, color: (order.isXerox ? AppColors.success : AppColors.primaryBlue)),
                              ),
                            ],
                          ),
                       ],
                      ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryLabel('FILES', '${order.fileUrls.length}'),
                  _summaryLabel('PAGES', '${order.totalPages}'),
                  _summaryLabel('TOTAL', '₹${order.totalPrice.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 16),
              if (order.status == OrderStatus.active)
                PrimaryButton(
                  label: 'GO BACK',
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
        );
      }
    );
  }
  Widget _infoSegment(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
        Text(value, style: GoogleFonts.manrope(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _settingBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color.withValues(alpha: 0.8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _summaryLabel(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textTertiary)),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      ],
    );
  }
  void _showShopDetails(BuildContext context) {
    final shopId = order.shopId;
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop identifier not found.')));
      return;
    }
    final xeroxVM = context.read<XeroxShopViewModel>();
    XeroxShopModel? shop;
    try {
      shop = xeroxVM.shops.firstWhere((s) => s.id == shopId);
    } catch (_) {}
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
              const Text('Fetching shop details...'),
            ],
          ),
        ),
      );
      
      xeroxVM.fetchShops().then((_) {
        if (context.mounted) {
           Navigator.pop(context); 
           _showShopDetails(context); 
        }
      });
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
             if (shop.phoneNumber != null && shop.phoneNumber!.isNotEmpty && shop.phoneNumber != 'N/A') ...[
               const SizedBox(height: 16),
               _detailRow(Icons.phone_rounded, 'MOBILE NUMBER', shop.phoneNumber!),
             ],
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
