import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_handler.dart';

class MobileRazorpayHandler implements RazorpayHandler {
  late Razorpay _razorpay;

  MobileRazorpayHandler() {
    _razorpay = Razorpay();
  }

  @override
  void openCheckout({
    required Map<String, dynamic> options,
    required Function(String paymentId, String orderId, String signature) onSuccess,
    required Function(String error) onFailure,
  }) {
    _razorpay.clear();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      onSuccess(response.paymentId!, response.orderId!, response.signature!);
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      onFailure(response.message ?? "Payment Failed");
    });
    _razorpay.open(options);
  }

  @override
  void dispose() {
    _razorpay.clear();
  }
}

RazorpayHandler getRazorpayHandler() => MobileRazorpayHandler();
