/// クライアント端末の日次活動量（ウォッチャー詳細で「この3日間のようす」表示）。
///
/// プライバシー原則: サーバーは数量の集計のみ返す（時刻詳細・アプリ名・座標は含まない）。
/// - [screenOnCount]: その日に画面を点けた回数の合計
/// - [appUsageSlots]: アプリを使った15分スロット数（× 15分 で概算時間）
/// - [movementSlots]: 動きがあった15分スロット数（× 15分 で概算時間）
/// - [heartbeatCount]: 端末が応答した回数（技術指標）
class DailyActivity {
  /// その日（端末ローカル日付、日付のみ）。
  final DateTime date;
  final int screenOnCount;
  final int appUsageSlots;
  final int movementSlots;
  final int heartbeatCount;

  const DailyActivity({
    required this.date,
    required this.screenOnCount,
    required this.appUsageSlots,
    required this.movementSlots,
    required this.heartbeatCount,
  });

  /// 何らかの活動シグナルがあったか（全メトリクス 0 なら「記録なし」扱い）。
  bool get hasActivity =>
      screenOnCount > 0 || appUsageSlots > 0 || movementSlots > 0;

  /// 動きがあった概算時間の表示文字列（例: 「約2時間」「約45分」「—」）。
  String get movementDuration => _slotsToDuration(movementSlots);

  /// スマホを使った概算時間の表示文字列。
  String get appUsageDuration => _slotsToDuration(appUsageSlots);

  /// 15分スロット数を「約◯時間◯分」の日本語表記に変換する。
  static String _slotsToDuration(int slots) {
    if (slots <= 0) return '—';
    final minutes = slots * 15;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '約$mins分';
    if (mins == 0) return '約$hours時間';
    return '約$hours時間$mins分';
  }

  factory DailyActivity.fromJson(Map<String, dynamic> json) => DailyActivity(
        // date は "2026-07-18" 形式。時刻を持たない日付として扱う。
        date: DateTime.parse(json['date'] as String),
        screenOnCount: (json['screen_on_count'] as num?)?.toInt() ?? 0,
        appUsageSlots: (json['app_usage_slots'] as num?)?.toInt() ?? 0,
        movementSlots: (json['movement_slots'] as num?)?.toInt() ?? 0,
        heartbeatCount: (json['heartbeat_count'] as num?)?.toInt() ?? 0,
      );
}
