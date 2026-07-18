import 'client_status.dart';

/// ウォッチャーが見守る対象クライアント。
/// プライバシー原則: 開示するのは時刻のみ（15分粒度・内容なし）。
/// - statusChangedAt: ステータスが現在の状態に変わった時刻
/// - lastActivityAt: 本人が最後に端末を操作した時刻（生存確認の中核）
/// - lastSeenAt: 端末が最後にサーバーと通信できた時刻（端末生存）
/// アプリ名・操作内容など「何をしたか」は一切保持しない。
class WatchedClient {
  final String id;
  final String displayName;
  final ClientStatus status;
  final DateTime? statusChangedAt;
  final DateTime? lastActivityAt; // 最後に操作が検出された時刻（server: last_activity_at）
  final DateTime? lastSeenAt; // 最後に通信できた時刻（server: last_seen_at）
  final bool hasIssue; // 権限失効など設定に問題がある（サーバー: has_issue）
  final String? propertyTag; // オーナープラン: 物件グルーピング

  const WatchedClient({
    required this.id,
    required this.displayName,
    required this.status,
    this.statusChangedAt,
    this.lastActivityAt,
    this.lastSeenAt,
    this.hasIssue = false,
    this.propertyTag,
  });

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory WatchedClient.fromJson(Map<String, dynamic> json) {
    return WatchedClient(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '名前未設定',
      status: ClientStatus.fromApi(json['status'] as String?),
      statusChangedAt: _parseDate(json['status_changed_at']),
      lastActivityAt: _parseDate(json['last_activity_at']),
      lastSeenAt: _parseDate(json['last_seen_at']),
      hasIssue: (json['has_issue'] as bool?) ?? false,
      propertyTag: json['property_tag'] as String?,
    );
  }

  WatchedClient copyWith({
    ClientStatus? status,
    DateTime? statusChangedAt,
    DateTime? lastActivityAt,
    DateTime? lastSeenAt,
  }) {
    return WatchedClient(
      id: id,
      displayName: displayName,
      status: status ?? this.status,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      hasIssue: hasIssue,
      propertyTag: propertyTag,
    );
  }
}

/// ステータス遷移履歴の1件（粒度は遷移のみ）。
class StatusTransition {
  final ClientStatus from;
  final ClientStatus to;
  final DateTime at;

  const StatusTransition({
    required this.from,
    required this.to,
    required this.at,
  });

  factory StatusTransition.fromJson(Map<String, dynamic> json) {
    return StatusTransition(
      // サーバーは from が null（初回遷移）を返すことがある → unknown 扱い。
      from: ClientStatus.fromApi(json['from'] as String?),
      to: ClientStatus.fromApi(json['to'] as String?),
      // サーバーのフィールド名は changed_at。
      at: DateTime.parse(json['changed_at'] as String),
    );
  }
}
