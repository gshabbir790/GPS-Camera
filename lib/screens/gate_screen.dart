import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/strings.dart';
import '../services/net.dart';
import '../widgets/exit_guard.dart';
import 'camera_screen.dart';

/// ایپ کھلنے سے پہلے: لوکیشن (GPS) آن + اجازت + انٹرنیٹ لازمی
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> with WidgetsBindingObserver {
  bool _gps = false, _perm = false, _net = false;
  bool _checked = false, _busy = false, _asked = false, _done = false;
  bool _foreverDenied = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_busy || _done) return;
    _busy = true;
    try {
      final gps = await Geolocator.isLocationServiceEnabled();
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && !_asked) {
        _asked = true;
        p = await Geolocator.requestPermission();
      }
      final perm = p == LocationPermission.always || p == LocationPermission.whileInUse;
      final net = await hasInternet();
      if (!mounted) return;
      setState(() {
        _gps = gps;
        _perm = perm;
        _net = net;
        _foreverDenied = p == LocationPermission.deniedForever;
        _checked = true;
      });
      if (gps && perm && net) {
        _done = true;
        _timer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => const CameraScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _fixPermission() async {
    if (_foreverDenied) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.requestPermission();
      _check();
    }
  }

  Widget _tile({
    required bool ok,
    required IconData icon,
    required String title,
    required String hint,
    String? action,
    VoidCallback? onAction,
  }) {
    final color = !_checked ? Colors.white38 : (ok ? Colors.greenAccent : Colors.redAccent);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.6)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            if (!ok && _checked)
              Text(hint, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        if (ok && _checked)
          const Icon(Icons.check_circle, color: Colors.greenAccent)
        else if (action != null && _checked)
          FilledButton(onPressed: onAction, child: Text(action))
        else if (!_checked)
          const SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else
          const Icon(Icons.cancel, color: Colors.redAccent),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E0E0E), Color(0xFF2B2300)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_searching, size: 64, color: Color(0xFFFFC400)),
                  const SizedBox(height: 12),
                  Text(S.t('Before we start', 'شروع کرنے سے پہلے'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    S.t('GPS Camera needs these to work. The app opens automatically when all are ready.',
                        'GPS Camera کے لیے یہ تینوں ضروری ہیں۔ سب ٹھیک ہوتے ہی ایپ خود کھل جائے گی۔'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  _tile(
                    ok: _gps,
                    icon: Icons.gps_fixed,
                    title: S.t('Location (GPS) is ON', 'لوکیشن (GPS) آن ہے'),
                    hint: S.t('Turn on location in phone settings', 'فون کی سیٹنگ میں لوکیشن آن کریں'),
                    action: S.t('Turn on', 'آن کریں'),
                    onAction: () => Geolocator.openLocationSettings(),
                  ),
                  _tile(
                    ok: _perm,
                    icon: Icons.verified_user,
                    title: S.t('Location permission', 'لوکیشن کی اجازت'),
                    hint: _foreverDenied
                        ? S.t('Open App settings → Permissions → Location → Allow',
                            'ایپ سیٹنگ → Permissions → Location → Allow')
                        : S.t('Please allow location access', 'لوکیشن کی اجازت دیں'),
                    action: _foreverDenied ? S.t('Settings', 'سیٹنگ') : S.t('Allow', 'اجازت دیں'),
                    onAction: _fixPermission,
                  ),
                  _tile(
                    ok: _net,
                    icon: Icons.wifi,
                    title: S.t('Internet (Wi-Fi or mobile data)', 'انٹرنیٹ (Wi-Fi یا موبائل ڈیٹا)'),
                    hint: S.t('Turn on Wi-Fi or mobile data', 'Wi-Fi یا موبائل ڈیٹا آن کریں'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: Text(S.t('Check again', 'دوبارہ چیک کریں'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
