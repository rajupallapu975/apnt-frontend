import 'package:apnt/viewmodels/auth/tester_viewmodel.dart';
import 'package:apnt/views/screens/auth/login_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../viewmodels/auth/auth_viewmodel.dart';
import '../utils/app_colors.dart';
import '../widgets/common/primary_button.dart';
import '../services/firestore_service.dart';
import '../models/print_order_model.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _showOrdersStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _OrdersStatsSheet(),
    );
  }

  void _showEditProfileSheet(BuildContext context, AuthViewModel authVM) {
    final nameController = TextEditingController(text: authVM.displayName ?? authVM.user?.displayName ?? '');
    final phoneController = TextEditingController(text: authVM.phoneNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EDIT PROFILE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.greyDark),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Full Name field
              Text(
                'FULL NAME',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Full name cannot be empty';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mobile Number field
              Text(
                'MOBILE NUMBER',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter 10 digit phone number',
                  prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length < 10) {
                    return 'Enter valid 10-digit number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'SAVE CHANGES',
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final newName = nameController.text.trim();
                    final newPhone = phoneController.text.trim();

                    if (newName.isNotEmpty) {
                      await authVM.updateDisplayName(newName);
                    }
                    if (newPhone.isNotEmpty) {
                      await authVM.updatePhoneNumber(newPhone);
                    }

                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPhoneSheet(BuildContext context, AuthViewModel authVM) {
    final controller = TextEditingController(text: authVM.phoneNumber);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UPDATE MOBILE NUMBER',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Enter 10 digit number',
                prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.primaryBlue),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'SAVE NUMBER',
              onPressed: () async {
                if (controller.text.length >= 10) {
                  await authVM.updatePhoneNumber(controller.text);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUPPORT CENTER',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _supportItem(Icons.email_outlined, 'Email Support', 'zikrint975@gmail.com', AppColors.primaryBlue),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _supportItem(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthViewModel authVM) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete Account?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete your account?',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryBlack),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '⚠️ PERMANENT ACTION: This will completely and permanently erase your account, order history, uploaded files, and settings. This CANNOT be undone.',
                      style: GoogleFonts.manrope(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w700, height: 1.4),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                if (!isDeleting)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('CANCEL', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.greyDark, fontSize: 13)),
                  ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setState(() {
                            isDeleting = true;
                          });
                          try {
                            await authVM.deleteAccount();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              if (context.mounted) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Your account has been completely and permanently deleted.'),
                                    backgroundColor: AppColors.primaryBlack,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setState(() {
                                isDeleting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    elevation: 0,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('DELETE PERMANENTLY', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1), width: 8),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.greyLight,
                          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                          child: user?.photoURL == null ? const Icon(Icons.person, size: 60, color: AppColors.primaryBlue) : null,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    authVM.displayName ?? user?.displayName ?? 'Welcome User',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryBlack),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Not signed in',
                    style: GoogleFonts.manrope(fontSize: 14, color: AppColors.greyDark, fontWeight: FontWeight.w500),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                  if (authVM.phoneNumber != null && authVM.phoneNumber!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      authVM.phoneNumber!,
                      style: GoogleFonts.manrope(fontSize: 14, color: AppColors.greyDark, fontWeight: FontWeight.w600),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2, end: 0),
                  ],
                ],
              ),
            ),

            /// ⚙️ SETTINGS LIST
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _profileItem(
                    icon: Icons.edit_note_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Update your name and phone number',
                    color: AppColors.primaryBlue,
                    onTap: () => _showEditProfileSheet(context, authVM),
                  ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 16),
                  _profileItem(
                    icon: Icons.history_rounded,
                    title: 'Orders',
                    subtitle: 'Check your print statistics and history',
                    color: AppColors.primaryBlue,
                    onTap: () => _showOrdersStats(context),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 16),
                  _profileItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Support Center',
                    subtitle: 'Get help with your print orders',
                    color: AppColors.greyDark,
                    onTap: () => _showSupportCenter(context),
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 16),

                  /// 🗑️ DELETE ACCOUNT ITEM
                  _profileItem(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete account and all data',
                    color: AppColors.error,
                    onTap: () => _showDeleteAccountDialog(context, authVM),
                  ).animate().fadeIn(delay: 650.ms).slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 48),

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
                        final testerVM = context.read<TesterViewModel>();
                        await testerVM.signOut();
                        await authVM.signOut(testerVM);
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginView()),
                            (route) => false,
                          );
                        }
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
          border: Border.all(color: AppColors.greyLight.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
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

class _OrdersStatsSheet extends StatelessWidget {
  const _OrdersStatsSheet();

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER STATISTICS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          FutureBuilder<Map<String, dynamic>>(
            future: firestoreService.getUserStatistics(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 100);
              
              final stats = snapshot.data!;
              final double totalAmount = (stats['totalAmount'] as num?)?.toDouble() ?? 0.0;
              final int totalOrders = (stats['totalOrders'] as num?)?.toInt() ?? 0;
              final int totalPages = (stats['totalPages'] as num?)?.toInt() ?? 0;
              final int totalFiles = (stats['totalFiles'] as num?)?.toInt() ?? 0;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlack,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 15)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACCOUNT-WIDE STATISTICS', 
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1)),
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('₹${totalAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 8),
                          child: Text('SPENT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text('$totalOrders ORDERS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statMini('TOTAL PAGES', '$totalPages'),
                        _statMini('TOTAL FILES', '$totalFiles'),
                        _statMini('ACC LEVEL', totalAmount > 500 ? 'GOLD' : 'SILVER'),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0);
            },
          ),

          const SizedBox(height: 16),

          // Box 2: Active Prints (CLOUD)
          StreamBuilder<List<PrintOrderModel>>(
            stream: firestoreService.getActiveOrders(),
            builder: (context, snapshot) {
              final orders = snapshot.data ?? [];
              final activeCount = orders.length;
              
              int activePages = 0;
              double activeAmount = 0;

              for (var o in orders) {
                activePages += o.totalPages;
                activeAmount += o.totalPrice;
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTIVE PRINTS', 
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1)),
                        const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$activeCount', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 8),
                          child: Text('ORDERS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
                        ),
                        const Spacer(),
                        _statMini('ACTIVE PAGES', '$activePages'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statMini('ACTIVE AMOUNT', '₹${activeAmount.toStringAsFixed(0)}'),
                        _statMini('STATUS', 'PRINTING'),
                        _statMini('SPEED', '100%'),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
            },
          ),
          const SizedBox(height: 32),
        ],
        ),
      ),
    );
  }

  Widget _statMini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.5))),
        Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }
}
