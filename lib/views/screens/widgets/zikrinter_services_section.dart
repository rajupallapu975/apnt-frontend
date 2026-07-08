// lib/views/screens/widgets/zikrinter_services_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../utils/app_colors.dart';
import '../zikrinter_service_details_page.dart';

class ZikrinterServicesSection extends StatelessWidget {
  final List<dynamic> services;

  const ZikrinterServicesSection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Other Services',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF2D3142),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final doc = services[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final serviceName = data['serviceName'] ?? data['name'] ?? 'Printing Service';
            final description = data['description'] ?? '';
            final imageUrl = data['imageUrl'] ?? (data['images'] != null && (data['images'] as List).isNotEmpty ? (data['images'] as List).first : '');
            final images = List<String>.from(data['images'] ?? []);
            final startingPrice = (data['startingPrice'] ?? 0.0).toDouble();
            final globalParams = {
              ...(data['parameters'] as Map<String, dynamic>? ?? {}),
              'paperSizes': data['paperSizes'],
            };
            final actionButtonLabel = data['actionLabel'] as String?;

            return Container(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ZikrinterServiceDetailsPage(
                          serviceId: doc.id,
                          serviceName: serviceName,
                          description: description,
                          imageUrl: imageUrl,
                          images: images,
                          startingPrice: startingPrice,
                          globalParams: globalParams,
                          actionButtonLabel: actionButtonLabel,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Image Header
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFFF1F5F9),
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _b) => Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(color: Colors.white),
                                  ),
                                  errorWidget: (_, _b, _c) => const Center(
                                    child: Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.image_rounded, color: Colors.grey),
                                ),
                        ),
                      ),
                      // Service Info
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Start from ₹${startingPrice.toStringAsFixed(0)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: AppColors.primaryBlue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
