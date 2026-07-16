import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ローカル通知（全画面インテント通知を含む）。
///
/// 本人確認 (CONFIRMING) はロック画面上に全画面表示し、アラーム音＋バイブで
/// 本人に届ける。誤報の逃げ道であり、KPI「本人確認解除率」の生命線。
class LocalNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// タップ時のコールバック（route 遷移に使う）。
  static void Function(String? payload)? onSelect;

  static const _confirmChannel = AndroidNotificationChannel(
    'confirming_fullscreen',
    '本人確認（全画面）',
    description: '見守りからの安否確認。全画面で表示されます。',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const _alertChannel = AndroidNotificationChannel(
    'alert_channel',
    '警告・SOS',
    description: '見守り対象の警告・SOS 通知。',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const _normalChannel = AndroidNotificationChannel(
    'normal_channel',
    '通常通知',
    description: '注視・設定に関する通知。',
    importance: Importance.defaultImportance,
  );

  static Future<void> init() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) => onSelect?.call(resp.payload),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_confirmChannel);
    await android?.createNotificationChannel(_alertChannel);
    await android?.createNotificationChannel(_normalChannel);
    await android?.requestNotificationsPermission();
  }

  /// 本人確認: ロック画面上に全画面表示。
  static Future<void> showConfirming(String clientName) async {
    final details = AndroidNotificationDetails(
      _confirmChannel.id,
      _confirmChannel.name,
      channelDescription: _confirmChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // ロック画面上に全画面
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        '$clientName、無事ですか？ タップしてお知らせください',
      ),
    );
    await _plugin.show(
      1001,
      '無事ですか？',
      'タップして無事をお知らせください',
      NotificationDetails(android: details),
      payload: 'confirming',
    );
  }

  static Future<void> cancelConfirming() => _plugin.cancel(1001);

  /// ウォッチャー向け警告（全画面＋アラーム音）。
  static Future<void> showAlert(String clientName) async {
    final details = AndroidNotificationDetails(
      _alertChannel.id,
      _alertChannel.name,
      channelDescription: _alertChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      color: const Color(0xFFD32F2F),
      styleInformation: BigTextStyleInformation(
        '$clientName の安否確認ができません。電話などで確認してください。',
      ),
    );
    await _plugin.show(
      2001,
      '⚠ 警告: $clientName',
      '安否確認ができません',
      NotificationDetails(android: details),
      payload: 'alert',
    );
  }

  /// ウォッチャー向け SOS（全画面＋地図への直行 payload）。
  static Future<void> showSos(String clientName, String incidentId) async {
    final details = AndroidNotificationDetails(
      _alertChannel.id,
      _alertChannel.name,
      channelDescription: _alertChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      playSound: true,
      enableVibration: true,
      color: const Color(0xFF7B1FA2),
      styleInformation: BigTextStyleInformation(
        '$clientName が SOS を発動しました。至急ご確認ください。',
      ),
    );
    await _plugin.show(
      3001,
      '🆘 SOS: $clientName',
      'タップして位置を確認',
      NotificationDetails(android: details),
      payload: 'sos:$incidentId',
    );
  }

  /// 通常通知（注視・設定に問題）。
  static Future<void> showNormal(String title, String body) async {
    final details = AndroidNotificationDetails(
      _normalChannel.id,
      _normalChannel.name,
      channelDescription: _normalChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      4001,
      title,
      body,
      NotificationDetails(android: details),
      payload: 'normal',
    );
  }
}
