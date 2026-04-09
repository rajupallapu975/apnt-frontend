class XeroxShopModel {
  final String id;
  final String name;
  final String address;
  final double rating;
  final String distance;
  final String imageUrl;
  final bool isOpen;
  final double pricePerBWPage;
  final double pricePerColorPage;
  final int activePrinters; // Added active printers count

  final String? ownerName;
  final String? phoneNumber;
  final String? email;
  final String? openingTime;
  final String? closingTime;

  XeroxShopModel({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.distance,
    required this.imageUrl,
    required this.isOpen,
    required this.pricePerBWPage,
    required this.pricePerColorPage,
    this.activePrinters = 0,
    this.ownerName,
    this.phoneNumber,
    this.email,
    this.openingTime,
    this.closingTime,
  });

  bool get isCurrentlyOpen {
    if (openingTime == null || closingTime == null) return isOpen;
    
    try {
      final now = DateTime.now();
      final opening = _parseTimeString(openingTime!);
      final closing = _parseTimeString(closingTime!);
      
      final currentMinutes = now.hour * 60 + now.minute;
      final openMinutes = opening.hour * 60 + opening.minute;
      final closeMinutes = closing.hour * 60 + closing.minute;

      if (closeMinutes < openMinutes) {
        // Shop stays open past midnight
        return currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
      }
      return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
    } catch (_) {
      return isOpen;
    }
  }

  DateTime _parseTimeString(String timeStr) {
    // Handles formats like "09:00 AM" or "21:30"
    final now = DateTime.now();
    try {
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        final parts = timeStr.split(' ');
        final hm = parts[0].split(':');
        int hour = int.parse(hm[0]);
        int minute = int.parse(hm[1]);
        if (parts[1] == 'PM' && hour < 12) hour += 12;
        if (parts[1] == 'AM' && hour == 12) hour = 0;
        return DateTime(now.year, now.month, now.day, hour, minute);
      } else {
        final hm = timeStr.split(':');
        return DateTime(now.year, now.month, now.day, int.parse(hm[0]), int.parse(hm[1]));
      }
    } catch (_) {
      return now;
    }
  }

  factory XeroxShopModel.fromMap(Map<String, dynamic> map, String id) {
    // 🚀 Robust Field Mapping: The Dashboard uses 'mobile' while models traditionally used 'phoneNumber'
    final dynamic rawMobile = map['mobile'] ?? map['phone'] ?? map['phoneNumber'] ?? 'N/A';
    final String? phoneNumber = (rawMobile.toString() == 'N/A' || rawMobile.toString().isEmpty) 
        ? null 
        : rawMobile.toString();

    return XeroxShopModel(
      id: id,
      name: map['shopName'] ?? 'Unknown Shop',
      address: map['address'] ?? 'No Address provided',
      rating: (map['rating'] ?? 4.5).toDouble(),
      distance: 'Nearby', 
      imageUrl: map['imageUrl'] ?? '',
      isOpen: map['isOpen'] ?? true, // Manual override from DB
      pricePerBWPage: (map['pricePerBWPage'] ?? map['priceBW'] ?? 3.0).toDouble(),
      pricePerColorPage: (map['pricePerColorPage'] ?? map['priceColor'] ?? 10.0).toDouble(),
      activePrinters: map['activePrinters'] ?? 0,
      ownerName: map['ownerName'] ?? 'Shop Keeper',
      phoneNumber: phoneNumber,
      email: map['email'],
      openingTime: map['openingTime'] ?? '09:00 AM',
      closingTime: map['closingTime'] ?? '09:00 PM',
    );
  }
}
