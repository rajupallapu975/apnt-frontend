import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../viewmodels/upload_viewmodel.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/modern_card.dart';

import '../../models/print_order_model.dart';
import '../../models/file_model.dart';
import '../../repositories/order_repository.dart';
import 'print_options/print_options_page.dart';
import 'history_page.dart';
import 'widgets/order_details_sheet.dart';
import '../profile_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final OrderRepository _orderRepo = OrderRepository();


  void _showUploadSheet(UploadViewModel uploadVM) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadSourceSheet(
        onCamera: () async {
          Navigator.pop(context);
          await uploadVM.pickFromCamera();
          if (!context.mounted) return;
          if (uploadVM.files.isEmpty) return;
          final files = List<FileModel>.from(uploadVM.files);
          uploadVM.clearPickedFiles();
          if (!context.mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => PrintOptionsPage(pickedFiles: files)));
        },
        onGallery: () async {
          Navigator.pop(context);
          await uploadVM.pickFromGallery();
          if (!context.mounted) return;
          if (uploadVM.files.isEmpty) return;
          final files = List<FileModel>.from(uploadVM.files);
          uploadVM.clearPickedFiles();
          if (!context.mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => PrintOptionsPage(pickedFiles: files)));
        },
        onFiles: () async {
          Navigator.pop(context);
          await uploadVM.pickFromFiles();
          if (!context.mounted) return;
          if (uploadVM.files.isEmpty) return;
          final files = List<FileModel>.from(uploadVM.files);
          uploadVM.clearPickedFiles();
          if (!context.mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => PrintOptionsPage(pickedFiles: files)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadVM = context.watch<UploadViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'THINK INK',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: uploadVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(uploadVM),
                    const SizedBox(height: 32),
                    _buildActiveOrdersHeader(),
                    const SizedBox(height: 16),
                    _buildOrdersList(),

                    // ─── Pending File Tray ───────────────────────────────────
                    if (uploadVM.pendingFiles.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildPendingTray(uploadVM),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Documents Hero Card ─────────────────────────────────────────────────────
  Widget _buildHeroSection(UploadViewModel uploadVM) {
    const bulletColor = AppColors.primaryBlue;
    final bulletStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      height: 1.5,
    );

    return ModernCard(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: Text Content ──
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documents',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2D3142),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _bullet(bulletStyle, bulletColor, 'Price starting at ₹3/page'),
                const SizedBox(height: 6),
                _bullet(bulletStyle, bulletColor, 'Paper quality: 70 GSM'),
                const SizedBox(height: 6),
                _bullet(bulletStyle, bulletColor, 'Single side prints'),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _showUploadSheet(uploadVM),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(
                      'Upload Files',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ── Right: Document Fan Illustration ──
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back card
                  Transform.rotate(
                    angle: 0.2,
                    child: _illustrationCard(Icons.image_rounded, AppColors.success.withValues(alpha: 0.7), 'JPG'),
                  ),
                  // Middle card
                  Transform.rotate(
                    angle: -0.1,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: _illustrationCard(Icons.article_rounded, AppColors.primaryBlue.withValues(alpha: 0.8), 'DOC'),
                    ),
                  ),
                  // Front card
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8),
                    child: _illustrationCard(Icons.picture_as_pdf_rounded, AppColors.error.withValues(alpha: 0.85), 'PDF'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05, end: 0, duration: 400.ms);
  }

  Widget _bullet(TextStyle style, Color iconColor, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.stars_rounded, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: style.copyWith(
              fontSize: 14,
              color: const Color(0xFF4F5B7D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _illustrationCard(IconData icon, Color color, String label) {
    return Container(
      width: 80,
      height: 113, // 80 / 113.1 = 0.707 (A4 Ratio)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Top colored header
            Container(height: 35, color: color),
            // Title placeholder
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Body lines
            Positioned(
              top: 45,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  5,
                  (i) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    height: 4,
                    width: i == 4 ? 40 : double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(2),
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


  // ─── Active Orders Header ────────────────────────────────────────────────────
  Widget _buildActiveOrdersHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'ACTIVE PRINTS',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 1.5, color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
          child: const Text('VIEW ALL'),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  // ─── Orders Stream ───────────────────────────────────────────────────────────
  Widget _buildOrdersList() {
    return StreamBuilder<List<PrintOrderModel>>(
      stream: _orderRepo.getActiveOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final activeOrders = snapshot.data!.where((o) => o.isActive).toList();

        if (activeOrders.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'No active orders',
                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activeOrders.length,
          itemBuilder: (context, index) => _buildOrderCard(activeOrders[index])
              .animate()
              .fadeIn(delay: (index * 80).ms)
              .slideY(begin: 0.1, end: 0),
        );
      },
    );
  }

  void _showOrderDetails(PrintOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderDetailsSheet(order: order),
    );
  }

  // ─── Order Card (Unique Code + Name only) ────────────────────────────────────
  Widget _buildOrderCard(PrintOrderModel order) {
    final shortName = 'Order #${order.orderId.substring(0, 6).toUpperCase()}';

    return InkWell(
      onTap: () => _showOrderDetails(order),
      borderRadius: BorderRadius.circular(16),
      child: ModernCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            // ── Code accent bar ──
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            // ── Name column ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NAME',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shortName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // ── Unique Code column ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'UNIQUE CODE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.pickupCode,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Blinkit-style Pending Tray ──────────────────────────────────────────────
  Widget _buildPendingTray(UploadViewModel uploadVM) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PENDING UPLOAD',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${uploadVM.pendingFiles.length}',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.warning),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: uploadVM.pendingFiles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final file = uploadVM.pendingFiles[i];
              return _PendingFileChip(
                file: file,
                onRemove: () => uploadVM.removeFile(file.id),
                onTap: () {
                  // Re-open just this file in PrintOptionsPage
                  final files = List<FileModel>.from(uploadVM.pendingFiles);
                  uploadVM.clearPickedFiles();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PrintOptionsPage(pickedFiles: files)),
                  );
                },
              ).animate().fadeIn(delay: (i * 60).ms).scale(begin: const Offset(0.9, 0.9));
            },
          ),
        ),
      ],
    );
  }
}

// ─── Pending File Chip (Blinkit-style) ──────────────────────────────────────
class _PendingFileChip extends StatelessWidget {
  final FileModel file;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PendingFileChip({
    required this.file,
    required this.onRemove,
    required this.onTap,
  });

  bool get _isPdf => file.name.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Progress ring ──
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  ),
                ),
                Icon(
                  _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                  size: 20,
                  color: _isPdf ? AppColors.error : AppColors.primaryBlue,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                file.name.length > 10 ? '${file.name.substring(0, 8)}…' : file.name,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Upload Source Bottom Sheet ──────────────────────────────────────────────
class _UploadSourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFiles;

  const _UploadSourceSheet({
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
