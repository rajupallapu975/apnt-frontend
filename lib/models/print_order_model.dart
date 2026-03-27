import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  active,
  expired,
  completed,
  cancelled,
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
  final DateTime expiresAt;
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
  
  bool get isXerox => printMode == PrintMode.xeroxShop;
  /// True if admin has confirmed printing is complete
  bool get isPrintingCompleted => 
    orderStatus == 'printing completed' || 
    orderStatus == 'order completed' || 
    orderStatus == 'completed' || 
    orderStatus == 'done';
  final PrintMode printMode;

  PrintOrderModel({
    required this.orderId,
    required this.pickupCode,
    required this.userId,
    required this.createdAt,
    required this.expiresAt,
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
  });

  // Check if order is expired
  bool get isExpired => (DateTime.now().isAfter(expiresAt) && status == OrderStatus.active) || status == OrderStatus.expired;

  // Check if order is active
  bool get isActive => status == OrderStatus.active && !isExpired;

  factory PrintOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrintOrderModel(
      orderId: doc.id,
      pickupCode: (data['pickupCode'] ?? '').toString(),
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.parse(data['createdAt'].toString()),
      expiresAt: data['expiresAt'] is Timestamp 
          ? (data['expiresAt'] as Timestamp).toDate() 
          : DateTime.parse(data['expiresAt'].toString()),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'].toString().toLowerCase(),
        orElse: () => OrderStatus.active,
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
    );
  }

  factory PrintOrderModel.fromLocalMap(Map<String, dynamic> data) {
    return PrintOrderModel(
      orderId: data['orderId'] ?? '',
      pickupCode: data['pickupCode'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: DateTime.parse(data['createdAt']),
      expiresAt: DateTime.parse(data['expiresAt']),
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

  List<String> get filenames {
    final List<dynamic> fList = printSettings['files'] ?? [];
    return fList.map((f) => f['fileName']?.toString() ?? 'File').toList().cast<String>();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pickupCode': pickupCode,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
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
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'pickupCode': pickupCode,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
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
      'orderStatus': orderStatus,
    };
  }

  // Create a copy with updated fields
  PrintOrderModel copyWith({
    String? orderId,
    String? pickupCode,
    String? userId,
    DateTime? createdAt,
    DateTime? expiresAt,
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
  }) {
    return PrintOrderModel(
      orderId: orderId ?? this.orderId,
      pickupCode: pickupCode ?? this.pickupCode,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
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
    );
  }
}


