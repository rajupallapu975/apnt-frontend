import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class ImageProcessingService {
  /// Standard A4 dimensions at 300 DPI: 2480 x 3508
  static const int a4Width = 2480;
  static const int a4Height = 3508;

  /// Process an image to fit into an A4 sheet (Portrait or Landscape)
  /// without cropping, adding white margins if necessary.
  static Future<Uint8List> processImageToA4({
    required Uint8List imageBytes,
    required bool isPortrait,
    int quality = 90,
  }) async {
    return await compute(_processImage, {
      'bytes': imageBytes,
      'isPortrait': isPortrait,
      'quality': quality,
    });
  }
  
  static Uint8List _processImage(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final bool isPortrait = params['isPortrait'];
    final int quality = params['quality'];

    final img.Image? original = img.decodeImage(bytes);
    if (original == null) throw Exception("Could not decode image");

    // Determine target dimensions
    final int targetWidth = isPortrait ? a4Width : a4Height;
    final int targetHeight = isPortrait ? a4Height : a4Width;

    // Create a white canvas
    final img.Image canvas = img.Image(width: targetWidth, height: targetHeight);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    // Scale original image to fit inside target dimensions proportionally
    final double scaleX = targetWidth / original.width;
    final double scaleY = targetHeight / original.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final int newWidth = (original.width * scale).toInt();
    final int newHeight = (original.height * scale).toInt();

    final img.Image resized = img.copyResize(
      original,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    // Center the resized image on the canvas
    final int xOffset = (targetWidth - newWidth) ~/ 2;
    final int yOffset = (targetHeight - newHeight) ~/ 2;

    img.compositeImage(
      canvas,
      resized,
      dstX: xOffset,
      dstY: yOffset,
    );

    return Uint8List.fromList(img.encodeJpg(canvas, quality: quality));
  }
}
