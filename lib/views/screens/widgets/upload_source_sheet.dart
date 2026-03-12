import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/app_colors.dart';

class UploadSourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFiles;

  const UploadSourceSheet({
    super.key,
    required this.onCamera,
    required this.onGallery,
    required this.onFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 28),
            Text(
              'SELECT SOURCE',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                _sourceOption(context, icon: Icons.camera_alt_rounded, label: 'Camera', onTap: onCamera),
                const SizedBox(width: 14),
                _sourceOption(context, icon: Icons.photo_library_rounded, label: 'Gallery', onTap: onGallery),
                const SizedBox(width: 14),
                _sourceOption(context, icon: Icons.folder_rounded, label: 'Files', onTap: onFiles),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 30),
              const SizedBox(height: 10),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
