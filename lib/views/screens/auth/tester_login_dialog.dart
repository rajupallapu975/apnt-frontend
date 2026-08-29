import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../viewmodels/auth/tester_viewmodel.dart';
import '../../../utils/app_colors.dart';
import '../upload_page.dart';

class TesterLoginDialog extends StatefulWidget {
  final TesterViewModel testerViewModel;

  const TesterLoginDialog({super.key, required this.testerViewModel});

  @override
  State<TesterLoginDialog> createState() => _TesterLoginDialogState();
}

class _TesterLoginDialogState extends State<TesterLoginDialog> {
  final _emailController = TextEditingController(text: 'reviewer@zikrint.app');
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            controller: _emailController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_isSubmitting,
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
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() {
                    _isSubmitting = true;
                  });

                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    final success = await widget.testerViewModel.signInWithEmail(
                      _emailController.text,
                      _passwordController.text,
                    );
                    nav.pop();
                    if (success) {
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const UploadPage()),
                        (route) => false,
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Sign in failed. Please check credentials.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  } catch (e) {
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Sign In'),
        ),
      ],
    );
  }
}

void showTesterLoginDialog(BuildContext context, TesterViewModel testerViewModel) {
  showDialog(
    context: context,
    builder: (context) => TesterLoginDialog(testerViewModel: testerViewModel),
  );
}
