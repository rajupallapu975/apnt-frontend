import 'dart:async';
import 'dart:convert';
// dart:io not needed at top level
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../config/cloudinary_config.dart';
import '../models/file_model.dart';
import '../utils/file_validator.dart';

class UploadProgress {
  final double progress; // 0.0 to 1.0
  final String? url;
  final String? error;

  UploadProgress({required this.progress, this.url, this.error});
}

class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytes, int totalBytes) onProgress;

  MultipartRequestWithProgress(
    super.method,
    super.url, {
    required this.onProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    int bytesUploaded = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesUploaded += data.length;
        onProgress(bytesUploaded, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}

class UploadService {
  /// Validates a single file before upload
  String? validateFile(FileModel file) {
    // 1. Max size validation (10MB)
    if (!FileValidator.isValidSize(file.size)) {
      return 'File exceeds maximum size of 10 MB.';
    }

    // 2. Extension validation
    final ext = path.extension(file.name).toLowerCase();
    final allowed = ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.bmp', '.tiff'];
    if (!allowed.contains(ext)) {
      return 'Unsupported file format. Please upload PDF, Word, or Image files.';
    }

    return null;
  }

  /// Uploads a single file to Cloudinary with live progress reporting via a Stream
  Stream<UploadProgress> uploadFile(FileModel fileModel, String pickupCode) {
    final controller = StreamController<UploadProgress>();
    
    // Perform asynchronous upload task
    () async {
      try {
        final ext = path.extension(fileModel.name).toLowerCase();
        final isPdf = ext == '.pdf';
        final isDoc = ext == '.doc' || ext == '.docx';
        final resourceType = isPdf ? 'image' : (isDoc ? 'raw' : 'auto');

        final cloudName = CloudinaryConfig.cloudNameB;
        final uploadPreset = CloudinaryConfig.uploadPresetB;
        final folderPath = 'xerox_orders';
        final basePublicId = '${pickupCode}_${DateTime.now().millisecondsSinceEpoch}';
        final fullPublicId = '$folderPath/$pickupCode/$basePublicId';

        final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');
        
        final request = MultipartRequestWithProgress(
          'POST',
          uri,
          onProgress: (bytes, total) {
            final progress = total > 0 ? (bytes / total) : 0.0;
            // Cap at 0.99 until response succeeds
            controller.add(UploadProgress(progress: progress >= 1.0 ? 0.99 : progress));
          },
        );

        request.fields['upload_preset'] = uploadPreset;
        request.fields['public_id'] = fullPublicId;

        final mimeType = isPdf 
            ? MediaType('application', 'pdf')
            : (isDoc ? MediaType('application', 'octet-stream') : MediaType('image', ext.replaceAll('.', '')));

        if (kIsWeb && fileModel.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            fileModel.bytes!,
            filename: fileModel.name,
            contentType: mimeType,
          ));
        } else if (fileModel.path.isNotEmpty) {
          request.files.add(await http.MultipartFile.fromPath(
            'file',
            fileModel.path,
            contentType: mimeType,
          ));
        } else if (fileModel.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            fileModel.bytes!,
            filename: fileModel.name,
            contentType: mimeType,
          ));
        } else {
          throw Exception('No file data available to upload.');
        }

        final response = await request.send();
        final responseString = await response.stream.bytesToString();
        
        if (response.statusCode == 200) {
          final data = jsonDecode(responseString);
          final String url = data['secure_url'] ?? '';
          controller.add(UploadProgress(progress: 1.0, url: url));
          controller.close();
        } else {
          controller.add(UploadProgress(progress: 0.0, error: 'Server error ${response.statusCode}: $responseString'));
          controller.close();
        }
      } catch (e) {
        controller.add(UploadProgress(progress: 0.0, error: e.toString()));
        controller.close();
      }
    }();

    return controller.stream;
  }
}
