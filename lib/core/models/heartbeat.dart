/// ハートビート（生存シグナル）1件。
///
/// プライバシー原則: サーバーへ送るのは
///  - screen_on_count（回数）
///  - had_app_usage（利用有無 boolean）
///  - battery_level
/// のみ。アプリ名・URL・詳細時刻など行動の中身は絶対に含めない。
class Heartbeat {
  final DateTime occurredAt;
  final int batteryLevel;
  final int screenOnCount;
  final bool hadAppUsage;
  final String appVersion;

  const Heartbeat({
    required this.occurredAt,
    required this.batteryLevel,
    required this.screenOnCount,
    required this.hadAppUsage,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'battery_level': batteryLevel,
        'screen_on_count': screenOnCount,
        'had_app_usage': hadAppUsage,
        'app_version': appVersion,
      };

  factory Heartbeat.fromJson(Map<String, dynamic> json) => Heartbeat(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        batteryLevel: (json['battery_level'] as num).toInt(),
        screenOnCount: (json['screen_on_count'] as num).toInt(),
        hadAppUsage: json['had_app_usage'] as bool,
        appVersion: (json['app_version'] as String?) ?? '',
      );
}

/// ハートビート送信の統計（Phase 1 の合否判定データ）。
/// 端末側で送信成功/失敗/キュー滞留をカウントし、ペイロードに同梱する。
class DeliveryStats {
  final int sent;
  final int failed;
  final int queued;

  const DeliveryStats({
    this.sent = 0,
    this.failed = 0,
    this.queued = 0,
  });

  Map<String, dynamic> toJson() => {
        'sent': sent,
        'failed': failed,
        'queued': queued,
      };
}
