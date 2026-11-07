import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';

class ReportLink {
  final String label;
  final String url;
  const ReportLink(this.label, this.url);
}

enum ReportAction { photo, pdf, share, whatsapp }

class _EncArgs {
  final Uint8List data;
  final int w, h;
  const _EncArgs(this.data, this.w, this.h);
}

Uint8List _encodeJpg(_EncArgs a) {
  final im = img.Image.fromBytes(
      width: a.w, height: a.h, bytes: a.data.buffer, numChannels: 4);
  return Uint8List.fromList(img.encodeJpg(im, quality: 88));
}

class _PdfArgs {
  final Uint8List jpg;
  final int w, h;
  final List<List<String>> links; // [label, url]
  const _PdfArgs(this.jpg, this.w, this.h, this.links);
}

Future<Uint8List> _buildPdf(_PdfArgs a) async {
  final doc = pw.Document();
  const pageW = 595.28;
  final pageH = pageW * a.h / a.w;
  // پوری رپورٹ ایک لمبے صفحے پر (تصویریں درمیان سے نہیں کٹتیں)
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat(pageW, pageH),
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Image(pw.MemoryImage(a.jpg), fit: pw.BoxFit.fill),
  ));
  if (a.links.isNotEmpty) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => <pw.Widget>[
        pw.Text('Locations (Google Maps)',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        for (var i = 0; i < a.links.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.UrlLink(
              destination: a.links[i][1],
              child: pw.Text(
                '${i + 1}. Open in Google Maps  -  ${a.links[i][0]}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.blue,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    ));
  }
  return doc.save();
}

class ReportCapture {
  final Uint8List jpg;
  final int w, h;
  const ReportCapture(this.jpg, this.w, this.h);
}

class ReportExport {
  static const _filesCh = MethodChannel('gps_camera/files');

  static Future<ReportCapture> capture(GlobalKey key) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final size = boundary.size;
    final ratio = min(1440 / size.width, 8000 / size.height).clamp(0.5, 4.0).toDouble();
    final image = await boundary.toImage(pixelRatio: ratio);
    final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) throw Exception('Could not render report');
    final data = Uint8List.fromList(
        bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes));
    final w = image.width, h = image.height;
    final jpg = await compute(_encodeJpg, _EncArgs(data, w, h));
    return ReportCapture(jpg, w, h);
  }

  static Future<Uint8List> pdf(ReportCapture c, List<ReportLink> links) {
    return compute(
      _buildPdf,
      _PdfArgs(c.jpg, c.w, c.h, [for (final l in links) [l.label, l.url]]),
    );
  }

  static Future<Directory> reportsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/reports');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static String timestamp() {
    final t = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p(t.month)}${p(t.day)}_${p(t.hour)}${p(t.minute)}${p(t.second)}';
  }

  /// Downloads/GPS Camera میں محفوظ (Android کے MediaStore کے ذریعے)
  static Future<bool> saveToDownloads(String path, String name, String mime) async {
    try {
      await _filesCh.invokeMethod('saveToDownloads', {'path': path, 'name': name, 'mime': mime});
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// دونوں رپورٹ اسکرینوں میں مشترک: Save Photo / Save PDF / Share / WhatsApp
mixin ReportExporter<T extends StatefulWidget> on State<T> {
  final GlobalKey reportKey = GlobalKey();
  bool exporting = false;
  bool _working = false;

  List<ReportLink> collectLinks();
  String get reportName;

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 3)));
  }

  Future<void> runExport(ReportAction a) async {
    if (_working) return;
    _working = true;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 150));
      final cap = await ReportExport.capture(reportKey);
      if (mounted) setState(() => exporting = false);

      final dir = await ReportExport.reportsDir();
      final base = '${reportName}_${ReportExport.timestamp()}';
      final links = collectLinks();
      final caption = links.isEmpty
          ? ''
          : [
              for (var i = 0; i < links.length; i++)
                '${i + 1}. ${links[i].label}\n${links[i].url}'
            ].join('\n\n');

      Future<File> writeJpg() async {
        final f = File('${dir.path}/$base.jpg');
        await f.writeAsBytes(cap.jpg);
        return f;
      }

      switch (a) {
        case ReportAction.photo:
          final f = await writeJpg();
          if (!await Gal.hasAccess(toAlbum: true)) await Gal.requestAccess(toAlbum: true);
          await Gal.putImage(f.path, album: 'GPS Camera');
          toast(S.t('Report saved to gallery ✓', 'رپورٹ گیلری میں محفوظ ہو گئی ✓'));
          break;
        case ReportAction.pdf:
          final bytes = await ReportExport.pdf(cap, links);
          final f = File('${dir.path}/$base.pdf');
          await f.writeAsBytes(bytes);
          final ok = await ReportExport.saveToDownloads(f.path, '$base.pdf', 'application/pdf');
          if (ok) {
            toast(S.t('PDF saved in Downloads/GPS Camera ✓',
                'PDF محفوظ ہو گئی: Downloads/GPS Camera ✓'));
          } else {
            await Share.shareXFiles([XFile(f.path)], text: caption);
          }
          break;
        case ReportAction.share:
          final bytes = await ReportExport.pdf(cap, links);
          final f = File('${dir.path}/$base.pdf');
          await f.writeAsBytes(bytes);
          await Share.shareXFiles([XFile(f.path)], text: caption.isEmpty ? null : caption);
          break;
        case ReportAction.whatsapp:
          final f = await writeJpg();
          await Share.shareXFiles([XFile(f.path)], text: caption.isEmpty ? null : caption);
          break;
      }
    } catch (e) {
      toast(S.t('Error: $e', 'خرابی: $e'));
    } finally {
      if (mounted) setState(() => exporting = false);
      _working = false;
    }
  }
}
