import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../models/print_order_model.dart';
import '../../services/local_storage_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/modern_card.dart';

class CompletedOrdersPage extends StatefulWidget {
  const CompletedOrdersPage({super.key});

  @override
  State<CompletedOrdersPage> createState() => _CompletedOrdersPageState();
}

class _CompletedOrdersPageState extends State<CompletedOrdersPage> {
  final LocalStorageService _localStorage = LocalStorageService();
  bool _isLoading = true;
  List<PrintOrderModel> _completedOrders = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final orders = await _localStorage.getLocalOrders();
    // Focused on COMPLETED orders per user request
    _completedOrders = orders.where((o) => 
      o.status == OrderStatus.completed || 
      o.isPicked ||
      o.orderDone
    ).toList();
    _completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'COMPLETED ORDERS',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _completedOrders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    itemCount: _completedOrders.length,
                    itemBuilder: (context, index) => _buildCompletedCard(_completedOrders[index])
                        .animate()
                        .fadeIn(delay: (index * 50).ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
                ),
    );
  }

  Widget _buildCompletedCard(PrintOrderModel order) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final String displayId = order.customId?.toUpperCase() ?? 
        'ORDER #${order.orderId.substring(order.orderId.length > 6 ? order.orderId.length - 6 : 0).toUpperCase()}';
    
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayId,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(order.createdAt),
                      style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textTertiary, size: 22),
                onPressed: () => _confirmDelete(order),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  'PICKUP CODE',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 2),
                ),
                const SizedBox(height: 6),
                Text(
                  order.pickupCode,
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(PrintOrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Remove from Completed'),
        content: const Text('This will remove the order from your completed list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _localStorage.deleteOrderLocally(order.orderId);
      _loadHistory();
    }
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          Text(
            'NO COMPLETED ORDERS',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep printing and your history will grow!',
            style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
