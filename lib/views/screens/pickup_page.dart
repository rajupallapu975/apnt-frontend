import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../models/print_order_model.dart';
import '../../utils/app_colors.dart';
import '../../services/firestore_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/backend_service.dart';
import '../../services/local_storage_service.dart';

class PickupPage extends StatefulWidget {
  final PrintOrderModel order;
  const PickupPage({super.key, required this.order});

  @override
  State<PickupPage> createState() => _PickupPageState();
}

class _PickupPageState extends State<PickupPage> {
  bool _isFinalizing = false;
  late Stream<DocumentSnapshot> _orderStream;

  @override
  void initState() {
    super.initState();
    // 📡 Real-time sync: Watch the order for external completion
    _orderStream = FirebaseFirestore.instance
        .collection('xerox_orders')
        .doc(widget.order.orderId)
        .snapshots();
  }

  Future<void> _handleComplete() async {
    setState(() => _isFinalizing = true);
    try {
      await FirestoreService().completeOrderPickup(
        orderId: widget.order.orderId,
        shopId: widget.order.shopId,
      );

      // 💾 Update Local Storage IMMEDIATELY for Instant History update
      final completedOrder = PrintOrderModel(
        orderId: widget.order.orderId,
        pickupCode: widget.order.pickupCode,
        userId: widget.order.userId,
        createdAt: widget.order.createdAt,
        expiresAt: widget.order.expiresAt,
        status: OrderStatus.completed,
        printMode: widget.order.printMode,
        printSettings: widget.order.printSettings,
        totalPages: widget.order.totalPages,
        totalPrice: widget.order.totalPrice,
        fileUrls: widget.order.fileUrls,
        publicIds: widget.order.publicIds,
        localFilePaths: widget.order.localFilePaths,
        customId: widget.order.customId,
        isPicked: true,
        orderDone: true,
      );
      await LocalStorageService().saveOrderLocally(completedOrder);
      // 🗑️ TRIGGER CLOUDINARY CLEANUP
      // (Optional: don't wait for deletion to close the page for better UX)
      BackendService().deleteOrderFiles(
        orderId: widget.order.orderId,
        publicIds: widget.order.publicIds,
      );

      if (mounted) {
        Navigator.pop(context); // Go back to Home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as picked up! 🎉'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _orderStream,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
          children: [
            const SizedBox(height: 40),
            // Success Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
              ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack).shake(hz: 4, duration: 600.ms),
            ),
            const SizedBox(height: 32),
            Text(
              'SCAN SUCCESSFUL',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.order.customId?.toUpperCase() ?? 'NEW ORDER',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 48),

            // Pickup Code Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'YOUR UNIQUE PICKUP CODE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTertiary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.order.pickupCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: Text(
                      widget.order.pickupCode,
                      style: GoogleFonts.inter(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                        letterSpacing: 12,
                      ),
                    ).animate().shimmer(duration: 2500.ms, color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.copy_rounded, size: 14, color: AppColors.textTertiary),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Provide this code orally to the shopkeeper\nto process your print job.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

            const Spacer(),

            // "DONE" Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _isFinalizing ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlack,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: _isFinalizing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'DONE — ITEMS PICKED UP',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  },
);
  }
}
