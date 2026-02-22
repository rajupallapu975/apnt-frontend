import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/app_colors.dart';
import '../widgets/common/primary_button.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final user = authVM.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'ACCOUNT',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryBlack,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// 👤 USER HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1), width: 8),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.greyLight,
                          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                          child: user?.photoURL == null ? const Icon(Icons.person, size: 60, color: AppColors.primaryBlue) : null,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                      ).animate().fadeIn(delay: 400.ms).scale(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    user?.displayName ?? 'Welcome User',
                    style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryBlack),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Not signed in',
                    style: GoogleFonts.manrope(fontSize: 14, color: AppColors.greyDark, fontWeight: FontWeight.w500),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),

            /// ⚙️ SETTINGS LIST
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _profileItem(
                    icon: Icons.history_rounded,
                    title: 'Order Tracking',
                    subtitle: 'Check your active and past prints',
                    color: AppColors.primaryBlue,
                    onTap: () => Navigator.pop(context),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 16),
                  _profileItem(
                    icon: Icons.security_rounded,
                    title: 'Privacy & Security',
                    subtitle: 'Manage your data and account info',
                    color: AppColors.primaryBlack,
                    onTap: () {},
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 16),
                  _profileItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Support Center',
                    subtitle: 'Get help with your print orders',
                    color: AppColors.greyDark,
                    onTap: () {},
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 56),

                  /// 🚪 LOGOUT BUTTON
                  PrimaryButton(
                    label: 'LOGOUT',
                    icon: Icons.logout_rounded,
                    backgroundColor: AppColors.error,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: const Text('Confirm Logout'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await authVM.signOut();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.greyLight.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: AppColors.greyDark, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.greyLight, size: 14),
          ],
        ),
      ),
    );
  }
}
