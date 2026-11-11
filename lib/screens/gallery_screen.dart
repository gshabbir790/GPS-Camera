import 'dart:io';

import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/photo_meta.dart';
import '../services/photo_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// ایپ میں محفوظ تصاویر (سٹوریج)
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await PhotoStore.allPhotos();
    if (mounted) {
      setState(() {
        _files = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('Storage (${_files.length})', 'سٹوریج (${_files.length})'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(child: Text(S.t('No photos yet', 'ابھی کوئی تصویر نہیں')))
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _files.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _Viewer(file: _files[i])),
                      );
                      _load();
                    },
                    child: Image.file(_files[i], fit: BoxFit.cover, cacheWidth: 300),
                  ),
                ),
    );
  }
}

class _Viewer extends StatelessWidget {
  final File file;
  const _Viewer({required this.file});

  @override
  Widget build(BuildContext context) {
    final name = file.path.split('/').last;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(name, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          if (readMeta(file.path) != null)
            IconButton(
              tooltip: 'Open in Google Maps',
              icon: const Icon(Icons.location_on),
              onPressed: () async {
                final m = readMeta(file.path)!;
                final ok = await openMaps(m.lat, m.lon);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(S.t('Could not open Google Maps', 'گوگل میپس نہیں کھل سکا'))));
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.shareXFiles([XFile(file.path)]),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(S.t('Delete photo?', 'تصویر حذف کریں؟')),
                  content: Text(S.t('The gallery copy will not be deleted.', 'گیلری والی کاپی حذف نہیں ہوگی۔')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('No', 'نہیں'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true), child: Text(S.t('Delete', 'حذف'))),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  file.deleteSync();
                  deleteMeta(file.path);
                  PhotoStore.scan(file.path);
                } catch (_) {}
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Center(child: InteractiveViewer(child: Image.file(file))),
    );
  }
}
