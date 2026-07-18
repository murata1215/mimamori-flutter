import 'package:flutter/material.dart';

import 'home/client_home_screen.dart';

/// クライアントモードのルート。Phase 1 は単一画面（ホーム）。
///
/// クライアント（見守られる本人）は無償で見守りに協力してくれている側であり、
/// 高齢者は誤タップも多いため、広告は表示しない（信頼感を優先）。
/// 広告は課金導線のあるウォッチャー側（WatcherShell）にのみ限定する。
class ClientShell extends StatelessWidget {
  const ClientShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClientHomeScreen();
  }
}
