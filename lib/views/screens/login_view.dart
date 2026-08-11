import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),

                          // 🔷 Brand Logo with Premium Breath Animation (Long-press for Reviewer Auth)
                          GestureDetector(
                            onLongPress: () => _showEmailSignInDialog(context, authViewModel),
                            child: Hero(
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
                          ),

                          const SizedBox(height: 48),

                          // 🖋️ Typography Hierarchy
                          Text.rich(
                            TextSpan(
                              text: 'zik',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                letterSpacing: -1.5,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                              children: [
                                TextSpan(
                                  text: 'rint',
                                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    letterSpacing: -1.5,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
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

                          const SizedBox(height: 40),

                          /// 🔐 AUTH SECTION
                          if (authViewModel.isLoading)
                            const SizedBox(
                              height: 56,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                ),
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
                                if (authViewModel.showEmailLogin) ...[
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: () => _showEmailSignInDialog(context, authViewModel),
                                    icon: const Icon(Icons.email_outlined, size: 16, color: AppColors.primaryBlue),
                                    label: Text(
                                      'Sign in with Email',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                            .animate()
                            .fadeIn(delay: 800.ms, duration: 800.ms)
                            .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailSignInDialog(BuildContext context, AuthViewModel authViewModel) {
    final emailController = TextEditingController(text: 'reviewer@zikrint.app');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 10),
            Text(
              'Reviewer Sign In',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Use official reviewer credentials to evaluate Zikrint test mode.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await authViewModel.signInWithEmail(
                emailController.text,
                passwordController.text,
              );
              nav.pop();
              if (!success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Sign in failed. Please check credentials.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
