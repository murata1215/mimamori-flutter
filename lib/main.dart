import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'core/feature_flags.dart';
import 'core/heartbeat/heartbeat_service.dart';
import 'core/heartbeat/heartbeat_task.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/local_notifications.dart';
import 'core/native_bridge.dart';
import 'core/providers.dart';
import 'core/storage/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await Prefs.create();

  // API クライアントは単一インスタンスを生成し、FCM トークン登録と共有する。
  final api = createApiClient(prefs);

  // 広告 SDK 初期化（無料利用向け下部バナー用。失敗しても起動を止めない）
  if (kEnableAds) {
    try {
      unawaited(MobileAds.instance.initialize());
    } catch (_) {}
  }

  // 通知・FCM・WorkManager を初期化（いずれも失敗しても起動を止めない）
  await LocalNotifications.init();
  await FcmService.init();
  // FCM トークンの登録・更新を有効化（保有ロールのトークンへ紐づけて送信）
  FcmService.configure(api, prefs);
  await HeartbeatScheduler.initialize();

  // 生存イベント収集用の SCREEN_ON レシーバを登録
  await NativeBridge.registerScreenReceiver();

  // クライアントとしてオンボーディング済みなら定期送信を再開
  if (prefs.roles.contains(AppRole.client) && prefs.clientOnboarded) {
    await HeartbeatScheduler.start();
    // 「アプリを開いた＝生存」シグナル。周期起床が保証されない iOS で特に有効
    // （Android にも害はない）。UI をブロックしないよう fire-and-forget。
    unawaited(HeartbeatService.sendOnce());
  }

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
      ],
      child: const MimamoriApp(),
    ),
  );
}
