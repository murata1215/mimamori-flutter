import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client/client_shell.dart';
import 'client/confirm/confirm_alive_screen.dart';
import 'core/notifications/local_notifications.dart';
import 'core/providers.dart';
import 'core/storage/prefs.dart';
import 'core/theme.dart';
import 'onboarding/role_select_screen.dart';
import 'watcher/watcher_shell.dart';

/// アプリのグローバル navigator（通知タップからの遷移に使う）。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MimamoriApp extends ConsumerStatefulWidget {
  const MimamoriApp({super.key});

  @override
  ConsumerState<MimamoriApp> createState() => _MimamoriAppState();
}

class _MimamoriAppState extends ConsumerState<MimamoriApp> {
  @override
  void initState() {
    super.initState();
    // 通知タップのハンドリング
    LocalNotifications.onSelect = _handleNotificationTap;
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    if (payload == 'confirming') {
      final prefs = ref.read(prefsProvider);
      nav.push(MaterialPageRoute(
        builder: (_) => ConfirmAliveScreen(clientName: prefs.clientId ?? ''),
      ));
    } else if (payload.startsWith('sos:')) {
      final incidentId = payload.substring(4);
      nav.pushNamed('/watcher/sos', arguments: incidentId);
    } else if (payload == 'alert') {
      // ウォッチャーホームへ
      nav.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);

    return MaterialApp(
      title: 'みまもり',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.light(),
      home: _initialScreen(prefs),
    );
  }

  Widget _initialScreen(Prefs prefs) => rootScreenFor(prefs);
}

/// prefs の状態からアプリのルート画面を決定する。
/// ロール切替・退会後の再構築でも再利用する。
Widget rootScreenFor(Prefs prefs) {
  if (!prefs.hasSelectedRole) {
    return const RoleSelectScreen();
  }
  final active = prefs.activeRole ?? prefs.roles.first;
  switch (active) {
    case AppRole.client:
      return const ClientShell();
    case AppRole.watcher:
      return const WatcherShell();
  }
}
