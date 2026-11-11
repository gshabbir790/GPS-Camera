import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../app_info.dart';
import '../config/app_config.dart';
import '../models/app_settings.dart';

/// گمنام استعمال کی معلومات (صارف کی اجازت کے بعد): ورژن، فون ماڈل، تقریبی علاقہ (~1 کلومیٹر)
class UsageStats {
  static const _ch = MethodChannel('gps_camera/files');
  static bool _sent = false;

  static Future<void> ping({required double lat, required double lon, String place = ''}) async {
    final s = AppSettings.instance;
    if (_sent || s.statsConsent != 1 || !AppConfig.statsReady) return;
    _sent = true;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      var model = '', android = '';
      try {
        final info = Map<String, dynamic>.from(await _ch.invokeMethod('deviceInfo') as Map);
        model = (info['model'] ?? '').toString();
        android = (info['android'] ?? '').toString();
      } catch (_) {}

      // درستگی ~1 کلومیٹر تک گھٹائی گئی (privacy)
      final rLat = (lat * 100).round() / 100;
      final rLon = (lon * 100).round() / 100;

      final doc = 'projects/${AppConfig.firebaseProjectId}/databases/(default)/documents/installs/${s.installId}';
      final body = jsonEncode({
        'writes': [
          {
            'update': {
              'name': doc,
              'fields': {
                'version': {'stringValue': kAppVersion},
                'model': {'stringValue': model},
                'android': {'stringValue': android},
                'lat': {'doubleValue': rLat},
                'lon': {'doubleValue': rLon},
                'place': {'stringValue': place},
                'firstSeen': {'timestampValue': s.firstSeen},
              },
            },
            'updateMask': {
              'fieldPaths': ['version', 'model', 'android', 'lat', 'lon', 'place', 'firstSeen'],
            },
            'updateTransforms': [
              {'fieldPath': 'lastSeen', 'setToServerValue': 'REQUEST_TIME'},
              {
                'fieldPath': 'sessions',
                'increment': {'integerValue': '1'},
              },
            ],
          },
        ],
      });

      Future<int> post(String key, {bool asAndroid = false}) async {
        final url = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/${AppConfig.firebaseProjectId}/databases/(default)/documents:commit?key=$key');
        final req = await client.postUrl(url);
        req.headers.set('Content-Type', 'application/json');
        if (asAndroid) {
          // Android کے لیے محدود (restricted) key کی شناخت
          req.headers.set('X-Android-Package', AppConfig.androidPackage);
          req.headers.set('X-Android-Cert', AppConfig.androidCertSha1);
        }
        req.add(utf8.encode(body));
        final res = await req.close().timeout(const Duration(seconds: 15));
        await res.drain<void>();
        return res.statusCode;
      }

      var code = await post(AppConfig.firebaseApiKey);
      if (code != 200 && AppConfig.firebaseAndroidKey.isNotEmpty) {
        code = await post(AppConfig.firebaseAndroidKey, asAndroid: true);
      }
      if (code != 200) _sent = false; // اگلی بار دوبارہ کوشش
    } catch (_) {
      // خاموشی سے نظر انداز - ایپ پر کوئی اثر نہیں
    } finally {
      client.close(force: true);
    }
  }
}
