import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import 'photo_meta.dart';
import 'photo_processor.dart';
import 'photo_store.dart';

/// ایک تصویر کا کام (diskپر محفوظ - ایپ بند/کریش ہو جائے تو اگلی بار خود مکمل ہو گا)
class PhotoJob {
  final String id, srcPath, stampPath, outPath;
  final double ratio;
  final int maxWidth, quality;
  final bool mirror;
  final double lat, lon;
  final String timeIso, title;
  final bool saveOriginal, saveGallery, shareAfter;
  int attempts;

  PhotoJob({
    required this.id,
    required this.srcPath,
    required this.stampPath,
    required this.outPath,
    required this.ratio,
    required this.maxWidth,
    required this.quality,
    required this.mirror,
    required this.lat,
    required this.lon,
    required this.timeIso,
    required this.title,
    required this.saveOriginal,
    required this.saveGallery,
    required this.shareAfter,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'srcPath': srcPath,
        'stampPath': stampPath,
        'outPath': outPath,
        'ratio': ratio,
        'maxWidth': maxWidth,
        'quality': quality,
        'mirror': mirror,
        'lat': lat,
        'lon': lon,
        'timeIso': timeIso,
        'title': title,
        'saveOriginal': saveOriginal,
        'saveGallery': saveGallery,
        'shareAfter': shareAfter,
        'attempts': attempts,
      };

  factory PhotoJob.fromJson(Map<String, dynamic> j) => PhotoJob(
        id: j['id'] as String,
        srcPath: j['srcPath'] as String,
        stampPath: j['stampPath'] as String,
        outPath: j['outPath'] as String,
        ratio: (j['ratio'] as num).toDouble(),
        maxWidth: (j['maxWidth'] as num).toInt(),
        quality: (j['quality'] as num).toInt(),
        mirror: j['mirror'] as bool,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        timeIso: j['timeIso'] as String,
        title: (j['title'] ?? '') as String,
        saveOriginal: j['saveOriginal'] as bool,
        saveGallery: j['saveGallery'] as bool,
        shareAfter: j['shareAfter'] as bool,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );
}

class QueueResult {
  final bool ok;
  final String outPath;
  final String? error;
  final bool shareAfter;
  final bool galleryFailed;
  const QueueResult(this.ok, this.outPath,
      {this.error, this.shareAfter = false, this.galleryFailed = false});
}

/// قابلِ اعتماد قطار:
/// Capture → GPS snapshot → اصل فائل محفوظ جگہ پر → Queue → Crop/Resize → Stamp → JPG →
/// Gallery → Metadata → Cleanup.   ایک وقت میں ایک کام، ناکامی پر 3 بار دوبارہ کوشش۔
class PhotoQueue {
  PhotoQueue._();
  static final PhotoQueue instance = PhotoQueue._();

  static const _ch = MethodChannel('gps_camera/files');

  /// قطار میں باقی کاموں کی تعداد (UI میں "Saving (n)")
  final ValueNotifier<int> pending = ValueNotifier(0);

  final StreamController<QueueResult> _results = StreamController<QueueResult>.broadcast();
  Stream<QueueResult> get results => _results.stream;

  /// ایسے فائل نام جو قطار میں ہیں (نام ٹکرانے سے بچاؤ)
  final Set<String> reserved = {};

  final Queue<PhotoJob> _jobs = Queue<PhotoJob>();
  bool _running = false;
  String _dir = '';

  String get _failedDir => '${Directory(_dir).parent.path}/queue_failed';

  Future<void> init() async {
    _ensureDir();
    // پچھلی بار کے ادھورے کام
    try {
      final files = Directory(_dir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.job.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        try {
          final j = PhotoJob.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
          if (File(j.srcPath).existsSync() && File(j.stampPath).existsSync()) {
            _jobs.add(j);
            reserved.add(j.outPath);
          } else {
            f.deleteSync();
          }
        } catch (_) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    pending.value = _jobs.length;
    if (_jobs.isNotEmpty) unawaited(_run());
  }

  void _ensureDir() {
    if (_dir.isEmpty) {
      final docs = Directory(PhotoStore.internalDir).parent.path;
      _dir = '$docs/queue';
    }
    final d = Directory(_dir);
    if (!d.existsSync()) d.createSync(recursive: true);
  }

  /// نیا کام شامل کریں؛ فائلیں پہلے محفوظ جگہ پر پہنچتی ہیں پھر کام قطار میں
  Future<void> enqueue({
    required String srcPath,
    required Uint8List stamp,
    required String outPath,
    required double ratio,
    required int maxWidth,
    required int quality,
    required bool mirror,
    required double lat,
    required double lon,
    required DateTime time,
    required String title,
    required bool saveOriginal,
    required bool saveGallery,
    required bool shareAfter,
  }) async {
    _ensureDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    // اصل تصویر کیمرے کی عارضی (cache) جگہ سے ایپ کی محفوظ جگہ پر
    final src = '$_dir/$id.src.jpg';
    try {
      File(srcPath).renameSync(src);
    } catch (_) {
      File(srcPath).copySync(src);
      try {
        File(srcPath).deleteSync();
      } catch (_) {}
    }
    final stampPath = '$_dir/$id.stamp.png';
    File(stampPath).writeAsBytesSync(stamp);

    final job = PhotoJob(
      id: id,
      srcPath: src,
      stampPath: stampPath,
      outPath: outPath,
      ratio: ratio,
      maxWidth: maxWidth,
      quality: quality,
      mirror: mirror,
      lat: lat,
      lon: lon,
      timeIso: time.toIso8601String(),
      title: title,
      saveOriginal: saveOriginal,
      saveGallery: saveGallery,
      shareAfter: shareAfter,
    );
    _saveJob(job);
    reserved.add(outPath);
    _jobs.add(job);
    pending.value = _jobs.length;
    unawaited(_run());
  }

  void _saveJob(PhotoJob j) {
    try {
      File('$_dir/${j.id}.job.json').writeAsStringSync(jsonEncode(j.toJson()));
    } catch (_) {}
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      while (_jobs.isNotEmpty) {
        final job = _jobs.first;
        QueueResult? res;
        String? err;
        try {
          res = await _process(job);
        } catch (e) {
          err = e.toString();
        }
        if (res != null) {
          _complete(job);
          _results.add(res);
          continue;
        }
        job.attempts++;
        if (job.attempts >= 3) {
          _giveUp(job);
          _results.add(QueueResult(false, job.outPath, error: err ?? 'failed'));
        } else {
          _saveJob(job);
          await Future.delayed(Duration(seconds: 3 * job.attempts));
        }
      }
    } finally {
      _running = false;
      pending.value = _jobs.length;
    }
  }

  Future<QueueResult> _process(PhotoJob job) async {
    final stamp = File(job.stampPath).readAsBytesSync();
    final args = ProcessArgs(
      srcPath: job.srcPath,
      outPath: job.outPath,
      stampPng: stamp,
      ratio: job.ratio,
      maxWidth: job.maxWidth,
      jpgQuality: job.quality,
      mirror: job.mirror,
    );
    await _compose(args);
    final out = File(job.outPath);
    if (!out.existsSync() || out.lengthSync() == 0) {
      throw Exception('output file missing');
    }

    // گیلری (ناکامی سے تصویر ضائع نہیں ہوتی، ایپ کی Storage میں موجود رہتی ہے)
    var galleryFailed = false;
    if (PhotoStore.publicOk) {
      await PhotoStore.scan(job.outPath);
    } else if (job.saveGallery) {
      try {
        if (!await Gal.hasAccess(toAlbum: true)) {
          await Gal.requestAccess(toAlbum: true);
        }
        await Gal.putImage(job.outPath, album: 'GPS Camera');
        if (job.saveOriginal) await Gal.putImage(job.srcPath, album: 'GPS Camera');
      } catch (_) {
        galleryFailed = true;
      }
    }

    writeMeta(job.outPath,
        lat: job.lat,
        lon: job.lon,
        time: DateTime.tryParse(job.timeIso) ?? DateTime.now(),
        title: job.title);

    return QueueResult(true, job.outPath,
        shareAfter: job.shareAfter, galleryFailed: galleryFailed);
  }

  /// تیز native پروسیسنگ، ناکام ہو تو Dart سے
  Future<void> _compose(ProcessArgs a) async {
    try {
      final ok = await _ch.invokeMethod<bool>('composePhoto', {
        'src': a.srcPath,
        'out': a.outPath,
        'stamp': a.stampPng,
        'ratio': a.ratio,
        'maxWidth': a.maxWidth,
        'quality': a.jpgQuality,
        'mirror': a.mirror,
      });
      if (ok == true) return;
    } catch (_) {}
    await compute(processPhoto, a);
  }

  void _remove(PhotoJob job) {
    if (_jobs.isNotEmpty && identical(_jobs.first, job)) _jobs.removeFirst();
    reserved.remove(job.outPath);
    pending.value = _jobs.length;
    for (final p in [job.stampPath, '$_dir/${job.id}.job.json']) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// کامیاب: عارضی فائلیں صاف
  void _complete(PhotoJob job) {
    _remove(job);
    try {
      final f = File(job.srcPath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// 3 بار ناکام: اصل تصویر الگ فولڈر میں بچا لیں (ضائع نہ ہو)
  void _giveUp(PhotoJob job) {
    try {
      final d = Directory(_failedDir);
      if (!d.existsSync()) d.createSync(recursive: true);
      File(job.srcPath).copySync('${d.path}/${job.id}.jpg');
      File(job.srcPath).deleteSync();
    } catch (_) {}
    _remove(job);
  }
}
