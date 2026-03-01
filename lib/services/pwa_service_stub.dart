class PWAService {
  static final PWAService _instance = PWAService._internal();
  factory PWAService() => _instance;
  PWAService._internal();

  bool get canInstall => false;

  Future<bool> promptInstall() async {
    return false;
  }
}
