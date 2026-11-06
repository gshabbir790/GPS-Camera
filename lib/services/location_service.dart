import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// لوکیشن کی موجودہ حالت
class GeoState {
  final bool hasFix;
  final double lat, lon, altitude;
  final String title; // Waryam Wala, Punjab, Pakistan
  final String addressRest; // Plus Code کے بغیر باقی پتہ
  final String plusCode;
  final String flag;
  final Uint8List? tile; // سیٹلائٹ نقشے کا ٹکڑا
  final double fx, fy; // ٹکڑے کے اندر پوائنٹ کی جگہ (0..1)
  final String status; // خرابی / انتظار کا پیغام
  final double accuracy; // میٹر میں (GPS)
  final bool manual; // دستی لوکیشن

  const GeoState({
    this.hasFix = false,
    this.lat = 0,
    this.lon = 0,
    this.altitude = 0,
    this.title = '',
    this.addressRest = '',
    this.plusCode = '',
    this.flag = '',
    this.tile,
    this.fx = .5,
    this.fy = .5,
    this.status = 'searching',
    this.accuracy = 0,
    this.manual = false,
  });

  GeoState copyWith({
    bool? hasFix,
    double? lat,
    double? lon,
    double? altitude,
    String? title,
    String? addressRest,
    String? plusCode,
    String? flag,
    Uint8List? tile,
    double? fx,
    double? fy,
    String? status,
    double? accuracy,
    bool? manual,
    bool clearTile = false,
  }) =>
      GeoState(
        hasFix: hasFix ?? this.hasFix,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        altitude: altitude ?? this.altitude,
        title: title ?? this.title,
        addressRest: addressRest ?? this.addressRest,
        plusCode: plusCode ?? this.plusCode,
        flag: flag ?? this.flag,
        tile: clearTile ? null : (tile ?? this.tile),
        fx: fx ?? this.fx,
        fy: fy ?? this.fy,
        status: status ?? this.status,
        accuracy: accuracy ?? this.accuracy,
        manual: manual ?? this.manual,
      );

  /// "X793+VJ3, Waryam Wala, Punjab, Pakistan"
  String get fullAddress {
    final parts = <String>[
      if (plusCode.isNotEmpty) plusCode,
      if (addressRest.isNotEmpty) addressRest,
    ];
    return parts.join(', ');
  }

  String get latLonText {
    String f(double v) => double.parse(v.toStringAsFixed(6)).toString();
    return 'Lat ${f(lat)}° Long ${f(lon)}°';
  }
}

class LocationService {
  final ValueNotifier<GeoState> state = ValueNotifier(const GeoState());
  StreamSubscription<Position>? _sub;

  double? _gLat, _gLon;
  DateTime _lastTry = DateTime.fromMillisecondsSinceEpoch(0);
  bool _resolving = false;
  String? _tileKey;
  bool _tileBusy = false;
  Position? _lastPos;
  bool _manual = false;
  double? _lastAcc;
  DateTime _lastAccept = DateTime.fromMillisecondsSinceEpoch(0);

  Position? get lastPos => _lastPos;
  DateTime _lastTileTry = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      state.value = state.value.copyWith(status: 'gps_off');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      state.value = state.value.copyWith(status: 'no_perm');
      return;
    }
    // پرانی (cached) لوکیشن استعمال نہیں کرتے - صرف تازہ GPS فکس
    await _sub?.cancel();
    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
          )
        : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPos, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stop();
  }

  void _onPos(Position p) {
    _lastPos = p;
    // GPS کی درستگی (میٹر) ہمیشہ اپڈیٹ ہوتی ہے
    state.value = state.value.copyWith(accuracy: p.accuracy);
    if (_manual) return; // دستی لوکیشن میں GPS سے پوزیشن نہیں بدلتی

    final cur = state.value;
    final now = DateTime.now();
    if (cur.hasFix) {
      // بہت خراب (>150m) فکس نظر انداز
      if (p.accuracy > 150) return;
      // کچھ لمحے پہلے کے اچھے فکس کے مقابلے میں اچانک بہت خراب فکس نظر انداز
      if (_lastAcc != null &&
          p.accuracy > 30 &&
          p.accuracy > _lastAcc! * 2 &&
          now.difference(_lastAccept).inSeconds < 15) {
        return;
      }
    }
    _lastAcc = p.accuracy;
    _lastAccept = now;
    _apply(p.latitude, p.longitude, p.altitude);
  }

  void _apply(double lat, double lon, double alt) {
    final t = _tileCoords(lat, lon);
    state.value = state.value.copyWith(
      hasFix: true,
      lat: lat,
      lon: lon,
      altitude: alt,
      plusCode: plusCode(lat, lon),
      fx: t.fx,
      fy: t.fy,
      status: '',
    );
    _maybeResolve(lat, lon);
    _maybeTile(t);
  }

  // ---------------- دستی لوکیشن ----------------
  /// صارف کی دی ہوئی لوکیشن۔ title خالی ہو تو انٹرنیٹ سے پتہ خود نکالا جاتا ہے۔
  void setManual(double lat, double lon, {String title = '', String address = ''}) {
    _manual = true;
    final t = _tileCoords(lat, lon);
    _tileKey = null;
    _gLat = null;
    _gLon = null;
    final hasTitle = title.trim().isNotEmpty;
    state.value = state.value.copyWith(
      hasFix: true,
      manual: true,
      lat: lat,
      lon: lon,
      plusCode: plusCode(lat, lon),
      fx: t.fx,
      fy: t.fy,
      status: '',
      title: hasTitle ? title.trim() : '',
      addressRest: hasTitle
          ? (address.trim().isNotEmpty ? address.trim() : title.trim())
          : '',
      flag: '',
      clearTile: true,
    );
    _maybeTile(t);
    if (!hasTitle) {
      _lastTry = DateTime.fromMillisecondsSinceEpoch(0);
      _maybeResolve(lat, lon);
    }
  }

  /// دستی لوکیشن ختم، دوبارہ GPS
  void clearManual() {
    _manual = false;
    _gLat = null;
    _gLon = null;
    state.value = state.value.copyWith(
      manual: false,
      title: '',
      addressRest: '',
      flag: '',
      clearTile: true,
    );
    _tileKey = null;
    _lastTry = DateTime.fromMillisecondsSinceEpoch(0);
    final p = _lastPos;
    if (p != null) {
      _lastAcc = null;
      _apply(p.latitude, p.longitude, p.altitude);
    } else {
      state.value = state.value.copyWith(hasFix: false, status: 'searching');
    }
  }

  // ---------------- پتہ (Reverse Geocoding) ----------------
  void _maybeResolve(double lat, double lon) {
    if (_resolving) return;
    final now = DateTime.now();
    final haveAddr = state.value.title.isNotEmpty;
    if (haveAddr && _gLat != null) {
      final moved = Geolocator.distanceBetween(_gLat!, _gLon!, lat, lon);
      if (moved < 40) return;
    }
    if (now.difference(_lastTry).inSeconds < (haveAddr ? 8 : 20)) return;
    _lastTry = now;
    _resolve(lat, lon);
  }

  Future<void> _resolve(double lat, double lon) async {
    _resolving = true;
    try {
      String locality = '', admin = '', country = '', iso = '', street = '';
      var ok = false;
      try {
        await setLocaleIdentifier('en_US');
        final pm = await placemarkFromCoordinates(lat, lon);
        if (pm.isNotEmpty) {
          final m = pm.first;
          locality = _first([m.locality, m.subAdministrativeArea, m.subLocality]);
          admin = m.administrativeArea ?? '';
          country = m.country ?? '';
          iso = m.isoCountryCode ?? '';
          street = m.street ?? '';
          ok = locality.isNotEmpty || admin.isNotEmpty || country.isNotEmpty;
        }
      } catch (_) {}

      if (!ok) {
        final b = await _httpGet(
            'https://nominatim.openstreetmap.org/reverse?format=jsonv2&accept-language=en&lat=$lat&lon=$lon');
        if (b != null) {
          try {
            final j = jsonDecode(utf8.decode(b)) as Map<String, dynamic>;
            final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};
            locality = _first([
              a['city'], a['town'], a['village'], a['suburb'], a['county']
            ]);
            admin = (a['state'] ?? '').toString();
            country = (a['country'] ?? '').toString();
            iso = (a['country_code'] ?? '').toString().toUpperCase();
            street = (a['road'] ?? '').toString();
            ok = locality.isNotEmpty || admin.isNotEmpty || country.isNotEmpty;
          } catch (_) {}
        }
      }

      final cs = state.value;
      if (ok && Geolocator.distanceBetween(lat, lon, cs.lat, cs.lon) < 100) {
        final title = [locality, admin, country].where((e) => e.isNotEmpty).join(', ');
        final rest = [
          if (street.isNotEmpty && street != locality) street,
          locality,
          admin,
          country,
        ].where((e) => e.isNotEmpty).join(', ');
        _gLat = lat;
        _gLon = lon;
        state.value = state.value.copyWith(
          title: title,
          addressRest: rest,
          flag: _flag(iso),
        );
      }
    } finally {
      _resolving = false;
    }
  }

  static String _first(List<dynamic> list) {
    for (final e in list) {
      final s = (e ?? '').toString();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String _flag(String iso) {
    if (iso.length != 2) return '';
    final u = iso.toUpperCase().codeUnits;
    if (u.any((c) => c < 65 || c > 90)) return '';
    return String.fromCharCodes(u.map((c) => 0x1F1E6 + c - 65));
  }

  // ---------------- نقشہ (سیٹلائٹ ٹکڑا) ----------------
  static const _zoom = 17;

  ({int x, int y, double fx, double fy}) _tileCoords(double lat, double lon) {
    final n = (1 << _zoom).toDouble();
    final xf = (lon + 180) / 360 * n;
    final latRad = lat * pi / 180;
    final yf = (1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n;
    final x = xf.floor(), y = yf.floor();
    return (x: x, y: y, fx: xf - x, fy: yf - y);
  }

  void _maybeTile(({int x, int y, double fx, double fy}) t) {
    final key = '${t.x}_${t.y}';
    if (_tileBusy) return;
    if (key == _tileKey && state.value.tile != null) return;
    if (DateTime.now().difference(_lastTileTry).inSeconds < 15 &&
        state.value.tile == null &&
        _tileKey == key) {
      return;
    }
    _fetchTile(t.x, t.y, key);
  }

  Future<void> _fetchTile(int x, int y, String key) async {
    _tileBusy = true;
    _lastTileTry = DateTime.now();
    _tileKey = key;
    try {
      final b = await _httpGet(
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$_zoom/$y/$x');
      // اگر اس دوران لوکیشن بدل گئی (دستی ایڈٹ) تو پرانا ٹکڑا نظر انداز
      if (_tileKey == key && b != null && b.isNotEmpty) {
        state.value = state.value.copyWith(tile: b);
      }
    } finally {
      _tileBusy = false;
      if (_tileKey == null) {
        final s = state.value;
        if (s.hasFix) _maybeTile(_tileCoords(s.lat, s.lon));
      }
    }
  }

  static Future<Uint8List?> _httpGet(String url) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await c.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'GpsCameraPersonal/1.0');
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return await consolidateHttpClientResponseBytes(res);
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  // ---------------- Plus Code (Open Location Code) ----------------
  static String plusCode(double lat, double lon) {
    const a = '23456789CFGHJMPQRVWX';
    final latF = ((lat.clamp(-90.0, 89.999999) + 90) * 40000 + 1e-6).floor();
    final lonF = (((lon + 540) % 360) * 32000 + 1e-6).floor(); // 0..360 تک
    var lp = latF ~/ 5, lr = latF % 5;
    var gp = lonF ~/ 4, gc = lonF % 4;
    final la = List<int>.filled(5, 0), lo = List<int>.filled(5, 0);
    for (var i = 4; i >= 0; i--) {
      la[i] = lp % 20;
      lp ~/= 20;
      lo[i] = gp % 20;
      gp ~/= 20;
    }
    final sb = StringBuffer();
    for (var i = 0; i < 5; i++) {
      sb.write(a[la[i]]);
      sb.write(a[lo[i]]);
    }
    final full = sb.toString();
    // مختصر کوڈ: پہلے 4 حروف (علاقے کا کوڈ) ہٹا دیے
    return '${full.substring(4, 8)}+${full.substring(8)}${a[lr * 4 + gc]}';
  }
}
