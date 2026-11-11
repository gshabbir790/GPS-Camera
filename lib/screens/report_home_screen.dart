import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../widgets/ad_banner.dart';
import '../widgets/report_widgets.dart';
import 'before_after_screen.dart';
import 'photo_report_screen.dart';

class ReportHomeScreen extends StatelessWidget {
  const ReportHomeScreen({super.key});

  Widget _card(BuildContext context, IconData icon, Color color, String title, String sub, Widget page) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kYellow, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(title: Text(S.t('Reports', 'رپورٹس'))),
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        _card(
          context,
          Icons.photo_library,
          const Color(0xFF1565F0),
          S.t('Photo Report', 'فوٹو رپورٹ'),
          S.t('Photos with date, time and Open in Google Maps link',
              'تصاویر کے ساتھ تاریخ، وقت اور گوگل میپس لنک'),
          const PhotoReportScreen(),
        ),
        _card(
          context,
          Icons.compare,
          const Color(0xFFE84545),
          S.t('Before / After Report', 'Before / After رپورٹ'),
          S.t('Compare work before and after, with descriptions',
              'کام سے پہلے اور بعد کا موازنہ، تفصیل کے ساتھ'),
          const BeforeAfterScreen(),
        ),
        const SizedBox(height: 8),
        Text(
          S.t('Reports use photos saved in the app Storage. Save PDF puts the file in Downloads/GPS Camera.',
              'رپورٹ میں ایپ کے سٹوریج کی تصاویر استعمال ہوتی ہیں۔ Save PDF فائل Downloads/GPS Camera میں رکھتا ہے۔'),
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ]),
    );
  }
}
