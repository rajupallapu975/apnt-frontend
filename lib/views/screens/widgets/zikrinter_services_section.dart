// lib/views/screens/widgets/zikrinter_services_section.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../utils/app_colors.dart';
import '../zikrinter_service_details_page.dart';
import '../zikrinter_all_services_page.dart';

class ZikrinterServicesSection extends StatelessWidget {
  final List<dynamic> services;

  const ZikrinterServicesSection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    // Show max 5 service cards + 1 "More" card = 6 total
    final showAll = services.length <= 5;
    final displayCount = showAll ? services.length : 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Other Services',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2D3142),
                letterSpacing: -0.5,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ZikrinterAllServicesPage(services: services),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More Services',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Grid ──────────────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.72, // taller than wide — Blinkit style
          ),
          itemCount: (services.length > 5 ? 5 : services.length) + 1, // +1 for "More" card
          itemBuilder: (context, index) {
            final displayCount = services.length > 5 ? 5 : services.length;
            // ── "More Services" card ─────────────────────────────────────────
            if (index == displayCount) {
              return _MoreCard(services: services);
            }

            final doc = services[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final serviceName = data['serviceName'] ?? data['name'] ?? 'Service';
            final description = data['description'] ?? '';
            final imageUrl = data['imageUrl'] ??
                (data['images'] != null && (data['images'] as List).isNotEmpty
                    ? (data['images'] as List).first
                    : '');
            final images = List<String>.from(data['images'] ?? []);
            final startingPrice = (data['startingPrice'] ?? 0.0).toDouble();
            final globalParams = {
              ...(data['parameters'] as Map<String, dynamic>? ?? {}),
              'paperSizes': data['paperSizes'],
            };
            final actionButtonLabel = data['actionLabel'] as String?;

            return _ServiceCard(
              serviceId: doc.id,
              serviceName: serviceName,
              description: description,
              imageUrl: imageUrl,
              images: images,
              startingPrice: startingPrice,
              globalParams: globalParams,
              actionButtonLabel: actionButtonLabel,
            );
          },
        ),
      ],
    );
  }
}

// ─── Uniform Service Card (Blinkit style) ─────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final String serviceId;
  final String serviceName;
  final String description;
  final String imageUrl;
  final List<String> images;
  final double startingPrice;
  final Map<String, dynamic> globalParams;
  final String? actionButtonLabel;

  const _ServiceCard({
    required this.serviceId,
    required this.serviceName,
    required this.description,
    required this.imageUrl,
    required this.images,
    required this.startingPrice,
    required this.globalParams,
    this.actionButtonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ZikrinterServiceDetailsPage(
            serviceId: serviceId,
            serviceName: serviceName,
            description: description,
            imageUrl: imageUrl,
            images: images,
            startingPrice: startingPrice,
            globalParams: globalParams,
            actionButtonLabel: actionButtonLabel,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF0F4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Uniform Square Image Area ──────────────────────────────────
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                child: Container(
                  width: double.infinity,
                  color: Colors.white, // Pure white — same for ALL cards
                  padding: const EdgeInsets.all(8),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain, // Full image visible, no cropping
                          alignment: Alignment.center,
                          placeholder: (_, __) => Container(color: Colors.white),
                          errorWidget: (_, __, ___) => _PlaceholderIcon(),
                        )
                      : _PlaceholderIcon(),
                ),
              ),
            ),

            // ── Service Info ───────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Service name — 2 lines max so cards stay uniform
                    Text(
                      serviceName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: const Color(0xFF1E2532),
                        height: 1.3,
                      ),
                    ),

                    // Price pill
                    if (startingPrice > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₹${startingPrice.toStringAsFixed(0)}+',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── "More Services" Card ─────────────────────────────────────────────────────
class _MoreCard extends StatelessWidget {
  final List<dynamic> services;
  const _MoreCard({required this.services});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ZikrinterAllServicesPage(services: services),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'More',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'View All',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholder when no image ────────────────────────────────────────────────
class _PlaceholderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.print_rounded,
        size: 28,
        color: AppColors.primaryBlue.withValues(alpha: 0.25),
      ),
    );
  }
}
