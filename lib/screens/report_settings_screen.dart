import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/app_settings.dart';

class ReportSettingsScreen extends StatelessWidget {
  const ReportSettingsScreen({super.key});

  Future<void> _edit(BuildContext context, String title, String initial, ValueChanged<String> save) async {
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
    if (r != null) save(r.trim());
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: Text(S.t('Report Settings', 'رپورٹ سیٹنگز'))),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(children: [
          ListTile(
            leading: const Icon(Icons.title),
            title: Text(S.t('Photo Report title', 'فوٹو رپورٹ کا عنوان')),
            subtitle: Text(s.rpTitle),
            onTap: () => _edit(context, S.t('Photo Report title', 'فوٹو رپورٹ کا عنوان'), s.rpTitle,
                (v) => s.update(() => s.rpTitle = v.isEmpty ? 'Photo Report' : v)),
          ),
          ListTile(
            leading: const Icon(Icons.compare),
            title: Text(S.t('Before / After title', 'Before / After کا عنوان')),
            subtitle: Text(s.rpTitleBA),
            onTap: () => _edit(context, S.t('Before / After title', 'Before / After کا عنوان'),
                s.rpTitleBA, (v) => s.update(() => s.rpTitleBA = v.isEmpty ? 'Before / After Report' : v)),
          ),
          ListTile(
            leading: const Icon(Icons.short_text),
            title: Text(S.t('Footer text', 'فوٹر کا متن')),
            subtitle: Text(s.rpFooter.isEmpty ? '—' : s.rpFooter),
            onTap: () => _edit(context, S.t('Footer text', 'فوٹر کا متن'), s.rpFooter,
                (v) => s.update(() => s.rpFooter = v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today),
            title: Text(S.t('Show date and time', 'تاریخ اور وقت دکھائیں')),
            value: s.rpShowDate,
            onChanged: (v) => s.update(() => s.rpShowDate = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.map),
            title: Text(S.t('Show "Open in Google Maps" links', '"Open in Google Maps" لنک دکھائیں')),
            value: s.rpShowLinks,
            onChanged: (v) => s.update(() => s.rpShowLinks = v),
          ),
        ]),
      ),
    );
  }
}
