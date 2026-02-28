import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../utils/app_colors.dart';

class PaymentSummarySheet extends StatelessWidget {
  final int totalPages;
  final double totalPrice;
  final Map<String, dynamic> printSettings;
  final VoidCallback onProceed;

  const PaymentSummarySheet({
    super.key,
    required this.totalPages,
    required this.totalPrice,
    required this.printSettings,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    // Extract summary info
    final List<dynamic> files = printSettings['files'] ?? [];
    final bool isDoubleSided = printSettings['doubleSide'] ?? false;
    
    // Simple summary text
    String colorModes = files.any((f) => f['color'] == 'COLOR') ? 'Color' : 'B&W';
    if (files.any((f) => f['color'] == 'COLOR') && files.any((f) => f['color'] == 'BW')) {
      colorModes = 'Mixed';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ➖ Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 💳 Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, 
                    color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Summary',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                  Text(
                    'Review your order details',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn().slideX(begin: -0.1, end: 0),

          const SizedBox(height: 32),

          // 📄 Order Details Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  icon: Icons.description_outlined,
                  label: 'Total Pages',
                  value: '$totalPages ${totalPages == 1 ? 'Page' : 'Pages'}',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                _buildSummaryRow(
                  icon: Icons.tune_rounded,
                  label: 'Print Settings',
                  value: '$colorModes • ${isDoubleSided ? 'Double Sided' : 'Single Sided'}',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                _buildSummaryRow(
                  icon: Icons.data_usage_rounded,
                  label: 'Storage Footprint',
                  value: _formatTotalKB(files),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                _buildSummaryRow(
                  icon: Icons.bolt_rounded,
                  label: 'Payment Method',
                  value: 'UPI / QR Code',
                  valueColor: AppColors.primaryBlue,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 40),

          // 💰 Total Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '₹${totalPrice.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlack,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),

          // 🚀 Proceed Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'PROCEED TO PAY',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const Positioned(
                    right: 0,
                    child: Icon(Icons.arrow_forward_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95)),
          
          const SizedBox(height: 12),
          
          // 🛡️ Security Note
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'SECURE 256-BIT ENCRYPTED PAYMENT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  String _formatTotalKB(List<dynamic> files) {
    double totalKB = 0;
    for (var f in files) {
      totalKB += double.tryParse(f['fileSizeKB']?.toString() ?? '0') ?? 0;
    }
    if (totalKB < 1024) return '${totalKB.toStringAsFixed(1)} KB';
    return '${(totalKB / 1024).toStringAsFixed(2)} MB';
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.primaryBlack,
          ),
        ),
      ],
    );
  }
}