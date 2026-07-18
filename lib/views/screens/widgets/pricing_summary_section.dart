import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/app_colors.dart';
import '../../../services/pricing_service.dart';

class PricingSummarySection extends StatelessWidget {
  final PricingCalculationResult pricingResult;
  final bool hasError;
  final VoidCallback? onRetry;

  const PricingSummarySection({
    super.key,
    required this.pricingResult,
    this.hasError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Failed to calculate pricing',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry Calculation'),
            ),
          ],
        ),
      );
    }

    final originalPrice = pricingResult.originalShopSubtotal;
    final discount = pricingResult.amountSaved;
    final printingCost = pricingResult.shopSubtotal;
    final platformFee = pricingResult.commissionAmount;
    final grandTotal = pricingResult.finalAmount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          // Original Printing Cost (if discounted)
          if (discount > 0) ...[
            _summaryLine(
              'Printing Cost (Original)',
              '₹${originalPrice.toStringAsFixed(2)}',
              strikethrough: true,
            ),
            _summaryLine(
              'Bulk Discount',
              '-₹${discount.toStringAsFixed(2)}',
              isGreen: true,
            ),
          ],

          _summaryLine(
            'Printing Cost',
            '₹${printingCost.toStringAsFixed(2)}',
            boldValue: true,
          ),
          if (pricingResult.generateCoverPage)
            _summaryLine(
              'Cover Page Charge',
              '₹${pricingResult.extraPageFee.toStringAsFixed(2)}',
            ),
          _summaryLine(
            'Platform Fee',
            '₹${platformFee.toStringAsFixed(2)}',
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              Text(
                '₹${grandTotal.toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {bool strikethrough = false, bool isGreen = false, bool boldValue = false}) {
    TextStyle valueStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: boldValue ? FontWeight.bold : FontWeight.w600,
      color: isGreen ? Colors.green[700] : AppColors.textPrimary,
    );

    if (strikethrough) {
      valueStyle = valueStyle.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textTertiary);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                softWrap: true,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
