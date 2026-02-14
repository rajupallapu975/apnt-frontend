import 'dart:io';
import 'package:pdfx/pdfx.dart'; // only for page count
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:apnt/services/payment_service.dart';
import 'package:apnt/views/screens/payment_processing_page.dart';
import 'package:apnt/views/screens/print_options/widgets/file_picker_sheet.dart';
import 'widgets/print_preview_carousel.dart';

class PrintOptionsPage extends StatefulWidget {
  final List<File?> files;
  final List<Uint8List?> bytes;
  final List<int> pageIndices;

  const PrintOptionsPage({
    super.key,
    required this.files,
    required this.bytes,
    required this.pageIndices,
  });

  @override
  State<PrintOptionsPage> createState() => _PrintOptionsPageState();
}

class _PrintOptionsPageState extends State<PrintOptionsPage> {
  bool isDoubleSide = false;
  bool _showPriceDetails = false;
  int _currentPageIndex = 0;

  late List<File?> files;
  late List<Uint8List?> bytes;
  late List<int> pageIndices;
  late List<PagePrintConfig> pageConfigs;

  int get pageCount => files.length;

  int get totalPrice {
    int total = 0;
    for (final p in pageConfigs) {
      final unitPrice = p.isColor ? 10 : 3;
      // ✅ For PDFs: pageCount × copies × unitPrice
      // ✅ For images: 1 × copies × unitPrice
      final pages = p.pageCount;
      final effectiveCopies =
          isDoubleSide ? (p.copies / 2).ceil() : p.copies;
      total += unitPrice * pages * effectiveCopies;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    files = List.from(widget.files);
    bytes = List.from(widget.bytes);
    pageIndices = List.from(widget.pageIndices);
    
    // ✅ Initialize configs, detect PDFs and set pageCount
    pageConfigs = List.generate(files.length, (i) {
      final file = files[i];
      if (file != null && file.path.toLowerCase().endsWith('.pdf')) {
        // Will be loaded async, default to 1 for now
        _loadPdfPageCount(i, file);
        return PagePrintConfig(pageCount: 1);
      }
      return PagePrintConfig();
    });
  }

  /// Load PDF page count asynchronously
  Future<void> _loadPdfPageCount(int index, File file) async {
    try {
      final bytes = await file.readAsBytes();
      final doc = await PdfDocument.openData(bytes);
      final count = doc.pagesCount;
      doc.close();
      
      if (mounted) {
        setState(() {
          pageConfigs[index].pageCount = count;
        });
      }
    } catch (e) {
      // If error, keep default pageCount = 1
    }
  }

  /// ---------------- ADD MORE FILES ----------------
  Future<void> _addMoreFiles() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FilePickerSheet(
        onPickedFiles: (pickedFiles) async {
          for (final f in pickedFiles) {
            if (f.path.toLowerCase().endsWith('.pdf')) {
              // ✅ PDF: Keep as ONE item, store pageCount
              final pdfBytes = await f.readAsBytes();
              final doc = await PdfDocument.openData(pdfBytes);
              final count = doc.pagesCount;
              doc.close();

              setState(() {
                files.add(f);
                bytes.add(null);
                pageIndices.add(0); // Not used for PDFs
                pageConfigs.add(PagePrintConfig(pageCount: count));
              });
            } else {
              // ✅ Image: One item per file
              setState(() {
                files.add(f);
                bytes.add(null);
                pageIndices.add(0);
                pageConfigs.add(PagePrintConfig());
              });
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Safety check for empty list or invalid index
    if (pageConfigs.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // ✅ Ensure index is valid
    if (_currentPageIndex >= pageConfigs.length) {
      _currentPageIndex = pageConfigs.length - 1;
    }
    if (_currentPageIndex < 0) {
      _currentPageIndex = 0;
    }
    
    final current = pageConfigs[_currentPageIndex];
    final paymentService = PaymentService();
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      resizeToAvoidBottomInset: true, // ✅ Prevents keyboard overflow
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          'Print options',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18 / textScale.clamp(0.8, 1.3), // ✅ Responsive font
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _addMoreFiles,
            icon: const Icon(Icons.add, color: Colors.green, size: 20),
            label: Text(
              'Add files',
              style: TextStyle(
                color: Colors.green,
                fontSize: 14 / textScale.clamp(0.8, 1.3), // ✅ Responsive font
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ✅ Detect keyboard
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final isKeyboardOpen = keyboardHeight > 0;
            
            // ✅ Adjust preview height based on keyboard
            final previewHeight = isKeyboardOpen
                ? constraints.maxHeight * 0.25 // Smaller when keyboard is open
                : constraints.maxHeight * 0.45; // Normal size

            return Column(
              children: [
                /// ---------------- PREVIEW ----------------
                if (!isKeyboardOpen) // ✅ Hide preview when keyboard is open
                  SizedBox(
                    height: previewHeight,
                    child: PrintPreviewCarousel(
                      files: files,
                      bytes: bytes,
                      isPortraitList: pageConfigs.map((e) => e.isPortrait).toList(),
                      isColorList: pageConfigs.map((e) => e.isColor).toList(),
                      isDoubleSide: isDoubleSide,
                      onPageChanged: (i) =>
                          setState(() => _currentPageIndex = i),
                      onEdit: (index) {
                        _currentPageIndex = index;
                        _editCurrentPage();
                      },
                      onRemove: (index) {
                        setState(() {
                          files.removeAt(index);
                          bytes.removeAt(index);
                          pageIndices.removeAt(index);
                          pageConfigs.removeAt(index);

                          if (pageConfigs.isEmpty) {
                            Navigator.pop(context);
                          } else if (_currentPageIndex >= pageConfigs.length) {
                            _currentPageIndex = pageConfigs.length - 1;
                          }
                        });
                      },
                    ),
                  ),

                /// ---------------- OPTIONS ----------------
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(), // ✅ Smooth iOS-style scrolling
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _section(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Page ${_currentPageIndex + 1} copies',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16 / textScale.clamp(0.8, 1.3),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  _circle(Icons.remove, () {
                                    if (current.copies > 1) {
                                      setState(() => current.copies--);
                                    }
                                  }),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      '${current.copies}',
                                      style: TextStyle(
                                        fontSize: 16 / textScale.clamp(0.8, 1.3),
                                      ),
                                    ),
                                  ),
                                  _circle(Icons.add,
                                      () => setState(() => current.copies++)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _section(
                          child: Row(
                            children: [
                              _option('Color', current.isColor,
                                  () => setState(() => current.isColor = true)),
                              const SizedBox(width: 12),
                              _option('B & W', !current.isColor,
                                  () => setState(() => current.isColor = false)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _section(
                          child: Row(
                            children: [
                              _option('Portrait', current.isPortrait,
                                  () => setState(() => current.isPortrait = true)),
                              const SizedBox(width: 12),
                              _option('Landscape', !current.isPortrait,
                                  () => setState(() => current.isPortrait = false)),
                            ],
                          ),
                        ),

                        if (pageCount > 1) ...[
                          const SizedBox(height: 12),
                          _section(
                            child: Row(
                              children: [
                                _option('One side', !isDoubleSide,
                                    () => setState(() => isDoubleSide = false)),
                                const SizedBox(width: 12),
                                _option('Both sides', isDoubleSide,
                                    () => setState(() => isDoubleSide = true)),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: isKeyboardOpen ? 20 : 80), // ✅ Less padding when keyboard is open
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      /// ---------------- BOTTOM BAR ----------------
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom, // ✅ Keyboard padding
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showPriceDetails) ...[
                ...List.generate(pageConfigs.length, (i) {
                  final p = pageConfigs[i];
                  final unitPrice = p.isColor ? 10 : 3;
                  final price = unitPrice * p.pageCount * p.copies;
                  final formula = p.pageCount > 1
                      ? 'Page ${i + 1} × ${p.pageCount} pages × ${p.copies} copies = ₹$price'
                      : 'Page ${i + 1} × ${p.copies} = ₹$price';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      formula,
                      style: TextStyle(
                        fontSize: 13 / textScale.clamp(0.8, 1.3),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }),
                const Divider(),
              ],

              GestureDetector(
                onTap: () =>
                    setState(() => _showPriceDetails = !_showPriceDetails),
                child: Row(
                  children: [
                    Text(
                      'Price details',
                      style: TextStyle(
                        fontSize: 13 / textScale.clamp(0.8, 1.3),
                        color: Colors.grey,
                      ),
                    ),
                    Icon(
                      _showPriceDetails
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹$totalPrice',
                    style: TextStyle(
                      fontSize: 20 / textScale.clamp(0.8, 1.3),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final isPaid =
                          await paymentService.performPayment(context);
                      if (!isPaid || !context.mounted) return;

                      final printSettings = {
                        "doubleSide": isDoubleSide,
                        "files": List.generate(pageConfigs.length, (i) {
                          final c = pageConfigs[i];
                          final file = files[i];
                          final isPdf = file != null && file.path.toLowerCase().endsWith('.pdf');
                          
                          return {
                            "fileIndex": i,
                            "pageNumber": pageIndices[i],
                            "pageCount": c.pageCount, // ✅ Total pages (for PDFs)
                            "isPdf": isPdf, // ✅ Backend knows if it's PDF
                            "color": c.isColor ? "COLOR" : "BW",
                            "orientation":
                                c.isPortrait ? "PORTRAIT" : "LANDSCAPE",
                            "copies": c.copies,
                          };
                        }),
                      };

                      // Calculate local values as fallback for PaymentProcessingPage
                      int localTotalPages = 0;
                      for (var pc in pageConfigs) {
                        localTotalPages += pc.pageCount * pc.copies;
                      }
                      final finalTotalPages = isDoubleSide ? (localTotalPages + 1) ~/ 2 : localTotalPages;
                      final finalTotalPrice = totalPrice.toDouble();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentProcessingPage(
                            selectedFiles: files,
                            selectedBytes: bytes,
                            printSettings: printSettings,
                            expectedPages: finalTotalPages,
                            expectedPrice: finalTotalPrice,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Payment',
                      style: TextStyle(
                        fontSize: 16 / textScale.clamp(0.8, 1.3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------- IMAGE EDIT ----------------
  Future<void> _editCurrentPage() async {
    final original = files[_currentPageIndex];
    if (original == null) return;

    // ❌ Cannot edit PDFs
    if (original.path.toLowerCase().endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit PDF files. Only images can be edited.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (kIsWeb || isDoubleSide) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Disable double side to edit pages')),
      );
      return;
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: original.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Page',
          toolbarColor: Colors.green,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(title: 'Edit Page'),
      ],
    );

    if (cropped == null) return;

    setState(() {
      files[_currentPageIndex] = File(cropped.path);
      bytes[_currentPageIndex] = null;
    });
  }

  /// ---------------- UI HELPERS ----------------
  Widget _section({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _circle(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.green,
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      );

  Widget _option(String label, bool selected, VoidCallback onTap) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? Colors.green : Colors.black12),
            color: selected
                ? Colors.green.withOpacity(0.15)
                : Colors.white,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14 / textScale.clamp(0.8, 1.3),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// ---------------- PAGE CONFIG ----------------
class PagePrintConfig {
  bool isPortrait;
  bool isColor;
  int copies;
  int pageCount; // ✅ For PDFs: actual page count, for images: 1

  PagePrintConfig({
    this.isPortrait = true,
    this.isColor = true,
    this.copies = 1,
    this.pageCount = 1, // Default: 1 page (for images)
  });
}
