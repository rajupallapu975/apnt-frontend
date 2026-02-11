class OrderModel {
  final String orderId;
  final String pickupCode;
  final int totalPages;
  final double totalPrice;

  OrderModel({
    required this.orderId,
    required this.pickupCode,
    required this.totalPages,
    required this.totalPrice,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Check if the response is wrapped in a 'data' object
    final Map<String, dynamic> d = (json.containsKey('data') && json['data'] is Map<String, dynamic>)
        ? json['data']
        : json;

    // Helper to find value by key (case-insensitive and common variants)
    dynamic find(List<String> keys) {
      for (final key in keys) {
        if (d.containsKey(key)) return d[key];
        // Case-insensitive check
        final match = d.keys.where((k) => k.toLowerCase() == key.toLowerCase());
        if (match.isNotEmpty) return d[match.first];
      }
      return null;
    }

    return OrderModel(
      orderId: (find(['orderId', 'id', 'order_id']) ?? '').toString(),
      pickupCode: (find(['pickupCode', 'pickup_code', 'code']) ?? '').toString(),
      totalPages: int.tryParse(find(['totalPages', 'total_pages', 'pages'])?.toString() ?? '0') ?? 0,
      totalPrice: double.tryParse(find(['totalPrice', 'total_price', 'price'])?.toString() ?? '0.0') ?? 0.0,
    );
  }
}
