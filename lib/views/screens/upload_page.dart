import 'package:apnt/xerox_shop/xerox_shop_page.dart';
import 'package:flutter/foundation.dart';
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
import 'notifications_page.dart';
import '../../services/notification_service.dart';
import '../../services/pwa_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/print_mode_selection_sheet.dart';
import 'widgets/upload_source_sheet.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final OrderRepository _orderRepo = OrderRepository();

  @override
  void initState() {
    super.initState();
    // 🔔 Prompt for notifications on home entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationService>().requestPermission();
        _checkPWAInstallation();
      }
    });
  }

  Future<void> _checkPWAInstallation() async {
    if (!kIsWeb) return;

    final pwa = PWAService();
    if (!pwa.canInstall) return;

    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('pwa_prompted') ?? false;

    if (!hasPrompted && mounted) {
      // ⏳ Small delay to not overwhelm on entry
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: [
              const Icon(Icons.install_mobile_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Text('INSTALL APP', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          content: const Text('Install ThinkInk on your home screen for a fast, app-like experience and easy access.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('NOT NOW', style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('INSTALL'),
            ),
          ],
        ),
      );

      if (shouldInstall == true) {
        await pwa.promptInstall();
      }
      
      // Mark as prompted so we don't ask again this session/re-login
      await prefs.setBool('pwa_prompted', true);
    }
  }


  void _showModeSheet({List<FileModel>? existingFiles}) {
    final uploadVM = context.read<UploadViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrintModeSelectionSheet(
        onSelected: (mode) {
          if (mode == PrintMode.xeroxShop) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => XeroxShopPage(files: existingFiles ?? []),
              ),
            );
            return;
          }

          if (existingFiles != null && existingFiles.isNotEmpty) {
             _handleSelectedFiles(mode, existingFiles);
          } else {
             _showSourceSheet(mode, uploadVM);
          }
        },
      ),
    );
  }

  void _showSourceSheet(PrintMode mode, UploadViewModel uploadVM) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadSourceSheet(
        onCamera: () async {
          Navigator.pop(context);
          await uploadVM.pickFromCamera();
          if (!context.mounted) return;
          if (uploadVM.files.isEmpty) return;
          _handleUploadedFiles(mode, uploadVM);
        },
        onGallery: () async {
          Navigator.pop(context);
          await uploadVM.pickFromGallery();
          if (!context.mounted) return;
          if (uploadVM.files.isEmpty) return;
          _handleUploadedFiles(mode, uploadVM);
        },
        onFiles: () async {
          Navigator.pop(context);
          await uploadVM.pickFromFiles();
          if (!context.mounted) return;
          if (uploadVM.files.isEmpty) return;
          _handleUploadedFiles(mode, uploadVM);
        },
      ),
    );
  }

  void _handleUploadedFiles(PrintMode mode, UploadViewModel uploadVM) {
    final files = List<FileModel>.from(uploadVM.files);
    uploadVM.clearPickedFiles();
    _handleSelectedFiles(mode, files);
  }

  void _handleSelectedFiles(PrintMode mode, List<FileModel> files) {
    if (mode == PrintMode.autonomous) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrintOptionsPage(
            pickedFiles: files,
            printMode: mode,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => XeroxShopPage(files: files),
        ),
      );
    }
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
            icon: const Icon(Icons.history_rounded, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 24),
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
                    onPressed: _showModeSheet,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVE PRINTS',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
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
    // 🆔 Use the custom Order ID (PRT(xxxx)) for Xerox, otherwise short Firestore ID
    final String? customId = order.printSettings['orderId'];
    final String displayId = (customId != null && customId.isNotEmpty) 
        ? customId.toUpperCase() 
        : 'JOB #${order.orderId.substring(0, 6).toUpperCase()}';

    return Stack(
      children: [
        InkWell(
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
                    color: order.isXerox ? AppColors.success : AppColors.primaryBlue,
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
                        displayId,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.5,
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
                      order.isXerox ? 'STATUS' : 'UNIQUE CODE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.isXerox ? 'READY' : order.pickupCode,
                      style: GoogleFonts.inter(
                        fontSize: order.isXerox ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: order.isXerox ? AppColors.success : AppColors.primaryBlue,
                        letterSpacing: order.isXerox ? 0 : 3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: (order.isXerox ? AppColors.success : AppColors.primaryBlue).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order.isXerox ? 'XEROX SHOP' : 'KIOSK PRINT',
              style: GoogleFonts.inter(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: order.isXerox ? AppColors.success : AppColors.primaryBlue,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
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
                  final files = List<FileModel>.from(uploadVM.pendingFiles);
                  uploadVM.clearPickedFiles();
                  _showModeSheet(existingFiles: files);
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

