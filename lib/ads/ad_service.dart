import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob: consent (UMP) + initialize
class AdService {
  // AdMob App ID (AndroidManifest.xml میں بھی یہی ہے):
  // ca-app-pub-2423643004395632~9386499372
  static const _bannerReal = 'ca-app-pub-2423643004395632/2009913093';
  static const _bannerTest = 'ca-app-pub-3940256099942544/6300978111'; // گوگل کا ٹیسٹ یونٹ

  /// debug بلڈ میں ٹیسٹ اشتہار، release میں اصلی
  static String get bannerUnitId => kDebugMode ? _bannerTest : _bannerReal;

  static Future<void>? _init;
  static bool canRequest = false;

  static Future<void> init() => _init ??= _doInit();

  static Future<void> _doInit() async {
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {});
          } catch (_) {}
          if (!done.isCompleted) done.complete();
        },
        (FormError e) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
      canRequest = await ConsentInformation.instance.canRequestAds();
      if (canRequest) await MobileAds.instance.initialize();
    } catch (_) {
      canRequest = false;
    }
  }
}
