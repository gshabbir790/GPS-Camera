import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/photo_meta.dart';

const kNavy = Color(0xFF1A1F4D);
const kYellow = Color(0xFFFFC400);

/// رپورٹ کا فریم: تاریخ، عنوان، پیلی لکیر، باڈی، فوٹر
class ReportFrame extends StatelessWidget {
  final String title;
  final bool showDate;
  final Widget? summary;
  final Widget body;
  final String footer;

  const ReportFrame({
    super.key,
    required this.title,
    required this.showDate,
    required this.body,
    this.summary,
    this.footer = '',
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF3FF), Colors.white, Color(0xFFFFF7DC)],
          ),
          border: Border.symmetric(vertical: BorderSide(color: kYellow, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate)
              Align(
                alignment: Alignment.centerRight,
                child: Text(fmtDateTime(DateTime.now()),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: kNavy)),
              ),
            const SizedBox(height: 6),
            Center(
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: kNavy)),
            ),
            const SizedBox(height: 6),
            Container(height: 2.5, color: kYellow),
            const SizedBox(height: 10),
            if (summary != null) ...[summary!, const SizedBox(height: 8)],
            body,
            if (footer.isNotEmpty) ...[
              const SizedBox(height: 14),
              Center(
                child: Text(footer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Open in Google Maps" لنک
class MapsLink extends StatelessWidget {
  final PhotoMeta meta;
  const MapsLink(this.meta, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final ok = await openMaps(meta.lat, meta.lon);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(S.t('Could not open Google Maps', 'گوگل میپس نہیں کھل سکا'))));
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          S.t('Open in Google Maps', 'گوگل میپس میں کھولیں'),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF0B57D0),
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF0B57D0),
          ),
        ),
      ),
    );
  }
}

/// کٹی ہوئی لکیر والا خانہ (Tap to add)
class DashedRRect extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  const DashedRRect({
    super.key,
    required this.child,
    this.radius = 16,
    this.color = const Color(0xFFBDBDBD),
  });

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashPainter(radius, color), child: child);
}

class _DashPainter extends CustomPainter {
  final double radius;
  final Color color;
  _DashPainter(this.radius, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => false;
}

/// نیچے کی چار کارروائیاں
class ReportActionBar extends StatelessWidget {
  final void Function(int index) onTap; // 0 photo, 1 pdf, 2 share, 3 whatsapp
  final bool busy;
  const ReportActionBar({super.key, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData icon, Color c, String label) => Expanded(
          child: InkWell(
            onTap: busy ? null : () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: busy ? Colors.grey : c,
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 13, color: kNavy)),
              ]),
            ),
          ),
        );

    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [
            Row(children: [
              item(0, Icons.add_photo_alternate, const Color(0xFF1565F0),
                  S.t('Save Photo', 'فوٹو محفوظ')),
              item(1, Icons.picture_as_pdf, const Color(0xFFE53935),
                  S.t('Save PDF', 'PDF محفوظ')),
              item(2, Icons.share, kNavy, S.t('Share', 'شیئر')),
              item(3, Icons.chat, const Color(0xFF25D366), S.t('WhatsApp', 'واٹس ایپ')),
            ]),
            if (busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66FFFFFF),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
