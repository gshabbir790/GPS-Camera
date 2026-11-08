import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/strings.dart';
import '../models/stamp_data.dart';

String templateName(int i) => [
      S.t('Advance Template', 'ایڈوانس ٹیمپلیٹ'),
      S.t('DateTime Template', 'تاریخ و وقت ٹیمپلیٹ'),
      S.t('Reporting Template', 'رپورٹنگ ٹیمپلیٹ'),
      S.t('Compass Template', 'کمپاس ٹیمپلیٹ'),
      S.t('Scan Location Template', 'اسکین لوکیشن ٹیمپلیٹ'),
    ][i];

const kTemplateCount = 5;

/// تصویر کے نیچے لگنے والا اسٹیمپ۔ پریویو اور اصل تصویر دونوں میں یہی ویجٹ استعمال ہوتا ہے۔
class StampWidget extends StatelessWidget {
  final StampData d;
  final int template;
  final bool showMap;
  final bool showLogo;

  const StampWidget({
    super.key,
    required this.d,
    required this.template,
    this.showMap = true,
    this.showLogo = true,
  });

  static const _bg = Color.fromRGBO(0, 0, 0, .58);
  static const _white = TextStyle(color: Colors.white, height: 1.25);

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (template) {
      case 1:
        body = _dateTime();
        break;
      case 2:
        body = _reporting();
        break;
      case 3:
        body = _compass();
        break;
      case 4:
        body = _scan();
        break;
      default:
        body = _advance();
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: _white.copyWith(decoration: TextDecoration.none),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLogo) _logo(),
              body,
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset('assets/icon/icon.png', width: 18, height: 18, fit: BoxFit.cover),
            ),
            const SizedBox(width: 5),
            const Text('GPS Camera',
                style: TextStyle(
                    fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ---------- مشترک حصے ----------
  Widget _titleRow(double size) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: d.title.isEmpty ? 'Location' : d.title,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w500)),
          if (d.flag.isNotEmpty) TextSpan(text: ' ${d.flag}', style: TextStyle(fontSize: size)),
        ]),
      );

  Widget _lines({double size = 11}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.address.isNotEmpty) Text(d.address, style: TextStyle(fontSize: size)),
          Text(d.latLon, style: TextStyle(fontSize: size)),
          Text(d.dateLine, style: TextStyle(fontSize: size)),
          if (d.note.isNotEmpty) Text('Note : ${d.note}', style: TextStyle(fontSize: size)),
        ],
      );

  Widget _map(double size, {bool stretch = false}) {
    if (!showMap) return const SizedBox.shrink();
    return Container(
      width: size,
      height: stretch ? null : size,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: d.map == null
          ? const Icon(Icons.map_outlined, color: Colors.white38)
          : Stack(fit: StackFit.expand, children: [
              Image.memory(d.map!, fit: BoxFit.cover, gaplessPlayback: true),
              if (d.mapOverlay != null)
                Image.memory(d.mapOverlay!, fit: BoxFit.cover, gaplessPlayback: true),
              Align(
                alignment: Alignment(d.mapFx * 2 - 1, d.mapFy * 2 - 1 - .12),
                child: const Icon(Icons.location_on, color: Colors.red, size: 26),
              ),
            ]),
    );
  }

  Widget _box({required Widget child, EdgeInsets pad = const EdgeInsets.all(8)}) =>
      Container(
        padding: pad,
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(3)),
        child: child,
      );

  // ---------- 1) ایڈوانس ----------
  // نقشہ متن والے خانے کے برابر اونچا (خود پھیل جاتا ہے)
  Widget _advance() => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _map(92, stretch: true),
            Expanded(
              child: _box(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [_titleRow(18), const SizedBox(height: 2), _lines(size: 10.5)],
                ),
              ),
            ),
          ],
        ),
      );

  // ---------- 2) تاریخ و وقت ----------
  Widget _dateTime() => _box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(StampData.clock(d.time),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
              Container(
                  width: 2,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFFFFC400)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(StampData.longDate(d.time),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(StampData.weekday(d.time),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 4),
            _titleRow(16),
            if (d.address.isNotEmpty) Text(d.address, style: const TextStyle(fontSize: 11)),
            Text(d.latLon, style: const TextStyle(fontSize: 11)),
            if (d.note.isNotEmpty) Text('Note : ${d.note}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      );

  // ---------- 3) رپورٹنگ ----------
  Widget _reporting() => _box(
        pad: const EdgeInsets.all(5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              padding: const EdgeInsets.symmetric(vertical: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(3)),
              child: const Text('Check In', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(height: 3),
            if (showMap) _map(88) else const SizedBox(width: 88),
          ]),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [_titleRow(18), const SizedBox(height: 2), _lines(size: 10.5)],
            ),
          ),
        ]),
      );

  // ---------- 4) کمپاس ----------
  Widget _compass() => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _box(
          pad: const EdgeInsets.all(6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 104,
              height: 104,
              child: CustomPaint(painter: _DialPainter(d.heading)),
            ),
            const SizedBox(height: 4),
            Text('Facing ${StampData.dirName(d.heading)}',
                style: const TextStyle(fontSize: 10)),
          ]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _titleRow(16),
                const SizedBox(height: 2),
                _lines(size: 10),
                Text('Azimuth/Bearing : ${d.heading.toStringAsFixed(2)}°',
                    style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.terrain, size: 14, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text('${d.altitude.round()} m', style: const TextStyle(fontSize: 11)),
                  const Spacer(),
                  const Icon(Icons.explore, size: 14, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text('${d.magnet.toStringAsFixed(2)} µT',
                      style: const TextStyle(fontSize: 11)),
                ]),
              ],
            ),
          ),
        ),
      ]);

  // ---------- 5) اسکین لوکیشن (QR) ----------
  Widget _scan() => _box(
        pad: const EdgeInsets.all(5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (showMap) _map(78),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [_titleRow(15), const SizedBox(height: 2), _lines(size: 9.5)],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(3),
            child: QrImageView(
              data: d.qrData.isEmpty ? 'https://maps.google.com' : d.qrData,
              size: 74,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ),
        ]),
      );
}

class _DialPainter extends CustomPainter {
  final double heading;
  _DialPainter(this.heading);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0x33FFFFFF));

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * pi / 180);

    final tick = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;
    for (var i = 0; i < 36; i++) {
      final a = i * 10 * pi / 180;
      final len = i % 9 == 0 ? 0.0 : (i % 3 == 0 ? 7.0 : 4.0);
      if (len == 0) continue;
      canvas.drawLine(
        Offset(sin(a) * (r - 2), -cos(a) * (r - 2)),
        Offset(sin(a) * (r - 2 - len), -cos(a) * (r - 2 - len)),
        tick,
      );
    }
    const labels = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * pi / 2);
      canvas.translate(0, -(r - 14));
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: i == 0 ? Colors.redAccent : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    canvas.restore();

    // اوپر کا نشان
    canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, 9),
        Paint()..color = Colors.white..strokeWidth = 2);

    final tp = TextPainter(
      text: TextSpan(
        text: '${heading.round()}° ${StampData.dirShort(heading)}',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.heading != heading;
}
