import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/print_order_model.dart';
import '../../../utils/app_colors.dart';

/// 🖨️ Printing Process Tracker Widget
/// Visualizes the 4-stage order lifecycle: Placed ➔ Printing ➔ Ready ➔ Collected
/// Fills a blue progress line up to the active stage of the order.
class PrintProgressTracker extends StatelessWidget {
  final OrderStatus status;
  final String? orderStatus;
  final bool isPrintingCompleted;
  final bool isPicked;
  final bool isCompleted;

  const PrintProgressTracker({
    super.key,
    required this.status,
    this.orderStatus,
    this.isPrintingCompleted = false,
    this.isPicked = false,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    // 📊 Determine active stage index (0 to 3)
    // 0: Placed
    // 1: Printing
    // 2: Ready
    // 3: Collected
    int currentStep = 0;
    final normStatus = (orderStatus ?? '').toLowerCase().trim();

    if (isPicked || isCompleted || status == OrderStatus.completed) {
      currentStep = 3; // Collected
    } else if (isPrintingCompleted ||
        normStatus.contains('ready') ||
        normStatus.contains('completed') ||
        normStatus.contains('done')) {
      currentStep = 2; // Ready for pickup
    } else if (normStatus == 'printing' || normStatus == 'in_progress' || normStatus == 'in progress') {
      currentStep = 1; // Printing in progress
    } else {
      currentStep = 0; // Placed / Paid ("not printed yet", etc.)
    }

    final double progressFactor = (currentStep / 3).clamp(0.0, 1.0);

    final steps = [
      {'title': 'Placed', 'icon': Icons.assignment_turned_in_rounded},
      {'title': 'Printing', 'icon': Icons.print_rounded},
      {'title': 'Ready', 'icon': Icons.inventory_2_rounded},
      {'title': 'Collected', 'icon': Icons.check_circle_rounded},
    ];

    final stepSubtitle = currentStep == 0
        ? 'Order placed. Waiting for shopkeeper to start.'
        : currentStep == 1
            ? 'Shopkeeper is printing files'
            : currentStep == 2
                ? 'Printing completed! Ready for pickup'
                : 'Order picked up & finished';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRINTING PROGRESS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  steps[currentStep]['title'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            stepSubtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // ── Timeline Track & Nodes ──
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              const linePadding = 17.0;
              final lineWidth = totalWidth - (linePadding * 2);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // 1. Background Grey Track Line
                  Positioned(
                    top: 16,
                    left: linePadding,
                    right: linePadding,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 2. Active Blue Progress Line (Fills up to current step)
                  Positioned(
                    top: 16,
                    left: linePadding,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      height: 4,
                      width: lineWidth * progressFactor,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Step Nodes Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(steps.length, (index) {
                      final isReached = index <= currentStep;
                      final isCurrent = index == currentStep;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isReached ? AppColors.primaryBlue : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isReached
                                    ? AppColors.primaryBlue
                                    : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryBlue
                                            .withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              steps[index]['icon'] as IconData,
                              size: 16,
                              color: isReached ? Colors.white : AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            steps[index]['title'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isReached ? FontWeight.w800 : FontWeight.w500,
                              color: isReached
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
