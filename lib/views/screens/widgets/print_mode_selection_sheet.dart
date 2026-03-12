import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../utils/app_colors.dart';
import '../../../models/print_order_model.dart';

class PrintModeSelectionSheet extends StatelessWidget {
  final Function(PrintMode mode) onSelected;

  const PrintModeSelectionSheet({
    super.key,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
          const SizedBox(height: 24),

          // 💳 Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.print_rounded, 
                    color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Print Mode',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                  Text(
                    'How would you like to print?',
                    style: GoogleFonts.inter(
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

          // 🤖 Autonomous Option
          _buildOption(
            context: context,
            mode: PrintMode.autonomous,
            icon: Icons.smart_toy_rounded,
            title: 'Autonomous',
            description: 'Print instantly via self-service kiosk',
            color: AppColors.primaryBlue,
            delay: 100,
          ),

          const SizedBox(height: 16),

          // 🏪 Xerox Shop Option
          _buildOption(
            context: context,
            mode: PrintMode.xeroxShop,
            icon: Icons.store_rounded,
            title: 'Xerox Shop',
            description: 'Pick up from a nearby shop with assistance',
            color: AppColors.success,
            delay: 200,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required PrintMode mode,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required int delay,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onSelected(mode);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlack,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1, end: 0);
  }
}
