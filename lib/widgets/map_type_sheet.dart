import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/app_settings.dart';

List<String> mapTypeNames() => [
      S.t('Normal', 'عام'),
      S.t('Satellite', 'سیٹلائٹ'),
      S.t('Terrain', 'ٹیرین'),
      S.t('Hybrid', 'ہائبرڈ'),
    ];

/// نقشے کی قسم منتخب کرنے کی شیٹ
Future<void> showMapTypeSheet(BuildContext context) {
  final s = AppSettings.instance;
  const icons = [Icons.map, Icons.satellite_alt, Icons.terrain, Icons.layers];
  const colors = [Color(0xFFBFE3C0), Color(0xFF3F6FA8), Color(0xFF8FB46A), Color(0xFF4F6B58)];
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final names = mapTypeNames();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(S.t('Map Type', 'نقشے کی قسم'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                S.t('Applies to the map on the photo stamp',
                    'یہ تصویر کے اسٹیمپ والے نقشے پر لاگو ہوگا'),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < 4; i++)
                    GestureDetector(
                      onTap: () {
                        s.update(() => s.mapType = i);
                        Navigator.pop(ctx);
                      },
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: colors[i],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: s.mapType == i ? const Color(0xFFFFC400) : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: Icon(icons[i], color: Colors.white, size: 34),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          names[i],
                          style: TextStyle(
                            fontWeight: s.mapType == i ? FontWeight.bold : FontWeight.normal,
                            color: s.mapType == i ? const Color(0xFFB88700) : Colors.black87,
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ]),
          ),
        );
      },
    ),
  );
}
