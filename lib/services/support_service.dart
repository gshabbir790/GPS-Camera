import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../config/app_config.dart';
import 'firestore_rest.dart';
import 'remote_guard.dart';

class SupportMsg {
  final String from; // 'user' یا 'admin'
  final String text;
  final DateTime? at;
  const SupportMsg(this.from, this.text, this.at);
}

/// ڈویلپر کو پیغام / جواب (Firestore: tickets/{deviceId}/messages)
class SupportService {
  /// ڈویلپر کا نیا جواب آیا ہوا ہے؟
  static final ValueNotifier<bool> unread = ValueNotifier(false);

  static Future<String> _id() async => (await RemoteGuard.deviceInfo())['id'] ?? '';

  static String _doc(String id) =>
      'projects/${AppConfig.firebaseProjectId}/databases/(default)/documents/tickets/$id';

  static Future<void> refreshUnread() async {
    try {
      if (!AppConfig.statsReady) return;
      final id = await _id();
      if (id.isEmpty) return;
      final r = await fsRequest('GET', '/tickets/$id');
      if (r.code == 200 && r.json != null) {
        final f = Map<String, dynamic>.from((r.json!['fields'] as Map?) ?? {});
        unread.value = fsInt(f, 'unreadUser') > 0;
      } else {
        unread.value = false;
      }
    } catch (_) {}
  }

  /// پیغامات؛ ناکامی پر null
  static Future<List<SupportMsg>?> fetch() async {
    final id = await _id();
    if (id.isEmpty) return null;
    final r = await fsRequest('GET', '/tickets/$id/messages?orderBy=at&pageSize=300');
    if (r.code == 404) return [];
    if (r.code != 200 || r.json == null) return null;
    final docs = (r.json!['documents'] as List?) ?? [];
    return [
      for (final d in docs)
        SupportMsg(
          fsStr(Map<String, dynamic>.from((d as Map)['fields'] as Map? ?? {}), 'from'),
          fsStr(Map<String, dynamic>.from(d['fields'] as Map? ?? {}), 'text'),
          fsTime(Map<String, dynamic>.from(d['fields'] as Map? ?? {}), 'at'),
        )
    ];
  }

  /// null = کامیاب، ورنہ خرابی کا متن
  static Future<String?> send(String text, String contact) async {
    final dev = await RemoteGuard.deviceInfo();
    final id = dev['id'] ?? '';
    if (id.isEmpty) return 'Device ID not available';
    final t = text.trim();
    if (t.isEmpty) return 'Empty message';

    final a = await fsRequest('POST', '/tickets/$id/messages', body: {
      'fields': {
        'from': {'stringValue': 'user'},
        'text': {'stringValue': t.length > 2000 ? t.substring(0, 2000) : t},
        'at': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      },
    });
    if (a.code != 200) {
      final m = a.message.toLowerCase();
      if (a.code == 404 && m.contains('database')) {
        return 'Firestore database is not created yet (developer setup)';
      }
      if (a.code == 403) return 'Permission denied (Firestore rules not published)';
      if (a.code == 0) return 'No connection';
      return 'Server error (${a.code})';
    }

    final c = contact.trim();
    final fields = <String, dynamic>{
      'deviceId': {'stringValue': id},
      'model': {'stringValue': dev['model'] ?? ''},
      'android': {'stringValue': dev['android'] ?? ''},
      'appVersion': {'stringValue': kAppVersion},
      'contact': {'stringValue': c},
      'lastText': {'stringValue': t.length > 200 ? t.substring(0, 200) : t},
      'lastFrom': {'stringValue': 'user'},
      'unreadUser': {'integerValue': '0'},
    };
    await fsRequest('POST', ':commit', body: {
      'writes': [
        {
          'update': {'name': _doc(id), 'fields': fields},
          'updateMask': {'fieldPaths': fields.keys.toList()},
          'updateTransforms': [
            {'fieldPath': 'lastAt', 'setToServerValue': 'REQUEST_TIME'},
            {'fieldPath': 'unreadAdmin', 'increment': {'integerValue': '1'}},
          ],
        },
      ],
    });
    return null;
  }

  static Future<void> markRead() async {
    try {
      final id = await _id();
      if (id.isEmpty) return;
      await fsRequest('POST', ':commit', body: {
        'writes': [
          {
            'update': {
              'name': _doc(id),
              'fields': {'unreadUser': {'integerValue': '0'}},
            },
            'updateMask': {'fieldPaths': ['unreadUser']},
          },
        ],
      });
      unread.value = false;
    } catch (_) {}
  }

  static Future<String> getContact() async =>
      (await SharedPreferences.getInstance()).getString('support_contact') ?? '';

  static Future<void> saveContact(String v) async =>
      (await SharedPreferences.getInstance()).setString('support_contact', v.trim());

  /// سرور سے رابطے کی جانچ
  static Future<String> test() async {
    final r = await fsRequest('GET', '/config/app');
    final m = r.message.toLowerCase();
    switch (r.code) {
      case 200:
        return 'OK (200) - connected';
      case 404:
        if (m.contains('database')) {
          return 'Firestore database is NOT created. Firebase Console → Build → Firestore Database → Create database.';
        }
        return 'OK (404) - connected (config/app not created yet)';
      case 0:
        return 'No connection (internet?)';
      case 403:
      case 401:
        return 'Rejected (${r.code}) - Firestore rules not published or API key problem.\n${r.message}';
      case 400:
        return 'Bad request (400) - ${r.message}';
      default:
        return 'Error (${r.code}) ${r.message}';
    }
  }
}
