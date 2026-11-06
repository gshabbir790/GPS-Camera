import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/stamp_data.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('سیٹنگز')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          children: [
            _header('کیمرہ'),
            ListTile(
              leading: const Icon(Icons.high_quality),
              title: const Text('تصویر کا معیار'),
              subtitle: const Text('کم معیار = چھوٹی فائل'),
              trailing: DropdownButton<int>(
                value: s.quality,
                underline: const SizedBox(),
                items: [
                  for (var i = 0; i < 3; i++)
                    DropdownMenuItem(value: i, child: Text(AppSettings.qualityLabels[i])),
                ],
                onChanged: (v) => s.update(() => s.quality = v ?? 0),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio),
              title: const Text('ریشو'),
              trailing: DropdownButton<int>(
                value: s.ratio,
                underline: const SizedBox(),
                items: [
                  for (var i = 0; i < 3; i++)
                    DropdownMenuItem(value: i, child: Text(AppSettings.ratioLabels[i])),
                ],
                onChanged: (v) => s.update(() => s.ratio = v ?? 0),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.grid_on),
              title: const Text('گرڈ'),
              value: s.grid,
              onChanged: (v) => s.update(() => s.grid = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: const Text('کیمرے کی آواز'),
              value: s.sound,
              onChanged: (v) => s.update(() => s.sound = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.flip),
              title: const Text('مرر (Mirror)'),
              subtitle: const Text('تصویر الٹی (شیشے کی طرح) محفوظ ہو'),
              value: s.mirror,
              onChanged: (v) => s.update(() => s.mirror = v),
            ),
            _header('اسٹیمپ'),
            SwitchListTile(
              secondary: const Icon(Icons.map),
              title: const Text('نقشہ دکھائیں'),
              subtitle: const Text('سیٹلائٹ نقشہ (انٹرنیٹ درکار)'),
              value: s.showMap,
              onChanged: (v) => s.update(() => s.showMap = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.photo_camera),
              title: const Text('ایپ کا لوگو دکھائیں'),
              value: s.showLogo,
              onChanged: (v) => s.update(() => s.showLogo = v),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('نوٹ (اسٹیمپ پر لکھا جانے والا متن)'),
              subtitle: Text(s.note.isEmpty ? '—' : s.note),
              onTap: () => _editText(context, 'نوٹ', s.note, (v) => s.update(() => s.note = v)),
            ),
            _header('فائل کا نام'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(s.buildFileName(DateTime.now(), 30.969637, 72.25404),
                      style: const TextStyle(fontSize: 15)),
                ),
              ),
            ),
            CheckboxListTile(
              title: const Text('تاریخ اور وقت'),
              value: s.nameDate,
              onChanged: (v) => s.update(() => s.nameDate = v ?? true),
            ),
            CheckboxListTile(
              title: const Text('سیریل نمبر'),
              value: s.nameSeq,
              onChanged: (v) => s.update(() => s.nameSeq = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Latitude / Longitude'),
              value: s.nameLatLng,
              onChanged: (v) => s.update(() => s.nameLatLng = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('اپنا نام'),
              subtitle: Text(s.customName),
              value: s.nameCustom,
              onChanged: (v) => s.update(() => s.nameCustom = v ?? true),
              secondary: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editText(
                    context, 'فائل کے نام میں اپنا نام', s.customName,
                    (v) => s.update(() => s.customName = v)),
              ),
            ),
            _header('سٹوریج اور شیئر'),
            SwitchListTile(
              secondary: const Icon(Icons.photo_library),
              title: const Text('گیلری میں بھی محفوظ کریں'),
              subtitle: const Text('البم: GPS Camera'),
              value: s.saveGallery,
              onChanged: (v) => s.update(() => s.saveGallery = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.image),
              title: const Text('اصل تصویر بھی محفوظ کریں'),
              subtitle: const Text('اسٹیمپ کے بغیر دوسری تصویر (گیلری میں)'),
              value: s.saveOriginal,
              onChanged: (v) => s.update(() => s.saveOriginal = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.share),
              title: const Text('ہر تصویر کے بعد شیئر کھولیں'),
              value: s.shareAfter,
              onChanged: (v) => s.update(() => s.shareAfter = v),
            ),
            const SizedBox(height: 24),
            const Center(child: Text('GPS Camera 1.0.0', style: TextStyle(color: Colors.black45))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Text(t,
            style: const TextStyle(
                color: Color(0xFFB88700), fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Future<void> _editText(
      BuildContext context, String title, String initial, ValueChanged<String> onSave) async {
    final tc = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: tc, autofocus: true, maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('منسوخ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, tc.text), child: const Text('ٹھیک ہے')),
        ],
      ),
    );
    if (r != null) onSave(r.trim());
  }
}
