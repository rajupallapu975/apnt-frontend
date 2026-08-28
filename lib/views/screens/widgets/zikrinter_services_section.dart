// lib/views/screens/widgets/zikrinter_services_section.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/service_availability_helper.dart';
import '../zikrinter_service_details_page.dart';

class ZikrinterServicesSection extends StatelessWidget {
  final List<dynamic> services;

  const ZikrinterServicesSection({super.key, required this.services});

  void _showComingSoonModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final textScaler = MediaQuery.textScalerOf(ctx);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Zikrint Logo Badge
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/zikrint_logo_transparent.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.print_rounded,
                    size: 42,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'We Will Update Soon!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: textScaler.scale(20),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E2532),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'We are expanding our service offerings to bring you more convenience and top quality printing features. Stay tuned for exciting new additions coming soon!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: textScaler.scale(13),
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),

              // Close / Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got It',
                    style: GoogleFonts.inter(
                      fontSize: textScaler.scale(15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

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
          ],
        ),
        const SizedBox(height: 16),

        // ── Services Grid ───────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
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
        const SizedBox(height: 14),

        // ── Full-Row Expanded "More Services" Banner Card ────────────────────
        _FullRowMoreCard(onTap: () => _showComingSoonModal(context)),
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
      onTap: () => ServiceAvailabilityHelper.checkAndNavigate(
        context: context,
        serviceId: serviceId,
        onAvailable: () => Navigator.push(
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
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF0F4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          placeholder: (_, __) => Container(color: Colors.white),
                          errorWidget: (_, __, ___) => _PlaceholderIcon(),
                        )
                      : _PlaceholderIcon(),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    if (startingPrice > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.08),
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

// ─── Full-Row Expanded "More Services" Banner Card ───────────────────────────
class _FullRowMoreCard extends StatelessWidget {
  final VoidCallback onTap;

  const _FullRowMoreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryBlue.withOpacity(0.08),
              AppColors.primaryBlue.withOpacity(0.03),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryBlue.withOpacity(0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Zikrint Logo Badge
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/zikrint_logo_transparent.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Flexible Title & Subtitle for Scaling Fonts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'More Services',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: textScaler.scale(14),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E2532),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to explore upcoming features & updates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: textScaler.scale(11),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Arrow Pill Action Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explore',
                    style: GoogleFonts.inter(
                      fontSize: textScaler.scale(11),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 9,
                    color: Colors.white,
                  ),
                ],
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
        color: AppColors.primaryBlue.withOpacity(0.25),
      ),
    );
  }
}
