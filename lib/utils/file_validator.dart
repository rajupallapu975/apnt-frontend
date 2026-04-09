import 'package:path/path.dart' as path;

class FileValidator {
  static const List<String> allowedExtensions = [
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.bmp',
    '.tiff',
  ];

  static const int maxFileSizeMB = 10;
  static const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;

  /// Checks if the file size is within the allowed limit (10MB).
  static bool isValidSize(int sizeInBytes) {
    return sizeInBytes <= maxFileSizeBytes;
  }

  /// Checks if the file name has an allowed extension.
  static bool isValidFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return allowedExtensions.contains(extension);
  }

  /// Returns a comma-separated string of allowed formats for display.
  static String get allowedFormatsString => 
      allowedExtensions.map((e) => e.replaceAll('.', '').toUpperCase()).join(', ');

  /// Validates a list of files and returns only the valid ones.
  static List<String> getInvalidFiles(List<String> fileNames) {
    return fileNames
        .where((name) => !isValidFile(name))
        .toList();
  }
}
