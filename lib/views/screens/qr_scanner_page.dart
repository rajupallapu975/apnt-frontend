import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isScanned) return;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isScanned = true);
        // Stop camera gracefully before navigating to prevent native BufferQueue crash
        await cameraController.stop();
        if (!mounted) return;
        Navigator.pop(context, barcode.rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Scanner ──
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) => _handleDetection(capture),
          ),

          // ── Premium Overlay ──
          _buildOverlay(),

          // ── Back Button ──
          Positioned(
            top: 60,
            left: 24,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // ── Flashlight Button ──
          Positioned(
            top: 60,
            right: 24,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: ValueListenableBuilder(
                valueListenable: cameraController,
                builder: (context, state, child) {
                  final torchState = state.torchState;
                  return IconButton(
                    icon: Icon(
                      torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => cameraController.toggleTorch(),
                  );
                },
              ),
            ),
          ),

          // ── Bottom Message ──
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan QR Code',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Align the QR code within the frame to scan it automatically',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Stack(
      children: [
        // Darken outside the scanning area
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.7),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanning Frame
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
            ),
            child: Stack(
              children: [
                // Corners
                _buildCorner(0, 0, 1, 0), // Top Left
                _buildCorner(null, 0, 0, 1), // Top Right
                _buildCorner(0, null, 1, 1), // Bottom Left
                _buildCorner(null, null, 0, 0), // Bottom Right

                // Scanning Animation Bar
                const _ScanningLine(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(double? left, double? top, int rotateX, int rotateY) {
    return Positioned(
      left: left,
      top: top,
      right: left == null ? 0 : null,
      bottom: top == null ? 0 : null,
      child: Transform.scale(
        scaleX: rotateX == 1 ? 1 : -1,
        scaleY: rotateY == 1 ? 1 : -1,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primaryBlue, width: 4),
              top: BorderSide(color: AppColors.primaryBlue, width: 4),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _ScanningLine extends StatefulWidget {
  const _ScanningLine();

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: 20 + (210 * _controller.value),
          left: 20,
          right: 20,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0),
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
