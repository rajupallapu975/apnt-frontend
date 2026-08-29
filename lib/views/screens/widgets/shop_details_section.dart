import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/app_colors.dart';
import '../../../xerox_shop/xerox_shop_model.dart';
import '../../../services/pricing_service.dart';

class ShopDetailsSection extends StatelessWidget {
  final XeroxShopModel shop;
  final String serviceId;
  final String serviceName;
  final Map<String, dynamic>? globalServiceParams;
  final bool isServiceDisabled;
  final VoidCallback onStartOver;

  const ShopDetailsSection({
    super.key,
    required this.shop,
    required this.serviceId,
    required this.serviceName,
    this.globalServiceParams,
    this.isServiceDisabled = false,
    required this.onStartOver,
  });

  @override
  Widget build(BuildContext context) {
    final pricing = XeroxPricing.fromShopData(shop.zikrinterServices, globalServiceParams, serviceId: serviceId);
    final isOpen = shop.isCurrentlyOpen;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If service disabled
          if (isServiceDisabled) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service No Longer Available',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red[900], fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This shop has disabled $serviceName. Please choose another shop.',
                          style: GoogleFonts.inter(color: Colors.red[800], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onStartOver,
                    child: const Text('Change Shop', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          // Shop details card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shop.address,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          shop.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOpen ? 'Open Now' : 'Closed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 20),

          // Pricing guidelines
          Text(
            'Pricing Guide',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _guideRow(
                  'B&W Printing (Normal)', 
                  pricing.normalBwPrice > 0 ? '₹${pricing.normalBwPrice.toStringAsFixed(2)} / page' : 'Unavailable',
                ),
                if (pricing.bulkBwPrice > 0) ...[
                  const Divider(height: 20),
                  _guideRow('B&W Printing (Bulk)', '₹${pricing.bulkBwPrice.toStringAsFixed(2)} / page'),
                  _guideSubRow('Applied if total B&W pages ≥ ${pricing.bwBulkStartPage} sheets'),
                ],
                const Divider(height: 24),
                _guideRow(
                  'Color Printing (Normal)', 
                  pricing.normalColorPrice > 0 ? '₹${pricing.normalColorPrice.toStringAsFixed(2)} / page' : 'Unavailable',
                ),
                if (pricing.bulkColorPrice > 0) ...[
                  const Divider(height: 20),
                  _guideRow('Color Printing (Bulk)', '₹${pricing.bulkColorPrice.toStringAsFixed(2)} / page'),
                  _guideSubRow('Applied if total Color pages ≥ ${pricing.colorBulkStartPage} sheets'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              softWrap: true,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _guideSubRow(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '* $text',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
