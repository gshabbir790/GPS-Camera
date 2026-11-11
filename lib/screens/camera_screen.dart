import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/app_settings.dart';
import '../models/stamp_data.dart';
import '../services/location_service.dart';
import '../services/photo_processor.dart';
import '../widgets/stamp_widget.dart';
import '../widgets/exit_guard.dart';
import '../services/photo_meta.dart';
import '../services/photo_store.dart';
import '../services/usage_stats.dart';
import '../config/app_config.dart';
import 'gallery_screen.dart';
import 'report_home_screen.dart';
import 'settings_screen.dart';
import 'template_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final s = AppSettings.instance;
  final loc = LocationService();

  List<CameraDescription> _cams = [];
  CameraController? _ctrl;
  bool _front = false;
  FlashMode _flash = FlashMode.off;
  double _zoom = 1, _minZoom = 1, _maxZoom = 1;
  String? _error;
  String _camKey = '';
  int _mode = 0; // 0 تصویر، 1 ویڈیو
  bool _recording = false;
  int _recSecs = 0;
  Timer? _recTimer;
  bool _audioDenied = false;
  int _appliedMap = 1;
  bool _routeActive = true;
  static const _volCh = MethodChannel('gps_camera/volume');
  static const _filesCh = MethodChannel('gps_camera/files');
  int _pending = 0;
  final Set<String> _reserved = {};

  bool _busy = false;
  int _count = 0;
  DateTime _now = DateTime.now();
  Timer? _tick;
  String? _lastPhoto;

  // کمپاس
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  List<double> _acc = [0, 9.8, 0], _mag = [0, 0, 0];
  double _heading = 0, _magnet = 0;

  final _stampKey = GlobalKey();
  double _fullRatio = 0.5; // 'Full' موڈ میں پریویو کا (چھوٹا/بڑا) تناسب

  double _captureRatio() => s.ratio == 3 ? _fullRatio : s.ratioValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appliedMap = s.mapType;
    loc.mapType = s.mapType;
    s.addListener(_onSettings);
    _volCh.setMethodCallHandler(_onNative);
    _syncIntercept();
    if (s.manualOn) loc.setManual(s.mLat, s.mLon, title: s.mTitle, address: s.mAddress);
    loc.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_busy) setState(() => _now = DateTime.now());
      final p = loc.lastPos;
      if (p != null && s.statsConsent == 1) {
        final g = loc.state.value;
        UsageStats.ping(lat: p.latitude, lon: p.longitude, place: g.manual ? '' : g.title);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askStatsConsent());
    _initCamera();
    _syncSensors();
    _loadLast();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.removeListener(_onSettings);
    _tick?.cancel();
    _recTimer?.cancel();
    _volCh.setMethodCallHandler(null);
    _volCh.invokeMethod('intercept', false).catchError((_) {});
    _accSub?.cancel();
    _magSub?.cancel();
    loc.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    _lifecycle(st);
  }

  Future<void> _lifecycle(AppLifecycleState st) async {
    if (st == AppLifecycleState.inactive || st == AppLifecycleState.paused) {
      if (_recording) await _stopRecording();
      final c = _ctrl;
      _ctrl = null;
      c?.dispose();
      loc.stop();
      if (mounted) setState(() {});
    } else if (st == AppLifecycleState.resumed) {
      loc.start();
      _initCamera();
    }
  }

  void _onSettings() {
    if (_camKeyNow() != _camKey) {
      _initCamera();
    }
    if (s.mapType != _appliedMap) {
      _appliedMap = s.mapType;
      loc.setMapType(s.mapType);
    }
    _syncIntercept();
    _syncSensors();
    if (mounted) setState(() {});
  }

  // ---------------- والیوم بٹن (native MainActivity کے ذریعے) ----------------
  Future<void> _syncIntercept() async {
    try {
      await _volCh.invokeMethod('intercept', s.volumeAction != 1 && _routeActive);
    } catch (_) {}
  }

  Future<dynamic> _onNative(MethodCall call) async {
    if (call.method != 'key' || !mounted || !_routeActive) return;
    final m = Map<String, dynamic>.from(call.arguments as Map);
    final dir = m['dir'] as String? ?? 'up';
    final rep = (m['repeat'] as int?) ?? 0;
    if (s.volumeAction == 0) {
      if (rep == 0) _capture();
    } else if (s.volumeAction == 2) {
      _setZoom(_zoom + (dir == 'up' ? 0.5 : -0.5));
    }
  }

  Future<T?> _open<T>(Widget page) async {
    _routeActive = false;
    _syncIntercept();
    final r = await Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));
    _routeActive = true;
    _syncIntercept();
    return r;
  }

  // ---------------- کیمرہ ----------------
  String _camKeyNow() => '${s.quality}-${s.videoQuality}-$_mode';

  Future<void> _initCamera() async {
    _camKey = _camKeyNow();
    try {
      if (_cams.isEmpty) _cams = await availableCameras();
      if (_cams.isEmpty) {
        if (mounted) setState(() => _error = S.t('No camera found on this phone', 'اس فون پر کیمرہ نہیں ملا'));
        return;
      }
      final dir = _front ? CameraLensDirection.front : CameraLensDirection.back;
      final desc = _cams.firstWhere((c) => c.lensDirection == dir, orElse: () => _cams.first);
      final preset = _mode == 1
          ? [
              ResolutionPreset.high,
              ResolutionPreset.veryHigh,
              ResolutionPreset.ultraHigh,
            ][s.videoQuality]
          : [
              ResolutionPreset.ultraHigh,
              ResolutionPreset.veryHigh,
              ResolutionPreset.high,
            ][s.quality];

      final old = _ctrl;
      _ctrl = null;
      if (mounted) setState(() {});
      await old?.dispose();

      final c = CameraController(
        desc,
        preset,
        enableAudio: _mode == 1 && !_audioDenied,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await c.initialize();
      _minZoom = await c.getMinZoomLevel();
      _maxZoom = await c.getMaxZoomLevel();
      _zoom = _minZoom > 1.0 ? _minZoom : 1.0;
      try {
        await c.setFlashMode(_flash);
      } catch (_) {}
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _ctrl = c;
        _error = null;
      });
    } on CameraException catch (e) {
      if (e.code.toLowerCase().contains('audio') && !_audioDenied) {
        _audioDenied = true;
        _toast(S.t('Microphone denied - video will have no sound',
            'مائیکروفون کی اجازت نہیں - ویڈیو بغیر آواز کے بنے گی'));
        _initCamera();
        return;
      }
      if (mounted) {
        setState(() => _error = (e.code.contains('Denied'))
            ? S.t('Allow camera permission (Settings → Apps → GPS Camera)', 'کیمرے کی اجازت دیں (Settings → Apps → GPS Camera)')
            : (e.description ?? e.code));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _cycleFlash() async {
    final next = {
      FlashMode.off: FlashMode.auto,
      FlashMode.auto: FlashMode.always,
      FlashMode.always: FlashMode.off,
    }[_flash]!;
    _flash = next;
    try {
      await _ctrl?.setFlashMode(next);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _setZoom(double z) async {
    final v = z.clamp(_minZoom, _maxZoom).toDouble();
    try {
      await _ctrl?.setZoomLevel(v);
      if (mounted) setState(() => _zoom = v);
    } catch (_) {}
  }

  Future<void> _focusAt(TapUpDetails d, BoxConstraints box) async {
    final p = Offset(d.localPosition.dx / box.maxWidth, d.localPosition.dy / box.maxHeight);
    try {
      await _ctrl?.setFocusPoint(p);
      await _ctrl?.setExposurePoint(p);
    } catch (_) {}
  }

  // ---------------- کمپاس سینسر ----------------
  void _syncSensors() {
    if (s.template == 3) {
      _accSub ??= accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen((e) => _acc = [e.x, e.y, e.z], onError: (_) {});
      _magSub ??= magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen((e) {
        _mag = [e.x, e.y, e.z];
        _updateHeading();
      }, onError: (_) {});
    } else {
      _accSub?.cancel();
      _magSub?.cancel();
      _accSub = null;
      _magSub = null;
    }
  }

  void _updateHeading() {
    final a = _acc, m = _mag;
    final hx = m[1] * a[2] - m[2] * a[1];
    final hy = m[2] * a[0] - m[0] * a[2];
    final hz = m[0] * a[1] - m[1] * a[0];
    final hn = sqrt(hx * hx + hy * hy + hz * hz);
    final an = sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    if (hn < 0.1 || an < 0.1) return;
    final mz = a[0] * hy - a[1] * hx; // (a × H).z  = شمال کا z جزو
    final eastZ = hz / hn;
    final northZ = mz / (an * hn);
    // کیمرے کی سمت = -z محور
    var deg = atan2(-eastZ, -northZ) * 180 / pi;
    deg = (deg + 360) % 360;
    var diff = deg - _heading;
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }
    _heading = (_heading + diff * 0.15 + 360) % 360;
    _magnet = sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]);
    if (mounted && !_busy) setState(() {});
  }

  String _statusText(String code) {
    switch (code) {
      case 'gps_off':
        return S.t('Turn on phone location (GPS)', 'فون کی لوکیشن (GPS) آن کریں');
      case 'no_perm':
        return S.t('Allow location permission', 'لوکیشن کی اجازت دیں');
      default:
        return S.t('Finding location...', 'لوکیشن تلاش ہو رہی ہے...');
    }
  }

  // ---------------- اسٹیمپ ڈیٹا ----------------
  StampData _stampData(GeoState g) {
    final hasFix = g.hasFix;
    return StampData(
      title: g.title.isNotEmpty ? g.title : (hasFix ? '' : _statusText(g.status)),
      address: g.fullAddress,
      latLon: hasFix ? g.latLonText : '',
      dateLine: StampData.fullLine(_now),
      note: s.showNote ? s.note : '',
      flag: g.flag,
      time: _now,
      altitude: g.altitude,
      heading: _heading,
      magnet: _magnet,
      map: g.tile,
      mapOverlay: g.overlay,
      mapFx: g.fx,
      mapFy: g.fy,
      qrData: hasFix ? 'https://maps.google.com/?q=${g.lat},${g.lon}' : '',
    );
  }

  // ---------------- تصویر لینا ----------------
  Future<void> _capture() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (_mode == 1) {
      await _toggleRecord();
      return;
    }
    if (_busy) return;
    if (!loc.state.value.hasFix) {
      _toast(S.t('Waiting for GPS location... or set location manually',
          'GPS لوکیشن کا انتظار کریں... یا لوکیشن دستی سیٹ کریں'));
      return;
    }

    if (s.timer > 0) {
      for (var i = s.timer; i > 0; i--) {
        if (!mounted) return;
        setState(() => _count = i);
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;
      setState(() => _count = 0);
    }

    setState(() => _busy = true);
    String? srcPath;
    var handedOff = false;
    try {
      _playSound('shutter');
      final shot = await c.takePicture();
      srcPath = shot.path;

      // عین اسی لمحے کا وقت اسٹیمپ میں
      _now = DateTime.now();
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _stampKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final maxW = AppSettings.maxWidths[s.quality];
      final ui.Image stampImg =
          await boundary.toImage(pixelRatio: maxW / boundary.size.width);
      final bd = await stampImg.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) throw Exception(S.t('Could not create stamp', 'اسٹیمپ نہیں بن سکا'));
      final stampPng = bd.buffer.asUint8List();

      final g = loc.state.value;
      final snapTime = _now;
      final photos = PhotoStore.saveDir(); // GPS Camera فولڈر یا اندرونی فولڈر

      final name = s.buildFileName(snapTime, g.lat, g.lon);
      var outPath = '${photos.path}/$name';
      var n = 1;
      while (File(outPath).existsSync() || _reserved.contains(outPath)) {
        final base = name.substring(0, name.length - 4);
        outPath = '${photos.path}/${base}_$n.jpg';
        n++;
      }
      _reserved.add(outPath);
      s.update(() => s.seq++);

      final args = ProcessArgs(
        srcPath: srcPath,
        outPath: outPath,
        stampPng: stampPng,
        ratio: _captureRatio(),
        maxWidth: maxW,
        jpgQuality: AppSettings.jpgQuality[s.quality],
        mirror: s.mirror,
      );

      // باقی کام (کراپ، اسٹیمپ، JPG، گیلری) پس منظر میں - کیمرہ فوراً دوبارہ تیار
      handedOff = true;
      _pending++;
      if (mounted) setState(() => _busy = false);
      unawaited(_finishPhoto(args, g, snapTime));
    } catch (e) {
      _toast(S.t('Error: $e', 'خرابی: $e'));
    } finally {
      if (!handedOff) {
        if (srcPath != null && !s.saveOriginal) {
          try {
            File(srcPath).deleteSync();
          } catch (_) {}
        }
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _finishPhoto(ProcessArgs a, GeoState g, DateTime t) async {
    try {
      await _compose(a);

      if (PhotoStore.publicOk) {
        // فائل پہلے ہی فون کے "GPS Camera" فولڈر میں ہے - صرف گیلری کو بتانا
        await PhotoStore.scan(a.outPath);
        if (s.saveOriginal) {
          try {
            final orig = '${PhotoStore.rootPath}/ORIG_${a.outPath.split('/').last}';
            File(a.srcPath).copySync(orig);
            await PhotoStore.scan(orig);
          } catch (_) {}
        }
      } else if (s.saveGallery) {
        try {
          if (!await Gal.hasAccess(toAlbum: true)) {
            await Gal.requestAccess(toAlbum: true);
          }
          await Gal.putImage(a.outPath, album: 'GPS Camera');
          if (s.saveOriginal) await Gal.putImage(a.srcPath, album: 'GPS Camera');
        } catch (_) {
          _toast(S.t('Could not save to gallery - check permission',
              'گیلری میں محفوظ نہیں ہو سکی - اجازت چیک کریں'));
        }
      }

      writeMeta(a.outPath, lat: g.lat, lon: g.lon, time: t, title: g.title);
      if (mounted) setState(() => _lastPhoto = a.outPath);
      _toast(S.t('Photo saved ✓', 'تصویر محفوظ ہو گئی ✓'));

      if (s.shareAfter) {
        await Share.shareXFiles([XFile(a.outPath)]);
      }
    } catch (e) {
      _toast(S.t('Error: $e', 'خرابی: $e'));
    } finally {
      if (!s.saveOriginal) {
        try {
          File(a.srcPath).deleteSync();
        } catch (_) {}
      }
      _reserved.remove(a.outPath);
      _pending--;
      if (mounted) setState(() {});
    }
  }

  /// تیز پروسیسنگ: Android کے native کوڈ سے (کچھ سو ملی سیکنڈ)، ناکام ہو تو Dart سے
  Future<void> _compose(ProcessArgs a) async {
    try {
      final ok = await _filesCh.invokeMethod<bool>('composePhoto', {
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

  Future<void> _playSound(String kind) async {
    if (!s.sound) return;
    try {
      await _filesCh.invokeMethod('sound', kind);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  // ---------------- ویڈیو ----------------
  Uint8List? _videoStamp;

  /// موجودہ اسٹیمپ کو PNG میں بدلیں (ویڈیو کے لیے)
  Future<Uint8List?> _renderStamp(int width) async {
    try {
      _now = DateTime.now();
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _stampKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: width / boundary.size.width);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      return bd?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleRecord() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (_recording) {
      await _stopRecording();
      return;
    }
    try {
      // ریکارڈنگ شروع ہونے کے وقت کا اسٹیمپ (لوکیشن + وقت) تیار کر لیں
      _videoStamp = loc.state.value.hasFix || s.manualOn ? await _renderStamp(1600) : null;
      if (_flash == FlashMode.always) await c.setFlashMode(FlashMode.torch);
      _playSound('start');
      await c.startVideoRecording();
      _recSecs = 0;
      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSecs++);
      });
      if (mounted) setState(() => _recording = true);
    } catch (e) {
      _toast(S.t('Could not start recording: $e', 'ریکارڈنگ شروع نہیں ہو سکی: $e'));
    }
  }

  Future<void> _stopRecording() async {
    final c = _ctrl;
    if (c == null || !_recording) return;
    _recTimer?.cancel();
    if (mounted) setState(() => _recording = false);
    try {
      final f = await c.stopVideoRecording();
      _playSound('stop');
      try {
        await c.setFlashMode(_flash == FlashMode.always ? FlashMode.off : _flash);
      } catch (_) {}
      final stamp = _videoStamp;
      _videoStamp = null;
      // اسٹیمپ لگانا پس منظر میں (ویڈیو کی لمبائی کے مطابق وقت لگتا ہے)
      _pending++;
      if (mounted) setState(() {});
      final g = loc.state.value;
      final vName = s
          .buildFileName(DateTime.now(), g.lat, g.lon)
          .replaceFirst(RegExp(r'\.jpg$'), '.mp4');
      unawaited(_finishVideo(f.path, stamp, vName));
    } catch (e) {
      _toast(S.t('Error: $e', 'خرابی: $e'));
    }
  }

  Future<void> _finishVideo(String path, Uint8List? stamp, String vName) async {
    final out = '$path.stamped.mp4';
    var burned = false;
    try {
      if (stamp != null) {
        try {
          burned = (await _filesCh.invokeMethod<bool>(
                  'burnVideo', {'src': path, 'out': out, 'stamp': stamp})) ==
              true;
        } catch (_) {
          burned = false;
        }
      }
      final finalPath = burned ? out : path;
      if (PhotoStore.publicOk) {
        var dest = '${PhotoStore.rootPath}/$vName';
        var n = 1;
        while (File(dest).existsSync()) {
          dest = '${PhotoStore.rootPath}/${vName.replaceFirst('.mp4', '')}_$n.mp4';
          n++;
        }
        File(finalPath).copySync(dest);
        await PhotoStore.scan(dest);
      } else {
        if (!await Gal.hasAccess(toAlbum: true)) await Gal.requestAccess(toAlbum: true);
        await Gal.putVideo(finalPath, album: 'GPS Camera');
      }
      _toast(burned
          ? S.t('Video saved with location stamp ✓', 'ویڈیو لوکیشن اسٹیمپ کے ساتھ محفوظ ہو گئی ✓')
          : S.t('Video saved (stamp could not be added)',
              'ویڈیو محفوظ ہو گئی (اسٹیمپ نہیں لگ سکا)'));
    } catch (e) {
      _toast(S.t('Error: $e', 'خرابی: $e'));
    } finally {
      for (final p in [path, out]) {
        try {
          final f = File(p);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      _pending--;
      if (mounted) setState(() {});
    }
  }

  String _recText() {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(_recSecs ~/ 60)}:${p(_recSecs % 60)}';
  }

  void _setMode(int m) {
    if (_recording || _busy || m == _mode) return;
    setState(() => _mode = m);
    _initCamera();
  }

  Widget _modeBar({bool vertical = false}) {
    Widget tab(String label, bool sel, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFFFC400) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label,
                style: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        );
    final tabs = <Widget>[
      tab(S.t('PHOTO', 'تصویر'), _mode == 0, () => _setMode(0)),
      tab(S.t('VIDEO', 'ویڈیو'), _mode == 1, () => _setMode(1)),
      tab(S.t('REPORTS', 'رپورٹس'), false, () {
        if (_recording) return;
        _open(const ReportHomeScreen());
      }),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: vertical ? 0 : 8),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              for (final w in tabs) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: w)
            ])
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: tabs),
    );
  }

  Future<void> _askStatsConsent() async {
    if (!mounted || !AppConfig.statsReady || s.statsConsent != -1) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('Help improve GPS Camera?', 'GPS Camera کو بہتر بنانے میں مدد کریں؟')),
        content: Text(S.t(
            'Share anonymous usage info with the developer: app version, phone model and your approximate area (about 1 km). Your photos are never uploaded. You can change this anytime in Settings.',
            'ڈویلپر کے ساتھ گمنام معلومات شیئر کریں: ایپ کا ورژن، فون کا ماڈل اور آپ کا تقریبی علاقہ (تقریباً 1 کلومیٹر)۔ آپ کی تصاویر کبھی اپلوڈ نہیں ہوتیں۔ آپ سیٹنگز میں کبھی بھی بدل سکتے ہیں۔')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('No thanks', 'نہیں شکریہ'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.t('Allow', 'اجازت ہے'))),
        ],
      ),
    );
    s.update(() => s.statsConsent = ok == true ? 1 : 0);
  }

  Future<void> _loadLast() async {
    try {
      final files = await PhotoStore.allPhotos();
      if (files.isNotEmpty && mounted) setState(() => _lastPhoto = files.first.path);
    } catch (_) {}
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  Future<void> _editNote() async {
    final tc = TextEditingController(text: s.note);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('Write note / text', 'نوٹ / ٹیکسٹ لکھیں')),
        content: TextField(
          controller: tc,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Note'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('Cancel', 'منسوخ'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, tc.text), child: Text(S.t('OK', 'ٹھیک ہے'))),
        ],
      ),
    );
    if (r != null) {
      s.update(() {
        s.note = r.trim();
        if (s.note.isNotEmpty) s.showNote = true;
      });
    }
  }

  // ---------------- لوکیشن ایڈٹ ----------------
  Widget _locChip() {
    return ValueListenableBuilder<GeoState>(
      valueListenable: loc.state,
      builder: (_, g, __) {
        Color c;
        String text;
        if (g.manual) {
          c = Colors.lightBlueAccent;
          text = S.t('Manual location', 'دستی لوکیشن');
        } else if (!g.hasFix) {
          c = Colors.grey;
          text = S.t('Finding GPS...', 'GPS تلاش ہو رہی ہے...');
        } else {
          final a = g.accuracy;
          c = a <= 15 ? Colors.greenAccent : (a <= 50 ? Colors.orangeAccent : Colors.redAccent);
          text = 'GPS ±${a.round()} m';
        }
        return GestureDetector(
          onTap: _editLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(g.manual ? Icons.edit_location_alt : Icons.gps_fixed, size: 14, color: c),
              const SizedBox(width: 4),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 12, color: Colors.white70),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _editLocation() async {
    final g = loc.state.value;
    final titleC = TextEditingController(text: g.title);
    final addrC = TextEditingController(text: g.addressRest);
    final latC = TextEditingController(text: g.hasFix ? g.lat.toStringAsFixed(6) : '');
    final lonC = TextEditingController(text: g.hasFix ? g.lon.toStringAsFixed(6) : '');
    const numKb = TextInputType.numberWithOptions(signed: true, decimal: true);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('Edit location', 'لوکیشن ایڈٹ کریں')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleC,
              decoration: InputDecoration(
                labelText: S.t('Place name', 'جگہ کا نام'),
                hintText: 'GHSS Waryam Wala, Punjab, Pakistan',
              ),
            ),
            TextField(
              controller: addrC,
              maxLines: 2,
              decoration: InputDecoration(labelText: S.t('Address', 'پتہ')),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: latC,
                  keyboardType: numKb,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: lonC,
                  keyboardType: numKb,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.my_location),
              label: Text(S.t('Fill from current GPS', 'موجودہ GPS سے بھریں')),
              onPressed: () {
                final p = loc.lastPos;
                if (p == null) {
                  _toast(S.t('GPS location not available yet', 'GPS لوکیشن ابھی نہیں ملی'));
                  return;
                }
                latC.text = p.latitude.toStringAsFixed(6);
                lonC.text = p.longitude.toStringAsFixed(6);
              },
            ),
            const SizedBox(height: 6),
            Text(
              S.t('Leave place name empty to find it automatically from internet.',
                  'جگہ کا نام خالی چھوڑیں تو انٹرنیٹ سے خود نکل آئے گا۔'),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('Cancel', 'منسوخ'))),
          TextButton(
            onPressed: () {
              s.update(() => s.manualOn = false);
              loc.clearManual();
              Navigator.pop(ctx);
            },
            child: Text(S.t('Use GPS (auto)', 'GPS (خودکار)')),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latC.text.trim());
              final lon = double.tryParse(lonC.text.trim());
              if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                _toast(S.t('Enter valid Latitude and Longitude', 'درست Latitude اور Longitude لکھیں'));
                return;
              }
              s.update(() {
                s.manualOn = true;
                s.mLat = lat;
                s.mLon = lon;
                s.mTitle = titleC.text.trim();
                s.mAddress = addrC.text.trim();
              });
              loc.setManual(lat, lon, title: s.mTitle, address: s.mAddress);
              Navigator.pop(ctx);
            },
            child: Text(S.t('Save', 'محفوظ کریں')),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.of(context).orientation == Orientation.landscape;
    return ExitGuard(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: land ? _landscapeBody() : _portraitBody(),
          ),
        ),
      ),
    );
  }

  Widget _portraitBody() => Column(
        children: [
          Expanded(child: Center(child: _previewBox(false))),
          _bottomBar(),
        ],
      );

  /// فون آڑا (landscape) ہو تو: بائیں گیلری/رپورٹس/ٹیمپلیٹ، درمیان پریویو، دائیں فوٹو-ویڈیو اور شٹر
  Widget _landscapeBody() => Row(
        children: [
          SizedBox(
            width: 84,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_galleryBtn(), _reportsBtn(), _templateBtn()],
            ),
          ),
          Expanded(child: Center(child: _previewBox(true))),
          SizedBox(
            width: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modeToggle(),
                const SizedBox(height: 14),
                _shutterBtn(),
              ],
            ),
          ),
        ],
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap,
      {String? label, bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? const Color(0xFFFFC400) : Colors.white, size: 24),
          if (label != null)
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active ? const Color(0xFFFFC400) : Colors.white70)),
        ]),
      ),
    );
  }

  Widget _topBar() {
    final flashIcon = _flash == FlashMode.off
        ? Icons.flash_off
        : (_flash == FlashMode.auto ? Icons.flash_auto : Icons.flash_on);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _iconBtn(flashIcon, _cycleFlash, active: _flash != FlashMode.off),
          _iconBtn(Icons.timer_outlined, () {
            const v = [0, 3, 5, 10];
            s.update(() => s.timer = v[(v.indexOf(s.timer) + 1) % v.length]);
          }, label: s.timer == 0 ? 'Off' : '${s.timer}s', active: s.timer > 0),
          _iconBtn(Icons.aspect_ratio, () {
            s.update(() => s.ratio = (s.ratio + 1) % 4);
          }, label: AppSettings.ratioLabels[s.ratio]),
          _iconBtn(Icons.grid_on, () => s.update(() => s.grid = !s.grid), active: s.grid),
          _iconBtn(Icons.text_fields, _editNote),
          _iconBtn(Icons.cameraswitch, () {
            _front = !_front;
            _initCamera();
          }),
          _iconBtn(Icons.settings, () {
            _open(const SettingsScreen());
          }),
        ],
      ),
    );
  }

  Widget _previewBox(bool landscapeUi) {
    final c = _ctrl;
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const CircularProgressIndicator(color: Color(0xFFFFC400));
    }
    final ps = c.value.previewSize ?? const Size(1280, 720);
    final full = s.ratio == 3;
    final Widget Function(Widget) wrap = full
        ? (w) => SizedBox.expand(child: w)
        : (w) => AspectRatio(
              aspectRatio: landscapeUi ? 1 / s.ratioValue : s.ratioValue,
              child: w,
            );
    return wrap(
      ClipRect(
        child: LayoutBuilder(builder: (context, box) {
          if (full && box.maxWidth > 0 && box.maxHeight > 0) {
            final a = box.maxWidth, b = box.maxHeight;
            _fullRatio = a < b ? a / b : b / a;
          }
          return GestureDetector(
            onTapUp: (d) => _focusAt(d, box),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ValueListenableBuilder<CameraValue>(
                  valueListenable: c,
                  builder: (_, v, __) {
                    final o = v.deviceOrientation;
                    final land = o == DeviceOrientation.landscapeLeft ||
                        o == DeviceOrientation.landscapeRight;
                    return FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        // آڑا فون: چوڑائی > اونچائی، سیدھا فون: الٹ
                        width: land ? ps.width : ps.height,
                        height: land ? ps.height : ps.width,
                        child: CameraPreview(c),
                      ),
                    );
                  },
                ),
                if (s.grid) const IgnorePointer(child: CustomPaint(painter: _GridPainter())),
                // اوپر کے آئیکن (پریویو کے اوپر، کالی پٹی نہیں)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                    child: _topBar(),
                  ),
                ),
                Positioned(top: 62, left: 6, child: _locChip()),
                // زوم بٹن (دائیں کنارے پر عمودی)
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _zoomChips(vertical: true)),
                ),
                if (_pending > 0)
                  Positioned(
                    top: 94,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFFFC400)),
                        ),
                        const SizedBox(width: 6),
                        Text(S.t('Saving ($_pending)...', 'محفوظ ہو رہی ہے ($_pending)...'),
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ]),
                    ),
                  ),
                if (_mode == 1)
                  Positioned(
                    top: 62,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.fiber_manual_record,
                            size: 12, color: _recording ? Colors.red : Colors.white54),
                        const SizedBox(width: 4),
                        Text(_recording ? _recText() : S.t('VIDEO', 'ویڈیو'),
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ]),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RepaintBoundary(
                    key: _stampKey,
                    child: ValueListenableBuilder<GeoState>(
                      valueListenable: loc.state,
                      builder: (_, g, __) => StampWidget(
                        d: _stampData(g),
                        template: s.template,
                        showMap: s.showMap,
                        showLogo: s.showLogo,
                      ),
                    ),
                  ),
                ),
                if (_count > 0)
                  Center(
                    child: Text('$_count',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold)),
                  ),
                if (_busy)
                  const ColoredBox(
                    color: Colors.black45,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFFFC400))),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _zoomChips({bool vertical = false}) {
    Widget chip(String text, double z) {
      final sel = (_zoom - z).abs() < 0.25;
      return GestureDetector(
        onTap: () => _setZoom(z),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFFFC400) : Colors.black54,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(text,
              style: TextStyle(
                  color: sel ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      );
    }

    final chips = <Widget>[
      chip('1x', 1),
      if (_maxZoom >= 2) chip('2x', 2),
      if (_maxZoom >= 3) chip('3x', 3),
    ];
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: chips)
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: chips);
  }

  Widget _galleryBtn() => GestureDetector(
        onTap: () async {
          await _open(const GalleryScreen());
          _loadLast();
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white12,
              border: Border.all(color: Colors.white38),
            ),
            clipBehavior: Clip.antiAlias,
            child: (_lastPhoto != null && File(_lastPhoto!).existsSync())
                ? Image.file(File(_lastPhoto!), fit: BoxFit.cover, cacheWidth: 150)
                : const Icon(Icons.photo_library, color: Colors.white70),
          ),
          Text(S.t('Storage', 'سٹوریج'),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );

  Widget _shutterBtn() => GestureDetector(
        onTap: _capture,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            margin: EdgeInsets.all(_recording ? 14 : 0),
            decoration: BoxDecoration(
              shape: _recording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: _recording ? BorderRadius.circular(6) : null,
              color: _busy
                  ? Colors.grey
                  : (_mode == 1 ? Colors.red : const Color(0xFFFFC400)),
            ),
          ),
        ),
      );

  Widget _templateBtn() => GestureDetector(
        onTap: () => _open(TemplateScreen(
          geo: loc.state,
          build: (g) {
            _now = DateTime.now();
            return _stampData(g);
          },
        )),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.dashboard_customize, color: Colors.white, size: 34),
          const SizedBox(height: 4),
          Text(S.t('Template', 'ٹیمپلیٹ'),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );

  Widget _reportsBtn() => GestureDetector(
        onTap: () {
          if (_recording) return;
          _open(const ReportHomeScreen());
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.assignment, color: Colors.white, size: 32),
          const SizedBox(height: 4),
          Text(S.t('Reports', 'رپورٹس'),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );

  /// فوٹو / ویڈیو - چھوٹا عمودی سوئچ
  Widget _modeToggle() {
    Widget tab(String label, bool sel, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 62,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFFFC400) : Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label,
                style: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      tab(S.t('PHOTO', 'تصویر'), _mode == 0, () => _setMode(0)),
      tab(S.t('VIDEO', 'ویڈیو'), _mode == 1, () => _setMode(1)),
    ]);
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _galleryBtn(),
          _modeToggle(),
          _shutterBtn(),
          _reportsBtn(),
          _templateBtn(),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
