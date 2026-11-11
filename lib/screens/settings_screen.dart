import 'package:flutter/material.dart';
import '../app_info.dart';
import '../config/app_config.dart';
import '../l10n/strings.dart';

import '../models/app_settings.dart';
import '../models/stamp_data.dart';
import '../widgets/ad_banner.dart';
import '../widgets/credit_banner.dart';
import '../widgets/map_type_sheet.dart';
import 'report_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: Text(S.t('Settings', 'سیٹنگز'))),
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          children: [
            _header(S.t('Language', 'زبان')),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(S.t('App language', 'ایپ کی زبان')),
              trailing: DropdownButton<String>(
                value: s.lang,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ur', child: Text('اردو')),
                ],
                onChanged: (v) => s.update(() => s.lang = v ?? 'en'),
              ),
            ),
            _header(S.t('Camera', 'کیمرہ')),
            ListTile(
              leading: const Icon(Icons.high_quality),
              title: Text(S.t('Photo quality', 'تصویر کا معیار')),
              subtitle: Text(S.t('Lower quality = smaller file', 'کم معیار = چھوٹی فائل')),
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
              leading: const Icon(Icons.videocam),
              title: Text(S.t('Video quality', 'ویڈیو کا معیار')),
              trailing: DropdownButton<int>(
                value: s.videoQuality,
                underline: const SizedBox(),
                items: [
                  for (var i = 0; i < 3; i++)
                    DropdownMenuItem(value: i, child: Text(AppSettings.videoLabels[i])),
                ],
                onChanged: (v) => s.update(() => s.videoQuality = v ?? 0),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.volume_down),
              title: Text(S.t('Volume button action', 'والیوم بٹن کا کام')),
              trailing: DropdownButton<int>(
                value: s.volumeAction,
                underline: const SizedBox(),
                items: [
                  for (var i = 0; i < 3; i++)
                    DropdownMenuItem(value: i, child: Text(AppSettings.volumeLabels[i])),
                ],
                onChanged: (v) => s.update(() => s.volumeAction = v ?? 0),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio),
              title: Text(S.t('Ratio', 'ریشو')),
              trailing: DropdownButton<int>(
                value: s.ratio,
                underline: const SizedBox(),
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(value: i, child: Text(AppSettings.ratioLabels[i])),
                ],
                onChanged: (v) => s.update(() => s.ratio = v ?? 0),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.grid_on),
              title: Text(S.t('Grid', 'گرڈ')),
              value: s.grid,
              onChanged: (v) => s.update(() => s.grid = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: Text(S.t('Shutter sound', 'کیمرے کی آواز')),
              value: s.sound,
              onChanged: (v) => s.update(() => s.sound = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.flip),
              title: Text(S.t('Mirror', 'مرر (Mirror)')),
              subtitle: Text(S.t('Save photo flipped (like a mirror)', 'تصویر الٹی (شیشے کی طرح) محفوظ ہو')),
              value: s.mirror,
              onChanged: (v) => s.update(() => s.mirror = v),
            ),
            _header(S.t('Stamp', 'اسٹیمپ')),
            ListTile(
              leading: const Icon(Icons.layers),
              title: Text(S.t('Map type', 'نقشے کی قسم')),
              subtitle: Text(mapTypeNames()[s.mapType]),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showMapTypeSheet(context),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.map),
              title: Text(S.t('Show map', 'نقشہ دکھائیں')),
              subtitle: Text(S.t('Satellite map (needs internet)', 'سیٹلائٹ نقشہ (انٹرنیٹ درکار)')),
              value: s.showMap,
              onChanged: (v) => s.update(() => s.showMap = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.photo_camera),
              title: Text(S.t('Show app logo', 'ایپ کا لوگو دکھائیں')),
              value: s.showLogo,
              onChanged: (v) => s.update(() => s.showLogo = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notes),
              title: Text(S.t('Show note on stamp', 'اسٹیمپ پر نوٹ دکھائیں')),
              value: s.showNote,
              onChanged: (v) => s.update(() => s.showNote = v),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(S.t('Note (text printed on stamp)', 'نوٹ (اسٹیمپ پر لکھا جانے والا متن)')),
              subtitle: Text(s.note.isEmpty ? '—' : s.note),
              onTap: () => _editText(context, S.t('Note', 'نوٹ'), s.note, (v) => s.update(() => s.note = v)),
            ),
            _header(S.t('File name', 'فائل کا نام')),
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
              title: Text(S.t('Date and time', 'تاریخ اور وقت')),
              value: s.nameDate,
              onChanged: (v) => s.update(() => s.nameDate = v ?? true),
            ),
            CheckboxListTile(
              title: Text(S.t('Sequence number', 'سیریل نمبر')),
              value: s.nameSeq,
              onChanged: (v) => s.update(() => s.nameSeq = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Latitude / Longitude'),
              value: s.nameLatLng,
              onChanged: (v) => s.update(() => s.nameLatLng = v ?? false),
            ),
            CheckboxListTile(
              title: Text(S.t('Custom name', 'اپنا نام')),
              subtitle: Text(s.customName),
              value: s.nameCustom,
              onChanged: (v) => s.update(() => s.nameCustom = v ?? true),
              secondary: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editText(
                    context, S.t('Custom name in file name', 'فائل کے نام میں اپنا نام'), s.customName,
                    (v) => s.update(() => s.customName = v)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(S.t('Report settings', 'رپورٹ سیٹنگز')),
              subtitle: Text(S.t('Titles, footer, date and map links', 'عنوان، فوٹر، تاریخ اور میپ لنک')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ReportSettingsScreen())),
            ),
            if (AppConfig.statsReady)
              SwitchListTile(
                secondary: const Icon(Icons.insights),
                title: Text(S.t('Share anonymous usage info', 'گمنام استعمال کی معلومات شیئر کریں')),
                subtitle: Text(S.t('App version, phone model, approximate area (~1 km)',
                    'ایپ ورژن، فون ماڈل، تقریبی علاقہ (~1 کلومیٹر)')),
                value: s.statsConsent == 1,
                onChanged: (v) => s.update(() => s.statsConsent = v ? 1 : 0),
              ),
            _header(S.t('Storage and share', 'سٹوریج اور شیئر')),
            SwitchListTile(
              secondary: const Icon(Icons.photo_library),
              title: Text(S.t('Also save to gallery', 'گیلری میں بھی محفوظ کریں')),
              subtitle: Text(S.t('Album: GPS Camera', 'البم: GPS Camera')),
              value: s.saveGallery,
              onChanged: (v) => s.update(() => s.saveGallery = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.image),
              title: Text(S.t('Also save original photo', 'اصل تصویر بھی محفوظ کریں')),
              subtitle: Text(S.t('Second photo without stamp (in gallery)', 'اسٹیمپ کے بغیر دوسری تصویر (گیلری میں)')),
              value: s.saveOriginal,
              onChanged: (v) => s.update(() => s.saveOriginal = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.share),
              title: Text(S.t('Open share after each photo', 'ہر تصویر کے بعد شیئر کھولیں')),
              value: s.shareAfter,
              onChanged: (v) => s.update(() => s.shareAfter = v),
            ),
            const SizedBox(height: 20),
            const CreditBanner(),
            const Center(child: Text('GPS Camera $kAppVersion', style: TextStyle(color: Colors.black45))),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('Cancel', 'منسوخ'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, tc.text), child: Text(S.t('OK', 'ٹھیک ہے'))),
        ],
      ),
    );
    if (r != null) onSave(r.trim());
  }
}
