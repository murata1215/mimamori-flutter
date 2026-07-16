import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../heartbeat/heartbeat_service.dart';
import 'local_notifications.dart';

/// FCM の初期化・受信ハンドリング。
///
/// - CONFIRMING: 全画面インテント通知を出す
/// - ALERT / SOS: ウォッチャーへ強通知
/// - silent push: クライアント端末で即時ハートビート送信を試みる
///   （WorkManager が殺された端末の検出・リカバリ）
///
/// google-services.json 未配置でも初期化失敗をガードし、他機能を止めない。
class FcmService {
  static bool available = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      available = true;
    } catch (_) {
      // Firebase 未設定（google-services.json 無し）でもアプリは動く。
      // スタックトレースは出さず、1行の案内のみに留める。
      debugPrint(
        '[FCM] google-services.json 未配置のため FCM は無効です'
        '（android/app/ に配置すれば自動で有効になります）',
      );
      available = false;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
      FirebaseMessaging.onMessage.listen(_handleForeground);
    } catch (e) {
      debugPrint('[FCM] setup skipped: $e');
    }
  }

  static Future<String?> token() async {
    if (!available) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _handleForeground(RemoteMessage message) async {
    await _route(message);
  }

  static Future<void> _route(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    final name = data['client_name'] ?? '見守り対象';

    switch (type) {
      case 'confirming':
        await LocalNotifications.showConfirming(data['client_name'] ?? 'あなた');
        break;
      case 'alert':
        await LocalNotifications.showAlert(name);
        break;
      case 'sos':
        await LocalNotifications.showSos(name, data['incident_id'] ?? '');
        break;
      case 'permission_health':
        await LocalNotifications.showNormal(
          '設定に問題',
          '$name の端末から信号が届いていません（電池切れ/設定の可能性）',
        );
        break;
      case 'silent_heartbeat':
        // サーバー発の silent push: 端末が生きていれば即ハートビート
        await HeartbeatService.sendOnce();
        break;
      default:
        if (message.notification != null) {
          await LocalNotifications.showNormal(
            message.notification!.title ?? 'みまもり',
            message.notification!.body ?? '',
          );
        }
    }
  }
}

/// バックグラウンド isolate のエントリ（トップレベル関数である必要がある）。
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  final type = message.data['type'];
  if (type == 'silent_heartbeat') {
    await HeartbeatService.sendOnce();
  } else if (type == 'confirming') {
    await LocalNotifications.init();
    await LocalNotifications.showConfirming(
      message.data['client_name'] ?? 'あなた',
    );
  } else if (type == 'sos') {
    await LocalNotifications.init();
    await LocalNotifications.showSos(
      message.data['client_name'] ?? '見守り対象',
      message.data['incident_id'] ?? '',
    );
  } else if (type == 'alert') {
    await LocalNotifications.init();
    await LocalNotifications.showAlert(
      message.data['client_name'] ?? '見守り対象',
    );
  }
}
