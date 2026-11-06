import 'dart:io';

/// اصل انٹرنیٹ موجود ہے یا نہیں (Wi-Fi یا موبائل ڈیٹا - جو بھی ہو)
Future<bool> hasInternet() async {
  try {
    final r = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
    if (r.isNotEmpty && r.first.rawAddress.isNotEmpty) return true;
  } catch (_) {}
  try {
    final s = await Socket.connect('1.1.1.1', 443, timeout: const Duration(seconds: 4));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
