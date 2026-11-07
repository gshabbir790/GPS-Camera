import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stamp_data.dart';

/// ہر تصویر کے ساتھ محفوظ لوکیشن کی معلومات (photo.jpg.json)
class PhotoMeta {
  final double lat, lon;
  final DateTime time;
  final String title;
  const PhotoMeta(this.lat, this.lon, this.time, this.title);

  String get mapsUrl => mapsLink(lat, lon);
}

String mapsLink(double lat, double lon) =>
    'https://www.google.com/maps/search/?api=1&query=$lat,$lon';

Future<bool> openMaps(double lat, double lon) async {
  try {
    return await launchUrl(Uri.parse(mapsLink(lat, lon)), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

void writeMeta(String photoPath,
    {required double lat, required double lon, required DateTime time, String title = ''}) {
  try {
    File('$photoPath.json').writeAsStringSync(jsonEncode({
      'lat': lat,
      'lon': lon,
      'time': time.toIso8601String(),
      'title': title,
    }));
  } catch (_) {}
}

PhotoMeta? readMeta(String photoPath) {
  try {
    final f = File('$photoPath.json');
    if (!f.existsSync()) return null;
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final lat = (j['lat'] as num).toDouble();
    final lon = (j['lon'] as num).toDouble();
    if (lat == 0 && lon == 0) return null;
    return PhotoMeta(lat, lon, DateTime.parse(j['time'] as String), (j['title'] ?? '').toString());
  } catch (_) {
    return null;
  }
}

void deleteMeta(String photoPath) {
  try {
    final f = File('$photoPath.json');
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

/// Friday, 06/11/2026 09:03 AM
String fmtDateTime(DateTime t) =>
    '${StampData.weekday(t)}, ${StampData.p2(t.day)}/${StampData.p2(t.month)}/${t.year} ${StampData.clock(t)}';

Future<List<File>> listPhotoFiles() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/photos');
  if (!dir.existsSync()) return [];
  final list = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList()
    ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return list;
}
