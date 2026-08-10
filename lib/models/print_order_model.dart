import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  active,
  completed,
  cancelled,
  failed,
  refunded,
}

enum PrintMode {
  autonomous,
  xeroxShop,
}

class PrintOrderModel {
  final String orderId;
  final String pickupCode;
  final String userId;
  final DateTime createdAt;
  final OrderStatus status;
  final Map<String, dynamic> printSettings;
  final int totalPages;
  final double totalPrice;
  final List<String> fileUrls;
  final List<String> publicIds; // Cloudinary IDs for deletion
  final List<String> localFilePaths; // Local paths for reprinting

  final String? reason;
  final String? xeroxId;
  final String? orderStatus; // Set by admin: 'printing completed' when done
  final bool scanned;    // True after QR scan
  final bool isPicked;   // True after "DONE" clicked
  final bool orderDone;  // True after "DONE" (scanned and picked)
  final bool codeRevealed; // Legacy, keep for now but use 'scanned' mostly

  final String? customId; // Sequential ID (order_1, order_2)
  final String projectId;

  // Cover Page details
  final bool generateCoverPage;
  final double coverPageCharge;
  final String? coverPageUrl;
  final String? coverPagePublicId;

  // Extended pricing & splitting fields
  final double? printingCost;
  final double? platformCommission;
  final double? shopkeeperEarnings;
  final double? platformEarnings;
  final Map<String, dynamic>? shopPricingUsed;
  final String? serviceId;
  final String? serviceName;
  final String? razorpayPaymentId;
  final String? paymentStatus;
  final String? userEmail;
  final String? customerName;
  
  bool get isXerox => printMode == PrintMode.xeroxShop;
  /// True if admin has confirmed printing is complete
  bool get isPrintingCompleted => 
    orderStatus == 'printing completed' || 
    orderStatus == 'order completed' || 
    orderStatus == 'completed' || 
    orderStatus == 'done';
  final PrintMode printMode;

  String get displayId {
    if (customId != null && customId!.isNotEmpty) {
      final cleanId = customId!
          .toUpperCase()
          .replaceAll('ORDER_', '')
          .replaceAll('ORDER', '')
          .replaceAll('_', ' ')
          .trim();
      return 'ORDER $cleanId';
    }
    return 'ORDER #${orderId.length > 6 ? orderId.substring(orderId.length - 6).toUpperCase() : orderId.toUpperCase()}';
  }

  PrintOrderModel({
    required this.orderId,
    required this.pickupCode,
    required this.userId,
    required this.createdAt,
    required this.status,
    required this.printMode,
    required this.printSettings,
    required this.totalPages,
    required this.totalPrice,
    required this.fileUrls,
    this.publicIds = const [],
    this.localFilePaths = const [],
    this.reason,
    this.xeroxId,
    this.orderStatus,
    this.codeRevealed = false,
    this.scanned = false,
    this.isPicked = false,
    this.orderDone = false,
    this.customId,
    this.projectId = 'psfc-43b5a',
    this.generateCoverPage = false,
    this.coverPageCharge = 0.0,
    this.coverPageUrl,
    this.coverPagePublicId,
    this.printingCost,
    this.platformCommission,
    this.shopkeeperEarnings,
    this.platformEarnings,
    this.shopPricingUsed,
    this.serviceId,
    this.serviceName,
    this.razorpayPaymentId,
    this.paymentStatus,
    this.userEmail,
    this.customerName,
  });

  // Check if order is active
  bool get isActive => status == OrderStatus.active;

  factory PrintOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrintOrderModel(
      orderId: doc.id,
      pickupCode: (data['pickupCode'] ?? '').toString(),
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate() 
          : (data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now()),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'].toString().toLowerCase(),
        orElse: () {
          final String s = data['status']?.toString().toLowerCase() ?? '';
          if (s == 'hidden_failed' || s == 'failed_processing') return OrderStatus.failed;
          if (s == 'refunded') return OrderStatus.refunded;
          return OrderStatus.active;
        },
      ),
      printMode: data['printMode'] == 'xeroxShop' ? PrintMode.xeroxShop : PrintMode.autonomous,
      printSettings: data['printSettings'] ?? {},
      totalPages: (data['totalPages'] ?? data['pages'] ?? 0).toInt(),
      totalPrice: (data['totalPrice'] ?? data['amount'] ?? 0).toDouble(),
      fileUrls: List<String>.from(data['fileUrls'] ?? []),
      publicIds: List<String>.from(data['publicIds'] ?? []),
      localFilePaths: List<String>.from(data['localFilePaths'] ?? []),
      reason: data['reason'],
      xeroxId: data['xeroxId']?.toString(),
      orderStatus: data['orderStatus']?.toString(),
      codeRevealed: data['codeRevealed'] == true,
      scanned: data['scanned'] == true,
      isPicked: data['isPicked'] == true,
      orderDone: data['orderDone'] == true,
      customId: data['customId']?.toString(),
      generateCoverPage: data['generateCoverPage'] == true,
      coverPageCharge: data['coverPageCharge'] != null ? (data['coverPageCharge'] as num).toDouble() : 0.0,
      coverPageUrl: data['coverPageUrl']?.toString(),
      coverPagePublicId: data['coverPagePublicId']?.toString(),
      printingCost: data['printingCost'] != null ? (data['printingCost'] as num).toDouble() : null,
      platformCommission: data['platformCommission'] != null ? (data['platformCommission'] as num).toDouble() : null,
      shopkeeperEarnings: data['shopkeeperEarnings'] != null ? (data['shopkeeperEarnings'] as num).toDouble() : null,
      platformEarnings: data['platformEarnings'] != null ? (data['platformEarnings'] as num).toDouble() : null,
      shopPricingUsed: data['shopPricingUsed'] is Map ? Map<String, dynamic>.from(data['shopPricingUsed'] as Map) : null,
      serviceId: data['serviceId']?.toString(),
      serviceName: data['serviceName']?.toString(),
      razorpayPaymentId: data['razorpayPaymentId']?.toString(),
      paymentStatus: data['paymentStatus']?.toString(),
      userEmail: data['userEmail']?.toString(),
      customerName: data['customerName']?.toString(),
      projectId: data['projectId']?.toString() ?? 'psfc-43b5a',
    );
  }

  factory PrintOrderModel.fromLocalMap(Map<String, dynamic> data) {
    return PrintOrderModel(
      orderId: data['orderId'] ?? '',
      pickupCode: data['pickupCode'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: DateTime.parse(data['createdAt']),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.active,
      ),
      printMode: data['printMode'] == 'xeroxShop' ? PrintMode.xeroxShop : PrintMode.autonomous,
      printSettings: data['printSettings'] ?? {},
      totalPages: (data['totalPages'] ?? data['pages'] ?? 0) as int,
      totalPrice: (data['totalPrice'] ?? data['amount'] ?? 0).toDouble(),
      fileUrls: List<String>.from(data['fileUrls'] ?? []),
      publicIds: List<String>.from(data['publicIds'] ?? []),
      localFilePaths: List<String>.from(data['localFilePaths'] ?? []),
      reason: data['reason'],
      xeroxId: data['xeroxId']?.toString(),
      codeRevealed: data['codeRevealed'] == true,
      scanned: data['scanned'] == true,
      isPicked: data['isPicked'] == true,
      orderDone: data['orderDone'] == true,
      customId: data['customId']?.toString(),
      orderStatus: data['orderStatus']?.toString(),
      generateCoverPage: data['generateCoverPage'] == true,
      coverPageCharge: data['coverPageCharge'] != null ? (data['coverPageCharge'] as num).toDouble() : 0.0,
      coverPageUrl: data['coverPageUrl']?.toString(),
      coverPagePublicId: data['coverPagePublicId']?.toString(),
      printingCost: data['printingCost'] != null ? (data['printingCost'] as num).toDouble() : null,
      platformCommission: data['platformCommission'] != null ? (data['platformCommission'] as num).toDouble() : null,
      shopkeeperEarnings: data['shopkeeperEarnings'] != null ? (data['shopkeeperEarnings'] as num).toDouble() : null,
      platformEarnings: data['platformEarnings'] != null ? (data['platformEarnings'] as num).toDouble() : null,
      shopPricingUsed: data['shopPricingUsed'] is Map ? Map<String, dynamic>.from(data['shopPricingUsed'] as Map) : null,
      serviceId: data['serviceId']?.toString(),
      serviceName: data['serviceName']?.toString(),
      razorpayPaymentId: data['razorpayPaymentId']?.toString(),
      paymentStatus: data['paymentStatus']?.toString(),
      projectId: data['projectId']?.toString() ?? 'psfc-43b5a',
    );
  }

  double get totalSizeKB {
    final List<dynamic> files = printSettings['files'] ?? [];
    double total = 0;
    for (var f in files) {
      total += double.tryParse(f['fileSizeKB']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  String? get shopName => printSettings['shopName']?.toString();
  String? get shopId => printSettings['shopId']?.toString();

  List<Map<String, dynamic>> get fileSettings {
    final List<dynamic> fList = printSettings['files'] ?? [];
    return fList.cast<Map<String, dynamic>>();
  }

  bool getIsColor(int index) {
    if (index < 0 || index >= fileSettings.length) return false;
    final color = fileSettings[index]['color']?.toString().toUpperCase();
    return color == 'COLOR';
  }

  bool getIsDuplex(int index) {
    if (index < 0 || index >= fileSettings.length) return false;
    return fileSettings[index]['doubleSided'] == true ||
        fileSettings[index]['isDoubleSided'] == true;
  }

  String getOrientation(int index) {
    if (index < 0 || index >= fileSettings.length) return 'portrait';
    return fileSettings[index]['orientation']?.toString().toLowerCase() ??
        'portrait';
  }

  int getCopies(int index) {
    if (index < 0 || index >= fileSettings.length) return 1;
    return (fileSettings[index]['copies'] ?? 1) as int;
  }

  int getPageCount(int index) {
    if (index >= 0 && index < fileSettings.length) {
      return (fileSettings[index]['pageCount'] ?? 1) as int;
    }
    return 1;
  }


  List<String> get filenames {
    final List<dynamic> fList = printSettings['files'] ?? [];
    return fList.map((f) => f['fileName']?.toString() ?? 'File').toList().cast<String>();
  }
  List<String> get displayFileUrls {
    if (generateCoverPage && fileUrls.isNotEmpty) {
      return fileUrls.sublist(1);
    }
    return fileUrls;
  }
  Map<String, dynamic> toFirestore() {
    return {
      'pickupCode': pickupCode,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'printSettings': printSettings,
      'totalPages': totalPages,
      'totalPrice': totalPrice,
      'fileUrls': fileUrls,
      'publicIds': publicIds,
      'localFilePaths': localFilePaths,
      if (reason != null) 'reason': reason,
      'codeRevealed': codeRevealed,
      'scanned': scanned,
      'isPicked': isPicked,
      'orderDone': orderDone,
      if (orderStatus != null) 'orderStatus': orderStatus,
      'printMode': isXerox ? 'xeroxShop' : 'autonomous',
      if (customId != null) 'customId': customId,
      'generateCoverPage': generateCoverPage,
      'coverPageCharge': coverPageCharge,
      if (coverPageUrl != null) 'coverPageUrl': coverPageUrl,
      if (coverPagePublicId != null) 'coverPagePublicId': coverPagePublicId,
      if (printingCost != null) 'printingCost': printingCost,
      if (platformCommission != null) 'platformCommission': platformCommission,
      if (shopkeeperEarnings != null) 'shopkeeperEarnings': shopkeeperEarnings,
      if (platformEarnings != null) 'platformEarnings': platformEarnings,
      if (shopPricingUsed != null) 'shopPricingUsed': shopPricingUsed,
      if (serviceId != null) 'serviceId': serviceId,
      if (serviceName != null) 'serviceName': serviceName,
      if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'pickupCode': pickupCode,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'printSettings': printSettings,
      'totalPages': totalPages,
      'totalPrice': totalPrice,
      'fileUrls': fileUrls,
      'publicIds': publicIds,
      'localFilePaths': localFilePaths,
      'reason': reason,
      'xeroxId': xeroxId,
      'codeRevealed': codeRevealed,
      'scanned': scanned,
      'isPicked': isPicked,
      'orderDone': orderDone,
      'customId': customId,
      'orderStatus': orderStatus,
      'printMode': isXerox ? 'xeroxShop' : 'autonomous',
      'generateCoverPage': generateCoverPage,
      'coverPageCharge': coverPageCharge,
      'coverPageUrl': coverPageUrl,
      'coverPagePublicId': coverPagePublicId,
      'printingCost': printingCost,
      'platformCommission': platformCommission,
      'shopkeeperEarnings': shopkeeperEarnings,
      'platformEarnings': platformEarnings,
      'shopPricingUsed': shopPricingUsed,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'razorpayPaymentId': razorpayPaymentId,
      'paymentStatus': paymentStatus,
      'projectId': projectId,
    };
  }

  // Create a copy with updated fields
  PrintOrderModel copyWith({
    String? orderId,
    String? pickupCode,
    String? userId,
    DateTime? createdAt,
    OrderStatus? status,
    PrintMode? printMode,
    Map<String, dynamic>? printSettings,
    int? totalPages,
    double? totalPrice,
    List<String>? fileUrls,
    List<String>? localFilePaths,
    String? reason,
    String? xeroxId,
    bool? codeRevealed,
    String? orderStatus,
    double? printingCost,
    double? platformCommission,
    double? shopkeeperEarnings,
    double? platformEarnings,
    Map<String, dynamic>? shopPricingUsed,
    String? serviceId,
    String? serviceName,
    String? razorpayPaymentId,
    String? paymentStatus,
    String? projectId,
  }) {
    return PrintOrderModel(
      orderId: orderId ?? this.orderId,
      pickupCode: pickupCode ?? this.pickupCode,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      printMode: printMode ?? this.printMode,
      printSettings: printSettings ?? this.printSettings,
      totalPages: totalPages ?? this.totalPages,
      totalPrice: totalPrice ?? this.totalPrice,
      fileUrls: fileUrls ?? this.fileUrls,
      publicIds: publicIds,
      localFilePaths: localFilePaths ?? this.localFilePaths,
      reason: reason ?? this.reason,
      xeroxId: xeroxId ?? this.xeroxId,
      codeRevealed: codeRevealed ?? this.codeRevealed,
      orderStatus: orderStatus ?? this.orderStatus,
      printingCost: printingCost ?? this.printingCost,
      platformCommission: platformCommission ?? this.platformCommission,
      shopkeeperEarnings: shopkeeperEarnings ?? this.shopkeeperEarnings,
      platformEarnings: platformEarnings ?? this.platformEarnings,
      shopPricingUsed: shopPricingUsed ?? this.shopPricingUsed,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      projectId: projectId ?? this.projectId,
    );
  }
}
