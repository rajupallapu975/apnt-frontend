import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/service_availability_helper.dart';
import 'zikrinter_service_details_page.dart';

class ZikrinterAllServicesPage extends StatelessWidget {
  final List<dynamic> services;

  const ZikrinterAllServicesPage({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "All Services",
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.68,
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => ServiceAvailabilityHelper.checkAndNavigate(
                    context: context,
                    serviceId: doc.id,
                    onAvailable: () => Navigator.push(
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
                    ),
                  ),
                  borderRadius: BorderRadius.circular(16),
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
                                    child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 18),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.image_rounded, color: Colors.grey, size: 18),
                                ),
                        ),
                      ),
                      // Service Info
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Starting from ₹${startingPrice.toStringAsFixed(0)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
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
      ),
    );
  }
}
