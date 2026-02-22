// ignore_for_file: undefined_function, undefined_method
@JS()
library razorpay_web_interop;

import 'package:js/js.dart';
import 'dart:convert';
import 'razorpay_handler.dart';

@JS('openRazorpayWebCheckout')
external void _openRazorpayWebCheckout(
  String options,
  void Function(String paymentId, String orderId, String signature) successCallback,
  void Function(String error) errorCallback,
);

class WebRazorpayHandler implements RazorpayHandler {
  @override
  void openCheckout({
    required Map<String, dynamic> options,
    required Function(String paymentId, String orderId, String signature) onSuccess,
    required Function(String error) onFailure,
  }) {
    _openRazorpayWebCheckout(
      jsonEncode(options),
      allowInterop((paymentId, orderId, signature) {
        onSuccess(paymentId, orderId, signature);
      }),
      allowInterop((error) {
        onFailure(error);
      }),
    );
  }

  @override
  void dispose() {}
}

RazorpayHandler getRazorpayHandler() => WebRazorpayHandler();
