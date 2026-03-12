import 'dart:math';

class OrderUtils {
  /// Generate a 4-digit unique code for Xerox Shops
  static String generateXeroxCode() {
    final Random random = Random();
    final int number = 1000 + random.nextInt(9000); // 4 digit number
    return number.toString();
  }
}
