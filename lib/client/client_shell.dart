import 'package:flutter/material.dart';

import '../core/ads/ad_banner_bar.dart';
import 'home/client_home_screen.dart';

/// クライアントモードのルート。Phase 1 は単一画面（ホーム）。
/// 無料利用向けに下部へアンカーバナー広告を固定表示する。
class ClientShell extends StatelessWidget {
  const ClientShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(child: ClientHomeScreen()),
        SafeArea(top: false, child: AdBannerBar()),
      ],
    );
  }
}
