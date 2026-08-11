import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/print_order_model.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../xerox_shop/xerox_shop_viewmodel.dart';
import '../../../services/firestore_service.dart';
import 'print_progress_tracker.dart';

class OrderDetailsSheet extends StatelessWidget {
  final PrintOrderModel order;
  const OrderDetailsSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final xeroxVM = context.read<XeroxShopViewModel>();
    if (order.isXerox && xeroxVM.shops.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        xeroxVM.fetchShops();
      });
    }
    // 🚀 LIVE STREAM: Listen specifically to this order to reveal code instantly
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.getFirestore(order.projectId)
          .collection(order.isXerox ? 'xerox_orders' : 'orders')
          .doc(order.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        // Fallback to the passed 'order' object if stream is loading/empty
        final data = snapshot.data?.data() as Map<String, dynamic>?;

        final String? liveStatus = data != null ? data['orderStatus'] : order.orderStatus;
        final bool isPrinted = liveStatus == 'printing completed';

        // Dynamically fetch phone number if available from the Shop ViewModel
        String? dynamicPhone = order.printSettings['shopPhone'];
        String? dynamicAddress = order.printSettings['shopAddress'];
        if (order.isXerox && order.shopId != null) {
          try {
            final xeroxVM = context.watch<XeroxShopViewModel>();
            final matchedShop = xeroxVM.shops.firstWhere((s) => s.id == order.shopId);
            if (matchedShop.phoneNumber?.isNotEmpty == true) {
              dynamicPhone = matchedShop.phoneNumber;
            }
            if (matchedShop.address.isNotEmpty) {
              dynamicAddress = matchedShop.address;
            }
          } catch (_) {}
        }
        String? formattedPhone;
        if (dynamicPhone != null && dynamicPhone.isNotEmpty && dynamicPhone != 'N/A') {
          var c = dynamicPhone.trim();
          if (c.startsWith('0')) c = c.substring(1).trim();
          formattedPhone = c.startsWith('+') ? c : '+91 $c';
        }
        final bool hasAddress =
            dynamicAddress != null && dynamicAddress.isNotEmpty && dynamicAddress != 'N/A';

        final media = MediaQuery.of(context);
        return Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + media.padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER DETAILS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    order.displayId,
                                    maxLines: 1,
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded,
                                        size: 13, color: AppColors.textTertiary),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        dateFormat.format(order.createdAt),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusBadge(
                            label: (order.status == OrderStatus.completed || order.isPicked || order.orderDone)
                                ? 'COMPLETED'
                                : (order.reason ?? order.status.name).toUpperCase(),
                            type: (order.status == OrderStatus.completed || order.isPicked || order.orderDone)
                                ? StatusType.success
                                : (order.status == OrderStatus.active
                                    ? StatusType.active
                                    : StatusType.success),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 🖨️ Printing Process Timeline Tracker (Active Orders Only)
                      if (!(order.status == OrderStatus.completed || order.isPicked || order.orderDone)) ...[
                        PrintProgressTracker(
                          status: order.status,
                          orderStatus: liveStatus ?? order.orderStatus,
                          isPrintingCompleted: isPrinted || order.isPrintingCompleted,
                          isPicked: order.isPicked,
                          isCompleted: false,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Live Print Status (Xerox only) ──
                      if (order.isXerox) ...[
                        Builder(
                          builder: (context) {
                            final bool isOrderDone = order.status == OrderStatus.completed || order.isPicked || order.orderDone;
                            final bool isReady = isPrinted || order.isPrintingCompleted || isOrderDone;
                            final Color statusCol = isReady ? AppColors.success : Colors.orange;

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: statusCol.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: statusCol.withValues(alpha: 0.25),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: statusCol.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isReady
                                          ? Icons.check_circle_rounded
                                          : Icons.hourglass_bottom_rounded,
                                      size: 22,
                                      color: statusCol,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                         final String norm = (liveStatus ?? order.orderStatus ?? '').toLowerCase().trim();
                                         final bool isPrinting = norm == 'printing' || norm == 'in_progress' || norm == 'in progress';
                                         final String statusTitle = isOrderDone
                                            ? 'ORDER COMPLETED'
                                            : (isReady
                                                ? 'READY TO COLLECT'
                                                : (isPrinting
                                                    ? 'PRINTING IN PROGRESS'
                                                    : 'ORDER PLACED'));
                                        final String statusSubtitle = isOrderDone
                                            ? 'Prints collected successfully at ${order.shopName ?? "Xerox Shop"}.'
                                            : (isReady
                                                ? 'Your documents are ready. Visit shop now.'
                                                : (isPrinting
                                                    ? 'Shopkeeper is printing your order.'
                                                    : 'Order received. Waiting for shopkeeper to start printing.'));

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              statusTitle,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.3,
                                                color: statusCol,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              statusSubtitle,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Selected Service ──
                      if (order.serviceName != null) ...[
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instanceFor(app: Firebase.app('zikrinter'))
                              .collection('zikrinter')
                              .doc(order.serviceId ?? 'ZHwQd18Vy08TZkyBFXjB')
                              .snapshots(),
                          builder: (context, serviceSnap) {
                            String? imageUrl;
                            if (serviceSnap.hasData && serviceSnap.data!.exists) {
                              final sData =
                                  serviceSnap.data!.data() as Map<String, dynamic>?;
                              if (sData != null) {
                                imageUrl = sData['imageUrl'] as String?;
                                if (imageUrl == null || imageUrl.isEmpty) {
                                  final images = sData['images'];
                                  if (images is List && images.isNotEmpty) {
                                    imageUrl = images[0] as String?;
                                  }
                                }
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? Image.network(imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.print_rounded,
                                                  color: AppColors.primaryBlue))
                                          : const Icon(Icons.print_rounded,
                                              color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SELECTED SERVICE',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textTertiary,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          order.serviceName!.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Xerox Shop card (Call & Directions) ──
                      if (order.isXerox) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border:
                                Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.store_rounded,
                                    color: AppColors.primaryBlue, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'XEROX SHOP',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textTertiary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      order.shopName ?? 'Xerox Shop',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (formattedPhone != null && !(order.status == OrderStatus.completed || order.isPicked || order.orderDone)) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_rounded,
                                              size: 13, color: AppColors.textSecondary),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              formattedPhone!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (hasAddress) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_rounded,
                                              size: 13, color: AppColors.textSecondary),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              dynamicAddress!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  if (formattedPhone != null && !(order.status == OrderStatus.completed || order.isPicked || order.orderDone))
                                    _actionCircle(
                                      icon: Icons.call_rounded,
                                      color: AppColors.success,
                                      onTap: () async {
                                        final Uri launchUri = Uri(
                                            scheme: 'tel',
                                            path: formattedPhone!.replaceAll(' ', ''));
                                        if (await canLaunchUrl(launchUri)) {
                                          await launchUrl(launchUri);
                                        }
                                      },
                                    ),
                                  if (formattedPhone != null && !(order.status == OrderStatus.completed || order.isPicked || order.orderDone) && hasAddress)
                                    const SizedBox(height: 8),
                                  if (hasAddress)
                                    _actionCircle(
                                      icon: Icons.directions_rounded,
                                      color: AppColors.primaryBlue,
                                      onTap: () async {
                                        String url;
                                        try {
                                          final xeroxVM = context.read<XeroxShopViewModel>();
                                          final matched = xeroxVM.shops.firstWhere((s) => s.id == order.shopId);
                                          url = matched.mapsUrl;
                                        } catch (_) {
                                          url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(dynamicAddress!)}';
                                        }
                                        if (await canLaunchUrl(Uri.parse(url))) {
                                          await launchUrl(Uri.parse(url),
                                              mode: LaunchMode.externalApplication);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Files ──
                      _sectionLabel('FILES  •  ${order.displayFileUrls.length}'),
                      const SizedBox(height: 10),
                      ...List.generate(order.displayFileUrls.length, (i) {
                        final fileName =
                            order.filenames.length > i ? order.filenames[i] : 'File ${i + 1}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.description_rounded,
                                        size: 16, color: AppColors.primaryBlue),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
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
                                runSpacing: 6,
                                children: [
                                  _settingBadge(
                                    order.getIsColor(i) ? 'COLOR' : 'B&W',
                                    order.getIsColor(i) ? Colors.pink : AppColors.textPrimary,
                                  ),
                                  _settingBadge(
                                    order.getOrientation(i).toUpperCase(),
                                    AppColors.primaryBlue,
                                  ),
                                  _settingBadge(
                                    order.getIsDuplex(i) ? 'TWO SIDED (DOUBLE)' : 'ONE SIDED (SINGLE)',
                                    order.getIsDuplex(i) ? Colors.indigo : AppColors.primaryBlue,
                                  ),
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
                      }),
                      const SizedBox(height: 10),

                      if (!(order.status == OrderStatus.completed || order.isPicked || order.orderDone)) ...[
                        // ── Print Instructions Guide ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.tips_and_updates_rounded,
                                      size: 15, color: AppColors.primaryBlue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'HOW TO COLLECT YOUR PRINTS',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryBlue,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildStepRow(1, 'Go to selected shop'),
                              _buildStepRow(2, 'Scan the Zikrint QR'),
                              _buildStepRow(3, 'Code is revealed'),
                              _buildStepRow(4, 'Show the code to the shopkeeper'),
                              _buildStepRow(5, 'Collect the prints', isLast: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Order Summary strip ──
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlack,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _summaryLabel('FILES', '${order.displayFileUrls.length}'),
                            _summaryDivider(),
                            _summaryLabel('PAGES', '${order.totalPages}'),
                            _summaryDivider(),
                            _summaryLabel('TOTAL', '₹${order.totalPrice.toStringAsFixed(0)}',
                                highlight: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionCircle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: AppColors.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStepRow(int stepNumber, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color.withValues(alpha: 0.85),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _summaryLabel(String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: highlight ? const Color(0xFF7EB3FF) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}
