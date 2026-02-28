import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/file_model.dart';
import '../utils/file_validator.dart';

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

      final fileModel = FileModel(
        id: DateTime.now().toString(),
        name: image.name,
        path: image.path,
        file: kIsWeb ? null : File(image.path),
        bytes: bytes,
        addedAt: DateTime.now(),
        size: size,
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
      
      _addFileIfValid(FileModel(
        id: DateTime.now().toString() + img.name,
        name: img.name,
        path: img.path,
        file: kIsWeb ? null : File(img.path),
        bytes: bytes,
        addedAt: DateTime.now(),
        size: size, // Pass the captured size
      ));
    }
  }

  Future<void> pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result == null) return;

    for (final f in result.files) {
      _addFileIfValid(FileModel(
        id: DateTime.now().toString() + f.name,
        name: f.name,
        path: f.path ?? '',
        file: f.path == null ? null : File(f.path!),
        bytes: f.bytes,
        addedAt: DateTime.now(),
        size: f.size,
      ));
    }
  }

  void _addFileIfValid(FileModel file) {
    if (FileValidator.isValidFile(file.name)) {
      _files.add(file);
      _error = null;
    } else {
      _error = "Unsupported file format: ${file.name}";
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
