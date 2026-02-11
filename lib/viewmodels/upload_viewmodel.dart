import 'package:flutter/material.dart';
import '../models/file_model.dart';

class UploadViewModel extends ChangeNotifier {
  final List<FileModel> _files = [];

  List<FileModel> get files => _files;

  bool get hasFiles => _files.isNotEmpty;

  void addFiles(List<FileModel> newFiles) {
    _files.addAll(newFiles);
    notifyListeners();
  }

  void removeFile(String id) {
    _files.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  void clearAll() {
    _files.clear();
    notifyListeners();
  }
}
