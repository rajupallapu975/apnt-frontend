/// Custom exception class for the application
class AppException implements Exception {
  final String message;
  final String prefix;
  final dynamic originalError;

  AppException(this.message, this.prefix, [this.originalError]);

  @override
  String toString() {
    return "$prefix: $message";
  }
}

class NetworkException extends AppException {
  NetworkException(String message, [dynamic error]) 
      : super(message, "Network Error", error);
}

class CloudinaryException extends AppException {
  CloudinaryException(String message, [dynamic error]) 
      : super(message, "Cloudinary Error", error);
}

class FirestoreException extends AppException {
  FirestoreException(String message, [dynamic error]) 
      : super(message, "Database Error", error);
}

class ValidationException extends AppException {
  ValidationException(String message) 
      : super(message, "Validation Error");
}
