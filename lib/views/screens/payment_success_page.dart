import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    // ✅ Success Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
                    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).shimmer(delay: 800.ms),
                    const SizedBox(height: 20),

                    Text(
                      isXerox ? 'FILES SENT TO SHOP' : 'ORDER CONFIRMED',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        letterSpacing: -1,
                        color: isXerox ? AppColors.success : AppColors.primaryBlack,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 12),

                    Text(
                      isXerox
                          ? 'Your documents have been sent to the Xerox Shop.'
                          : 'Your documents are ready for printing. Use the code below at any Zikrint kiosk.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 20),

                    // 🔑 Pickup Code Card (Autonomous / Kiosk only)
                    if (!isXerox)
                      ModernCard(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        color: AppColors.primaryBlue,
                        boxShadow: AppColors.mediumShadow,
                        child: Column(
                          children: [
                            Text(
                              'PICKUP CODE',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                pickupCode.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),

                    // 🔒 Xerox: Code is HIDDEN — reveal only by scanning shop QR
                    if (isXerox)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.success.withValues(alpha: 0.08),
                              AppColors.primaryBlue.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [

                            // Lock icon
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_rounded, color: AppColors.success, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your pickup code is locked',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlack,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Visit the Xerox shop and scan their QR code to reveal your unique pickup code.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Masked code dots
                            Text(
                              '• • • •',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textTertiary,
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Scan button hint
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'SCAN SHOP QR TO REVEAL',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 16),



                    // ⌨️ Kiosk tip (Autonomous only)
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
                                'Enter this code on the Zikrint kiosk keypad to start printing.',
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
                      ).animate().fadeIn(delay: 800.ms),

                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'DONE',
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.5, end: 0),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

            ),
          ),
        ),
      ),
    );
  }
}
