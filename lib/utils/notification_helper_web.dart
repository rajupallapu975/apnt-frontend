import 'dart:js' as js;

/// Professional high-fidelity Web implementation using 'dart:js' interop.
/// Enables the 'Ask 3 Times' notification strategy for browser/PWA users.
Future<String> getBrowserNotificationStatus() async {
  try {
     final status = (js.context['Notification'] as js.JsObject)['permission'].toString();
     return status;
  } catch (_) {
    return 'unsupported';
  }
}

void triggerBrowserNotificationPermission() {
  try {
     js.context['Notification'].callMethod('requestPermission');
  } catch (_) {}
}
