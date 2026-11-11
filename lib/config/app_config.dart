/// استعمال کے اعداد و شمار (Firebase Firestore)
/// خالی ہوں تو یہ فیچر بند رہتا ہے اور کچھ بھی نہیں بھیجا جاتا۔
class AppConfig {
  /// Firebase Console → Project settings → Project ID
  static const firebaseProjectId = 'gps-camera-9af65';

  /// Web app کی API Key (پہلے یہ آزمائی جاتی ہے)
  static const firebaseApiKey = 'AIzaSyALtNdUPsCIQ5jK84C0JLp_r0hJHgLMVMQ';

  /// Android app کی API Key (google-services.json سے) - اگر اوپر والی نہ چلے تو یہ
  static const firebaseAndroidKey = 'AIzaSyBk1qwB2B9F2qzhqVN483iNCMB0Uqj7ebI';

  /// ایپ کا پیکج نام اور سائننگ سرٹیفکیٹ SHA-1 (ci/debug.keystore) - Android key کے لیے
  static const androidPackage = 'com.gsabbir.gps_camera';
  static const androidCertSha1 = '6135B773FE37CDA2A5066A1988702683EAD6D865';

  static bool get statsReady => firebaseProjectId.isNotEmpty && firebaseApiKey.isNotEmpty;
}
