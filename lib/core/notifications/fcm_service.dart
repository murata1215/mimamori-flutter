import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../heartbeat/heartbeat_service.dart';
import '../models/stamp.dart';
import '../storage/prefs.dart';
import 'local_notifications.dart';

/// FCM の初期化・受信ハンドリング。
///
/// サーバーは data payload の `kind` で種別を伝える（`type` ではない）:
/// - confirming: クライアント端末で全画面インテント通知（本人確認）
/// - watch / alert / sos / permission / outage: ウォッチャーへの通知
/// - silent: クライアント端末で即時ハートビート送信（WorkManager 死活のリカバリ）
///
/// data 値はすべて文字列。ウォッチャー宛には `client_name` が含まれる想定だが、
/// 未提供の場合はローカルキャッシュ / 汎用文言でフォールバックする。
///
/// google-services.json 未配置でも初期化失敗をガードし、他機能を止めない。
class FcmService {
  static bool available = false;
  static ApiClient? _api;
  static Prefs? _prefs;

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

  /// API クライアント / Prefs を束ね、FCM トークンの登録・更新を有効化する。
  /// トークン更新（onTokenRefresh）時に現在のロールへ自動再登録する。
  static void configure(ApiClient api, Prefs prefs) {
    _api = api;
    _prefs = prefs;
    if (!available) return;
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => syncToken());
    } catch (e) {
      debugPrint('[FCM] onTokenRefresh listen skipped: $e');
    }
    // 起動時に一度、保有トークンをサーバーへ同期。
    syncToken();
  }

  static Future<String?> token() async {
    if (!available) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// 現在の FCM トークンを、保有するロールのトークンに紐づけてサーバー登録する。
  static Future<void> syncToken() async {
    final api = _api;
    final prefs = _prefs;
    if (api == null || prefs == null) return;
    final fcm = await token();
    if (fcm == null) return;

    final clientToken = prefs.clientToken;
    if (clientToken != null) {
      try {
        await api.updateDeviceFcmToken(
          clientToken: clientToken,
          fcmToken: fcm,
        );
      } catch (e) {
        debugPrint('[FCM] device token sync failed: $e');
      }
    }

    final watcherToken = prefs.watcherToken;
    if (watcherToken != null) {
      try {
        await api.updateWatcherFcmToken(
          watcherToken: watcherToken,
          fcmToken: fcm,
        );
      } catch (e) {
        debugPrint('[FCM] watcher token sync failed: $e');
      }
    }
  }

  static Future<void> _handleForeground(RemoteMessage message) async {
    await _route(message);
  }

  static Future<void> _route(RemoteMessage message) async {
    final data = message.data;
    final kind = data['kind'];
    final name = _nameFor(data);

    switch (kind) {
      case 'confirming':
        await LocalNotifications.showConfirming('あなた');
        break;
      case 'watch':
        await LocalNotifications.showNormal(
          '見守り',
          '$name の様子を確認しています',
        );
        break;
      case 'alert':
        await LocalNotifications.showAlert(name);
        break;
      case 'sos':
        await LocalNotifications.showSos(name, data['incident_id'] ?? '');
        break;
      case 'permission':
        await LocalNotifications.showNormal(
          '設定に問題',
          '$name の端末から信号が届いていません（電池切れ/設定の可能性）',
        );
        break;
      case 'outage':
        // outage はサービス全体の一時停止を全ウォッチャーへ一斉送信する通知。
        // 特定クライアントに紐づかない（client_id / client_name なし）ため、
        // 個人名を使わずサービス全体の汎用文言で表示する。
        await LocalNotifications.showNormal(
          '見守りが一時停止していました',
          _outageBody(data['gap_minutes']),
        );
        break;
      case 'stamp':
        // スタンプ（きもち）の双方向通知。data: { stamp, direction, client_name? / sender_name? }
        await LocalNotifications.showNormal('きもちが届きました', _stampBody(data));
        break;
      case 'silent':
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

  /// 通知に表示する対象名。サーバーが client_name を送らない場合は
  /// ローカルキャッシュ（未実装環境では null）→ 汎用文言でフォールバック。
  static String _nameFor(Map<String, dynamic> data) {
    final n = data['client_name'];
    if (n is String && n.isNotEmpty) return n;
    return '見守り対象';
  }
}

/// スタンプ通知の本文。送信者名は direction によって
/// client_name（クライアント発）/ sender_name（ウォッチャー発）を使い分ける。
String _stampBody(Map<String, dynamic> data) {
  final label = StampKind.of((data['stamp'] as String?) ?? '').label;
  final direction = data['direction'];
  String sender;
  if (direction == 'from_watcher') {
    final n = data['sender_name'];
    sender = (n is String && n.isNotEmpty) ? n : 'ご家族';
  } else {
    final n = data['client_name'];
    sender = (n is String && n.isNotEmpty) ? n : '見守り対象';
  }
  return '$senderから「$label」のスタンプが届きました';
}

/// outage（サービス全体の見守り一時停止）通知の本文。
/// gap_minutes は文字列（例 "30"）で届く。存在すれば分数を埋め込む。
String _outageBody(Object? gapMinutes) {
  final gap = gapMinutes;
  if (gap is String && gap.isNotEmpty) {
    return 'サーバー側の問題で約$gap分間、見守りが停止していました。現在は復旧しています。';
  }
  return 'サーバー側の問題で一時的に見守りが停止していました。現在は復旧しています。';
}

/// バックグラウンド isolate のエントリ（トップレベル関数である必要がある）。
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  final data = message.data;
  final kind = data['kind'];
  final name =
      (data['client_name'] is String && (data['client_name'] as String).isNotEmpty)
          ? data['client_name'] as String
          : '見守り対象';

  if (kind == 'silent') {
    await HeartbeatService.sendOnce();
  } else if (kind == 'confirming') {
    await LocalNotifications.init();
    await LocalNotifications.showConfirming('あなた');
  } else if (kind == 'sos') {
    await LocalNotifications.init();
    await LocalNotifications.showSos(name, data['incident_id'] ?? '');
  } else if (kind == 'alert') {
    await LocalNotifications.init();
    await LocalNotifications.showAlert(name);
  } else if (kind == 'permission') {
    await LocalNotifications.init();
    await LocalNotifications.showNormal(
      '設定に問題',
      '$name の端末から信号が届いていません（電池切れ/設定の可能性）',
    );
  } else if (kind == 'outage') {
    // サービス全体の一時停止（client_id / client_name なし）。個人名は使わない。
    await LocalNotifications.init();
    await LocalNotifications.showNormal(
      '見守りが一時停止していました',
      _outageBody(data['gap_minutes']),
    );
  } else if (kind == 'stamp') {
    await LocalNotifications.init();
    await LocalNotifications.showNormal('きもちが届きました', _stampBody(data));
  }
}
