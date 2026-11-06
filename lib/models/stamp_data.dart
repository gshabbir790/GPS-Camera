import 'dart:typed_data';

/// اسٹیمپ بنانے کے لیے تمام معلومات
class StampData {
  final String title;
  final String address;
  final String latLon;
  final String dateLine; // Friday, 06/11/2026 03:17 PM GMT +05:00
  final String note;
  final String flag;
  final DateTime time;
  final double altitude;
  final double heading;
  final double magnet;
  final Uint8List? map;
  final double mapFx, mapFy;
  final String qrData;

  const StampData({
    required this.title,
    required this.address,
    required this.latLon,
    required this.dateLine,
    required this.note,
    required this.flag,
    required this.time,
    this.altitude = 0,
    this.heading = 0,
    this.magnet = 0,
    this.map,
    this.mapFx = .5,
    this.mapFy = .5,
    this.qrData = '',
  });

  static const _wd = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _mn = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  static String p2(int v) => v.toString().padLeft(2, '0');

  static String weekday(DateTime t) => _wd[t.weekday - 1];
  static String longDate(DateTime t) => '${p2(t.day)} ${_mn[t.month - 1]} ${t.year}';
  static String clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${p2(h)}:${p2(t.minute)} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// Friday, 06/11/2026 03:17 PM GMT +05:00
  static String fullLine(DateTime t) {
    final off = t.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final oh = off.inHours.abs(), om = off.inMinutes.abs() % 60;
    return '${weekday(t)}, ${p2(t.day)}/${p2(t.month)}/${t.year} ${clock(t)} GMT $sign${p2(oh)}:${p2(om)}';
  }

  static const _dirs = [
    'North', 'North East', 'East', 'South East', 'South', 'South West', 'West', 'North West'
  ];
  static const _dirShort = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  static int _idx(double h) => ((h % 360) / 45).round() % 8;
  static String dirName(double h) => _dirs[_idx(h)];
  static String dirShort(double h) => _dirShort[_idx(h)];
}
