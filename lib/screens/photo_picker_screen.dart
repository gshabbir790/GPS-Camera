import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/photo_meta.dart';

/// ایپ سٹوریج سے تصاویر منتخب کریں (رپورٹ کے لیے)
class PhotoPickerScreen extends StatefulWidget {
  final bool multi;
  const PhotoPickerScreen({super.key, this.multi = true});

  @override
  State<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<PhotoPickerScreen> {
  List<File> _files = [];
  final Set<String> _sel = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    listPhotoFiles().then((l) {
      if (mounted) {
        setState(() {
          _files = l;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('Select photos', 'تصاویر منتخب کریں')),
        actions: [
          if (widget.multi)
            TextButton(
              onPressed: _sel.isEmpty ? null : () => Navigator.pop(context, _sel.toList()),
              child: Text(S.t('Add (${_sel.length})', 'شامل کریں (${_sel.length})')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      S.t('No photos in Storage yet. Take photos with the camera first.',
                          'سٹوریج میں ابھی کوئی تصویر نہیں۔ پہلے کیمرے سے تصاویر لیں۔'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _files.length,
                  itemBuilder: (context, i) {
                    final f = _files[i];
                    final sel = _sel.contains(f.path);
                    return GestureDetector(
                      onTap: () {
                        if (!widget.multi) {
                          Navigator.pop(context, [f.path]);
                          return;
                        }
                        setState(() => sel ? _sel.remove(f.path) : _sel.add(f.path));
                      },
                      child: Stack(fit: StackFit.expand, children: [
                        Image.file(f, fit: BoxFit.cover, cacheWidth: 300),
                        if (sel) Container(color: Colors.black38),
                        if (widget.multi)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              sel ? Icons.check_circle : Icons.circle_outlined,
                              color: sel ? const Color(0xFFFFC400) : Colors.white,
                            ),
                          ),
                      ]),
                    );
                  },
                ),
    );
  }
}
