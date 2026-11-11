import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';

/// ایپ کی تمام سیٹنگز (فون میں محفوظ رہتی ہیں)
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  SharedPreferences? _p;

  String lang = 'en'; // 'en' یا 'ur'

  // کیمرہ
  int quality = 0; // 0 High, 1 Medium, 2 Low
  int ratio = 1; // 0 = 4:3, 1 = 16:9 (9:16 پوری اسکرین)، 2 = 1:1، 3 = Full
  bool grid = false;
  int timer = 0; // 0, 3, 5, 10
  bool sound = true;
  bool mirror = false;

  // اسٹیمپ
  int template = 0; // 0 Advance, 1 DateTime, 2 Reporting, 3 Compass, 4 Scan
  String note = 'GPS Camera';
  bool showNote = true;
  bool showMap = true;
  bool showLogo = true;

  // فائل کا نام
  bool nameDate = true;
  bool nameCustom = true;
  String customName = 'ByGPSMapCamera';
  bool nameSeq = false;
  bool nameLatLng = false;
  int seq = 1;

  // نقشہ / والیوم بٹن / ویڈیو / رپورٹ
  int mapType = 1; // 0 Normal, 1 Satellite, 2 Terrain, 3 Hybrid
  int volumeAction = 0; // 0 Photo Capture, 1 Volume, 2 Zoom
  int videoQuality = 0; // 0 HD, 1 Full HD, 2 4K
  String rpTitle = 'Photo Report';
  String rpTitleBA = 'Before / After Report';
  String rpFooter = '';
  bool rpShowDate = true;
  bool rpShowLinks = true;

  // استعمال کی معلومات
  int statsConsent = -1; // -1 نہیں پوچھا، 0 نہیں، 1 ہاں
  String installId = '';
  String firstSeen = '';

  // دستی لوکیشن
  bool manualOn = false;
  double mLat = 0, mLon = 0;
  String mTitle = '', mAddress = '';

  // سٹوریج / شیئر
  bool saveGallery = true;
  bool saveOriginal = false;
  bool shareAfter = false;

  static List<String> get videoLabels => ['HD 720p', 'Full HD 1080p', '4K'];
  static List<String> get volumeLabels => [
        S.t('Photo Capture', 'تصویر لینا'),
        S.t('Volume', 'آواز'),
        S.t('Zoom', 'زوم'),
      ];

  static const ratioValues = [3 / 4, 9 / 16, 1.0]; // چوڑائی / اونچائی (پورٹریٹ)
  static const ratioLabels = ['4:3', '16:9', '1:1', 'Full'];
  static List<String> get qualityLabels =>
      [S.t('High', 'ہائی'), S.t('Medium', 'درمیانی'), S.t('Low', 'کم')];
  static const maxWidths = [2160, 1600, 1080];
  static const jpgQuality = [92, 85, 75];

  double get ratioValue => ratio < ratioValues.length ? ratioValues[ratio] : 0.5; // 3 = Full (پوری اسکرین)

  Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    mapType = p.getInt('mapType') ?? mapType;
    volumeAction = p.getInt('volumeAction') ?? volumeAction;
    videoQuality = p.getInt('videoQuality') ?? videoQuality;
    rpTitle = p.getString('rpTitle') ?? rpTitle;
    rpTitleBA = p.getString('rpTitleBA') ?? rpTitleBA;
    rpFooter = p.getString('rpFooter') ?? rpFooter;
    rpShowDate = p.getBool('rpShowDate') ?? rpShowDate;
    rpShowLinks = p.getBool('rpShowLinks') ?? rpShowLinks;
    manualOn = p.getBool('manualOn') ?? manualOn;
    mLat = p.getDouble('mLat') ?? mLat;
    mLon = p.getDouble('mLon') ?? mLon;
    mTitle = p.getString('mTitle') ?? mTitle;
    mAddress = p.getString('mAddress') ?? mAddress;
    statsConsent = p.getInt('statsConsent') ?? statsConsent;
    installId = p.getString('installId') ?? '';
    firstSeen = p.getString('firstSeen') ?? '';
    if (installId.isEmpty) {
      final r = Random.secure();
      installId = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      firstSeen = DateTime.now().toUtc().toIso8601String();
    }
    lang = p.getString('lang') ?? lang;
    S.lang = lang;
    quality = p.getInt('quality') ?? quality;
    // ورژن 2.7.9: ڈیفالٹ ریشو 9:16 (پوری اسکرین) - پرانی سیٹنگ ایک بار بدلی جائے گی
    if ((p.getInt('prefsVersion') ?? 0) < 279) {
      ratio = 1;
      await p.setInt('prefsVersion', 279);
    } else {
      ratio = p.getInt('ratio') ?? ratio;
    }
    grid = p.getBool('grid') ?? grid;
    timer = p.getInt('timer') ?? timer;
    sound = p.getBool('sound') ?? sound;
    mirror = p.getBool('mirror') ?? mirror;
    template = p.getInt('template') ?? template;
    note = p.getString('note') ?? note;
    if (note == 'Captured by GPS Map Camera') note = 'GPS Camera'; // پرانا ڈیفالٹ
    showNote = p.getBool('showNote') ?? showNote;
    showMap = p.getBool('showMap') ?? showMap;
    showLogo = p.getBool('showLogo') ?? showLogo;
    nameDate = p.getBool('nameDate') ?? nameDate;
    nameCustom = p.getBool('nameCustom') ?? nameCustom;
    customName = p.getString('customName') ?? customName;
    nameSeq = p.getBool('nameSeq') ?? nameSeq;
    nameLatLng = p.getBool('nameLatLng') ?? nameLatLng;
    seq = p.getInt('seq') ?? seq;
    saveGallery = p.getBool('saveGallery') ?? saveGallery;
    saveOriginal = p.getBool('saveOriginal') ?? saveOriginal;
    shareAfter = p.getBool('shareAfter') ?? shareAfter;
  }

  /// کوئی بھی سیٹنگ بدلنے کے لیے: s.update(() => s.grid = true);
  void update(VoidCallback change) {
    change();
    S.lang = lang;
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _p;
    if (p == null) return;
    await p.setInt('mapType', mapType);
    await p.setInt('volumeAction', volumeAction);
    await p.setInt('videoQuality', videoQuality);
    await p.setString('rpTitle', rpTitle);
    await p.setString('rpTitleBA', rpTitleBA);
    await p.setString('rpFooter', rpFooter);
    await p.setBool('rpShowDate', rpShowDate);
    await p.setBool('rpShowLinks', rpShowLinks);
    await p.setBool('manualOn', manualOn);
    await p.setDouble('mLat', mLat);
    await p.setDouble('mLon', mLon);
    await p.setString('mTitle', mTitle);
    await p.setString('mAddress', mAddress);
    await p.setString('lang', lang);
    await p.setInt('statsConsent', statsConsent);
    await p.setString('installId', installId);
    await p.setString('firstSeen', firstSeen);
    await p.setInt('quality', quality);
    await p.setInt('ratio', ratio);
    await p.setBool('grid', grid);
    await p.setInt('timer', timer);
    await p.setBool('sound', sound);
    await p.setBool('mirror', mirror);
    await p.setInt('template', template);
    await p.setString('note', note);
    await p.setBool('showNote', showNote);
    await p.setBool('showMap', showMap);
    await p.setBool('showLogo', showLogo);
    await p.setBool('nameDate', nameDate);
    await p.setBool('nameCustom', nameCustom);
    await p.setString('customName', customName);
    await p.setBool('nameSeq', nameSeq);
    await p.setBool('nameLatLng', nameLatLng);
    await p.setInt('seq', seq);
    await p.setBool('saveGallery', saveGallery);
    await p.setBool('saveOriginal', saveOriginal);
    await p.setBool('shareAfter', shareAfter);
  }

  /// فائل کا نام، مثلاً 20261106_31743PM_ByGPSMapCamera.jpg
  String buildFileName(DateTime t, double lat, double lon) {
    String p2(int v) => v.toString().padLeft(2, '0');
    final parts = <String>[];
    if (nameDate) {
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      parts.add('${t.year}${p2(t.month)}${p2(t.day)}_$h${p2(t.minute)}${p2(t.second)}${t.hour >= 12 ? 'PM' : 'AM'}');
    }
    if (nameSeq) parts.add(seq.toString().padLeft(4, '0'));
    if (nameLatLng) parts.add('${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}');
    final c = customName.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-\u0600-\u06FF ]'), '').replaceAll(' ', '_');
    if (nameCustom && c.isNotEmpty) parts.add(c);
    if (parts.isEmpty) parts.add('IMG');
    return '${parts.join('_')}.jpg';
  }
}
