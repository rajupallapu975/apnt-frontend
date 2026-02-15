import 'dart:io';
import 'package:pdfx/pdfx.dart'; // only for page count
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:apnt/services/payment_service.dart';
import 'package:apnt/views/screens/payment_processing_page.dart';
import 'package:apnt/views/screens/print_options/widgets/file_picker_sheet.dart';
import 'package:apnt/models/file_model.dart';
import 'widgets/print_preview_carousel.dart';

class PrintOptionsPage extends StatefulWidget {
  final List<FileModel> pickedFiles;

  const PrintOptionsPage({
    super.key,
    required this.pickedFiles,
  });

  @override
  State<PrintOptionsPage> createState() => _PrintOptionsPageState();
}

class _PrintOptionsPageState extends State<PrintOptionsPage> {
  bool _showPriceDetails = false;
  int _currentPageIndex = 0;
  final PageController _pageController = PageController();

  late List<FileModel> pickedFiles;
  late List<PagePrintConfig> pageConfigs;

  int get pageCount => pickedFiles.length;

  int get totalPrice {
    int total = 0;
    for (final p in pageConfigs) {
      final unitPrice = p.isColor ? 10 : 3;
      final pages = p.pageCount;
      total += unitPrice * pages * p.copies;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    pickedFiles = List.from(widget.pickedFiles);
    
    // Initialize configs
    pageConfigs = List.generate(pickedFiles.length, (i) {
      final fileModel = pickedFiles[i];
      final isPdf = fileModel.name.toLowerCase().endsWith('.pdf');
      
      if (isPdf) {
        _loadPdfPageCount(i, fileModel);
        return PagePrintConfig(pageCount: 1); // Default to 1, will update async
      }
      return PagePrintConfig(); // Normal image = 1 page
    });
  }

  /// Load PDF page count asynchronously using bytes (works for both web & mobile)
  Future<void> _loadPdfPageCount(int index, FileModel model) async {
    try {
      Uint8List? data = model.bytes;
      if (data == null && !kIsWeb && model.file != null) {
        data = await model.file!.readAsBytes();
      }
      
      if (data != null) {
        final doc = await PdfDocument.openData(data);
        final count = doc.pagesCount;
        doc.close();
        
        if (mounted) {
          setState(() {
            pageConfigs[index].pageCount = count;
          });
        }
      }
    } catch (e) {
      debugPrint("PDF Load Error: $e");
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
        onPickedFiles: (newPicked) async {
          for (final f in newPicked) {
            final isPdf = f.name.toLowerCase().endsWith('.pdf');
            int count = 1;
            
            if (isPdf) {
              try {
                final data = f.bytes ?? (f.file != null ? await f.file!.readAsBytes() : null);
                if (data != null) {
                  final doc = await PdfDocument.openData(data);
                  count = doc.pagesCount;
                  doc.close();
                }
              } catch (e) {
                debugPrint("PDF Load Error: $e");
              }
            }

            setState(() {
              pickedFiles.add(f);
              pageConfigs.add(PagePrintConfig(pageCount: count));
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pageConfigs.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_currentPageIndex >= pageConfigs.length) {
      _currentPageIndex = pageConfigs.length - 1;
    }
    if (_currentPageIndex < 0) {
      _currentPageIndex = 0;
    }
    
    final current = pageConfigs[_currentPageIndex];
    final paymentService = PaymentService();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Print options', style: TextStyle(color: Colors.black, fontSize: 18)),
        actions: [
          TextButton.icon(
            onPressed: _addMoreFiles,
            icon: const Icon(Icons.add, color: Colors.green, size: 20),
            label: const Text('Add files', style: TextStyle(color: Colors.green, fontSize: 14)),
          ),
        ],
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final isKeyboardOpen = keyboardHeight > 0;
            final previewHeight = isKeyboardOpen ? constraints.maxHeight * 0.25 : constraints.maxHeight * 0.45;

            return Column(
              children: [
                /// ---------------- PREVIEW ----------------
                if (!isKeyboardOpen)
                  SizedBox(
                    height: previewHeight,
                    child: PrintPreviewCarousel(
                      controller: _pageController,
                      fileNames: pickedFiles.map((e) => e.name).toList(),
                      files: pickedFiles.map((e) => e.file).toList(),
                      bytes: pickedFiles.map((e) => e.bytes).toList(),
                      isPortraitList: pageConfigs.map((e) => e.isPortrait).toList(),
                      isColorList: pageConfigs.map((e) => e.isColor).toList(),
                      onPageChanged: (i) => setState(() => _currentPageIndex = i),
                      onEdit: (index) {
                        _currentPageIndex = index;
                        _editCurrentPage();
                      },
                      onRemove: (index) {
                        setState(() {
                          pickedFiles.removeAt(index);
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
                    physics: const BouncingScrollPhysics(),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  _circle(Icons.remove, () {
                                    if (current.copies > 1) setState(() => current.copies--);
                                  }),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('${current.copies}', style: const TextStyle(fontSize: 16)),
                                  ),
                                  _circle(Icons.add, () => setState(() => current.copies++)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _section(
                          child: Row(
                            children: [
                              _option('Color', current.isColor, () => setState(() => current.isColor = true)),
                              const SizedBox(width: 12),
                              _option('B & W', !current.isColor, () => setState(() => current.isColor = false)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _section(
                          child: Row(
                            children: [
                              _option('Portrait', current.isPortrait, () => setState(() => current.isPortrait = true)),
                              const SizedBox(width: 12),
                              _option('Landscape', !current.isPortrait, () => setState(() => current.isPortrait = false)),
                            ],
                          ),
                        ),

                        
                        SizedBox(height: isKeyboardOpen ? 20 : 80),
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
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
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
                      ? 'Item ${i + 1} (${p.pageCount} pages) × ${p.copies} copies = ₹$price'
                      : 'Item ${i + 1} × ${p.copies} = ₹$price';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(formula, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  );
                }),
                const Divider(),
              ],

              GestureDetector(
                onTap: () => setState(() => _showPriceDetails = !_showPriceDetails),
                child: Row(
                  children: [
                    const Text('Price details', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Icon(_showPriceDetails ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 18, color: Colors.grey),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₹$totalPrice', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final isPaid = await paymentService.performPayment(context);
                      if (!isPaid || !context.mounted) return;

                      final printSettings = {
                        "doubleSide": false,
                        "files": List.generate(pageConfigs.length, (i) {
                          final c = pageConfigs[i];
                          final model = pickedFiles[i];
                          return {
                            "fileName": model.name,
                            "pageCount": c.pageCount,
                            "color": c.isColor ? "COLOR" : "BW",
                            "orientation": c.isPortrait ? "PORTRAIT" : "LANDSCAPE",
                            "copies": c.copies,
                          };
                        }),
                      };

                      int localTotalPages = 0;
                      for (var pc in pageConfigs) localTotalPages += pc.pageCount * pc.copies;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentProcessingPage(
                            selectedFiles: pickedFiles.map((e) => e.file).toList(),
                            selectedBytes: pickedFiles.map((e) => e.bytes).toList(),
                            printSettings: printSettings,
                            expectedPages: localTotalPages,
                            expectedPrice: totalPrice.toDouble(),
                          ),
                        ),
                      );
                    },
                    child: const Text('Payment', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editCurrentPage() async {
    final model = pickedFiles[_currentPageIndex];
    if (model.name.toLowerCase().endsWith('.pdf')) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit PDF files.')));
       return;
    }


    final String sourcePath = kIsWeb ? model.path : (model.file?.path ?? model.path);
    
    if (sourcePath.isEmpty && kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit this image source on web.')));
      return;
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      // image_cropper works on web if configured properly in index.html, 
      // but let's assume it works for now or the user handles it.
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Edit', toolbarColor: Colors.green, toolbarWidgetColor: Colors.white),
        IOSUiSettings(title: 'Edit'),
        WebUiSettings(context: context),
      ],
    );

    if (cropped == null) return;

    final bytes = await cropped.readAsBytes();
    setState(() {
      pickedFiles[_currentPageIndex] = FileModel(
        id: model.id,
        name: model.name,
        path: kIsWeb ? '' : cropped.path,
        file: kIsWeb ? null : File(cropped.path),
        bytes: bytes,
        addedAt: model.addedAt,
      );
    });
  }

  Widget _section({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  Widget _circle(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: CircleAvatar(radius: 14, backgroundColor: Colors.green, child: Icon(icon, size: 16, color: Colors.white)),
      );

  Widget _option(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Colors.green : Colors.black12),
            color: selected ? Colors.green.withOpacity(0.15) : Colors.white,
          ),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}

class PagePrintConfig {
  bool isPortrait;
  bool isColor;
  int copies;
  int pageCount;

  PagePrintConfig({
    this.isPortrait = true,
    this.isColor = true,
    this.copies = 1,
    this.pageCount = 1,
  });
}
