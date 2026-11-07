import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/app_settings.dart';
import '../models/stamp_data.dart';
import '../services/location_service.dart';
import '../widgets/stamp_widget.dart';

/// ٹیمپلیٹ منتخب کریں - پریویو میں آپ کی اصل (لائیو) لوکیشن، وقت اور نقشہ نظر آتا ہے
class TemplateScreen extends StatefulWidget {
  final ValueListenable<GeoState> geo;
  final StampData Function(GeoState) build;

  const TemplateScreen({super.key, required this.geo, required this.build});

  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // وقت ہر سیکنڈ تازہ ہوتا رہے
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: Text(S.t('Template', 'ٹیمپلیٹ'))),
      body: ListenableBuilder(
        listenable: Listenable.merge([s, widget.geo]),
        builder: (context, _) {
          final g = widget.geo.value;
          final data = widget.build(g);
          return Column(children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF4CC),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Icon(g.hasFix ? Icons.gps_fixed : Icons.gps_not_fixed,
                    size: 18, color: g.hasFix ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.manual
                        ? S.t('Showing your manual location', 'آپ کی دستی لوکیشن دکھائی جا رہی ہے')
                        : (g.hasFix
                            ? S.t('Live location (GPS ±${g.accuracy.round()} m)',
                                'لائیو لوکیشن (GPS ±${g.accuracy.round()} m)')
                            : S.t('Finding GPS location...', 'GPS لوکیشن تلاش ہو رہی ہے...')),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: kTemplateCount,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final sel = s.template == i;
                  return InkWell(
                    onTap: () {
                      s.update(() => s.template = i);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7F8E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? const Color(0xFFFF8A00) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Row(children: [
                              Text(templateName(i),
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (sel) const Icon(Icons.check_circle, color: Color(0xFFFFC400)),
                            ]),
                          ),
                          StampWidget(
                            d: data,
                            template: i,
                            showMap: s.showMap,
                            showLogo: false,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
