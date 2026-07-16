import 'package:flutter/material.dart';

import 'home/client_home_screen.dart';

/// クライアントモードのルート。Phase 1 は単一画面（ホーム）。
class ClientShell extends StatelessWidget {
  const ClientShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClientHomeScreen();
  }
}
