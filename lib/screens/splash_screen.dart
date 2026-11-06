import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../widgets/credit_banner.dart';
import 'gate_screen.dart';

/// شروع کی اسپلیش اسکرین (اینیمیشن کے ساتھ)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final AnimationController _bar =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const GateScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logo.dispose();
    _pulse.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _logo, curve: Curves.elasticOut);
    final fade = CurvedAnimation(parent: _logo, curve: const Interval(.4, 1, curve: Curves.easeOut));
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E0E0E), Color(0xFF2B2300)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(alignment: Alignment.center, children: [
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) => CustomPaint(
                              size: const Size(220, 220),
                              painter: _RingPainter(_pulse.value),
                            ),
                          ),
                          ScaleTransition(
                            scale: scale,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC400),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x66FFC400), blurRadius: 30, spreadRadius: 2),
                                ],
                              ),
                              child: const Stack(alignment: Alignment.center, children: [
                                Icon(Icons.photo_camera, size: 70, color: Color(0xFF1E1E1E)),
                                Positioned(
                                  bottom: 22,
                                  child: Icon(Icons.location_on, size: 34, color: Color(0xFFD32F2F)),
                                ),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: fade,
                        child: Column(children: [
                          const Text('GPS Camera',
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 6),
                          Text(S.t('Geotag every photo', 'ہر تصویر پر لوکیشن'),
                              style: const TextStyle(fontSize: 15, color: Colors.white70)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const CreditBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 8, 48, 20),
                child: AnimatedBuilder(
                  animation: _bar,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _bar.value,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFFFFC400),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = 60 + 50 * p;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFC400).withOpacity((1 - p) * .5),
      );
    }
    // گھومتی ہوئی چھوٹی نقطہ
    final a = t * 2 * pi;
    canvas.drawCircle(
      c + Offset(cos(a) * 100, sin(a) * 100),
      4,
      Paint()..color = const Color(0xFFFFC400),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}
