import 'package:flutter/material.dart';
import '../l10n/strings.dart';

import '../models/app_settings.dart';
import '../models/stamp_data.dart';
import '../widgets/stamp_widget.dart';

/// ٹیمپلیٹ منتخب کرنے کی اسکرین (نمونہ ڈیٹا کے ساتھ)
class TemplateScreen extends StatelessWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final now = DateTime.now();
    final sample = StampData(
      title: 'Waryam Wala, Punjab, Pakistan',
      address: 'X793+VJ3, Waryam Wala, Punjab, Pakistan',
      latLon: 'Lat 30.969637° Long 72.25404°',
      dateLine: StampData.fullLine(now),
      note: s.note,
      flag: '🇵🇰',
      time: now,
      altitude: 149,
      heading: 56,
      magnet: 22.46,
      qrData: 'https://maps.google.com/?q=30.969637,72.25404',
    );

    return Scaffold(
      appBar: AppBar(title: Text(S.t('Template', 'ٹیمپلیٹ'))),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView.separated(
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
                      d: sample,
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
    );
  }
}
