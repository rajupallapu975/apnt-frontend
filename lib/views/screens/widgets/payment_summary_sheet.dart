import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../utils/app_colors.dart';

class PaymentSummarySheet extends StatefulWidget {
  final int totalPages;
  final double totalPrice;
  final Map<String, dynamic> printSettings;
  final Function(String? phoneNumber)? onProceed;
  final Future<Map<String, dynamic>>? razorpayFuture;
  final Future<List<Uint8List?>>? processingFuture;

  const PaymentSummarySheet({
    super.key,
    required this.totalPages,
    required this.totalPrice,
    required this.printSettings,
    required this.onProceed,
    this.razorpayFuture,
    this.processingFuture,
  });

  @override
  State<PaymentSummarySheet> createState() => _PaymentSummarySheetState();
}

class _PaymentSummarySheetState extends State<PaymentSummarySheet> {
  final TextEditingController _phoneController = TextEditingController();

  final bool _isInit = true;
  bool _needsPhone = false;
  bool _isProcessing = false;
  bool _isWaitingForRequest = true;

  double get _shopSubtotal {
    final settings = widget.printSettings;
    return (settings['shopSubtotal'] as num? ?? settings['subtotal'] as num? ?? widget.totalPrice).toDouble();
  }

  double get _platformFee {
    final settings = widget.printSettings;
    return (settings['commission'] as num? ?? settings['commissionAmount'] as num? ?? 0.0).toDouble();
  }

  double get _amountSaved {
    final settings = widget.printSettings;
    return (settings['amountSaved'] as num? ?? 0.0).toDouble();
  }

  double get _originalShopSubtotal {
    final settings = widget.printSettings;
    return (settings['originalShopSubtotal'] as num? ?? _shopSubtotal).toDouble();
  }

  double get _originalFinalAmount {
    final settings = widget.printSettings;
    return (settings['originalFinalAmount'] as num? ?? widget.totalPrice).toDouble();
  }

  bool get _isBulkApplied {
    final settings = widget.printSettings;
    return settings['isBulkApplied'] == true;
  }

  bool get _generateCoverPage {
    final settings = widget.printSettings;
    return settings['generateCoverPage'] == true;
  }

  double get _coverPageCharge {
    final settings = widget.printSettings;
    return (settings['coverPageCharge'] as num? ?? 0.0).toDouble();
  }


  @override
  void initState() {
    super.initState();
    final authVM = context.read<AuthViewModel>();
    _needsPhone = authVM.phoneNumber == null || authVM.phoneNumber!.isEmpty;

    _waitForPreparations();
  }

  Future<void> _waitForPreparations() async {
    try {
      // 📡 WAIT FOR ALL BACKGROUND TASKS
      await Future.wait([
        widget.razorpayFuture ?? Future.value({}),
        widget.processingFuture ?? Future.value([]),
      ]);
      
      if (mounted) {
        setState(() {
          _isWaitingForRequest = false; // 💳 SWITCH TO SUMMARY PAGE
        });
      }
    } catch (e) {
      debugPrint("❌ Preparation Error: $e");
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare print request: $e'))
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const SizedBox(height: 100);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
      child: AnimatedSwitcher(
        duration: 150.ms,
        child: _isWaitingForRequest ? _buildWaitingUI() : _buildSummaryUI(),
      ),
    );
  }

  Widget _buildSummaryUI() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ➖ Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 💳 Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, 
                    color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Summary',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                  Text(
                    'Review and confirm details',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn().slideX(begin: -0.1, end: 0),

          const SizedBox(height: 24),

          // 📄 Pricing Details
          // 📄 Pricing Details
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                if (widget.printSettings['shopName'] != null) ...[
                  _buildSimpleRow('Destination', widget.printSettings['shopName']),
                  const SizedBox(height: 12),
                ],
                if (widget.printSettings['paperSize'] != null) ...[
                  _buildSimpleRow('Paper Size', widget.printSettings['paperSize'].toString().toUpperCase()),
                  const SizedBox(height: 12),
                ],
                () {
                  final isProjectBinding = widget.printSettings['serviceType'] == 'project_binding';
                  if (isProjectBinding) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSimpleRow(
                          'Printing Cost',
                          '₹${(widget.printSettings['printingCost'] as num? ?? 0.0).toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        _buildSimpleRow(
                          'Binding Cost (${widget.printSettings['bindingType'].toString().toUpperCase()})',
                          '₹${(widget.printSettings['bindingCost'] as num? ?? 0.0).toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        _buildSimpleRow(
                          'Platform Fee',
                          '₹${(widget.printSettings['platformCommission'] as num? ?? 0.0).toStringAsFixed(2)}',
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSimpleRow('Layout Side', widget.printSettings['doubleSide'] == true ? 'Double Sided' : 'Single Sided'),
                      const SizedBox(height: 12),
                      _buildSimpleRow(
                        'Pages Breakdown',
                        'B&W: ${widget.printSettings['totalBwPagesWithCopies'] ?? 0} | Color: ${widget.printSettings['totalColorPagesWithCopies'] ?? 0}',
                      ),
                      const SizedBox(height: 12),

                      // 1. Printing Cost (Original) - strikethrough if bulk applied
                      if (_isBulkApplied) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Printing Cost',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '₹${_originalShopSubtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 2. Bulk Discount
                        _buildSimpleRow(
                          'Bulk Discount',
                          '-₹${_amountSaved.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 3. Printing Cost (Final)
                      _buildSimpleRow(
                        'Printing Cost',
                        '₹${_shopSubtotal.toStringAsFixed(2)}',
                      ),

                      // 3b. Cover Page Charge
                      if (_generateCoverPage) ...[
                        const SizedBox(height: 12),
                        _buildSimpleRow(
                          'Cover Page Charge',
                          '₹${_coverPageCharge.toStringAsFixed(2)}',
                        ),
                      ],

                      // 4. Platform Fee
                      if (_platformFee > 0) ...[
                        const SizedBox(height: 12),
                        _buildSimpleRow(
                          'Platform Fee',
                          '₹${_platformFee.toStringAsFixed(2)}',
                        ),
                      ],
                    ],
                  );
                }(),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),

                // 5. Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlack,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_isBulkApplied)
                          Text(
                            '₹${_originalFinalAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          '₹${widget.totalPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

          if (_needsPhone) ...[
            const SizedBox(height: 24),
            Text(
              'CONTACT NUMBER (REQUIRED)',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.textTertiary,
                letterSpacing: 1,
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 12),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.primaryBlue),
                  hintText: 'Enter 10 digit number',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          ],

          const SizedBox(height: 32),

          // 🚀 Action Button (Pay ₹X)
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () async {
                if (_needsPhone && _phoneController.text.length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 10-digit number'))
                  );
                  return;
                }
                
                if (_needsPhone) {
                  setState(() => _isProcessing = true);
                  try {
                    await context.read<AuthViewModel>().updatePhoneNumber(_phoneController.text);
                  } catch (e) {
                    debugPrint("⚠️ Phone update skipped/failed: $e");
                  }
                }
                
                // 💳 PROCEED TO PAYMENT
                widget.onProceed?.call(_needsPhone ? _phoneController.text : null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                shadowColor: AppColors.primaryBlack.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.print_rounded, size: 22),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Confirm Order',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          
          const SizedBox(height: 20),
          
          // 🛡️ Security Badges
          Column(
            children: [
              _securityRow(Icons.lock_rounded, 'Secure payment'),
              const SizedBox(height: 8),
              _securityRow(Icons.bolt_rounded, 'Instant processing'),
              const SizedBox(height: 8),
              _securityRow(Icons.confirmation_num_rounded, 'Pickup code will be generated after payment'),
            ],
          ).animate().fadeIn(delay: 500.ms),
        ],
    );
  }


  Widget _buildWaitingUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🖨️ PRINTING ANIMATION
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 📄 Flying Papers (Background Layer)
                ...List.generate(3, (index) {
                  return Positioned(
                    top: 60,
                    child: Container(
                      width: 50,
                      height: 65,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 30, height: 3, color: AppColors.border),
                            const SizedBox(height: 4),
                            Container(width: 20, height: 3, color: AppColors.border),
                            const SizedBox(height: 4),
                            Container(width: 35, height: 3, color: AppColors.border),
                          ],
                        ),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .moveY(begin: 0, end: 120, duration: 2.seconds, delay: (index * 600).ms, curve: Curves.easeInOut)
                    .fadeIn(duration: 400.ms, delay: (index * 600).ms)
                    .fadeOut(begin: 1, duration: 400.ms, delay: (index * 600 + 1600).ms),
                  );
                }),

                // 🖨️ Printer (Foreground Layer)
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.print_rounded,
                      size: 54,
                      color: AppColors.primaryBlue,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.3))
                  .shake(hz: 2, curve: Curves.easeInOut, rotation: 0.02),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            "PREPARING YOUR PRINT REQUEST...",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryBlack,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 24),
          
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ).animate().fadeIn(),
        ],
      ),
    );
  }

  Widget _buildSimpleRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // _buildSimpleRowWithStrikethrough removed (superseded by _buildRow in the new pricing layout)

  Widget _securityRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.success),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}