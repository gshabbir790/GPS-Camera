import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/app_settings.dart';
import '../services/photo_meta.dart';
import '../services/report_export.dart';
import '../widgets/report_widgets.dart';
import 'photo_picker_screen.dart';
import 'report_settings_screen.dart';

class _RItem {
  final String path;
  final PhotoMeta? meta;
  final DateTime time;
  _RItem(this.path, this.meta, this.time);
}

/// فوٹو رپورٹ: تصاویر + تاریخ/وقت + Open in Google Maps
class PhotoReportScreen extends StatefulWidget {
  const PhotoReportScreen({super.key});

  @override
  State<PhotoReportScreen> createState() => _PhotoReportScreenState();
}

class _PhotoReportScreenState extends State<PhotoReportScreen> with ReportExporter {
  final s = AppSettings.instance;
  final List<_RItem> _items = [];
  final _summary = TextEditingController();

  @override
  String get reportName => 'Photo_Report';

  @override
  List<ReportLink> collectLinks() => [
        for (final it in _items)
          if (it.meta != null) ReportLink(fmtDateTime(it.time), it.meta!.mapsUrl),
      ];

  @override
  void initState() {
    super.initState();
    s.addListener(_refresh);
  }

  @override
  void dispose() {
    s.removeListener(_refresh);
    _summary.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final r = await Navigator.push<List<String>>(
        context, MaterialPageRoute(builder: (_) => const PhotoPickerScreen(multi: true)));
    if (r == null) return;
    setState(() {
      for (final p in r) {
        if (_items.any((e) => e.path == p)) continue;
        final m = readMeta(p);
        DateTime t;
        try {
          t = m?.time ?? File(p).lastModifiedSync();
        } catch (_) {
          t = DateTime.now();
        }
        _items.add(_RItem(p, m, t));
      }
    });
  }

  Widget _cell(_RItem it) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(File(it.path),
              width: double.infinity, fit: BoxFit.fitWidth, cacheWidth: 900),
        ),
        if (!exporting)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => setState(() => _items.remove(it)),
              child: const CircleAvatar(
                radius: 13,
                backgroundColor: Color(0xCCFFFFFF),
                child: Icon(Icons.close, size: 16, color: Colors.black54),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Text(fmtDateTime(it.time),
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: kNavy)),
      if (s.rpShowLinks && it.meta != null) MapsLink(it.meta!),
      const SizedBox(height: 10),
    ]);
  }

  Widget _grid() {
    if (_items.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Text(
          S.t('Tap + to add photos', 'تصاویر شامل کرنے کے لیے + دبائیں'),
          style: const TextStyle(color: Colors.black45, fontSize: 16),
        ),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < _items.length; i += 2) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _cell(_items[i])),
        const SizedBox(width: 10),
        Expanded(child: i + 1 < _items.length ? _cell(_items[i + 1]) : const SizedBox()),
      ]));
    }
    return Column(children: rows);
  }

  Widget _summaryField() {
    if (exporting) {
      return _summary.text.trim().isEmpty
          ? const SizedBox.shrink()
          : Text(_summary.text, style: const TextStyle(fontSize: 15, color: kNavy));
    }
    return TextField(
      controller: _summary,
      maxLines: null,
      decoration: InputDecoration(
        hintText: S.t('Add Summary (Optional)', 'خلاصہ لکھیں (اختیاری)'),
        border: InputBorder.none,
        isDense: true,
      ),
      style: const TextStyle(fontSize: 15, color: kNavy),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('Photo Report', 'فوٹو رپورٹ')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ReportSettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: exporting
          ? null
          : FloatingActionButton(
              backgroundColor: kYellow,
              foregroundColor: Colors.black,
              onPressed: _add,
              child: const Icon(Icons.add, size: 30),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90),
        child: RepaintBoundary(
          key: reportKey,
          child: ColoredBox(
            color: Colors.white,
            child: ReportFrame(
              title: s.rpTitle,
              showDate: s.rpShowDate,
              summary: _summaryField(),
              body: _grid(),
              footer: s.rpFooter,
            ),
          ),
        ),
      ),
      bottomNavigationBar: ReportActionBar(
        busy: exporting,
        onTap: (i) => runExport(ReportAction.values[i]),
      ),
    );
  }
}
