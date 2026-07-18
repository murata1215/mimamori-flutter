import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../feature_flags.dart';
import 'ad_config.dart';

/// 画面下部に固定表示するアンカー型アダプティブバナー広告。
///
/// - 前面ポップアップ（インタースティシャル等）は使わず、下部バナーのみ。
/// - 読み込み失敗・未初期化・非対応プラットフォームでは高さ 0（SizedBox.shrink）で
///   空白を残さない。
/// - [kEnableAds] が false の場合は常に非表示。
class AdBannerBar extends StatefulWidget {
  const AdBannerBar({super.key});

  @override
  State<AdBannerBar> createState() => _AdBannerBarState();
}

class _AdBannerBarState extends State<AdBannerBar> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Android / iOS のみ対応。それ以外（Web/デスクトップ）は読み込まない。
    if (kEnableAds && (Platform.isAndroid || Platform.isIOS)) {
      // 幅確定後に読み込む（アダプティブサイズは画面幅を要するため）。
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }
  }

  Future<void> _loadAd() async {
    if (!mounted) return;
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width,
    );
    if (size == null || !mounted) return;

    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!kEnableAds || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
