import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/google_slider_button.dart';
import '../../utils/app_colors.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final sliderKey = GlobalKey<GoogleSliderButtonState>();

    return Scaffold(
      body: Stack(
        children: [
          // 🎭 Animated Abstract Background
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryBlue.withValues(alpha: 0.08),
                    AppColors.primaryBlue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1500.ms).scale(begin: const Offset(0.5, 0.5)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // 🔷 Brand Logo with Premium Breath Animation
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.mediumShadow,
                      ),
                      child: Image.asset(
                        'assets/image.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack)
                  .shimmer(delay: 1000.ms, duration: 2000.ms, color: AppColors.primaryBlue.withValues(alpha: 0.1)),

                  const SizedBox(height: 48),

                  // 🖋️ Typography Hierarchy
                  Text(
                    'THINK INK',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      letterSpacing: -2,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 12),

                  Text(
                    'Precision printing, perfectly handled.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),

                  const Spacer(flex: 2),

                  /// 🔐 AUTH SECTION
                  if (authViewModel.isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                    ).animate().scale()
                  else
                    Column(
                      children: [
                        GoogleSliderButton(
                          key: sliderKey,
                          onAction: () async {
                            final success = await authViewModel.signIn();
                            if (!success) {
                              sliderKey.currentState?.reset();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sign in failed. Please try again.'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 8),
                            Text(
                              'Secure Google Authentication',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 800.ms)
                    .slideY(begin: 0.1, end: 0),

                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
