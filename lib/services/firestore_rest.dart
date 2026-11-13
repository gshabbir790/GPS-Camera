import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';

class FsResponse {
  final int code;
  final Map<String, dynamic>? json;
  final DateTime? serverDate; // Google سرور کا وقت (فون کی گھڑی بدلنے سے نہیں بدلتا)
  const FsResponse(this.code, this.json, this.serverDate);
}

/// Firestore REST: پہلے Web key، ناکام ہو تو Android key (package + SHA-1 کے ساتھ)
Future<FsResponse> fsRequest(String method, String path, {Map<String, dynamic>? body}) async {
  FsResponse? last;
  final keys = <List<Object>>[
    [AppConfig.firebaseApiKey, false],
    if (AppConfig.firebaseAndroidKey.isNotEmpty) [AppConfig.firebaseAndroidKey, true],
  ];
  for (final k in keys) {
    last = await _once(method, path, body, k[0] as String, k[1] as bool);
    if (last.code == 200 || last.code == 404 || last.code == 409) return last;
  }
  return last ?? const FsResponse(0, null, null);
}

Future<FsResponse> _once(
    String method, String path, Map<String, dynamic>? body, String key, bool asAndroid) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final base =
        'https://firestore.googleapis.com/v1/projects/${AppConfig.firebaseProjectId}/databases/(default)/documents';
    final sep = path.contains('?') ? '&' : '?';
    final url = Uri.parse('$base$path${sep}key=$key');
    final req = await client.openUrl(method, url);
    if (asAndroid) {
      req.headers.set('X-Android-Package', AppConfig.androidPackage);
      req.headers.set('X-Android-Cert', AppConfig.androidCertSha1);
    }
    if (body != null) {
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(jsonEncode(body)));
    }
    final res = await req.close().timeout(const Duration(seconds: 15));
    final text = await res.transform(utf8.decoder).join();
    DateTime? date;
    final dh = res.headers.value('date');
    if (dh != null) {
      try {
        date = HttpDate.parse(dh);
      } catch (_) {}
    }
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}
    return FsResponse(res.statusCode, json, date);
  } catch (_) {
    return const FsResponse(0, null, null);
  } finally {
    client.close(force: true);
  }
}

// ---- Firestore فیلڈ پڑھنے کے مددگار ----
String fsStr(Map f, String k) => ((f[k] as Map?)?['stringValue'] ?? '').toString();
bool fsBool(Map f, String k) => (f[k] as Map?)?['booleanValue'] == true;
int fsInt(Map f, String k) {
  final m = f[k] as Map?;
  if (m == null) return 0;
  final v = m['integerValue'] ?? m['doubleValue'] ?? 0;
  return int.tryParse(v.toString()) ?? (double.tryParse(v.toString())?.round() ?? 0);
}

DateTime? fsTime(Map f, String k) {
  final v = (f[k] as Map?)?['timestampValue'];
  return v == null ? null : DateTime.tryParse(v.toString());
}
