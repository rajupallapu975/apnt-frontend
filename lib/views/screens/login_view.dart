import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/google_slider_button.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    // 🔑 Key to control slider reset
    final sliderKey = GlobalKey<GoogleSliderButtonState>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 1.0],
            colors: [
              const Color(0xFF6366F1).withOpacity(0.08),
              Colors.white,
              const Color(0xFF6366F1).withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // 🔷 Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF6366F1).withOpacity(0.1),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/image.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 48),

                Text(
                  'ThinkInk',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                    letterSpacing: -1,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Precision printing, perfectly handled',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),

                const Spacer(flex: 1),

                /// 🔐 AUTH AREA
                if (authViewModel.isLoading)
                  const CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                  )
                else
                  GoogleSliderButton(
                    key: sliderKey,
                    onAction: () async {
                      final success = await authViewModel.signIn();

                      // 🔁 Reset slider if sign-in failed
                      if (!success) {
                        sliderKey.currentState?.reset();
                      }
                    },
                  ),

                const SizedBox(height: 24),

                const Text(
                  'Verified security with Google Auth',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
