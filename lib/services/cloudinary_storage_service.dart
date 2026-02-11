import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../config/cloudinary_config.dart';
import '../utils/app_exceptions.dart';

class CloudinaryStorageService {
  /// RAW endpoint for PDF uploads
  String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/raw/upload';

  Future<List<String>> uploadFiles({
    required String orderId,
    required List<File?> files,
    required List<Uint8List?> bytes,
  }) async {
    final List<String> uploadedUrls = [];

    try {
      print('🚀 Cloudinary upload started');
      print('🆔 Order ID: $orderId');

      for (int i = 0; i < files.length; i++) {
        final File? file = files[i];
        final Uint8List? fileBytes = bytes[i];

        if (file == null && fileBytes == null) continue;

        final String filename =
            file != null ? path.basename(file.path) : 'file_${i + 1}.pdf';

        final request = http.MultipartRequest(
          'POST',
          Uri.parse(_uploadUrl),
        );

        /// REQUIRED for unsigned upload
        request.fields['upload_preset'] =
            CloudinaryConfig.uploadPreset;

        /// Folder path inside Cloudinary
        request.fields['folder'] =
            'raw_pdf_signed/orders/$orderId';

        /// Attach file
        if (fileBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: filename,
              contentType: MediaType('application', 'pdf'),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              file!.path,
              filename: filename,
              contentType: MediaType('application', 'pdf'),
            ),
          );
        }

        print('📤 Uploading: $filename');

        final streamedResponse = await request.send();
        final response =
            await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 ||
            response.statusCode == 201) {
          final Map<String, dynamic> data =
              jsonDecode(response.body);

          final String? secureUrl = data['secure_url'];

          if (secureUrl == null) {
            throw CloudinaryException(
                'Upload succeeded but secure_url missing');
          }

          uploadedUrls.add(secureUrl);
          print('✅ Uploaded: $secureUrl');
        } else {
          print('❌ Cloudinary Error: ${response.body}');
          final error = jsonDecode(response.body);
          throw CloudinaryException(
            error['error']?['message'] ??
                'Cloudinary upload failed',
            error,
          );
        }
      }

      print('🎉 All files uploaded successfully');
      return uploadedUrls;
    } catch (e) {
      if (e is AppException) rethrow;
      throw CloudinaryException('Cloudinary upload failed', e);
    }
  }
}
