import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../utils/app_colors.dart';
import '../../../xerox_shop/xerox_shop_model.dart';
import '../../../services/pricing_service.dart';

class ShopSelectionSection extends StatefulWidget {
  final List<XeroxShopModel> shops;
  final String serviceId;
  final Map<String, dynamic>? globalServiceParams;
  final ValueChanged<XeroxShopModel> onShopSelected;
  final bool isLoading;

  const ShopSelectionSection({
    super.key,
    required this.shops,
    required this.serviceId,
    this.globalServiceParams,
    required this.onShopSelected,
    this.isLoading = false,
  });

  @override
  State<ShopSelectionSection> createState() => _ShopSelectionSectionState();
}

class _ShopSelectionSectionState extends State<ShopSelectionSection> {
  String _searchQuery = '';
  String _filterType = 'Nearest'; // 'Nearest', 'Rating', 'Lowest Price'

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildShimmerLoading();
    }

    // Filter and sort list locally
    final filteredShops = widget.shops.where((shop) {
      if (_searchQuery.isEmpty) return true;
      return shop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          shop.address.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (_filterType == 'Rating') {
      filteredShops.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_filterType == 'Lowest Price') {
      filteredShops.sort((a, b) {
        final pricingA = XeroxPricing.fromShopData(a.zikrinterServices, widget.globalServiceParams, serviceId: widget.serviceId);
        final pricingB = XeroxPricing.fromShopData(b.zikrinterServices, widget.globalServiceParams, serviceId: widget.serviceId);
        return pricingA.normalBwPrice.compareTo(pricingB.normalBwPrice);
      });
    } else {
      // Nearest
      filteredShops.sort((a, b) => _parseDistance(a.distance).compareTo(_parseDistance(b.distance)));
    }

    return Column(
      children: [
        // Search & Filter Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search shops by name or address...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Nearest', 'Rating', 'Lowest Price'].map((filter) {
                    final isSelected = _filterType == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _filterType = filter);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // List of shops
        if (filteredShops.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront_rounded, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'No shops match your criteria.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredShops.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final shop = filteredShops[index];
                final pricing = XeroxPricing.fromShopData(shop.zikrinterServices, widget.globalServiceParams, serviceId: widget.serviceId);
                final bool isOpen = shop.isCurrentlyOpen;

                return GestureDetector(
                  onTap: () => widget.onShopSelected(shop),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Shop image/logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: shop.imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, _b) => Shimmer.fromColors(
                              baseColor: Colors.grey[200]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (_, _b, _c) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.store_rounded, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Shop Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      shop.name,
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF9C4),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_rounded, size: 12, color: Colors.orange),
                                        const SizedBox(width: 2),
                                        Text(
                                          shop.rating.toStringAsFixed(1),
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shop.address,
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    shop.distance,
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      '15 min ready', // estimate placeholder
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Price Badge & Open Status
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Starts from ₹${pricing.normalBwPrice.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isOpen ? 'Open Now' : 'Closed',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isOpen ? Colors.green[700] : Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, _b) => const SizedBox(height: 12),
        itemBuilder: (_, _c) => Shimmer.fromColors(
          baseColor: Colors.grey[200]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  double _parseDistance(String distanceStr) {
    final clean = distanceStr.toLowerCase().trim();
    if (clean == 'nearby') return 0.1;
    final value = double.tryParse(clean.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 999.0;
    if (clean.contains('km')) {
      return value;
    } else if (clean.contains('m')) {
      return value / 1000.0;
    }
    return value;
  }
}
