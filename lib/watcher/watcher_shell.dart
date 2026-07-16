import 'package:flutter/material.dart';

import 'home/watcher_home_screen.dart';
import 'sos/sos_map_screen.dart';

/// ウォッチャーモードのルート。
/// 通知タップからの SOS 地図遷移用に onGenerateRoute を持つ。
class WatcherShell extends StatelessWidget {
  const WatcherShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        if (settings.name == '/watcher/sos') {
          final incidentId = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => SosMapScreen(incidentId: incidentId),
          );
        }
        return MaterialPageRoute(builder: (_) => const WatcherHomeScreen());
      },
    );
  }
}
