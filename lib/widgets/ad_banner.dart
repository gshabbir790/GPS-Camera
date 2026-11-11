import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_service.dart';

/// چھوٹا بینر اشتہار (کیمرہ اسکرین پر نہیں لگایا جاتا)
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AdService.init();
    if (!mounted || !AdService.canRequest) return;
    final ad = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (mounted) {
            setState(() => _loaded = true);
          } else {
            a.dispose();
          }
        },
        onAdFailedToLoad: (a, e) => a.dispose(),
      ),
    );
    _ad = ad;
    try {
      await ad.load();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Center(child: SizedBox(width: 320, height: 50, child: AdWidget(ad: ad))),
    );
  }
}
