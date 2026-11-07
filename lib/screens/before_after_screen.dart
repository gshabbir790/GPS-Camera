import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/app_settings.dart';
import '../services/photo_meta.dart';
import '../services/report_export.dart';
import '../widgets/report_widgets.dart';
import 'photo_picker_screen.dart';
import 'report_settings_screen.dart';

class _Cmp {
  String? before, after;
  PhotoMeta? metaB, metaA;
  final TextEditingController title;
  final TextEditingController descB = TextEditingController();
  final TextEditingController descA = TextEditingController();
  _Cmp(String t) : title = TextEditingController(text: t);

  void dispose() {
    title.dispose();
    descB.dispose();
    descA.dispose();
  }
}

/// Before / After رپورٹ
class BeforeAfterScreen extends StatefulWidget {
  const BeforeAfterScreen({super.key});

  @override
  State<BeforeAfterScreen> createState() => _BeforeAfterScreenState();
}

class _BeforeAfterScreenState extends State<BeforeAfterScreen> with ReportExporter {
  final s = AppSettings.instance;
  final List<_Cmp> _cmps = [];
  final _summary = TextEditingController();

  @override
  String get reportName => 'Before_After_Report';

  @override
  List<ReportLink> collectLinks() {
    final out = <ReportLink>[];
    for (final c in _cmps) {
      final n = c.title.text.trim();
      if (c.metaB != null) out.add(ReportLink('$n - Before', c.metaB!.mapsUrl));
      if (c.metaA != null) out.add(ReportLink('$n - After', c.metaA!.mapsUrl));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _cmps.add(_Cmp('Comparison 1'));
    s.addListener(_refresh);
  }

  @override
  void dispose() {
    s.removeListener(_refresh);
    for (final c in _cmps) {
      c.dispose();
    }
    _summary.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pick(_Cmp c, bool before) async {
    final r = await Navigator.push<List<String>>(
        context, MaterialPageRoute(builder: (_) => const PhotoPickerScreen(multi: false)));
    if (r == null || r.isEmpty) return;
    setState(() {
      if (before) {
        c.before = r.first;
        c.metaB = readMeta(r.first);
      } else {
        c.after = r.first;
        c.metaA = readMeta(r.first);
      }
    });
  }

  void _swap(_Cmp c) {
    setState(() {
      final p = c.before, m = c.metaB;
      c.before = c.after;
      c.metaB = c.metaA;
      c.after = p;
      c.metaA = m;
    });
  }

  Widget _textField(TextEditingController c, String hint,
      {double size = 14, bool bold = false, Color color = kNavy}) {
    final style = TextStyle(
        fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.normal, color: color);
    if (exporting) {
      return c.text.trim().isEmpty ? const SizedBox.shrink() : Text(c.text, style: style);
    }
    return TextField(
      controller: c,
      maxLines: null,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: size, color: Colors.black38),
      ),
      style: style,
    );
  }

  Widget _slot(_Cmp c, bool before) {
    final path = before ? c.before : c.after;
    final meta = before ? c.metaB : c.metaA;
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: before ? const Color(0xFFE84545) : const Color(0xFF2EDB1E),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(before ? 'Before' : 'After',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    );

    final Widget box;
    if (path == null) {
      box = DashedRRect(
        child: Container(
          height: 230,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: exporting
              ? const SizedBox.shrink()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFFCFCFCF),
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(S.t('Tap to add', 'شامل کرنے کے لیے دبائیں'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF50566B))),
                ]),
        ),
      );
    } else {
      box = Container(
        height: 230,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Image.file(File(path), fit: BoxFit.contain, cacheWidth: 900),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: exporting ? null : () => _pick(c, before),
        child: Stack(children: [
          box,
          Positioned(top: 10, right: 10, child: label),
          if (path != null && !exporting && before)
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () => _swap(c),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.swap_horiz, color: Colors.white, size: 22),
                ),
              ),
            ),
        ]),
      ),
      if (s.rpShowLinks && meta != null) MapsLink(meta),
      _textField(before ? c.descB : c.descA, S.t('Add a description (optional)', 'تفصیل لکھیں (اختیاری)'),
          size: 14),
    ]);
  }

  Widget _cmpBlock(int i) {
    final c = _cmps[i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _textField(c.title, 'Comparison ${i + 1}', size: 22, bold: true)),
        if (_cmps.length > 1 && !exporting)
          IconButton(
            icon: const Icon(Icons.delete, color: kNavy, size: 28),
            onPressed: () => setState(() {
              _cmps.removeAt(i).dispose();
            }),
          ),
      ]),
      Container(height: 1.5, color: const Color(0xFF50566B), margin: const EdgeInsets.only(bottom: 12)),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _slot(c, true)),
        const SizedBox(width: 12),
        Expanded(child: _slot(c, false)),
      ]),
      const SizedBox(height: 18),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Before / After'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ReportSettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: RepaintBoundary(
          key: reportKey,
          child: ColoredBox(
            color: Colors.white,
            child: ReportFrame(
              title: s.rpTitleBA,
              showDate: s.rpShowDate,
              summary: _textField(_summary, S.t('Add Summary (Optional)', 'خلاصہ لکھیں (اختیاری)'),
                  size: 17, bold: true, color: const Color(0xFF50566B)),
              footer: s.rpFooter,
              body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < _cmps.length; i++) _cmpBlock(i),
                if (!exporting)
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _cmps.add(_Cmp('Comparison ${_cmps.length + 1}'))),
                      icon: const Icon(Icons.add),
                      label: Text(S.t('Add Comparison Group', 'نیا موازنہ گروپ شامل کریں')),
                    ),
                  ),
              ]),
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
