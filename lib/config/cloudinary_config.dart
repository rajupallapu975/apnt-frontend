class CloudinaryConfig {
  // Main Cloudinary
  static const String cloudName = 'dpmpyvmbg';
  static const String uploadPreset = 'printer_unsigned';

  // Secondary Cloudinary (Xerox Shop)
  static const String cloudNameB = 'doymq9qhk';
  static const String uploadPresetB = 'printer_unsigned';

  // Backup Cloudinary (Failover Account)
  static const String cloudNameC = 'irtchxuf';
  static const String uploadPresetC = 'printer_unsigned';
}
