import 'package:flutter/material.dart';

class PaymentErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onGoBack;

  const PaymentErrorPage({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Something went wrong")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 72),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text("Retry"),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onGoBack,
                    child: const Text("Go Back"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
