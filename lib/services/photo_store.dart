import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// تصاویر کا فولڈر: فون کی جڑ میں  /storage/emulated/0/GPS Camera
/// (اس کے لیے "All files access" کی اجازت چاہیے، ورنہ ایپ کے اندرونی فولڈر میں)
class PhotoStore {
  static const _ch = MethodChannel('gps_camera/files');
  static const rootPath = '/storage/emulated/0/GPS Camera';

  static String internalDir = '';
  static String metaDir = '';
  static bool _publicOk = false;

  /// True ہو تو تصاویر "GPS Camera" فولڈر میں محفوظ ہو رہی ہیں
  static bool get publicOk => _publicOk;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    internalDir = '${docs.path}/photos';
    metaDir = '${docs.path}/meta';
    for (final d in [internalDir, metaDir]) {
      final x = Directory(d);
      if (!x.existsSync()) x.createSync(recursive: true);
    }
    await refresh();
  }

  static Future<bool> hasAllFiles() async {
    try {
      return (await _ch.invokeMethod<bool>('hasAllFilesAccess')) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestAllFiles() async {
    try {
      await _ch.invokeMethod('requestAllFilesAccess');
    } catch (_) {}
  }

  /// Play Store کے مطابق: کوئی اضافی اجازت نہیں - تصاویر گیلری (Pictures/GPS Camera) میں جاتی ہیں
  static Future<bool> refresh() async {
    _publicOk = false;
    return false;
  }

  /// لوکیشن کی "Precise" (درست) اجازت ملی ہے یا صرف تقریبی؟
  static Future<bool> hasFineLocation() async {
    try {
      return (await _ch.invokeMethod<bool>('hasFineLocation')) != false;
    } catch (_) {
      return true;
    }
  }

  static Directory saveDir() {
    final d = Directory(_publicOk ? rootPath : internalDir);
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// گیلری ایپس کو نئی/حذف شدہ فائل کا بتانا
  static Future<void> scan(String path) async {
    try {
      await _ch.invokeMethod('scanFile', path);
    } catch (_) {}
  }

  /// دونوں فولڈرز (نیا + پرانا اندرونی) کی تصاویر، نئی سب سے اوپر
  static Future<List<File>> allPhotos() async {
    final out = <File>[];
    for (final p in {rootPath, internalDir}) {
      final d = Directory(p);
      try {
        if (d.existsSync()) {
          out.addAll(d.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.jpg')));
        }
      } catch (_) {}
    }
    out.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return out;
  }
}
