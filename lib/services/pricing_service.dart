// lib/services/pricing_service.dart

class XeroxPricing {
  final Map<String, double> normalBwPrices;
  final Map<String, double> doubleBwPrices;
  final Map<String, double> bulkBwPrices;
  final Map<String, double> doubleBulkBwPrices;
  final Map<String, int> bwBulkStartPages;

  final Map<String, double> normalColorPrices;
  final Map<String, double> doubleColorPrices;
  final Map<String, double> bulkColorPrices;
  final Map<String, double> doubleBulkColorPrices;
  final Map<String, int> colorBulkStartPages;

  XeroxPricing({
    required this.normalBwPrices,
    required this.doubleBwPrices,
    required this.bulkBwPrices,
    required this.doubleBulkBwPrices,
    required this.bwBulkStartPages,
    required this.normalColorPrices,
    required this.doubleColorPrices,
    required this.bulkColorPrices,
    required this.doubleBulkColorPrices,
    required this.colorBulkStartPages,
  });

  double get normalBwPrice => normalBwPrices['a4'] ?? 2.0;
  double get doubleBwPrice => doubleBwPrices['a4'] ?? 0.0;
  double get bulkBwPrice => bulkBwPrices['a4'] ?? 0.0;
  double get doubleBulkBwPrice => doubleBulkBwPrices['a4'] ?? 0.0;
  int get bwBulkStartPage => bwBulkStartPages['a4'] ?? 10;

  double get normalColorPrice => normalColorPrices['a4'] ?? 10.0;
  double get doubleColorPrice => doubleColorPrices['a4'] ?? 0.0;
  double get bulkColorPrice => bulkColorPrices['a4'] ?? 0.0;
  double get doubleBulkColorPrice => doubleBulkColorPrices['a4'] ?? 0.0;
  int get colorBulkStartPage => colorBulkStartPages['a4'] ?? 10;

  bool isBwAvailable(String sizeKey) {
    final key = sizeKey.toLowerCase();
    final p = normalBwPrices[key] ?? normalBwPrices['a4'] ?? 0.0;
    return p > 0.0;
  }

  bool isColorAvailable(String sizeKey) {
    final key = sizeKey.toLowerCase();
    final p = normalColorPrices[key] ?? normalColorPrices['a4'] ?? 0.0;
    return p > 0.0;
  }

  bool isDoubleSidedAvailable(String sizeKey, bool isColor) {
    final key = sizeKey.toLowerCase();
    if (isColor) {
      final p = doubleColorPrices[key] ?? doubleColorPrices['a4'] ?? 0.0;
      return p > 0.0;
    } else {
      final p = doubleBwPrices[key] ?? doubleBwPrices['a4'] ?? 0.0;
      return p > 0.0;
    }
  }

  bool isBulkBwAvailable(String sizeKey) {
    final key = sizeKey.toLowerCase();
    final p = bulkBwPrices[key] ?? bulkBwPrices['a4'] ?? 0.0;
    return p > 0.0;
  }

  bool isDoubleBulkBwAvailable(String sizeKey) {
    final key = sizeKey.toLowerCase();
    final p = doubleBulkBwPrices[key] ?? doubleBulkBwPrices['a4'] ?? 0.0;
    return p > 0.0;
  }

  bool isBulkColorAvailable(String sizeKey) {
    final key = sizeKey.toLowerCase();
    final p = bulkColorPrices[key] ?? bulkColorPrices['a4'] ?? 0.0;
    return p > 0.0;
  }

  bool isDoubleBulkColorAvailable(String sizeKey) {
    final key = sizeKey.toLowerCase();
    final p = doubleBulkColorPrices[key] ?? doubleBulkColorPrices['a4'] ?? 0.0;
    return p > 0.0;
  }

  factory XeroxPricing.fromShopData(Map<String, dynamic> shopData, Map<String, dynamic>? globalServiceParams, {String? serviceId}) {
    final zikrinterServices = shopData['zikrinterServices'] as Map<String, dynamic>? ?? {};
    final String targetServiceId = serviceId ?? 'ZHwQd18Vy08TZkyBFXjB';
    final config = zikrinterServices[targetServiceId] as Map<String, dynamic>? ?? {};

    final Map<String, double> normalBwPrices = {};
    final Map<String, double> doubleBwPrices = {};
    final Map<String, double> bulkBwPrices = {};
    final Map<String, double> doubleBulkBwPrices = {};
    final Map<String, int> bwBulkStartPages = {};

    final Map<String, double> normalColorPrices = {};
    final Map<String, double> doubleColorPrices = {};
    final Map<String, double> bulkColorPrices = {};
    final Map<String, double> doubleBulkColorPrices = {};
    final Map<String, int> colorBulkStartPages = {};

    final bool hasExplicitShopConfig = (shopData.isNotEmpty && shopData.containsKey('zikrinterServices')) || config.isNotEmpty;

    // 1. Read base values for A4
    double? rawNormalBw = _toDouble(shopData['pricePerBWPage']) ?? _toDouble(config['pricePerBWPage']) ?? _toDouble(config['bw_singleSidePrice']);
    double baseNormalBw = rawNormalBw ?? (hasExplicitShopConfig ? 0.0 : 2.0);
    double? rawDoubleBw = _toDouble(shopData['doubleBwPrice']) ?? _toDouble(config['doubleBwPrice']) ?? _toDouble(config['bw_doubleSidePrice']);
    double baseDoubleBw = rawDoubleBw ?? 0.0;
    double? rawBulkBw = _toDouble(shopData['bulkBwPrice']) ?? _toDouble(config['bulkBwPrice']) ?? _toDouble(config['bw_bulkPrintingPrice']);
    double baseBulkBw = rawBulkBw ?? 0.0;
    double? rawDoubleBulkBw = _toDouble(shopData['doubleBulkBwPrice']) ?? _toDouble(config['doubleBulkBwPrice']) ?? _toDouble(config['bw_double_bulkPrintingPrice']) ?? _toDouble(config['double_bulkPrintingPrice']);
    double baseDoubleBulkBw = rawDoubleBulkBw ?? 0.0;
    
    double? rawNormalColor = _toDouble(shopData['pricePerColorPage']) ?? _toDouble(config['pricePerColorPage']) ?? _toDouble(config['color_singleSidePrice']);
    double baseNormalColor = rawNormalColor ?? (hasExplicitShopConfig ? 0.0 : 10.0);
    double? rawDoubleColor = _toDouble(shopData['doubleColorPrice']) ?? _toDouble(config['doubleColorPrice']) ?? _toDouble(config['color_doubleSidePrice']);
    double baseDoubleColor = rawDoubleColor ?? 0.0;
    double? rawBulkColor = _toDouble(shopData['bulkColorPrice']) ?? _toDouble(config['bulkColorPrice']) ?? _toDouble(config['color_bulkPrintingPrice']);
    double baseBulkColor = rawBulkColor ?? 0.0;
    double? rawDoubleBulkColor = _toDouble(shopData['doubleBulkColorPrice']) ?? _toDouble(config['doubleBulkColorPrice']) ?? _toDouble(config['color_double_bulkPrintingPrice']);
    double baseDoubleBulkColor = rawDoubleBulkColor ?? 0.0;

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
      double? doubleBulkBw;
      int? bwBulkStart;
      double? normalColor;
      double? doubleColor;
      double? bulkColor;
      double? doubleBulkColor;
      int? colorBulkStart;

      if (sizeConfig != null) {
        normalBw = _toDouble(sizeConfig['bw']?['singleSidePrice']);
        doubleBw = _toDouble(sizeConfig['bw']?['doubleSidePrice']);
        bulkBw = _toDouble(sizeConfig['bw']?['bulkPrintingPrice']);
        doubleBulkBw = _toDouble(sizeConfig['bw']?['doubleBulkPrintingPrice'] ?? sizeConfig['bw']?['double_bulkPrintingPrice']);
        bwBulkStart = _toInt(sizeConfig['bw']?['bulkStartPage'] ?? sizeConfig['bw']?['setPages']);
        
        normalColor = _toDouble(sizeConfig['color']?['singleSidePrice']);
        doubleColor = _toDouble(sizeConfig['color']?['doubleSidePrice']);
        bulkColor = _toDouble(sizeConfig['color']?['bulkPrintingPrice']);
        doubleBulkColor = _toDouble(sizeConfig['color']?['doubleBulkPrintingPrice'] ?? sizeConfig['color']?['double_bulkPrintingPrice']);
        colorBulkStart = _toInt(sizeConfig['color']?['bulkStartPage'] ?? sizeConfig['color']?['setPages']);
      }

      // Flat prefixed key fallback
      normalBw ??= _toDouble(config['${sizeKey}_bw_singleSidePrice']);
      doubleBw ??= _toDouble(config['${sizeKey}_bw_doubleSidePrice']);
      bulkBw ??= _toDouble(config['${sizeKey}_bw_bulkPrintingPrice']);
      doubleBulkBw ??= _toDouble(config['${sizeKey}_bw_double_bulkPrintingPrice']);
      bwBulkStart ??= _toInt(config['${sizeKey}_bw_bulkPrinting']?['setPages']);

      normalColor ??= _toDouble(config['${sizeKey}_color_singleSidePrice']);
      doubleColor ??= _toDouble(config['${sizeKey}_color_doubleSidePrice']);
      bulkColor ??= _toDouble(config['${sizeKey}_color_bulkPrintingPrice']);
      doubleBulkColor ??= _toDouble(config['${sizeKey}_color_double_bulkPrintingPrice']);
      colorBulkStart ??= _toInt(config['${sizeKey}_color_bulkPrinting']?['setPages']);

      // Base legacy fallback
      if (sizeKey == 'legal') {
        normalBw ??= _toDouble(config['legal_bw_singleSidePrice']) ?? _toDouble(config['legal_singleSidePrice']) ?? (baseNormalBw > 0 ? baseNormalBw : null);
        doubleBw ??= _toDouble(config['legal_bw_doubleSidePrice']) ?? _toDouble(config['legal_doubleSidePrice']) ?? (baseDoubleBw > 0 ? baseDoubleBw : null);
        bulkBw ??= _toDouble(config['legal_bw_bulkPrintingPrice']) ?? _toDouble(config['legal_bulkPrintingPrice']) ?? (baseBulkBw > 0 ? baseBulkBw : null);
        doubleBulkBw ??= _toDouble(config['legal_bw_double_bulkPrintingPrice']) ?? (baseDoubleBulkBw > 0 ? baseDoubleBulkBw : null);
        bwBulkStart ??= _toInt(config['legal_bw_bulkPrinting']?['setPages']) ?? _toInt(config['legal_bulkPrinting']?['setPages']) ?? baseBwBulkStart;
        
        normalColor ??= _toDouble(config['legal_color_singleSidePrice']) ?? (baseNormalColor > 0 ? baseNormalColor : null);
        doubleColor ??= _toDouble(config['legal_color_doubleSidePrice']) ?? (baseDoubleColor > 0 ? baseDoubleColor : null);
        bulkColor ??= _toDouble(config['legal_color_bulkPrintingPrice']) ?? (baseBulkColor > 0 ? baseBulkColor : null);
        doubleBulkColor ??= _toDouble(config['legal_color_double_bulkPrintingPrice']) ?? (baseDoubleBulkColor > 0 ? baseDoubleBulkColor : null);
        colorBulkStart ??= _toInt(config['legal_color_bulkPrinting']?['setPages']) ?? baseColorBulkStart;
      } else if (sizeKey == 'a4') {
        normalBw ??= (baseNormalBw > 0 ? baseNormalBw : null);
        doubleBw ??= (baseDoubleBw > 0 ? baseDoubleBw : null);
        bulkBw ??= (baseBulkBw > 0 ? baseBulkBw : null);
        doubleBulkBw ??= (baseDoubleBulkBw > 0 ? baseDoubleBulkBw : null);
        bwBulkStart ??= baseBwBulkStart;

        normalColor ??= (baseNormalColor > 0 ? baseNormalColor : null);
        doubleColor ??= (baseDoubleColor > 0 ? baseDoubleColor : null);
        bulkColor ??= (baseBulkColor > 0 ? baseBulkColor : null);
        doubleBulkColor ??= (baseDoubleBulkColor > 0 ? baseDoubleBulkColor : null);
        colorBulkStart ??= baseColorBulkStart;
      }

      // Size-aware defaults (scale up from A4 base only if base is configured)
      final double sizeMultiplier = sizeKey == 'a3'
          ? 1.5
          : sizeKey == 'a2'
              ? 2.0
              : sizeKey == 'a1'
                  ? 3.0
                  : 1.0;

      normalBwPrices[sizeKey] = normalBw ?? (baseNormalBw > 0 ? (baseNormalBw * sizeMultiplier).ceilToDouble() : 0.0);
      doubleBwPrices[sizeKey] = doubleBw ?? (baseDoubleBw > 0 ? (baseDoubleBw * sizeMultiplier).ceilToDouble() : 0.0);
      bulkBwPrices[sizeKey] = bulkBw ?? (baseBulkBw > 0 ? (baseBulkBw * sizeMultiplier).ceilToDouble() : 0.0);
      doubleBulkBwPrices[sizeKey] = doubleBulkBw ?? (baseDoubleBulkBw > 0 ? (baseDoubleBulkBw * sizeMultiplier).ceilToDouble() : 0.0);
      bwBulkStartPages[sizeKey] = bwBulkStart ?? baseBwBulkStart;

      normalColorPrices[sizeKey] = normalColor ?? (baseNormalColor > 0 ? (baseNormalColor * sizeMultiplier).ceilToDouble() : 0.0);
      doubleColorPrices[sizeKey] = doubleColor ?? (baseDoubleColor > 0 ? (baseDoubleColor * sizeMultiplier).ceilToDouble() : 0.0);
      bulkColorPrices[sizeKey] = bulkColor ?? (baseBulkColor > 0 ? (baseBulkColor * sizeMultiplier).ceilToDouble() : 0.0);
      doubleBulkColorPrices[sizeKey] = doubleBulkColor ?? (baseDoubleBulkColor > 0 ? (baseDoubleBulkColor * sizeMultiplier).ceilToDouble() : 0.0);
      colorBulkStartPages[sizeKey] = colorBulkStart ?? baseColorBulkStart;
    }

    return XeroxPricing(
      normalBwPrices: normalBwPrices,
      doubleBwPrices: doubleBwPrices,
      bulkBwPrices: bulkBwPrices,
      doubleBulkBwPrices: doubleBulkBwPrices,
      bwBulkStartPages: bwBulkStartPages,
      normalColorPrices: normalColorPrices,
      doubleColorPrices: doubleColorPrices,
      bulkColorPrices: bulkColorPrices,
      doubleBulkColorPrices: doubleBulkColorPrices,
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
    List<dynamic>? allShopServices,
  }) {
    final isProjectBinding = serviceId?.toLowerCase().contains('project') == true ||
        (globalServiceParams != null &&
            (globalServiceParams['serviceType'] == 'project_binding' ||
                (globalServiceParams['name'] ?? '').toString().toLowerCase().contains('project')));

    if (isProjectBinding) {
      int totalPagesWithCopies = 0;
      double totalPrintingCost = 0.0;
      double totalPrintingCommission = 0.0;
      final List<double> fileCosts = [];

      for (final file in fileConfigs) {
        final int pageCount = (file['pageCount'] as num? ?? 1).toInt();
        final int copies = (file['copies'] as num? ?? 1).toInt();
        final bool isColor = file['isColor'] == true;
        final bool isDoubleSided = file['isDoubleSided'] == true;
        final String rawSize = (file['paperSize'] ?? 'A4').toString().toLowerCase();

        // 1. Identify Target Service ID and mapping paper size key
        final bool isBond = rawSize.contains('bond');
        final String fileServiceId = isBond ? 'nyAKL7mMnGGkTx2Ow9HA' : 'ZHwQd18Vy08TZkyBFXjB';
        final String filePaperSize = isBond ? 'a4' : rawSize;

        // 2. Fetch global service parameters for commission
        Map<String, dynamic>? fileGlobalParams;
        if (allShopServices != null) {
          final serviceDoc = allShopServices.firstWhere(
            (s) => s['id'] == fileServiceId,
            orElse: () => null,
          );
          if (serviceDoc != null) {
            fileGlobalParams = serviceDoc['parameters'] as Map<String, dynamic>?;
          }
        }

        // 3. Resolve target pricing configuration
        final pricing = XeroxPricing.fromShopData(shopData, fileGlobalParams, serviceId: fileServiceId);

        // 4. Calculate pricing for this file using target pricing config
        final int chargeableSheets = isDoubleSided ? (pageCount / 2.0).ceil() : pageCount;
        final int sheetsWithCopies = chargeableSheets * copies;
        totalPagesWithCopies += sheetsWithCopies;

        double printPrice = 0.0;
        if (isColor) {
          printPrice = isDoubleSided
              ? (pricing.doubleColorPrices[filePaperSize] ?? pricing.doubleColorPrices['a4'] ?? 20.0)
              : (pricing.normalColorPrices[filePaperSize] ?? pricing.normalColorPrices['a4'] ?? 10.0);
        } else {
          printPrice = isDoubleSided
              ? (pricing.doubleBwPrices[filePaperSize] ?? pricing.doubleBwPrices['a4'] ?? 4.0)
              : (pricing.normalBwPrices[filePaperSize] ?? pricing.normalBwPrices['a4'] ?? 2.0);
        }

        final double itemCost = sheetsWithCopies * printPrice;
        fileCosts.add(itemCost);
        totalPrintingCost += itemCost;

        // 5. Calculate commission for this file configuration
        final Map<String, dynamic> sizeConfigGlobal = fileGlobalParams?['paperSizes']?[filePaperSize] ?? {};
        final String printCommType = sizeConfigGlobal['commissionType'] ?? 'percentage';
        final double printCommValue = (sizeConfigGlobal['commission'] as num? ?? 0.0).toDouble();

        double fileCommission = 0.0;
        if (printCommType.toLowerCase() == 'percentage') {
          fileCommission = itemCost * (printCommValue / 100.0);
        } else {
          fileCommission = sheetsWithCopies * printCommValue;
        }
        totalPrintingCommission += fileCommission;
      }

      final roundedCommission = totalPrintingCommission.ceilToDouble();

      return PricingCalculationResult(
        totalBwPages: 0,
        totalBwPagesWithCopies: 0,
        bwPricingMode: 'Normal',
        bwPricePerPage: 0.0,
        bwCost: 0.0,
        bwOriginalCost: 0.0,
        isBwBulkApplied: false,
        totalColorPages: totalPagesWithCopies,
        totalColorPagesWithCopies: totalPagesWithCopies,
        colorPricingMode: 'Normal',
        colorPricePerPage: totalPrintingCost / (totalPagesWithCopies > 0 ? totalPagesWithCopies : 1.0),
        colorCost: totalPrintingCost,
        colorOriginalCost: totalPrintingCost,
        isColorBulkApplied: false,
        shopSubtotal: totalPrintingCost,
        originalShopSubtotal: totalPrintingCost,
        amountSaved: 0.0,
        isBulkApplied: false,
        commissionType: 'connected',
        commissionValue: 0.0,
        commissionAmount: roundedCommission,
        originalCommissionAmount: roundedCommission,
        finalAmount: totalPrintingCost + roundedCommission,
        originalFinalAmount: totalPrintingCost + roundedCommission,
        finalAmountSaved: 0.0,
        extraPageFee: 0.0,
        fileCosts: fileCosts,
        generateCoverPage: false,
      );
    }

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

        final double normalSinglePrice = pricing.normalColorPrices[sizeKey] ?? pricing.normalColorPrices['a4'] ?? 0.0;
        final double rawDoublePrice = pricing.doubleColorPrices[sizeKey] ?? pricing.doubleColorPrices['a4'] ?? 0.0;
        final double doublePrice = rawDoublePrice > 0.0 ? rawDoublePrice : (normalSinglePrice * 2.0);

        final double singleBulkPrice = pricing.bulkColorPrices[sizeKey] ?? pricing.bulkColorPrices['a4'] ?? 0.0;
        final double doubleBulkPrice = pricing.doubleBulkColorPrices[sizeKey] ?? pricing.doubleBulkColorPrices['a4'] ?? 0.0;
        final int bulkStart = pricing.colorBulkStartPages[sizeKey] ?? pricing.colorBulkStartPages['a4'] ?? 10;

        final double normalPrice = isDoubleSided ? doublePrice : normalSinglePrice;
        double rate = normalPrice;
        bool isBulk = false;

        if (sheetsWithCopies >= bulkStart) {
          if (isDoubleSided) {
            if (doubleBulkPrice > 0.0) {
              rate = doubleBulkPrice < normalPrice ? doubleBulkPrice : normalPrice;
              if (rate < normalPrice) {
                isBulk = true;
                isColorBulkApplied = true;
              }
            }
          } else {
            if (singleBulkPrice > 0.0) {
              rate = singleBulkPrice < normalPrice ? singleBulkPrice : normalPrice;
              if (rate < normalPrice) {
                isBulk = true;
                isColorBulkApplied = true;
              }
            }
          }
        }

        itemCost = sheetsWithCopies * rate;
        itemOriginalCost = sheetsWithCopies * normalPrice;

        colorCost += itemCost;
        colorOriginalCost += itemOriginalCost;

        paramType = isBulk ? (isDoubleSided ? 'double_bulkPrinting' : 'bulkPrinting') : (isDoubleSided ? 'doubleSide' : 'singleSide');
      } else {
        totalBwPages += chargeableSheets;
        totalBwPagesWithCopies += sheetsWithCopies;

        final double normalSinglePrice = pricing.normalBwPrices[sizeKey] ?? pricing.normalBwPrices['a4'] ?? 0.0;
        final double rawDoublePrice = pricing.doubleBwPrices[sizeKey] ?? pricing.doubleBwPrices['a4'] ?? 0.0;
        final double doublePrice = rawDoublePrice > 0.0 ? rawDoublePrice : (normalSinglePrice * 2.0);

        final double singleBulkBwPrice = pricing.bulkBwPrices[sizeKey] ?? pricing.bulkBwPrices['a4'] ?? 0.0;
        final double doubleBulkBwPrice = pricing.doubleBulkBwPrices[sizeKey] ?? pricing.doubleBulkBwPrices['a4'] ?? 0.0;
        final int bulkStart = pricing.bwBulkStartPages[sizeKey] ?? pricing.bwBulkStartPages['a4'] ?? 10;

        final double normalPrice = isDoubleSided ? doublePrice : normalSinglePrice;
        double rate = normalPrice;
        bool isBulk = false;

        if (sheetsWithCopies >= bulkStart) {
          if (isDoubleSided) {
            if (doubleBulkBwPrice > 0.0) {
              rate = doubleBulkBwPrice < normalPrice ? doubleBulkBwPrice : normalPrice;
              if (rate < normalPrice) {
                isBulk = true;
                isBwBulkApplied = true;
              }
            }
          } else {
            if (singleBulkBwPrice > 0.0) {
              rate = singleBulkBwPrice < normalPrice ? singleBulkBwPrice : normalPrice;
              if (rate < normalPrice) {
                isBulk = true;
                isBwBulkApplied = true;
              }
            }
          }
        }

        itemCost = sheetsWithCopies * rate;
        itemOriginalCost = sheetsWithCopies * normalPrice;

        bwCost += itemCost;
        bwOriginalCost += itemOriginalCost;

        paramType = isBulk ? (isDoubleSided ? 'double_bulkPrinting' : 'bulkPrinting') : (isDoubleSided ? 'doubleSide' : 'singleSide');
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
