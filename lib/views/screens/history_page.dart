import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../models/print_order_model.dart';
import '../../services/local_storage_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/modern_card.dart';
import '../../widgets/common/status_badge.dart';
import 'widgets/order_details_sheet.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final LocalStorageService _localStorage = LocalStorageService();
  bool _isLoading = true;
  List<PrintOrderModel> _historyOrders = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final orders = await _localStorage.getLocalOrders();
    // Show orders that are explicitly completed or cancelled, excluding expired ones
    _historyOrders = orders.where((o) => (o.status == OrderStatus.completed || o.status == OrderStatus.cancelled) && !o.isExpired).toList();
    setState(() => _isLoading = false);
  }

  void _showOrderDetails(PrintOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderDetailsSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PRINT HISTORY',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyOrders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    itemCount: _historyOrders.length,
                    itemBuilder: (context, index) => _buildHistoryCard(_historyOrders[index])
                        .animate()
                        .fadeIn(delay: (index * 50).ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
                ),
    );
  }

  Widget _buildHistoryCard(PrintOrderModel order) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final shortId = order.orderId.substring(0, 8).toUpperCase();
    
    // Determine the "Reason" or Status label
    String reasonLabel = order.status == OrderStatus.completed ? "PRINTED" : "EXPIRED";
    if (order.status == OrderStatus.cancelled) reasonLabel = "CANCELLED";
    if (order.reason != null) reasonLabel = order.reason!.toUpperCase();

    final isExpired = order.status == OrderStatus.expired;

    return InkWell(
      onTap: () => _showOrderDetails(order),
      borderRadius: BorderRadius.circular(20),
      child: ModernCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isExpired ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpired ? Icons.timer_off_rounded : Icons.check_circle_rounded,
                    color: isExpired ? AppColors.error : AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$shortId',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      Text(
                        dateFormat.format(order.createdAt),
                        style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: reasonLabel,
                  type: isExpired ? StatusType.error : StatusType.success,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfoRow(Icons.description_outlined, '${order.totalPages} Pages'),
                Text(
                  '₹${order.totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: AppColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text(
            'NO PRINT HISTORY',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Historical orders will appear here.',
            style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
