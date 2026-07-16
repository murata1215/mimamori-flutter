import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/heartbeat/heartbeat_task.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/local_notifications.dart';
import 'core/native_bridge.dart';
import 'core/providers.dart';
import 'core/storage/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await Prefs.create();

  // 通知・FCM・WorkManager を初期化（いずれも失敗しても起動を止めない）
  await LocalNotifications.init();
  await FcmService.init();
  await HeartbeatScheduler.initialize();

  // 生存イベント収集用の SCREEN_ON レシーバを登録
  await NativeBridge.registerScreenReceiver();

  // クライアントとしてオンボーディング済みなら定期送信を再開
  if (prefs.roles.contains(AppRole.client) && prefs.clientOnboarded) {
    await HeartbeatScheduler.start();
  }

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const MimamoriApp(),
    ),
  );
}
