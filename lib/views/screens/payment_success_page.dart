import 'package:flutter/material.dart';

class PaymentSuccessPage extends StatelessWidget {
  final String orderId;
  final String pickupCode;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.pickupCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Successful")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              "Payment Successful!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text("Order ID: $orderId"),
            const SizedBox(height: 8),
            Text(
              "Pickup Code: $pickupCode",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
