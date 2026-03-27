import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../utils/app_colors.dart';

class PrintPreviewCarousel extends StatelessWidget {
  final PageController controller;
  final List<String> fileNames;
  final List<File?> files;
  final List<Uint8List?> bytes;
  final List<bool> isPortraitList;
  final List<bool> isColorList;
  final Function(int) onEdit;
  final Function(int) onRemove;
  final Function(int) onPageChanged;

  const PrintPreviewCarousel({
    super.key,
    required this.controller,
    required this.fileNames,
    required this.files,
    required this.bytes,
    required this.isPortraitList,
    required this.isColorList,
    required this.onEdit,
    required this.onRemove,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: fileNames.length,
          onPageChanged: onPageChanged,
          itemBuilder: (_, index) {
            final name = fileNames[index];
            final portrait = isPortraitList[index];
            final color = isColorList[index];
            final a4Ratio = portrait ? 210 / 297 : 297 / 210;
            
            final file = files[index];
            final byteData = bytes[index];
            
            Widget previewWidget;

            final isPdf = name.toLowerCase().endsWith('.pdf');
            final isWord = name.toLowerCase().endsWith('.doc') || name.toLowerCase().endsWith('.docx');

            if (isPdf) {
              // PDF PREVIEW (Show thumbnail if available in byteData)
              if (byteData != null) {
                previewWidget = Image.memory(byteData, fit: BoxFit.contain, filterQuality: FilterQuality.high);
              } else {
                previewWidget = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 64,
                      color: color ? AppColors.primaryBlue : AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color ? AppColors.textPrimary : AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }
            } else if (isWord) {
              // DOCX PREVIEW (Placeholder icon)
              previewWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_rounded,
                    size: 64,
                    color: color ? AppColors.primaryBlue : AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            } else {
              // IMAGE PREVIEW
              if (kIsWeb) {
                previewWidget = byteData != null 
                  ? Image.memory(byteData, fit: BoxFit.contain, filterQuality: FilterQuality.high) 
                  : const Center(child: CircularProgressIndicator());
              } else {
                previewWidget = file != null 
                  ? Image.file(file, fit: BoxFit.contain, filterQuality: FilterQuality.high) 
                  : const Center(child: CircularProgressIndicator());
              }
            }

            // B&W filter (Apply to images and PDF thumbnails)
            if (!color && !isWord && (isPdf ? byteData != null : true)) {
              previewWidget = ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: previewWidget,
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              child: Center(
                child: AspectRatio(
                  aspectRatio: a4Ratio,
                  child: Stack(
                    children: [
                      // 📄 A4 PAPER (Invariant Background)
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4), 
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08), 
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: previewWidget,
                        ),

                      // 🟣 ACTION OVERLAY (Edit for Images, Open for Docs)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => onEdit(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (isPdf || isWord) ? Icons.visibility_rounded : Icons.tune_rounded, 
                                      color: AppColors.primaryBlue, 
                                      size: 18
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      (isPdf || isWord) ? 'Open' : 'Edit',
                                      style: GoogleFonts.inter(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        /// NAVIGATION BUTTONS
        if (fileNames.length > 1) ...[
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _navButton(Icons.chevron_left_rounded, () {
                controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
              }),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _navButton(Icons.chevron_right_rounded, () {
                controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: AppColors.softShadow,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primaryBlue),
        onPressed: onTap,
      ),
    );
  }

}
