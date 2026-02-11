import 'dart:io';
import 'package:flutter/foundation.dart';

class FileModel {
  final String id;
  final String name;
  final String path;
  final File? file;        // mobile
  final Uint8List? bytes;  // web
  final DateTime addedAt;
  final int? pageCount;    // for PDFs only

  FileModel({
    required this.id,
    required this.name,
    required this.path,
    this.file,
    this.bytes,
    required this.addedAt,
    this.pageCount,
  });
}
