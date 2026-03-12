import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../config/cloudinary_config.dart';

class CloudinaryStorageService {

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

  Future<Map<String, List<String>>> uploadFiles({
    required String pickupCode,
    required List<File?> files,
    required List<Uint8List?> bytes,
    List<String?>? filenames,
    String printMode = 'autonomous', // Determine which account to use
  }) async {
    final isXerox = printMode == 'xeroxShop';
    final currentCloudName = isXerox ? CloudinaryConfig.cloudNameB : CloudinaryConfig.cloudName;
    final currentUploadPreset = isXerox ? CloudinaryConfig.uploadPresetB : CloudinaryConfig.uploadPreset;

    // ⚔️ EXPERT FIX: CLONE EVERYTHING IMMEDIATELY
    // We must copy every single file into standard memory BEFORE the first 'await'.
    // If we wait (sequential upload), Chrome will detach the later files in the list.
    final List<Uint8List> lockedBytes = [];
    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if (b != null) {
        lockedBytes.add(Uint8List.fromList(List<int>.from(b)));
      } else if (i < files.length && files[i] != null && !kIsWeb) {
        // For mobile, we can read later, but for safety we'd usually pre-read.
        // However, the detachment issue is specifically a Web/Browser problem.
        lockedBytes.add(await files[i]!.readAsBytes());
      } else {
        // Add empty if missing
        lockedBytes.add(Uint8List(0));
      }
    }

    final List<String> uploadedUrls = [];
    final List<String> publicIds = [];
    final Map<String, Map<String, String>> uploadedCache = {};
    int totalUploadedBytes = 0;

    try {
      for (int i = 0; i < lockedBytes.length; i++) {
        final Uint8List bytesToUse = lockedBytes[i];
        if (bytesToUse.isEmpty) continue;

        // Robust name detection
        final String originalName = (filenames != null && filenames.length > i && filenames[i] != null)
            ? filenames[i]!
            : 'file_${i + 1}';

        final String hash = md5.convert(bytesToUse).toString();

        if (uploadedCache.containsKey(hash)) {
          uploadedUrls.add(uploadedCache[hash]!['url']!);
          publicIds.add(uploadedCache[hash]!['publicId']!);
          continue;
        }

        final extension = path.extension(originalName).toLowerCase();
        final String basePublicId = '${pickupCode}_${i + 1}';
        final String fullPublicId = 'orders/$pickupCode/$basePublicId';

        // 🚀 Resource type routing:
        // - PDF → 'image' (viewable in dashboard)
        // - DOC/DOCX → 'raw' (office documents)
        // - everything else → 'auto'
        final bool isPdf = extension == '.pdf';
        final bool isDoc = extension == '.doc' || extension == '.docx';
        final String resourceType = isPdf ? 'image' : (isDoc ? 'raw' : 'auto');
        final String uploadUrl = 'https://api.cloudinary.com/v1_1/$currentCloudName/$resourceType/upload';

        debugPrint('📤 Uploading $originalName as $resourceType to $fullPublicId (account: $currentCloudName)...');
        
        final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.fields['upload_preset'] = currentUploadPreset;
        request.fields['public_id'] = fullPublicId;

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytesToUse,
            filename: '$basePublicId$extension',
            contentType: _getMediaType(originalName),
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final String? secureUrl = data['secure_url'];
          final String? pId = data['public_id'];

          if (secureUrl == null || pId == null) {
            throw Exception('Upload succeeded but secure_url or public_id missing');
          }

          uploadedCache[hash] = {'url': secureUrl, 'publicId': pId};
          uploadedUrls.add(secureUrl);
          publicIds.add(pId);
          totalUploadedBytes += (data['bytes'] as num?)?.toInt() ?? bytesToUse.length;

          debugPrint('✅ Uploaded: $secureUrl');
        } else {
          throw Exception('Cloudinary upload failed: ${response.body}');
        }
      }

      return {
        'urls': uploadedUrls,
        'publicIds': publicIds,
        'totalBytes': ['$totalUploadedBytes'],
      };
    } catch (e) {
      debugPrint('❌ ERROR IN UPLOAD_FILES: $e');
      throw Exception('Cloudinary upload failed: $e');
    }
  }
}
