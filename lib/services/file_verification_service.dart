import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

class FileVerificationResult {
  final bool isValid;
  final bool isSafe;
  final double blackContentPercentage;
  final String? errorMessage;
  final List<String> warnings;

  FileVerificationResult({
    required this.isValid,
    required this.isSafe,
    required this.blackContentPercentage,
    this.errorMessage,
    this.warnings = const [],
  });

  bool get hasHighBlackContent => blackContentPercentage > 60.0;
}

class FileVerificationService {
  /// Verify a file for safety and black content
  Future<FileVerificationResult> verifyFile({
    File? file,
    Uint8List? bytes,
    required String fileName,
  }) async {
    try {
      // Basic file validation
      if (file == null && bytes == null) {
        return FileVerificationResult(
          isValid: false,
          isSafe: false,
          blackContentPercentage: 0,
          errorMessage: 'No file provided',
        );
      }

      final warnings = <String>[];

      // Check file extension
      final extension = fileName.toLowerCase().split('.').last;
      if (!_isSupportedFileType(extension)) {
        return FileVerificationResult(
          isValid: false,
          isSafe: false,
          blackContentPercentage: 0,
          errorMessage: 'Unsupported file type: .$extension',
        );
      }

      // Check file size (max 50MB)
      final fileSize = file?.lengthSync() ?? bytes?.length ?? 0;
      if (fileSize > 50 * 1024 * 1024) {
        return FileVerificationResult(
          isValid: false,
          isSafe: false,
          blackContentPercentage: 0,
          errorMessage: 'File too large. Maximum size is 50MB',
        );
      }

      // Verify file is not corrupted
      final isSafe = await _verifyFileSafety(file, bytes, extension);
      if (!isSafe) {
        return FileVerificationResult(
          isValid: false,
          isSafe: false,
          blackContentPercentage: 0,
          errorMessage: 'File appears to be corrupted or unsafe',
        );
      }

      // Calculate black content percentage
      double blackPercentage = 0;
      if (extension == 'pdf') {
        blackPercentage = await _calculatePdfBlackContent(file, bytes);
      } else {
        blackPercentage = await _calculateImageBlackContent(file, bytes);
      }

      // Add warning if high black content
      if (blackPercentage > 60) {
        warnings.add(
          'High black content detected (${blackPercentage.toStringAsFixed(1)}%). '
          'Price will be doubled for this page.',
        );
      }

      return FileVerificationResult(
        isValid: true,
        isSafe: true,
        blackContentPercentage: blackPercentage,
        warnings: warnings,
      );
    } catch (e) {
      return FileVerificationResult(
        isValid: false,
        isSafe: false,
        blackContentPercentage: 0,
        errorMessage: 'Error verifying file: $e',
      );
    }
  }

  /// Check if file type is supported
  bool _isSupportedFileType(String extension) {
    const supportedTypes = [
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
    ];
    return supportedTypes.contains(extension);
  }

  /// Verify file safety (basic checks)
  Future<bool> _verifyFileSafety(
    File? file,
    Uint8List? bytes,
    String extension,
  ) async {
    try {
      if (extension == 'pdf') {
        // Try to open PDF to verify it's valid
        final pdfBytes = bytes ?? await file!.readAsBytes();
        final document = await PdfDocument.openData(pdfBytes);
        await document.close();
        return true;
      } else {
        // Try to decode image to verify it's valid
        final imageBytes = bytes ?? await file!.readAsBytes();
        final image = img.decodeImage(imageBytes);
        return image != null;
      }
    } catch (e) {
      debugPrint('File safety verification failed: $e');
      return false;
    }
  }

  /// Calculate black content percentage for images
  Future<double> _calculateImageBlackContent(
    File? file,
    Uint8List? bytes,
  ) async {
    try {
      final imageBytes = bytes ?? await file!.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) return 0;

      int darkPixels = 0;

      // Sample every 10th pixel for performance
      for (int y = 0; y < image.height; y += 10) {
        for (int x = 0; x < image.width; x += 10) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          
          // Calculate brightness (0-255)
          final brightness = (r + g + b) / 3;
          
          // Consider pixel dark if brightness < 100
          if (brightness < 100) {
            darkPixels++;
          }
        }
      }

      // Adjust for sampling
      final sampledTotal = (image.width / 10).ceil() * (image.height / 10).ceil();
      final percentage = (darkPixels / sampledTotal) * 100;
      
      return percentage.clamp(0, 100);
    } catch (e) {
      debugPrint('Error calculating image black content: $e');
      return 0;
    }
  }

  /// Calculate black content percentage for PDFs
  Future<double> _calculatePdfBlackContent(
    File? file,
    Uint8List? bytes,
  ) async {
    try {
      final pdfBytes = bytes ?? await file!.readAsBytes();
      final document = await PdfDocument.openData(pdfBytes);
      
      double totalBlackPercentage = 0;
      int pageCount = 0;

      // Analyze first 5 pages or all pages if less than 5
      final pagesToAnalyze = document.pagesCount > 5 ? 5 : document.pagesCount;

      for (int i = 1; i <= pagesToAnalyze; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width,
          height: page.height,
          format: PdfPageImageFormat.png,
        );
        
        if (pageImage != null) {
          final image = img.decodeImage(pageImage.bytes);
          if (image != null) {
            int darkPixels = 0;
            
            // Sample every 20th pixel for performance
            for (int y = 0; y < image.height; y += 20) {
              for (int x = 0; x < image.width; x += 20) {
                final pixel = image.getPixel(x, y);
                final r = pixel.r.toInt();
                final g = pixel.g.toInt();
                final b = pixel.b.toInt();
                
                final brightness = (r + g + b) / 3;
                if (brightness < 100) {
                  darkPixels++;
                }
              }
            }

            final sampledTotal = (image.width / 20).ceil() * (image.height / 20).ceil();
            final pagePercentage = (darkPixels / sampledTotal) * 100;
            totalBlackPercentage += pagePercentage;
            pageCount++;
          }
        }
        
        await page.close();
      }

      await document.close();

      return pageCount > 0 ? (totalBlackPercentage / pageCount).clamp(0, 100) : 0;
    } catch (e) {
      debugPrint('Error calculating PDF black content: $e');
      return 0;
    }
  }

  /// Get price multiplier based on black content
  /// Only applies to black and white prints, not color prints
  double getPriceMultiplier(double blackContentPercentage, {bool isColor = false}) {
    // Black content pricing only applies to B&W prints
    if (isColor) {
      return 1.0; // No multiplier for color prints
    }
    return blackContentPercentage > 60 ? 2.0 : 1.0;
  }

  /// Calculate adjusted price
  double calculateAdjustedPrice({
    required double basePrice,
    required double blackContentPercentage,
    bool isColor = false,
  }) {
    final multiplier = getPriceMultiplier(blackContentPercentage, isColor: isColor);
    return basePrice * multiplier;
  }
}
