import 'package:flutter/foundation.dart';

/// Backend Configuration
/// Automatically selects the correct backend URL based on platform
class BackendConfig {
  /// Get the base URL for the backend based on the current platform
  /// Set this to false for Local Development, true for Render (Prod)
  static const bool isProduction = false; 

  /// Get the base URL for the backend based on current context
  static String get baseUrl {
    // ⚠️ UPDATE THIS IP to your LAPTOP'S CURRENT IP if testing locally on a real device
    const String laptopIp = "13.233.76.8";
    const String localUrl = "http://$laptopIp:5001";
    const String renderUrl = "http://13.233.76.8:5001"; // Updated to match user request as primary cloud URL too

    if (isProduction) return renderUrl;

    if (kIsWeb) {
      return "http://localhost:5000";
    } else {  
      return localUrl;
    }
  }

  

  /// Create Order endpoint
  static String get createOrderUrl => "$baseUrl/create-order";

  /// Razorpay endpoints
  static String get createRazorpayOrderUrl => "$baseUrl/create-razorpay-order";
  static String get verifyPaymentUrl => "$baseUrl/verify-payment";
  static String get refundPaymentUrl => "$baseUrl/refund-payment";
  static String get getXeroxShopsUrl => "$baseUrl/get-xerox-shops";

  /// Upload Files endpoint
  static String get uploadFilesUrl => "$baseUrl/upload-files";

  /// Complete Order endpoint
  static String get completeOrderUrl => "$baseUrl/complete-order";

  /// Delete Order Files endpoint (Cloudinary)
  static String get deleteOrderFilesUrl => "$baseUrl/delete-order-files";

  /// Print current configuration (for debugging)
  static void printConfig() {
    debugPrint('🔧 Backend Configuration:');
    debugPrint('   Platform: ${defaultTargetPlatform.name}');
    debugPrint('   Is Web: $kIsWeb');
    debugPrint('   Base URL: $baseUrl');
  }
}
