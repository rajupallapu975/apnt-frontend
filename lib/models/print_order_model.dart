import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  active,
  expired,
  completed,
  cancelled,
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

  PrintOrderModel({
    required this.orderId,
    required this.pickupCode,
    required this.userId,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.printSettings,
    required this.totalPages,
    required this.totalPrice,
    required this.fileUrls,
    this.publicIds = const [],
    this.localFilePaths = const [],
  });

  // Check if order is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt) && status == OrderStatus.active;

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
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.active,
      ),
      printSettings: data['printSettings'] ?? {},
      totalPages: data['totalPages'] ?? 0,
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      fileUrls: List<String>.from(data['fileUrls'] ?? []),
      publicIds: List<String>.from(data['publicIds'] ?? []),
      localFilePaths: List<String>.from(data['localFilePaths'] ?? []),
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
      printSettings: data['printSettings'] ?? {},
      totalPages: data['totalPages'] ?? 0,
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      fileUrls: List<String>.from(data['fileUrls'] ?? []),
      publicIds: List<String>.from(data['publicIds'] ?? []),
      localFilePaths: List<String>.from(data['localFilePaths'] ?? []),
    );
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
    Map<String, dynamic>? printSettings,
    int? totalPages,
    double? totalPrice,
    List<String>? fileUrls,
  }) {
    return PrintOrderModel(
      orderId: orderId ?? this.orderId,
      pickupCode: pickupCode ?? this.pickupCode,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      printSettings: printSettings ?? this.printSettings,
      totalPages: totalPages ?? this.totalPages,
      totalPrice: totalPrice ?? this.totalPrice,
      fileUrls: fileUrls ?? this.fileUrls,
      publicIds: publicIds ?? this.publicIds,
      localFilePaths: localFilePaths ?? this.localFilePaths,
    );
  }
}
