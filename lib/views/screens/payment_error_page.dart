import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_colors.dart';
import '../../widgets/common/primary_button.dart';

class PaymentErrorPage extends StatelessWidget {
  final String message;
  final bool isRefundInitiated;
  final Function(BuildContext context) onRetry;
  final Function(BuildContext context) onGoBack;

  const PaymentErrorPage({
    super.key,
    required this.message,
    this.isRefundInitiated = false,
    required this.onRetry,
    required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // ❌ Error Icon with Shake Animation
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 64),
              ).animate().shake(duration: 500.ms),

              const SizedBox(height: 40),

              Text(
                'SOMETHING WENT WRONG',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 24),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 16),

              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 400.ms),
              
              if (isRefundInitiated) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'REFUND INITIATED',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your payment was successful, but the order setup failed. We have automatically triggered a full refund via Razorpay.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Amount will reflect in your original payment method within 5-7 business days as per banking standards.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success, height: 1.4),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
              ],

              const Spacer(),

              PrimaryButton(
                label: 'RETRY',
                onPressed: () => onRetry(context),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () => onGoBack(context),
                  child: const Text('CANCEL'),
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
