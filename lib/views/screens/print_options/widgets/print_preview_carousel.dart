import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
            
            Widget image;

            if (name.toLowerCase().endsWith('.pdf')) {
              image = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 80,
                    color: color ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color ? Colors.black87 : Colors.grey,
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
                image = byteData != null 
                  ? Image.memory(byteData, fit: BoxFit.contain) 
                  : const Center(child: CircularProgressIndicator());
              } else {
                image = file != null 
                  ? Image.file(file, fit: BoxFit.contain) 
                  : const Center(child: CircularProgressIndicator());
              }
              
              // B&W filter
              if (!color) {
                image = ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: image,
                );
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: Row(
                children: [
                  /// 🟢 LEFT ACTION ZONE (EDIT)
                  SizedBox(
                    width: 44,
                    child: !name.toLowerCase().endsWith('.pdf')
                        ? IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => onEdit(index),
                          )
                        : const SizedBox(),
                  ),

                  /// 📄 A4 PAPER
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: a4Ratio,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: image,
                        ),
                      ),
                    ),
                  ),

                  /// 🔴 RIGHT ACTION ZONE (REMOVE)
                  SizedBox(
                    width: 44,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => onRemove(index),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        /// NAVIGATION BUTTONS (WEB/LAPTOP)
        if (fileNames.length > 1) ...[
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.8),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.green),
                  onPressed: () {
                    controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.8),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.green),
                  onPressed: () {
                    controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
