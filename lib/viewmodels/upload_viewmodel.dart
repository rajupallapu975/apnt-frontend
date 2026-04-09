import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../models/file_model.dart';
import '../utils/file_validator.dart';
import 'package:pdfx/pdfx.dart';
// archive import removed

class UploadViewModel extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  
  final List<FileModel> _files = [];
  bool _isLoading = false;
  String? _error;

  List<FileModel> get files => _files;
  List<FileModel> get pendingFiles => _files;
  bool get hasFiles => _files.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> pickFromCamera() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      
      Uint8List? bytes;
      int size = 0;
      if (kIsWeb) {
        bytes = await image.readAsBytes();
        size = bytes.length;
      } else {
        size = await File(image.path).length();
      }

      final String webPath = kIsWeb && bytes != null 
          ? "data:image/png;base64,${base64Encode(bytes)}" 
          : image.path;

      final fileModel = FileModel(
        id: DateTime.now().toString(),
        name: image.name,
        path: webPath,
        file: kIsWeb ? null : File(image.path),
        bytes: bytes,
        addedAt: DateTime.now(),
        size: size,
        pageCount: 1,
      );
      
      _addFileIfValid(fileModel);
    } catch (e) {
      _error = "Camera access failed.";
      notifyListeners();
    }
  }

  Future<void> pickFromGallery() async {
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    for (final img in images) {
      Uint8List? bytes;
      int size = 0;
      if (kIsWeb) {
        bytes = await img.readAsBytes();
        size = bytes.length;
      } else {
        size = await File(img.path).length();
      }
      
      final String webPath = kIsWeb && bytes != null 
          ? "data:image/png;base64,${base64Encode(bytes)}" 
          : img.path;
      
      _addFileIfValid(FileModel(
        id: DateTime.now().toString() + img.name,
        name: img.name,
        path: webPath,
        file: kIsWeb ? null : File(img.path),
        bytes: bytes,
        addedAt: DateTime.now(),
        size: size,
        pageCount: 1,
      ));
    }
  }

  Future<void> pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result == null) return;

    for (final f in result.files) {
      final String webPath = kIsWeb && f.bytes != null 
          ? "data:image/png;base64,${base64Encode(f.bytes!)}" 
          : (f.path ?? '');

      int? pageCount;
      if (f.name.toLowerCase().endsWith('.pdf')) {
        pageCount = await _getPdfPageCount(f.path, f.bytes);
      }

      _addFileIfValid(FileModel(
        id: DateTime.now().toString() + f.name,
        name: f.name,
        path: webPath,
        file: f.path == null ? null : File(f.path!),
        bytes: f.bytes,
        addedAt: DateTime.now(),
        size: f.size,
        pageCount: pageCount,
      ));
    }
  }

  Future<int?> _getPdfPageCount(String? path, Uint8List? bytes) async {
    try {
      PdfDocument? doc;
      if (kIsWeb && bytes != null) {
        doc = await PdfDocument.openData(bytes);
      } else if (path != null) {
        doc = await PdfDocument.openFile(path);
      }
      int? count = doc?.pagesCount;
      await doc?.close();
      return count;
    } catch (e) {
      debugPrint("Error counting PDF pages: $e");
      return 1; // Fallback
    }
  }

  void _addFileIfValid(FileModel file) {
    if (!FileValidator.isValidFile(file.name)) {
      _error = "Unsupported format: ${file.name}";
    } else if (!FileValidator.isValidSize(file.size)) {
      _error = "The file must be below 10 MB";
      debugPrint("❌ File size limit exceeded: ${file.size} bytes");
    } else {
      _files.add(file);
      _error = null;
    }
    notifyListeners();
  }

  void removeFile(String id) {
    _files.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  /// Called after successfully navigating to PrintOptionsPage
  void clearPickedFiles() {
    _files.clear();
    _error = null;
    notifyListeners();
  }

  void clearAll() {
    _files.clear();
    _error = null;
    notifyListeners();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
