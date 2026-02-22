import 'package:flutter/foundation.dart';

/// Backend Configuration
/// Automatically selects the correct backend URL based on platform
class BackendConfig {
  /// Get the base URL for the backend based on the current platform
  // static String get baseUrl {
  //   if (kIsWeb) {
  //     // Web: Use localhost (same machine)
  //     return "https://printer-backend-ch2e.onrender.com";
  //   } else if (defaultTargetPlatform == TargetPlatform.android) {
  //     // Android: Use Windows PC IP address
  //     // Make sure your Android device is on the same WiFi network
  //     return "https://printer-backend-ch2e.onrender.com";
  //   } else if (defaultTargetPlatform == TargetPlatform.iOS) {
  //     // iOS: Use Windows PC IP address
  //     // Make sure your iOS device is on the same WiFi network
  //     return "https://printer-backend-ch2e.onrender.com";
  //   } else {
  //     // Fallback for other platforms (Linux, macOS, Windows desktop)
  //     return "https://printer-backend-ch2e.onrender.com";
  //   }
  // }

  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5000";
    }
    
    // For mobile (Android/iOS)
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      // 💡 If using Android Emulator, use 10.0.2.2 instead.
      // 💡 If using Physical Device, use your laptop's IP (10.14.211.155).
      return "http://10.14.211.155:5000";
    }
    
    return "http://localhost:5000";
  }

  /// Create Order endpoint
  static String get createOrderUrl => "$baseUrl/create-order";

  /// Razorpay endpoints
  static String get createRazorpayOrderUrl => "$baseUrl/create-razorpay-order";
  static String get verifyPaymentUrl => "$baseUrl/verify-payment";

  /// Upload Files endpoint
  static String get uploadFilesUrl => "$baseUrl/upload-files";

  /// Print current configuration (for debugging)
  static void printConfig() {
    print('🔧 Backend Configuration:');
    print('   Platform: ${defaultTargetPlatform.name}');
    print('   Is Web: $kIsWeb');
    print('   Base URL: $baseUrl');
  }
}
