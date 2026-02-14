import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class PrintPreviewCarousel extends StatelessWidget {
  final List<File?> files;
  final List<Uint8List?> bytes;
  final List<bool> isPortraitList;
  final List<bool> isColorList;
  final bool isDoubleSide;
  final Function(int) onEdit;
  final Function(int) onRemove;
  final Function(int) onPageChanged;

  const PrintPreviewCarousel({
    super.key,
    required this.files,
    required this.bytes,
    required this.isPortraitList,
    required this.isColorList,
    required this.isDoubleSide,
    required this.onEdit,
    required this.onRemove,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: files.length,
      onPageChanged: onPageChanged,
      itemBuilder: (_, index) {
        final portrait = isPortraitList[index];
        final color = isColorList[index];
        final a4Ratio = portrait ? 210 / 297 : 297 / 210;
        final file = files[index];
        Widget image;

        if (file != null && file.path.toLowerCase().endsWith('.pdf')) {
          // ✅ Simple PDF preview: icon + filename + page count
          final filename = path.basename(file.path);
          image = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf,
                size: 80,
                color: color ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                filename,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color ? Colors.black87 : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        } else {
          // ✅ Image files: show actual image
          image = kIsWeb
              ? Image.memory(bytes[index]!, fit: BoxFit.contain)
              : Image.file(file!, fit: BoxFit.contain);
          
          // 🎨 B&W filter for images only
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              /// 🟢 LEFT ACTION ZONE (EDIT)
              SizedBox(
                width: 44,
                child: !isDoubleSide && file != null && !file.path.toLowerCase().endsWith('.pdf')
                    ? IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => onEdit(index),
                      )
                    : const SizedBox(),
              ),

              /// 📄 A4 PAPER (PURE – NO BUTTONS)
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: a4Ratio,
                    child: Container(
                      padding: const EdgeInsets.all(14),
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
    );
  }
}
