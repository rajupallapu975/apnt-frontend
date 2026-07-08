// lib/services/pricing_service.dart

class XeroxPricing {
  final Map<String, double> normalBwPrices;
  final Map<String, double> doubleBwPrices;
  final Map<String, double> bulkBwPrices;
  final Map<String, int> bwBulkStartPages;

  final Map<String, double> normalColorPrices;
  final Map<String, double> doubleColorPrices;
  final Map<String, double> bulkColorPrices;
  final Map<String, int> colorBulkStartPages;

  XeroxPricing({
    required this.normalBwPrices,
    required this.doubleBwPrices,
    required this.bulkBwPrices,
    required this.bwBulkStartPages,
    required this.normalColorPrices,
    required this.doubleColorPrices,
    required this.bulkColorPrices,
    required this.colorBulkStartPages,
  });

  double get normalBwPrice => normalBwPrices['a4'] ?? 2.0;
  double get doubleBwPrice => doubleBwPrices['a4'] ?? 4.0;
  double get bulkBwPrice => bulkBwPrices['a4'] ?? 1.5;
  int get bwBulkStartPage => bwBulkStartPages['a4'] ?? 10;

  double get normalColorPrice => normalColorPrices['a4'] ?? 10.0;
  double get doubleColorPrice => doubleColorPrices['a4'] ?? 20.0;
  double get bulkColorPrice => bulkColorPrices['a4'] ?? 8.0;
  int get colorBulkStartPage => colorBulkStartPages['a4'] ?? 10;

  factory XeroxPricing.fromShopData(Map<String, dynamic> shopData, Map<String, dynamic>? globalServiceParams, {String? serviceId}) {
    final zikrinterServices = shopData['zikrinterServices'] as Map<String, dynamic>? ?? {};
    final String targetServiceId = serviceId ?? 'ZHwQd18Vy08TZkyBFXjB';
    final config = zikrinterServices[targetServiceId] as Map<String, dynamic>? ?? {};

    final Map<String, double> normalBwPrices = {};
    final Map<String, double> doubleBwPrices = {};
    final Map<String, double> bulkBwPrices = {};
    final Map<String, int> bwBulkStartPages = {};

    final Map<String, double> normalColorPrices = {};
    final Map<String, double> doubleColorPrices = {};
    final Map<String, double> bulkColorPrices = {};
    final Map<String, int> colorBulkStartPages = {};

    // 1. Read base values for A4 (using top-level fallbacks if legacy)
    double baseNormalBw = _toDouble(shopData['pricePerBWPage']) ?? _toDouble(config['pricePerBWPage']) ?? _toDouble(config['bw_singleSidePrice']) ?? 2.0;
    double baseDoubleBw = _toDouble(shopData['doubleBwPrice']) ?? _toDouble(config['doubleBwPrice']) ?? _toDouble(config['bw_doubleSidePrice']) ?? (baseNormalBw * 2.0);
    double baseBulkBw = _toDouble(shopData['bulkBwPrice']) ?? _toDouble(config['bulkBwPrice']) ?? _toDouble(config['bw_bulkPrintingPrice']) ?? 1.5;
    
    double baseNormalColor = _toDouble(shopData['pricePerColorPage']) ?? _toDouble(config['pricePerColorPage']) ?? _toDouble(config['color_singleSidePrice']) ?? 10.0;
    double baseDoubleColor = _toDouble(shopData['doubleColorPrice']) ?? _toDouble(config['doubleColorPrice']) ?? _toDouble(config['color_doubleSidePrice']) ?? (baseNormalColor * 2.0);
    double baseBulkColor = _toDouble(shopData['bulkColorPrice']) ?? _toDouble(config['bulkColorPrice']) ?? _toDouble(config['color_bulkPrintingPrice']) ?? 8.0;

    int baseBwBulkStart = _toInt(shopData['bwBulkStartPage']) ?? _toInt(shopData['bulkStartPage']) ?? _toInt(config['bwBulkStartPage']) ?? _toInt(config['bulkStartPage']) ?? _toInt(config['bw_bulkPrinting']?['setPages']) ?? 10;
    int baseColorBulkStart = _toInt(shopData['colorBulkStartPage']) ?? _toInt(shopData['bulkStartPage']) ?? _toInt(config['colorBulkStartPage']) ?? _toInt(config['bulkStartPage']) ?? _toInt(config['color_bulkPrinting']?['setPages']) ?? 10;

    if (globalServiceParams != null) {
      baseBwBulkStart = _toInt(globalServiceParams['bw_bulkPrinting']?['setPages']) ?? baseBwBulkStart;
      baseColorBulkStart = _toInt(globalServiceParams['color_bulkPrinting']?['setPages']) ?? _toInt(globalServiceParams['bulkPrinting']?['setPages']) ?? baseColorBulkStart;
    }

    // 2. Map all paper sizes dynamically
    final List<dynamic> rawSizes = globalServiceParams != null ? (globalServiceParams['paperSizes'] as List<dynamic>? ?? []) : [];
    final List<String> allSizes = rawSizes.isNotEmpty ? List<String>.from(rawSizes) : ['A4', 'A3', 'A2', 'A1', 'Legal'];

    for (final size in allSizes) {
      final sizeKey = size.toLowerCase();

      // Check nested schema first
      final sizeConfig = config['paperSizes']?[sizeKey] ?? config['paperSizes']?[size.toUpperCase()];
      
      double? normalBw;
      double? doubleBw;
      double? bulkBw;
      int? bwBulkStart;
      double? normalColor;
      double? doubleColor;
      double? bulkColor;
      int? colorBulkStart;

      if (sizeConfig != null) {
        normalBw = _toDouble(sizeConfig['bw']?['singleSidePrice']);
        doubleBw = _toDouble(sizeConfig['bw']?['doubleSidePrice']);
        bulkBw = _toDouble(sizeConfig['bw']?['bulkPrintingPrice']);
        bwBulkStart = _toInt(sizeConfig['bw']?['bulkStartPage'] ?? sizeConfig['bw']?['setPages']);
        
        normalColor = _toDouble(sizeConfig['color']?['singleSidePrice']);
        doubleColor = _toDouble(sizeConfig['color']?['doubleSidePrice']);
        bulkColor = _toDouble(sizeConfig['color']?['bulkPrintingPrice']);
        colorBulkStart = _toInt(sizeConfig['color']?['bulkStartPage'] ?? sizeConfig['color']?['setPages']);
      }

      // Flat prefixed key fallback
      normalBw ??= _toDouble(config['${sizeKey}_bw_singleSidePrice']);
      doubleBw ??= _toDouble(config['${sizeKey}_bw_doubleSidePrice']);
      bulkBw ??= _toDouble(config['${sizeKey}_bw_bulkPrintingPrice']);
      bwBulkStart ??= _toInt(config['${sizeKey}_bw_bulkPrinting']?['setPages']);

      normalColor ??= _toDouble(config['${sizeKey}_color_singleSidePrice']);
      doubleColor ??= _toDouble(config['${sizeKey}_color_doubleSidePrice']);
      bulkColor ??= _toDouble(config['${sizeKey}_color_bulkPrintingPrice']);
      colorBulkStart ??= _toInt(config['${sizeKey}_color_bulkPrinting']?['setPages']);

      // Base legacy fallback
      if (sizeKey == 'legal') {
        normalBw ??= _toDouble(config['legal_bw_singleSidePrice']) ?? _toDouble(config['legal_singleSidePrice']);
        doubleBw ??= _toDouble(config['legal_bw_doubleSidePrice']) ?? _toDouble(config['legal_doubleSidePrice']);
        bulkBw ??= _toDouble(config['legal_bw_bulkPrintingPrice']) ?? _toDouble(config['legal_bulkPrintingPrice']);
        bwBulkStart ??= _toInt(config['legal_bw_bulkPrinting']?['setPages']) ?? _toInt(config['legal_bulkPrinting']?['setPages']);
        
        normalColor ??= _toDouble(config['legal_color_singleSidePrice']);
        doubleColor ??= _toDouble(config['legal_color_doubleSidePrice']);
        bulkColor ??= _toDouble(config['legal_color_bulkPrintingPrice']);
        colorBulkStart ??= _toInt(config['legal_color_bulkPrinting']?['setPages']);
      } else if (sizeKey == 'a4') {
        normalBw ??= baseNormalBw;
        doubleBw ??= baseDoubleBw;
        bulkBw ??= baseBulkBw;
        bwBulkStart ??= baseBwBulkStart;

        normalColor ??= baseNormalColor;
        doubleColor ??= baseDoubleColor;
        bulkColor ??= baseBulkColor;
        colorBulkStart ??= baseColorBulkStart;
      }

      // Final mappings with defaults to base A4 values
      normalBwPrices[sizeKey] = normalBw ?? baseNormalBw;
      doubleBwPrices[sizeKey] = doubleBw ?? baseDoubleBw;
      bulkBwPrices[sizeKey] = bulkBw ?? baseBulkBw;
      bwBulkStartPages[sizeKey] = bwBulkStart ?? baseBwBulkStart;

      normalColorPrices[sizeKey] = normalColor ?? baseNormalColor;
      doubleColorPrices[sizeKey] = doubleColor ?? baseDoubleColor;
      bulkColorPrices[sizeKey] = bulkColor ?? baseBulkColor;
      colorBulkStartPages[sizeKey] = colorBulkStart ?? baseColorBulkStart;
    }

    return XeroxPricing(
      normalBwPrices: normalBwPrices,
      doubleBwPrices: doubleBwPrices,
      bulkBwPrices: bulkBwPrices,
      bwBulkStartPages: bwBulkStartPages,
      normalColorPrices: normalColorPrices,
      doubleColorPrices: doubleColorPrices,
      bulkColorPrices: bulkColorPrices,
      colorBulkStartPages: colorBulkStartPages,
    );
  }

  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  static int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString());
  }
}

class PricingCalculationResult {
  final int totalBwPages;
  final int totalBwPagesWithCopies;
  final String bwPricingMode; // "Normal" or "Bulk"
  final double bwPricePerPage;
  final double bwCost;
  final double bwOriginalCost;
  final bool isBwBulkApplied;

  final int totalColorPages;
  final int totalColorPagesWithCopies;
  final String colorPricingMode; // "Normal" or "Bulk"
  final double colorPricePerPage;
  final double colorCost;
  final double colorOriginalCost;
  final bool isColorBulkApplied;

  final double shopSubtotal;
  final double originalShopSubtotal;
  final double amountSaved;
  final bool isBulkApplied;

  final String commissionType; // "percentage" or "fixed"
  final double commissionValue;
  final double commissionAmount;
  final double originalCommissionAmount;

  final double finalAmount;
  final double originalFinalAmount;
  final double finalAmountSaved;
  final double extraPageFee;
  final List<double> fileCosts;
  final bool generateCoverPage;

  PricingCalculationResult({
    required this.totalBwPages,
    required this.totalBwPagesWithCopies,
    required this.bwPricingMode,
    required this.bwPricePerPage,
    required this.bwCost,
    required this.bwOriginalCost,
    required this.isBwBulkApplied,
    required this.totalColorPages,
    required this.totalColorPagesWithCopies,
    required this.colorPricingMode,
    required this.colorPricePerPage,
    required this.colorCost,
    required this.colorOriginalCost,
    required this.isColorBulkApplied,
    required this.shopSubtotal,
    required this.originalShopSubtotal,
    required this.amountSaved,
    required this.isBulkApplied,
    required this.commissionType,
    required this.commissionValue,
    required this.commissionAmount,
    required this.originalCommissionAmount,
    required this.finalAmount,
    required this.originalFinalAmount,
    required this.finalAmountSaved,
    required this.extraPageFee,
    required this.fileCosts,
    required this.generateCoverPage,
  });
}

class PricingService {
  static PricingCalculationResult calculate({
    required List<Map<String, dynamic>> fileConfigs, // Contains: pageCount, copies, isColor, isDoubleSided, paperSize
    required Map<String, dynamic> shopData,
    Map<String, dynamic>? globalServiceParams,
    required String commissionType,
    required double commissionValue,
    String? serviceId,
  }) {
    final pricing = XeroxPricing.fromShopData(shopData, globalServiceParams, serviceId: serviceId);

    int totalBwPages = 0;
    int totalColorPages = 0;

    int totalBwPagesWithCopies = 0;
    int totalColorPagesWithCopies = 0;

    double bwCost = 0.0;
    double bwOriginalCost = 0.0;
    double colorCost = 0.0;
    double colorOriginalCost = 0.0;

    bool isBwBulkApplied = false;
    bool isColorBulkApplied = false;

    double totalCommissionAmount = 0.0;
    double totalOriginalCommissionAmount = 0.0;

    int totalPrintablePages = 0;
    for (final file in fileConfigs) {
      final int pageCount = (file['pageCount'] as num? ?? 1).toInt();
      final int copies = (file['copies'] as num? ?? 1).toInt();
      totalPrintablePages += pageCount * copies;
    }

    final bool generateCoverPage = totalPrintablePages > 5;
    final double extraPageFee = generateCoverPage ? 2.0 : 0.0;
    final List<double> fileCosts = [];

    for (final file in fileConfigs) {
      final int pageCount = (file['pageCount'] as num? ?? 1).toInt();
      final int copies = (file['copies'] as num? ?? 1).toInt();
      final bool isColor = file['isColor'] == true;
      final bool isDoubleSided = file['isDoubleSided'] == true;
      final String sizeKey = (file['paperSize'] ?? 'A4').toString().toLowerCase();

      // Duplex sheet calculation
      final int chargeableSheets = isDoubleSided ? (pageCount / 2.0).ceil() : pageCount;
      final int sheetsWithCopies = chargeableSheets * copies;

      double itemCost = 0.0;
      double itemOriginalCost = 0.0;
      String paramType = 'singleSide';

      if (isColor) {
        totalColorPages += chargeableSheets;
        totalColorPagesWithCopies += sheetsWithCopies;

        final double normalPrice = isDoubleSided 
            ? (pricing.doubleColorPrices[sizeKey] ?? pricing.doubleColorPrices['a4'] ?? 20.0) 
            : (pricing.normalColorPrices[sizeKey] ?? pricing.normalColorPrices['a4'] ?? 10.0);
        final double bulkPrice = pricing.bulkColorPrices[sizeKey] ?? pricing.bulkColorPrices['a4'] ?? 8.0;
        final int bulkStart = pricing.colorBulkStartPages[sizeKey] ?? pricing.colorBulkStartPages['a4'] ?? 10;

        final bool isBulk = sheetsWithCopies >= bulkStart;
        if (isBulk) isColorBulkApplied = true;

        final double rate = isBulk ? bulkPrice : normalPrice;
        itemCost = sheetsWithCopies * rate;
        itemOriginalCost = sheetsWithCopies * normalPrice;

        colorCost += itemCost;
        colorOriginalCost += itemOriginalCost;

        paramType = isBulk ? 'bulkPrinting' : (isDoubleSided ? 'doubleSide' : 'singleSide');
      } else {
        totalBwPages += chargeableSheets;
        totalBwPagesWithCopies += sheetsWithCopies;

        final double normalPrice = isDoubleSided 
            ? (pricing.doubleBwPrices[sizeKey] ?? pricing.doubleBwPrices['a4'] ?? 4.0) 
            : (pricing.normalBwPrices[sizeKey] ?? pricing.normalBwPrices['a4'] ?? 2.0);
        final double bulkPrice = pricing.bulkBwPrices[sizeKey] ?? pricing.bulkBwPrices['a4'] ?? 1.5;
        final int bulkStart = pricing.bwBulkStartPages[sizeKey] ?? pricing.bwBulkStartPages['a4'] ?? 10;

        final bool isBulk = sheetsWithCopies >= bulkStart;
        if (isBulk) isBwBulkApplied = true;

        final double rate = isBulk ? bulkPrice : normalPrice;
        itemCost = sheetsWithCopies * rate;
        itemOriginalCost = sheetsWithCopies * normalPrice;

        bwCost += itemCost;
        bwOriginalCost += itemOriginalCost;

        paramType = isBulk ? 'bulkPrinting' : (isDoubleSided ? 'doubleSide' : 'singleSide');
      }

      // Calculate dynamic commission for this item
      final String colorMode = isColor ? 'color' : 'bw';
      final String paramKey = '${sizeKey}_${colorMode}_$paramType';
      final String fallbackParamKey = '${colorMode}_$paramType';

      final Map<String, dynamic> itemParamConfig = Map<String, dynamic>.from(
          (globalServiceParams != null 
              ? (globalServiceParams[paramKey] ?? globalServiceParams[fallbackParamKey] ?? const {}) 
              : const {}) as Map);

      double itemCommissionVal = (itemParamConfig['commission'] ?? commissionValue).toDouble();
      String itemCommissionType = itemParamConfig['commissionType'] ?? commissionType;

      double itemCommission = 0.0;
      if (itemCommissionType.toLowerCase() == 'percentage') {
        itemCommission = itemCost * (itemCommissionVal / 100.0);
      } else if (itemCommissionType.toLowerCase() == 'fixed') {
        // Commission fixed is per sheet or page
        itemCommission = sheetsWithCopies * itemCommissionVal;
      }
      totalCommissionAmount += itemCommission;

      double itemOriginalCommission = 0.0;
      if (itemCommissionType.toLowerCase() == 'percentage') {
        itemOriginalCommission = itemOriginalCost * (itemCommissionVal / 100.0);
      } else if (itemCommissionType.toLowerCase() == 'fixed') {
        itemOriginalCommission = sheetsWithCopies * itemCommissionVal;
      }
      totalOriginalCommissionAmount += itemOriginalCommission;
      fileCosts.add(itemCost);
    }

    final String bwPricingMode = isBwBulkApplied ? "Bulk" : "Normal";
    final double bwPricePerPage = totalBwPagesWithCopies > 0 ? (bwCost / totalBwPagesWithCopies) : 0.0;

    final String colorPricingMode = isColorBulkApplied ? "Bulk" : "Normal";
    final double colorPricePerPage = totalColorPagesWithCopies > 0 ? (colorCost / totalColorPagesWithCopies) : 0.0;

    final double shopSubtotal = bwCost + colorCost;
    final double originalShopSubtotal = bwOriginalCost + colorOriginalCost;
    final double amountSaved = originalShopSubtotal - shopSubtotal;
    final bool isBulkApplied = isBwBulkApplied || isColorBulkApplied;

    // Round commission UP to nearest integer (e.g. ₹2.69 → ₹3)
    final double roundedCommissionAmount = totalCommissionAmount.ceilToDouble();
    final double roundedOriginalCommissionAmount = totalOriginalCommissionAmount.ceilToDouble();

    final double finalAmount = shopSubtotal + roundedCommissionAmount + extraPageFee;
    final double originalFinalAmount = originalShopSubtotal + roundedOriginalCommissionAmount + extraPageFee;
    final double finalAmountSaved = originalFinalAmount - finalAmount;

    return PricingCalculationResult(
      totalBwPages: totalBwPages,
      totalBwPagesWithCopies: totalBwPagesWithCopies,
      bwPricingMode: bwPricingMode,
      bwPricePerPage: bwPricePerPage,
      bwCost: bwCost,
      bwOriginalCost: bwOriginalCost,
      isBwBulkApplied: isBwBulkApplied,
      totalColorPages: totalColorPages,
      totalColorPagesWithCopies: totalColorPagesWithCopies,
      colorPricingMode: colorPricingMode,
      colorPricePerPage: colorPricePerPage,
      colorCost: colorCost,
      colorOriginalCost: colorOriginalCost,
      isColorBulkApplied: isColorBulkApplied,
      shopSubtotal: shopSubtotal,
      originalShopSubtotal: originalShopSubtotal,
      amountSaved: amountSaved,
      isBulkApplied: isBulkApplied,
      commissionType: commissionType,
      commissionValue: commissionValue,
      commissionAmount: roundedCommissionAmount,
      originalCommissionAmount: roundedOriginalCommissionAmount,
      finalAmount: finalAmount,
      originalFinalAmount: originalFinalAmount,
      finalAmountSaved: finalAmountSaved,
      extraPageFee: extraPageFee,
      fileCosts: fileCosts,
      generateCoverPage: generateCoverPage,
    );
  }
}
