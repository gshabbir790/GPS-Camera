import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// ڈویلپر کا اینیمیٹڈ کریڈٹ بینر (چمکتا ہوا نام + دھڑکتی سنہری روشنی)
class CreditBanner extends StatefulWidget {
  const CreditBanner({super.key});

  @override
  State<CreditBanner> createState() => _CreditBannerState();
}

class _CreditBannerState extends State<CreditBanner> with TickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();

  @override
  void dispose() {
    _loop.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _in, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .5), end: Offset.zero).animate(curved),
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final t = _loop.value;
            final glow = 0.5 + 0.5 * sin(t * 2 * pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B1B1B), Color(0xFF2E2500)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFC400).withOpacity(.55 + .35 * glow)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC400).withOpacity(.12 + .25 * glow),
                    blurRadius: 8 + 14 * glow,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16, color: Colors.white.withOpacity(.7)),
                      const SizedBox(width: 6),
                      Text(S.t('Developed by', 'تیار کردہ'),
                          style: TextStyle(
                              fontSize: 12, color: Colors.white.withOpacity(.75), letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) => LinearGradient(
                      colors: const [Color(0xFFFFC400), Colors.white, Color(0xFFFFC400)],
                      stops: [
                        (t - .25).clamp(0.0, 1.0).toDouble(),
                        t,
                        (t + .25).clamp(0.0, 1.0).toDouble(),
                      ],
                    ).createShader(rect),
                    child: Text(
                      S.t('Ghulam Shabbir', 'غلام شبیر'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.t('Principal GHSS WARYAM WALA', 'پرنسپل GHSS وریام والا'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
