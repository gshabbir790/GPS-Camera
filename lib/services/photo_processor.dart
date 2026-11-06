import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ProcessArgs {
  final String srcPath;
  final String outPath;
  final Uint8List stampPng;
  final double ratio; // چوڑائی / اونچائی
  final int maxWidth;
  final int jpgQuality;
  final bool mirror;

  const ProcessArgs({
    required this.srcPath,
    required this.outPath,
    required this.stampPng,
    required this.ratio,
    required this.maxWidth,
    required this.jpgQuality,
    required this.mirror,
  });
}

/// الگ isolate میں چلتا ہے (compute کے ذریعے): کراپ + سائز + اسٹیمپ + JPG محفوظ
Future<String> processPhoto(ProcessArgs a) async {
  var im = img.decodeJpg(File(a.srcPath).readAsBytesSync());
  if (im == null) throw Exception('Could not open photo');
  im = img.bakeOrientation(im);

  // مطلوبہ ریشو پر کراپ
  final cur = im.width / im.height;
  if ((cur - a.ratio).abs() > 0.01) {
    if (cur > a.ratio) {
      final nw = (im.height * a.ratio).round();
      im = img.copyCrop(im, x: ((im.width - nw) / 2).round(), y: 0, width: nw, height: im.height);
    } else {
      final nh = (im.width / a.ratio).round();
      im = img.copyCrop(im, x: 0, y: ((im.height - nh) / 2).round(), width: im.width, height: nh);
    }
  }

  if (im.width > a.maxWidth) {
    im = img.copyResize(im, width: a.maxWidth, interpolation: img.Interpolation.average);
  }
  if (a.mirror) im = img.flipHorizontal(im);

  var stamp = img.decodePng(a.stampPng);
  if (stamp != null) {
    if (stamp.width != im.width) {
      stamp = img.copyResize(stamp, width: im.width, interpolation: img.Interpolation.linear);
    }
    img.compositeImage(im, stamp, dstX: 0, dstY: im.height - stamp.height);
  }

  File(a.outPath).writeAsBytesSync(img.encodeJpg(im, quality: a.jpgQuality));
  return a.outPath;
}
