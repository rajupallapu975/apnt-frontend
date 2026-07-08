import 'dart:convert';
import 'dart:io';

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
    int totalUploadedBytes = 0;

    try {
      final uploadFutures = List.generate(lockedBytes.length, (i) async {
        final Uint8List bytesToUse = lockedBytes[i];
        if (bytesToUse.isEmpty) return null;

        // Robust name detection
        final String originalName = (filenames != null && filenames.length > i && filenames[i] != null)
            ? filenames[i]!
            : 'file_${i + 1}';

        final extension = path.extension(originalName).toLowerCase();
        final String basePublicId = '${pickupCode}_${i + 1}';
        final String folderPath = isXerox ? 'xerox_orders' : 'autonomous_orders';
        final String fullPublicId = '$folderPath/$pickupCode/$basePublicId';

        final bool isPdf = extension == '.pdf';
        final bool isDoc = extension == '.doc' || extension == '.docx';
        final String resourceType = isPdf ? 'image' : (isDoc ? 'raw' : 'auto');

        // 🛡️ Failover Account Selection
        String activeCloudName = currentCloudName;
        String activeUploadPreset = currentUploadPreset;

        try {
          return await _executeSingleUpload(
            bytes: bytesToUse,
            cloudName: activeCloudName,
            uploadPreset: activeUploadPreset,
            resourceType: resourceType,
            fullPublicId: fullPublicId,
            basePublicId: basePublicId,
            extension: extension,
            originalName: originalName,
          );
        } catch (primaryErr) {
          debugPrint('⚠️ Primary Cloudinary Upload Failed ($activeCloudName): $primaryErr');
          debugPrint('🔄 Switching to Backup Cloudinary Account (Account C)...');

          activeCloudName = CloudinaryConfig.cloudNameC;
          activeUploadPreset = CloudinaryConfig.uploadPresetC;

          try {
            return await _executeSingleUpload(
              bytes: bytesToUse,
              cloudName: activeCloudName,
              uploadPreset: activeUploadPreset,
              resourceType: resourceType,
              fullPublicId: fullPublicId,
              basePublicId: basePublicId,
              extension: extension,
              originalName: originalName,
            );
          } catch (backupErr) {
            debugPrint('❌ Backup Cloudinary Upload also failed ($activeCloudName): $backupErr');
            if (isXerox) {
              debugPrint('🔄 Xerox fallback: trying Account A as a secondary backup...');
              activeCloudName = CloudinaryConfig.cloudName;
              activeUploadPreset = CloudinaryConfig.uploadPreset;
              try {
                return await _executeSingleUpload(
                  bytes: bytesToUse,
                  cloudName: activeCloudName,
                  uploadPreset: activeUploadPreset,
                  resourceType: resourceType,
                  fullPublicId: fullPublicId,
                  basePublicId: basePublicId,
                  extension: extension,
                  originalName: originalName,
                );
              } catch (_) {}
            }
            throw backupErr;
          }
        }
      });

      final resultsList = await Future.wait(uploadFutures);
      for (final res in resultsList) {
        if (res != null) {
          uploadedUrls.add(res['url'] as String);
          publicIds.add(res['publicId'] as String);
          totalUploadedBytes += res['bytes'] as int;
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

  Future<Map<String, dynamic>> _executeSingleUpload({
    required Uint8List bytes,
    required String cloudName,
    required String uploadPreset,
    required String resourceType,
    required String fullPublicId,
    required String basePublicId,
    required String extension,
    required String originalName,
  }) async {
    final String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload';
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.fields['upload_preset'] = uploadPreset;
    request.fields['public_id'] = fullPublicId;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
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

      debugPrint('✅ Uploaded: $secureUrl');
      return {
        'url': secureUrl,
        'publicId': pId,
        'bytes': (data['bytes'] as num?)?.toInt() ?? bytes.length,
      };
    } else {
      throw Exception('Cloudinary upload failed (Status ${response.statusCode}): ${response.body}');
    }
  }
}
