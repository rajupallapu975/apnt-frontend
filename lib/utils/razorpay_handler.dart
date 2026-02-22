import 'razorpay_handler_mobile.dart' if (dart.library.js) 'razorpay_handler_web.dart';

abstract class RazorpayHandler {
  void openCheckout({
    required Map<String, dynamic> options,
    required Function(String paymentId, String orderId, String signature) onSuccess,
    required Function(String error) onFailure,
  });
  
  void dispose();
  
  factory RazorpayHandler() => getRazorpayHandler();
}
