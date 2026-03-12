import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

import '../../utils/app_colors.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/modern_card.dart';

class PaymentSuccessPage extends StatelessWidget {
  final String orderId;
  final String pickupCode;
  final String? xeroxId;
  final bool isXerox;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.pickupCode,
    this.xeroxId,
    this.isXerox = false,
  });

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // 🎉 Success Icon with Animation
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: AppColors.success, size: 64),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).shimmer(delay: 800.ms),

                const SizedBox(height: 40),

                Text(
                  isXerox ? 'FILES SENT TO SHOP' : 'ORDER CONFIRMED',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(letterSpacing: -1, color: isXerox ? AppColors.success : AppColors.primaryBlack),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 12),

                Text(
                  isXerox 
                    ? 'Your documents have been successfully sent to the Xerox Shop. Please visit the counter to collect them.'
                    : 'Your documents are ready for printing. Use the code below at any Think Ink kiosk.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                const Spacer(),

                // 🔑 Pickup Code Card
                ModernCard(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  color: isXerox ? AppColors.success : AppColors.primaryBlue,
                  boxShadow: AppColors.mediumShadow,
                  child: Column(
                    children: [
                      Text(
                        isXerox ? 'IDENTIFIER' : 'PICKUP CODE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        pickupCode.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: isXerox ? 32 : 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: isXerox ? 2 : 8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: pickupCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied to clipboard'), behavior: SnackBarBehavior.floating),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 8),
                              Text('COPY CODE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),

                if (xeroxId != null && !isXerox) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                         Text(
                          'XEROX SHOP ID',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                         Text(
                          xeroxId!,
                          style: GoogleFonts.inter(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                            letterSpacing: 10,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
                ],

                const SizedBox(height: 32),

                // ⌨️ Keypad Instructions
                if (!isXerox)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard_alt_outlined, color: AppColors.primaryBlue, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Enter this code on the Think Ink kiosk keypad to start printing.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),

                const Spacer(flex: 2),

                PrimaryButton(
                  label: 'DONE',
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.5, end: 0),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
