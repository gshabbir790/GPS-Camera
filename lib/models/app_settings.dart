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
  int ratio = 0; // 0 = 4:3, 1 = 16:9, 2 = 1:1
  bool grid = false;
  int timer = 0; // 0, 3, 5, 10
  bool sound = true;
  bool mirror = false;

  // اسٹیمپ
  int template = 0; // 0 Advance, 1 DateTime, 2 Reporting, 3 Compass, 4 Scan
  String note = 'Captured by GPS Map Camera';
  bool showMap = true;
  bool showLogo = true;

  // فائل کا نام
  bool nameDate = true;
  bool nameCustom = true;
  String customName = 'ByGPSMapCamera';
  bool nameSeq = false;
  bool nameLatLng = false;
  int seq = 1;

  // دستی لوکیشن
  bool manualOn = false;
  double mLat = 0, mLon = 0;
  String mTitle = '', mAddress = '';

  // سٹوریج / شیئر
  bool saveGallery = true;
  bool saveOriginal = false;
  bool shareAfter = false;

  static const ratioValues = [3 / 4, 9 / 16, 1.0]; // چوڑائی / اونچائی (پورٹریٹ)
  static const ratioLabels = ['4:3', '16:9', '1:1'];
  static List<String> get qualityLabels =>
      [S.t('High', 'ہائی'), S.t('Medium', 'درمیانی'), S.t('Low', 'کم')];
  static const maxWidths = [2160, 1600, 1080];
  static const jpgQuality = [92, 85, 75];

  double get ratioValue => ratioValues[ratio];

  Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    manualOn = p.getBool('manualOn') ?? manualOn;
    mLat = p.getDouble('mLat') ?? mLat;
    mLon = p.getDouble('mLon') ?? mLon;
    mTitle = p.getString('mTitle') ?? mTitle;
    mAddress = p.getString('mAddress') ?? mAddress;
    lang = p.getString('lang') ?? lang;
    S.lang = lang;
    quality = p.getInt('quality') ?? quality;
    ratio = p.getInt('ratio') ?? ratio;
    grid = p.getBool('grid') ?? grid;
    timer = p.getInt('timer') ?? timer;
    sound = p.getBool('sound') ?? sound;
    mirror = p.getBool('mirror') ?? mirror;
    template = p.getInt('template') ?? template;
    note = p.getString('note') ?? note;
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
    await p.setBool('manualOn', manualOn);
    await p.setDouble('mLat', mLat);
    await p.setDouble('mLon', mLon);
    await p.setString('mTitle', mTitle);
    await p.setString('mAddress', mAddress);
    await p.setString('lang', lang);
    await p.setInt('quality', quality);
    await p.setInt('ratio', ratio);
    await p.setBool('grid', grid);
    await p.setInt('timer', timer);
    await p.setBool('sound', sound);
    await p.setBool('mirror', mirror);
    await p.setInt('template', template);
    await p.setString('note', note);
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
