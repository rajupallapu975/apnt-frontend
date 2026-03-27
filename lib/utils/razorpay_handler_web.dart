import 'dart:js_interop';
import 'dart:convert';
import 'razorpay_handler.dart';

@JS('openRazorpayWebCheckout')
external void _openRazorpayWebCheckout(
  JSString options,
  JSFunction successCallback,
  JSFunction errorCallback,
);

class WebRazorpayHandler implements RazorpayHandler {
  @override
  void openCheckout({
    required Map<String, dynamic> options,
    required Function(String paymentId, String orderId, String signature) onSuccess,
    required Function(String error) onFailure,
  }) {
    _openRazorpayWebCheckout(
      jsonEncode(options).toJS,
      ((JSString paymentId, JSString orderId, JSString signature) {
        onSuccess(paymentId.toDart, orderId.toDart, signature.toDart);
      }).toJS,
      ((JSString error) {
        onFailure(error.toDart);
      }).toJS,
    );
  }

  @override
  void dispose() {}
}

RazorpayHandler getRazorpayHandler() => WebRazorpayHandler();
