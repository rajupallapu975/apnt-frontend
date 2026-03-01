import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../utils/app_colors.dart';
import '../../widgets/common/primary_button.dart';

class PaymentErrorPage extends StatelessWidget {
  final String message;
  final Function(BuildContext context) onRetry;
  final Function(BuildContext context) onGoBack;

  const PaymentErrorPage({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // ❌ Error Icon with Shake Animation
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 64),
              ).animate().shake(duration: 500.ms),

              const SizedBox(height: 40),

              Text(
                'SOMETHING WENT WRONG',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 24),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 16),

              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 400.ms),

              const Spacer(),

              PrimaryButton(
                label: 'RETRY',
                onPressed: () => onRetry(context),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () => onGoBack(context),
                  child: const Text('CANCEL'),
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
