import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import 'xerox_shop_model.dart';

class ShopCard extends StatelessWidget {
  final XeroxShopModel shop;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  const ShopCard({
    super.key,
    required this.shop,
    required this.onTap,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue.withValues(alpha: 0.1), AppColors.primaryBlue.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.store_rounded, color: AppColors.primaryBlue, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              shop.name,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlack,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusTag(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shop.address,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Pricing Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.background.withValues(alpha: 0.4),
            child: Row(
              children: [
                _priceTag('B/W: ₹${shop.pricePerBWPage.toStringAsFixed(0)}'),
                const SizedBox(width: 10),
                _priceTag('Color: ₹${shop.pricePerColorPage.toStringAsFixed(0)}'),
                const Spacer(),
                Text(
                  '${shop.openingTime} - ${shop.closingTime}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // 🎮 ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    label: 'DETAILS',
                    icon: Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    onPressed: onDetails,
                    isFilled: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    label: 'SELECT',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.primaryBlue,
                    onPressed: onTap,
                    isFilled: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: shop.isOpen 
            ? AppColors.success.withValues(alpha: 0.1) 
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        shop.isOpen ? 'OPEN' : 'CLOSED',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: shop.isOpen ? AppColors.success : AppColors.error,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
        const SizedBox(width: 4),
        Text(
          '${shop.rating}',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBlack),
        ),
        const SizedBox(width: 16),
        Icon(Icons.directions_walk_rounded, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          shop.distance,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onPressed,
    required bool isFilled,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFilled ? color : Colors.white,
          foregroundColor: isFilled ? Colors.white : color,
          elevation: isFilled ? 2 : 0,
          side: isFilled ? BorderSide.none : BorderSide(color: color.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBlack.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
