import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../config/cloudinary_config.dart';
import '../utils/file_validator.dart';

class CloudinaryStorageService {
  /// Single endpoint for all file types
  String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/auto/upload';

  /// Detect correct MediaType
  MediaType _getMediaType(String filename) {
    final ext = path.extension(filename).toLowerCase();

    switch (ext) {
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.png':
        return MediaType('image', 'png');
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.bmp':
        return MediaType('image', 'bmp');
      case '.tiff':
      case '.tif':
        return MediaType('image', 'tiff');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  Future<List<String>> uploadFiles({
    required String pickupCode,
    required List<File?> files,
    required List<Uint8List?> bytes,
  }) async {
    final List<String> uploadedUrls = [];
    final Map<String, String> uploadedHashes = {};

    // Validate extensions before starting uploads
    for (int i = 0; i < files.length; i++) {
        final originalName = files[i] != null 
            ? path.basename(files[i]!.path) 
            : 'file_${i + 1}'; // Fallback for bytes only
        
        if (!FileValidator.isValidFile(originalName) && !originalName.startsWith('file_')) {
             throw Exception('Format ${path.extension(originalName)} not accepted. Only PDF, JPG, JPEG, PNG, BMP, TIFF are allowed.');
        }
    }

    try {
      print('🚀 Cloudinary upload started');
      print('🔑 Pickup Code: $pickupCode');
      print('🌐 Upload URL: $_uploadUrl');
      print('📝 Upload Preset: ${CloudinaryConfig.uploadPreset}');

      for (int i = 0; i < files.length; i++) {
        final File? file = files[i];
        Uint8List? fileBytes = bytes[i];

        if (file == null && fileBytes == null) continue;

        // Get file bytes if not provided
        if (fileBytes == null && file != null) {
          fileBytes = await file.readAsBytes();
        }

        if (fileBytes == null) continue;

        // 🔥 FIX: Create a fresh copy of bytes to avoid "detached ArrayBuffer" issue on web
        // This happens because the original buffer might be detached after first use or during async ops.
        final Uint8List bytesToUse = Uint8List.fromList(fileBytes);

        // 🔥 Generate MD5 hash for duplicate detection
        final String hash =
            md5.convert(bytesToUse).toString();

        // 🔁 Skip upload if duplicate file detected
        if (uploadedHashes.containsKey(hash)) {
          print('♻️ Duplicate file detected, skipping upload');
          uploadedUrls.add(uploadedHashes[hash]!);
          continue;
        }

        // Extract extension
        final originalName =
            file != null ? path.basename(file.path) : 'file_${i + 1}';

        final extension = path.extension(originalName);

        // 🔥 Filename = pickupCode_index.extension
        final String filename =
            '${pickupCode}_${i + 1}$extension';

        final request = http.MultipartRequest(
          'POST',
          Uri.parse(_uploadUrl),
        );

        // Required for unsigned upload
        request.fields['upload_preset'] =
            CloudinaryConfig.uploadPreset;

        // Folder inside Cloudinary
        request.fields['folder'] =
            'orders/$pickupCode';

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytesToUse,
            filename: filename,
            contentType: _getMediaType(filename),
          ),
        );

        print('📤 Uploading: $filename');

        final streamedResponse =
            await request.send();

        final response =
            await http.Response.fromStream(
                streamedResponse);

        if (response.statusCode == 200 ||
            response.statusCode == 201) {
          final Map<String, dynamic> data =
              jsonDecode(response.body);

          final String? secureUrl =
              data['secure_url'];

          if (secureUrl == null) {
            throw Exception(
                'Upload succeeded but secure_url missing');
          }

          // Store hash → URL mapping
          uploadedHashes[hash] = secureUrl;

          uploadedUrls.add(secureUrl);

          print('✅ Uploaded: $secureUrl');
        } else {
          print('❌ Cloudinary Error: ${response.body}');
          throw Exception(
              'Cloudinary upload failed: ${response.body}');
        }
      }

      print('🎉 Upload process completed');
      return uploadedUrls;
    } catch (e) {
      throw Exception('Cloudinary upload failed: $e');
    }
  }
}
