import 'dart:async';
import 'dart:io';
import 'dart:math';
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
import 'gallery_screen.dart';
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
  int _appliedQuality = 0;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appliedQuality = s.quality;
    s.addListener(_onSettings);
    loc.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_busy) setState(() => _now = DateTime.now());
    });
    _initCamera();
    _syncSensors();
    _loadLast();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.removeListener(_onSettings);
    _tick?.cancel();
    _accSub?.cancel();
    _magSub?.cancel();
    loc.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.inactive || st == AppLifecycleState.paused) {
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
    if (s.quality != _appliedQuality) {
      _appliedQuality = s.quality;
      _initCamera();
    }
    _syncSensors();
    if (mounted) setState(() {});
  }

  // ---------------- کیمرہ ----------------
  Future<void> _initCamera() async {
    try {
      if (_cams.isEmpty) _cams = await availableCameras();
      if (_cams.isEmpty) {
        if (mounted) setState(() => _error = S.t('No camera found on this phone', 'اس فون پر کیمرہ نہیں ملا'));
        return;
      }
      final dir = _front ? CameraLensDirection.front : CameraLensDirection.back;
      final desc = _cams.firstWhere((c) => c.lensDirection == dir, orElse: () => _cams.first);
      final preset = [
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
        enableAudio: false,
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
      note: s.note,
      flag: g.flag,
      time: _now,
      altitude: g.altitude,
      heading: _heading,
      magnet: _magnet,
      map: g.tile,
      mapFx: g.fx,
      mapFy: g.fy,
      qrData: hasFix ? 'https://maps.google.com/?q=${g.lat},${g.lon}' : '',
    );
  }

  // ---------------- تصویر لینا ----------------
  Future<void> _capture() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || _busy) return;

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
    try {
      if (s.sound) SystemSound.play(SystemSoundType.click);
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
      final docs = await getApplicationDocumentsDirectory();
      final photos = Directory('${docs.path}/photos');
      if (!photos.existsSync()) photos.createSync(recursive: true);

      var name = s.buildFileName(_now, g.lat, g.lon);
      var outPath = '${photos.path}/$name';
      var n = 1;
      while (File(outPath).existsSync()) {
        final base = name.substring(0, name.length - 4);
        outPath = '${photos.path}/${base}_$n.jpg';
        n++;
      }

      await compute(
        processPhoto,
        ProcessArgs(
          srcPath: srcPath,
          outPath: outPath,
          stampPng: stampPng,
          ratio: s.ratioValue,
          maxWidth: maxW,
          jpgQuality: AppSettings.jpgQuality[s.quality],
          mirror: s.mirror,
        ),
      );

      if (s.saveGallery) {
        try {
          if (!await Gal.hasAccess(toAlbum: true)) {
            await Gal.requestAccess(toAlbum: true);
          }
          await Gal.putImage(outPath, album: 'GPS Camera');
          if (s.saveOriginal) await Gal.putImage(srcPath, album: 'GPS Camera');
        } catch (_) {
          _toast(S.t('Could not save to gallery - check permission', 'گیلری میں محفوظ نہیں ہو سکی - اجازت چیک کریں'));
        }
      }

      s.update(() => s.seq++);
      if (mounted) setState(() => _lastPhoto = outPath);
      _toast(S.t('Photo saved ✓', 'تصویر محفوظ ہو گئی ✓'));

      if (s.shareAfter) {
        await Share.shareXFiles([XFile(outPath)]);
      }
    } catch (e) {
      _toast(S.t('Error: $e', 'خرابی: $e'));
    } finally {
      if (srcPath != null && !s.saveOriginal) {
        try {
          File(srcPath).deleteSync();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadLast() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/photos');
      if (!dir.existsSync()) return;
      final files = dir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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
    if (r != null) s.update(() => s.note = r.trim());
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              _topBar(),
              Expanded(child: Center(child: _previewBox())),
              _zoomChips(),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

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
            s.update(() => s.ratio = (s.ratio + 1) % 3);
          }, label: AppSettings.ratioLabels[s.ratio]),
          _iconBtn(Icons.grid_on, () => s.update(() => s.grid = !s.grid), active: s.grid),
          _iconBtn(Icons.text_fields, _editNote),
          _iconBtn(Icons.cameraswitch, () {
            _front = !_front;
            _initCamera();
          }),
          _iconBtn(Icons.settings, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _previewBox() {
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
    return AspectRatio(
      aspectRatio: s.ratioValue,
      child: ClipRect(
        child: LayoutBuilder(builder: (context, box) {
          return GestureDetector(
            onTapUp: (d) => _focusAt(d, box),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: ps.height, // پورٹریٹ میں چوڑائی/اونچائی الٹ جاتی ہے
                    height: ps.width,
                    child: CameraPreview(c),
                  ),
                ),
                if (s.grid) const IgnorePointer(child: CustomPaint(painter: _GridPainter())),
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

  Widget _zoomChips() {
    Widget chip(String t, double z) {
      final sel = (_zoom - z).abs() < 0.25;
      return GestureDetector(
        onTap: () => _setZoom(z),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFFFC400) : Colors.white12,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(t,
              style: TextStyle(
                  color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      chip('1x', 1),
      if (_maxZoom >= 2) chip('2x', 2),
      if (_maxZoom >= 3) chip('3x', 3),
    ]);
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // گیلری / سٹوریج
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const GalleryScreen()));
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
              Text(S.t('Storage', 'سٹوریج'), style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          // شٹر
          GestureDetector(
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _busy ? Colors.grey : const Color(0xFFFFC400),
                ),
              ),
            ),
          ),
          // ٹیمپلیٹ
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const TemplateScreen())),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.dashboard_customize, color: Colors.white, size: 34),
              const SizedBox(height: 4),
              Text(S.t('Template', 'ٹیمپلیٹ'), style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
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
