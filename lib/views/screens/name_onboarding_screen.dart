import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/app_colors.dart';

class NameOnboardingScreen extends StatefulWidget {
  const NameOnboardingScreen({super.key});

  @override
  State<NameOnboardingScreen> createState() => _NameOnboardingScreenState();
}

class _NameOnboardingScreenState extends State<NameOnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill name from Google account if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      if (authVM.user?.displayName != null && authVM.user!.displayName!.isNotEmpty) {
        _nameController.text = authVM.user!.displayName!;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authVM = context.read<AuthViewModel>();
      await authVM.updateDisplayName(_nameController.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving name: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // 🎭 Animated Background Orb
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryBlue.withValues(alpha: 0.1),
                      AppColors.primaryBlue.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 1200.ms).scale(begin: const Offset(0.6, 0.6)),
  
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon badge
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.face_retouching_natural_rounded,
                              color: AppColors.primaryBlue,
                              size: 36,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack),
  
                          const SizedBox(height: 24),
  
                          // Title
                          Text(
                            "What should we call you?",
                            style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 600.ms)
                          .slideY(begin: 0.2, end: 0),
  
                          const SizedBox(height: 8),
  
                          // Subtitle
                          Text(
                            "Your name will be used on the printed cover page so the shop owner can identify your prints easily.",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 600.ms)
                          .slideY(begin: 0.2, end: 0),
  
                          const SizedBox(height: 32),
  
                          // Input field
                          TextFormField(
                            controller: _nameController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText: "Full Name",
                              labelStyle: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.textSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.error),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your name";
                              }
                              if (value.trim().length < 2) {
                                return "Name must be at least 2 characters";
                              }
                              return null;
                            },
                          )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 600.ms)
                          .slideY(begin: 0.2, end: 0),
  
                          const SizedBox(height: 24),
  
                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitName,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Continue",
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded, size: 18),
                                      ],
                                    ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 650.ms, duration: 600.ms)
                          .slideY(begin: 0.2, end: 0),
  
                          const SizedBox(height: 16),
  
                          // Sign Out Button (to switch accounts if needed, but not bypass)
                          Center(
                            child: TextButton(
                              onPressed: _isSubmitting ? null : () async {
                                final authVM = context.read<AuthViewModel>();
                                await authVM.signOut();
                              },
                              child: Text(
                                "Cancel & Sign Out",
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 750.ms, duration: 600.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
