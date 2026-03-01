import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS()
external bool isPwaInstallable();

@JS()
external bool isStandalone();

@JS()
external JSPromise<JSBoolean> promptPwaInstall();

class PWAService {
  static final PWAService _instance = PWAService._internal();
  factory PWAService() => _instance;
  PWAService._internal();

  bool get canInstall => kIsWeb && !_isAlreadyInstalled() && _checkInstallable();

  bool _isAlreadyInstalled() {
    try {
      return isStandalone();
    } catch (e) {
      return false;
    }
  }

  bool _checkInstallable() {
    try {
      return isPwaInstallable();
    } catch (e) {
      return false;
    }
  }

  Future<bool> promptInstall() async {
    if (!canInstall) return false;
    try {
      final result = await promptPwaInstall().toDart;
      return result.toDart;
    } catch (e) {
      debugPrint('❌ PWA Install Error: $e');
      return false;
    }
  }
}
