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

  /// Checks if the file name has an allowed extension.
  static bool isValidFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return allowedExtensions.contains(extension);
  }

  /// Returns a comma-separated string of allowed formats for display.
  static String get allowedFormatsString => 
      allowedExtensions.map((e) => e.replaceAll('.', '').toUpperCase()).join(', ');

  /// Validates a list of files and returns only the valid ones.
  /// If any file is invalid, it can throw an exception or return a result indicating failure.
  static List<String> getInvalidFiles(List<String> fileNames) {
    return fileNames
        .where((name) => !isValidFile(name))
        .toList();
  }
}
