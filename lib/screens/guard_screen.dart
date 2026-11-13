import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../config/app_config.dart';
import '../l10n/strings.dart';
import '../services/remote_guard.dart';
import '../widgets/exit_guard.dart';
import 'camera_screen.dart';

enum _Phase { checking, update, license, expired, tamper, unverified }

/// ایپ کھلنے سے پہلے: غیر سرکاری APK؟ → لازمی اپڈیٹ؟ → ڈیوائس لائسنس؟
class GuardScreen extends StatefulWidget {
  const GuardScreen({super.key});

  @override
  State<GuardScreen> createState() => _GuardScreenState();
}

class _GuardScreenState extends State<GuardScreen> {
  _Phase _phase = _Phase.checking;
  RemoteConfig _cfg = const RemoteConfig();
  Map<String, String> _dev = {'id': '', 'model': '', 'android': ''};
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _go() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const CameraScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  Future<void> _run() async {
    if (mounted) setState(() => _phase = _Phase.checking);
    try {
      // 1) غیر سرکاری / بدلی ہوئی APK
      final sha = await RemoteGuard.signatureSha1();
      if (AppConfig.expectedCertSha1.isNotEmpty &&
          sha.isNotEmpty &&
          sha != AppConfig.expectedCertSha1.toUpperCase()) {
        _set(_Phase.tamper);
        return;
      }

      // 2) لازمی اپڈیٹ
      final cfg = await RemoteGuard.fetchConfig();
      if (cfg != null) {
        _cfg = cfg;
        if (cfg.minVersion.isNotEmpty && RemoteGuard.isOlder(kAppVersion, cfg.minVersion)) {
          _set(_Phase.update);
          return;
        }
      }

      // 3) ڈیوائس لائسنس
      final required = cfg?.licenseRequired ?? await RemoteGuard.cachedRequired();
      if (!required) {
        _go();
        return;
      }
      _dev = await RemoteGuard.deviceInfo();
      final lic = await RemoteGuard.checkLicense(cfg, _dev);
      switch (lic.state) {
        case LicenseState.allowed:
          _go();
          break;
        case LicenseState.trial:
          RemoteGuard.trialDaysLeft = lic.trialDaysLeft;
          _go();
          break;
        case LicenseState.denied:
          _set(_Phase.license);
          break;
        case LicenseState.expired:
          _expiry = lic.expiry;
          _set(_Phase.expired);
          break;
        case LicenseState.unverified:
          if (await RemoteGuard.withinGrace()) {
            _go();
          } else {
            _set(_Phase.unverified);
          }
          break;
      }
    } catch (_) {
      // غیر متوقع خرابی پر ایپ نہ روکیں اگر پہلے کامیاب جانچ ہو چکی ہو
      if (await RemoteGuard.withinGrace() || !(await RemoteGuard.cachedRequired())) {
        _go();
      } else {
        _set(_Phase.unverified);
      }
    }
  }

  void _set(_Phase p) {
    if (mounted) setState(() => _phase = p);
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String get _waLink {
    final msg = (_cfg.contactMessage.isNotEmpty
            ? _cfg.contactMessage
            : 'Hello, I want to activate GPS Camera on my device.') +
        '\nDevice ID: ${_dev['id']}\nModel: ${_dev['model']}';
    return 'https://wa.me/${_cfg.whatsapp}?text=${Uri.encodeComponent(msg)}';
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, {bool filled = true}) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ]);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: filled
            ? FilledButton(onPressed: onTap, child: child)
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: child,
              ),
      ),
    );
  }

  Widget _panel(IconData icon, Color color, String title, String text, List<Widget> extra) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 72, color: color),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        const SizedBox(height: 14),
        ...extra,
      ],
    );
  }

  Widget _idBox() {
    final id = _dev['id'] ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC400)),
      ),
      child: Column(children: [
        Text(S.t('Your Device ID', 'آپ کی ڈیوائس ID'),
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        SelectableText(id,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFFFC400), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: id));
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(S.t('Copied', 'کاپی ہو گیا'))));
          },
          icon: const Icon(Icons.copy, size: 16),
          label: Text(S.t('Copy', 'کاپی')),
        ),
      ]),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.checking:
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: Color(0xFFFFC400)),
          const SizedBox(height: 16),
          Text(S.t('Checking...', 'جانچ ہو رہی ہے...'),
              style: const TextStyle(color: Colors.white70)),
        ]);

      case _Phase.update:
        return _panel(
          Icons.system_update,
          const Color(0xFFFFC400),
          S.t('Update required', 'اپڈیٹ ضروری ہے'),
          _cfg.updateMessage.isNotEmpty
              ? _cfg.updateMessage
              : S.t('A new version of GPS Camera is available. Please update to continue.',
                  'GPS Camera کا نیا ورژن آ چکا ہے۔ جاری رکھنے کے لیے اپڈیٹ کریں۔'),
          [
            Text(
              S.t('Installed: $kAppVersion   •   Required: ${_cfg.minVersion}',
                  'انسٹال شدہ: $kAppVersion   •   درکار: ${_cfg.minVersion}'),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            _btn(S.t('Update now', 'ابھی اپڈیٹ کریں'), Icons.download, () => _open(_cfg.updateUrl)),
            _btn(S.t('I have updated - check again', 'اپڈیٹ کر لیا - دوبارہ چیک کریں'),
                Icons.refresh, _run, filled: false),
          ],
        );

      case _Phase.license:
      case _Phase.expired:
        final expired = _phase == _Phase.expired;
        return _panel(
          Icons.lock,
          Colors.redAccent,
          expired
              ? S.t('License expired', 'لائسنس کی مدت ختم')
              : S.t('This device is not activated', 'یہ ڈیوائس فعال نہیں ہے'),
          expired
              ? S.t('Please renew to keep using GPS Camera. Send your Device ID to the developer.',
                  'GPS Camera جاری رکھنے کے لیے تجدید کروائیں۔ اپنی ڈیوائس ID ڈویلپر کو بھیجیں۔')
              : S.t('GPS Camera works only on activated devices. Send your Device ID to the developer to get access.',
                  'GPS Camera صرف فعال شدہ ڈیوائسز پر چلتی ہے۔ رسائی کے لیے اپنی ڈیوائس ID ڈویلپر کو بھیجیں۔'),
          [
            _idBox(),
            if (_cfg.priceText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_cfg.priceText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
            if (_cfg.whatsapp.isNotEmpty)
              _btn(S.t('Buy / Activate on WhatsApp', 'WhatsApp پر خریدیں / فعال کروائیں'),
                  Icons.chat, () => _open(_waLink)),
            _btn(S.t('I am activated - check again', 'فعال ہو گیا - دوبارہ چیک کریں'),
                Icons.refresh, _run, filled: false),
          ],
        );

      case _Phase.tamper:
        return _panel(
          Icons.gpp_bad,
          Colors.redAccent,
          S.t('Unofficial copy', 'غیر سرکاری کاپی'),
          S.t('This copy of GPS Camera was modified or is not from the official developer. Please install the official app.',
              'GPS Camera کی یہ کاپی بدلی ہوئی ہے یا سرکاری ڈویلپر کی نہیں۔ براہ کرم سرکاری ایپ انسٹال کریں۔'),
          [
            if (_cfg.updateUrl.isNotEmpty)
              _btn(S.t('Get official app', 'سرکاری ایپ حاصل کریں'), Icons.download,
                  () => _open(_cfg.updateUrl)),
          ],
        );

      case _Phase.unverified:
        return _panel(
          Icons.wifi_off,
          Colors.orangeAccent,
          S.t('Could not verify license', 'لائسنس کی جانچ نہیں ہو سکی'),
          S.t('Please check your internet connection and try again.',
              'اپنا انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔'),
          [_btn(S.t('Try again', 'دوبارہ کوشش کریں'), Icons.refresh, _run)],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E0E0E), Color(0xFF2B2300)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _body(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
