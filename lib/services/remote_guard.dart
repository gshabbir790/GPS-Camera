import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../config/app_config.dart';
import 'firestore_rest.dart';

enum LicenseState { allowed, trial, denied, expired, unverified }

class RemoteConfig {
  final String minVersion, latestVersion, updateUrl, updateMessage;
  final String whatsapp, priceText, contactMessage;
  final String certSha1; // اجازت شدہ سائننگ SHA-1 (کاما سے الگ)، خالی = ایپ میں لکھی ہوئی
  final bool licenseRequired;
  final int trialDays;

  const RemoteConfig({
    this.minVersion = '',
    this.latestVersion = '',
    this.updateUrl = '',
    this.updateMessage = '',
    this.whatsapp = '',
    this.priceText = '',
    this.contactMessage = '',
    this.certSha1 = '',
    this.licenseRequired = false,
    this.trialDays = 0,
  });
}

class LicenseResult {
  final LicenseState state;
  final int trialDaysLeft;
  final DateTime? expiry;
  const LicenseResult(this.state, {this.trialDaysLeft = 0, this.expiry});
}

/// Firebase کے ذریعے: لازمی اپڈیٹ + ڈیوائس لائسنس + غیر سرکاری APK کی جانچ
class RemoteGuard {
  static const _ch = MethodChannel('gps_camera/files');

  /// ٹرائل کے باقی دن (کیمرہ اسکرین پر دکھانے کے لیے)
  static int? trialDaysLeft;

  static Future<Map<String, String>> deviceInfo() async {
    try {
      final m = Map<String, dynamic>.from(await _ch.invokeMethod('deviceInfo') as Map);
      return {
        'id': (m['id'] ?? '').toString(),
        'model': (m['model'] ?? '').toString(),
        'android': (m['android'] ?? '').toString(),
      };
    } catch (_) {
      return {'id': '', 'model': '', 'android': ''};
    }
  }

  static Future<String> signatureSha1() async {
    try {
      return ((await _ch.invokeMethod<String>('signatureSha1')) ?? '').toUpperCase();
    } catch (_) {
      return '';
    }
  }

  /// a < b ؟  ("2.7.9" < "2.8.0")
  static bool isOlder(String a, String b) {
    List<int> p(String s) =>
        s.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    final x = p(a), y = p(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0;
      final yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi < yi;
    }
    return false;
  }

  /// config/app دستاویز؛ ناکامی پر null
  static Future<RemoteConfig?> fetchConfig() async {
    if (!AppConfig.statsReady) return const RemoteConfig();
    final r = await fsRequest('GET', '/config/app');
    if (r.code == 404) return const RemoteConfig(); // ابھی بنائی نہیں گئی: کوئی پابندی نہیں
    if (r.code != 200 || r.json == null) return null;
    final f = Map<String, dynamic>.from((r.json!['fields'] as Map?) ?? {});
    final cfg = RemoteConfig(
      minVersion: fsStr(f, 'minVersion'),
      latestVersion: fsStr(f, 'latestVersion'),
      updateUrl: fsStr(f, 'updateUrl'),
      updateMessage: fsStr(f, 'updateMessage'),
      whatsapp: fsStr(f, 'whatsapp').replaceAll(RegExp(r'[^0-9]'), ''),
      priceText: fsStr(f, 'priceText'),
      contactMessage: fsStr(f, 'contactMessage'),
      certSha1: fsStr(f, 'certSha1'),
      licenseRequired: fsBool(f, 'licenseRequired'),
      trialDays: fsInt(f, 'trialDays'),
    );
    final p = await SharedPreferences.getInstance();
    await p.setBool('cfg_required', cfg.licenseRequired);
    return cfg;
  }

  static Future<bool> cachedRequired() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('cfg_required') ?? false;
  }

  /// آخری کامیاب جانچ کے بعد مہلت (grace) باقی ہے؟
  static Future<bool> withinGrace() async {
    final p = await SharedPreferences.getInstance();
    final until = p.getInt('lic_ok_until') ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  static Future<void> _markOk() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('lic_ok_until',
        DateTime.now().add(const Duration(hours: AppConfig.graceHours)).millisecondsSinceEpoch);
  }

  static String _docPath(String id) =>
      'projects/${AppConfig.firebaseProjectId}/databases/(default)/documents/devices/$id';

  /// ڈیوائس لائسنس: devices/{deviceId}
  static Future<LicenseResult> checkLicense(RemoteConfig? cfg, Map<String, String> dev) async {
    final id = dev['id'] ?? '';
    if (id.isEmpty) return const LicenseResult(LicenseState.unverified);

    var r = await fsRequest('GET', '/devices/$id');
    if (r.code == 404) {
      // نئی ڈیوائس: درخواست (allowed=false) بنا دیں تاکہ ڈویلپر کنسول میں دیکھ کر منظور کر سکے
      await fsRequest('POST', ':commit', body: {
        'writes': [
          {
            'update': {
              'name': _docPath(id),
              'fields': {
                'allowed': {'booleanValue': false},
                'model': {'stringValue': dev['model'] ?? ''},
                'android': {'stringValue': dev['android'] ?? ''},
                'appVersion': {'stringValue': kAppVersion},
              },
            },
            'currentDocument': {'exists': false},
            'updateTransforms': [
              {'fieldPath': 'lastSeen', 'setToServerValue': 'REQUEST_TIME'},
              {'fieldPath': 'sessions', 'increment': {'integerValue': '1'}},
            ],
          },
        ],
      });
      r = await fsRequest('GET', '/devices/$id');
    }
    if (r.code != 200 || r.json == null) return const LicenseResult(LicenseState.unverified);

    final f = Map<String, dynamic>.from((r.json!['fields'] as Map?) ?? {});
    final allowed = fsBool(f, 'allowed');
    final expiry = fsTime(f, 'expiry');
    final created = DateTime.tryParse((r.json!['createTime'] ?? '').toString());
    final now = (r.serverDate ?? DateTime.now()).toUtc();

    // آخری دیکھنے کا وقت / سیشن (best effort)
    fsRequest('POST', ':commit', body: {
      'writes': [
        {
          'update': {
            'name': _docPath(id),
            'fields': {
              'model': {'stringValue': dev['model'] ?? ''},
              'android': {'stringValue': dev['android'] ?? ''},
              'appVersion': {'stringValue': kAppVersion},
            },
          },
          'updateMask': {
            'fieldPaths': ['model', 'android', 'appVersion'],
          },
          'updateTransforms': [
            {'fieldPath': 'lastSeen', 'setToServerValue': 'REQUEST_TIME'},
            {'fieldPath': 'sessions', 'increment': {'integerValue': '1'}},
          ],
        },
      ],
    });

    if (allowed) {
      if (expiry != null && now.isAfter(expiry.toUtc())) {
        return LicenseResult(LicenseState.expired, expiry: expiry);
      }
      await _markOk();
      return LicenseResult(LicenseState.allowed, expiry: expiry);
    }

    final trialDays = cfg?.trialDays ?? 0;
    if (trialDays > 0 && created != null) {
      final end = created.toUtc().add(Duration(days: trialDays));
      if (now.isBefore(end)) {
        await _markOk();
        final left = end.difference(now).inDays + 1;
        return LicenseResult(LicenseState.trial, trialDaysLeft: left);
      }
    }
    return const LicenseResult(LicenseState.denied);
  }
}
