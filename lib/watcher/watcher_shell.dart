import 'package:flutter/material.dart';

import '../core/ads/ad_banner_bar.dart';
import 'home/watcher_home_screen.dart';
import 'sos/sos_map_screen.dart';

/// ウォッチャーモードのルート。
/// 通知タップからの SOS 地図遷移用に onGenerateRoute を持つ。
/// 無料利用向けに下部へアンカーバナー広告を固定表示するが、
/// SOS 画面（/watcher/sos）表示中は緊急性を優先して広告を隠す。
class WatcherShell extends StatefulWidget {
  const WatcherShell({super.key});

  @override
  State<WatcherShell> createState() => _WatcherShellState();
}

class _WatcherShellState extends State<WatcherShell> {
  /// 現在 SOS 画面を表示中かどうか（true の間は広告を隠す）。
  final ValueNotifier<bool> _sosVisible = ValueNotifier<bool>(false);
  late final _SosRouteObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = _SosRouteObserver(_sosVisible);
  }

  @override
  void dispose() {
    _sosVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Navigator(
            observers: [_observer],
            onGenerateRoute: (settings) {
              if (settings.name == '/watcher/sos') {
                final incidentId = settings.arguments as String? ?? '';
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => SosMapScreen(incidentId: incidentId),
                );
              }
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const WatcherHomeScreen(),
              );
            },
          ),
        ),
        // SOS 表示中はバナーを隠す。
        ValueListenableBuilder<bool>(
          valueListenable: _sosVisible,
          builder: (_, sos, child) => sos
              ? const SizedBox.shrink()
              : const SafeArea(top: false, child: AdBannerBar()),
        ),
      ],
    );
  }
}

/// SOS 画面の表示/離脱を監視して [visible] に反映する NavigatorObserver。
class _SosRouteObserver extends NavigatorObserver {
  _SosRouteObserver(this.visible);
  final ValueNotifier<bool> visible;

  bool _isSos(Route<dynamic>? route) =>
      route?.settings.name == '/watcher/sos';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isSos(route)) visible.value = true;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isSos(route)) visible.value = _isSos(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isSos(route)) visible.value = _isSos(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    visible.value = _isSos(newRoute);
  }
}
