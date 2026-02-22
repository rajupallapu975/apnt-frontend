import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as path;

import '../../models/print_order_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/modern_card.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/primary_button.dart';
import 'payment_processing_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
          tabs: const [
            Tab(text: 'ACTIVE'),
            Tab(text: 'ALL PRINTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersStream(_firestoreService.getActiveOrders(), isActive: true),
          _buildOrdersStream(_firestoreService.getUserOrders()),
        ],
      ),
    );
  }

  Widget _buildOrdersStream(Stream<List<PrintOrderModel>> stream, {bool isActive = false}) {
    return StreamBuilder<List<PrintOrderModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return _buildEmptyState(
            icon: isActive ? Icons.print_rounded : Icons.history_rounded,
            message: isActive ? 'NO ACTIVE PRINTS' : 'NO HISTORY FOUND',
            subtitle: isActive ? 'Your pending prints will appear here.' : 'Start your first print to see it in history.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index], isActive: isActive).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(PrintOrderModel order, {bool isActive = false}) {
    final dateFormat = DateFormat('MMM dd • hh:mm a');

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
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
                    order.orderId.substring(0, 8).toUpperCase(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    dateFormat.format(order.createdAt),
                    style: GoogleFonts.manrope(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              StatusBadge(
                label: order.status.name.toUpperCase(),
                type: order.status == OrderStatus.active ? StatusType.active : StatusType.success,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PICKUP CODE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                Text(
                  order.pickupCode,
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryBlue, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoTile(Icons.description_outlined, '${order.totalPages} Pages'),
              const Spacer(),
              Text('₹${order.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          if (!isActive) ...[
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'REPRINT',
              height: 48,
              onPressed: () => _reprintOrder(order),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.greyLight.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(subtitle, style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    ).animate().fadeIn();
  }

  Future<void> _reprintOrder(PrintOrderModel order) async {
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

    final List<File?> reprintFiles = [];
    if (order.localFilePaths.isNotEmpty) {
      for (final path in order.localFilePaths) {
        final file = File(path);
        if (await file.exists()) reprintFiles.add(file);
      }
    }

    if (reprintFiles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local source files not found.')));
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentProcessingPage(
          selectedFiles: reprintFiles,
          selectedBytes: const [],
          filenames: reprintFiles.map((f) => path.basename(f!.path)).toList(),
          printSettings: order.printSettings,
          expectedPages: order.totalPages,
          expectedPrice: order.totalPrice,
        ),
      ),
    );
  }
}
